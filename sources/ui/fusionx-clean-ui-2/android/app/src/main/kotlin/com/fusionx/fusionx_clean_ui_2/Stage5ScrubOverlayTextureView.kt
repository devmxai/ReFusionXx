package com.refusion.app

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.SurfaceTexture
import android.view.TextureView

class Stage5ScrubOverlayTextureView(
    context: Context,
) : TextureView(context), TextureView.SurfaceTextureListener {
    private val paint = Paint(Paint.ANTI_ALIAS_FLAG or Paint.FILTER_BITMAP_FLAG)
    private var latestBitmap: Bitmap? = null

    init {
        isOpaque = false
        surfaceTextureListener = this
    }

    fun presentFrame(bitmap: Bitmap) {
        latestBitmap = bitmap
        if (isAvailable) {
            drawLatestBitmap()
        }
    }

    override fun onSurfaceTextureAvailable(
        surface: SurfaceTexture,
        width: Int,
        height: Int,
    ) {
        drawLatestBitmap()
    }

    override fun onSurfaceTextureSizeChanged(
        surface: SurfaceTexture,
        width: Int,
        height: Int,
    ) {
        drawLatestBitmap()
    }

    override fun onSurfaceTextureDestroyed(surface: SurfaceTexture): Boolean = true

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
        canvas.drawColor(Color.BLACK)
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
