package com.refusion.app

import android.content.Context
import android.graphics.SurfaceTexture
import android.view.Surface
import android.view.TextureView

class Stage5ScrubOverlayTextureView(
    context: Context,
) : TextureView(context), TextureView.SurfaceTextureListener {
    var onOutputSurfaceAvailable: (() -> Unit)? = null
    private var outputSurface: Surface? = null

    init {
        isOpaque = false
        surfaceTextureListener = this
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
        onOutputSurfaceAvailable?.invoke()
    }

    override fun onSurfaceTextureSizeChanged(
        surface: SurfaceTexture,
        width: Int,
        height: Int,
    ) = Unit

    override fun onSurfaceTextureDestroyed(surface: SurfaceTexture): Boolean {
        synchronized(this) {
            releaseOutputSurface()
        }
        return true
    }

    override fun onSurfaceTextureUpdated(surface: SurfaceTexture) = Unit
}
