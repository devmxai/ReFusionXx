package com.refusion.app

import android.content.Context
import android.os.SystemClock
import android.view.Surface
import androidx.media3.common.util.UnstableApi
import java.util.concurrent.CountDownLatch
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit

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
    val sourceWidth: Int? = null,
    val sourceHeight: Int? = null,
) {
    fun containsPosition(positionMs: Long): Boolean =
        positionMs >= timelineStartMs && positionMs < timelineEndMs

    fun resolveSourcePositionMs(timelinePositionMs: Long): Long {
        return (sourceStartMs + resolveSourceOffsetMs(timelinePositionMs))
            .coerceIn(sourceStartMs, sourceStartMs + sourceDurationMs)
    }

    fun resolveSourceOffsetMs(timelinePositionMs: Long): Long {
        val localTimelineOffsetMs =
            (timelinePositionMs - timelineStartMs).coerceIn(0L, durationMs)
        return (localTimelineOffsetMs * playbackRate).toLong()
            .coerceIn(0L, sourceDurationMs)
    }

    fun sourceAspectRatio(): Float? {
        val width = sourceWidth?.takeIf { it > 0 } ?: return null
        val height = sourceHeight?.takeIf { it > 0 } ?: return null
        return width.toFloat() / height.toFloat().coerceAtLeast(1f)
    }
}

