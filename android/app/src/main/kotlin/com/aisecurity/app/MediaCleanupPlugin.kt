package com.aisecurity.app

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.media.MediaMetadataRetriever
import android.media.ThumbnailUtils
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import android.util.Base64
import android.util.Log
import android.util.Size
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.*
import java.io.ByteArrayOutputStream
import java.io.File
import java.security.MessageDigest

object MediaCleanupPlugin {

    private const val CHANNEL = "ai_security/media_cleanup"
    private const val TAG     = "MediaCleanup"

    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main)

    // WhatsApp subdirectory names (title-case — Android filesystem is case-sensitive)
    private val CATEGORY_DIRS = mapOf(
        "images"   to listOf("WhatsApp Images", "WhatsApp Animated Gifs", "WhatsApp AI Media"),
        "videos"   to listOf("WhatsApp Video", "WhatsApp Video Notes"),
        "audio"    to listOf("WhatsApp Audio", "WhatsApp Voice Notes", "WhatsApp Music"),
        "docs"     to listOf("WhatsApp Documents"),
        "stickers" to listOf("WhatsApp Stickers", "WhatsApp Sticker Packs", "WhatsApp Backup Excluded Stickers"),
    )

    private val CATEGORY_EXTENSIONS = mapOf(
        "images"   to setOf("jpg", "jpeg", "png", "gif", "bmp", "webp"),
        "videos"   to setOf("mp4", "3gp", "mkv", "mov", "avi", "webm"),
        "audio"    to setOf("mp3", "m4a", "ogg", "opus", "aac", "wav", "amr"),
        "docs"     to setOf("pdf", "doc", "docx", "xls", "xlsx", "ppt", "pptx", "txt", "zip", "apk"),
        "stickers" to setOf("webp"),
    )

    private const val LARGE_FILE_THRESHOLD = 50L * 1024 * 1024
    private const val OLD_MEDIA_THRESHOLD  = 180L * 24 * 3600 * 1000L

    // In-memory cache — avoid rescanning filesystem on every open
    private var _cachedFiles:     Map<String, List<FileInfo>>? = null
    private var _cachedDupGroups: List<Map<String, Any?>>?     = null
    private var _cacheTs: Long = 0
    private const val CACHE_TTL = 5 * 60 * 1000L // 5 minutes

    // ── Registration ─────────────────────────────────────────────────────────

    fun register(engine: FlutterEngine, context: Context) {
        MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    // ── Heavy async methods ───────────────────────────────
                    // Fire-and-forget pre-warm: starts scanning in background immediately
                    // so by the time user taps "Start Scan", cache is likely ready.
                    "warmCache" -> scope.launch {
                        withContext(Dispatchers.IO) { allFilesByCategory(context) }
                        result.success(null)
                    }
                    "scanAll" -> scope.launch {
                        val r = withContext(Dispatchers.IO) { scanAll(context) }
                        result.success(r)
                    }
                    "getFilesWithThumbs" -> scope.launch {
                        val cat    = call.argument<String>("category") ?: "images"
                        val offset = call.argument<Int>("offset")     ?: 0
                        val limit  = call.argument<Int>("limit")      ?: 20
                        val r = withContext(Dispatchers.IO) { getFilesWithThumbs(context, cat, offset, limit) }
                        result.success(r)
                    }
                    "getFilesMeta" -> scope.launch {
                        val cat    = call.argument<String>("category") ?: "images"
                        val offset = call.argument<Int>("offset")     ?: 0
                        val limit  = call.argument<Int>("limit")      ?: 20
                        val r = withContext(Dispatchers.IO) { getFilesMeta(context, cat, offset, limit) }
                        result.success(r)
                    }
                    "getThumbnailBatch" -> scope.launch {
                        @Suppress("UNCHECKED_CAST")
                        val paths = call.argument<List<String>>("paths") ?: emptyList()
                        // getThumbnailBatch is already a suspend function managing its own IO dispatching
                        val r = getThumbnailBatch(context, paths)
                        result.success(r)
                    }
                    "getDuplicateGroups" -> scope.launch {
                        val r = withContext(Dispatchers.IO) { getDuplicateGroups(context) }
                        result.success(r)
                    }
                    // ── Lightweight sync methods ──────────────────────────
                    "deleteFiles" -> {
                        @Suppress("UNCHECKED_CAST")
                        val paths = call.argument<List<String>>("paths") ?: emptyList()
                        result.success(deleteFiles(context, paths))
                    }
                    "deleteCategory" -> {
                        val cat = call.argument<String>("category") ?: ""
                        result.success(deleteCategory(context, cat))
                    }
                    // legacy methods kept for backward compat
                    "getStats"  -> result.success(getStats(context))
                    "getFiles"  -> {
                        val cat = call.argument<String>("category") ?: ""
                        result.success(getFilesLegacy(context, cat))
                    }
                    else -> result.notImplemented()
                }
            }
    }

    // ── Data classes ─────────────────────────────────────────────────────────

    private data class FileInfo(
        val path:     String,
        val name:     String,
        val size:     Long,
        val modified: Long,      // epoch ms
        val mimeType: String = "",
        val isSent:   Boolean = false,
        var md5:      String  = "",
    )

    // ── Core scan ─────────────────────────────────────────────────────────────

    private fun scanAll(context: Context): Map<String, Any> {
        // Single cached scan — all categories at once
        val byCategory = allFilesByCategory(context)
        val allFiles   = byCategory.values.flatten()
        val now        = System.currentTimeMillis()

        // Standard categories — already grouped, no extra filtering needed
        val categories = byCategory.entries.associate { (cat, files) ->
            cat to mapOf(
                "count" to files.size.toLong(),
                "size"  to files.sumOf { it.size },
            )
        }

        // Smart categories (derived, no extra scan)
        val largeFiles  = allFiles.filter { it.size >= LARGE_FILE_THRESHOLD }
        val oldMedia    = allFiles.filter { now - it.modified >= OLD_MEDIA_THRESHOLD }
        val forwarded   = allFiles.filter { it.isSent }

        // Duplicates: cheap size-bucket estimate only (no MD5 — MD5 is deferred to getDuplicateGroups)
        val potentialDups = allFiles.groupBy { it.size }.filter { it.value.size > 1 }
        val dupEstimateCount = potentialDups.values.sumOf { it.size - 1 }.toLong()
        val dupEstimateSize  = potentialDups.values.sumOf { (it.size - 1) * it.first().size }

        val smart = mapOf(
            "large_files" to mapOf(
                "count" to largeFiles.size.toLong(),
                "size"  to largeFiles.sumOf { it.size },
            ),
            "old_media" to mapOf(
                "count" to oldMedia.size.toLong(),
                "size"  to oldMedia.sumOf { it.size },
            ),
            "forwarded" to mapOf(
                "count" to forwarded.size.toLong(),
                "size"  to forwarded.sumOf { it.size },
            ),
            "duplicates" to mapOf(
                "count" to dupEstimateCount,
                "size"  to dupEstimateSize,
            ),
        )

        val total = mapOf(
            "count" to allFiles.size.toLong(),
            "size"  to allFiles.sumOf { it.size },
        )

        Log.d(TAG, "scanAll: ${allFiles.size} files, total ${total["size"]} bytes")
        return mapOf("categories" to categories, "smart" to smart, "total" to total)
    }

    /** Compute wasted bytes from duplicates without keeping results in memory. */
    private fun computeDuplicateWaste(files: List<FileInfo>): Pair<Long, Long> {
        var wastedCount = 0L
        var wastedSize  = 0L
        val bySizeGroup = files.groupBy { it.size }.filter { it.value.size > 1 }
        for ((_, group) in bySizeGroup) {
            val byHash = group.groupBy { md5(File(it.path)) }.filter { it.value.size > 1 }
            for ((_, dups) in byHash) {
                wastedCount += dups.size - 1
                wastedSize  += (dups.size - 1) * dups.first().size
            }
        }
        return Pair(wastedCount, wastedSize)
    }

    // ── Paginated file listing with thumbnails ────────────────────────────────

    private fun getFilesWithThumbs(
        context: Context,
        category: String,
        offset: Int,
        limit: Int,
    ): List<Map<String, Any?>> {
        val files = smartCategoryFiles(context, category)
        return files
            .sortedByDescending { it.size }
            .drop(offset)
            .take(limit)
            .map { f ->
                val ext   = f.name.substringAfterLast('.').lowercase()
                val cacheDir = thumbCacheDir(context)
                val thumb = when {
                    f.mimeType.startsWith("image/") || ext in setOf("jpg","jpeg","png","gif","bmp","webp") ->
                        generateImageThumb(f.path, f.modified, cacheDir)
                    f.mimeType.startsWith("video/") || ext in setOf("mp4","3gp","mkv","mov","avi","webm") ->
                        generateVideoThumb(f.path, f.modified, cacheDir)
                    else -> null
                }
                mapOf(
                    "path"      to f.path,
                    "name"      to f.name,
                    "size"      to f.size,
                    "modified"  to f.modified,
                    "mimeType"  to f.mimeType,
                    "isSent"    to f.isSent,
                    "thumb"     to thumb,
                )
            }
    }

    /** Returns all files for a category, including smart categories. */
    private fun smartCategoryFiles(context: Context, category: String): List<FileInfo> {
        return when (category) {
            "large_files"  -> {
                val all = allFilesFlat(context)
                all.filter { it.size >= LARGE_FILE_THRESHOLD }
            }
            "old_media"    -> {
                val now = System.currentTimeMillis()
                val all = allFilesFlat(context)
                all.filter { now - it.modified >= OLD_MEDIA_THRESHOLD }
            }
            "forwarded"    -> {
                val all = allFilesFlat(context)
                all.filter { it.isSent }
            }
            "duplicates"   -> {
                // Return the duplicate files (all but the "keep" copy per group)
                val all = allFilesFlat(context)
                val toDelete = mutableListOf<FileInfo>()
                val bySizeGroup = all.groupBy { it.size }.filter { it.value.size > 1 }
                for ((_, group) in bySizeGroup) {
                    val byHash = group.groupBy { md5(File(it.path)) }.filter { it.value.size > 1 }
                    for ((_, dups) in byHash) {
                        val keep = dups.maxByOrNull { it.modified }!!
                        toDelete.addAll(dups.filter { it.path != keep.path })
                    }
                }
                toDelete
            }
            else -> categoryFiles(context, category)
        }
    }

    private fun allFilesFlat(context: Context): List<FileInfo> {
        val all = mutableListOf<FileInfo>()
        for (cat in CATEGORY_DIRS.keys) all.addAll(categoryFiles(context, cat))
        return all
    }

    // ── Duplicate groups (full detail, cached after first MD5 pass) ───────────

    private fun getDuplicateGroups(context: Context): List<Map<String, Any?>> {
        // Return cached result if available (MD5 is expensive)
        _cachedDupGroups?.let { return it }

        val all     = allFilesFlat(context)
        val cacheDir = thumbCacheDir(context)
        val groups  = mutableListOf<Map<String, Any?>>()

        val bySizeGroup = all.groupBy { it.size }.filter { it.value.size > 1 }
        for ((_, group) in bySizeGroup) {
            val byHash = group.groupBy { md5(File(it.path)) }.filter { it.value.size > 1 }
            for ((hash, dups) in byHash) {
                val keep = dups.maxByOrNull { it.modified }!!
                // Only generate a thumb for the FIRST file in the group (preview in card header)
                val previewThumb = generateImageThumb(dups.first().path, dups.first().modified, cacheDir)
                    ?: generateVideoThumb(dups.first().path, dups.first().modified, cacheDir)
                val filesList = dups.map { f ->
                    mapOf(
                        "path"     to f.path,
                        "name"     to f.name,
                        "size"     to f.size,
                        "modified" to f.modified,
                        "isSent"   to f.isSent,
                        "keep"     to (f.path == keep.path),
                        // Individual thumbs loaded lazily via getThumbnailBatch
                        "thumb"    to if (f.path == dups.first().path) previewThumb else null,
                    )
                }
                groups.add(mapOf(
                    "md5"   to hash,
                    "count" to dups.size.toLong(),
                    "size"  to dups.first().size,
                    "files" to filesList,
                ))
            }
        }

        val result = groups.sortedByDescending { (it["size"] as Long) * (it["count"] as Long) }
        _cachedDupGroups = result
        return result
    }

    // ── File discovery ────────────────────────────────────────────────────────

    /** Returns all files grouped by category. Uses in-memory cache (5 min TTL). */
    private fun allFilesByCategory(context: Context): Map<String, List<FileInfo>> {
        val now = System.currentTimeMillis()
        _cachedFiles?.takeIf { now - _cacheTs < CACHE_TTL }?.let { return it }

        val isManager = Build.VERSION.SDK_INT >= Build.VERSION_CODES.R &&
                Environment.isExternalStorageManager()
        val result = if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q || isManager)
            allFilesByFsSinglePass()
        else
            allFilesByMediaStore(context)

        _cachedFiles = result
        _cacheTs     = now
        Log.d(TAG, "allFilesByCategory: scanned ${result.values.sumOf { it.size }} files")
        return result
    }

    private fun categoryFiles(context: Context, category: String): List<FileInfo> =
        allFilesByCategory(context)[category] ?: emptyList()

    /** Single walkTopDown pass over all WA roots — much faster than 5 separate walks. */
    private fun allFilesByFsSinglePass(): Map<String, List<FileInfo>> {
        val result: Map<String, MutableList<FileInfo>> =
            CATEGORY_DIRS.keys.associateWith { mutableListOf() }
        val extStorage = Environment.getExternalStorageDirectory()

        val waRoots = listOf(
            "WhatsApp/Media",
            "Android/media/com.whatsapp/WhatsApp/Media",
            "Android/media/com.whatsapp.w4b/WhatsApp Business/Media",
        ).map { File(extStorage, it) }.filter { it.exists() && it.isDirectory }

        for (root in waRoots) {
            root.walkTopDown()
                .filter { it.isFile && !it.name.startsWith(".") }
                .forEach { f ->
                    val cat = inferCategory(f) ?: return@forEach
                    result[cat]?.add(FileInfo(
                        path     = f.absolutePath,
                        name     = f.name,
                        size     = f.length(),
                        modified = f.lastModified(),
                        mimeType = mimeForExt(f.extension),
                        isSent   = f.absolutePath.contains("/Sent/"),
                    ))
                }
        }

        // Flat Pictures/WhatsApp/ (newer WA versions)
        val picturesWa = File(extStorage, "Pictures/WhatsApp")
        if (picturesWa.exists()) {
            picturesWa.listFiles()
                ?.filter { it.isFile && !it.name.startsWith(".") }
                ?.forEach { f ->
                    val cat = inferCategoryByExt(f.extension.lowercase()) ?: return@forEach
                    result[cat]?.add(FileInfo(
                        path     = f.absolutePath,
                        name     = f.name,
                        size     = f.length(),
                        modified = f.lastModified(),
                        mimeType = mimeForExt(f.extension),
                        isSent   = false,
                    ))
                }
        }
        return result
    }

    /** MediaStore fallback grouped by category (Android 10 without MANAGE_EXTERNAL_STORAGE). */
    private fun allFilesByMediaStore(context: Context): Map<String, List<FileInfo>> {
        val result: Map<String, MutableList<FileInfo>> =
            CATEGORY_DIRS.keys.associateWith { mutableListOf() }
        val uri = MediaStore.Files.getContentUri("external")
        val projection = arrayOf(
            MediaStore.Files.FileColumns.DATA,
            MediaStore.Files.FileColumns.DISPLAY_NAME,
            MediaStore.Files.FileColumns.SIZE,
            MediaStore.Files.FileColumns.DATE_MODIFIED,
            MediaStore.Files.FileColumns.MIME_TYPE,
        )
        try {
            context.contentResolver.query(
                uri, projection,
                "${MediaStore.Files.FileColumns.DATA} LIKE ?",
                arrayOf("%WhatsApp%"), null
            )?.use { cursor ->
                val di = cursor.getColumnIndexOrThrow(MediaStore.Files.FileColumns.DATA)
                val ni = cursor.getColumnIndexOrThrow(MediaStore.Files.FileColumns.DISPLAY_NAME)
                val si = cursor.getColumnIndexOrThrow(MediaStore.Files.FileColumns.SIZE)
                val mi = cursor.getColumnIndexOrThrow(MediaStore.Files.FileColumns.DATE_MODIFIED)
                val ti = cursor.getColumnIndexOrThrow(MediaStore.Files.FileColumns.MIME_TYPE)
                while (cursor.moveToNext()) {
                    val path = cursor.getString(di) ?: continue
                    if (File(path).name.startsWith(".")) continue
                    val info = FileInfo(
                        path     = path,
                        name     = cursor.getString(ni) ?: File(path).name,
                        size     = cursor.getLong(si),
                        modified = cursor.getLong(mi) * 1000L,
                        mimeType = cursor.getString(ti) ?: "",
                        isSent   = path.contains("/Sent/"),
                    )
                    val cat = inferCategoryByExt(path.substringAfterLast('.').lowercase())
                        ?: continue
                    result[cat]?.add(info)
                }
            }
        } catch (e: Exception) { Log.e(TAG, "allFilesByMediaStore: ${e.message}") }
        return result
    }

    private fun inferCategory(file: File): String? {
        val lp = file.absolutePath.lowercase()
        for ((cat, dirs) in CATEGORY_DIRS) {
            if (dirs.any { lp.contains(it.lowercase()) }) return cat
        }
        return inferCategoryByExt(file.extension.lowercase())
    }

    private fun inferCategoryByExt(ext: String): String? {
        for ((cat, exts) in CATEGORY_EXTENSIONS) {
            if (ext in exts) return cat
        }
        return null
    }

    private fun filesViaMediaStore(context: Context, category: String): List<FileInfo> {
        val dirs = CATEGORY_DIRS[category] ?: return emptyList()
        val files = mutableListOf<FileInfo>()
        val uri = MediaStore.Files.getContentUri("external")
        val projection = arrayOf(
            MediaStore.Files.FileColumns.DATA,
            MediaStore.Files.FileColumns.DISPLAY_NAME,
            MediaStore.Files.FileColumns.SIZE,
            MediaStore.Files.FileColumns.DATE_MODIFIED,
            MediaStore.Files.FileColumns.MIME_TYPE,
        )
        for (dirName in dirs) {
            try {
                context.contentResolver.query(
                    uri, projection,
                    "${MediaStore.Files.FileColumns.DATA} LIKE ?",
                    arrayOf("%WhatsApp%$dirName%"), null
                )?.use { cursor ->
                    val di = cursor.getColumnIndexOrThrow(MediaStore.Files.FileColumns.DATA)
                    val ni = cursor.getColumnIndexOrThrow(MediaStore.Files.FileColumns.DISPLAY_NAME)
                    val si = cursor.getColumnIndexOrThrow(MediaStore.Files.FileColumns.SIZE)
                    val mi = cursor.getColumnIndexOrThrow(MediaStore.Files.FileColumns.DATE_MODIFIED)
                    val ti = cursor.getColumnIndexOrThrow(MediaStore.Files.FileColumns.MIME_TYPE)
                    while (cursor.moveToNext()) {
                        val path = cursor.getString(di) ?: continue
                        if (File(path).name.startsWith(".")) continue
                        files.add(FileInfo(
                            path     = path,
                            name     = cursor.getString(ni) ?: File(path).name,
                            size     = cursor.getLong(si),
                            modified = cursor.getLong(mi) * 1000L,
                            mimeType = cursor.getString(ti) ?: "",
                            isSent   = path.contains("/Sent/"),
                        ))
                    }
                }
            } catch (e: Exception) {
                Log.e(TAG, "MediaStore query failed for $dirName: ${e.message}")
            }
        }

        // Broad fallback if nothing found
        if (files.isEmpty()) {
            try {
                context.contentResolver.query(
                    uri, projection,
                    "${MediaStore.Files.FileColumns.DATA} LIKE ?",
                    arrayOf("%WhatsApp%"), null
                )?.use { cursor ->
                    val di = cursor.getColumnIndexOrThrow(MediaStore.Files.FileColumns.DATA)
                    val ni = cursor.getColumnIndexOrThrow(MediaStore.Files.FileColumns.DISPLAY_NAME)
                    val si = cursor.getColumnIndexOrThrow(MediaStore.Files.FileColumns.SIZE)
                    val mi = cursor.getColumnIndexOrThrow(MediaStore.Files.FileColumns.DATE_MODIFIED)
                    val ti = cursor.getColumnIndexOrThrow(MediaStore.Files.FileColumns.MIME_TYPE)
                    while (cursor.moveToNext()) {
                        val path = cursor.getString(di) ?: continue
                        val f = FileInfo(
                            path     = path,
                            name     = cursor.getString(ni) ?: File(path).name,
                            size     = cursor.getLong(si),
                            modified = cursor.getLong(mi) * 1000L,
                            mimeType = cursor.getString(ti) ?: "",
                            isSent   = path.contains("/Sent/"),
                        )
                        if (fileMatchesCategory(f, category)) files.add(f)
                    }
                }
            } catch (e: Exception) { /* ignore */ }
        }

        return files
    }

    private fun fileMatchesCategory(file: FileInfo, category: String): Boolean {
        val lp   = file.path.lowercase()
        val ext  = file.path.substringAfterLast('.', "").lowercase()
        val mime = file.mimeType.lowercase()
        val categoryDirs = CATEGORY_DIRS[category] ?: emptyList()
        if (categoryDirs.any { lp.contains(it.lowercase()) }) return true
        val isInAnyKnownDir = CATEGORY_DIRS.values.flatten().any { lp.contains(it.lowercase()) }
        if (isInAnyKnownDir) return false
        val extensions = CATEGORY_EXTENSIONS[category] ?: emptySet()
        return when (category) {
            "images"   -> (mime.startsWith("image/") && ext != "webp") || ext in extensions
            "videos"   -> mime.startsWith("video/") || ext in extensions
            "audio"    -> mime.startsWith("audio/") || ext in extensions
            "docs"     -> ext in extensions
            "stickers" -> false
            else       -> false
        }
    }

    // ── Metadata-only listing (Phase 1 — instant) ────────────────────────────

    private fun getFilesMeta(context: Context, category: String, offset: Int, limit: Int): List<Map<String, Any?>> {
        return smartCategoryFiles(context, category)
            .sortedByDescending { it.size }
            .drop(offset)
            .take(limit)
            .map { f ->
                mapOf(
                    "path"     to f.path,
                    "name"     to f.name,
                    "size"     to f.size,
                    "modified" to f.modified,
                    "mimeType" to f.mimeType,
                    "isSent"   to f.isSent,
                )
            }
    }

    // ── Batch thumbnail fetch — parallel, with disk cache ────────────────────

    private suspend fun getThumbnailBatch(context: Context, paths: List<String>): Map<String, String?> {
        val cacheDir = thumbCacheDir(context)
        // Process in chunks of 4 to limit peak memory and avoid ANR
        val result = mutableMapOf<String, String?>()
        paths.chunked(8).forEach { chunk ->
            coroutineScope {
                chunk.map { path ->
                    async(Dispatchers.IO) {
                        val file = File(path)
                        if (!file.exists()) return@async path to null
                        val ext = path.substringAfterLast('.').lowercase()
                        val thumb = when {
                            ext in setOf("jpg","jpeg","png","gif","bmp","webp") ->
                                generateImageThumb(path, file.lastModified(), cacheDir)
                            ext in setOf("mp4","3gp","mkv","mov","avi","webm") ->
                                generateVideoThumb(path, file.lastModified(), cacheDir)
                            else -> null
                        }
                        path to thumb
                    }
                }.awaitAll().forEach { (p, t) -> result[p] = t }
            }
        }
        return result
    }

    // ── Thumbnail generation with disk cache ──────────────────────────────────

    private fun thumbCacheDir(context: Context): File =
        File(context.cacheDir, "thumb_cache").also { it.mkdirs() }

    private fun thumbCacheKey(path: String, modified: Long): String {
        val md = MessageDigest.getInstance("MD5")
        md.update(path.toByteArray())
        val hash = md.digest().joinToString("") { "%02x".format(it) }
        return "${hash}_$modified"
    }

    private fun generateImageThumb(path: String, modified: Long = 0, cacheDir: File? = null): String? {
        if (cacheDir != null) {
            val cached = File(cacheDir, "${thumbCacheKey(path, modified)}.jpg")
            if (cached.exists()) return Base64.encodeToString(cached.readBytes(), Base64.NO_WRAP)
        }
        return try {
            // ThumbnailUtils (API 29+) uses system media cache — much faster than BitmapFactory
            val bmp = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q)
                ThumbnailUtils.createImageThumbnail(File(path), Size(200, 200), null)
            else {
                val opts = BitmapFactory.Options().apply { inSampleSize = 8 }
                BitmapFactory.decodeFile(path, opts)
            } ?: return null
            val out = ByteArrayOutputStream()
            bmp.compress(Bitmap.CompressFormat.JPEG, 60, out)
            bmp.recycle()
            val bytes = out.toByteArray()
            cacheDir?.let { try { File(it, "${thumbCacheKey(path, modified)}.jpg").writeBytes(bytes) } catch (_: Exception) {} }
            Base64.encodeToString(bytes, Base64.NO_WRAP)
        } catch (e: Exception) { null }
    }

    private fun generateVideoThumb(path: String, modified: Long = 0, cacheDir: File? = null): String? {
        if (cacheDir != null) {
            val cached = File(cacheDir, "${thumbCacheKey(path, modified)}.jpg")
            if (cached.exists()) return Base64.encodeToString(cached.readBytes(), Base64.NO_WRAP)
        }
        return try {
            // ThumbnailUtils (API 29+) uses system-cached frame — much faster than MediaMetadataRetriever
            val bmp = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q)
                ThumbnailUtils.createVideoThumbnail(File(path), Size(200, 200), null)
            else
                @Suppress("DEPRECATION")
                ThumbnailUtils.createVideoThumbnail(path, MediaStore.Video.Thumbnails.MINI_KIND)
            bmp ?: return null
            val out = ByteArrayOutputStream()
            bmp.compress(Bitmap.CompressFormat.JPEG, 60, out)
            bmp.recycle()
            val bytes = out.toByteArray()
            cacheDir?.let { try { File(it, "${thumbCacheKey(path, modified)}.jpg").writeBytes(bytes) } catch (_: Exception) {} }
            Base64.encodeToString(bytes, Base64.NO_WRAP)
        } catch (e: Exception) { null }
    }

    // ── Deletion ──────────────────────────────────────────────────────────────

    private fun deleteFiles(context: Context, paths: List<String>): Map<String, Long> {
        _cachedFiles     = null  // invalidate so next scanAll rescans
        _cachedDupGroups = null
        var count = 0L
        var freed = 0L
        val isManager = Build.VERSION.SDK_INT >= Build.VERSION_CODES.R &&
                Environment.isExternalStorageManager()
        for (path in paths) {
            val f = File(path)
            if (!f.exists() || !f.isFile) continue
            freed += f.length()
            if (f.delete()) {
                count++
                // Notify MediaStore so gallery apps update
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q && !isManager) {
                    try {
                        context.contentResolver.delete(
                            MediaStore.Files.getContentUri("external"),
                            "${MediaStore.Files.FileColumns.DATA}=?",
                            arrayOf(path)
                        )
                    } catch (_: Exception) {}
                }
            }
        }
        return mapOf("count" to count, "freed" to freed)
    }

    private fun deleteCategory(context: Context, category: String): Map<String, Long> {
        val files = categoryFiles(context, category)
        return deleteFiles(context, files.map { it.path })
    }

    // ── Legacy compat ─────────────────────────────────────────────────────────

    private fun getStats(context: Context): Map<String, Map<String, Long>> {
        return CATEGORY_DIRS.keys.associate { cat ->
            val files = categoryFiles(context, cat)
            val totalMb = files.sumOf { it.size } / 1024 / 1024
            Log.d(TAG, "getStats[$cat]: ${files.size} files, ${totalMb} MB")
            cat to mapOf("count" to files.size.toLong(), "size" to files.sumOf { it.size })
        }
    }

    private fun getFilesLegacy(context: Context, category: String): List<Map<String, Any>> {
        return categoryFiles(context, category)
            .sortedByDescending { it.modified }
            .take(200)
            .map { f ->
                mapOf("path" to f.path, "name" to f.name,
                      "size" to f.size,  "modified" to f.modified)
            }
    }

    // ── Utilities ─────────────────────────────────────────────────────────────

    private fun md5(file: File): String {
        if (!file.exists()) return ""
        return try {
            val md = MessageDigest.getInstance("MD5")
            file.inputStream().buffered(65536).use { ins ->
                val buf = ByteArray(65536)
                var read: Int
                while (ins.read(buf).also { read = it } != -1) md.update(buf, 0, read)
            }
            md.digest().joinToString("") { "%02x".format(it) }
        } catch (e: Exception) { "" }
    }

    private fun mimeForExt(ext: String): String = when (ext.lowercase()) {
        "jpg", "jpeg" -> "image/jpeg"
        "png"         -> "image/png"
        "gif"         -> "image/gif"
        "webp"        -> "image/webp"
        "mp4"         -> "video/mp4"
        "3gp"         -> "video/3gpp"
        "mkv"         -> "video/x-matroska"
        "mov"         -> "video/quicktime"
        "mp3"         -> "audio/mpeg"
        "ogg"         -> "audio/ogg"
        "opus"        -> "audio/opus"
        "m4a"         -> "audio/mp4"
        "aac"         -> "audio/aac"
        "pdf"         -> "application/pdf"
        else          -> "application/octet-stream"
    }
}
