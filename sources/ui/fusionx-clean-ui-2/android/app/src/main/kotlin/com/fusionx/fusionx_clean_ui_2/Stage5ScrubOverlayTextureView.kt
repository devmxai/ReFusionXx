package com.refusion.app

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Matrix
import android.graphics.SurfaceTexture
import android.view.Surface
import android.view.TextureView
import kotlin.math.atan2
import kotlin.math.sqrt

class Stage5ScrubOverlayTextureView(
    context: Context,
) : TextureView(context), TextureView.SurfaceTextureListener {
    var onOutputSurfaceAvailable: (() -> Unit)? = null
    private var outputSurface: Surface? = null
    private var contentAspectRatio: Float? = null
    private var runtimeTransformMatrix3x3: List<Double>? = null
    private var runtimeOpacity: Float = 1f
    private var visibilityAlpha: Float = 1f
    private var motionCompositeSuppressed: Boolean = false

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
    fun setMotionCompositeSuppressed(suppressed: Boolean) {
        motionCompositeSuppressed = suppressed
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

    fun snapshotBitmap(): Bitmap? {
        if (!isAvailable || width <= 0 || height <= 0) {
            return null
        }
        return runCatching {
            getBitmap(width.coerceAtMost(1280), height.coerceAtMost(1280))
        }.getOrNull()
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
        // Keep aspect fitting in TextureView's texture matrix, and apply runtime
        // motion (scale/rotation/position) as a view transform. Mixing both in
        // one texture matrix can produce anisotropic stretch artifacts.
        setTransform(aspectMatrix)
        applyRuntimeViewTransform(viewWidth, viewHeight)
        alpha =
            if (motionCompositeSuppressed) {
                0f
            } else {
                (runtimeOpacity * visibilityAlpha).coerceIn(0f, 1f)
            }
    }

    private fun applyRuntimeViewTransform(
        viewWidth: Float,
        viewHeight: Float,
    ) {
        val centerX = viewWidth / 2f
        val centerY = viewHeight / 2f
        pivotX = centerX
        pivotY = centerY
        val values = runtimeTransformMatrix3x3
        if (values == null) {
            translationX = 0f
            translationY = 0f
            scaleX = 1f
            scaleY = 1f
            rotation = 0f
            return
        }
        if (values.size != 9) {
            translationX = 0f
            translationY = 0f
            scaleX = 1f
            scaleY = 1f
            rotation = 0f
            return
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
            translationX = 0f
            translationY = 0f
            scaleX = 1f
            scaleY = 1f
            rotation = 0f
            return
        }
        val derivedScaleX = sqrt((m00 * m00) + (m10 * m10))
        val derivedScaleY = sqrt((m01 * m01) + (m11 * m11))
        val derivedRotationDegrees = Math.toDegrees(atan2(m10, m00).toDouble()).toFloat()
        translationX = tx
        translationY = ty
        scaleX = if (derivedScaleX.isFinite()) derivedScaleX else 1f
        scaleY = if (derivedScaleY.isFinite()) derivedScaleY else 1f
        rotation = if (derivedRotationDegrees.isFinite()) derivedRotationDegrees else 0f
    }
}
