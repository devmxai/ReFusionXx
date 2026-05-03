package com.refusion.app

import android.content.Context
import android.graphics.Matrix
import android.graphics.SurfaceTexture
import android.view.Surface
import android.view.TextureView

class Stage5ScrubOverlayTextureView(
    context: Context,
) : TextureView(context), TextureView.SurfaceTextureListener {
    var onOutputSurfaceAvailable: (() -> Unit)? = null
    private var outputSurface: Surface? = null
    private var contentAspectRatio: Float? = null
    private var runtimeTransformMatrix3x3: List<Double>? = null
    private var runtimeOpacity: Float = 1f
    private var visibilityAlpha: Float = 1f

    init {
        isOpaque = false
        surfaceTextureListener = this
    }

    @Synchronized
    fun setContentAspectRatio(aspectRatio: Float?) {
        contentAspectRatio = aspectRatio?.takeIf { it > 0f }
        applyCompositeTransform()
    }

    @Synchronized
    fun setRuntimeVisualState(
        transformMatrix3x3: List<Double>?,
        opacity: Double?,
    ) {
        runtimeTransformMatrix3x3 =
            transformMatrix3x3
                ?.takeIf { it.size == 9 }
                ?.map { entry ->
                    if (entry.isFinite()) {
                        entry
                    } else {
                        0.0
                    }
                }
        runtimeOpacity =
            ((opacity ?: 1.0).coerceIn(0.0, 1.0)).toFloat()
        applyCompositeTransform()
    }

    @Synchronized
    fun setSurfaceVisibilityAlpha(alpha: Float) {
        visibilityAlpha = alpha.coerceIn(0f, 1f)
        applyCompositeTransform()
    }

    @Synchronized
    fun acquireOutputSurface(): Surface? {
        val texture = surfaceTexture ?: return null
        val currentSurface = outputSurface
        if (currentSurface != null && currentSurface.isValid) {
            return currentSurface
        }
        return Surface(texture).also { surface ->
            outputSurface = surface
        }
    }

    @Synchronized
    fun releaseOutputSurface() {
        outputSurface?.release()
        outputSurface = null
    }

    override fun onSurfaceTextureAvailable(
        surface: SurfaceTexture,
        width: Int,
        height: Int,
    ) {
        applyCompositeTransform()
        onOutputSurfaceAvailable?.invoke()
    }

    override fun onSurfaceTextureSizeChanged(
        surface: SurfaceTexture,
        width: Int,
        height: Int,
    ) {
        applyCompositeTransform()
    }

    override fun onSurfaceTextureDestroyed(surface: SurfaceTexture): Boolean {
        synchronized(this) {
            releaseOutputSurface()
        }
        return true
    }

    override fun onSurfaceTextureUpdated(surface: SurfaceTexture) = Unit

    private fun applyCompositeTransform() {
        val viewWidth = width.toFloat().coerceAtLeast(1f)
        val viewHeight = height.toFloat().coerceAtLeast(1f)
        val aspectRatio = contentAspectRatio
        val aspectMatrix =
            if (aspectRatio == null || aspectRatio <= 0f) {
                null
            } else {
                val viewAspectRatio = viewWidth / viewHeight
                val scaleX: Float
                val scaleY: Float
                if (aspectRatio > viewAspectRatio) {
                    scaleX = 1f
                    scaleY = (viewWidth / aspectRatio) / viewHeight
                } else {
                    scaleX = (viewHeight * aspectRatio) / viewWidth
                    scaleY = 1f
                }
                Matrix().apply {
                    setScale(
                        scaleX.coerceAtMost(1f),
                        scaleY.coerceAtMost(1f),
                        viewWidth / 2f,
                        viewHeight / 2f,
                    )
                }
            }
        val runtimeMatrix = runtimeMatrixForView(viewWidth, viewHeight)
        val finalMatrix =
            when {
                aspectMatrix == null && runtimeMatrix == null -> null
                aspectMatrix == null -> runtimeMatrix
                runtimeMatrix == null -> aspectMatrix
                else -> Matrix(aspectMatrix).apply { postConcat(runtimeMatrix) }
            }
        setTransform(finalMatrix)
        alpha = (runtimeOpacity * visibilityAlpha).coerceIn(0f, 1f)
    }

    private fun runtimeMatrixForView(
        viewWidth: Float,
        viewHeight: Float,
    ): Matrix? {
        val values = runtimeTransformMatrix3x3 ?: return null
        if (values.size != 9) {
            return null
        }
        val m00 = values[0].toFloat()
        val m01 = values[1].toFloat()
        val tx = values[2].toFloat()
        val m10 = values[3].toFloat()
        val m11 = values[4].toFloat()
        val ty = values[5].toFloat()
        if (!m00.isFinite() || !m01.isFinite() || !tx.isFinite() ||
            !m10.isFinite() || !m11.isFinite() || !ty.isFinite()
        ) {
            return null
        }
        val matrix = Matrix()
        val mappedValues = floatArrayOf(
            m00,
            m01,
            tx,
            m10,
            m11,
            ty,
            0f,
            0f,
            1f,
        )
        matrix.setValues(mappedValues)
        val centerX = viewWidth / 2f
        val centerY = viewHeight / 2f
        matrix.postTranslate(centerX - (m00 * centerX + m01 * centerY), centerY - (m10 * centerX + m11 * centerY))
        return matrix
    }
}
