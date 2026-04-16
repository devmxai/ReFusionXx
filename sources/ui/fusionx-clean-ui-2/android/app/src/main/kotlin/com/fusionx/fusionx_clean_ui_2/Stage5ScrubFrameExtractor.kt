package com.refusion.app

import android.content.Context
import android.graphics.Bitmap
import android.media.MediaMetadataRetriever
import android.net.Uri
import android.os.Build
import java.util.concurrent.ConcurrentHashMap
import kotlin.math.roundToInt

class Stage5ScrubFrameExtractor(
    private val appContext: Context,
) {
    private data class ReusableRetrieverHandle(
        var sourceUri: String? = null,
        var retriever: MediaMetadataRetriever? = null,
    )

    private val retrieverHandles = ConcurrentHashMap<Long, ReusableRetrieverHandle>()

    fun extractInto(
        store: Stage5ScrubFrameStore,
        shouldContinue: () -> Boolean = { true },
        onFrameExtracted: (Int) -> Unit = {},
    ) {
        withRetriever(store.request.sourceUri) { retriever ->
            for (index in 0 until store.frameCount) {
                if (!shouldContinue()) {
                    return@withRetriever
                }
                extractIndexInto(
                    retriever = retriever,
                    store = store,
                    index = index,
                    shouldContinue = shouldContinue,
                    onFrameExtracted = onFrameExtracted,
                )
            }
        }
    }

    fun extractIndices(
        store: Stage5ScrubFrameStore,
        indices: Iterable<Int>,
        shouldContinue: () -> Boolean = { true },
        onFrameExtracted: (Int) -> Unit = {},
    ) {
        withRetriever(store.request.sourceUri) { retriever ->
            indices
                .distinct()
                .filter { index -> index in 0 until store.frameCount }
                .forEach { index ->
                    if (!shouldContinue()) {
                        return@withRetriever
                    }
                    extractIndexInto(
                        retriever = retriever,
                        store = store,
                        index = index,
                        shouldContinue = shouldContinue,
                        onFrameExtracted = onFrameExtracted,
                    )
                }
        }
    }

    fun release() {
        retrieverHandles.values.forEach { handle ->
            synchronized(handle) {
                handle.retriever?.release()
                handle.retriever = null
                handle.sourceUri = null
            }
        }
        retrieverHandles.clear()
    }

    private inline fun withRetriever(
        sourceUri: String,
        block: (MediaMetadataRetriever) -> Unit,
    ) {
        val threadId = Thread.currentThread().id
        val handle =
            retrieverHandles.getOrPut(threadId) {
                ReusableRetrieverHandle()
            }
        synchronized(handle) {
            var retriever = handle.retriever
            if (retriever == null || handle.sourceUri != sourceUri) {
                retriever?.release()
                retriever =
                    MediaMetadataRetriever().apply {
                        setDataSource(appContext, Uri.parse(sourceUri))
                    }
                handle.retriever = retriever
                handle.sourceUri = sourceUri
            }
            block(retriever)
        }
    }

    private fun extractIndexInto(
        retriever: MediaMetadataRetriever,
        store: Stage5ScrubFrameStore,
        index: Int,
        shouldContinue: () -> Boolean,
        onFrameExtracted: (Int) -> Unit,
    ) {
        if (store.hasFrame(index)) {
            return
        }
        val positionUs = store.frameTimeMs(index) * 1_000L
        val bitmap =
            loadFrameBitmap(
                retriever = retriever,
                positionUs = positionUs,
                targetWidth = store.request.previewWidth,
                targetHeight = store.request.previewHeight,
            ) ?: return
        try {
            if (!shouldContinue()) {
                return
            }
            store.putFrameBitmap(index, bitmap)
            onFrameExtracted(index)
        } finally {
            bitmap.recycle()
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
