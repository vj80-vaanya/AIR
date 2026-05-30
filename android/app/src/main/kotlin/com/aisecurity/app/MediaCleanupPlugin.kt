package com.aisecurity.app

import android.content.Context
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import android.util.Log
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

object MediaCleanupPlugin {

    private const val CHANNEL = "ai_security/media_cleanup"
    private const val TAG = "MediaCleanup"

    // WhatsApp subdirectory names — title case matches the real filesystem (case-sensitive on Android).
    // Lowercase variants are used for MediaStore path comparisons in fileMatchesCategory().
    private val CATEGORY_DIRS = mapOf(
        "images"   to listOf("WhatsApp Images", "WhatsApp Animated Gifs", "WhatsApp AI Media"),
        "videos"   to listOf("WhatsApp Video", "WhatsApp Video Notes"),
        "audio"    to listOf("WhatsApp Audio", "WhatsApp Voice Notes", "WhatsApp Music"),
        "docs"     to listOf("WhatsApp Documents"),
        "stickers" to listOf("WhatsApp Stickers", "WhatsApp Sticker Packs", "WhatsApp Backup Excluded Stickers"),
    )

    // File extensions used as fallback for the flat Pictures/WhatsApp/ structure
    private val CATEGORY_EXTENSIONS = mapOf(
        "images"   to setOf("jpg", "jpeg", "png", "gif", "bmp"),
        "videos"   to setOf("mp4", "3gp", "mkv", "mov", "avi", "webm"),
        "audio"    to setOf("mp3", "m4a", "ogg", "opus", "aac", "wav", "amr"),
        "docs"     to setOf("pdf", "doc", "docx", "xls", "xlsx", "ppt", "pptx", "txt", "zip", "apk"),
        "stickers" to setOf("webp"),
    )

