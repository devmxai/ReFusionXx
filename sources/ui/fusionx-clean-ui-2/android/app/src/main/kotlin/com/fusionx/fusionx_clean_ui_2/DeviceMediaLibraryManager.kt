package com.fusionx.fusionx_clean_ui_2

import android.content.ContentUris
import android.content.Context
import android.provider.MediaStore

class DeviceMediaLibraryManager(
    context: Context,
) {
    private val appContext = context.applicationContext

    fun queryMediaPage(
        tab: String,
        offset: Int,
        limit: Int,
    ): Map<String, Any?> =
        when (tab) {
            "image" -> queryImages(offset = offset, limit = limit)
            else -> queryVideos(offset = offset, limit = limit)
        }

    fun queryMedia(tab: String): List<Map<String, Any?>> =
        when (tab) {
            "image" -> itemsFromPage(queryImages(offset = 0, limit = 60))
            else -> itemsFromPage(queryVideos(offset = 0, limit = 60))
        }

    private fun itemsFromPage(page: Map<String, Any?>): List<Map<String, Any?>> =
        (page["items"] as? List<*>)?.mapNotNull { entry ->
            val mapEntry = entry as? Map<*, *> ?: return@mapNotNull null
            mapEntry.entries.associate { (key, value) -> key.toString() to value }
        } ?: emptyList()

    private fun queryVideos(offset: Int, limit: Int): Map<String, Any?> {
        val projection =
            arrayOf(
                MediaStore.Video.Media._ID,
                MediaStore.Video.Media.DISPLAY_NAME,
                MediaStore.Video.Media.DURATION,
                MediaStore.Video.Media.WIDTH,
                MediaStore.Video.Media.HEIGHT,
                MediaStore.Video.Media.DATE_ADDED,
            )
        val items = mutableListOf<Map<String, Any?>>()
        val safeOffset = offset.coerceAtLeast(0)
        val safeLimit = limit.coerceIn(1, 60)
        val sortOrder =
            "${MediaStore.Video.Media.DATE_ADDED} DESC, ${MediaStore.Video.Media._ID} DESC"
        val cursor =
            appContext.contentResolver.query(
                MediaStore.Video.Media.EXTERNAL_CONTENT_URI,
                projection,
                null,
                null,
                sortOrder,
            )
        cursor?.use { resultCursor ->
            val idIndex = resultCursor.getColumnIndexOrThrow(MediaStore.Video.Media._ID)
            val nameIndex = resultCursor.getColumnIndexOrThrow(MediaStore.Video.Media.DISPLAY_NAME)
            val durationIndex = resultCursor.getColumnIndexOrThrow(MediaStore.Video.Media.DURATION)
            val widthIndex = resultCursor.getColumnIndexOrThrow(MediaStore.Video.Media.WIDTH)
            val heightIndex = resultCursor.getColumnIndexOrThrow(MediaStore.Video.Media.HEIGHT)
            val dateAddedIndex =
                resultCursor.getColumnIndexOrThrow(MediaStore.Video.Media.DATE_ADDED)
            if (safeOffset > 0 && !resultCursor.moveToPosition(safeOffset - 1)) {
                return mapOf(
                    "items" to emptyList<Map<String, Any?>>(),
                    "nextOffset" to safeOffset,
                    "hasMore" to false,
                )
            }
            while (resultCursor.moveToNext() && items.size < safeLimit) {
                val id = resultCursor.getLong(idIndex)
                val contentUri =
                    ContentUris.withAppendedId(MediaStore.Video.Media.EXTERNAL_CONTENT_URI, id)
                items.add(
                    mapOf(
                        "id" to "video-$id",
                        "tab" to "video",
                        "label" to resultCursor.getString(nameIndex).orEmpty().ifBlank { "Video $id" },
                        "sourceUri" to contentUri.toString(),
                        "durationMs" to resultCursor.getLong(durationIndex),
                        "width" to resultCursor.getInt(widthIndex),
                        "height" to resultCursor.getInt(heightIndex),
                        "dateAddedSeconds" to resultCursor.getLong(dateAddedIndex),
                    ),
                )
            }
            val hasMore = resultCursor.position < resultCursor.count - 1
            return mapOf(
                "items" to items,
                "nextOffset" to safeOffset + items.size,
                "hasMore" to hasMore,
            )
        }
        return mapOf(
            "items" to items,
            "nextOffset" to safeOffset + items.size,
            "hasMore" to false,
        )
    }

    private fun queryImages(offset: Int, limit: Int): Map<String, Any?> {
        val projection =
            arrayOf(
                MediaStore.Images.Media._ID,
                MediaStore.Images.Media.DISPLAY_NAME,
                MediaStore.Images.Media.WIDTH,
                MediaStore.Images.Media.HEIGHT,
                MediaStore.Images.Media.DATE_ADDED,
            )
        val items = mutableListOf<Map<String, Any?>>()
        val safeOffset = offset.coerceAtLeast(0)
        val safeLimit = limit.coerceIn(1, 60)
        val sortOrder =
            "${MediaStore.Images.Media.DATE_ADDED} DESC, ${MediaStore.Images.Media._ID} DESC"
        val cursor =
            appContext.contentResolver.query(
                MediaStore.Images.Media.EXTERNAL_CONTENT_URI,
                projection,
                null,
                null,
                sortOrder,
            )
        cursor?.use { resultCursor ->
            val idIndex = resultCursor.getColumnIndexOrThrow(MediaStore.Images.Media._ID)
            val nameIndex = resultCursor.getColumnIndexOrThrow(MediaStore.Images.Media.DISPLAY_NAME)
            val widthIndex = resultCursor.getColumnIndexOrThrow(MediaStore.Images.Media.WIDTH)
            val heightIndex = resultCursor.getColumnIndexOrThrow(MediaStore.Images.Media.HEIGHT)
            val dateAddedIndex =
                resultCursor.getColumnIndexOrThrow(MediaStore.Images.Media.DATE_ADDED)
            if (safeOffset > 0 && !resultCursor.moveToPosition(safeOffset - 1)) {
                return mapOf(
                    "items" to emptyList<Map<String, Any?>>(),
                    "nextOffset" to safeOffset,
                    "hasMore" to false,
                )
            }
            while (resultCursor.moveToNext() && items.size < safeLimit) {
                val id = resultCursor.getLong(idIndex)
                val contentUri =
                    ContentUris.withAppendedId(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, id)
                items.add(
                    mapOf(
                        "id" to "image-$id",
                        "tab" to "image",
                        "label" to resultCursor.getString(nameIndex).orEmpty().ifBlank { "Image $id" },
                        "sourceUri" to contentUri.toString(),
                        "durationMs" to 0L,
                        "width" to resultCursor.getInt(widthIndex),
                        "height" to resultCursor.getInt(heightIndex),
                        "dateAddedSeconds" to resultCursor.getLong(dateAddedIndex),
                    ),
                )
            }
            val hasMore = resultCursor.position < resultCursor.count - 1
            return mapOf(
                "items" to items,
                "nextOffset" to safeOffset + items.size,
                "hasMore" to hasMore,
            )
        }
        return mapOf(
            "items" to items,
            "nextOffset" to safeOffset + items.size,
            "hasMore" to false,
        )
    }
}
