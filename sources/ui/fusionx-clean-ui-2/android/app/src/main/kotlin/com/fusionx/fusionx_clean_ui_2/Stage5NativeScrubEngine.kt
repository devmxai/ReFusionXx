package com.refusion.app

import android.graphics.Bitmap
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors
import kotlin.math.abs

data class Stage5NativeScrubSourceDescriptor(
    val clipId: String,
    val assetId: String,
    val scrubStoreKey: String,
    val timelineStartMs: Long,
    val timelineEndMs: Long,
    val durationMs: Long,
    val sourceStartMs: Long,
    val sourceDurationMs: Long,
    val playbackRate: Double,
) {
    fun containsPosition(positionMs: Long): Boolean =
        positionMs >= timelineStartMs && positionMs < timelineEndMs

    fun resolveSourcePositionMs(timelinePositionMs: Long): Long {
        val localTimelineOffsetMs =
            (timelinePositionMs - timelineStartMs).coerceIn(0L, durationMs)
        val sourceOffsetMs = (localTimelineOffsetMs * playbackRate).toLong()
        return (sourceStartMs + sourceOffsetMs)
            .coerceIn(sourceStartMs, sourceStartMs + sourceDurationMs)
    }
}

class Stage5NativeScrubEngine(
    private val scrubPreparationManager: Stage5ScrubPreparationManager,
) {
    companion object {
        private const val PRIORITY_EXTRACTION_RADIUS_FRAMES = 25
        private const val RENDER_LOOP_RETRY_DELAY_MS = 8L
        private const val SESSION_BOOTSTRAP_RENDER_BUDGET_MS = 32L
        private const val SESSION_BOOTSTRAP_RENDER_POLL_MS = 4L
    }

    private val renderHosts = LinkedHashSet<Stage5ScrubRenderHost>()
    private val renderExecutor: ExecutorService = Executors.newSingleThreadExecutor()
    private var activeStoreKey: String? = null
    private var latestPresentationToken: String? = null
    private var latestTargetPositionMs: Long? = null
    private var latestPresentedFrameTimeMs: Long? = null
    private var latestPresentedFrameSource: Stage5ResolvedScrubFrameSource? = null
    private var lastExtractionRequestStoreKey: String? = null
    private var lastExtractionRequestFrameIndex: Int? = null
    private var targetGeneration: Long = 0
    private var renderLoopRunning = false
    private var configuredTargetWidth: Int = 480
    private var configuredTargetHeight: Int = 854
    private var textureSessionId: Long? = null
    private var nextTextureSessionId: Long = 1L
    private var configuredPreviewSources: List<Stage5NativeScrubSourceDescriptor> =
        emptyList()
    private val diagnostics = Diagnostics()

    private data class Diagnostics(
        var beginSessionCount: Long = 0L,
        var updateTargetCount: Long = 0L,
        var renderPassCount: Long = 0L,
        var exactFrameHitCount: Long = 0L,
        var nearestReadyFallbackCount: Long = 0L,
        var frameMissCount: Long = 0L,
    ) {
        fun toMap(): Map<String, Any> =
            mapOf(
                "beginSessionCount" to beginSessionCount,
                "updateTargetCount" to updateTargetCount,
                "renderPassCount" to renderPassCount,
                "exactFrameHitCount" to exactFrameHitCount,
                "nearestReadyFallbackCount" to nearestReadyFallbackCount,
                "frameMissCount" to frameMissCount,
            )

        fun reset() {
            beginSessionCount = 0L
            updateTargetCount = 0L
            renderPassCount = 0L
            exactFrameHitCount = 0L
            nearestReadyFallbackCount = 0L
            frameMissCount = 0L
        }
    }

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
    fun configurePreviewSources(
        previewSources: List<Stage5NativeScrubSourceDescriptor>,
        targetWidth: Int,
        targetHeight: Int,
    ) {
        configuredPreviewSources =
            previewSources.sortedBy(Stage5NativeScrubSourceDescriptor::timelineStartMs)
        configuredTargetWidth = targetWidth
        configuredTargetHeight = targetHeight
    }

    @Synchronized
    @Suppress("UNUSED_PARAMETER")
    fun ensureTexture(
        targetWidth: Int,
        targetHeight: Int,
    ): Long? {
        configuredTargetWidth = targetWidth
        configuredTargetHeight = targetHeight
        if (textureSessionId == null) {
            textureSessionId = nextTextureSessionId++
        }
        return textureSessionId
    }

    @Synchronized
    fun currentTextureId(): Long? = textureSessionId

    @Synchronized
    fun scrubTimelinePosition(positionMs: Long): Boolean {
        val descriptor = resolveDescriptorForPosition(positionMs) ?: return false
        val sourcePositionMs = descriptor.resolveSourcePositionMs(positionMs)
        return updateTarget(
            scrubStoreKey = descriptor.scrubStoreKey,
            positionMs = sourcePositionMs,
            targetWidth = configuredTargetWidth,
            targetHeight = configuredTargetHeight,
        )
    }

    @Synchronized
    @Suppress("UNUSED_PARAMETER")
    fun beginSession(
        scrubStoreKey: String,
        positionMs: Long,
        targetWidth: Int,
        targetHeight: Int,
    ): Boolean {
        diagnostics.beginSessionCount += 1
        activeStoreKey = scrubStoreKey
        latestPresentationToken = null
        latestTargetPositionMs = positionMs
        latestPresentedFrameTimeMs = null
        latestPresentedFrameSource = null
        lastExtractionRequestStoreKey = null
        lastExtractionRequestFrameIndex = null
        targetGeneration += 1
        requestExtractionForTargetLocked(
            scrubStoreKey = scrubStoreKey,
            positionMs = positionMs,
        )
        val rendered =
            attemptBootstrapRender(
                scrubStoreKey = scrubStoreKey,
                positionMs = positionMs,
            )
        scheduleRenderLoopLocked()
        return rendered
    }

    @Synchronized
    @Suppress("UNUSED_PARAMETER")
    fun updateTarget(
        scrubStoreKey: String,
        positionMs: Long,
        targetWidth: Int,
        targetHeight: Int,
    ): Boolean {
        diagnostics.updateTargetCount += 1
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
        val rendered =
            attemptImmediateRender(
                scrubStoreKey = scrubStoreKey,
                positionMs = positionMs,
            )
        scheduleRenderLoopLocked()
        return rendered
    }

    @Synchronized
    fun endSession() {
        activeStoreKey = null
        latestPresentationToken = null
        latestTargetPositionMs = null
        latestPresentedFrameTimeMs = null
        latestPresentedFrameSource = null
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
        textureSessionId = null
    }

    @Synchronized
    fun release() {
        endSession()
        renderHosts.clear()
        renderExecutor.shutdownNow()
    }

    @Synchronized
    fun diagnosticsSnapshot(): Map<String, Any?> =
        mapOf(
            "nativeEngine" to diagnostics.toMap(),
            "activeStoreKey" to activeStoreKey,
            "latestPresentationToken" to latestPresentationToken,
            "latestTargetPositionMs" to latestTargetPositionMs,
            "configuredPreviewSourceCount" to configuredPreviewSources.size,
        )

    @Synchronized
    fun resetDiagnostics() {
        diagnostics.reset()
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
                    generation = snapshot.generation,
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
        generation: Long,
    ): Boolean {
        diagnostics.renderPassCount += 1
        val allowApproximateFrames =
            synchronized(this) {
                latestPresentationToken == null
            }
        val resolvedFrame =
            scrubPreparationManager.resolvePreviewFrame(
                assetId = scrubStoreKey,
                positionMs = positionMs,
                allowApproximateFrames = allowApproximateFrames,
            )
        when (resolvedFrame?.source) {
            Stage5ResolvedScrubFrameSource.DENSE_EXACT ->
                diagnostics.exactFrameHitCount += 1
            Stage5ResolvedScrubFrameSource.OVERVIEW_EXACT,
            Stage5ResolvedScrubFrameSource.DENSE_NEAREST,
            Stage5ResolvedScrubFrameSource.OVERVIEW_NEAREST ->
                diagnostics.nearestReadyFallbackCount += 1
            null -> diagnostics.frameMissCount += 1
        }
        if (resolvedFrame != null) {
            presentFrame(
                scrubStoreKey = scrubStoreKey,
                targetPositionMs = positionMs,
                generation = generation,
                resolvedFrame = resolvedFrame,
            )
        }
        return resolvedFrame?.source != Stage5ResolvedScrubFrameSource.DENSE_EXACT
    }

    private fun attemptBootstrapRender(
        scrubStoreKey: String,
        positionMs: Long,
    ): Boolean {
        val deadline = System.currentTimeMillis() + SESSION_BOOTSTRAP_RENDER_BUDGET_MS
        do {
            attemptImmediateRender(
                scrubStoreKey = scrubStoreKey,
                positionMs = positionMs,
            )
            synchronized(this) {
                if (activeStoreKey != scrubStoreKey) {
                    return false
                }
                if (latestPresentationToken != null) {
                    return true
                }
            }
            if (System.currentTimeMillis() >= deadline) {
                break
            }
            Thread.sleep(SESSION_BOOTSTRAP_RENDER_POLL_MS)
        } while (true)
        synchronized(this) {
            return activeStoreKey == scrubStoreKey && latestPresentationToken != null
        }
    }

    private fun attemptImmediateRender(
        scrubStoreKey: String,
        positionMs: Long,
    ): Boolean {
        performRenderPass(
            scrubStoreKey = scrubStoreKey,
            positionMs = positionMs,
            generation = synchronized(this) { targetGeneration },
        )
        synchronized(this) {
            return activeStoreKey == scrubStoreKey && latestPresentationToken != null
        }
    }

    private fun presentFrame(
        scrubStoreKey: String,
        targetPositionMs: Long,
        generation: Long,
        resolvedFrame: Stage5ResolvedScrubFrame,
    ): Boolean {
        val bitmap = resolvedFrame.bitmap
        val hostsToRender: List<Stage5ScrubRenderHost>
        val candidateDistanceMs = abs(resolvedFrame.frameTimeMs - targetPositionMs)
        synchronized(this) {
            if (activeStoreKey != scrubStoreKey) {
                return false
            }
            if (generation != targetGeneration) {
                return false
            }
            if (latestPresentationToken == resolvedFrame.presentationToken) {
                return true
            }
            val latestFrameTimeMs = latestPresentedFrameTimeMs
            if (latestFrameTimeMs != null) {
                val displayedDistanceMs = abs(latestFrameTimeMs - targetPositionMs)
                if (candidateDistanceMs > displayedDistanceMs) {
                    return false
                }
                if (candidateDistanceMs == displayedDistanceMs) {
                    val latestSourceRank =
                        latestPresentedFrameSource?.let(::resolvedFrameSourceRank) ?: Int.MAX_VALUE
                    if (resolvedFrameSourceRank(resolvedFrame.source) >= latestSourceRank) {
                        return false
                    }
                }
            }
            latestPresentationToken = resolvedFrame.presentationToken
            latestPresentedFrameTimeMs = resolvedFrame.frameTimeMs
            latestPresentedFrameSource = resolvedFrame.source
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
        val positionMs = latestTargetPositionMs ?: return null
        return scrubPreparationManager.resolvePreviewFrame(
            assetId = storeKey,
            positionMs = positionMs,
            allowApproximateFrames = latestPresentationToken == null,
        )?.bitmap
    }

    private fun resolveDescriptorForPosition(
        positionMs: Long,
    ): Stage5NativeScrubSourceDescriptor? {
        val previewSources = configuredPreviewSources
        if (previewSources.isEmpty()) {
            return null
        }
        previewSources.firstOrNull { descriptor ->
            descriptor.containsPosition(positionMs)
        }?.let { return it }
        return previewSources.minByOrNull { descriptor ->
            when {
                positionMs < descriptor.timelineStartMs ->
                    descriptor.timelineStartMs - positionMs
                else -> positionMs - descriptor.timelineEndMs
            }
        }
    }

    private fun resolvedFrameSourceRank(source: Stage5ResolvedScrubFrameSource): Int =
        when (source) {
            Stage5ResolvedScrubFrameSource.DENSE_EXACT -> 0
            Stage5ResolvedScrubFrameSource.DENSE_NEAREST -> 1
            Stage5ResolvedScrubFrameSource.OVERVIEW_EXACT -> 2
            Stage5ResolvedScrubFrameSource.OVERVIEW_NEAREST -> 3
        }

    private data class RenderSnapshot(
        val scrubStoreKey: String,
        val positionMs: Long,
        val generation: Long,
    )
}
