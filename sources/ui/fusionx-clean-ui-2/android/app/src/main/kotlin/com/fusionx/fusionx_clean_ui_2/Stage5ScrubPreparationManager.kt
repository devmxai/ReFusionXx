package com.refusion.app

import android.content.Context
import android.graphics.Bitmap
import java.io.File
import java.security.MessageDigest
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors
import kotlin.math.abs

enum class Stage5ResolvedScrubFrameSource {
    DENSE_EXACT,
    OVERVIEW_EXACT,
    DENSE_NEAREST,
    OVERVIEW_NEAREST,
}

data class Stage5ResolvedScrubFrame(
    val bitmap: Bitmap,
    val presentationToken: String,
    val source: Stage5ResolvedScrubFrameSource,
    val frameTimeMs: Long,
)

class Stage5ScrubPreparationManager(
    context: Context,
) {
    companion object {
        private const val TARGET_ACTIVE_WINDOW_SPAN_MS = 3_000L
        private const val TARGET_BOOTSTRAP_RADIUS_MS = 1_000L
        private const val MIN_ACTIVE_WINDOW_RADIUS_FRAMES = 8
        private const val PRIORITY_WORKER_COUNT = 4
        private const val BACKGROUND_WORKER_COUNT = 2
    }

    private val appContext = context.applicationContext
    private val extractor = Stage5ScrubFrameExtractor(appContext)
    private val priorityExecutor: ExecutorService =
        Executors.newFixedThreadPool(PRIORITY_WORKER_COUNT)
    private val backgroundExecutor: ExecutorService =
        Executors.newFixedThreadPool(BACKGROUND_WORKER_COUNT)
    private val stores = ConcurrentHashMap<String, ManagedStore>()
    private val rootDirectory =
        File(appContext.cacheDir, "stage5_scrub_frame_stores").apply {
            mkdirs()
        }

    fun prepareStore(
        request: Stage5ScrubFrameStoreRequest,
        initialPositionMs: Long? = null,
        bootstrapSynchronously: Boolean = true,
    ): Stage5ScrubFrameStoreStatus {
        synchronized(this) {
            val existing = stores[request.assetId]
            if (existing != null && existing.matches(request)) {
                scheduleOverviewFill(existing)
                val bootstrapTargetIndex =
                    initialPositionMs?.let(existing.denseStore::resolveFrameIndex) ?: 0
                scheduleExtractionWindow(
                    managed = existing,
                    targetIndex = bootstrapTargetIndex,
                    radiusFrames = 0,
                    bootstrapSynchronously = bootstrapSynchronously,
                )
                return existing.toStatus()
            }
            existing?.dispose()
            val denseFrameIntervalMs = resolveDenseFrameIntervalMs(request.durationMs)
            val denseStorageTier = resolveStorageTier(request.durationMs, denseFrameIntervalMs)
            val denseBackingDirectory =
                if (denseStorageTier == Stage5ScrubStorageTier.DISK) {
                    File(
                        rootDirectory,
                        buildStoreDirectoryName(request, suffix = "dense"),
                    ).apply {
                        mkdirs()
                    }
                } else {
                    null
                }
            val denseStore =
                Stage5ScrubFrameStore(
                    request = request,
                    frameIntervalMs = denseFrameIntervalMs,
                    storageTier = denseStorageTier,
                    backingDirectory = denseBackingDirectory,
                )
            val overviewFrameIntervalMs = resolveOverviewFrameIntervalMs(request.durationMs)
            val overviewStorageTier = resolveStorageTier(request.durationMs, overviewFrameIntervalMs)
            val overviewBackingDirectory =
                if (overviewStorageTier == Stage5ScrubStorageTier.DISK) {
                    File(
                        rootDirectory,
                        buildStoreDirectoryName(request, suffix = "overview"),
                    ).apply {
                        mkdirs()
                    }
                } else {
                    null
                }
            val overviewStore =
                Stage5ScrubFrameStore(
                    request = request,
                    frameIntervalMs = overviewFrameIntervalMs,
                    storageTier = overviewStorageTier,
                    backingDirectory = overviewBackingDirectory,
                )
            val managed = ManagedStore(denseStore = denseStore, overviewStore = overviewStore)
            stores[request.assetId] = managed
            managed.state = Stage5ScrubFrameStoreState.PREPARING
            managed.error = null
            managed.extractedFrameCount = 0
            managed.overviewExtractedFrameCount = 0
            scheduleOverviewFill(managed)
            val bootstrapTargetIndex =
                initialPositionMs?.let(denseStore::resolveFrameIndex) ?: 0
            scheduleExtractionWindow(
                managed = managed,
                targetIndex = bootstrapTargetIndex,
                radiusFrames = 0,
                bootstrapSynchronously = bootstrapSynchronously,
            )
            return managed.toStatus()
        }
    }

    fun getStatus(assetId: String): Stage5ScrubFrameStoreStatus? = stores[assetId]?.toStatus()

    fun getStore(assetId: String): Stage5ScrubFrameStore? = stores[assetId]?.denseStore

    fun resolvePreviewFrame(
        assetId: String,
        positionMs: Long,
        allowApproximateFrames: Boolean = true,
    ): Stage5ResolvedScrubFrame? =
        stores[assetId]?.resolvePreviewFrame(
            positionMs = positionMs,
            allowApproximateFrames = allowApproximateFrames,
        )

    fun requestFramesAround(
        assetId: String,
        positionMs: Long,
        radiusFrames: Int = 0,
    ) {
        val managed = stores[assetId] ?: return
        scheduleOverviewFill(managed)
        val targetIndex = managed.denseStore.resolveFrameIndex(positionMs)
        scheduleExtractionWindow(
            managed = managed,
            targetIndex = targetIndex,
            radiusFrames = radiusFrames.coerceAtLeast(1),
        )
    }

    fun release() {
        stores.values.forEach(ManagedStore::dispose)
        stores.clear()
        extractor.release()
        priorityExecutor.shutdownNow()
        backgroundExecutor.shutdownNow()
    }

    private fun scheduleExtractionWindow(
        managed: ManagedStore,
        targetIndex: Int,
        radiusFrames: Int,
        bootstrapSynchronously: Boolean = false,
    ) {
        val effectiveRadiusFrames =
            radiusFrames.coerceAtLeast(
                resolveActiveWindowRadiusFrames(managed.denseStore.frameIntervalMs),
            )
        val plan = managed.beginActiveWindow(targetIndex, effectiveRadiusFrames)
        var remainingPriorityIndices = plan.priorityIndices
        if (bootstrapSynchronously && remainingPriorityIndices.isNotEmpty()) {
            val bootstrapFrameCount =
                resolveBootstrapPriorityFrameCount(
                    frameIntervalMs = managed.denseStore.frameIntervalMs,
                    radiusFrames = effectiveRadiusFrames,
                )
            val bootstrapIndices = remainingPriorityIndices.take(bootstrapFrameCount)
            extractPriorityFrames(
                managed = managed,
                generation = plan.generation,
                indices = bootstrapIndices,
            )
            remainingPriorityIndices =
                remainingPriorityIndices.drop(bootstrapIndices.size)
        }
        val priorityChunks =
            partitionIndices(remainingPriorityIndices, PRIORITY_WORKER_COUNT)
        priorityChunks.forEach { chunk ->
            if (chunk.isEmpty()) {
                return@forEach
            }
            priorityExecutor.execute {
                extractPriorityFrames(
                    managed = managed,
                    generation = plan.generation,
                    indices = chunk,
                )
            }
        }
        scheduleDenseBackgroundFill(
            managed = managed,
            targetIndex = targetIndex,
            radiusFrames = effectiveRadiusFrames,
            restart = plan.windowChanged,
        )
    }

    private fun extractPriorityFrames(
        managed: ManagedStore,
        generation: Int,
        indices: List<Int>,
    ) {
        if (!managed.isGenerationCurrent(generation)) {
            managed.clearPriorityScheduled(indices, generation)
            return
        }
        try {
            extractor.extractIndices(
                store = managed.denseStore,
                indices = indices,
                shouldContinue = { managed.isGenerationCurrent(generation) },
                onFrameExtracted = managed::onDenseFrameExtracted,
            )
        } catch (error: Throwable) {
            if (managed.error == null) {
                managed.error = error.message ?: error.toString()
            }
        } finally {
            managed.clearPriorityScheduled(indices, generation)
        }
    }

    private fun scheduleDenseBackgroundFill(
        managed: ManagedStore,
        targetIndex: Int,
        radiusFrames: Int,
        restart: Boolean,
    ) {
        val plan =
            managed.beginDenseBackgroundFill(
                targetIndex = targetIndex,
                radiusFrames = radiusFrames,
                restart = restart,
            ) ?: return
        val backgroundChunks =
            partitionIndices(plan.indices, BACKGROUND_WORKER_COUNT)
        backgroundChunks.forEach { chunk ->
            if (chunk.isEmpty()) {
                return@forEach
            }
            backgroundExecutor.execute {
                extractDenseBackgroundFrames(
                    managed = managed,
                    generation = plan.generation,
                    indices = chunk,
                )
            }
        }
    }

    private fun extractDenseBackgroundFrames(
        managed: ManagedStore,
        generation: Int,
        indices: List<Int>,
    ) {
        if (!managed.isDenseBackgroundGenerationCurrent(generation)) {
            managed.clearDenseBackgroundScheduled(indices, generation)
            return
        }
        try {
            extractor.extractIndices(
                store = managed.denseStore,
                indices = indices,
                shouldContinue = { managed.isDenseBackgroundGenerationCurrent(generation) },
                onFrameExtracted = managed::onDenseFrameExtracted,
            )
        } catch (error: Throwable) {
            if (managed.error == null) {
                managed.error = error.message ?: error.toString()
            }
        } finally {
            managed.clearDenseBackgroundScheduled(indices, generation)
        }
    }

    private fun scheduleOverviewFill(
        managed: ManagedStore,
        restart: Boolean = false,
    ) {
        val plan = managed.beginOverviewFill(restart = restart) ?: return
        val chunks = partitionIndices(plan.indices, BACKGROUND_WORKER_COUNT)
        chunks.forEach { chunk ->
            if (chunk.isEmpty()) {
                return@forEach
            }
            backgroundExecutor.execute {
                extractOverviewFrames(
                    managed = managed,
                    generation = plan.generation,
                    indices = chunk,
                )
            }
        }
    }

    private fun extractOverviewFrames(
        managed: ManagedStore,
        generation: Int,
        indices: List<Int>,
    ) {
        if (!managed.isOverviewGenerationCurrent(generation)) {
            managed.clearOverviewScheduled(indices, generation)
            return
        }
        try {
            extractor.extractIndices(
                store = managed.overviewStore,
                indices = indices,
                shouldContinue = { managed.isOverviewGenerationCurrent(generation) },
                onFrameExtracted = managed::onOverviewFrameExtracted,
            )
        } catch (error: Throwable) {
            if (managed.error == null) {
                managed.error = error.message ?: error.toString()
            }
        } finally {
            managed.clearOverviewScheduled(indices, generation)
        }
    }

    private fun resolveDenseFrameIntervalMs(durationMs: Long): Int =
        when {
            durationMs <= 30_000L -> 50
            durationMs <= 5 * 60_000L -> 100
            durationMs <= 15 * 60_000L -> 150
            durationMs <= 30 * 60_000L -> 250
            else -> 500
        }

    private fun resolveOverviewFrameIntervalMs(durationMs: Long): Int =
        when {
            durationMs <= 30_000L -> 200
            durationMs <= 5 * 60_000L -> 300
            durationMs <= 15 * 60_000L -> 500
            durationMs <= 30 * 60_000L -> 750
            else -> 1_000
        }

    private fun resolveStorageTier(
        durationMs: Long,
        frameIntervalMs: Int,
    ): Stage5ScrubStorageTier {
        val frameCount =
            (((durationMs.coerceAtLeast(0L) + frameIntervalMs - 1) / frameIntervalMs) + 1L)
                .coerceAtLeast(1L)
        return if (durationMs <= 90_000L && frameCount <= 1_500L) {
            Stage5ScrubStorageTier.MEMORY
        } else {
            Stage5ScrubStorageTier.DISK
        }
    }

    private fun resolveActiveWindowRadiusFrames(frameIntervalMs: Int): Int =
        ((TARGET_ACTIVE_WINDOW_SPAN_MS + frameIntervalMs - 1L) / frameIntervalMs.toLong())
            .toInt()
            .coerceAtLeast(MIN_ACTIVE_WINDOW_RADIUS_FRAMES)

    private fun resolveBootstrapPriorityFrameCount(
        frameIntervalMs: Int,
        radiusFrames: Int,
    ): Int {
        val bootstrapRadiusFrames =
            ((TARGET_BOOTSTRAP_RADIUS_MS + frameIntervalMs - 1L) / frameIntervalMs.toLong())
                .toInt()
                .coerceAtLeast(1)
        return (bootstrapRadiusFrames * 2 + 1)
            .coerceAtMost(radiusFrames * 2 + 1)
            .coerceAtLeast(3)
    }

    private fun resolveDenseNearestReadyMaxDistance(frameIntervalMs: Int): Int {
        val maxDeltaMs =
            when {
                frameIntervalMs <= 50 -> 300
                frameIntervalMs <= 100 -> 400
                frameIntervalMs <= 150 -> 450
                frameIntervalMs <= 250 -> 500
                else -> 750
            }
        return (maxDeltaMs / frameIntervalMs.toFloat()).toInt().coerceAtLeast(2)
    }

    private fun resolveOverviewNearestReadyMaxDistance(frameIntervalMs: Int): Int =
        when {
            frameIntervalMs <= 300 -> 1
            frameIntervalMs <= 750 -> 2
            else -> 3
        }

    private fun buildStoreDirectoryName(
        request: Stage5ScrubFrameStoreRequest,
        suffix: String,
    ): String {
        val digest =
            MessageDigest.getInstance("SHA-1")
                .digest("${request.assetId}|${request.sourceUri}|$suffix".toByteArray())
        return digest.joinToString(separator = "") { byte ->
            "%02x".format(byte)
        }
    }

    private fun buildPriorityWindow(
        targetIndex: Int,
        frameCount: Int,
        radiusFrames: Int,
    ): List<Int> {
        if (frameCount <= 0) {
            return emptyList()
        }
        val clampedTarget = targetIndex.coerceIn(0, frameCount - 1)
        val ordered = ArrayList<Int>(radiusFrames * 2 + 1)
        ordered.add(clampedTarget)
        for (distance in 1..radiusFrames.coerceAtLeast(0)) {
            val before = clampedTarget - distance
            if (before >= 0) {
                ordered.add(before)
            }
            val after = clampedTarget + distance
            if (after < frameCount) {
                ordered.add(after)
            }
        }
        return ordered
    }

    private fun buildDenseBackgroundFillWindow(
        targetIndex: Int,
        frameCount: Int,
        skipRadiusFrames: Int,
    ): List<Int> {
        if (frameCount <= 0) {
            return emptyList()
        }
        val clampedTarget = targetIndex.coerceIn(0, frameCount - 1)
        val maxDistance = maxOf(clampedTarget, frameCount - 1 - clampedTarget)
        val ordered = LinkedHashSet<Int>((frameCount - 1).coerceAtLeast(0))
        for (distance in (skipRadiusFrames.coerceAtLeast(0) + 1)..maxDistance) {
            val before = clampedTarget - distance
            if (before >= 0) {
                ordered.add(before)
            }
            val after = clampedTarget + distance
            if (after < frameCount) {
                ordered.add(after)
            }
        }
        return ordered.toList()
    }

    private fun partitionIndices(
        indices: List<Int>,
        partitionCount: Int,
    ): List<List<Int>> {
        if (indices.isEmpty()) {
            return emptyList()
        }
        val partitions = MutableList(partitionCount.coerceAtLeast(1)) { mutableListOf<Int>() }
        indices.forEachIndexed { index, frameIndex ->
            partitions[index % partitions.size].add(frameIndex)
        }
        return partitions.filter { it.isNotEmpty() }
    }

    private data class ActiveWindowPlan(
        val generation: Int,
        val priorityIndices: List<Int>,
        val windowChanged: Boolean,
    )

    private data class BackgroundFillPlan(
        val generation: Int,
        val indices: List<Int>,
    )

    private inner class ManagedStore(
        val denseStore: Stage5ScrubFrameStore,
        val overviewStore: Stage5ScrubFrameStore,
    ) {
        @Volatile
        var state: Stage5ScrubFrameStoreState = Stage5ScrubFrameStoreState.PREPARING

        @Volatile
        var extractedFrameCount: Int = 0

        @Volatile
        var overviewExtractedFrameCount: Int = 0

        @Volatile
        var error: String? = null

        @Volatile
        private var activeGeneration: Int = 0

        @Volatile
        private var activeWindowStartIndex: Int = -1

        @Volatile
        private var activeWindowEndIndex: Int = -1

        private val priorityGenerationsByIndex = ConcurrentHashMap<Int, Int>()

        @Volatile
        private var denseBackgroundGeneration: Int = 0

        @Volatile
        private var denseBackgroundWindowStartIndex: Int = -1

        @Volatile
        private var denseBackgroundWindowEndIndex: Int = -1

        private val denseBackgroundGenerationsByIndex = ConcurrentHashMap<Int, Int>()

        @Volatile
        private var overviewGeneration: Int = 0

        private val overviewGenerationsByIndex = ConcurrentHashMap<Int, Int>()
        private val extractedDenseIndices = ConcurrentHashMap.newKeySet<Int>()
        private val extractedOverviewIndices = ConcurrentHashMap.newKeySet<Int>()

        fun matches(request: Stage5ScrubFrameStoreRequest): Boolean {
            val current = denseStore.request
            return current.assetId == request.assetId &&
                current.sourceUri == request.sourceUri &&
                current.durationMs == request.durationMs &&
                current.previewWidth == request.previewWidth &&
                current.previewHeight == request.previewHeight
        }

        fun toStatus(): Stage5ScrubFrameStoreStatus {
            val activeWindowFrameCount =
                if (activeWindowStartIndex >= 0 &&
                    activeWindowEndIndex >= activeWindowStartIndex
                ) {
                    activeWindowEndIndex - activeWindowStartIndex + 1
                } else {
                    0
                }
            val activeWindowReadyFrameCount =
                if (activeWindowFrameCount > 0) {
                    countReadyDenseFrames(activeWindowStartIndex, activeWindowEndIndex)
                } else {
                    0
                }
            val activeWindowStartMs =
                if (activeWindowFrameCount > 0) {
                    denseStore.frameTimeMs(activeWindowStartIndex)
                } else {
                    null
                }
            val activeWindowEndMs =
                if (activeWindowFrameCount > 0) {
                    denseStore.frameTimeMs(activeWindowEndIndex)
                } else {
                    null
                }
            val isActiveWindowReady =
                activeWindowFrameCount > 0 &&
                    activeWindowReadyFrameCount >= activeWindowFrameCount
            return Stage5ScrubFrameStoreStatus(
                assetId = denseStore.request.assetId,
                sourceUri = denseStore.request.sourceUri,
                state = state,
                frameIntervalMs = denseStore.frameIntervalMs,
                frameCount = denseStore.frameCount,
                extractedFrameCount = extractedFrameCount.coerceIn(0, denseStore.frameCount),
                overviewFrameIntervalMs = overviewStore.frameIntervalMs,
                overviewFrameCount = overviewStore.frameCount,
                overviewExtractedFrameCount =
                    overviewExtractedFrameCount.coerceIn(0, overviewStore.frameCount),
                activeWindowStartMs = activeWindowStartMs,
                activeWindowEndMs = activeWindowEndMs,
                activeWindowFrameCount = activeWindowFrameCount,
                activeWindowReadyFrameCount = activeWindowReadyFrameCount,
                isActiveWindowReady = isActiveWindowReady,
                hasRenderablePreview = extractedFrameCount > 0 || overviewExtractedFrameCount > 0,
                storageTier = denseStore.storageTier,
                error = error,
            )
        }

        @Synchronized
        fun onDenseFrameExtracted(index: Int) {
            if (extractedDenseIndices.add(index)) {
                extractedFrameCount = extractedDenseIndices.size
                if (extractedFrameCount >= denseStore.frameCount) {
                    state = Stage5ScrubFrameStoreState.READY
                } else if (state != Stage5ScrubFrameStoreState.FAILED) {
                    state = Stage5ScrubFrameStoreState.PREPARING
                }
            }
        }

        @Synchronized
        fun onOverviewFrameExtracted(index: Int) {
            if (extractedOverviewIndices.add(index)) {
                overviewExtractedFrameCount = extractedOverviewIndices.size
            }
        }

        @Synchronized
        fun beginActiveWindow(
            targetIndex: Int,
            radiusFrames: Int,
        ): ActiveWindowPlan {
            val clampedTarget = targetIndex.coerceIn(0, denseStore.frameCount - 1)
            val windowStart = (clampedTarget - radiusFrames).coerceAtLeast(0)
            val windowEnd =
                (clampedTarget + radiusFrames).coerceAtMost(denseStore.frameCount - 1)
            val isInsideActiveWindow =
                clampedTarget in activeWindowStartIndex..activeWindowEndIndex
            var windowChanged = false
            if (!isInsideActiveWindow) {
                activeGeneration += 1
                activeWindowStartIndex = windowStart
                activeWindowEndIndex = windowEnd
                priorityGenerationsByIndex.clear()
                windowChanged = true
            }
            val generation = activeGeneration
            state = Stage5ScrubFrameStoreState.PREPARING
            val priorityWindow =
                buildPriorityWindow(
                    targetIndex = clampedTarget,
                    frameCount = denseStore.frameCount,
                    radiusFrames = radiusFrames,
                )
            val scheduledPriority = markPriorityScheduled(priorityWindow, generation)
            return ActiveWindowPlan(
                generation = generation,
                priorityIndices = scheduledPriority,
                windowChanged = windowChanged,
            )
        }

        fun isGenerationCurrent(generation: Int): Boolean = generation == activeGeneration

        @Synchronized
        fun beginDenseBackgroundFill(
            targetIndex: Int,
            radiusFrames: Int,
            restart: Boolean,
        ): BackgroundFillPlan? {
            if (denseStore.frameCount <= 0 || extractedFrameCount >= denseStore.frameCount) {
                return null
            }
            val clampedTarget = targetIndex.coerceIn(0, denseStore.frameCount - 1)
            val windowStart = (clampedTarget - radiusFrames).coerceAtLeast(0)
            val windowEnd =
                (clampedTarget + radiusFrames).coerceAtMost(denseStore.frameCount - 1)
            val hasBackgroundWorkInFlight = denseBackgroundGenerationsByIndex.isNotEmpty()
            val targetInsideBackgroundWindow =
                clampedTarget in denseBackgroundWindowStartIndex..denseBackgroundWindowEndIndex
            if (!restart && targetInsideBackgroundWindow && hasBackgroundWorkInFlight) {
                return null
            }
            denseBackgroundGeneration += 1
            denseBackgroundWindowStartIndex = windowStart
            denseBackgroundWindowEndIndex = windowEnd
            denseBackgroundGenerationsByIndex.clear()
            val generation = denseBackgroundGeneration
            val scheduledBackground =
                markDenseBackgroundScheduled(
                    buildDenseBackgroundFillWindow(
                        targetIndex = clampedTarget,
                        frameCount = denseStore.frameCount,
                        skipRadiusFrames = radiusFrames,
                    ),
                    generation,
                )
            if (scheduledBackground.isEmpty()) {
                return null
            }
            return BackgroundFillPlan(
                generation = generation,
                indices = scheduledBackground,
            )
        }

        fun isDenseBackgroundGenerationCurrent(generation: Int): Boolean =
            generation == denseBackgroundGeneration

        @Synchronized
        fun beginOverviewFill(restart: Boolean): BackgroundFillPlan? {
            if (overviewStore.frameCount <= 0 ||
                overviewExtractedFrameCount >= overviewStore.frameCount
            ) {
                return null
            }
            val hasOverviewWorkInFlight = overviewGenerationsByIndex.isNotEmpty()
            if (!restart && hasOverviewWorkInFlight) {
                return null
            }
            overviewGeneration += 1
            overviewGenerationsByIndex.clear()
            val generation = overviewGeneration
            val scheduledOverview =
                markOverviewScheduled(
                    (0 until overviewStore.frameCount).toList(),
                    generation,
                )
            if (scheduledOverview.isEmpty()) {
                return null
            }
            return BackgroundFillPlan(
                generation = generation,
                indices = scheduledOverview,
            )
        }

        fun isOverviewGenerationCurrent(generation: Int): Boolean =
            generation == overviewGeneration

        private fun markPriorityScheduled(
            indices: List<Int>,
            generation: Int,
        ): List<Int> =
            indices.filter { index ->
                !denseStore.hasFrame(index) &&
                    priorityGenerationsByIndex.put(index, generation) != generation
            }

        private fun markDenseBackgroundScheduled(
            indices: List<Int>,
            generation: Int,
        ): List<Int> =
            indices.filter { index ->
                !denseStore.hasFrame(index) &&
                    denseBackgroundGenerationsByIndex.put(index, generation) != generation
            }

        private fun markOverviewScheduled(
            indices: List<Int>,
            generation: Int,
        ): List<Int> =
            indices.filter { index ->
                !overviewStore.hasFrame(index) &&
                    overviewGenerationsByIndex.put(index, generation) != generation
            }

        fun clearPriorityScheduled(
            indices: List<Int>,
            generation: Int,
        ) {
            indices.forEach { index ->
                priorityGenerationsByIndex.remove(index, generation)
            }
        }

        fun clearDenseBackgroundScheduled(
            indices: List<Int>,
            generation: Int,
        ) {
            indices.forEach { index ->
                denseBackgroundGenerationsByIndex.remove(index, generation)
            }
        }

        fun clearOverviewScheduled(
            indices: List<Int>,
            generation: Int,
        ) {
            indices.forEach { index ->
                overviewGenerationsByIndex.remove(index, generation)
            }
        }

        fun resolvePreviewFrame(
            positionMs: Long,
            allowApproximateFrames: Boolean,
        ): Stage5ResolvedScrubFrame? {
            if (denseStore.frameCount <= 0) {
                return null
            }
            val candidates = ArrayList<Stage5ResolvedScrubFrame>(4)
            val denseTargetIndex = denseStore.resolveFrameIndex(positionMs)
            denseStore.getFrameBitmap(denseTargetIndex)?.let { bitmap ->
                candidates += Stage5ResolvedScrubFrame(
                    bitmap = bitmap,
                    presentationToken = "dense:$denseTargetIndex",
                    source = Stage5ResolvedScrubFrameSource.DENSE_EXACT,
                    frameTimeMs = denseStore.frameTimeMs(denseTargetIndex),
                )
            }
            if (!allowApproximateFrames) {
                return candidates.firstOrNull()
            }
            val overviewTargetIndex = overviewStore.resolveFrameIndex(positionMs)
            overviewStore.getFrameBitmap(overviewTargetIndex)?.let { bitmap ->
                candidates += Stage5ResolvedScrubFrame(
                    bitmap = bitmap,
                    presentationToken = "overview:$overviewTargetIndex",
                    source = Stage5ResolvedScrubFrameSource.OVERVIEW_EXACT,
                    frameTimeMs = overviewStore.frameTimeMs(overviewTargetIndex),
                )
            }
            denseStore.nearestReadyFrameIndex(
                targetIndex = denseTargetIndex,
                maxDistance = resolveDenseNearestReadyMaxDistance(denseStore.frameIntervalMs),
            )?.let { fallbackIndex ->
                val bitmap = denseStore.getFrameBitmap(fallbackIndex) ?: return@let
                candidates += Stage5ResolvedScrubFrame(
                    bitmap = bitmap,
                    presentationToken = "dense:$fallbackIndex",
                    source = Stage5ResolvedScrubFrameSource.DENSE_NEAREST,
                    frameTimeMs = denseStore.frameTimeMs(fallbackIndex),
                )
            }
            overviewStore.nearestReadyFrameIndex(
                targetIndex = overviewTargetIndex,
                maxDistance = resolveOverviewNearestReadyMaxDistance(overviewStore.frameIntervalMs),
            )?.let { fallbackIndex ->
                val bitmap = overviewStore.getFrameBitmap(fallbackIndex) ?: return@let
                candidates += Stage5ResolvedScrubFrame(
                    bitmap = bitmap,
                    presentationToken = "overview:$fallbackIndex",
                    source = Stage5ResolvedScrubFrameSource.OVERVIEW_NEAREST,
                    frameTimeMs = overviewStore.frameTimeMs(fallbackIndex),
                )
            }
            if (candidates.isEmpty()) {
                return null
            }
            return candidates.minWithOrNull(
                compareBy<Stage5ResolvedScrubFrame> { candidate ->
                    abs(candidate.frameTimeMs - positionMs)
                }.thenBy { candidate ->
                    when (candidate.source) {
                        Stage5ResolvedScrubFrameSource.DENSE_EXACT -> 0
                        Stage5ResolvedScrubFrameSource.DENSE_NEAREST -> 1
                        Stage5ResolvedScrubFrameSource.OVERVIEW_EXACT -> 2
                        Stage5ResolvedScrubFrameSource.OVERVIEW_NEAREST -> 3
                    }
                },
            )
        }

        private fun countReadyDenseFrames(
            startIndex: Int,
            endIndex: Int,
        ): Int {
            if (startIndex < 0 || endIndex < startIndex) {
                return 0
            }
            var readyCount = 0
            for (index in startIndex..endIndex) {
                if (denseStore.hasFrame(index)) {
                    readyCount += 1
                }
            }
            return readyCount
        }

        fun dispose() {
            denseStore.cleanup()
            overviewStore.cleanup()
        }
    }
}
