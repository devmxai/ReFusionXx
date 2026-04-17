package com.refusion.app

import android.content.Context
import android.media.MediaMetadataRetriever
import android.net.Uri
import android.os.Handler
import android.os.HandlerThread
import android.os.Looper
import androidx.media3.common.C
import androidx.media3.common.Effect
import androidx.media3.common.MediaItem
import androidx.media3.common.MimeTypes
import androidx.media3.common.util.UnstableApi
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

@UnstableApi
class Stage5ScrubPreviewProxyManager(
    context: Context,
) {
    companion object {
        private const val LONG_FORM_THRESHOLD_MS = 10 * 60 * 1000L
        private const val SHORT_FORM_TARGET_HEIGHT = 720
        private const val LONG_FORM_TARGET_HEIGHT = 540
        private const val SHORT_FORM_TARGET_BITRATE = 4_000_000
        private const val LONG_FORM_TARGET_BITRATE = 2_500_000
        private const val TARGET_I_FRAME_INTERVAL_SECONDS = 0.25f
    }

    data class ProxyResolution(
        val playbackUri: String,
        val proxyUri: String? = null,
        val isProxyReady: Boolean = false,
    )

    private enum class ProxyState {
        PREPARING,
        READY,
        FAILED,
    }

    private data class ProxySpec(
        val width: Int,
        val height: Int,
        val bitrate: Int,
    )

    private data class ProxyEntry(
        val outputFile: File,
        var state: ProxyState,
        var transformer: Transformer? = null,
        var failure: String? = null,
    ) {
        val outputUri: String
            get() = Uri.fromFile(outputFile).toString()
    }

    private val appContext = context.applicationContext
    private val proxyDirectory =
        File(appContext.cacheDir, "stage5_scrub_preview_proxies").apply {
            mkdirs()
        }
    private val proxyThread =
        HandlerThread("Stage5ScrubPreviewProxyThread").apply {
            start()
        }
    private val proxyHandler = Handler(proxyThread.looper)
    private val entries = ConcurrentHashMap<String, ProxyEntry>()

    fun ensurePreviewMedia(
        sourceUri: String,
        previewUriHint: String? = null,
    ) {
        if (sourceUri.isBlank()) {
            return
        }
        val normalizedHint = normalizePlayableUri(previewUriHint)
        if (normalizedHint != null) {
            return
        }
        val entry =
            entries.computeIfAbsent(sourceUri) {
                val outputFile = File(proxyDirectory, "${hashString(sourceUri)}.mp4")
                ProxyEntry(
                    outputFile = outputFile,
                    state =
                        if (outputFile.isFile && outputFile.length() > 0L) {
                            ProxyState.READY
                        } else {
                            ProxyState.PREPARING
                        },
                )
            }
        if (entry.state == ProxyState.READY && entry.outputFile.length() > 0L) {
            return
        }
        runOnProxyThread {
            synchronized(entry) {
                if (entries[sourceUri] !== entry) {
                    return@runOnProxyThread
                }
                if (entry.state == ProxyState.READY && entry.outputFile.length() > 0L) {
                    return@runOnProxyThread
                }
                if (entry.transformer != null) {
                    return@runOnProxyThread
                }
                entry.outputFile.parentFile?.mkdirs()
                if (entry.outputFile.exists() && !entry.outputFile.delete()) {
                    entry.failure = "Unable to replace existing scrub preview proxy."
                    entry.state = ProxyState.FAILED
                    return@runOnProxyThread
                }
                val proxySpec =
                    runCatching { resolveProxySpec(sourceUri) }
                        .getOrElse { error ->
                            entry.failure = error.message ?: error.toString()
                            entry.state = ProxyState.FAILED
                            return@runOnProxyThread
                        }
                val encoderFactory =
                    DefaultEncoderFactory.Builder(appContext)
                        .setEnableFallback(true)
                        .setRequestedVideoEncoderSettings(
                            VideoEncoderSettings.Builder()
                                .setBitrate(proxySpec.bitrate)
                                .setiFrameIntervalSeconds(TARGET_I_FRAME_INTERVAL_SECONDS)
                                .build(),
                        )
                        .build()
                val videoEffects =
                    listOf<Effect>(
                        Presentation.createForWidthAndHeight(
                            proxySpec.width,
                            proxySpec.height,
                            Presentation.LAYOUT_SCALE_TO_FIT,
                        ),
                    )
                val mediaItem = MediaItem.fromUri(Uri.parse(sourceUri))
                val editedMediaItem =
                    EditedMediaItem.Builder(mediaItem)
                        .setRemoveAudio(true)
                        .setEffects(Effects(emptyList(), videoEffects))
                        .build()
                val sequence =
                    EditedMediaItemSequence.Builder(setOf(C.TRACK_TYPE_VIDEO))
                        .addItem(editedMediaItem)
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
                                    synchronized(entry) {
                                        entry.transformer = null
                                        entry.failure = null
                                        entry.state =
                                            if (entry.outputFile.isFile &&
                                                entry.outputFile.length() > 0L
                                            ) {
                                                ProxyState.READY
                                            } else {
                                                ProxyState.FAILED
                                            }
                                    }
                                }

                                override fun onError(
                                    composition: Composition,
                                    exportResult: ExportResult,
                                    exportException: ExportException,
                                ) {
                                    synchronized(entry) {
                                        entry.transformer = null
                                        entry.failure =
                                            exportException.message
                                                ?: exportException.errorCodeName
                                        entry.state = ProxyState.FAILED
                                    }
                                }
                            },
                        )
                        .build()
                entry.transformer = transformer
                entry.state = ProxyState.PREPARING
                entry.failure = null
                transformer.start(composition, entry.outputFile.absolutePath)
            }
        }
    }

    fun resolvePlaybackUri(
        sourceUri: String,
        previewUriHint: String? = null,
    ): ProxyResolution {
        val normalizedHint = normalizePlayableUri(previewUriHint)
        if (normalizedHint != null) {
            return ProxyResolution(
                playbackUri = normalizedHint,
                proxyUri = normalizedHint,
                isProxyReady = true,
            )
        }
        val entry = entries[sourceUri]
        if (entry != null &&
            entry.state == ProxyState.READY &&
            entry.outputFile.isFile &&
            entry.outputFile.length() > 0L
        ) {
            return ProxyResolution(
                playbackUri = entry.outputUri,
                proxyUri = entry.outputUri,
                isProxyReady = true,
            )
        }
        return ProxyResolution(playbackUri = sourceUri)
    }

    fun pruneEntries(activeSourceUris: Set<String>) {
        val retainedSourceUris = activeSourceUris.toSet()
        runOnProxyThread {
            val iterator = entries.entries.iterator()
            while (iterator.hasNext()) {
                val entry = iterator.next()
                if (entry.key in retainedSourceUris) {
                    continue
                }
                synchronized(entry.value) {
                    entry.value.transformer?.cancel()
                    entry.value.transformer = null
                }
                entry.value.outputFile.delete()
                iterator.remove()
            }
        }
    }

    fun release() {
        val releaseEntries = entries.values.toList()
        runOnProxyThread {
            releaseEntries.forEach { entry ->
                synchronized(entry) {
                    entry.transformer?.cancel()
                    entry.transformer = null
                }
            }
            entries.clear()
            proxyThread.quitSafely()
        }
    }

    private fun runOnProxyThread(block: () -> Unit) {
        if (Looper.myLooper() == proxyThread.looper) {
            block()
        } else {
            proxyHandler.post(block)
        }
    }

    private fun resolveProxySpec(sourceUri: String): ProxySpec {
        var retriever: MediaMetadataRetriever? = null
        return try {
            retriever = MediaMetadataRetriever()
            applyRetrieverDataSource(retriever, sourceUri)
            val rawWidth =
                retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_WIDTH)
                    ?.toIntOrNull()
                    ?: SHORT_FORM_TARGET_HEIGHT
            val rawHeight =
                retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_HEIGHT)
                    ?.toIntOrNull()
                    ?: SHORT_FORM_TARGET_HEIGHT
            val rotation =
                retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_ROTATION)
                    ?.toIntOrNull()
                    ?: 0
            val durationMs =
                retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION)
                    ?.toLongOrNull()
                    ?: 0L
            val (sourceWidth, sourceHeight) =
                if (rotation == 90 || rotation == 270) {
                    rawHeight to rawWidth
                } else {
                    rawWidth to rawHeight
                }
            val targetHeight =
                if (durationMs >= LONG_FORM_THRESHOLD_MS) {
                    LONG_FORM_TARGET_HEIGHT
                } else {
                    SHORT_FORM_TARGET_HEIGHT
                }
            val aspectRatio =
                sourceWidth.toDouble() / sourceHeight.toDouble().coerceAtLeast(1.0)
            val targetWidth =
                ensureEven(
                    (targetHeight * aspectRatio).roundToInt().coerceAtLeast(targetHeight / 2),
                )
            ProxySpec(
                width = targetWidth.coerceAtLeast(2),
                height = ensureEven(targetHeight).coerceAtLeast(2),
                bitrate =
                    if (durationMs >= LONG_FORM_THRESHOLD_MS) {
                        LONG_FORM_TARGET_BITRATE
                    } else {
                        SHORT_FORM_TARGET_BITRATE
                    },
            )
        } finally {
            retriever?.release()
        }
    }

    private fun normalizePlayableUri(previewUriHint: String?): String? {
        val candidate = previewUriHint?.trim()?.takeIf(String::isNotEmpty) ?: return null
        val parsed = Uri.parse(candidate)
        if (!parsed.scheme.isNullOrBlank()) {
            return candidate
        }
        val file = File(candidate)
        if (!file.isFile) {
            return null
        }
        return Uri.fromFile(file).toString()
    }

    private fun applyRetrieverDataSource(
        retriever: MediaMetadataRetriever,
        uriString: String,
    ) {
        val parsedUri = Uri.parse(uriString)
        if (parsedUri.scheme.isNullOrBlank()) {
            retriever.setDataSource(uriString)
        } else {
            retriever.setDataSource(appContext, parsedUri)
        }
    }

    private fun hashString(value: String): String {
        val digest = MessageDigest.getInstance("SHA-256")
        return digest.digest(value.toByteArray()).joinToString(separator = "") { byte ->
            "%02x".format(byte)
        }
    }

    private fun ensureEven(value: Int): Int = if (value % 2 == 0) value else value + 1
}
