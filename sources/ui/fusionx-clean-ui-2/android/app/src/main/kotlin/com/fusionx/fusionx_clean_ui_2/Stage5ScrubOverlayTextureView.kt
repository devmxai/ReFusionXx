package com.refusion.app

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.PorterDuff
import android.graphics.SurfaceTexture
import android.view.Surface
import android.view.TextureView

class Stage5ScrubOverlayTextureView(
    context: Context,
) : TextureView(context), TextureView.SurfaceTextureListener {
    var onOutputSurfaceAvailable: (() -> Unit)? = null
    private val paint = Paint(Paint.ANTI_ALIAS_FLAG or Paint.FILTER_BITMAP_FLAG)
    private var latestBitmap: Bitmap? = null
    private var outputSurface: Surface? = null

    init {
        isOpaque = false
        surfaceTextureListener = this
    }

    @Synchronized
    fun presentFrame(bitmap: Bitmap) {
        latestBitmap = bitmap
        if (isAvailable) {
            drawLatestBitmap()
        }
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
        synchronized(this) {
            drawLatestBitmap()
        }
        onOutputSurfaceAvailable?.invoke()
    }

    override fun onSurfaceTextureSizeChanged(
        surface: SurfaceTexture,
        width: Int,
        height: Int,
    ) {
        synchronized(this) {
            drawLatestBitmap()
        }
    }

    override fun onSurfaceTextureDestroyed(surface: SurfaceTexture): Boolean {
        synchronized(this) {
            releaseOutputSurface()
        }
        return true
    }

    override fun onSurfaceTextureUpdated(surface: SurfaceTexture) = Unit

    private fun drawLatestBitmap() {
        val bitmap = latestBitmap ?: return
        val canvas = lockCanvas() ?: return
        try {
            drawBitmap(canvas, bitmap)
        } finally {
            unlockCanvasAndPost(canvas)
        }
    }

    private fun drawBitmap(
        canvas: Canvas,
        bitmap: Bitmap,
    ) {
        canvas.drawColor(Color.TRANSPARENT, PorterDuff.Mode.CLEAR)
        val left = 0f
        val top = 0f
        val width = width.toFloat().coerceAtLeast(1f)
        val height = height.toFloat().coerceAtLeast(1f)
        val bitmapAspect = bitmap.width.toFloat() / bitmap.height.toFloat().coerceAtLeast(1f)
        val viewAspect = width / height
        val destLeft: Float
        val destTop: Float
        val destRight: Float
        val destBottom: Float
        if (bitmapAspect > viewAspect) {
            val scaledHeight = width / bitmapAspect
            destLeft = left
            destRight = width
            destTop = (height - scaledHeight) / 2f
            destBottom = destTop + scaledHeight
        } else {
            val scaledWidth = height * bitmapAspect
            destTop = top
            destBottom = height
            destLeft = (width - scaledWidth) / 2f
            destRight = destLeft + scaledWidth
        }
        canvas.drawBitmap(
            bitmap,
            null,
            android.graphics.RectF(destLeft, destTop, destRight, destBottom),
            paint,
        )
    }
}
