package com.refusion.app

import android.content.Context
import android.media.MediaMetadataRetriever
import android.net.Uri

data class ResolvedMediaDisplayGeometry(
    val width: Int,
    val height: Int,
    val rotationDegrees: Int,
)

class MediaDisplayGeometryResolver(
    private val appContext: Context,
) {
    fun resolve(sourceUri: String): ResolvedMediaDisplayGeometry? {
        var retriever: MediaMetadataRetriever? = null
        return try {
            retriever = MediaMetadataRetriever()
            retriever.setDataSource(appContext, Uri.parse(sourceUri))
            val rawWidth =
                retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_WIDTH)
                    ?.toIntOrNull()
                    ?.coerceAtLeast(0) ?: 0
            val rawHeight =
                retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_HEIGHT)
                    ?.toIntOrNull()
                    ?.coerceAtLeast(0) ?: 0
            if (rawWidth <= 0 || rawHeight <= 0) {
                return null
            }
            val rotationDegrees =
                retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_ROTATION)
                    ?.toIntOrNull() ?: 0
            val normalizedRotation = ((rotationDegrees % 360) + 360) % 360
            val displayWidth =
                if (normalizedRotation == 90 || normalizedRotation == 270) {
                    rawHeight
                } else {
                    rawWidth
                }
            val displayHeight =
                if (normalizedRotation == 90 || normalizedRotation == 270) {
                    rawWidth
                } else {
                    rawHeight
                }
            ResolvedMediaDisplayGeometry(
                width = displayWidth,
                height = displayHeight,
                rotationDegrees = normalizedRotation,
            )
        } finally {
            retriever?.release()
        }
    }
}
