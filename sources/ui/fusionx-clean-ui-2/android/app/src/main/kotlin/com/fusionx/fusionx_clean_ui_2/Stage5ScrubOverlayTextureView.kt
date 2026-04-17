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

    init {
        isOpaque = false
        surfaceTextureListener = this
    }

    @Synchronized
    fun setContentAspectRatio(aspectRatio: Float?) {
        contentAspectRatio = aspectRatio?.takeIf { it > 0f }
        applyAspectTransform()
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
        applyAspectTransform()
        onOutputSurfaceAvailable?.invoke()
    }

    override fun onSurfaceTextureSizeChanged(
        surface: SurfaceTexture,
        width: Int,
        height: Int,
    ) {
        applyAspectTransform()
    }

    override fun onSurfaceTextureDestroyed(surface: SurfaceTexture): Boolean {
        synchronized(this) {
            releaseOutputSurface()
        }
        return true
    }

    override fun onSurfaceTextureUpdated(surface: SurfaceTexture) = Unit

    private fun applyAspectTransform() {
        val viewWidth = width.toFloat().coerceAtLeast(1f)
        val viewHeight = height.toFloat().coerceAtLeast(1f)
        val aspectRatio = contentAspectRatio
        if (aspectRatio == null || aspectRatio <= 0f) {
            setTransform(null)
            return
        }
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
        val matrix = Matrix().apply {
            setScale(
                scaleX.coerceAtMost(1f),
                scaleY.coerceAtMost(1f),
                viewWidth / 2f,
                viewHeight / 2f,
            )
        }
        setTransform(matrix)
    }
}
