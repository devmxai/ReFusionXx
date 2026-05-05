package com.refusion.app

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BlendMode
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Matrix
import android.graphics.Paint
import android.graphics.PorterDuff
import android.graphics.PorterDuffXfermode
import android.graphics.RectF
import android.media.MediaMetadataRetriever
import android.net.Uri
import android.os.Build
import android.view.Surface
import kotlin.math.roundToInt

class Stage5TemporalMotionBlurRenderer(
    private val context: Context,
) {
    private val retrievers =
        object : LinkedHashMap<String, MediaMetadataRetriever>(4, 0.75f, true) {
            override fun removeEldestEntry(
                eldest: MutableMap.MutableEntry<String, MediaMetadataRetriever>,
            ): Boolean {
                if (size <= MAX_RETRIEVER_CACHE_SIZE) {
                    return false
                }
                runCatching { eldest.value.release() }
                return true
            }
        }
    private val paint =
        Paint(Paint.ANTI_ALIAS_FLAG or Paint.FILTER_BITMAP_FLAG or Paint.DITHER_FLAG)

    @Synchronized
    fun render(
        playbackUri: String,
        descriptor: Stage5NativeScrubSourceDescriptor,
        visualState: Stage5VisualRuntimeSurfaceState,
        samples: List<Stage5VisualRuntimeMotionBlurSample>,
        outputSurface: Surface,
    ): Boolean {
        if (playbackUri.isBlank() || !outputSurface.isValid || samples.size <= 1) {
            return false
        }
        val safeSamples =
            samples
                .filter { sample ->
                    sample.transformMatrix3x3.size == 9 &&
                        sample.transformMatrix3x3.all { it.isFinite() } &&
                        sample.opacity.isFinite()
                }
                .take(visualState.motionBlurPolicy?.adaptiveSampleLimit?.coerceIn(2, 64) ?: 16)
        if (safeSamples.size <= 1) {
            return false
        }
        val canvas =
            runCatching {
                outputSurface.lockCanvas(null)
            }.getOrNull() ?: return false
        return try {
            val drawnSampleCount = drawTemporalSamples(
                canvas = canvas,
                playbackUri = playbackUri,
                descriptor = descriptor,
                samples = safeSamples,
            )
            drawnSampleCount > 0
        } catch (_: Throwable) {
            false
        } finally {
            runCatching {
                outputSurface.unlockCanvasAndPost(canvas)
            }
        }
    }

    @Synchronized
    fun release() {
        retrievers.values.forEach { retriever ->
            runCatching { retriever.release() }
        }
        retrievers.clear()
    }

    private fun drawTemporalSamples(
        canvas: Canvas,
        playbackUri: String,
        descriptor: Stage5NativeScrubSourceDescriptor,
        samples: List<Stage5VisualRuntimeMotionBlurSample>,
    ): Int {
        val canvasWidth = canvas.width.coerceAtLeast(1)
        val canvasHeight = canvas.height.coerceAtLeast(1)
        canvas.drawColor(Color.BLACK, PorterDuff.Mode.SRC)
        configureAdditiveBlendPaint()
        return try {
            val sampleWeight = 1f / samples.size.toFloat().coerceAtLeast(1f)
            var drawnSampleCount = 0
            samples.forEach { sample ->
                val sourcePositionMs = descriptor.resolveSourcePositionMs(sample.timelineTimeMs)
                val frame =
                    frameAt(
                        playbackUri = playbackUri,
                        positionMs = sourcePositionMs,
                        canvasWidth = canvasWidth,
                        canvasHeight = canvasHeight,
                        descriptor = descriptor,
                    ) ?: return@forEach
                try {
                    val opacity = sample.opacity.toFloat().coerceIn(0f, 1f)
                    paint.alpha =
                        (255f * sampleWeight * opacity)
                            .roundToInt()
                            .coerceIn(0, 255)
                    val sampleMatrix =
                        transformMatrixForSample(
                            sample = sample,
                            canvasWidth = canvasWidth.toFloat(),
                            canvasHeight = canvasHeight.toFloat(),
                        )
                    val dst = fittedDestinationRect(
                        bitmap = frame,
                        canvasWidth = canvasWidth.toFloat(),
                        canvasHeight = canvasHeight.toFloat(),
                        descriptor = descriptor,
                    )
                    canvas.save()
                    canvas.concat(sampleMatrix)
                    canvas.drawBitmap(frame, null, dst, paint)
                    canvas.restore()
                    drawnSampleCount += 1
                } finally {
                    frame.recycle()
                }
            }
            drawnSampleCount
        } finally {
            clearBlendMode()
        }
    }

    private fun frameAt(
        playbackUri: String,
        positionMs: Long,
        canvasWidth: Int,
        canvasHeight: Int,
        descriptor: Stage5NativeScrubSourceDescriptor,
    ): Bitmap? {
        val retriever = retrieverFor(playbackUri) ?: return null
        val timeUs = positionMs.coerceAtLeast(0L) * 1000L
        val scaledSize =
            scaledFrameSize(
                descriptor = descriptor,
                canvasWidth = canvasWidth,
                canvasHeight = canvasHeight,
            )
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1 && scaledSize != null) {
            runCatching {
                retriever.getScaledFrameAtTime(
                    timeUs,
                    MediaMetadataRetriever.OPTION_CLOSEST,
                    scaledSize.first,
                    scaledSize.second,
                )
            }.getOrNull()
        } else {
            runCatching {
                retriever.getFrameAtTime(
                    timeUs,
                    MediaMetadataRetriever.OPTION_CLOSEST,
                )
            }.getOrNull()
        }
    }

    private fun scaledFrameSize(
        descriptor: Stage5NativeScrubSourceDescriptor,
        canvasWidth: Int,
        canvasHeight: Int,
    ): Pair<Int, Int>? {
        val aspectRatio =
            descriptor.sourceAspectRatio()?.takeIf { it.isFinite() && it > 0f }
                ?: return null
        val canvasAspectRatio = canvasWidth.toFloat() / canvasHeight.toFloat().coerceAtLeast(1f)
        val width: Int
        val height: Int
        if (aspectRatio > canvasAspectRatio) {
            width = canvasWidth
            height = (canvasWidth / aspectRatio).roundToInt().coerceAtLeast(1)
        } else {
            height = canvasHeight
            width = (canvasHeight * aspectRatio).roundToInt().coerceAtLeast(1)
        }
        return width.coerceAtLeast(1) to height.coerceAtLeast(1)
    }

    private fun fittedDestinationRect(
        bitmap: Bitmap,
        canvasWidth: Float,
        canvasHeight: Float,
        descriptor: Stage5NativeScrubSourceDescriptor,
    ): RectF {
        val aspectRatio =
            descriptor.sourceAspectRatio()?.takeIf { it.isFinite() && it > 0f }
                ?: (bitmap.width.toFloat() / bitmap.height.toFloat().coerceAtLeast(1f))
        val canvasAspectRatio = canvasWidth / canvasHeight.coerceAtLeast(1f)
        val width: Float
        val height: Float
        if (aspectRatio > canvasAspectRatio) {
            width = canvasWidth
            height = canvasWidth / aspectRatio
        } else {
            height = canvasHeight
            width = canvasHeight * aspectRatio
        }
        val left = (canvasWidth - width) / 2f
        val top = (canvasHeight - height) / 2f
        return RectF(left, top, left + width, top + height)
    }

    private fun transformMatrixForSample(
        sample: Stage5VisualRuntimeMotionBlurSample,
        canvasWidth: Float,
        canvasHeight: Float,
    ): Matrix {
        val values = sample.transformMatrix3x3
        val m00 = values[0].toFloat()
        val m01 = values[1].toFloat()
        val tx = values[2].toFloat()
        val m10 = values[3].toFloat()
        val m11 = values[4].toFloat()
        val ty = values[5].toFloat()
        val centerX = canvasWidth / 2f
        val centerY = canvasHeight / 2f
        return Matrix().apply {
            setValues(
                floatArrayOf(
                    m00,
                    m01,
                    tx,
                    m10,
                    m11,
                    ty,
                    0f,
                    0f,
                    1f,
                ),
            )
            postTranslate(
                centerX - (m00 * centerX + m01 * centerY),
                centerY - (m10 * centerX + m11 * centerY),
            )
        }
    }

    private fun retrieverFor(playbackUri: String): MediaMetadataRetriever? {
        retrievers[playbackUri]?.let { return it }
        val retriever = MediaMetadataRetriever()
        val configured =
            runCatching {
                retriever.setDataSource(context, Uri.parse(playbackUri))
            }.isSuccess ||
                runCatching {
                    retriever.setDataSource(playbackUri.removePrefix("file://"))
                }.isSuccess
        if (!configured) {
            runCatching { retriever.release() }
            return null
        }
        retrievers[playbackUri] = retriever
        return retriever
    }

    private fun configureAdditiveBlendPaint() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            paint.blendMode = BlendMode.PLUS
            paint.xfermode = null
        } else {
            paint.xfermode = PorterDuffXfermode(PorterDuff.Mode.ADD)
        }
    }

    private fun clearBlendMode() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            paint.blendMode = null
        }
        paint.xfermode = null
        paint.alpha = 255
    }

    private companion object {
        const val MAX_RETRIEVER_CACHE_SIZE = 4
    }
}
