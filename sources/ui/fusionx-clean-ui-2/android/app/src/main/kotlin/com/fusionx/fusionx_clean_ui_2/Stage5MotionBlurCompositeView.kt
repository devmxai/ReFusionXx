package com.refusion.app

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Matrix
import android.graphics.Paint
import android.graphics.RectF
import android.view.View

class Stage5MotionBlurCompositeView(
    context: Context,
) : View(context) {
    private val paint =
        Paint(Paint.ANTI_ALIAS_FLAG or Paint.FILTER_BITMAP_FLAG or Paint.DITHER_FLAG)
    private var sourceFrame: Bitmap? = null
    private var samples: List<Stage5VisualRuntimeMotionBlurSample> = emptyList()

    val currentSourceFrame: Bitmap?
        get() = sourceFrame

    val hasActiveComposite: Boolean
        get() = sourceFrame != null && samples.size > 1

    fun setSourceFrame(bitmap: Bitmap?) {
        if (bitmap == null || bitmap.isRecycled) {
            return
        }
        if (sourceFrame !== bitmap) {
            val copied = runCatching {
                bitmap.copy(Bitmap.Config.ARGB_8888, false)
            }.getOrNull()
            bitmap.recycle()
            if (copied == null) {
                clearSourceFrame()
                return
            }
            sourceFrame?.recycle()
            sourceFrame = copied
        }
        updateVisibility()
        invalidate()
    }

    fun clearSourceFrame() {
        sourceFrame?.recycle()
        sourceFrame = null
        updateVisibility()
        invalidate()
    }

    fun setMotionBlurSamples(nextSamples: List<Stage5VisualRuntimeMotionBlurSample>) {
        samples =
            nextSamples
                .filter { sample ->
                    sample.transformMatrix3x3.size == 9 &&
                        sample.transformMatrix3x3.all { value -> value.isFinite() } &&
                        sample.opacity.isFinite()
                }
                .take(64)
        updateVisibility()
        invalidate()
    }

    override fun onDetachedFromWindow() {
        sourceFrame?.recycle()
        sourceFrame = null
        super.onDetachedFromWindow()
    }

    override fun onDraw(canvas: Canvas) {
        val bitmap = sourceFrame
        if (bitmap == null || bitmap.isRecycled || samples.size <= 1) {
            return
        }
        val viewWidth = width.toFloat().coerceAtLeast(1f)
        val viewHeight = height.toFloat().coerceAtLeast(1f)
        val dst = RectF(0f, 0f, viewWidth, viewHeight)
        val sampleAlpha = (255f / samples.size.toFloat()).coerceIn(1f, 255f)
        val layerId = canvas.saveLayer(0f, 0f, viewWidth, viewHeight, null)
        samples.forEach { sample ->
            val sampleMatrix = transformMatrixForSample(
                sample = sample,
                viewWidth = viewWidth,
                viewHeight = viewHeight,
            )
            val opacity = sample.opacity.toFloat().coerceIn(0f, 1f)
            paint.alpha = (sampleAlpha * opacity).toInt().coerceIn(0, 255)
            canvas.save()
            canvas.concat(sampleMatrix)
            canvas.drawBitmap(bitmap, null, dst, paint)
            canvas.restore()
        }
        canvas.restoreToCount(layerId)
    }

    private fun transformMatrixForSample(
        sample: Stage5VisualRuntimeMotionBlurSample,
        viewWidth: Float,
        viewHeight: Float,
    ): Matrix {
        val values = sample.transformMatrix3x3
        val m00 = values[0].toFloat()
        val m01 = values[1].toFloat()
        val tx = values[2].toFloat()
        val m10 = values[3].toFloat()
        val m11 = values[4].toFloat()
        val ty = values[5].toFloat()
        val centerX = viewWidth / 2f
        val centerY = viewHeight / 2f
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

    private fun updateVisibility() {
        visibility =
            if (hasActiveComposite) {
                VISIBLE
            } else {
                INVISIBLE
            }
    }
}
