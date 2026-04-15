package com.refusion.app

import android.graphics.Bitmap

class Stage5NativeScrubEngine(
    private val scrubPreparationManager: Stage5ScrubPreparationManager,
) {
    private val renderHosts = LinkedHashSet<Stage5ScrubRenderHost>()
    private var activeStoreKey: String? = null
    private var latestFrameIndex: Int? = null

    @Synchronized
    fun registerRenderHost(host: Stage5ScrubRenderHost) {
        renderHosts.add(host)
        val latestBitmap = resolveLatestBitmap()
        val hasScrubSurface = activeStoreKey != null && latestBitmap != null
        host.setScrubSurfaceVisible(hasScrubSurface)
        latestBitmap?.let(host::presentScrubFrame)
    }

    @Synchronized
    fun unregisterRenderHost(host: Stage5ScrubRenderHost) {
        renderHosts.remove(host)
    }

    @Synchronized
    fun ensureTexture(
        targetWidth: Int,
        targetHeight: Int,
    ): Long? = null

    @Synchronized
    fun currentTextureId(): Long? = null

    @Synchronized
    fun beginSession(
        scrubStoreKey: String,
        positionMs: Long,
        @Suppress("UNUSED_PARAMETER") targetWidth: Int,
        @Suppress("UNUSED_PARAMETER") targetHeight: Int,
    ) {
        activeStoreKey = scrubStoreKey
        latestFrameIndex = null
        renderHosts.forEach { host ->
            host.setScrubSurfaceVisible(true)
        }
        renderFrame(
            scrubStoreKey = scrubStoreKey,
            positionMs = positionMs,
        )
    }

    @Synchronized
    fun updateTarget(
        scrubStoreKey: String,
        positionMs: Long,
        @Suppress("UNUSED_PARAMETER") targetWidth: Int,
        @Suppress("UNUSED_PARAMETER") targetHeight: Int,
    ) {
        if (activeStoreKey != scrubStoreKey) {
            beginSession(
                scrubStoreKey = scrubStoreKey,
                positionMs = positionMs,
                targetWidth = targetWidth,
                targetHeight = targetHeight,
            )
            return
        }
        renderFrame(
            scrubStoreKey = scrubStoreKey,
            positionMs = positionMs,
        )
    }

    @Synchronized
    fun endSession() {
        activeStoreKey = null
        latestFrameIndex = null
        renderHosts.forEach { host ->
            host.setScrubSurfaceVisible(false)
        }
    }

    @Synchronized
    fun clearTexture() {
        renderHosts.forEach { host ->
            host.setScrubSurfaceVisible(false)
        }
    }

    @Synchronized
    fun disposeTexture() {
        endSession()
    }

    @Synchronized
    fun release() {
        endSession()
        renderHosts.clear()
    }

    private fun renderFrame(
        scrubStoreKey: String,
        positionMs: Long,
    ) {
        val store = scrubPreparationManager.getStore(scrubStoreKey) ?: return
        val frameIndex = store.resolveFrameIndex(positionMs)
        val bitmap = store.getFrameBitmap(frameIndex) ?: return
        latestFrameIndex = frameIndex
        renderHosts.forEach { host ->
            host.presentScrubFrame(bitmap)
            host.setScrubSurfaceVisible(true)
        }
    }

    private fun resolveLatestBitmap(): Bitmap? {
        val storeKey = activeStoreKey ?: return null
        val frameIndex = latestFrameIndex ?: return null
        val store = scrubPreparationManager.getStore(storeKey) ?: return null
        return store.getFrameBitmap(frameIndex)
    }
}