@UnstableApi
class Stage5NativeScrubEngine(
    context: Context,
    private val scrubPreviewProxyManager: Stage5ScrubPreviewProxyManager,
) {
    companion object {
        private const val RENDER_LOOP_RETRY_DELAY_MS = 8L
        private const val PROXY_WAIT_RETRY_DELAY_MS = 64L
        private const val BOUNDARY_WARMUP_MARGIN_MS = 2_000L
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
        var decoderConfigureFailureCount: Long = 0L,
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
                "decoderConfigureFailureCount" to decoderConfigureFailureCount,
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
            decoderConfigureFailureCount = 0L
            renderFailureCount = 0L
        }
    }

    private data class RenderSnapshot(
        val descriptor: Stage5NativeScrubSourceDescriptor,
        val sourcePositionMs: Long,
        val generation: Long,
        val forceSeekBeforeRender: Boolean,
        val requireFreshFrame: Boolean,
    )

    private data class OutputTarget(
        val host: Stage5ScrubRenderHost,
        val surface: Surface,
    )

    private data class ReadinessTarget(
        val descriptor: Stage5NativeScrubSourceDescriptor,
        val sourcePositionMs: Long,
    )

    private val surfaceScrubDecoder = Stage5SurfaceScrubDecoder(context.applicationContext)
    private val mediaDisplayGeometryResolver =
        MediaDisplayGeometryResolver(context.applicationContext)
    private val renderHosts = LinkedHashSet<Stage5ScrubRenderHost>()
    private val renderExecutor: ExecutorService = Executors.newSingleThreadExecutor()
    private val warmupExecutor: ExecutorService = Executors.newSingleThreadExecutor()
    private val diagnostics = Diagnostics()
    private val proxyReadyListener =
        object : Stage5ScrubPreviewProxyListener {
            override fun onProxyReady(sourceUri: String) {
                handleProxyReady(sourceUri)
            }
        }

    private var activeDescriptor: Stage5NativeScrubSourceDescriptor? = null
    private var latestTargetSourcePositionMs: Long? = null
    private var latestKnownTimelinePositionMs: Long? = null
    private var targetGeneration: Long = 0L
    private var renderLoopRunning = false
    private var sessionFrozen = false
    private var freezeAfterNextRenderedTarget = false
    private var configuredTargetWidth: Int = 480
    private var configuredTargetHeight: Int = 854
    private var configuredPreviewSources: List<Stage5NativeScrubSourceDescriptor> =
        emptyList()
    private var configurationGeneration: Long = 0L
    private var lastProxyWarmupSourceUri: String? = null
    private var lastBoundaryWarmupKey: String? = null
    private var pendingDecoderForceSeekStoreKey: String? = null
    private val resolvedAspectRatioBySourceUri = HashMap<String, Float>()
    @Volatile
    private var lastRenderAwaitingProxy = false

    init {
        scrubPreviewProxyManager.addListener(proxyReadyListener)
    }

    fun primePreviewSource(
        sourceUri: String,
        previewUriHint: String? = null,
    ) {
        if (sourceUri.isBlank()) {
            return
        }
        warmupExecutor.execute {
            scrubPreviewProxyManager.ensurePreviewMedia(
                sourceUri = sourceUri,
                previewUriHint = previewUriHint,
            )
        }
    }

    fun awaitTimelineScrubReady(
        timelinePositionMs: Long,
        timeoutMs: Long = 1_200L,
    ): Boolean {
        val normalizedTimelinePositionMs = timelinePositionMs.coerceAtLeast(0L)
        val readinessTimeoutMs = timeoutMs.coerceAtLeast(1L)
        var readinessGeneration: Long
        val readinessTargets =
            synchronized(this) {
                latestKnownTimelinePositionMs = normalizedTimelinePositionMs
                sessionFrozen = false
                activeDescriptor = null
                latestTargetSourcePositionMs = null
                pendingDecoderForceSeekStoreKey = null
                lastBoundaryWarmupKey = null
                targetGeneration += 1
                readinessGeneration = targetGeneration
                renderHosts.forEach { host ->
                    host.setScrubSurfaceVisible(false)
                }
                buildReadinessTargetsLocked(normalizedTimelinePositionMs)
            }
        if (readinessTargets.isEmpty()) {
            return false
        }
        val primaryTarget = readinessTargets.last()
        readinessTargets.forEach { target ->
            scrubPreviewProxyManager.ensurePreviewMedia(
                sourceUri = target.descriptor.sourceUri,
                previewUriHint = target.descriptor.previewUri,
            )
        }
        val result = BooleanArray(1)
        val latch = CountDownLatch(1)
        renderExecutor.execute {
            try {
                result[0] =
                    renderHiddenReadinessTargets(
                        targets = readinessTargets,
                        timeoutMs = readinessTimeoutMs,
                        readinessGeneration = readinessGeneration,
                    )
            } finally {
                latch.countDown()
            }
        }
        val completed =
            latch.await(
                readinessTimeoutMs + PROXY_WAIT_RETRY_DELAY_MS,
                TimeUnit.MILLISECONDS,
            )
        val isReady = completed && result[0]
        synchronized(this) {
            if (targetGeneration != readinessGeneration) {
                return false
            }
            renderHosts.forEach { host ->
                host.setScrubSurfaceVisible(false)
            }
            if (isReady) {
                activeDescriptor = primaryTarget.descriptor
                latestTargetSourcePositionMs = primaryTarget.sourcePositionMs
                pendingDecoderForceSeekStoreKey = null
                sessionFrozen = true
            } else {
                activeDescriptor = null
                latestTargetSourcePositionMs = null
                pendingDecoderForceSeekStoreKey = null
                sessionFrozen = false
            }
            targetGeneration += 1
        }
        return isReady
    }

    @Synchronized
    fun activatePrimedSession(): Boolean {
        if (
            !sessionFrozen ||
            activeDescriptor == null ||
            latestTargetSourcePositionMs == null
        ) {
            return false
        }
        sessionFrozen = false
        freezeAfterNextRenderedTarget = false
        renderHosts.forEach { host ->
            host.setScrubSurfaceVisible(true)
        }
        targetGeneration += 1
        scheduleRenderLoopLocked()
        return true
    }

    @Synchronized
    fun registerRenderHost(host: Stage5ScrubRenderHost) {
        renderHosts.add(host)
        host.setScrubSurfaceVisible(false)
        if (activeDescriptor != null && latestTargetSourcePositionMs != null && !sessionFrozen) {
            targetGeneration += 1
            scheduleRenderLoopLocked()
        }
    }

    @Synchronized
    fun unregisterRenderHost(host: Stage5ScrubRenderHost) {
        host.releaseScrubOutputSurface()
        renderHosts.remove(host)
        if (renderHosts.isEmpty()) {
            surfaceScrubDecoder.release()
        }
    }

    @Synchronized
    fun configurePreviewSources(
        previewSources: List<Stage5NativeScrubSourceDescriptor>,
        targetWidth: Int,
        targetHeight: Int,
        initialTimelinePositionMs: Long? = null,
    ) {
        val sortedPreviewSources =
            previewSources.sortedBy(Stage5NativeScrubSourceDescriptor::timelineStartMs)
        val previewSourcesChanged =
            configuredPreviewSources != sortedPreviewSources ||
                configuredTargetWidth != targetWidth ||
                configuredTargetHeight != targetHeight
        configuredPreviewSources = sortedPreviewSources
        configuredTargetWidth = targetWidth
        configuredTargetHeight = targetHeight
        if (initialTimelinePositionMs != null) {
            latestKnownTimelinePositionMs = initialTimelinePositionMs.coerceAtLeast(0L)
        }
        if (!previewSourcesChanged) {
            return
        }
        configurationGeneration += 1
        val generation = configurationGeneration
        val prioritizedDescriptors =
            prioritizeDescriptorsForWarmup(
                descriptors = configuredPreviewSources,
                initialTimelinePositionMs = initialTimelinePositionMs,
            )
        val activeSourceUris = prioritizedDescriptors.mapTo(LinkedHashSet()) { descriptor ->
            descriptor.sourceUri
        }
        warmupExecutor.execute {
            synchronized(this) {
                if (generation != configurationGeneration) {
                    return@execute
                }
            }
            prioritizedDescriptors.forEach { descriptor ->
                scrubPreviewProxyManager.ensurePreviewMedia(
                    sourceUri = descriptor.sourceUri,
                    previewUriHint = descriptor.previewUri,
                )
            }
            scrubPreviewProxyManager.pruneEntries(activeSourceUris)
        }
        val primePositionMs = latestKnownTimelinePositionMs
        if (primePositionMs != null) {
            warmupExecutor.execute {
                primeTimelinePosition(primePositionMs)
            }
        }
    }

    @Synchronized
    fun primeTimelinePosition(positionMs: Long) {
        latestKnownTimelinePositionMs = positionMs.coerceAtLeast(0L)
        val descriptor = resolveDescriptorForPosition(positionMs) ?: return
        diagnostics.warmupRequestCount += 1
        warmupExecutor.execute {
            synchronized(this) {
                if (activeDescriptor != null) {
                    return@execute
                }
            }
            scrubPreviewProxyManager.ensurePreviewMedia(
                sourceUri = descriptor.sourceUri,
                previewUriHint = descriptor.previewUri,
            )
            val playbackUri = resolveReadyPlaybackUri(descriptor) ?: return@execute
            val outputTarget =
                synchronized(this) {
                    if (activeDescriptor != null) {
                        null
                    } else {
                        acquireOutputTargetLocked()
                    }
                } ?: return@execute
            surfaceScrubDecoder.ensureConfigured(
                playbackUri = playbackUri.playbackUri,
                outputSurface = outputTarget.surface,
            )
        }
    }

    @Synchronized
    fun scrubTimelinePosition(positionMs: Long): Boolean {
        latestKnownTimelinePositionMs = positionMs.coerceAtLeast(0L)
        val descriptor = resolveDescriptorForPosition(positionMs) ?: return false
        val sourcePositionMs = descriptor.resolveSourcePositionMs(positionMs)
        primeBoundaryNeighborsLocked(
            timelinePositionMs = positionMs,
            descriptor = descriptor,
        )
        return updateTarget(
            descriptor = descriptor,
            positionMs = sourcePositionMs,
            targetWidth = configuredTargetWidth,
            targetHeight = configuredTargetHeight,
        )
    }

    @Synchronized
    fun commitFinalTimelinePosition(positionMs: Long): Boolean {
        latestKnownTimelinePositionMs = positionMs.coerceAtLeast(0L)
        val descriptor = resolveDescriptorForPosition(positionMs) ?: return false
        val sourcePositionMs = descriptor.resolveSourcePositionMs(positionMs)
        primeBoundaryNeighborsLocked(
            timelinePositionMs = positionMs,
            descriptor = descriptor,
        )
        val didUpdateTarget =
            updateTarget(
                descriptor = descriptor,
                positionMs = sourcePositionMs,
                targetWidth = configuredTargetWidth,
                targetHeight = configuredTargetHeight,
            )
        if (didUpdateTarget) {
            freezeAfterNextRenderedTarget = true
        }
        return didUpdateTarget
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
        sessionFrozen = false
        freezeAfterNextRenderedTarget = false
        val descriptorChanged =
            activeDescriptor?.scrubStoreKey != descriptor.scrubStoreKey
        activeDescriptor = descriptor
        latestTargetSourcePositionMs = normalizeDescriptorPositionMs(descriptor, positionMs)
        targetGeneration += 1
        if (descriptorChanged) {
            pendingDecoderForceSeekStoreKey = descriptor.scrubStoreKey
        }
        if (lastProxyWarmupSourceUri != descriptor.sourceUri) {
            lastProxyWarmupSourceUri = descriptor.sourceUri
            warmupExecutor.execute {
                scrubPreviewProxyManager.ensurePreviewMedia(
                    sourceUri = descriptor.sourceUri,
                    previewUriHint = descriptor.previewUri,
                )
            }
        }
        scheduleRenderLoopLocked()
        return renderHosts.isNotEmpty()
    }

    @Synchronized
    fun freezeSession() {
        if (activeDescriptor == null) {
            return
        }
        freezeAfterNextRenderedTarget = false
        sessionFrozen = true
        targetGeneration += 1
    }

    @Synchronized
    fun endSession() {
        sessionFrozen = false
        freezeAfterNextRenderedTarget = false
        activeDescriptor = null
        latestTargetSourcePositionMs = null
        pendingDecoderForceSeekStoreKey = null
        targetGeneration += 1
        renderHosts.forEach { host ->
            host.setScrubSurfaceVisible(false)
        }
    }

    @Synchronized
    fun release() {
        endSession()
        renderHosts.clear()
        scrubPreviewProxyManager.removeListener(proxyReadyListener)
        surfaceScrubDecoder.release()
        renderExecutor.shutdownNow()
        warmupExecutor.shutdownNow()
        scrubPreviewProxyManager.release()
    }

    @Synchronized
    fun diagnosticsSnapshot(): Map<String, Any?> =
        mapOf(
            "nativeEngine" to diagnostics.toMap(),
            "activeStoreKey" to activeDescriptor?.scrubStoreKey,
            "latestTargetPositionMs" to latestTargetSourcePositionMs,
            "configuredPreviewSourceCount" to configuredPreviewSources.size,
            "hasRenderHost" to renderHosts.isNotEmpty(),
        )

    @Synchronized
    fun resetDiagnostics() {
        diagnostics.reset()
    }

    @Synchronized
    fun notifyDirectOutputSurfaceAvailable() {
        if (activeDescriptor != null && latestTargetSourcePositionMs != null && !sessionFrozen) {
            targetGeneration += 1
            scheduleRenderLoopLocked()
            return
        }
        val primePositionMs = latestKnownTimelinePositionMs
        if (primePositionMs != null && configuredPreviewSources.isNotEmpty()) {
            warmupExecutor.execute {
                primeTimelinePosition(primePositionMs)
            }
        }
    }

    @Synchronized
    private fun scheduleRenderLoopLocked() {
        if (
            renderLoopRunning ||
            sessionFrozen ||
            activeDescriptor == null ||
            latestTargetSourcePositionMs == null ||
            renderHosts.isEmpty()
        ) {
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
                    if (sessionFrozen || descriptor == null || sourcePositionMs == null) {
                        renderLoopRunning = false
                        return
                    }
                    RenderSnapshot(
                        descriptor = descriptor,
                        sourcePositionMs = sourcePositionMs,
                        generation = targetGeneration,
                        forceSeekBeforeRender =
                            pendingDecoderForceSeekStoreKey == descriptor.scrubStoreKey,
                        requireFreshFrame = freezeAfterNextRenderedTarget,
                    )
                }
            val rendered = renderSnapshot(snapshot)
            val retryDelayMs =
                if (lastRenderAwaitingProxy) {
                    PROXY_WAIT_RETRY_DELAY_MS
                } else {
                    RENDER_LOOP_RETRY_DELAY_MS
                }
            var retryImmediately = false
            synchronized(this) {
                val sessionActive =
                    !sessionFrozen && activeDescriptor != null && latestTargetSourcePositionMs != null
                val targetChanged = targetGeneration != snapshot.generation
                if (!sessionActive) {
                    renderLoopRunning = false
                    return
                }
                if (!targetChanged && rendered && freezeAfterNextRenderedTarget) {
                    sessionFrozen = true
                    freezeAfterNextRenderedTarget = false
                    targetGeneration += 1
                    renderLoopRunning = false
                    return
                }
                if (!targetChanged && rendered) {
                    renderLoopRunning = false
                    return
                }
                if (targetChanged && !lastRenderAwaitingProxy) {
                    retryImmediately = true
                }
            }
            if (!retryImmediately && retryDelayMs > 0L) {
                Thread.sleep(retryDelayMs)
            }
        }
    }

    private fun renderSnapshot(snapshot: RenderSnapshot): Boolean {
        diagnostics.renderRequestCount += 1
        val outputTarget =
            synchronized(this) {
                if (
                    sessionFrozen ||
                    activeDescriptor?.scrubStoreKey != snapshot.descriptor.scrubStoreKey
                ) {
                    null
                } else {
                    acquireOutputTargetLocked()
                }
            } ?: run {
                lastRenderAwaitingProxy = false
                diagnostics.noSurfaceCount += 1
                return false
            }
        val playbackUri =
            resolveReadyPlaybackUri(snapshot.descriptor) ?: run {
                lastRenderAwaitingProxy = true
                return false
            }
        lastRenderAwaitingProxy = false
        if (playbackUri.isProxyReady) {
            diagnostics.proxyReadyRenderCount += 1
        } else {
            diagnostics.sourceFallbackRenderCount += 1
        }
        if (
            !surfaceScrubDecoder.ensureConfigured(
                playbackUri = playbackUri.playbackUri,
                outputSurface = outputTarget.surface,
            )
        ) {
            diagnostics.decoderConfigureFailureCount += 1
            return false
        }
        outputTarget.host.setScrubContentAspectRatio(
            resolveDescriptorAspectRatio(snapshot.descriptor),
        )
        if (snapshot.forceSeekBeforeRender) {
            surfaceScrubDecoder.forceSeekOnNextRender()
        }
        val rendered =
            surfaceScrubDecoder.renderToPosition(
                positionMs = snapshot.sourcePositionMs,
                requireFreshFrame = snapshot.requireFreshFrame,
                shouldContinue = {
                    synchronized(this) {
                        val finalCommitStillTargetsSnapshot =
                            !freezeAfterNextRenderedTarget ||
                                (targetGeneration == snapshot.generation &&
                                    latestTargetSourcePositionMs == snapshot.sourcePositionMs)
                        !sessionFrozen &&
                            activeDescriptor?.scrubStoreKey == snapshot.descriptor.scrubStoreKey &&
                            finalCommitStillTargetsSnapshot
                    }
                },
            )
        if (!rendered) {
            diagnostics.renderFailureCount += 1
            return false
        }
        diagnostics.renderedFrameCount += 1
        synchronized(this) {
            if (
                sessionFrozen ||
                activeDescriptor?.scrubStoreKey != snapshot.descriptor.scrubStoreKey
            ) {
                return false
            }
            renderHosts.forEach { host ->
                host.setScrubSurfaceVisible(host === outputTarget.host)
            }
            if (pendingDecoderForceSeekStoreKey == snapshot.descriptor.scrubStoreKey) {
                pendingDecoderForceSeekStoreKey = null
            }
        }
        return true
    }

    private fun renderHiddenReadinessTargets(
        targets: List<ReadinessTarget>,
        timeoutMs: Long,
        readinessGeneration: Long,
    ): Boolean {
        val deadlineMs = SystemClock.elapsedRealtime() + timeoutMs.coerceAtLeast(1L)
        val outputTarget = awaitOutputTarget(deadlineMs) ?: run {
            diagnostics.noSurfaceCount += 1
            return false
        }
        var renderedTargetCount = 0
        targets.forEachIndexed { index, target ->
            if (SystemClock.elapsedRealtime() >= deadlineMs) {
                return@forEachIndexed
            }
            if (synchronized(this) { targetGeneration != readinessGeneration }) {
                return false
            }
            val playbackUri = resolveReadyPlaybackUri(target.descriptor) ?: return@forEachIndexed
            if (playbackUri.isProxyReady) {
                diagnostics.proxyReadyRenderCount += 1
            } else {
                diagnostics.sourceFallbackRenderCount += 1
            }
            if (
                !surfaceScrubDecoder.ensureConfigured(
                    playbackUri = playbackUri.playbackUri,
                    outputSurface = outputTarget.surface,
                )
            ) {
                diagnostics.decoderConfigureFailureCount += 1
                return@forEachIndexed
            }
            outputTarget.host.setScrubContentAspectRatio(
                resolveDescriptorAspectRatio(target.descriptor),
            )
            surfaceScrubDecoder.forceSeekOnNextRender()
            val rendered =
                surfaceScrubDecoder.renderToPosition(
                    positionMs = target.sourcePositionMs,
                    shouldContinue = {
                        SystemClock.elapsedRealtime() < deadlineMs &&
                            synchronized(this) { targetGeneration == readinessGeneration }
                    },
                )
            if (!rendered) {
                diagnostics.renderFailureCount += 1
                return@forEachIndexed
            }
            diagnostics.renderedFrameCount += 1
            renderedTargetCount = index + 1
        }
        synchronized(this) {
            renderHosts.forEach { host ->
                host.setScrubSurfaceVisible(false)
            }
        }
        return renderedTargetCount == targets.size
    }

    private fun awaitOutputTarget(deadlineMs: Long): OutputTarget? {
        while (SystemClock.elapsedRealtime() < deadlineMs) {
            synchronized(this) {
                acquireOutputTargetLocked()
            }?.let { outputTarget ->
                return outputTarget
            }
            Thread.sleep(16L)
        }
        return synchronized(this) { acquireOutputTargetLocked() }
    }

    private fun acquireOutputTargetLocked(): OutputTarget? {
        renderHosts.forEach { host ->
            val surface = host.acquireScrubOutputSurface()
            if (surface != null && surface.isValid) {
                return OutputTarget(host = host, surface = surface)
            }
        }
        return null
    }

    private fun resolvePlaybackUri(
        descriptor: Stage5NativeScrubSourceDescriptor,
    ): Stage5ScrubPreviewProxyManager.ProxyResolution =
        scrubPreviewProxyManager.resolvePlaybackUri(
            sourceUri = descriptor.sourceUri,
            previewUriHint = descriptor.previewUri,
        )

    private fun resolveReadyPlaybackUri(
        descriptor: Stage5NativeScrubSourceDescriptor,
    ): Stage5ScrubPreviewProxyManager.ProxyResolution? {
        val resolution = resolvePlaybackUri(descriptor)
        if (resolution.isProxyReady) {
            return resolution
        }
        scrubPreviewProxyManager.ensurePreviewMedia(
            sourceUri = descriptor.sourceUri,
            previewUriHint = descriptor.previewUri,
        )
        return resolution
    }

    private fun normalizeDescriptorPositionMs(
        descriptor: Stage5NativeScrubSourceDescriptor,
        positionMs: Long,
    ): Long {
        val sourceStartMs = descriptor.sourceStartMs.coerceAtLeast(0L)
        val sourceEndMs = (descriptor.sourceStartMs + descriptor.sourceDurationMs).coerceAtLeast(sourceStartMs)
        return positionMs.coerceIn(sourceStartMs, sourceEndMs)
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

    private fun handleProxyReady(sourceUri: String) {
        val primePositionMs =
            synchronized(this) {
                val knownTimelinePositionMs = latestKnownTimelinePositionMs ?: return
                if (configuredPreviewSources.none { descriptor -> descriptor.sourceUri == sourceUri }) {
                    return
                }
                if (sessionFrozen) {
                    if (activeDescriptor?.sourceUri != sourceUri) {
                        return
                    }
                    knownTimelinePositionMs
                } else {
                    if (activeDescriptor != null) {
                        return
                    }
                    knownTimelinePositionMs
                }
            }
        warmupExecutor.execute {
            awaitTimelineScrubReady(
                timelinePositionMs = primePositionMs,
                timeoutMs = 700L,
            )
        }
    }

    private fun resolveDescriptorAspectRatio(descriptor: Stage5NativeScrubSourceDescriptor): Float? {
        resolvedAspectRatioBySourceUri[descriptor.sourceUri]?.let { return it }
        mediaDisplayGeometryResolver.resolve(descriptor.sourceUri)?.let { geometry ->
            val aspectRatio =
                geometry.width.toFloat() / geometry.height.toFloat().coerceAtLeast(1f)
            resolvedAspectRatioBySourceUri[descriptor.sourceUri] = aspectRatio
            return aspectRatio
        }
        descriptor.sourceAspectRatio()?.let { aspectRatio ->
            resolvedAspectRatioBySourceUri[descriptor.sourceUri] = aspectRatio
            return aspectRatio
        }
        return null
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
        return prioritized.toList()
    }

    private fun buildReadinessTargetsLocked(
        timelinePositionMs: Long,
    ): List<ReadinessTarget> {
        val descriptor = resolveDescriptorForPosition(timelinePositionMs) ?: return emptyList()
        val sorted = configuredPreviewSources
        val descriptorIndex =
            sorted.indexOfFirst { candidate ->
                candidate.scrubStoreKey == descriptor.scrubStoreKey
            }
        val readinessTargets = ArrayList<ReadinessTarget>(3)
        // A timeline edit can be followed by an immediate drag across clip
        // boundaries, so readiness must warm the adjacent decoders as well as
        // the current frame. The current descriptor is appended last so it
        // remains the frozen primed session after hidden readiness completes.
        if (descriptorIndex >= 0) {
            sorted.getOrNull(descriptorIndex - 1)?.let { previousDescriptor ->
                val previousTimelinePositionMs =
                    (previousDescriptor.timelineEndMs - 1L)
                        .coerceAtLeast(previousDescriptor.timelineStartMs)
                readinessTargets +=
                    ReadinessTarget(
                        descriptor = previousDescriptor,
                        sourcePositionMs =
                            previousDescriptor.resolveSourcePositionMs(previousTimelinePositionMs),
                    )
            }
            sorted.getOrNull(descriptorIndex + 1)?.let { nextDescriptor ->
                readinessTargets +=
                    ReadinessTarget(
                        descriptor = nextDescriptor,
                        sourcePositionMs =
                            nextDescriptor.resolveSourcePositionMs(nextDescriptor.timelineStartMs),
                    )
            }
        }
        readinessTargets +=
            ReadinessTarget(
                descriptor = descriptor,
                sourcePositionMs = descriptor.resolveSourcePositionMs(timelinePositionMs),
            )
        return readinessTargets
    }

    private fun primeBoundaryNeighborsLocked(
        timelinePositionMs: Long,
        descriptor: Stage5NativeScrubSourceDescriptor,
    ) {
        val sorted = configuredPreviewSources
        if (sorted.size < 2) {
            return
        }
        val descriptorIndex =
            sorted.indexOfFirst { candidate ->
                candidate.scrubStoreKey == descriptor.scrubStoreKey
            }
        if (descriptorIndex < 0) {
            return
        }
        val descriptorsToPrime = LinkedHashSet<Stage5NativeScrubSourceDescriptor>()
        descriptorsToPrime.add(descriptor)
        if (timelinePositionMs >= descriptor.timelineEndMs - BOUNDARY_WARMUP_MARGIN_MS) {
            sorted.getOrNull(descriptorIndex + 1)?.let(descriptorsToPrime::add)
        }
        if (timelinePositionMs <= descriptor.timelineStartMs + BOUNDARY_WARMUP_MARGIN_MS) {
            sorted.getOrNull(descriptorIndex - 1)?.let(descriptorsToPrime::add)
        }
        val warmupKey =
            descriptorsToPrime.joinToString(separator = "|") { candidate ->
                candidate.scrubStoreKey
            }
        if (warmupKey == lastBoundaryWarmupKey) {
            return
        }
        lastBoundaryWarmupKey = warmupKey
        val descriptors = descriptorsToPrime.toList()
        warmupExecutor.execute {
            descriptors.forEach { candidate ->
                scrubPreviewProxyManager.ensurePreviewMedia(
                    sourceUri = candidate.sourceUri,
                    previewUriHint = candidate.previewUri,
                )
            }
        }
    }
}
