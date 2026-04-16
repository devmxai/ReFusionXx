package com.refusion.app

import android.content.Context
import android.net.Uri
import androidx.media3.common.C
import androidx.media3.common.MediaItem
import androidx.media3.common.MimeTypes
import androidx.media3.effect.Presentation
import androidx.media3.transformer.Composition
import androidx.media3.transformer.DefaultEncoderFactory
import androidx.media3.transformer.EditedMediaItem
import androidx.media3.transformer.EditedMediaItemSequence
import androidx.media3.transformer.Effects
import androidx.media3.transformer.ExportException
import androidx.media3.transformer.ExportResult
import androidx.media3.transformer.Transformer
import androidx.media3.transformer.VideoEncoderSettings
import java.io.File
import java.security.MessageDigest
import java.util.concurrent.ConcurrentHashMap
import kotlin.math.roundToInt

enum class Stage5ScrubProxyState {
    IDLE,
    PREPARING,
    READY,
    FAILED,
}

data class Stage5ScrubProxyRequest(
    val assetId: String,
    val sourceUri: String,
    val durationMs: Long,
    val sourceWidth: Int?,
    val sourceHeight: Int?,
)

data class Stage5ScrubProxyStatus(
    val assetId: String,
    val sourceUri: String,
    val state: Stage5ScrubProxyState,
    val previewUri: String?,
    val targetWidth: Int?,
    val targetHeight: Int?,
    val error: String?,
) {
    fun toMap(): Map<String, Any?> =
        mapOf(
            "assetId" to assetId,
            "sourceUri" to sourceUri,
            "state" to state.name.lowercase(),
            "previewUri" to previewUri,
            "targetWidth" to targetWidth,
            "targetHeight" to targetHeight,
            "error" to error,
            "isReady" to (state == Stage5ScrubProxyState.READY),
        )
}

