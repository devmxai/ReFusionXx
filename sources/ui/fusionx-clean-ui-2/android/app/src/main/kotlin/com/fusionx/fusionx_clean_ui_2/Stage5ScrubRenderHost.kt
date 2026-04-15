package com.refusion.app

import android.graphics.Bitmap

interface Stage5ScrubRenderHost {
    fun setScrubSurfaceVisible(visible: Boolean)

    fun presentScrubFrame(bitmap: Bitmap)
}
