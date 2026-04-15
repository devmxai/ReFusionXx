package com.refusion.app

import android.content.Context
import android.graphics.Bitmap
import android.media.MediaMetadataRetriever
import android.net.Uri
import android.os.Build
import kotlin.math.roundToInt

class Stage5ScrubFrameExtractor(
    private val appContext: Context,
) {
    fun extractInto(
        store: Stage5ScrubFrameStore,
        onFrameExtracted: (Int) -> Unit = {},
    ) {
        val retriever = MediaMetadataRetriever()
        try {
            retriever.setDataSource(appContext, Uri.parse(store.request.sourceUri))
            for (index in 0 until store.frameCount) {
                val positionUs = store.frameTimeMs(index) * 1_000L
                val bitmap =
                    loadFrameBitmap(
                        retriever = retriever,
                        positionUs = positionUs,
                        targetWidth = store.request.previewWidth,
                        targetHeight = store.request.previewHeight,
                    ) ?: continue
                try {
                    store.putFrameBitmap(index, bitmap)
                    onFrameExtracted(index)
                } finally {
                    bitmap.recycle()
                }
            }
        } finally {
            retriever.release()
        }
    }

    private fun loadFrameBitmap(
        retriever: MediaMetadataRetriever,
        positionUs: Long,
        targetWidth: Int,
        targetHeight: Int,
    ): Bitmap? {
        val safeWidth = targetWidth.coerceAtLeast(1)
        val safeHeight = targetHeight.coerceAtLeast(1)
        val rawBitmap =
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
                retriever.getScaledFrameAtTime(
                    positionUs,
                    MediaMetadataRetriever.OPTION_CLOSEST,
                    safeWidth,
                    safeHeight,
                )
            } else {
                retriever.getFrameAtTime(positionUs, MediaMetadataRetriever.OPTION_CLOSEST)
            } ?: return null
        if (rawBitmap.width == safeWidth && rawBitmap.height == safeHeight) {
            return rawBitmap
        }
        val scaled =
            scaleDownBitmap(
                source = rawBitmap,
                targetWidth = safeWidth,
                targetHeight = safeHeight,
            )
        if (scaled !== rawBitmap) {
            rawBitmap.recycle()
        }
        return scaled
    }

    private fun scaleDownBitmap(
        source: Bitmap,
        targetWidth: Int,
        targetHeight: Int,
    ): Bitmap {
        if (source.width <= 0 || source.height <= 0) {
            return source
        }
        val widthScale = targetWidth.toFloat() / source.width.toFloat()
        val heightScale = targetHeight.toFloat() / source.height.toFloat()
        val scale = minOf(widthScale, heightScale).coerceAtMost(1f)
        val scaledWidth = (source.width * scale).roundToInt().coerceAtLeast(1)
        val scaledHeight = (source.height * scale).roundToInt().coerceAtLeast(1)
        if (scaledWidth == source.width && scaledHeight == source.height) {
            return source
        }
        return Bitmap.createScaledBitmap(source, scaledWidth, scaledHeight, true)
    }
}
