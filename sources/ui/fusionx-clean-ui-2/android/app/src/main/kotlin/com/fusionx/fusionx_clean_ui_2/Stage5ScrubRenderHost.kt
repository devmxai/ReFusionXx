package com.refusion.app

import android.view.Surface

interface Stage5ScrubRenderHost {
    fun setScrubSurfaceVisible(visible: Boolean)

    fun hasScrubOutputSurface(): Boolean = false

    fun acquireScrubOutputSurface(): Surface? = null

    fun releaseScrubOutputSurface() = Unit
}
