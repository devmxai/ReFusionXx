package com.refusion.app

import android.graphics.Bitmap
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

class Stage5NativeScrubEngine(
    private val scrubPreparationManager: Stage5ScrubPreparationManager,
) {
    companion object {
        private const val PRIORITY_EXTRACTION_RADIUS_FRAMES = 25
        private const val NEAREST_READY_MAX_DISTANCE = 2
        private const val RENDER_LOOP_RETRY_DELAY_MS = 8L
    }

    private val renderHosts = LinkedHashSet<Stage5ScrubRenderHost>()
    private val renderExecutor: ExecutorService = Executors.newSingleThreadExecutor()
    private var activeStoreKey: String? = null
    private var latestFrameIndex: Int? = null
    private var latestTargetPositionMs: Long? = null
    private var lastExtractionRequestStoreKey: String? = null
    private var lastExtractionRequestFrameIndex: Int? = null
    private var targetGeneration: Long = 0
    private var renderLoopRunning = false

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
    @Suppress("UNUSED_PARAMETER")
    fun ensureTexture(
        targetWidth: Int,
        targetHeight: Int,
    ): Long? = null

    @Synchronized
    fun currentTextureId(): Long? = null

    @Synchronized
    @Suppress("UNUSED_PARAMETER")
    fun beginSession(
        scrubStoreKey: String,
        positionMs: Long,
        targetWidth: Int,
        targetHeight: Int,
    ): Boolean {
        activeStoreKey = scrubStoreKey
        latestFrameIndex = null
        latestTargetPositionMs = positionMs
        lastExtractionRequestStoreKey = null
        lastExtractionRequestFrameIndex = null
        targetGeneration += 1
        requestExtractionForTargetLocked(
            scrubStoreKey = scrubStoreKey,
            positionMs = positionMs,
        )
        scheduleRenderLoopLocked()
        return latestFrameIndex != null
    }

    @Synchronized
    @Suppress("UNUSED_PARAMETER")
    fun updateTarget(
        scrubStoreKey: String,
        positionMs: Long,
        targetWidth: Int,
        targetHeight: Int,
    ): Boolean {
        if (activeStoreKey != scrubStoreKey) {
            return beginSession(
                scrubStoreKey = scrubStoreKey,
                positionMs = positionMs,
                targetWidth = targetWidth,
                targetHeight = targetHeight,
            )
        }
        latestTargetPositionMs = positionMs
        targetGeneration += 1
        requestExtractionForTargetLocked(
            scrubStoreKey = scrubStoreKey,
            positionMs = positionMs,
        )
        scheduleRenderLoopLocked()
        return latestFrameIndex != null
    }

    @Synchronized
    fun endSession() {
        activeStoreKey = null
        latestFrameIndex = null
        latestTargetPositionMs = null
        lastExtractionRequestStoreKey = null
        lastExtractionRequestFrameIndex = null
        targetGeneration += 1
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
        renderExecutor.shutdownNow()
    }

    @Synchronized
    private fun scheduleRenderLoopLocked() {
        if (renderLoopRunning || activeStoreKey == null || latestTargetPositionMs == null) {
            return
        }
        renderLoopRunning = true
        renderExecutor.execute(::runRenderLoop)
    }

    private fun runRenderLoop() {
        while (true) {
            val snapshot =
                synchronized(this) {
                    val storeKey = activeStoreKey
                    val positionMs = latestTargetPositionMs
                    if (storeKey == null || positionMs == null) {
                        renderLoopRunning = false
                        return
                    }
                    RenderSnapshot(
                        scrubStoreKey = storeKey,
                        positionMs = positionMs,
                        generation = targetGeneration,
                    )
                }

            val shouldContinue =
                performRenderPass(
                    scrubStoreKey = snapshot.scrubStoreKey,
                    positionMs = snapshot.positionMs,
                )

            synchronized(this) {
                val sessionActive =
                    activeStoreKey != null && latestTargetPositionMs != null
                val targetChanged = targetGeneration != snapshot.generation
                if (!sessionActive) {
                    renderLoopRunning = false
                    return
                }
                if (!shouldContinue && !targetChanged) {
                    renderLoopRunning = false
                    if (activeStoreKey != null &&
                        latestTargetPositionMs != null &&
                        targetGeneration != snapshot.generation
                    ) {
                        scheduleRenderLoopLocked()
                    }
                    return
                }
            }

            Thread.sleep(RENDER_LOOP_RETRY_DELAY_MS)
        }
    }

    private fun performRenderPass(
        scrubStoreKey: String,
        positionMs: Long,
    ): Boolean {
        val store = scrubPreparationManager.getStore(scrubStoreKey) ?: return true
        val targetFrameIndex = store.resolveFrameIndex(positionMs)
        val exactFrameReady = store.hasFrame(targetFrameIndex)
        val resolvedFrameIndex =
            if (exactFrameReady) {
                targetFrameIndex
            } else {
                store.nearestReadyFrameIndex(
                    targetIndex = targetFrameIndex,
                    maxDistance = NEAREST_READY_MAX_DISTANCE,
                )
            }
        if (resolvedFrameIndex != null) {
            presentFrame(
                scrubStoreKey = scrubStoreKey,
                resolvedFrameIndex = resolvedFrameIndex,
            )
        }
        return !exactFrameReady
    }

    private fun presentFrame(
        scrubStoreKey: String,
        resolvedFrameIndex: Int,
    ): Boolean {
        val store =
            synchronized(this) {
                if (activeStoreKey != scrubStoreKey) {
                    return false
                }
                if (latestFrameIndex == resolvedFrameIndex) {
                    return true
                }
                scrubPreparationManager.getStore(scrubStoreKey)
            } ?: return false
        val bitmap = store.getFrameBitmap(resolvedFrameIndex) ?: return false
        val hostsToRender: List<Stage5ScrubRenderHost>
        synchronized(this) {
            if (activeStoreKey != scrubStoreKey) {
                return false
            }
            if (latestFrameIndex == resolvedFrameIndex) {
                return true
            }
            latestFrameIndex = resolvedFrameIndex
            hostsToRender = renderHosts.toList()
        }
        hostsToRender.forEach { host ->
            host.presentScrubFrame(bitmap)
            host.setScrubSurfaceVisible(true)
        }
        return true
    }

    private fun requestExtractionForTargetLocked(
        scrubStoreKey: String,
        positionMs: Long,
    ) {
        val store = scrubPreparationManager.getStore(scrubStoreKey) ?: return
        val frameIndex = store.resolveFrameIndex(positionMs)
        if (lastExtractionRequestStoreKey == scrubStoreKey &&
            lastExtractionRequestFrameIndex == frameIndex
        ) {
            return
        }
        lastExtractionRequestStoreKey = scrubStoreKey
        lastExtractionRequestFrameIndex = frameIndex
        scrubPreparationManager.requestFramesAround(
            assetId = scrubStoreKey,
            positionMs = positionMs,
            radiusFrames = PRIORITY_EXTRACTION_RADIUS_FRAMES,
        )
    }

    private fun resolveLatestBitmap(): Bitmap? {
        val storeKey = activeStoreKey ?: return null
        val frameIndex = latestFrameIndex ?: return null
        val store = scrubPreparationManager.getStore(storeKey) ?: return null
        return store.getFrameBitmap(frameIndex)
    }

    private data class RenderSnapshot(
        val scrubStoreKey: String,
        val positionMs: Long,
        val generation: Long,
    )
}
