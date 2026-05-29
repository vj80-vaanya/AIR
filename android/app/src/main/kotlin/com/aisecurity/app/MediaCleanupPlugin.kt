package com.aisecurity.app

import android.content.Context
import android.os.Build
import android.os.Environment
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

object MediaCleanupPlugin {

    private const val CHANNEL = "ai_security/media_cleanup"

    // Known WhatsApp media root paths (both legacy and scoped-storage paths)
    private val WA_ROOTS = listOf(
        "WhatsApp/Media",
        "Android/media/com.whatsapp/WhatsApp/Media",
        "Android/media/com.whatsapp.w4b/WhatsApp Business/Media",
    )

    private val CATEGORY_DIRS = mapOf(
        "images"  to listOf("WhatsApp Images", "WhatsApp Animated Gifs"),
        "videos"  to listOf("WhatsApp Video"),
        "audio"   to listOf("WhatsApp Audio", "WhatsApp Voice Notes", "WhatsApp Music"),
        "docs"    to listOf("WhatsApp Documents"),
        "stickers" to listOf("WhatsApp Stickers"),
    )

    fun register(engine: FlutterEngine, context: Context) {
        MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getStats"      -> result.success(getStats(context))
                    "getFiles"      -> {
                        val cat = call.argument<String>("category") ?: ""
                        result.success(getFiles(context, cat))
                    }
                    "deleteFiles"   -> {
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

    // ── Helpers ──────────────────────────────────────────────────────────────

    private fun waRootFiles(context: Context): List<File> {
        val extStorage = Environment.getExternalStorageDirectory()
        return WA_ROOTS.map { File(extStorage, it) }.filter { it.exists() && it.isDirectory }
    }

    private fun categoryFiles(context: Context, category: String): List<File> {
        val dirs = CATEGORY_DIRS[category] ?: return emptyList()
        val roots = waRootFiles(context)
        val files = mutableListOf<File>()
        for (root in roots) {
            for (dirName in dirs) {
                val dir = File(root, dirName)
                if (dir.exists() && dir.isDirectory) {
                    dir.listFiles()
                        ?.filter { it.isFile && !it.name.startsWith(".") }
                        ?.let { files.addAll(it) }
                }
            }
        }
        return files
    }

    private fun getStats(context: Context): Map<String, Map<String, Long>> {
        return CATEGORY_DIRS.keys.associate { cat ->
            val files = categoryFiles(context, cat)
            cat to mapOf(
                "count" to files.size.toLong(),
                "size"  to files.sumOf { it.length() },
            )
        }
    }

    private fun getFiles(context: Context, category: String): List<Map<String, Any>> {
        return categoryFiles(context, category)
            .sortedByDescending { it.lastModified() }
            .take(200) // cap to avoid huge payloads
            .map { f ->
                mapOf(
                    "path"     to f.absolutePath,
                    "name"     to f.name,
                    "size"     to f.length(),
                    "modified" to f.lastModified(),
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
        return deleteFiles(files.map { it.absolutePath })
    }
}
