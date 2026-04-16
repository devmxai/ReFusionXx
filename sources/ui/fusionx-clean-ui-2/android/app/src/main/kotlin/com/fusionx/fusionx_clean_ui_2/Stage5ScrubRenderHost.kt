package com.refusion.app

import android.graphics.Bitmap
import android.view.Surface

interface Stage5ScrubRenderHost {
    fun setScrubSurfaceVisible(visible: Boolean)

    fun presentScrubFrame(bitmap: Bitmap)

    fun hasScrubOutputSurface(): Boolean = false

    fun acquireScrubOutputSurface(): Surface? = null

    fun releaseScrubOutputSurface() = Unit
}