class Stage5ScrubProxyManager(
    context: Context,
) {
    companion object {
        private const val LONG_FORM_PROXY_THRESHOLD_MS = 10 * 60 * 1000L
        private const val DEFAULT_PROXY_LONG_SIDE_PX = 480
        private const val LONG_FORM_PROXY_LONG_SIDE_PX = 360
        private const val DEFAULT_PROXY_BITRATE = 1_600_000
        private const val LONG_FORM_PROXY_BITRATE = 900_000
        private const val DEFAULT_PROXY_FRAME_RATE = 30
    }

    private val appContext = context.applicationContext
    private val proxyDirectory =
        File(appContext.cacheDir, "stage5_scrub_proxies").apply {
            mkdirs()
        }
    private val proxies = ConcurrentHashMap<String, ManagedProxy>()

    @Synchronized
    fun prepareProxy(request: Stage5ScrubProxyRequest): Stage5ScrubProxyStatus {
        val existing = proxies[request.assetId]
        if (existing != null && existing.matches(request)) {
            if (existing.state == Stage5ScrubProxyState.READY &&
                existing.outputFile.exists()
            ) {
                return existing.toStatus()
            }
            if (existing.state == Stage5ScrubProxyState.PREPARING) {
                return existing.toStatus()
            }
        }
        existing?.dispose()
        val outputSize = resolveOutputSize(request)
        val outputFile = File(proxyDirectory, buildProxyFileName(request, outputSize))
        if (outputFile.exists() && outputFile.length() > 0L) {
            val managed =
                ManagedProxy(
                    request = request,
                    outputFile = outputFile,
                    targetWidth = outputSize.first,
                    targetHeight = outputSize.second,
                ).apply {
                    state = Stage5ScrubProxyState.READY
                    previewUri = Uri.fromFile(outputFile).toString()
                }
            proxies[request.assetId] = managed
            return managed.toStatus()
        }
        outputFile.parentFile?.mkdirs()
        outputFile.delete()
        val managed =
            ManagedProxy(
                request = request,
                outputFile = outputFile,
                targetWidth = outputSize.first,
                targetHeight = outputSize.second,
            )
        proxies[request.assetId] = managed
        startProxyExport(managed)
        return managed.toStatus()
    }

    @Synchronized
    fun getStatus(assetId: String): Stage5ScrubProxyStatus? {
        val managed = proxies[assetId] ?: return null
        if (managed.state == Stage5ScrubProxyState.READY && !managed.outputFile.exists()) {
            managed.state = Stage5ScrubProxyState.FAILED
            managed.previewUri = null
            managed.error = "Proxy file is missing from cache."
        }
        return managed.toStatus()
    }

    @Synchronized
    fun release() {
        proxies.values.forEach(ManagedProxy::dispose)
        proxies.clear()
    }

    private fun startProxyExport(managed: ManagedProxy) {
        val request = managed.request
        try {
            val videoEncoderSettings =
                VideoEncoderSettings.Builder()
                    .setBitrate(resolveBitrate(request.durationMs))
                    .setiFrameIntervalSeconds(1.0f)
                    .build()
            val encoderFactory =
                DefaultEncoderFactory.Builder(appContext)
                    .setEnableFallback(true)
                    .setRequestedVideoEncoderSettings(videoEncoderSettings)
                    .build()
            val mediaItem =
                MediaItem.Builder()
                    .setUri(request.sourceUri)
                    .setMimeType(MimeTypes.VIDEO_H264)
                    .build()
            val editedItem =
                EditedMediaItem.Builder(mediaItem)
                    .setFrameRate(DEFAULT_PROXY_FRAME_RATE)
                    .setRemoveAudio(true)
                    .setEffects(
                        Effects(
                            emptyList(),
                            listOf(
                                Presentation.createForWidthAndHeight(
                                    managed.targetWidth,
                                    managed.targetHeight,
                                    Presentation.LAYOUT_SCALE_TO_FIT,
                                ),
                            ),
                        ),
                    ).build()
            val sequence =
                EditedMediaItemSequence.Builder(setOf(C.TRACK_TYPE_VIDEO))
                    .addItem(editedItem)
                    .build()
            val composition = Composition.Builder(listOf(sequence)).build()
            val transformer =
                Transformer.Builder(appContext)
                    .setVideoMimeType(MimeTypes.VIDEO_H264)
                    .setEncoderFactory(encoderFactory)
                    .setEnsureFileStartsOnVideoFrameEnabled(true)
                    .addListener(
                        object : Transformer.Listener {
                            override fun onCompleted(
                                composition: Composition,
                                exportResult: ExportResult,
                            ) {
                                synchronized(this@Stage5ScrubProxyManager) {
                                    val current = proxies[request.assetId] ?: return
                                    if (current !== managed) {
                                        return
                                    }
                                    managed.state = Stage5ScrubProxyState.READY
                                    managed.previewUri = Uri.fromFile(managed.outputFile).toString()
                                    managed.error = null
                                    managed.transformer?.removeAllListeners()
                                    managed.transformer = null
                                }
                            }

                            override fun onError(
                                composition: Composition,
                                exportResult: ExportResult,
                                exportException: ExportException,
                            ) {
                                synchronized(this@Stage5ScrubProxyManager) {
                                    val current = proxies[request.assetId] ?: return
                                    if (current !== managed) {
                                        return
                                    }
                                    managed.state = Stage5ScrubProxyState.FAILED
                                    managed.previewUri = null
                                    managed.error =
                                        exportException.message ?: "Unable to generate scrub proxy."
                                    managed.transformer?.removeAllListeners()
                                    managed.transformer = null
                                    cleanupOutputFile(managed.outputFile)
                                }
                            }
                        },
                    ).build()
            synchronized(this) {
                val current = proxies[request.assetId]
                if (current !== managed) {
                    transformer.cancel()
                    transformer.removeAllListeners()
                    return
                }
                managed.transformer = transformer
            }
            transformer.start(composition, managed.outputFile.absolutePath)
        } catch (error: Exception) {
            synchronized(this) {
                val current = proxies[request.assetId]
                if (current !== managed) {
                    return
                }
                managed.state = Stage5ScrubProxyState.FAILED
                managed.previewUri = null
                managed.error = error.message ?: "Unable to initialize scrub proxy generation."
                managed.transformer?.removeAllListeners()
                managed.transformer = null
                cleanupOutputFile(managed.outputFile)
            }
        }
    }

    private fun cleanupOutputFile(file: File) {
        if (file.exists()) {
            file.delete()
        }
    }

    private fun resolveBitrate(durationMs: Long): Int =
        if (durationMs > LONG_FORM_PROXY_THRESHOLD_MS) {
            LONG_FORM_PROXY_BITRATE
        } else {
            DEFAULT_PROXY_BITRATE
        }

    private fun resolveOutputSize(request: Stage5ScrubProxyRequest): Pair<Int, Int> {
        val sourceWidth = request.sourceWidth?.takeIf { it > 0 }
        val sourceHeight = request.sourceHeight?.takeIf { it > 0 }
        val longSideTarget =
            if (request.durationMs > LONG_FORM_PROXY_THRESHOLD_MS) {
                LONG_FORM_PROXY_LONG_SIDE_PX
            } else {
                DEFAULT_PROXY_LONG_SIDE_PX
            }
        if (sourceWidth == null || sourceHeight == null) {
            return 270 to longSideTarget
        }
        val isLandscape = sourceWidth >= sourceHeight
        val aspectRatio = sourceWidth.toDouble() / sourceHeight.toDouble()
        val resolved =
            if (isLandscape) {
                val width = longSideTarget
                val height = (width / aspectRatio).roundToInt()
                width to height
            } else {
                val height = longSideTarget
                val width = (height * aspectRatio).roundToInt()
                width to height
            }
        return evenDimension(resolved.first) to evenDimension(resolved.second)
    }

    private fun evenDimension(value: Int): Int {
        val safe = value.coerceAtLeast(2)
        return if (safe % 2 == 0) safe else safe - 1
    }

    private fun buildProxyFileName(
        request: Stage5ScrubProxyRequest,
        outputSize: Pair<Int, Int>,
    ): String {
        val digest =
            MessageDigest.getInstance("SHA-1")
                .digest(
                    "${request.assetId}|${request.sourceUri}|${outputSize.first}x${outputSize.second}"
                        .toByteArray(),
                )
        val hex =
            digest.joinToString(separator = "") { byte ->
                "%02x".format(byte)
            }
        return "proxy_$hex.mp4"
    }

    private inner class ManagedProxy(
        val request: Stage5ScrubProxyRequest,
        val outputFile: File,
        val targetWidth: Int,
        val targetHeight: Int,
    ) {
        var state: Stage5ScrubProxyState = Stage5ScrubProxyState.PREPARING
        var previewUri: String? = null
        var error: String? = null
        var transformer: Transformer? = null

        fun matches(other: Stage5ScrubProxyRequest): Boolean =
            request.assetId == other.assetId &&
                request.sourceUri == other.sourceUri &&
                request.durationMs == other.durationMs &&
                request.sourceWidth == other.sourceWidth &&
                request.sourceHeight == other.sourceHeight

        fun toStatus(): Stage5ScrubProxyStatus =
            Stage5ScrubProxyStatus(
                assetId = request.assetId,
                sourceUri = request.sourceUri,
                state = state,
                previewUri = previewUri,
                targetWidth = targetWidth,
                targetHeight = targetHeight,
                error = error,
            )

        fun dispose() {
            transformer?.cancel()
            transformer?.removeAllListeners()
            transformer = null
            if (state != Stage5ScrubProxyState.READY) {
                cleanupOutputFile(outputFile)
            }
        }
    }
}
