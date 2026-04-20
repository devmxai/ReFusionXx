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
import java.nio.file.Files
import java.nio.file.StandardCopyOption
import java.security.MessageDigest
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.CopyOnWriteArraySet
import kotlin.math.roundToInt

interface Stage5ScrubPreviewProxyListener {
    fun onProxyReady(sourceUri: String) = Unit
}

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
        private const val PROXY_DURATION_TOLERANCE_MS = 1_000L
        private const val TEMP_PROXY_SUFFIX = ".partial"
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
        val tempOutputFile: File,
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
    private val sourceDurationMsCache = ConcurrentHashMap<String, Long>()
    private val listeners = CopyOnWriteArraySet<Stage5ScrubPreviewProxyListener>()

    fun addListener(listener: Stage5ScrubPreviewProxyListener) {
        listeners.add(listener)
    }

    fun removeListener(listener: Stage5ScrubPreviewProxyListener) {
        listeners.remove(listener)
    }

    fun ensurePreviewMedia(
        sourceUri: String,
        previewUriHint: String? = null,
    ) {
        if (sourceUri.isBlank()) {
            return
        }
        if (resolveValidatedPreviewHint(sourceUri, previewUriHint) != null) {
            return
        }
        val entry =
            entries.computeIfAbsent(sourceUri) {
                val fileHash = hashString(sourceUri)
                val outputFile = File(proxyDirectory, "$fileHash.mp4")
                ProxyEntry(
                    outputFile = outputFile,
                    tempOutputFile = File(proxyDirectory, "$fileHash$TEMP_PROXY_SUFFIX.mp4"),
                    state = ProxyState.PREPARING,
                )
            }
        if (entry.state == ProxyState.READY &&
            entry.outputFile.isFile &&
            entry.outputFile.length() > 0L
        ) {
            return
        }
        runOnProxyThread {
            synchronized(entry) {
                if (entries[sourceUri] !== entry) {
                    return@runOnProxyThread
                }
                if (entry.state == ProxyState.READY &&
                    entry.outputFile.isFile &&
                    entry.outputFile.length() > 0L
                ) {
                    return@runOnProxyThread
                }
                if (promoteExistingProxyIfValid(sourceUri, entry)) {
                    return@runOnProxyThread
                }
                if (entry.transformer != null) {
                    return@runOnProxyThread
                }
                entry.outputFile.parentFile?.mkdirs()
                if (!deleteIfExists(entry.tempOutputFile)) {
                    entry.failure = "Unable to replace temporary scrub preview proxy."
                    entry.state = ProxyState.FAILED
                    return@runOnProxyThread
                }
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
                                    val shouldNotifyReady =
                                        synchronized(entry) {
                                        entry.transformer = null
                                        promoteGeneratedProxyIfValid(
                                            sourceUri = sourceUri,
                                            entry = entry,
                                        )
                                    }
                                    if (shouldNotifyReady) {
                                        notifyProxyReady(sourceUri)
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
                                        deleteIfExists(entry.tempOutputFile)
                                    }
                                }
                            },
                        )
                        .build()
                entry.transformer = transformer
                entry.state = ProxyState.PREPARING
                entry.failure = null
                transformer.start(composition, entry.tempOutputFile.absolutePath)
            }
        }
    }

    fun resolvePlaybackUri(
        sourceUri: String,
        previewUriHint: String? = null,
    ): ProxyResolution {
        val validatedHint = resolveValidatedPreviewHint(sourceUri, previewUriHint)
        if (validatedHint != null) {
            return ProxyResolution(
                playbackUri = validatedHint,
                proxyUri = validatedHint,
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
                entry.value.tempOutputFile.delete()
                iterator.remove()
                sourceDurationMsCache.remove(entry.key)
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
            sourceDurationMsCache.clear()
            proxyThread.quitSafely()
        }
    }

    private fun notifyProxyReady(sourceUri: String) {
        listeners.forEach { listener ->
            listener.onProxyReady(sourceUri)
        }
    }

    private fun runOnProxyThread(block: () -> Unit) {
        if (Looper.myLooper() == proxyThread.looper) {
            block()
        } else {
            proxyHandler.post(block)
        }
    }

    private fun resolveValidatedPreviewHint(
        sourceUri: String,
        previewUriHint: String?,
    ): String? {
        val candidate = normalizePlayableUri(previewUriHint) ?: return null
        return candidate.takeIf {
            previewCoversSourceDuration(
                sourceUri = sourceUri,
                previewUri = candidate,
            )
        }
    }

    private fun promoteExistingProxyIfValid(
        sourceUri: String,
        entry: ProxyEntry,
    ): Boolean {
        if (!entry.outputFile.isFile || entry.outputFile.length() <= 0L) {
            deleteIfExists(entry.tempOutputFile)
            entry.state = ProxyState.PREPARING
            return false
        }
        if (previewCoversSourceDuration(sourceUri, entry.outputFile.absolutePath)) {
            entry.failure = null
            entry.state = ProxyState.READY
            deleteIfExists(entry.tempOutputFile)
            return true
        }
        val cachedPreviewDurationMs = resolveVideoDurationMs(entry.outputFile.absolutePath)
        deleteIfExists(entry.outputFile)
        deleteIfExists(entry.tempOutputFile)
        entry.failure =
            buildDurationMismatchFailure(
                sourceDurationMs = resolveSourceDurationMs(sourceUri),
                previewDurationMs = cachedPreviewDurationMs,
            )
        entry.state = ProxyState.PREPARING
        return false
    }

    private fun promoteGeneratedProxyIfValid(
        sourceUri: String,
        entry: ProxyEntry,
    ): Boolean {
        if (!entry.tempOutputFile.isFile || entry.tempOutputFile.length() <= 0L) {
            entry.failure = "Generated scrub preview proxy file is missing."
            entry.state = ProxyState.FAILED
            deleteIfExists(entry.tempOutputFile)
            return false
        }
        val previewDurationMs = resolveVideoDurationMs(entry.tempOutputFile.absolutePath)
        val sourceDurationMs = resolveSourceDurationMs(sourceUri)
        if (!previewCoversSourceDuration(sourceUri, entry.tempOutputFile.absolutePath)) {
            entry.failure =
                buildDurationMismatchFailure(
                    sourceDurationMs = sourceDurationMs,
                    previewDurationMs = previewDurationMs,
                )
            entry.state = ProxyState.FAILED
            deleteIfExists(entry.tempOutputFile)
            deleteIfExists(entry.outputFile)
            return false
        }
        if (!replaceFileAtomically(entry.tempOutputFile, entry.outputFile)) {
            entry.failure = "Unable to finalize scrub preview proxy file."
            entry.state = ProxyState.FAILED
            deleteIfExists(entry.tempOutputFile)
            deleteIfExists(entry.outputFile)
            return false
        }
        entry.failure = null
        entry.state = ProxyState.READY
        return true
    }

    private fun previewCoversSourceDuration(
        sourceUri: String,
        previewUri: String,
    ): Boolean {
        val previewDurationMs = resolveVideoDurationMs(previewUri)
        if (previewDurationMs <= 0L) {
            return false
        }
        val sourceDurationMs = resolveSourceDurationMs(sourceUri)
        if (sourceDurationMs <= 0L) {
            return true
        }
        return previewDurationMs + PROXY_DURATION_TOLERANCE_MS >= sourceDurationMs
    }

    private fun resolveSourceDurationMs(sourceUri: String): Long =
        sourceDurationMsCache.computeIfAbsent(sourceUri, ::resolveVideoDurationMs)

    private fun resolveVideoDurationMs(uriString: String): Long {
        var retriever: MediaMetadataRetriever? = null
        return try {
            retriever = MediaMetadataRetriever()
            applyRetrieverDataSource(retriever, uriString)
            retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION)
                ?.toLongOrNull()
                ?: 0L
        } catch (_: Throwable) {
            0L
        } finally {
            retriever?.release()
        }
    }

    private fun replaceFileAtomically(
        sourceFile: File,
        targetFile: File,
    ): Boolean =
        runCatching {
            targetFile.parentFile?.mkdirs()
            Files.move(
                sourceFile.toPath(),
                targetFile.toPath(),
                StandardCopyOption.REPLACE_EXISTING,
                StandardCopyOption.ATOMIC_MOVE,
            )
        }.recoverCatching {
            if (targetFile.exists() && !targetFile.delete()) {
                error("Unable to replace existing scrub preview proxy output.")
            }
            if (!sourceFile.renameTo(targetFile)) {
                error("Unable to move scrub preview proxy into place.")
            }
        }.isSuccess

    private fun buildDurationMismatchFailure(
        sourceDurationMs: Long,
        previewDurationMs: Long,
    ): String =
        "Rejected scrub preview proxy with duration $previewDurationMs ms for source $sourceDurationMs ms."

    private fun deleteIfExists(file: File): Boolean = !file.exists() || file.delete()

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
