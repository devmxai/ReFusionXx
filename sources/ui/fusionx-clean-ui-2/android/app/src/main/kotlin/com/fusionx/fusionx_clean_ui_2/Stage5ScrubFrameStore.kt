package com.refusion.app

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.util.LruCache
import java.io.File
import java.io.FileOutputStream
import kotlin.math.min

enum class Stage5ScrubStorageTier {
    MEMORY,
    DISK,
}

enum class Stage5ScrubFrameStoreState {
    IDLE,
    PREPARING,
    READY,
    FAILED,
}

data class Stage5ScrubFrameStoreRequest(
    val assetId: String,
    val sourceUri: String,
    val durationMs: Long,
    val sourceWidth: Int?,
    val sourceHeight: Int?,
    val previewWidth: Int,
    val previewHeight: Int,
)

data class Stage5ScrubFrameStoreStatus(
    val assetId: String,
    val sourceUri: String,
    val state: Stage5ScrubFrameStoreState,
    val frameIntervalMs: Int,
    val frameCount: Int,
    val extractedFrameCount: Int,
    val storageTier: Stage5ScrubStorageTier?,
    val error: String?,
) {
    fun toMap(): Map<String, Any?> =
        mapOf(
            "assetId" to assetId,
            "sourceUri" to sourceUri,
            "state" to state.name.lowercase(),
            "frameIntervalMs" to frameIntervalMs,
            "frameCount" to frameCount,
            "extractedFrameCount" to extractedFrameCount,
            "storageTier" to storageTier?.name?.lowercase(),
            "error" to error,
            "isReady" to (state == Stage5ScrubFrameStoreState.READY),
        )
}

class Stage5ScrubFrameStore(
    val request: Stage5ScrubFrameStoreRequest,
    val frameIntervalMs: Int,
    val storageTier: Stage5ScrubStorageTier,
    private val backingDirectory: File?,
) {
    val frameCount: Int =
        (((request.durationMs.coerceAtLeast(0L) + frameIntervalMs - 1) / frameIntervalMs) + 1L)
            .coerceAtLeast(1L)
            .toInt()

    private val memoryFrames: Array<Bitmap?> = arrayOfNulls(frameCount)
    private val diskFramePaths: Array<String?> = arrayOfNulls(frameCount)
    private val diskDecodedFrames =
        object : LruCache<Int, Bitmap>(150) {
            override fun entryRemoved(
                evicted: Boolean,
                key: Int,
                oldValue: Bitmap,
                newValue: Bitmap?,
            ) {
                if (evicted && oldValue !== newValue && !oldValue.isRecycled) {
                    oldValue.recycle()
                }
            }
        }

    fun resolveFrameIndex(positionMs: Long): Int {
        if (frameCount <= 1) {
            return 0
        }
        val clampedPositionMs = positionMs.coerceIn(0L, request.durationMs.coerceAtLeast(0L))
        return (clampedPositionMs / frameIntervalMs.toLong())
            .toInt()
            .coerceIn(0, frameCount - 1)
    }

    fun frameTimeMs(index: Int): Long =
        min(request.durationMs.coerceAtLeast(0L), index.coerceAtLeast(0) * frameIntervalMs.toLong())

    @Synchronized
    fun hasFrame(index: Int): Boolean {
        if (index !in 0 until frameCount) {
            return false
        }
        return when (storageTier) {
            Stage5ScrubStorageTier.MEMORY -> memoryFrames[index] != null
            Stage5ScrubStorageTier.DISK -> {
                val path = diskFramePaths[index] ?: return false
                File(path).exists()
            }
        }
    }

    @Synchronized
    fun nearestReadyFrameIndex(
        targetIndex: Int,
        maxDistance: Int,
    ): Int? {
        if (targetIndex !in 0 until frameCount) {
            return null
        }
        if (hasFrame(targetIndex)) {
            return targetIndex
        }
        for (distance in 1..maxDistance.coerceAtLeast(0)) {
            val before = targetIndex - distance
            if (before >= 0 && hasFrame(before)) {
                return before
            }
            val after = targetIndex + distance
            if (after < frameCount && hasFrame(after)) {
                return after
            }
        }
        return null
    }

    @Synchronized
    fun putFrameBitmap(index: Int, bitmap: Bitmap) {
        if (index !in 0 until frameCount) {
            return
        }
        when (storageTier) {
            Stage5ScrubStorageTier.MEMORY -> {
                memoryFrames[index]?.takeIf { !it.isRecycled }?.recycle()
                val safeConfig: Bitmap.Config =
                    if (bitmap.config == null || bitmap.config == Bitmap.Config.HARDWARE) {
                        Bitmap.Config.ARGB_8888
                    } else {
                        bitmap.config!!
                    }
                memoryFrames[index] = bitmap.copy(safeConfig, false)
            }
            Stage5ScrubStorageTier.DISK -> {
                val directory = backingDirectory ?: return
                if (!directory.exists()) {
                    directory.mkdirs()
                }
                val frameFile = File(directory, index.toString().padStart(8, '0') + ".jpg")
                FileOutputStream(frameFile).use { output ->
                    bitmap.compress(Bitmap.CompressFormat.JPEG, 82, output)
                }
                diskDecodedFrames.remove(index)
                diskFramePaths[index] = frameFile.absolutePath
            }
        }
    }

    @Synchronized
    fun getFrameBitmap(index: Int): Bitmap? {
        if (index !in 0 until frameCount) {
            return null
        }
        return when (storageTier) {
            Stage5ScrubStorageTier.MEMORY -> memoryFrames[index]
            Stage5ScrubStorageTier.DISK -> {
                diskDecodedFrames.get(index)?.let { cached ->
                    if (!cached.isRecycled) {
                        return cached
                    }
                    diskDecodedFrames.remove(index)
                }
                val path = diskFramePaths[index] ?: return null
                val frameFile = File(path)
                if (!frameFile.exists()) {
                    return null
                }
                val decoded = BitmapFactory.decodeFile(frameFile.absolutePath) ?: return null
                diskDecodedFrames.put(index, decoded)
                decoded
            }
        }
    }

    @Synchronized
    fun cleanup() {
        for (index in memoryFrames.indices) {
            memoryFrames[index]?.takeIf { !it.isRecycled }?.recycle()
            memoryFrames[index] = null
        }
        for (index in diskFramePaths.indices) {
            diskFramePaths[index] = null
        }
        diskDecodedFrames.evictAll()
        if (storageTier == Stage5ScrubStorageTier.DISK) {
            backingDirectory?.deleteRecursively()
        }
    }
}
