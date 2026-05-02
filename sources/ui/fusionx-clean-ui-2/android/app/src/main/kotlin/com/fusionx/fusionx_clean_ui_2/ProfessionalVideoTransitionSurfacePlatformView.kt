package com.refusion.app

import android.content.Context
import android.graphics.SurfaceTexture
import android.view.Surface
import android.view.TextureView
import android.view.View
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory

class ProfessionalVideoTransitionSurfacePlatformViewFactory(
    private val compositorManager: ProfessionalVideoTransitionCompositorManager,
) : PlatformViewFactory(StandardMessageCodec.INSTANCE) {
    override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
        val creationArgs = args as? Map<*, *>
        return ProfessionalVideoTransitionSurfacePlatformView(
            context = context,
            compositorManager = compositorManager,
            surfaceId = creationArgs?.get("surfaceId")?.toString().orEmpty(),
            mode = creationArgs?.get("mode")?.toString().orEmpty(),
            requestedCanvasWidth = (creationArgs?.get("canvasWidth") as? Number)?.toInt() ?: 0,
            requestedCanvasHeight = (creationArgs?.get("canvasHeight") as? Number)?.toInt() ?: 0,
        )
    }
}

private class ProfessionalVideoTransitionSurfacePlatformView(
    context: Context,
    private val compositorManager: ProfessionalVideoTransitionCompositorManager,
    private val surfaceId: String,
    private val mode: String,
    private val requestedCanvasWidth: Int,
    private val requestedCanvasHeight: Int,
) : PlatformView {
    private var surface: Surface? = null
    private var registeredSurfaceId: String? = null

    private val textureView =
        TextureView(context).apply {
            isOpaque = false
            surfaceTextureListener =
                object : TextureView.SurfaceTextureListener {
                    override fun onSurfaceTextureAvailable(
                        texture: SurfaceTexture,
                        width: Int,
                        height: Int,
                    ) {
                        registerSurface(texture, width, height)
                    }

                    override fun onSurfaceTextureSizeChanged(
                        texture: SurfaceTexture,
                        width: Int,
                        height: Int,
                    ) {
                        registerSurface(texture, width, height)
                    }

                    override fun onSurfaceTextureDestroyed(
                        texture: SurfaceTexture,
                    ): Boolean {
                        unregisterSurface()
                        return true
                    }

                    override fun onSurfaceTextureUpdated(texture: SurfaceTexture) = Unit
                }
        }

    override fun getView(): View = textureView

    override fun dispose() {
        unregisterSurface()
    }

    private fun registerSurface(
        texture: SurfaceTexture,
        width: Int,
        height: Int,
    ) {
        val safeSurfaceId = surfaceId.trim()
        if (safeSurfaceId.isBlank()) {
            return
        }
        val targetWidth = requestedCanvasWidth.takeIf { it > 0 } ?: width
        val targetHeight = requestedCanvasHeight.takeIf { it > 0 } ?: height
        if (targetWidth <= 0 || targetHeight <= 0) {
            return
        }
        if (registeredSurfaceId == safeSurfaceId && surface?.isValid == true) {
            return
        }
        unregisterSurface()
        texture.setDefaultBufferSize(targetWidth, targetHeight)
        val nextSurface = Surface(texture)
        surface = nextSurface
        compositorManager.registerInteractiveSurface(
            surfaceId = safeSurfaceId,
            width = targetWidth,
            height = targetHeight,
            surface = nextSurface,
        )
        registeredSurfaceId = safeSurfaceId
    }

    private fun unregisterSurface() {
        registeredSurfaceId?.let { registeredId ->
            compositorManager.unregisterInteractiveSurface(registeredId)
        }
        registeredSurfaceId = null
        surface?.release()
        surface = null
    }
}
