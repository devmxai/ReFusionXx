package com.refusion.app

import android.content.Context
import android.view.Surface
import androidx.media3.common.util.UnstableApi
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

data class Stage5NativeScrubSourceDescriptor(
    val clipId: String,
    val assetId: String,
    val scrubStoreKey: String,
    val sourceUri: String,
    val previewUri: String?,
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

@UnstableApi
class Stage5NativeScrubEngine(
    context: Context,
    private val scrubPreviewProxyManager: Stage5ScrubPreviewProxyManager,
) {
    companion object {
        private const val RENDER_LOOP_RETRY_DELAY_MS = 8L
    }

    private data class Diagnostics(
        var beginSessionCount: Long = 0L,
        var updateTargetCount: Long = 0L,
        var renderRequestCount: Long = 0L,
        var warmupRequestCount: Long = 0L,
        var renderedFrameCount: Long = 0L,
        var proxyReadyRenderCount: Long = 0L,
        var sourceFallbackRenderCount: Long = 0L,
        var noSurfaceCount: Long = 0L,
        var renderFailureCount: Long = 0L,
    ) {
        fun toMap(): Map<String, Any> =
            mapOf(
                "beginSessionCount" to beginSessionCount,
                "updateTargetCount" to updateTargetCount,
                "renderRequestCount" to renderRequestCount,
                "warmupRequestCount" to warmupRequestCount,
                "renderedFrameCount" to renderedFrameCount,
                "proxyReadyRenderCount" to proxyReadyRenderCount,
                "sourceFallbackRenderCount" to sourceFallbackRenderCount,
                "noSurfaceCount" to noSurfaceCount,
                "renderFailureCount" to renderFailureCount,
            )

        fun reset() {
            beginSessionCount = 0L
            updateTargetCount = 0L
            renderRequestCount = 0L
            warmupRequestCount = 0L
            renderedFrameCount = 0L
            proxyReadyRenderCount = 0L
            sourceFallbackRenderCount = 0L
            noSurfaceCount = 0L
            renderFailureCount = 0L
        }
    }

    private data class RenderSnapshot(
        val descriptor: Stage5NativeScrubSourceDescriptor,
        val sourcePositionMs: Long,
        val generation: Long,
    )

    private val appContext = context.applicationContext
    private val renderHosts = LinkedHashSet<Stage5ScrubRenderHost>()
    private val renderExecutor: ExecutorService = Executors.newSingleThreadExecutor()
    private val diagnostics = Diagnostics()

    private var activeDescriptor: Stage5NativeScrubSourceDescriptor? = null
    private var latestTargetSourcePositionMs: Long? = null
    private var targetGeneration: Long = 0L
    private var renderLoopRunning = false
    private var configuredTargetWidth: Int = 480
    private var configuredTargetHeight: Int = 854
    private var configuredPreviewSources: List<Stage5NativeScrubSourceDescriptor> =
        emptyList()
    private var decoder: Stage5SurfaceScrubDecoder? = null
    private var decoderPlaybackUri: String? = null

    @Synchronized
    fun registerRenderHost(host: Stage5ScrubRenderHost) {
        renderHosts.add(host)
        host.setScrubSurfaceVisible(activeDescriptor != null)
        if (activeDescriptor != null && latestTargetSourcePositionMs != null) {
            targetGeneration += 1
            scheduleRenderLoopLocked()
        }
    }

    @Synchronized
    fun unregisterRenderHost(host: Stage5ScrubRenderHost) {
        host.releaseScrubOutputSurface()
        renderHosts.remove(host)
    }

    @Synchronized
    fun configurePreviewSources(
        previewSources: List<Stage5NativeScrubSourceDescriptor>,
        targetWidth: Int,
        targetHeight: Int,
        initialTimelinePositionMs: Long? = null,
    ) {
        configuredPreviewSources =
            previewSources.sortedBy(Stage5NativeScrubSourceDescriptor::timelineStartMs)
        configuredTargetWidth = targetWidth
        configuredTargetHeight = targetHeight
        val prioritizedDescriptors =
            prioritizeDescriptorsForWarmup(
                descriptors = configuredPreviewSources,
                initialTimelinePositionMs = initialTimelinePositionMs,
            )
        prioritizedDescriptors.forEach { descriptor ->
            scrubPreviewProxyManager.ensurePreviewMedia(
                sourceUri = descriptor.sourceUri,
                previewUriHint = descriptor.previewUri,
            )
        }
        initialTimelinePositionMs?.let(::primeTimelinePosition)
    }

    @Synchronized
    fun primeTimelinePosition(positionMs: Long) {
        val descriptor = resolveDescriptorForPosition(positionMs) ?: return
        val sourcePositionMs = descriptor.resolveSourcePositionMs(positionMs)
        diagnostics.warmupRequestCount += 1
        renderExecutor.execute {
            synchronized(this) {
                if (activeDescriptor != null) {
                    return@execute
                }
            }
            renderSnapshot(
                snapshot =
                    RenderSnapshot(
                        descriptor = descriptor,
                        sourcePositionMs = sourcePositionMs,
                        generation = -1L,
                    ),
                makeVisible = false,
                onlyWhileInactive = true,
            )
        }
    }

    @Synchronized
    fun scrubTimelinePosition(positionMs: Long): Boolean {
        val descriptor = resolveDescriptorForPosition(positionMs) ?: return false
        val sourcePositionMs = descriptor.resolveSourcePositionMs(positionMs)
        return updateTarget(
            descriptor = descriptor,
            positionMs = sourcePositionMs,
            targetWidth = configuredTargetWidth,
            targetHeight = configuredTargetHeight,
        )
    }

    @Synchronized
    fun beginSession(
        scrubStoreKey: String,
        positionMs: Long,
        targetWidth: Int,
        targetHeight: Int,
    ): Boolean {
        val descriptor = resolveDescriptorForStoreKey(scrubStoreKey) ?: return false
        diagnostics.beginSessionCount += 1
        return updateTarget(
            descriptor = descriptor,
            positionMs = positionMs,
            targetWidth = targetWidth,
            targetHeight = targetHeight,
        )
    }

    @Synchronized
    fun updateTarget(
        scrubStoreKey: String,
        positionMs: Long,
        targetWidth: Int,
        targetHeight: Int,
    ): Boolean {
        val descriptor = resolveDescriptorForStoreKey(scrubStoreKey) ?: return false
        return updateTarget(
            descriptor = descriptor,
            positionMs = positionMs,
            targetWidth = targetWidth,
            targetHeight = targetHeight,
        )
    }

    @Synchronized
    private fun updateTarget(
        descriptor: Stage5NativeScrubSourceDescriptor,
        positionMs: Long,
        targetWidth: Int,
        targetHeight: Int,
    ): Boolean {
        diagnostics.updateTargetCount += 1
        configuredTargetWidth = targetWidth
        configuredTargetHeight = targetHeight
        activeDescriptor = descriptor
        latestTargetSourcePositionMs = positionMs.coerceAtLeast(0L)
        targetGeneration += 1
        scheduleRenderLoopLocked()
        return renderHosts.any(Stage5ScrubRenderHost::hasScrubOutputSurface)
    }

    @Synchronized
    fun endSession() {
        activeDescriptor = null
        latestTargetSourcePositionMs = null
        targetGeneration += 1
        renderHosts.forEach { host ->
            host.setScrubSurfaceVisible(false)
        }
    }

    @Synchronized
    fun release() {
        endSession()
        releaseDirectOutputSurface()
        decoder?.release()
        decoder = null
        decoderPlaybackUri = null
        renderHosts.clear()
        scrubPreviewProxyManager.release()
        renderExecutor.shutdownNow()
    }

    @Synchronized
    fun diagnosticsSnapshot(): Map<String, Any?> =
        mapOf(
            "nativeEngine" to diagnostics.toMap(),
            "activeStoreKey" to activeDescriptor?.scrubStoreKey,
            "latestTargetPositionMs" to latestTargetSourcePositionMs,
            "configuredPreviewSourceCount" to configuredPreviewSources.size,
            "decoderPlaybackUri" to decoderPlaybackUri,
            "hasDirectOutputSurface" to renderHosts.any(Stage5ScrubRenderHost::hasScrubOutputSurface),
        )

    @Synchronized
    fun resetDiagnostics() {
        diagnostics.reset()
    }

    @Synchronized
    fun notifyDirectOutputSurfaceAvailable() {
        if (activeDescriptor != null && latestTargetSourcePositionMs != null) {
            targetGeneration += 1
            scheduleRenderLoopLocked()
        }
    }

    @Synchronized
    fun acquireDirectOutputSurface(): Surface? =
        renderHosts.firstNotNullOfOrNull(Stage5ScrubRenderHost::acquireScrubOutputSurface)

    @Synchronized
    fun releaseDirectOutputSurface() {
        renderHosts.forEach(Stage5ScrubRenderHost::releaseScrubOutputSurface)
    }

    @Synchronized
    private fun scheduleRenderLoopLocked() {
        if (renderLoopRunning || activeDescriptor == null || latestTargetSourcePositionMs == null) {
            return
        }
        renderLoopRunning = true
        renderExecutor.execute(::runRenderLoop)
    }

    private fun runRenderLoop() {
        while (true) {
            val snapshot =
                synchronized(this) {
                    val descriptor = activeDescriptor
                    val sourcePositionMs = latestTargetSourcePositionMs
                    if (descriptor == null || sourcePositionMs == null) {
                        renderLoopRunning = false
                        return
                    }
                    RenderSnapshot(
                        descriptor = descriptor,
                        sourcePositionMs = sourcePositionMs,
                        generation = targetGeneration,
                    )
                }
            val rendered =
                renderSnapshot(
                snapshot = snapshot,
                makeVisible = true,
                onlyWhileInactive = false,
            )
            synchronized(this) {
                val sessionActive =
                    activeDescriptor != null && latestTargetSourcePositionMs != null
                val targetChanged = targetGeneration != snapshot.generation
                if (!sessionActive) {
                    renderLoopRunning = false
                    return
                }
                if (!targetChanged && rendered) {
                    renderLoopRunning = false
                    return
                }
            }
            Thread.sleep(RENDER_LOOP_RETRY_DELAY_MS)
        }
    }

    private fun renderSnapshot(
        snapshot: RenderSnapshot,
        makeVisible: Boolean,
        onlyWhileInactive: Boolean,
    ): Boolean {
        diagnostics.renderRequestCount += 1
        val outputSurface =
            synchronized(this) {
                if (onlyWhileInactive && activeDescriptor != null) {
                    return false
                }
                acquireDirectOutputSurface()
            } ?: run {
                diagnostics.noSurfaceCount += 1
                return false
            }
        val resolution =
            scrubPreviewProxyManager.resolvePlaybackUri(
                sourceUri = snapshot.descriptor.sourceUri,
                previewUriHint = snapshot.descriptor.previewUri,
            )
        if (resolution.isProxyReady) {
            diagnostics.proxyReadyRenderCount += 1
        } else {
            diagnostics.sourceFallbackRenderCount += 1
        }
        val decoder =
            ensureDecoderConfigured(
                playbackUri = resolution.playbackUri,
                outputSurface = outputSurface,
            ) ?: run {
                diagnostics.renderFailureCount += 1
                return false
            }
        val rendered =
            decoder.renderToPosition(snapshot.sourcePositionMs) {
                synchronized(this) {
                    if (onlyWhileInactive) {
                        activeDescriptor == null
                    } else {
                        activeDescriptor?.scrubStoreKey == snapshot.descriptor.scrubStoreKey
                    }
                }
            }
        if (!rendered) {
            diagnostics.renderFailureCount += 1
            return false
        }
        diagnostics.renderedFrameCount += 1
        if (!makeVisible) {
            return true
        }
        val hostsToShow =
            synchronized(this) {
                if (activeDescriptor?.scrubStoreKey != snapshot.descriptor.scrubStoreKey) {
                    return false
                }
                renderHosts.toList()
            }
        hostsToShow.forEach { host ->
            host.setScrubSurfaceVisible(true)
        }
        return true
    }

    private fun ensureDecoderConfigured(
        playbackUri: String,
        outputSurface: Surface,
    ): Stage5SurfaceScrubDecoder? {
        val currentDecoder =
            synchronized(this) {
                decoder ?: Stage5SurfaceScrubDecoder(appContext).also { decoder = it }
            }
        if (!currentDecoder.ensureConfigured(playbackUri, outputSurface)) {
            return null
        }
        synchronized(this) {
            decoderPlaybackUri = playbackUri
        }
        return currentDecoder
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

    private fun resolveDescriptorForStoreKey(
        scrubStoreKey: String,
    ): Stage5NativeScrubSourceDescriptor? =
        configuredPreviewSources.firstOrNull { descriptor ->
            descriptor.scrubStoreKey == scrubStoreKey
        }

    private fun prioritizeDescriptorsForWarmup(
        descriptors: List<Stage5NativeScrubSourceDescriptor>,
        initialTimelinePositionMs: Long?,
    ): List<Stage5NativeScrubSourceDescriptor> {
        if (descriptors.isEmpty() || initialTimelinePositionMs == null) {
            return descriptors
        }
        val ordered = descriptors.sortedBy(Stage5NativeScrubSourceDescriptor::timelineStartMs)
        val primaryIndex =
            ordered.indexOfFirst { descriptor ->
                descriptor.containsPosition(initialTimelinePositionMs)
            }.takeIf { it >= 0 } ?: 0
        val prioritized = LinkedHashSet<Stage5NativeScrubSourceDescriptor>()
        prioritized.add(ordered[primaryIndex])
        ordered.getOrNull(primaryIndex - 1)?.let(prioritized::add)
        ordered.getOrNull(primaryIndex + 1)?.let(prioritized::add)
        ordered.forEach(prioritized::add)
        return prioritized.toList()
    }
}
