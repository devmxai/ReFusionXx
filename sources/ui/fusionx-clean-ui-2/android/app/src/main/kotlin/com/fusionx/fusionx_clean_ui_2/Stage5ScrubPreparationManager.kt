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
    private val appContext = context.applicationContext
    private val extractor = Stage5ScrubFrameExtractor(appContext)
    private val executor: ExecutorService = Executors.newSingleThreadExecutor()
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
            executor.execute {
                extractStore(managed)
            }
            return managed.toStatus()
        }
    }

    fun getStatus(assetId: String): Stage5ScrubFrameStoreStatus? = stores[assetId]?.toStatus()

    fun getStore(assetId: String): Stage5ScrubFrameStore? = stores[assetId]?.store

    private fun extractStore(managed: ManagedStore) {
        managed.state = Stage5ScrubFrameStoreState.PREPARING
        managed.error = null
        managed.extractedFrameCount = 0
        try {
            extractor.extractInto(managed.store) { index ->
                managed.extractedFrameCount = (index + 1).coerceAtLeast(managed.extractedFrameCount)
            }
            managed.extractedFrameCount = managed.store.frameCount
            managed.state = Stage5ScrubFrameStoreState.READY
        } catch (error: Throwable) {
            managed.state = Stage5ScrubFrameStoreState.FAILED
            managed.error = error.message ?: error.toString()
        }
    }

    private fun resolveFrameIntervalMs(durationMs: Long): Int =
        when {
            durationMs <= 30_000L -> 50
            durationMs <= 5 * 60_000L -> 100
            durationMs <= 15 * 60_000L -> 200
            durationMs <= 30 * 60_000L -> 500
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

    private fun buildStoreDirectoryName(request: Stage5ScrubFrameStoreRequest): String {
        val digest =
            MessageDigest.getInstance("SHA-1")
                .digest("${request.assetId}|${request.sourceUri}".toByteArray())
        return digest.joinToString(separator = "") { byte ->
            "%02x".format(byte)
        }
    }

    private class ManagedStore(
        val store: Stage5ScrubFrameStore,
    ) {
        @Volatile
        var state: Stage5ScrubFrameStoreState = Stage5ScrubFrameStoreState.PREPARING

        @Volatile
        var extractedFrameCount: Int = 0

        @Volatile
        var error: String? = null

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

        fun dispose() {
            store.cleanup()
        }
    }
}
