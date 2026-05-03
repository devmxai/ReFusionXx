package com.refusion.app

import android.view.Surface

interface Stage5ScrubRenderHost {
    fun setScrubSurfaceVisible(visible: Boolean)

    fun setScrubContentAspectRatio(aspectRatio: Float?) = Unit

    fun setScrubVisualState(
        transformMatrix3x3: List<Double>?,
        opacity: Double?,
    ) = Unit

    fun hasScrubOutputSurface(): Boolean = false

    fun acquireScrubOutputSurface(): Surface? = null

    fun releaseScrubOutputSurface() = Unit
}
