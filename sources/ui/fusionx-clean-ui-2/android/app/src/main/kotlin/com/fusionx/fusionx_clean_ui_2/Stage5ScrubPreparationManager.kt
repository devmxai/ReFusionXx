package com.refusion.app

import android.content.Context
import java.io.File
import java.security.MessageDigest
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

class Stage5ScrubPreparationManager(
    context: Context,
) {
    companion object {
        private const val DEFAULT_ACTIVE_WINDOW_RADIUS_FRAMES = 25
        private const val PRIORITY_WORKER_COUNT = 4
    }

    private val appContext = context.applicationContext
    private val extractor = Stage5ScrubFrameExtractor(appContext)
    private val priorityExecutor: ExecutorService =
        Executors.newFixedThreadPool(PRIORITY_WORKER_COUNT)
    private val stores = ConcurrentHashMap<String, ManagedStore>()
    private val rootDirectory =
        File(appContext.cacheDir, "stage5_scrub_frame_stores").apply {
            mkdirs()
        }

    fun prepareStore(request: Stage5ScrubFrameStoreRequest): Stage5ScrubFrameStoreStatus {
        synchronized(this) {
            val existing = stores[request.assetId]
            if (existing != null && existing.matches(request)) {
                return existing.toStatus()
            }
            existing?.dispose()
            val frameIntervalMs = resolveFrameIntervalMs(request.durationMs)
            val storageTier = resolveStorageTier(request.durationMs, frameIntervalMs)
            val backingDirectory =
                if (storageTier == Stage5ScrubStorageTier.DISK) {
                    File(rootDirectory, buildStoreDirectoryName(request)).apply {
                        mkdirs()
                    }
                } else {
                    null
                }
            val store =
                Stage5ScrubFrameStore(
                    request = request,
                    frameIntervalMs = frameIntervalMs,
                    storageTier = storageTier,
                    backingDirectory = backingDirectory,
                )
            val managed = ManagedStore(store)
            stores[request.assetId] = managed
            managed.state = Stage5ScrubFrameStoreState.PREPARING
            managed.error = null
            managed.extractedFrameCount = 0
            scheduleExtractionWindow(
                managed = managed,
                targetIndex = 0,
                radiusFrames = DEFAULT_ACTIVE_WINDOW_RADIUS_FRAMES,
            )
            return managed.toStatus()
        }
    }

    fun getStatus(assetId: String): Stage5ScrubFrameStoreStatus? = stores[assetId]?.toStatus()

    fun getStore(assetId: String): Stage5ScrubFrameStore? = stores[assetId]?.store

    fun requestFramesAround(
        assetId: String,
        positionMs: Long,
        radiusFrames: Int = DEFAULT_ACTIVE_WINDOW_RADIUS_FRAMES,
    ) {
        val managed = stores[assetId] ?: return
        val targetIndex = managed.store.resolveFrameIndex(positionMs)
        scheduleExtractionWindow(
            managed = managed,
            targetIndex = targetIndex,
            radiusFrames = radiusFrames.coerceAtLeast(1),
        )
    }

    fun hasCoverageAround(
        assetId: String,
        positionMs: Long,
        radiusFrames: Int = DEFAULT_ACTIVE_WINDOW_RADIUS_FRAMES,
    ): Boolean {
        val managed = stores[assetId] ?: return false
        return managed.hasCoverageAround(
            positionMs = positionMs,
            radiusFrames = radiusFrames.coerceAtLeast(1),
        )
    }

    private fun scheduleExtractionWindow(
        managed: ManagedStore,
        targetIndex: Int,
        radiusFrames: Int,
    ) {
        val plan = managed.beginActiveWindow(targetIndex, radiusFrames)
        val priorityChunks = partitionIndices(plan.priorityIndices, PRIORITY_WORKER_COUNT)
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
                store = managed.store,
                indices = indices,
                shouldContinue = { managed.isGenerationCurrent(generation) },
                onFrameExtracted = managed::onFrameExtracted,
            )
        } catch (error: Throwable) {
            if (managed.error == null) {
                managed.error = error.message ?: error.toString()
            }
        } finally {
            managed.clearPriorityScheduled(indices, generation)
        }
    }

    private fun resolveFrameIntervalMs(durationMs: Long): Int =
        when {
            durationMs <= 30_000L -> 50
            durationMs <= 5 * 60_000L -> 100
            durationMs <= 15 * 60_000L -> 150
            durationMs <= 30 * 60_000L -> 250
            else -> 500
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

    private fun buildStoreDirectoryName(request: Stage5ScrubFrameStoreRequest): String {
        val digest =
            MessageDigest.getInstance("SHA-1")
                .digest("${request.assetId}|${request.sourceUri}".toByteArray())
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
    )

    private inner class ManagedStore(
        val store: Stage5ScrubFrameStore,
    ) {
        @Volatile
        var state: Stage5ScrubFrameStoreState = Stage5ScrubFrameStoreState.PREPARING

        @Volatile
        var extractedFrameCount: Int = 0

        @Volatile
        var error: String? = null

        @Volatile
        private var activeGeneration: Int = 0

        @Volatile
        private var activeWindowStartIndex: Int = -1

        @Volatile
        private var activeWindowEndIndex: Int = -1

        private val priorityGenerationsByIndex = ConcurrentHashMap<Int, Int>()
        private val extractedIndices = ConcurrentHashMap.newKeySet<Int>()

        fun matches(request: Stage5ScrubFrameStoreRequest): Boolean {
            val current = store.request
            return current.assetId == request.assetId &&
                current.sourceUri == request.sourceUri &&
                current.durationMs == request.durationMs &&
                current.previewWidth == request.previewWidth &&
                current.previewHeight == request.previewHeight
        }

        fun toStatus(): Stage5ScrubFrameStoreStatus =
            Stage5ScrubFrameStoreStatus(
                assetId = store.request.assetId,
                sourceUri = store.request.sourceUri,
                state = state,
                frameIntervalMs = store.frameIntervalMs,
                frameCount = store.frameCount,
                extractedFrameCount = extractedFrameCount.coerceIn(0, store.frameCount),
                storageTier = store.storageTier,
                error = error,
            )

        @Synchronized
        fun onFrameExtracted(index: Int) {
            if (extractedIndices.add(index)) {
                extractedFrameCount = extractedIndices.size
                if (extractedFrameCount >= store.frameCount) {
                    state = Stage5ScrubFrameStoreState.READY
                } else if (state != Stage5ScrubFrameStoreState.FAILED) {
                    state = Stage5ScrubFrameStoreState.PREPARING
                }
            }
        }

        @Synchronized
        fun beginActiveWindow(
            targetIndex: Int,
            radiusFrames: Int,
        ): ActiveWindowPlan {
            val clampedTarget = targetIndex.coerceIn(0, store.frameCount - 1)
            val windowStart = (clampedTarget - radiusFrames).coerceAtLeast(0)
            val windowEnd = (clampedTarget + radiusFrames).coerceAtMost(store.frameCount - 1)
            val isInsideActiveWindow =
                clampedTarget in activeWindowStartIndex..activeWindowEndIndex
            if (!isInsideActiveWindow) {
                activeGeneration += 1
                activeWindowStartIndex = windowStart
                activeWindowEndIndex = windowEnd
                priorityGenerationsByIndex.clear()
            }
            val generation = activeGeneration
            state = Stage5ScrubFrameStoreState.PREPARING
            val priorityWindow =
                buildPriorityWindow(
                    targetIndex = clampedTarget,
                    frameCount = store.frameCount,
                    radiusFrames = radiusFrames,
                )
            val scheduledPriority = markPriorityScheduled(priorityWindow, generation)
            return ActiveWindowPlan(
                generation = generation,
                priorityIndices = scheduledPriority,
            )
        }

        @Synchronized
        fun hasCoverageAround(
            positionMs: Long,
            radiusFrames: Int,
        ): Boolean {
            if (store.frameCount <= 0) {
                return false
            }
            val targetIndex = store.resolveFrameIndex(positionMs)
            val startIndex = (targetIndex - radiusFrames).coerceAtLeast(0)
            val endIndex = (targetIndex + radiusFrames).coerceAtMost(store.frameCount - 1)
            for (index in startIndex..endIndex) {
                if (!store.hasFrame(index)) {
                    return false
                }
            }
            return true
        }

        fun isGenerationCurrent(generation: Int): Boolean = generation == activeGeneration

        private fun markPriorityScheduled(
            indices: List<Int>,
            generation: Int,
        ): List<Int> =
            indices.filter { index ->
                !store.hasFrame(index) &&
                    priorityGenerationsByIndex.put(index, generation) != generation
            }

        fun clearPriorityScheduled(
            indices: List<Int>,
            generation: Int,
        ) {
            indices.forEach { index ->
                priorityGenerationsByIndex.remove(index, generation)
            }
        }

        fun dispose() {
            store.cleanup()
        }
    }
}