    fun register(engine: FlutterEngine, context: Context) {
        MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getStats"       -> result.success(getStats(context))
                    "getFiles"       -> {
                        val cat = call.argument<String>("category") ?: ""
                        result.success(getFiles(context, cat))
                    }
                    "deleteFiles"    -> {
                        @Suppress("UNCHECKED_CAST")
                        val paths = call.argument<List<String>>("paths") ?: emptyList()
                        result.success(deleteFiles(paths))
                    }
                    "deleteCategory" -> {
                        val cat = call.argument<String>("category") ?: ""
                        result.success(deleteCategory(context, cat))
                    }
                    else -> result.notImplemented()
                }
            }
    }

    // ── Data class ────────────────────────────────────────────────────────────

    private data class FileInfo(
        val path: String,
        val name: String,
        val size: Long,
        val modified: Long,
        val mimeType: String = "",
    )

    // ── File discovery ────────────────────────────────────────────────────────

    private fun categoryFiles(context: Context, category: String): List<FileInfo> {
        val isManager = Build.VERSION.SDK_INT >= Build.VERSION_CODES.R && Environment.isExternalStorageManager()
        Log.d(TAG, "categoryFiles[$category] isExternalStorageManager=$isManager SDK=${Build.VERSION.SDK_INT}")
        return when {
            Build.VERSION.SDK_INT < Build.VERSION_CODES.Q ->
                categoryFilesViaFileSystem(category)
            isManager ->
                categoryFilesViaFileSystem(category)
            else ->
                allWhatsAppFiles(context).filter { fileMatchesCategory(it, category) }
        }
    }

    /** Direct filesystem scan — works on Android 9- or when MANAGE_EXTERNAL_STORAGE is granted. */
    private fun categoryFilesViaFileSystem(category: String): List<FileInfo> {
        val dirs = CATEGORY_DIRS[category] ?: return emptyList()
        val extStorage = Environment.getExternalStorageDirectory()
        val waMediaRoots = listOf(
            "WhatsApp/Media",
            "Android/media/com.whatsapp/WhatsApp/Media",
            "Android/media/com.whatsapp.w4b/WhatsApp Business/Media",
        ).map { File(extStorage, it) }.filter { it.exists() && it.isDirectory }

        val files = mutableListOf<FileInfo>()

        // Recursively scan named subdirectories (Sent/, Private/ etc. are inside category dirs)
        for (root in waMediaRoots) {
            for (dirName in dirs) {
                val dir = File(root, dirName)
                if (dir.exists() && dir.isDirectory) {
                    dir.walkTopDown()
                        .filter { it.isFile && !it.name.startsWith(".") }
                        .forEach { files.add(FileInfo(it.absolutePath, it.name, it.length(), it.lastModified())) }
                }
            }
            // Also pick up root-level media files (e.g. UUID-named mp4s dropped directly in Media/)
            if (category == "videos") {
                root.listFiles()
                    ?.filter { it.isFile && !it.name.startsWith(".") &&
                        it.extension.lowercase() in setOf("mp4", "3gp", "mkv", "mov") }
                    ?.forEach { files.add(FileInfo(it.absolutePath, it.name, it.length(), it.lastModified())) }
            }
        }

        // Also include flat Pictures/WhatsApp/ structure
        val picturesWa = File(extStorage, "Pictures/WhatsApp")
        if (picturesWa.exists() && picturesWa.isDirectory) {
            val ext = setOf("jpg", "jpeg", "png", "gif", "webp", "bmp")
            picturesWa.listFiles()
                ?.filter { it.isFile && !it.name.startsWith(".") }
                ?.filter { f ->
                    when (category) {
                        "images" -> f.extension.lowercase() in ext
                        "videos" -> f.extension.lowercase() in setOf("mp4", "3gp", "mkv", "mov")
                        "audio"  -> f.extension.lowercase() in setOf("mp3", "m4a", "ogg", "opus", "aac")
                        else     -> false
                    }
                }
                ?.forEach { files.add(FileInfo(it.absolutePath, it.name, it.length(), it.lastModified())) }
        }

        return files
    }

    /** Fetch every file MediaStore knows about that has "WhatsApp" in its path. */
    private fun allWhatsAppFiles(context: Context): List<FileInfo> {
        val files = mutableListOf<FileInfo>()
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
                Log.d(TAG, "allWhatsAppFiles: ${cursor.count} rows found")
                val dataIdx     = cursor.getColumnIndexOrThrow(MediaStore.Files.FileColumns.DATA)
                val nameIdx     = cursor.getColumnIndexOrThrow(MediaStore.Files.FileColumns.DISPLAY_NAME)
                val sizeIdx     = cursor.getColumnIndexOrThrow(MediaStore.Files.FileColumns.SIZE)
                val modifiedIdx = cursor.getColumnIndexOrThrow(MediaStore.Files.FileColumns.DATE_MODIFIED)
                val mimeIdx     = cursor.getColumnIndexOrThrow(MediaStore.Files.FileColumns.MIME_TYPE)
                while (cursor.moveToNext()) {
                    val path = cursor.getString(dataIdx) ?: continue
                    val fileName = File(path).name
                    if (fileName.startsWith(".")) continue
                    files.add(FileInfo(
                        path     = path,
                        name     = cursor.getString(nameIdx) ?: fileName,
                        size     = cursor.getLong(sizeIdx),
                        modified = cursor.getLong(modifiedIdx) * 1000L,
                        mimeType = cursor.getString(mimeIdx) ?: "",
                    ))
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "allWhatsAppFiles failed: ${e.message}")
        }
        return files
    }

    /**
     * Categorize a file using two strategies:
     * 1. Directory name match (old WhatsApp: WhatsApp/Media/WhatsApp Images/)
     * 2. Extension/MIME fallback (new flat structure: Pictures/WhatsApp/)
     */
    private fun fileMatchesCategory(file: FileInfo, category: String): Boolean {
        val lowerPath = file.path.lowercase()
        val ext       = file.path.substringAfterLast('.', "").lowercase()
        val mime      = file.mimeType.lowercase()

        // Strategy 1: directory-name based (case-insensitive match against CATEGORY_DIRS)
        val categoryDirs = CATEGORY_DIRS[category] ?: emptyList()
        if (categoryDirs.any { lowerPath.contains(it.lowercase()) }) return true

        // Strategy 2: extension/MIME based (new flat WhatsApp structure)
        // Only apply when the file is NOT in a known WA category dir of another category
        val isInAnyKnownDir = CATEGORY_DIRS.values.flatten().any { lowerPath.contains(it) }
        if (isInAnyKnownDir) return false  // already handled by strategy 1 of correct category

        val extensions = CATEGORY_EXTENSIONS[category] ?: emptySet()
        return when {
            category == "images"  -> mime.startsWith("image/") && ext != "webp" || ext in extensions
            category == "videos"  -> mime.startsWith("video/") || ext in extensions
            category == "audio"   -> mime.startsWith("audio/") || ext in extensions
            category == "docs"    -> ext in extensions
            // webp files not in a known sticker dir are more likely shared images — skip
            category == "stickers" -> false
            else                  -> false
        }
    }

    // ── Stats / listing / deletion ────────────────────────────────────────────

    private fun getStats(context: Context): Map<String, Map<String, Long>> {
        return CATEGORY_DIRS.keys.associate { cat ->
            val files = categoryFiles(context, cat)
            val totalMb = files.sumOf { it.size } / 1024 / 1024
            Log.d(TAG, "getStats[$cat]: ${files.size} files, ${totalMb} MB")
            cat to mapOf(
                "count" to files.size.toLong(),
                "size"  to files.sumOf { it.size },
            )
        }
    }

    private fun getFiles(context: Context, category: String): List<Map<String, Any>> {
        return categoryFiles(context, category)
            .sortedByDescending { it.modified }
            .take(200)
            .map { f ->
                mapOf(
                    "path"     to f.path,
                    "name"     to f.name,
                    "size"     to f.size,
                    "modified" to f.modified,
                )
            }
    }

    private fun deleteFiles(paths: List<String>): Map<String, Long> {
        var count = 0L
        var freed = 0L
        for (path in paths) {
            val f = File(path)
            if (f.exists() && f.isFile) {
                freed += f.length()
                if (f.delete()) count++
            }
        }
        return mapOf("count" to count, "freed" to freed)
    }

    private fun deleteCategory(context: Context, category: String): Map<String, Long> {
        val files = categoryFiles(context, category)
        return deleteFiles(files.map { it.path })
    }
}
