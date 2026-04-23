package com.refusion.app

import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.BlurMaskFilter
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.PorterDuff
import android.graphics.PorterDuffXfermode
import android.graphics.RectF
import android.graphics.Typeface
import android.media.MediaCodecInfo
import android.media.MediaExtractor
import android.media.MediaMetadataRetriever
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.os.Handler
import android.os.Looper
import android.provider.MediaStore
import android.text.Layout
import android.text.StaticLayout
import android.text.TextPaint
import android.text.TextDirectionHeuristics
import android.util.Log
import androidx.core.content.FileProvider
import androidx.media3.common.C
import androidx.media3.common.Effect
import androidx.media3.common.MediaItem
import androidx.media3.common.MimeTypes
import androidx.media3.common.audio.SpeedProvider
import androidx.media3.effect.AlphaScale
import androidx.media3.effect.CanvasOverlay
import androidx.media3.effect.GaussianBlur
import androidx.media3.effect.OverlayEffect
import androidx.media3.effect.Presentation
import androidx.media3.effect.TextureOverlay
import androidx.media3.effect.TimestampWrapper
import androidx.media3.transformer.Composition
import androidx.media3.transformer.AudioEncoderSettings
import androidx.media3.transformer.DefaultEncoderFactory
import androidx.media3.transformer.EditedMediaItem
import androidx.media3.transformer.EditedMediaItemSequence
import androidx.media3.transformer.EncoderUtil
import androidx.media3.transformer.Effects
import androidx.media3.transformer.ExportException
import androidx.media3.transformer.ExportResult
import androidx.media3.transformer.ProgressHolder
import androidx.media3.transformer.Transformer
import androidx.media3.transformer.VideoEncoderSettings
import io.flutter.plugin.common.EventChannel
import java.io.File
import java.io.IOException
import java.util.Locale
import java.util.UUID
import kotlin.math.PI
import kotlin.math.abs
import kotlin.math.cos
import kotlin.math.exp
import kotlin.math.pow
import kotlin.math.roundToInt
import kotlin.math.roundToLong
import kotlin.math.sin
import kotlin.math.sqrt

class Stage6ExportManager(
    private val appContext: Context,
    private val previewTransportManager: Stage5TransportManager? = null,
) {
    companion object {
        const val METHOD_CHANNEL_NAME = "com.refusion.app/stage6_export"
        const val EVENT_CHANNEL_NAME = "com.refusion.app/stage6_export_events"
        const val SUPPORTED_EXPORT_GRAPH_SCHEMA_VERSION = "export-graph.v1alpha1"
        private val SUPPORTED_EXPORT_INTERPOLATION_KINDS =
            setOf(
                "linear",
                "hold",
                "easeIn",
                "easeOut",
                "easeInOut",
                "cubicBezier",
                "spring",
                "bounce",
                "elastic",
            )
        private val SUPPORTED_EXPORT_CHANNEL_EDGE_MODES = setOf("clamp")
        private const val CURRENT_CANONICAL_EFFECTS_BACKEND_ID = "media3CanvasOverlayRenderer"
        private const val TAG = "Stage6ExportManager"
    }

    private val mainHandler = Handler(Looper.getMainLooper())
    private var eventSink: EventChannel.EventSink? = null
    private var activeJobId: String? = null
    private var activePreset: String? = null
    private var activeSelectedVideoCodec: String? = null
    private var activeBitrateMode: String? = null
    private var activeTransformer: Transformer? = null
    private var activeOutputPath: String? = null
    private var activeMotionTextParityDiagnostics: NativeMotionTextParityDiagnostics? = null
    private var activeCanonicalEffectsDiagnostics: NativeCanonicalEffectsDiagnostics? = null
    private var activeAuthoredVisualSurfaceDiagnostics: NativeAuthoredVisualSurfaceDiagnostics? = null
    private var activeVisualAssemblyDiagnostics: NativeVisualAssemblyDiagnostics? = null
    private var previewSuspendedForActiveExport = false
    private val progressHolder = ProgressHolder()
    private val progressEmitter =
        object : Runnable {
            override fun run() {
                val transformer = activeTransformer ?: return
                val jobId = activeJobId ?: return
                val progressState = transformer.getProgress(progressHolder)
                if (jobId != activeJobId) {
                    return
                }
                val event =
                    if (progressState == Transformer.PROGRESS_STATE_AVAILABLE) {
                        mapOf(
                            "jobId" to jobId,
                            "status" to "progress",
                            "phase" to "exporting",
                            "progress" to (progressHolder.progress / 100.0),
                            "outputPath" to activeOutputPath,
                            "motionTextParity" to activeMotionTextParityDiagnostics?.toMap(),
                            "canonicalEffectsDiagnostics" to
                                activeCanonicalEffectsDiagnostics?.toMap(),
                            "authoredVisualSurfaceDiagnostics" to
                                activeAuthoredVisualSurfaceDiagnostics?.toMap(),
                            "visualAssemblyDiagnostics" to
                                activeVisualAssemblyDiagnostics?.toMap(),
                        )
                    } else {
                        mapOf(
                            "jobId" to jobId,
                            "status" to "started",
                            "phase" to "preparing_media",
                            "progress" to 0.0,
                            "outputPath" to activeOutputPath,
                            "motionTextParity" to activeMotionTextParityDiagnostics?.toMap(),
                            "canonicalEffectsDiagnostics" to
                                activeCanonicalEffectsDiagnostics?.toMap(),
                            "authoredVisualSurfaceDiagnostics" to
                                activeAuthoredVisualSurfaceDiagnostics?.toMap(),
                            "visualAssemblyDiagnostics" to
                                activeVisualAssemblyDiagnostics?.toMap(),
                        )
                    }
                emitEvent(event)
                mainHandler.postDelayed(this, 250L)
            }
        }

    fun attachEventSink(events: EventChannel.EventSink) {
        eventSink = events
    }

    fun detachEventSink() {
        eventSink = null
    }

    fun exportTimeline(
        compositionMap: Map<String, Any?>,
        exportProfileMap: Map<String, Any?>,
        requestedFileName: String?,
    ): Map<String, Any?> {
        if (activeJobId != null) {
            return mapOf(
                "status" to "failed",
                "phase" to "busy",
                "progress" to 0.0,
                "error" to "An export job is already running.",
            )
        }
        val preflightVisualAssemblyDiagnostics =
            buildPreflightVisualAssemblyDiagnostics(compositionMap)
        val preflightCanonicalEffectsDiagnostics =
            buildPreflightCanonicalEffectsDiagnostics(compositionMap)
        val preflightAuthoredVisualSurfaceDiagnostics =
            buildPreflightAuthoredVisualSurfaceDiagnostics(compositionMap)
        val validationError = validateBaselineComposition(compositionMap)
        if (validationError != null) {
            return mapOf(
                "status" to "failed",
                "phase" to "invalid_composition",
                "progress" to 0.0,
                "error" to validationError,
                "canonicalEffectsDiagnostics" to
                    preflightCanonicalEffectsDiagnostics?.toMap(),
                "authoredVisualSurfaceDiagnostics" to
                    preflightAuthoredVisualSurfaceDiagnostics?.toMap(),
                "visualAssemblyDiagnostics" to preflightVisualAssemblyDiagnostics?.toMap(),
            )
        }
        val requestedProfile = resolveRequestedExportProfile(exportProfileMap)
        val preset = requestedProfile.resolutionPreset
        val expectedOutputFrameRate = resolveOutputFrameRate(compositionMap, requestedProfile.frameRate)
        val exportComposition =
            buildExportComposition(
                compositionMap = compositionMap,
                preset = preset,
                requestedFrameRate = expectedOutputFrameRate,
            )
        val encoderPlan =
            try {
                resolveEncoderPlan(
                    outputSize = exportComposition.outputSize,
                    outputFrameRate = expectedOutputFrameRate,
                    expectsAudio = exportComposition.expectsAudio,
                    requestedProfile = requestedProfile,
                )
            } catch (error: IllegalArgumentException) {
                return mapOf(
                    "status" to "failed",
                    "phase" to "unsupported_export_profile",
                    "progress" to 0.0,
                    "preset" to preset,
                    "requestedFrameRate" to expectedOutputFrameRate,
                    "selectedVideoCodec" to requestedProfile.videoCodec,
                    "bitrateMode" to requestedProfile.bitrateMode,
                    "error" to (error.message ?: "Requested export profile is not supported."),
                    "canonicalEffectsDiagnostics" to
                        preflightCanonicalEffectsDiagnostics?.toMap(),
                    "authoredVisualSurfaceDiagnostics" to
                        preflightAuthoredVisualSurfaceDiagnostics?.toMap(),
                    "visualAssemblyDiagnostics" to preflightVisualAssemblyDiagnostics?.toMap(),
                )
            }
        val jobId = "export-${UUID.randomUUID()}"
        activeJobId = jobId
        activePreset = preset
        activeSelectedVideoCodec = encoderPlan?.selectedVideoCodec
        activeBitrateMode = requestedProfile.bitrateMode
        val clipCount = exportComposition.clips.size
        val executionDurationMs = exportComposition.executionDurationMs
        val timelineDurationMs = exportComposition.timelineDurationMs
        val outputPath =
            createOutputFile(
                    preset = preset,
                    requestedFileName = requestedFileName,
                )
                .absolutePath
        activeOutputPath = outputPath
        activeMotionTextParityDiagnostics = exportComposition.motionTextParityDiagnostics
        activeCanonicalEffectsDiagnostics = exportComposition.canonicalEffectsDiagnostics
        activeAuthoredVisualSurfaceDiagnostics = exportComposition.authoredVisualSurfaceDiagnostics
        activeVisualAssemblyDiagnostics = exportComposition.visualAssemblyDiagnostics
        suspendPreviewForActiveExport()
        val transformer =
            try {
                val encoderFactoryBuilder =
                    DefaultEncoderFactory.Builder(appContext)
                        .setEnableFallback(true)
                encoderPlan?.videoEncoderSettings?.let { videoEncoderSettings ->
                    encoderFactoryBuilder.setRequestedVideoEncoderSettings(videoEncoderSettings)
                }
                encoderPlan?.audioEncoderSettings?.let { audioEncoderSettings ->
                    encoderFactoryBuilder.setRequestedAudioEncoderSettings(audioEncoderSettings)
                }
                Transformer.Builder(appContext)
                    .setAudioMimeType(encoderPlan?.audioMimeType ?: MimeTypes.AUDIO_AAC)
                    .setVideoMimeType(encoderPlan?.videoMimeType ?: MimeTypes.VIDEO_H264)
                    .setEncoderFactory(encoderFactoryBuilder.build())
                    .setEnsureFileStartsOnVideoFrameEnabled(true)
                    .addListener(
                        object : Transformer.Listener {
                        override fun onCompleted(
                            composition: Composition,
                            exportResult: ExportResult,
                        ) {
                            if (jobId != activeJobId) {
                                return
                            }
                            val validation =
                                validateOutputFile(
                                    outputPath = outputPath,
                                    expectedDurationMs = exportComposition.executionDurationMs,
                                    timelineDurationMs = exportComposition.timelineDurationMs,
                                    expectedHasAudio = exportComposition.expectsAudio,
                                    expectedOutputSize = exportComposition.outputSize,
                                    expectedOutputFrameRate = expectedOutputFrameRate,
                                    expectedVideoTrackMime = encoderPlan?.videoMimeType,
                                    expectedAudioTrackMime = encoderPlan?.audioMimeType,
                                )
                            if (!validation.isValid) {
                                clearActiveExport(jobId)
                                val cleanupPerformed = deleteOutputFileIfPresent(outputPath)
                                emitEvent(
                                    mapOf(
                                        "jobId" to jobId,
                                        "status" to "failed",
                                        "phase" to "validation_failed",
                                        "progress" to 1.0,
                                        "outputPath" to outputPath,
                                        "validation" to validation.toMap(),
                                        "cleanupPerformed" to cleanupPerformed,
                                        "motionTextParity" to
                                            exportComposition.motionTextParityDiagnostics?.toMap(),
                                        "canonicalEffectsDiagnostics" to
                                            exportComposition.canonicalEffectsDiagnostics?.toMap(),
                                        "authoredVisualSurfaceDiagnostics" to
                                            exportComposition.authoredVisualSurfaceDiagnostics?.toMap(),
                                        "visualAssemblyDiagnostics" to
                                            exportComposition.visualAssemblyDiagnostics?.toMap(),
                                        "error" to
                                            (validation.failureReason
                                                ?: "Export output validation failed."),
                                    ),
                                )
                                return
                            }
                            emitEvent(
                                mapOf(
                                    "jobId" to jobId,
                                    "status" to "completed",
                                    "phase" to "completed",
                                    "progress" to 1.0,
                                    "outputPath" to outputPath,
                                    "cleanupPerformed" to false,
                                    "validation" to validation.toMap(),
                                    "motionTextParity" to
                                        exportComposition.motionTextParityDiagnostics?.toMap(),
                                    "canonicalEffectsDiagnostics" to
                                        exportComposition.canonicalEffectsDiagnostics?.toMap(),
                                    "authoredVisualSurfaceDiagnostics" to
                                        exportComposition.authoredVisualSurfaceDiagnostics?.toMap(),
                                    "visualAssemblyDiagnostics" to
                                        exportComposition.visualAssemblyDiagnostics?.toMap(),
                                ),
                            )
                            clearActiveExport(jobId)
                        }

                        override fun onError(
                            composition: Composition,
                            exportResult: ExportResult,
                            exportException: ExportException,
                        ) {
                            Log.e(
                                TAG,
                                "Export failed: code=${exportException.errorCodeName} message=${exportException.message}",
                                exportException,
                            )
                            if (jobId != activeJobId) {
                                return
                            }
                            clearActiveExport(jobId)
                            val cleanupPerformed = deleteOutputFileIfPresent(outputPath)
                            emitEvent(
                                mapOf(
                                    "jobId" to jobId,
                                    "status" to "failed",
                                    "phase" to "failed",
                                    "progress" to 0.0,
                                    "outputPath" to outputPath,
                                    "cleanupPerformed" to cleanupPerformed,
                                    "motionTextParity" to
                                        exportComposition.motionTextParityDiagnostics?.toMap(),
                                    "canonicalEffectsDiagnostics" to
                                        exportComposition.canonicalEffectsDiagnostics?.toMap(),
                                    "authoredVisualSurfaceDiagnostics" to
                                        exportComposition.authoredVisualSurfaceDiagnostics?.toMap(),
                                    "visualAssemblyDiagnostics" to
                                        exportComposition.visualAssemblyDiagnostics?.toMap(),
                                    "error" to
                                        (exportException.message
                                            ?: "Media3 export failed."),
                                ),
                            )
                        }
                        },
                    ).build()
            } catch (error: Exception) {
                clearActiveExport(jobId)
                val cleanupPerformed = deleteOutputFileIfPresent(outputPath)
                return mapOf(
                    "jobId" to jobId,
                    "status" to "failed",
                    "phase" to "transformer_build_failed",
                    "progress" to 0.0,
                    "outputPath" to outputPath,
                    "cleanupPerformed" to cleanupPerformed,
                    "canonicalEffectsDiagnostics" to
                        exportComposition.canonicalEffectsDiagnostics?.toMap(),
                    "authoredVisualSurfaceDiagnostics" to
                        exportComposition.authoredVisualSurfaceDiagnostics?.toMap(),
                    "visualAssemblyDiagnostics" to
                        exportComposition.visualAssemblyDiagnostics?.toMap(),
                    "error" to
                        (error.message
                            ?: "Unable to initialize export transformer."),
                )
            }
        activeTransformer = transformer
        Log.i(
            TAG,
            "Starting export job=$jobId preset=$preset fps=$expectedOutputFrameRate codec=${encoderPlan?.selectedVideoCodec} size=${exportComposition.outputSize?.width}x${exportComposition.outputSize?.height} encoder=${encoderPlan?.encoderName} videoBitrate=${encoderPlan?.videoBitrate}",
        )
        val response =
            mapOf(
                "jobId" to jobId,
                "status" to "started",
                "phase" to "transformer_start",
                "progress" to 0.0,
                "preset" to preset,
                "requestedFrameRate" to expectedOutputFrameRate,
                "requestedVideoBitrate" to encoderPlan?.videoBitrate,
                "requestedAudioBitrate" to encoderPlan?.audioBitrate,
                "selectedEncoderName" to encoderPlan?.encoderName,
                "selectedVideoCodec" to encoderPlan?.selectedVideoCodec,
                "bitrateMode" to requestedProfile.bitrateMode,
                "requestedFileName" to requestedFileName,
                "clipCount" to clipCount,
                "durationMs" to executionDurationMs,
                "executionDurationMs" to executionDurationMs,
                "timelineDurationMs" to timelineDurationMs,
                "outputPath" to outputPath,
                "motionTextParity" to exportComposition.motionTextParityDiagnostics?.toMap(),
                "canonicalEffectsDiagnostics" to
                    exportComposition.canonicalEffectsDiagnostics?.toMap(),
                "authoredVisualSurfaceDiagnostics" to
                    exportComposition.authoredVisualSurfaceDiagnostics?.toMap(),
                "visualAssemblyDiagnostics" to
                    exportComposition.visualAssemblyDiagnostics?.toMap(),
            )
        try {
            transformer.start(exportComposition.composition, outputPath)
            emitEvent(response)
            mainHandler.removeCallbacks(progressEmitter)
            mainHandler.post(progressEmitter)
        } catch (error: Exception) {
            clearActiveExport(jobId)
            val cleanupPerformed = deleteOutputFileIfPresent(outputPath)
            emitEvent(
                mapOf(
                    "jobId" to jobId,
                    "status" to "failed",
                    "phase" to "start_failed",
                    "progress" to 0.0,
                    "outputPath" to outputPath,
                    "cleanupPerformed" to cleanupPerformed,
                    "motionTextParity" to exportComposition.motionTextParityDiagnostics?.toMap(),
                    "canonicalEffectsDiagnostics" to
                        exportComposition.canonicalEffectsDiagnostics?.toMap(),
                    "authoredVisualSurfaceDiagnostics" to
                        exportComposition.authoredVisualSurfaceDiagnostics?.toMap(),
                    "visualAssemblyDiagnostics" to
                        exportComposition.visualAssemblyDiagnostics?.toMap(),
                    "error" to (error.message ?: "Unable to start export."),
                ),
            )
        }
        return response
    }

    fun cancelExport(jobId: String): Map<String, Any?> {
        val wasActive = activeJobId == jobId
        if (wasActive) {
            val outputPath = activeOutputPath
            val transformer = activeTransformer
            val motionTextParityDiagnostics = activeMotionTextParityDiagnostics?.toMap()
            val canonicalEffectsDiagnostics = activeCanonicalEffectsDiagnostics?.toMap()
            val authoredVisualSurfaceDiagnostics = activeAuthoredVisualSurfaceDiagnostics?.toMap()
            val visualAssemblyDiagnostics = activeVisualAssemblyDiagnostics?.toMap()
            transformer?.cancel()
            clearActiveExport(jobId)
            val cleanupPerformed = deleteOutputFileIfPresent(outputPath)
            emitEvent(
                mapOf(
                    "jobId" to jobId,
                    "status" to "cancelled",
                    "phase" to "cancelled",
                    "progress" to 0.0,
                    "outputPath" to outputPath,
                    "cleanupPerformed" to cleanupPerformed,
                    "motionTextParity" to motionTextParityDiagnostics,
                    "canonicalEffectsDiagnostics" to canonicalEffectsDiagnostics,
                    "authoredVisualSurfaceDiagnostics" to authoredVisualSurfaceDiagnostics,
                    "visualAssemblyDiagnostics" to visualAssemblyDiagnostics,
                ),
            )
            return mapOf(
                "jobId" to jobId,
                "status" to "cancelled",
                "phase" to "cancelled",
                "progress" to 0.0,
                "cleanupPerformed" to cleanupPerformed,
                "motionTextParity" to motionTextParityDiagnostics,
                "canonicalEffectsDiagnostics" to canonicalEffectsDiagnostics,
                "authoredVisualSurfaceDiagnostics" to authoredVisualSurfaceDiagnostics,
                "visualAssemblyDiagnostics" to visualAssemblyDiagnostics,
            )
        }
        return mapOf(
            "jobId" to jobId,
            "status" to "cancelled",
            "phase" to "not_found",
            "progress" to 0.0,
            "cleanupPerformed" to false,
        )
    }

    fun openExportOutput(
        outputPath: String,
        mimeType: String?,
    ): Map<String, Any?> {
        val resolvedOutput =
            resolveOutputFile(outputPath, mimeType)
                ?: return mapOf(
                    "status" to "failed",
                    "error" to "Export output file does not exist.",
                )
        val openIntent =
            Intent(Intent.ACTION_VIEW)
                .setDataAndType(resolvedOutput.contentUri, resolvedOutput.mimeType)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        val chooserIntent =
            Intent.createChooser(openIntent, "Open export")
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        return try {
            appContext.startActivity(chooserIntent)
            mapOf(
                "status" to "opened",
                "outputPath" to outputPath,
            )
        } catch (error: Exception) {
            mapOf(
                "status" to "failed",
                "error" to (error.message ?: "Unable to open export output."),
                "outputPath" to outputPath,
            )
        }
    }

    fun shareExportOutput(
        outputPath: String,
        mimeType: String?,
    ): Map<String, Any?> {
        val resolvedOutput =
            resolveOutputFile(outputPath, mimeType)
                ?: return mapOf(
                    "status" to "failed",
                    "error" to "Export output file does not exist.",
                )
        val shareIntent =
            Intent(Intent.ACTION_SEND)
                .setType(resolvedOutput.mimeType)
                .putExtra(Intent.EXTRA_STREAM, resolvedOutput.contentUri)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        val chooserIntent =
            Intent.createChooser(shareIntent, "Share export")
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        return try {
            appContext.startActivity(chooserIntent)
            mapOf(
                "status" to "shared",
                "outputPath" to outputPath,
            )
        } catch (error: Exception) {
            mapOf(
                "status" to "failed",
                "error" to (error.message ?: "Unable to share export output."),
                "outputPath" to outputPath,
            )
        }
    }

    fun saveExportOutputToGallery(
        outputPath: String,
        mimeType: String?,
    ): Map<String, Any?> {
        val resolvedOutput =
            resolveOutputFile(outputPath, mimeType)
                ?: return mapOf(
                    "status" to "failed",
                    "error" to "Export output file does not exist.",
                )
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
            return mapOf(
                "status" to "failed",
                "error" to "Saving exports to gallery requires Android 10 or later.",
            )
        }
        val resolver = appContext.contentResolver
        val contentValues =
            ContentValues().apply {
                put(MediaStore.MediaColumns.DISPLAY_NAME, resolvedOutput.file.name)
                put(MediaStore.MediaColumns.MIME_TYPE, resolvedOutput.mimeType)
                put(
                    MediaStore.MediaColumns.RELATIVE_PATH,
                    "${Environment.DIRECTORY_MOVIES}/InGene Exports",
                )
                put(MediaStore.MediaColumns.IS_PENDING, 1)
            }
        val collection = MediaStore.Video.Media.EXTERNAL_CONTENT_URI
        var savedUri: Uri? = null
        return try {
            savedUri =
                resolver.insert(collection, contentValues)
                    ?: throw IOException("Unable to create gallery destination.")
            resolver.openOutputStream(savedUri!!)?.use { outputStream ->
                resolvedOutput.file.inputStream().use { inputStream ->
                    inputStream.copyTo(outputStream)
                }
            } ?: throw IOException("Unable to open gallery destination stream.")
            val completedValues =
                ContentValues().apply {
                    put(MediaStore.MediaColumns.IS_PENDING, 0)
                }
            resolver.update(savedUri!!, completedValues, null, null)
            mapOf(
                "status" to "saved",
                "outputPath" to outputPath,
                "savedUri" to savedUri.toString(),
                "displayName" to resolvedOutput.file.name,
            )
        } catch (error: Exception) {
            savedUri?.let { resolver.delete(it, null, null) }
            mapOf(
                "status" to "failed",
                "error" to (error.message ?: "Unable to save export output."),
                "outputPath" to outputPath,
            )
        }
    }

    private fun clearActiveExport(jobId: String) {
        if (jobId != activeJobId) {
            return
        }
        mainHandler.removeCallbacks(progressEmitter)
        activeTransformer?.removeAllListeners()
        activeTransformer = null
        resumePreviewAfterActiveExport()
        activeJobId = null
        activePreset = null
        activeSelectedVideoCodec = null
        activeBitrateMode = null
        activeOutputPath = null
        activeMotionTextParityDiagnostics = null
        activeCanonicalEffectsDiagnostics = null
        activeAuthoredVisualSurfaceDiagnostics = null
        activeVisualAssemblyDiagnostics = null
    }

    private fun emitEvent(event: Map<String, Any?>) {
        eventSink?.success(event)
    }

    private fun deleteOutputFileIfPresent(outputPath: String?): Boolean {
        if (outputPath.isNullOrBlank()) {
            return false
        }
        return runCatching {
                val outputFile = File(outputPath)
                repeat(4) { attempt ->
                    if (!outputFile.exists()) {
                        return@runCatching true
                    }
                    outputFile.setWritable(true)
                    if (outputFile.delete()) {
                        return@runCatching true
                    }
                    Thread.sleep(((attempt + 1) * 80L).coerceAtMost(320L))
                }
                !outputFile.exists()
            }
            .getOrDefault(false)
    }

    private fun resolveOutputFile(
        outputPath: String,
        mimeType: String?,
    ): ResolvedOutputFile? {
        val outputFile = File(outputPath)
        if (!outputFile.exists()) {
            return null
        }
        val resolvedMimeType =
            mimeType?.takeIf { it.isNotBlank() }
                ?: when (outputFile.extension.lowercase()) {
                    "mp4" -> "video/mp4"
                    "m4v" -> "video/mp4"
                    else -> "*/*"
                }
        val contentUri: Uri =
            FileProvider.getUriForFile(
                appContext,
                "${appContext.packageName}.fileprovider",
                outputFile,
            )
        return ResolvedOutputFile(
            file = outputFile,
            contentUri = contentUri,
            mimeType = resolvedMimeType,
        )
    }

    private fun readClipCount(compositionMap: Map<String, Any?>): Int {
        val tracks = compositionMap["tracks"] as? List<*> ?: return 0
        var total = 0
        tracks.forEach { trackEntry ->
            val track = trackEntry as? Map<*, *> ?: return@forEach
            val clips = track["clips"] as? List<*> ?: return@forEach
            total += clips.size
        }
        return total
    }

    private fun readDurationMs(compositionMap: Map<String, Any?>): Long {
        val format = compositionMap["format"] as? Map<*, *> ?: return 0L
        val durationValue = format["durationMs"]
        return when (durationValue) {
            is Int -> durationValue.toLong()
            is Long -> durationValue
            is Double -> durationValue.toLong()
            else -> 0L
        }
    }

    private fun validateBaselineComposition(compositionMap: Map<String, Any?>): String? {
        val graphSchemaVersion = compositionMap["graphSchemaVersion"]?.toString().orEmpty()
        if (graphSchemaVersion.isBlank()) {
            return "Export graph metadata is missing."
        }
        if (graphSchemaVersion != SUPPORTED_EXPORT_GRAPH_SCHEMA_VERSION) {
            return "Unsupported export graph schema version: $graphSchemaVersion."
        }
        val preflightSummary = compositionMap["preflightSummary"] as? Map<*, *>
        val canonicalEffectsGraph =
            readCanonicalEffectsGraph(compositionMap["canonicalEffectsGraph"])
                ?: return "Canonical effects graph is missing."
        val visualCompositorGraph =
            readVisualCompositorGraph(compositionMap["visualCompositorGraph"])
                ?: return "Visual compositor graph is missing."
        val visualCompositorGraphSummary = visualCompositorGraph.summary
        val preflightBlockingCodes =
            readStringList(preflightSummary?.get("firstBaselineBlockingCodes"))
        val nativeInterpolationValidationError =
            validateNativeInterpolationContracts(preflightSummary)
        if (nativeInterpolationValidationError != null) {
            return nativeInterpolationValidationError
        }
        val motionTextProgram = readMotionTextProgram(compositionMap["motionTextProgram"])
        val motionTextRasterProgram =
            readMotionTextRasterProgram(compositionMap["motionTextRasterProgram"])
        val authoredVisualSurfaceProgram =
            readAuthoredVisualSurfaceProgram(compositionMap["authoredVisualSurfaceProgram"])
        val nativeMotionSemanticValidationError =
            validateNativeMotionChannelSemantics(
                motionTextProgram = motionTextProgram,
                motionTextRasterProgram = motionTextRasterProgram,
            )
        if (nativeMotionSemanticValidationError != null) {
            return nativeMotionSemanticValidationError
        }
        val canonicalEffectsDiagnostics = buildCanonicalEffectsDiagnostics(canonicalEffectsGraph)
        canonicalEffectsDiagnostics.firstBlockedDetail?.let { blockingDetail ->
            return blockingDetail
        }
        val motionSummary = readMotionContractSummary(compositionMap["motion"])
        val motionTextProgramSummary =
            motionTextProgram?.let { NativeMotionTextProgramSummary(nodeCount = it.nodes.size) }
        val motionTextRenderTrackSummary =
            readMotionTextRenderTrackSummary(compositionMap["motionTextRenderTrack"])
        if (!validateVisualCompositorGraphSummary(visualCompositorGraphSummary)) {
            return "Visual compositor graph summary is internally inconsistent."
        }
        if (!validateVisualCompositorGraph(visualCompositorGraph, readDurationMs(compositionMap))) {
            return "Visual compositor graph windows are internally inconsistent."
        }
        val assetsById = HashMap<String, Map<*, *>>()
        val assets = compositionMap["assets"] as? List<*> ?: emptyList<Any?>()
        assets.forEach { assetEntry ->
            val asset = assetEntry as? Map<*, *> ?: return@forEach
            val assetId = asset["assetId"]?.toString()
            if (!assetId.isNullOrBlank()) {
                assetsById[assetId] = asset
            }
        }
        val trackMaps =
            (compositionMap["tracks"] as? List<*> ?: emptyList<Any?>())
                .mapNotNull { it as? Map<*, *> }
        val visualClips =
            runCatching {
                buildNativeVisualClipsFromGraph(
                    visualCompositorGraph = visualCompositorGraph,
                    trackMaps = trackMaps,
                    assetsById = assetsById,
                )
            }.getOrNull()
        val resolvedCompositorExecutions =
            if (visualClips != null) {
                resolveCompositorWindowExecutions(
                    clips = visualClips,
                    visualCompositorGraph = visualCompositorGraph,
                )
            } else {
                emptyMap()
            }
        val hasUnsupportedCompositorWindows =
            resolvedCompositorExecutions.values.any { execution -> !execution.isExecutable }
        val immediatePreflightBlockingCode =
            preflightBlockingCodes.firstOrNull { code ->
                when (code) {
                    "compositorRequiredVisualWindow",
                    "multipleVisualTracks",
                    -> hasUnsupportedCompositorWindows || visualClips == null
                    else -> true
                }
            }
        if (immediatePreflightBlockingCode != null) {
            return buildPreflightBlockingMessage(
                code = immediatePreflightBlockingCode,
                preflightSummary = preflightSummary,
            )
        }
        val firstBlockedCompositorExecution =
            resolvedCompositorExecutions.values.firstOrNull { execution ->
                !execution.isExecutable
            }
        if (firstBlockedCompositorExecution != null) {
            return firstBlockedCompositorExecution.detail
        }
        if (motionSummary != null) {
            if (motionSummary.textElementCount > 0 &&
                visualCompositorGraphSummary.authoredLayerCount <= 0
            ) {
                return "Visual compositor graph is missing an authored motion/text layer."
            }
            if (motionSummary.textElementCount > 0 &&
                visualCompositorGraph.motionTextOverlayWindows.isEmpty()
            ) {
                return "Visual compositor graph is missing authored overlay windows for motion/text."
            }
            if (motionSummary.nonTextElementCount > 0) {
                if (!visualCompositorGraphSummary.requirementReasons.contains(
                        "non_text_authored_visuals_present",
                    )
                ) {
                    return "Visual compositor graph did not declare non-text authored visuals."
                }
                if (visualCompositorGraph.authoredOverlayWindows.isEmpty()) {
                    return "Visual compositor graph is missing authored overlay windows for non-text visuals."
                }
                if (authoredVisualSurfaceProgram == null || authoredVisualSurfaceProgram.nodes.isEmpty()) {
                    return "Canonical authored visual surface program is required for non-text authored visuals."
                }
                val authoredSurfaceNodeIds =
                    authoredVisualSurfaceProgram.nodes.mapTo(linkedSetOf()) { node ->
                        "element:${node.targetElementId}"
                    }
                val missingAuthoredSurfaceNodeIds =
                    visualCompositorGraph.authoredOverlaySegments
                        .filter { segment ->
                            segment.rendererOwnerId == "app_authored_visual_surface_renderer"
                        }.mapNotNull { segment -> segment.nodeId }
                        .filter { nodeId -> nodeId !in authoredSurfaceNodeIds }
                        .distinct()
                        .sorted()
                if (missingAuthoredSurfaceNodeIds.isNotEmpty()) {
                    return "Authored visual surface program is missing compositor-owned nodes: ${missingAuthoredSurfaceNodeIds.joinToString()}."
                }
                return "Only generated text motion is in the first export baseline " +
                    "(nonTextElements=${motionSummary.nonTextElementCount})."
            }
            if (motionSummary.cameraCount > 0) {
                if (!visualCompositorGraphSummary.requirementReasons.contains(
                        "motion_cameras_present",
                    )
                ) {
                    return "Visual compositor graph did not declare authored camera requirements."
                }
                return "Motion camera bindings are not in the first export baseline " +
                    "(cameras=${motionSummary.cameraCount})."
            }
            if (motionSummary.effectCount > 0) {
                if (!visualCompositorGraphSummary.requirementReasons.contains(
                        "motion_effects_present",
                    )
                ) {
                    return "Visual compositor graph did not declare authored motion effects."
                }
                return "Motion effects are not in the first export baseline " +
                    "(effects=${motionSummary.effectCount})."
            }
            if (motionSummary.transitionCount > 0) {
                if (!visualCompositorGraphSummary.requirementReasons.contains(
                        "motion_transitions_present",
                    )
                ) {
                    return "Visual compositor graph did not declare authored motion transitions."
                }
                return "Motion transitions are not in the first export baseline " +
                    "(transitions=${motionSummary.transitionCount})."
            }
            if (motionSummary.textElementCount > 0 &&
                (motionTextProgramSummary == null || motionTextProgramSummary.nodeCount <= 0)
            ) {
                return buildString {
                    append("Canonical motion/text export program is required for export ")
                    append("(textElements=${motionSummary.textElementCount}")
                    append(", scenes=${motionSummary.sceneCount}")
                    append(", channels=${motionSummary.channelCount}")
                    append(", textAnimations=${motionSummary.textAnimationCount}")
                    if (motionTextRenderTrackSummary != null &&
                        motionTextRenderTrackSummary.sampleCount > 0
                    ) {
                        append(", sampledFallbackSamples=${motionTextRenderTrackSummary.sampleCount}")
                    }
                    append(").")
                }
            }
        }
        val tracks = compositionMap["tracks"] as? List<*> ?: return "Export tracks are missing."
        val nonEmptyTracks =
            tracks.mapNotNull { it as? Map<*, *> }
                .filter { track ->
                    val clips = track["clips"] as? List<*> ?: emptyList<Any?>()
                    clips.isNotEmpty()
                }
        if (nonEmptyTracks.isEmpty()) {
            return "Export composition contains no media clips."
        }
        val nonEmptyVisualTracks =
            nonEmptyTracks.filter { track ->
                val kind = track["kind"]?.toString() ?: ""
                kind == "video" || kind == "image"
            }
        if (nonEmptyVisualTracks.isEmpty()) {
            return "Export composition contains no visual baseline track."
        }
        if (visualCompositorGraphSummary.mediaLayerCount <= 0) {
            return "Visual compositor graph does not include a media layer."
        }
        if (nonEmptyVisualTracks.size > 1) {
            if (!visualCompositorGraphSummary.requirementReasons.contains(
                    "multiple_visual_media_tracks",
                )
            ) {
                return "Visual compositor graph did not declare multi-visual media requirements."
            }
            return "Multiple visual tracks are not in the first export baseline."
        }
        val nonEmptyAudioTracks =
            nonEmptyTracks.filter { track ->
                val kind = track["kind"]?.toString() ?: ""
                kind == "audio"
            }
        if (nonEmptyAudioTracks.size > 1) {
            return "Multiple audio tracks are not in the first export baseline."
        }
        if (nonEmptyTracks.any { track ->
                val kind = track["kind"]?.toString() ?: ""
                kind != "video" && kind != "image" && kind != "audio"
            }) {
            return "Only single visual-track video/image plus one audio track are in the first export baseline."
        }
        nonEmptyTracks.forEach { track ->
            val clips = track["clips"] as? List<*> ?: emptyList<Any?>()
            clips.forEach clipLoop@ { clipEntry ->
                val clip = clipEntry as? Map<*, *> ?: return@clipLoop
                val speedMode = clip["speedMode"]?.toString() ?: "normal"
                val playbackRate = readDouble(clip["playbackRate"])
                if (speedMode == "curve") {
                    return "Curve clip speed is not in the first export baseline."
                }
                if (playbackRate <= 0.0) {
                    return "Clip speed must be greater than zero."
                }
            }
        }
        return null
    }

    private fun validateNativeInterpolationContracts(
        preflightSummary: Map<*, *>?,
    ): String? {
        val entries = preflightSummary?.get("interpolationContractRegistry") as? List<*> ?: return null
        val unsupportedEncounteredKinds =
            entries
                .mapNotNull { entry ->
                    val descriptor = entry as? Map<*, *> ?: return@mapNotNull null
                    val kind = descriptor["kind"]?.toString().orEmpty()
                    val encountered = descriptor["encountered"] as? Boolean ?: false
                    val status = descriptor["status"]?.toString().orEmpty()
                    if (!encountered) {
                        return@mapNotNull null
                    }
                    if (status != "supported") {
                        return@mapNotNull kind.ifBlank { "__missing__" }
                    }
                    if (!SUPPORTED_EXPORT_INTERPOLATION_KINDS.contains(kind)) {
                        return@mapNotNull kind.ifBlank { "__missing__" }
                    }
                    null
                }.distinct()
                .sorted()
        if (unsupportedEncounteredKinds.isEmpty()) {
            return null
        }
        return "Encountered interpolation kinds are not registered for native export: ${unsupportedEncounteredKinds.joinToString()}."
    }

    private fun validateNativeMotionChannelSemantics(
        motionTextProgram: NativeMotionTextProgram?,
        motionTextRasterProgram: NativeMotionTextRasterProgram?,
    ): String? {
        val unsupportedModes = linkedSetOf<String>()
        val affectedProperties = linkedSetOf<String>()

        fun inspectChannel(channel: NativeMotionScalarChannel) {
            val beforeStart = channel.beforeStart.trim().ifBlank { "clamp" }
            val afterEnd = channel.afterEnd.trim().ifBlank { "clamp" }
            if (beforeStart !in SUPPORTED_EXPORT_CHANNEL_EDGE_MODES) {
                unsupportedModes += "beforeStart=$beforeStart"
                affectedProperties += channel.propertyId
            }
            if (afterEnd !in SUPPORTED_EXPORT_CHANNEL_EDGE_MODES) {
                unsupportedModes += "afterEnd=$afterEnd"
                affectedProperties += channel.propertyId
            }
        }

        motionTextProgram?.nodes?.forEach { node ->
            node.channels.forEach(::inspectChannel)
            node.layerChannels.forEach(::inspectChannel)
        }
        motionTextRasterProgram?.nodes?.forEach { node ->
            node.channels.forEach(::inspectChannel)
            node.layerChannels.forEach(::inspectChannel)
        }

        if (unsupportedModes.isEmpty()) {
            return null
        }
        val affectedPropertiesSummary =
            affectedProperties
                .filter { it.isNotBlank() }
                .sorted()
                .joinToString()
                .ifBlank { "unknownProperties" }
        return buildString {
            append("Encountered motion channel edge semantics not supported by the current native export lane: ")
            append(unsupportedModes.toList().sorted().joinToString())
            append(". Supported modes: ")
            append(SUPPORTED_EXPORT_CHANNEL_EDGE_MODES.toList().sorted().joinToString())
            append(". Affected properties: ")
            append(affectedPropertiesSummary)
            append(".")
        }
    }

    private fun buildPreflightBlockingMessage(
        code: String,
        preflightSummary: Map<*, *>?,
    ): String {
        return when (code) {
            "unresolvedCompositionErrors" -> "Export composition contains unresolved export errors."
            "missingMotionTextProgram" ->
                "Canonical motion/text export program is required; sampled fallback alone is not baseline-eligible."
            "compositorRequiredVisualWindow" ->
                "Visual assembly contains windows that require a wider compositor path than the current backend baseline."
            "unsupportedNonTextMotion" ->
                "Non-text motion elements are not in the first export baseline."
            "unsupportedMotionCamera" ->
                "Motion camera bindings are not in the first export baseline."
            "unsupportedMotionEffect" ->
                "Motion effects are not in the first export baseline."
            "unsupportedMotionTransition" ->
                "Motion transitions are not in the first export baseline."
            "noMediaClips" -> "Export composition contains no media clips."
            "noVisualBaselineTrack" ->
                "Export composition contains no visual baseline track."
            "multipleVisualTracks" ->
                "Multiple visual tracks are not in the first export baseline."
            "multipleAudioTracks" ->
                "Multiple audio tracks are not in the first export baseline."
            "unsupportedTrackKind" ->
                "Only single visual-track video/image plus one audio track are in the first export baseline."
            "curveSpeed" -> "Curve clip speed is not in the first export baseline."
            "unsupportedInterpolationKind" -> {
                val unsupportedKinds =
                    readStringList(preflightSummary?.get("unsupportedInterpolationKinds"))
                if (unsupportedKinds.isEmpty()) {
                    "Encountered interpolation kinds are not registered for export."
                } else {
                    "Encountered interpolation kinds are not registered for export: ${unsupportedKinds.joinToString()}."
                }
            }

            else -> "Export preflight rejected the composition (code=$code)."
        }
    }

    private fun readMotionContractSummary(motion: Any?): NativeMotionContractSummary? {
        val motionMap = motion as? Map<*, *> ?: return null
        val elements = motionMap["elements"] as? List<*> ?: emptyList<Any?>()
        val textElementCount =
            elements.count { entry ->
                val element = entry as? Map<*, *> ?: return@count false
                (element["kind"]?.toString() ?: "") == "text"
            }
        return NativeMotionContractSummary(
            sceneCount = readNestedCount(motionMap["scenes"]),
            elementCount = elements.size,
            textElementCount = textElementCount,
            nonTextElementCount = elements.size - textElementCount,
            channelCount =
                readNestedCount(motionMap["globalChannels"]) +
                    readSceneNestedChannelCount(motionMap["scenes"]),
            cameraCount = readNestedCount(motionMap["cameras"]),
            textAnimationCount = readNestedCount(motionMap["textAnimations"]),
            effectCount = readNestedCount(motionMap["effects"]),
            transitionCount = readNestedCount(motionMap["transitions"]),
        )
    }

    private fun readNestedCount(value: Any?): Int {
        return when (value) {
            is List<*> -> value.size
            else -> 0
        }
    }

    private fun readStringList(value: Any?): List<String> {
        return (value as? List<*> ?: emptyList<Any?>())
            .mapNotNull { entry ->
                val text = entry?.toString()?.trim().orEmpty()
                text.takeIf { it.isNotEmpty() }
            }
    }

    private fun readMotionPropertyValueMap(value: Any?): Map<String, Map<String, Any?>> {
        val map = value as? Map<*, *> ?: return emptyMap()
        return map.entries.mapNotNull { entry ->
            val key = entry.key?.toString()?.trim().orEmpty()
            if (key.isEmpty()) {
                return@mapNotNull null
            }
            val propertyValue = entry.value as? Map<*, *> ?: return@mapNotNull null
            key to propertyValue.entries.associate { propertyEntry ->
                propertyEntry.key?.toString().orEmpty() to propertyEntry.value
            }
        }.toMap()
    }

    private fun readMotionTextRenderTrackSummary(value: Any?): NativeMotionTextRenderTrackSummary? {
        val trackMap = value as? Map<*, *> ?: return null
        return NativeMotionTextRenderTrackSummary(
            sampleCount = readNestedCount(trackMap["samples"]),
            sampleStepMs = readLong(trackMap["sampleStepMs"]),
            totalNodeInstances = readLong(trackMap["totalNodeInstances"]),
        )
    }

    private fun readMotionTextProgramSummary(value: Any?): NativeMotionTextProgramSummary? {
        val programMap = value as? Map<*, *> ?: return null
        return NativeMotionTextProgramSummary(
            nodeCount = readNestedCount(programMap["nodes"]),
        )
    }

    private fun readVisualCompositorGraphSummary(value: Any?): NativeVisualCompositorGraphSummary? {
        val graphMap = value as? Map<*, *> ?: return null
        return NativeVisualCompositorGraphSummary(
            layerCount = readInt(graphMap["layerCount"]),
            segmentCount = readInt(graphMap["segmentCount"]),
            windowCount = readInt(graphMap["windowCount"]),
            gapWindowCount = readInt(graphMap["gapWindowCount"]),
            mediaOnlyWindowCount = readInt(graphMap["mediaOnlyWindowCount"]),
            mediaWithAuthoredOverlayWindowCount =
                readInt(graphMap["mediaWithAuthoredOverlayWindowCount"]),
            compositorRequiredWindowCount = readInt(graphMap["compositorRequiredWindowCount"]),
            compositorWindowExecutionPlanCount =
                readInt(graphMap["compositorWindowExecutionPlanCount"]),
            mediaLayerCount = readInt(graphMap["mediaLayerCount"]),
            authoredLayerCount = readInt(graphMap["authoredLayerCount"]),
            maxConcurrentVisualSegments = readInt(graphMap["maxConcurrentVisualSegments"]),
            requiresVisualCompositor = readBoolean(graphMap["requiresVisualCompositor"]),
            requirementReasons = readStringList(graphMap["requirementReasons"]),
        )
    }

    private fun readVisualCompositorGraph(value: Any?): NativeVisualCompositorGraph? {
        val graphMap = value as? Map<*, *> ?: return null
        val summary = readVisualCompositorGraphSummary(graphMap) ?: return null
        val layers =
            (graphMap["layers"] as? List<*> ?: emptyList<Any?>())
                .mapNotNull { layerEntry ->
                    val layer = layerEntry as? Map<*, *> ?: return@mapNotNull null
                    NativeVisualLayer(
                        id = layer["id"]?.toString() ?: return@mapNotNull null,
                        kind = layer["kind"]?.toString() ?: return@mapNotNull null,
                        sourceTruthKind =
                            layer["sourceTruthKind"]?.toString() ?: return@mapNotNull null,
                        rendererOwnerId =
                            layer["rendererOwnerId"]?.toString() ?: return@mapNotNull null,
                        zOrder = readInt(layer["zOrder"]),
                        supportsCurrentBackend = readBoolean(layer["supportsCurrentBackend"]),
                        trackKind = layer["trackKind"]?.toString(),
                    )
                }
        val segments =
            (graphMap["segments"] as? List<*> ?: emptyList<Any?>())
                .mapNotNull { segmentEntry ->
                    val segment = segmentEntry as? Map<*, *> ?: return@mapNotNull null
                    val timelineRange = segment["timelineRange"] as? Map<*, *> ?: return@mapNotNull null
                    NativeVisualSegment(
                        id = segment["id"]?.toString() ?: return@mapNotNull null,
                        layerId = segment["layerId"]?.toString() ?: return@mapNotNull null,
                        sourceTruthKind =
                            segment["sourceTruthKind"]?.toString() ?: return@mapNotNull null,
                        rendererOwnerId =
                            segment["rendererOwnerId"]?.toString() ?: return@mapNotNull null,
                        timelineStartMs = readLong(timelineRange["startMs"]),
                        timelineEndExclusiveMs = readLong(timelineRange["endExclusiveMs"]),
                        zOrder = readInt(segment["zOrder"]),
                        trackKind = segment["trackKind"]?.toString(),
                        clipId = segment["clipId"]?.toString(),
                        nodeId = segment["nodeId"]?.toString(),
                    )
                }
        val windows =
            (graphMap["windows"] as? List<*> ?: emptyList<Any?>())
                .mapNotNull { windowEntry ->
                    val window = windowEntry as? Map<*, *> ?: return@mapNotNull null
                    val timelineRange = window["timelineRange"] as? Map<*, *> ?: return@mapNotNull null
                    NativeVisualAssemblyWindow(
                        id = window["id"]?.toString() ?: return@mapNotNull null,
                        timelineStartMs = readLong(timelineRange["startMs"]),
                        timelineEndExclusiveMs = readLong(timelineRange["endExclusiveMs"]),
                        policy = window["policy"]?.toString() ?: return@mapNotNull null,
                        executionOwner =
                            window["executionOwner"]?.toString() ?: return@mapNotNull null,
                        requiresVisualCompositor = readBoolean(window["requiresVisualCompositor"]),
                        supportsCurrentBackend = readBoolean(window["supportsCurrentBackend"]),
                        activeLayerIds = readStringList(window["activeLayerIds"]),
                        activeSegmentIds = readStringList(window["activeSegmentIds"]),
                    )
                }
        val compositorWindowExecutionPlans =
            (graphMap["compositorWindowExecutionPlans"] as? List<*> ?: emptyList<Any?>())
                .mapNotNull { planEntry ->
                    val plan = planEntry as? Map<*, *> ?: return@mapNotNull null
                    val timelineRange =
                        plan["timelineRange"] as? Map<*, *> ?: return@mapNotNull null
                    NativeCompositorWindowExecutionPlan(
                        windowId = plan["windowId"]?.toString() ?: return@mapNotNull null,
                        timelineStartMs = readLong(timelineRange["startMs"]),
                        timelineEndExclusiveMs = readLong(timelineRange["endExclusiveMs"]),
                        executionOwner =
                            plan["executionOwner"]?.toString() ?: return@mapNotNull null,
                        orderedLayerIds = readStringList(plan["orderedLayerIds"]),
                        orderedSegmentIds = readStringList(plan["orderedSegmentIds"]),
                        mediaSegmentIds = readStringList(plan["mediaSegmentIds"]),
                        authoredSegmentIds = readStringList(plan["authoredSegmentIds"]),
                        executionInputs =
                            (plan["executionInputs"] as? List<*> ?: emptyList<Any?>())
                                .mapNotNull inputMap@{ inputEntry ->
                                    val input = inputEntry as? Map<*, *> ?: return@inputMap null
                                    NativeCompositorExecutionInput(
                                        segmentId =
                                            input["segmentId"]?.toString()
                                                ?: return@inputMap null,
                                        layerId =
                                            input["layerId"]?.toString()
                                                ?: return@inputMap null,
                                        role =
                                            input["role"]?.toString()
                                                ?: return@inputMap null,
                                        sourceTruthKind =
                                            input["sourceTruthKind"]?.toString()
                                                ?: return@inputMap null,
                                        rendererOwnerId =
                                            input["rendererOwnerId"]?.toString()
                                                ?: return@inputMap null,
                                        zOrder = readInt(input["zOrder"]),
                                        trackKind = input["trackKind"]?.toString(),
                                        clipId = input["clipId"]?.toString(),
                                        nodeId = input["nodeId"]?.toString(),
                                    )
                                },
                    )
                }
        return NativeVisualCompositorGraph(
            summary = summary,
            layers = layers,
            segments = segments,
            windows = windows,
            compositorWindowExecutionPlans = compositorWindowExecutionPlans,
        )
    }

    private fun readCanonicalEffectsGraph(value: Any?): NativeCanonicalEffectsGraph? {
        val graphMap = value as? Map<*, *> ?: return null
        return NativeCanonicalEffectsGraph(
            schemaVersion = graphMap["schemaVersion"]?.toString() ?: return null,
            nodes =
                (graphMap["nodes"] as? List<*> ?: emptyList<Any?>())
                    .mapNotNull(::readCanonicalEffectsNode),
            operations =
                (graphMap["operations"] as? List<*> ?: emptyList<Any?>())
                    .mapNotNull(::readCanonicalEffectsOperation),
        )
    }

    private fun readCanonicalEffectsNode(value: Any?): NativeCanonicalEffectsNode? {
        val nodeMap = value as? Map<*, *> ?: return null
        return NativeCanonicalEffectsNode(
            id = nodeMap["id"]?.toString() ?: return null,
            label = nodeMap["label"]?.toString() ?: return null,
            kind = nodeMap["kind"]?.toString() ?: return null,
            sourceTruthKind = nodeMap["sourceTruthKind"]?.toString() ?: return null,
            targetAddress = nodeMap["targetAddress"]?.toString(),
            detail = nodeMap["detail"]?.toString(),
            backendSupport =
                (nodeMap["backendSupport"] as? List<*> ?: emptyList<Any?>())
                    .mapNotNull(::readCanonicalEffectsBackendSupport),
        )
    }

    private fun readCanonicalEffectsOperation(value: Any?): NativeCanonicalEffectsOperation? {
        val operationMap = value as? Map<*, *> ?: return null
        return NativeCanonicalEffectsOperation(
            id = operationMap["id"]?.toString() ?: return null,
            label = operationMap["label"]?.toString() ?: return null,
            kind = operationMap["kind"]?.toString() ?: return null,
            sourceTruthKind = operationMap["sourceTruthKind"]?.toString() ?: return null,
            targetNodeId = operationMap["targetNodeId"]?.toString(),
            targetAddress = operationMap["targetAddress"]?.toString(),
            propertyId = operationMap["propertyId"]?.toString(),
            detail = operationMap["detail"]?.toString(),
            backendSupport =
                (operationMap["backendSupport"] as? List<*> ?: emptyList<Any?>())
                    .mapNotNull(::readCanonicalEffectsBackendSupport),
        )
    }

    private fun readCanonicalEffectsBackendSupport(value: Any?): NativeCanonicalEffectsBackendSupport? {
        val supportMap = value as? Map<*, *> ?: return null
        return NativeCanonicalEffectsBackendSupport(
            backendId = supportMap["backendId"]?.toString() ?: return null,
            status = supportMap["status"]?.toString() ?: return null,
            detail = supportMap["detail"]?.toString(),
        )
    }

    private fun buildPreflightCanonicalEffectsDiagnostics(
        compositionMap: Map<String, Any?>,
    ): NativeCanonicalEffectsDiagnostics? {
        val canonicalEffectsGraph =
            readCanonicalEffectsGraph(compositionMap["canonicalEffectsGraph"]) ?: return null
        return buildCanonicalEffectsDiagnostics(canonicalEffectsGraph)
    }

    private fun buildPreflightAuthoredVisualSurfaceDiagnostics(
        compositionMap: Map<String, Any?>,
    ): NativeAuthoredVisualSurfaceDiagnostics? {
        val visualCompositorGraph =
            readVisualCompositorGraph(compositionMap["visualCompositorGraph"]) ?: return null
        val authoredVisualSurfaceProgram =
            readAuthoredVisualSurfaceProgram(compositionMap["authoredVisualSurfaceProgram"])
        return buildAuthoredVisualSurfaceDiagnostics(
            visualCompositorGraph = visualCompositorGraph,
            runtimeBundle = NativeAuthoredVisualSurfaceRuntimeBundle(authoredVisualSurfaceProgram),
        )
    }

    private fun buildCanonicalEffectsDiagnostics(
        canonicalEffectsGraph: NativeCanonicalEffectsGraph,
    ): NativeCanonicalEffectsDiagnostics {
        val relevantNodes =
            canonicalEffectsGraph.nodes.filter { node ->
                node.sourceTruthKind == "canonicalTracks" ||
                    node.sourceTruthKind == "motionTextProgram" ||
                    node.kind == "imageElement" ||
                    node.kind == "shapeElement"
            }
        val relevantOperations =
            canonicalEffectsGraph.operations.filter { operation ->
                operation.sourceTruthKind == "canonicalTracks" ||
                    operation.sourceTruthKind == "motionTextProgram" ||
                    operation.kind == "motionEffect" ||
                    operation.kind == "motionTransition" ||
                    operation.kind == "camera" ||
                    operation.kind == "blendMode"
            }
        val firstBlockedNode =
            relevantNodes.firstOrNull { node ->
                resolveCanonicalEffectsBackendStatus(
                    backendSupport = node.backendSupport,
                    backendId = CURRENT_CANONICAL_EFFECTS_BACKEND_ID,
                ) == "blocked"
            }
        val firstBlockedOperation =
            relevantOperations.firstOrNull { operation ->
                isCanonicalEffectsBlockingOperation(operation) &&
                    resolveCanonicalEffectsBackendStatus(
                        backendSupport = operation.backendSupport,
                        backendId = CURRENT_CANONICAL_EFFECTS_BACKEND_ID,
                    ) == "blocked"
            }
        val firstBlockedDetail =
            firstBlockedNode?.let { node ->
                "Canonical effects graph contains `${node.kind}` `${node.id}` which is not yet executable in the current export backend."
            }
                ?: firstBlockedOperation?.let { operation ->
                    operation.detail
                        ?: "Canonical effects graph requires `${operation.kind}` `${operation.id}` which is not yet executable in the current export backend."
                }
        return NativeCanonicalEffectsDiagnostics(
            currentBackendId = CURRENT_CANONICAL_EFFECTS_BACKEND_ID,
            nodeCount = canonicalEffectsGraph.nodes.size,
            operationCount = canonicalEffectsGraph.operations.size,
            relevantNodeCount = relevantNodes.size,
            relevantOperationCount = relevantOperations.size,
            supportedNodeCount =
                relevantNodes.count { node ->
                    resolveCanonicalEffectsBackendStatus(
                        backendSupport = node.backendSupport,
                        backendId = CURRENT_CANONICAL_EFFECTS_BACKEND_ID,
                    ) == "supported"
                },
            baselineOnlyNodeCount =
                relevantNodes.count { node ->
                    resolveCanonicalEffectsBackendStatus(
                        backendSupport = node.backendSupport,
                        backendId = CURRENT_CANONICAL_EFFECTS_BACKEND_ID,
                    ) == "baselineOnly"
                },
            approximationNodeCount =
                relevantNodes.count { node ->
                    resolveCanonicalEffectsBackendStatus(
                        backendSupport = node.backendSupport,
                        backendId = CURRENT_CANONICAL_EFFECTS_BACKEND_ID,
                    ) == "approximation"
                },
            blockedNodeCount =
                relevantNodes.count { node ->
                    resolveCanonicalEffectsBackendStatus(
                        backendSupport = node.backendSupport,
                        backendId = CURRENT_CANONICAL_EFFECTS_BACKEND_ID,
                    ) == "blocked"
                },
            supportedOperationCount =
                relevantOperations.count { operation ->
                    resolveCanonicalEffectsBackendStatus(
                        backendSupport = operation.backendSupport,
                        backendId = CURRENT_CANONICAL_EFFECTS_BACKEND_ID,
                    ) == "supported"
                },
            baselineOnlyOperationCount =
                relevantOperations.count { operation ->
                    resolveCanonicalEffectsBackendStatus(
                        backendSupport = operation.backendSupport,
                        backendId = CURRENT_CANONICAL_EFFECTS_BACKEND_ID,
                    ) == "baselineOnly"
                },
            approximationOperationCount =
                relevantOperations.count { operation ->
                    resolveCanonicalEffectsBackendStatus(
                        backendSupport = operation.backendSupport,
                        backendId = CURRENT_CANONICAL_EFFECTS_BACKEND_ID,
                    ) == "approximation"
                },
            blockedOperationCount =
                relevantOperations.count { operation ->
                    resolveCanonicalEffectsBackendStatus(
                        backendSupport = operation.backendSupport,
                        backendId = CURRENT_CANONICAL_EFFECTS_BACKEND_ID,
                    ) == "blocked"
                },
            firstBlockedNodeId = firstBlockedNode?.id,
            firstBlockedOperationId = firstBlockedOperation?.id,
            firstBlockedDetail = firstBlockedDetail,
            nodeKinds = relevantNodes.map { node -> node.kind }.toSet().toList().sorted(),
            operationKinds =
                relevantOperations.map { operation -> operation.kind }.toSet().toList().sorted(),
        )
    }

    private fun resolveCanonicalEffectsBackendStatus(
        backendSupport: List<NativeCanonicalEffectsBackendSupport>,
        backendId: String,
    ): String =
        backendSupport.firstOrNull { descriptor -> descriptor.backendId == backendId }?.status
            ?: "unknown"

    private fun isCanonicalEffectsBlockingOperation(
        operation: NativeCanonicalEffectsOperation,
    ): Boolean =
        operation.kind == "motionEffect" ||
            operation.kind == "motionTransition" ||
            operation.kind == "camera" ||
            operation.kind == "blendMode"

    private fun buildAuthoredVisualSurfaceDiagnostics(
        visualCompositorGraph: NativeVisualCompositorGraph,
        runtimeBundle: NativeAuthoredVisualSurfaceRuntimeBundle,
    ): NativeAuthoredVisualSurfaceDiagnostics? {
        val program = runtimeBundle.program ?: return null
        if (program.nodes.isEmpty()) {
            return null
        }
        val graphSegments =
            visualCompositorGraph.authoredOverlaySegments.filter { segment ->
                segment.rendererOwnerId == "app_authored_visual_surface_renderer"
            }
        val programNodeIds =
            program.nodes.mapTo(linkedSetOf()) { node ->
                "element:${node.targetElementId}"
            }
        val graphNodeIds = graphSegments.mapNotNull { segment -> segment.nodeId }.toSet()
        val missingProgramNodeIds =
            graphNodeIds.filter { nodeId -> nodeId !in programNodeIds }.sorted()
        val imageNodeCount = program.nodes.count { node -> node.elementKind == "image" }
        val shapeNodeCount = program.nodes.count { node -> node.elementKind == "shape" }
        val maskNodeCount = program.nodes.count { node -> node.elementKind == "mask" }
        val videoNodeCount = program.nodes.count { node -> node.elementKind == "videoClip" }
        val animatedNodeCount =
            program.nodes.count { node ->
                node.channels.isNotEmpty() || node.layerChannels.isNotEmpty()
            }
        val blurCapableNodeCount =
            program.nodes.count { node ->
                node.blurAmount > 0f ||
                    node.channels.any { channel -> channel.propertyId == "visual.blur.amount" }
            }
        val runtimeSummary =
            Stage6AuthoredVisualSurfaceRuntimeEvaluator.summarizeRuntime(
                program = program,
                sampleTimesMs = buildAuthoredVisualSurfaceSampleTimes(program, visualCompositorGraph),
            )
        val status =
            if (missingProgramNodeIds.isEmpty()) {
                "runtime_ready_for_backend_routing"
            } else {
                "missing_program_nodes"
            }
        val detail =
            if (missingProgramNodeIds.isEmpty()) {
                "Authored visual surface runtime bundle backs all compositor-owned non-text segments and resolves ${runtimeSummary.activeNodeCount} active node(s) across ${runtimeSummary.sampleCount} sampled timeline point(s)."
            } else {
                "Authored visual surface runtime bundle is missing compositor-owned nodes: ${missingProgramNodeIds.joinToString()}."
            }
        return NativeAuthoredVisualSurfaceDiagnostics(
            status = status,
            runtimePathKind = "authored_surface_program_runtime",
            nodeCount = program.nodes.size,
            imageNodeCount = imageNodeCount,
            shapeNodeCount = shapeNodeCount,
            maskNodeCount = maskNodeCount,
            videoNodeCount = videoNodeCount,
            animatedNodeCount = animatedNodeCount,
            blurCapableNodeCount = blurCapableNodeCount,
            compositorOwnedSegmentCount = graphSegments.size,
            programBackedSegmentCount =
                graphSegments.count { segment ->
                    segment.nodeId != null && segment.nodeId in programNodeIds
                },
            missingProgramNodeCount = missingProgramNodeIds.size,
            sampleCount = runtimeSummary.sampleCount,
            activeNodeCount = runtimeSummary.activeNodeCount,
            activeAnimatedNodeCount = runtimeSummary.activeAnimatedNodeCount,
            activeBlurNodeCount = runtimeSummary.activeBlurNodeCount,
            normalBlendNodeCount = runtimeSummary.normalBlendNodeCount,
            surfaceEffectEligibleNodeCount = runtimeSummary.surfaceEffectEligibleNodeCount,
            maxConcurrentActiveNodeCount = runtimeSummary.maxConcurrentActiveNodeCount,
            maxResolvedBlurAmount = runtimeSummary.maxResolvedBlurAmount,
            firstMissingProgramNodeId = missingProgramNodeIds.firstOrNull(),
            firstResolvedNodeId = runtimeSummary.firstResolvedNodeId,
            sourceKinds = program.nodes.map { node -> node.sourceKind }.distinct().sorted(),
            detail = detail,
        )
    }

    private fun buildAuthoredVisualSurfaceSampleTimes(
        program: NativeAuthoredVisualSurfaceProgram,
        visualCompositorGraph: NativeVisualCompositorGraph,
    ): List<Long> {
        val sampleTimes = linkedSetOf<Long>()
        visualCompositorGraph.authoredOverlayWindows.forEach { window ->
            if (window.timelineEndExclusiveMs <= window.timelineStartMs) {
                return@forEach
            }
            val startMs = window.timelineStartMs.coerceAtLeast(0L)
            val lastMs =
                (window.timelineEndExclusiveMs - 1L).coerceAtLeast(startMs)
            sampleTimes += startMs
            sampleTimes += startMs + ((lastMs - startMs) / 2L)
            sampleTimes += lastMs
        }
        if (sampleTimes.isEmpty()) {
            program.nodes.forEach { node ->
                val startMs = node.projectRangeStartMs.coerceAtLeast(0L)
                val endExclusiveMs =
                    node.projectRangeEndExclusiveMs.coerceAtLeast(startMs + 1L)
                val lastMs = (endExclusiveMs - 1L).coerceAtLeast(startMs)
                sampleTimes += startMs
                sampleTimes += startMs + ((lastMs - startMs) / 2L)
                sampleTimes += lastMs
            }
        }
        return sampleTimes.toList().sorted()
    }

    private fun validateVisualCompositorGraphSummary(
        summary: NativeVisualCompositorGraphSummary,
    ): Boolean {
        if (summary.layerCount < 0 ||
            summary.segmentCount < 0 ||
            summary.windowCount < 0 ||
            summary.gapWindowCount < 0 ||
            summary.mediaOnlyWindowCount < 0 ||
            summary.mediaWithAuthoredOverlayWindowCount < 0 ||
            summary.compositorRequiredWindowCount < 0 ||
            summary.compositorWindowExecutionPlanCount < 0 ||
            summary.mediaLayerCount < 0 ||
            summary.authoredLayerCount < 0 ||
            summary.maxConcurrentVisualSegments < 0
        ) {
            return false
        }
        if (summary.layerCount != summary.mediaLayerCount + summary.authoredLayerCount) {
            return false
        }
        if (summary.gapWindowCount > summary.windowCount ||
            summary.mediaOnlyWindowCount > summary.windowCount ||
            summary.mediaWithAuthoredOverlayWindowCount > summary.windowCount ||
            summary.compositorRequiredWindowCount > summary.windowCount
        ) {
            return false
        }
        if (summary.windowCount !=
            summary.gapWindowCount +
                summary.mediaOnlyWindowCount +
                summary.mediaWithAuthoredOverlayWindowCount +
                summary.compositorRequiredWindowCount
        ) {
            return false
        }
        if (summary.requiresVisualCompositor != summary.requirementReasons.isNotEmpty()) {
            return false
        }
        return true
    }

    private fun validateVisualCompositorGraph(
        graph: NativeVisualCompositorGraph,
        durationMs: Long,
    ): Boolean {
        if (graph.windows.size != graph.summary.windowCount) {
            return false
        }
        val gapWindowCount =
            graph.windows.count { window -> window.policy == "gap" }
        if (gapWindowCount != graph.summary.gapWindowCount) {
            return false
        }
        val mediaOnlyWindowCount =
            graph.windows.count { window -> window.policy == "mediaOnly" }
        if (mediaOnlyWindowCount != graph.summary.mediaOnlyWindowCount) {
            return false
        }
        val mediaWithAuthoredOverlayWindowCount =
            graph.windows.count { window -> window.policy == "mediaWithAuthoredOverlay" }
        if (mediaWithAuthoredOverlayWindowCount !=
            graph.summary.mediaWithAuthoredOverlayWindowCount
        ) {
            return false
        }
        val compositorRequiredWindowCount =
            graph.windows.count { window -> window.requiresVisualCompositor }
        if (compositorRequiredWindowCount != graph.summary.compositorRequiredWindowCount) {
            return false
        }
        val rawCanonicalWindows = buildCanonicalVisualAssemblyWindows(graph.segments, durationMs)
        val canonicalCompositorPlans =
            buildCanonicalCompositorWindowExecutionPlans(rawCanonicalWindows, graph.segments)
        val canonicalWindows =
            normalizeCanonicalVisualAssemblyWindows(
                windows = rawCanonicalWindows,
                compositorPlans = canonicalCompositorPlans,
                segments = graph.segments,
            )
        if (canonicalWindows.size != graph.windows.size) {
            return false
        }
        val windowsMatch =
            graph.windows.zip(canonicalWindows).all { (declaredWindow, canonicalWindow) ->
            declaredWindow.timelineStartMs == canonicalWindow.timelineStartMs &&
                declaredWindow.timelineEndExclusiveMs == canonicalWindow.timelineEndExclusiveMs &&
                declaredWindow.policy == canonicalWindow.policy &&
                declaredWindow.executionOwner == canonicalWindow.executionOwner &&
                declaredWindow.requiresVisualCompositor == canonicalWindow.requiresVisualCompositor &&
                declaredWindow.supportsCurrentBackend == canonicalWindow.supportsCurrentBackend &&
                declaredWindow.activeLayerIds == canonicalWindow.activeLayerIds &&
                declaredWindow.activeSegmentIds == canonicalWindow.activeSegmentIds
        }
        if (!windowsMatch) {
            return false
        }
        if (canonicalCompositorPlans.size != graph.compositorWindowExecutionPlans.size ||
            canonicalCompositorPlans.size != graph.summary.compositorWindowExecutionPlanCount
        ) {
            return false
        }
        return graph.compositorWindowExecutionPlans.zip(canonicalCompositorPlans).all {
            (declaredPlan, canonicalPlan) ->
            declaredPlan.windowId == canonicalPlan.windowId &&
                declaredPlan.timelineStartMs == canonicalPlan.timelineStartMs &&
                declaredPlan.timelineEndExclusiveMs == canonicalPlan.timelineEndExclusiveMs &&
                declaredPlan.executionOwner == canonicalPlan.executionOwner &&
                declaredPlan.orderedLayerIds == canonicalPlan.orderedLayerIds &&
                declaredPlan.orderedSegmentIds == canonicalPlan.orderedSegmentIds &&
                declaredPlan.mediaSegmentIds == canonicalPlan.mediaSegmentIds &&
                declaredPlan.authoredSegmentIds == canonicalPlan.authoredSegmentIds &&
                declaredPlan.executionInputs == canonicalPlan.executionInputs
        }
    }

    private fun buildCanonicalVisualAssemblyWindows(
        segments: List<NativeVisualSegment>,
        durationMs: Long,
    ): List<NativeVisualAssemblyWindow> {
        val boundaries = linkedSetOf<Long>()
        boundaries += 0L
        if (durationMs > 0L) {
            boundaries += durationMs
        }
        segments.forEach { segment ->
            boundaries += segment.timelineStartMs
            boundaries += segment.timelineEndExclusiveMs
        }
        val sortedBoundaries = boundaries.toMutableList().sorted()
        val windows = mutableListOf<NativeVisualAssemblyWindow>()
        for (index in 0 until (sortedBoundaries.size - 1)) {
            val startMs = sortedBoundaries[index]
            val endMs = sortedBoundaries[index + 1]
            if (endMs <= startMs) {
                continue
            }
            val activeSegments =
                segments.filter { segment ->
                    segment.timelineStartMs < endMs &&
                        segment.timelineEndExclusiveMs > startMs
                }.sortedBy { it.zOrder }
            val activeLayerIds = mutableListOf<String>()
            activeSegments.forEach { segment ->
                if (segment.layerId !in activeLayerIds) {
                    activeLayerIds += segment.layerId
                }
            }
            val activeSegmentIds = activeSegments.map { segment -> segment.id }
            val activeMediaSegments =
                activeSegments.count { segment ->
                    segment.sourceTruthKind == "canonicalTracks"
                }
            val activeAuthoredSegments = activeSegments.size - activeMediaSegments
            val hasUnsupportedAuthoredSegment =
                activeSegments.any { segment ->
                    segment.sourceTruthKind != "canonicalTracks" &&
                        segment.rendererOwnerId != "app_motion_text_program_renderer"
                }
            val policy =
                if (activeSegments.isEmpty()) {
                    "gap"
                } else if (!hasUnsupportedAuthoredSegment &&
                    activeMediaSegments == 1 &&
                    activeAuthoredSegments == 0
                ) {
                    "mediaOnly"
                } else if (!hasUnsupportedAuthoredSegment &&
                    activeMediaSegments == 1 &&
                    activeAuthoredSegments > 0
                ) {
                    "mediaWithAuthoredOverlay"
                } else {
                    "compositorRequired"
                }
            val requiresVisualCompositor = policy == "compositorRequired"
            val executionOwner =
                when (policy) {
                    "gap" -> "none"
                    "mediaOnly" -> "media3BaselineRoute"
                    "mediaWithAuthoredOverlay" -> "media3BaselineRoute"
                    else -> "nativeVisualCompositor"
                }
            windows +=
                NativeVisualAssemblyWindow(
                    id = "visual.window.$index",
                    timelineStartMs = startMs,
                    timelineEndExclusiveMs = endMs,
                    policy = policy,
                    executionOwner = executionOwner,
                    requiresVisualCompositor = requiresVisualCompositor,
                    supportsCurrentBackend = !requiresVisualCompositor,
                    activeLayerIds = activeLayerIds,
                    activeSegmentIds = activeSegmentIds,
                )
        }
        return windows
    }

    private fun normalizeCanonicalVisualAssemblyWindows(
        windows: List<NativeVisualAssemblyWindow>,
        compositorPlans: List<NativeCompositorWindowExecutionPlan>,
        segments: List<NativeVisualSegment>,
    ): List<NativeVisualAssemblyWindow> {
        if (windows.isEmpty() || compositorPlans.isEmpty() || segments.isEmpty()) {
            return windows
        }
        val segmentsById = segments.associateBy { segment -> segment.id }
        val supportedWindowIds =
            compositorPlans.filter { plan ->
                isSupportedCurrentBackendCompositorPlan(
                    plan = plan,
                    segmentsById = segmentsById,
                )
            }.map { plan -> plan.windowId }.toSet()
        return windows.map { window ->
            if (!window.requiresVisualCompositor) {
                window
            } else {
                window.copy(supportsCurrentBackend = window.id in supportedWindowIds)
            }
        }
    }

    private fun buildCanonicalCompositorWindowExecutionPlans(
        windows: List<NativeVisualAssemblyWindow>,
        segments: List<NativeVisualSegment>,
    ): List<NativeCompositorWindowExecutionPlan> {
        if (windows.isEmpty() || segments.isEmpty()) {
            return emptyList()
        }
        val segmentsById = segments.associateBy { segment -> segment.id }
        return windows.filter { window -> window.policy == "compositorRequired" }
            .map { window ->
                val orderedSegments =
                    window.activeSegmentIds.mapNotNull { segmentId -> segmentsById[segmentId] }
                        .sortedBy { segment -> segment.zOrder }
                val orderedLayerIds = mutableListOf<String>()
                orderedSegments.forEach { segment ->
                    if (segment.layerId !in orderedLayerIds) {
                        orderedLayerIds += segment.layerId
                    }
                }
                var mediaInputIndex = 0
                NativeCompositorWindowExecutionPlan(
                    windowId = window.id,
                    timelineStartMs = window.timelineStartMs,
                    timelineEndExclusiveMs = window.timelineEndExclusiveMs,
                    executionOwner = "nativeVisualCompositor",
                    orderedLayerIds = orderedLayerIds,
                    orderedSegmentIds = orderedSegments.map { segment -> segment.id },
                    mediaSegmentIds =
                        orderedSegments.filter { segment ->
                            segment.sourceTruthKind == "canonicalTracks"
                        }.map { segment -> segment.id },
                    authoredSegmentIds =
                        orderedSegments.filter { segment ->
                            segment.sourceTruthKind != "canonicalTracks"
                        }.map { segment -> segment.id },
                    executionInputs =
                        orderedSegments.map { segment ->
                            val isMedia = segment.sourceTruthKind == "canonicalTracks"
                            val role =
                                if (!isMedia) {
                                    "authoredOverlay"
                                } else if (mediaInputIndex++ == 0) {
                                    "baseMedia"
                                } else {
                                    "overlayMedia"
                                }
                            NativeCompositorExecutionInput(
                                segmentId = segment.id,
                                layerId = segment.layerId,
                                role = role,
                                sourceTruthKind = segment.sourceTruthKind,
                                rendererOwnerId = segment.rendererOwnerId,
                                zOrder = segment.zOrder,
                                trackKind = segment.trackKind,
                                clipId = segment.clipId,
                                nodeId = segment.nodeId,
                            )
                        },
                )
            }
    }

    private fun isSupportedCurrentBackendCompositorPlan(
        plan: NativeCompositorWindowExecutionPlan,
        segmentsById: Map<String, NativeVisualSegment>,
    ): Boolean {
        if (plan.executionOwner != "nativeVisualCompositor") {
            return false
        }
        if (plan.executionInputs.map { input -> input.segmentId } != plan.orderedSegmentIds) {
            return false
        }
        val baseMediaInputs =
            plan.executionInputs.filter { input -> input.role == "baseMedia" }
        val overlayMediaInputs =
            plan.executionInputs.filter { input -> input.role == "overlayMedia" }
        val authoredInputs =
            plan.executionInputs.filter { input -> input.role == "authoredOverlay" }
        if (baseMediaInputs.size != 1 || overlayMediaInputs.isEmpty()) {
            return false
        }
        if (baseMediaInputs.any { input -> input.sourceTruthKind != "canonicalTracks" } ||
            overlayMediaInputs.any { input ->
                input.sourceTruthKind != "canonicalTracks" || input.trackKind != "image"
            }
        ) {
            return false
        }
        val firstAuthoredIndex =
            plan.executionInputs.indexOfFirst { input -> input.role == "authoredOverlay" }
        val lastMediaIndex =
            plan.executionInputs.indexOfLast { input ->
                input.role == "baseMedia" || input.role == "overlayMedia"
            }
        if (firstAuthoredIndex != -1 &&
            lastMediaIndex != -1 &&
            firstAuthoredIndex <= lastMediaIndex
        ) {
            return false
        }
        return authoredInputs.all { input ->
            input.rendererOwnerId == "app_motion_text_program_renderer" &&
                input.nodeId != null &&
                input.sourceTruthKind != "canonicalTracks" &&
                segmentsById[input.segmentId]?.nodeId != null
        }
    }

    private fun collectCompositorRequiredWindows(
        graph: NativeVisualCompositorGraph,
    ): List<NativeVisualAssemblyWindow> {
        return graph.windows.filter { window ->
            window.policy == "compositorRequired" ||
                window.requiresVisualCompositor ||
                !window.supportsCurrentBackend
        }
    }

    private fun buildCompositorRequiredWindowMessage(
        window: NativeVisualAssemblyWindow,
    ): String {
        val activeLayerIds =
            if (window.activeLayerIds.isEmpty()) {
                "-"
            } else {
                window.activeLayerIds.joinToString()
            }
        val activeSegmentIds =
            if (window.activeSegmentIds.isEmpty()) {
                "-"
            } else {
                window.activeSegmentIds.joinToString()
            }
        return buildString {
            append("Visual assembly window `${window.id}` requires a wider compositor path ")
            append("(")
            append(window.timelineStartMs)
            append("-")
            append(window.timelineEndExclusiveMs)
            append("ms, policy=")
            append(window.policy)
            append(", activeLayers=")
            append(activeLayerIds)
            append(", activeSegments=")
            append(activeSegmentIds)
            if (window.policy == "compositorRequired" &&
                window.activeSegmentIds.isNotEmpty() &&
                window.activeLayerIds.any { layerId -> layerId == "motion.text.program" } &&
                window.activeLayerIds.none { layerId -> layerId.startsWith("media.track.") }
            ) {
                append(", reason=authored_overlay_without_media_base")
            }
            append(").")
        }
    }

    private fun buildPreflightVisualAssemblyDiagnostics(
        compositionMap: Map<String, Any?>,
    ): NativeVisualAssemblyDiagnostics? {
        val visualCompositorGraph =
            readVisualCompositorGraph(compositionMap["visualCompositorGraph"]) ?: return null
        val assetsById = HashMap<String, Map<*, *>>()
        val assets = compositionMap["assets"] as? List<*> ?: emptyList<Any?>()
        assets.forEach { assetEntry ->
            val asset = assetEntry as? Map<*, *> ?: return@forEach
            val assetId = asset["assetId"]?.toString()
            if (!assetId.isNullOrBlank()) {
                assetsById[assetId] = asset
            }
        }
        val trackMaps =
            (compositionMap["tracks"] as? List<*> ?: emptyList<Any?>())
                .mapNotNull { it as? Map<*, *> }
        val visualClips =
            runCatching {
                buildNativeVisualClipsFromGraph(
                    visualCompositorGraph = visualCompositorGraph,
                    trackMaps = trackMaps,
                    assetsById = assetsById,
                )
            }.getOrNull()
        if (visualClips != null) {
            val resolvedCompositorExecutions =
                resolveCompositorWindowExecutions(
                    clips = visualClips,
                    visualCompositorGraph = visualCompositorGraph,
                )
            return buildVisualAssemblyDiagnostics(
                clips = visualClips,
                visualCompositorGraph = visualCompositorGraph,
                resolvedCompositorExecutions = resolvedCompositorExecutions,
            )
        }
        val blockedWindows = collectCompositorRequiredWindows(visualCompositorGraph)
        val firstBlockedWindow = blockedWindows.firstOrNull()
        return NativeVisualAssemblyDiagnostics(
            status = if (blockedWindows.isEmpty()) "preflight_unavailable" else "blocked",
            routeCount = 0,
            mediaOnlyRouteCount = 0,
            overlayRouteCount = 0,
            blockedRouteCount = blockedWindows.size,
            compositorWindowCount = blockedWindows.size,
            executableCompositorWindowCount = 0,
            blockedCompositorWindowCount = blockedWindows.size,
            firstBlockedWindowId = firstBlockedWindow?.id,
            firstBlockedClipId = null,
            firstBlockedDetail =
                firstBlockedWindow?.let { window ->
                    buildCompositorRequiredWindowMessage(window)
                },
            routes = emptyList(),
            compositorRoutes = emptyList(),
        )
    }

    private fun windowsOverlapClip(
        window: NativeVisualAssemblyWindow,
        clip: NativeExportClip,
    ): Boolean {
        return window.timelineStartMs < clip.timelineStartMs + clip.timelineDurationMs &&
            window.timelineEndExclusiveMs > clip.timelineStartMs
    }

    private fun buildClipWindowRoutingPlan(
        clip: NativeExportClip,
        visualAssemblyWindows: List<NativeVisualAssemblyWindow>,
    ): NativeClipWindowRoutingPlan {
        val overlappingWindows =
            visualAssemblyWindows.filter { window -> windowsOverlapClip(window, clip) }
                .sortedBy { window -> window.timelineStartMs }
        val clipStartMs = clip.timelineStartMs
        val clipEndExclusiveMs = clip.timelineStartMs + clip.timelineDurationMs
        require(overlappingWindows.isNotEmpty()) {
            "Visual assembly windows do not cover clip `${clip.clipId}`."
        }
        var coverageCursorMs = clipStartMs
        overlappingWindows.forEach { window ->
            val effectiveStartMs = maxOf(window.timelineStartMs, clipStartMs)
            val effectiveEndExclusiveMs = minOf(window.timelineEndExclusiveMs, clipEndExclusiveMs)
            if (effectiveEndExclusiveMs <= effectiveStartMs) {
                return@forEach
            }
            require(effectiveStartMs == coverageCursorMs) {
                "Visual assembly windows leave an uncovered gap for clip `${clip.clipId}` " +
                    "at ${coverageCursorMs}ms before `${window.id}`."
            }
            require(window.policy != "gap") {
                "Gap visual assembly window `${window.id}` overlaps clip `${clip.clipId}`."
            }
            coverageCursorMs = effectiveEndExclusiveMs
        }
        require(coverageCursorMs == clipEndExclusiveMs) {
            "Visual assembly windows do not fully cover clip `${clip.clipId}`."
        }
        val blockedWindows =
            overlappingWindows.filter { window ->
                window.policy == "compositorRequired" ||
                    window.requiresVisualCompositor ||
                    !window.supportsCurrentBackend
            }
        val mediaOnlyWindows =
            overlappingWindows.filter { window -> window.policy == "mediaOnly" }
        val overlayWindows =
            overlappingWindows.filter { window ->
                window.policy == "mediaWithAuthoredOverlay"
            }
        return NativeClipWindowRoutingPlan(
            clipId = clip.clipId,
            overlappingWindows = overlappingWindows,
            mediaOnlyWindows = mediaOnlyWindows,
            overlayWindows = overlayWindows,
            blockedWindows = blockedWindows,
        )
    }

    private fun buildVisualAssemblyDiagnostics(
        clips: List<NativeExportClip>,
        visualCompositorGraph: NativeVisualCompositorGraph,
        resolvedCompositorExecutions: Map<String, NativeResolvedCompositorWindowExecution>,
    ): NativeVisualAssemblyDiagnostics {
        val visualAssemblyWindows = visualCompositorGraph.windows
        val windowsById = visualAssemblyWindows.associateBy { window -> window.id }
        val routes =
            clips.filter { clip -> clip.assetKind != NativeExportClipKind.AUDIO }
                .map { clip ->
                    val coveredWindows =
                        if (clip.coveredWindowIds.isNotEmpty()) {
                            clip.coveredWindowIds.mapNotNull(windowsById::get)
                        } else {
                            listOfNotNull(clip.graphWindowId?.let(windowsById::get))
                        }
                    NativeVisualAssemblyRouteDiagnostics(
                        clipId = clip.clipId,
                        graphSegmentId = clip.graphSegmentId,
                        graphLayerId = clip.graphLayerId,
                        graphWindowId = clip.graphWindowId,
                        coveredWindowIds =
                            if (clip.coveredWindowIds.isNotEmpty()) {
                                clip.coveredWindowIds
                            } else {
                                listOfNotNull(clip.graphWindowId)
                            },
                        graphZOrder = clip.graphZOrder,
                        graphAssemblyOrder = clip.graphAssemblyOrder,
                        route = clip.graphWindowPolicy ?: "unknown",
                        timelineStartMs = clip.timelineStartMs,
                        timelineEndExclusiveMs = clip.timelineStartMs + clip.timelineDurationMs,
                        activeLayerIds =
                            coveredWindows.flatMap { window -> window.activeLayerIds }.distinct(),
                        activeSegmentIds =
                            coveredWindows.flatMap { window -> window.activeSegmentIds }.distinct(),
                    )
                }
        val compositorRoutes =
            resolvedCompositorExecutions.values.map { execution -> execution.toDiagnostics() }
                .sortedBy { route -> route.windowId }
        val executableCompositorWindowIds =
            compositorRoutes.filter { route -> route.isExecutable }
                .map { route -> route.windowId }
                .toSet()
        val blockedRoutes =
            routes.filter { route ->
                when (route.route) {
                    "mediaOnly",
                    "mediaWithAuthoredOverlay",
                    "mediaTimelineRoute",
                    "mediaTimelineRouteWithAuthoredOverlay",
                    -> false
                    "compositorRequired" ->
                        route.graphWindowId !in executableCompositorWindowIds
                    else -> true
                }
            }
        val blockedCompositorRoutes =
            compositorRoutes.filter { route -> !route.isExecutable }
        val firstBlockedRoute = blockedRoutes.firstOrNull()
        val firstBlockedCompositorRoute = blockedCompositorRoutes.firstOrNull()
        val firstBlockedDetail =
            firstBlockedRoute?.let { route ->
                buildString {
                    append("Clip `${route.clipId}` resolved to route `${route.route}`")
                    route.graphWindowId?.let { windowId ->
                        append(" via `${windowId}`")
                    }
                    append(".")
                }
            } ?: firstBlockedCompositorRoute?.detail
        val status =
            when {
                blockedRoutes.isNotEmpty() || blockedCompositorRoutes.isNotEmpty() -> "blocked"
                compositorRoutes.isNotEmpty() -> "compositor_routed"
                else -> "baseline_routed"
            }
        return NativeVisualAssemblyDiagnostics(
            status = status,
            routeCount = routes.size,
            mediaOnlyRouteCount =
                routes.count { route ->
                    route.route == "mediaOnly" || route.route == "mediaTimelineRoute"
                },
            overlayRouteCount =
                routes.count { route ->
                    route.route == "mediaWithAuthoredOverlay" ||
                        route.route == "mediaTimelineRouteWithAuthoredOverlay"
                },
            blockedRouteCount = blockedRoutes.size,
            compositorWindowCount = compositorRoutes.size,
            executableCompositorWindowCount =
                compositorRoutes.count { route -> route.isExecutable },
            blockedCompositorWindowCount = blockedCompositorRoutes.size,
            firstBlockedWindowId =
                firstBlockedRoute?.graphWindowId ?: firstBlockedCompositorRoute?.windowId,
            firstBlockedClipId = firstBlockedRoute?.clipId,
            firstBlockedDetail = firstBlockedDetail,
            routes = routes,
            compositorRoutes = compositorRoutes,
        )
    }

    private fun resolveCompositorWindowExecutions(
        clips: List<NativeExportClip>,
        visualCompositorGraph: NativeVisualCompositorGraph,
    ): Map<String, NativeResolvedCompositorWindowExecution> {
        if (visualCompositorGraph.compositorWindowExecutionPlans.isEmpty()) {
            return emptyMap()
        }
        val windowsById = visualCompositorGraph.windows.associateBy { window -> window.id }
        val segmentsById = visualCompositorGraph.segments.associateBy { segment -> segment.id }
        val clipsByWindowAndSegmentId =
            clips.filter { clip -> clip.graphWindowId != null && clip.graphSegmentId != null }
                .associateBy { clip -> "${clip.graphWindowId}:${clip.graphSegmentId}" }
        return visualCompositorGraph.compositorWindowExecutionPlans.associate { plan ->
            val window = windowsById[plan.windowId]
            val baseSegmentId =
                plan.executionInputs.firstOrNull { input -> input.role == "baseMedia" }?.segmentId
            val baseClip =
                baseSegmentId?.let { segmentId ->
                    clipsByWindowAndSegmentId["${plan.windowId}:$segmentId"]
                }
            val overlayImageInputs =
                plan.executionInputs.filter { input -> input.role == "overlayMedia" }
            val overlayImageClips =
                overlayImageInputs.mapNotNull { input ->
                    val segmentId = input.segmentId
                    clipsByWindowAndSegmentId["${plan.windowId}:$segmentId"]
                }
            val authoredInputs =
                plan.executionInputs.filter { input -> input.role == "authoredOverlay" }
            val authoredNodeIds = authoredInputs.mapNotNull { input -> input.nodeId }
            val firstAuthoredIndex =
                plan.executionInputs.indexOfFirst { input ->
                    input.role == "authoredOverlay"
                }
            val lastMediaIndex =
                plan.executionInputs.indexOfLast { input ->
                    input.role == "baseMedia" || input.role == "overlayMedia"
                }
            val authoredAfterMedia =
                firstAuthoredIndex == -1 || lastMediaIndex == -1 || firstAuthoredIndex > lastMediaIndex
            val execution =
                when {
                    window == null ->
                        NativeResolvedCompositorWindowExecution.blocked(
                            plan = plan,
                            detail =
                                "Compositor window `${plan.windowId}` is missing from the visual compositor graph.",
                        )
                    window.executionOwner != "nativeVisualCompositor" ->
                        NativeResolvedCompositorWindowExecution.blocked(
                            plan = plan,
                            detail =
                                "Compositor window `${plan.windowId}` does not declare nativeVisualCompositor ownership.",
                        )
                    plan.executionOwner != "nativeVisualCompositor" ->
                        NativeResolvedCompositorWindowExecution.blocked(
                            plan = plan,
                            detail =
                                "Compositor plan `${plan.windowId}` does not declare nativeVisualCompositor ownership.",
                        )
                    plan.executionInputs.count { input ->
                        input.role == "baseMedia" || input.role == "overlayMedia"
                    } < 2 ->
                        NativeResolvedCompositorWindowExecution.blocked(
                            plan = plan,
                            detail =
                                "Compositor window `${plan.windowId}` is outside the current image-overlay compositor path.",
                        )
                    baseClip == null ->
                        NativeResolvedCompositorWindowExecution.blocked(
                            plan = plan,
                            detail =
                                "Compositor window `${plan.windowId}` could not resolve its base media clip.",
                        )
                    overlayImageClips.size != overlayImageInputs.size ->
                        NativeResolvedCompositorWindowExecution.blocked(
                            plan = plan,
                            detail =
                                "Compositor window `${plan.windowId}` could not resolve all overlay media clips.",
                        )
                    overlayImageClips.any { overlayClip ->
                        overlayClip.assetKind != NativeExportClipKind.IMAGE
                    } ->
                        NativeResolvedCompositorWindowExecution.blocked(
                            plan = plan,
                            detail =
                                "Compositor window `${plan.windowId}` currently supports image overlay stacks only above the base media input.",
                        )
                    !authoredAfterMedia ->
                        NativeResolvedCompositorWindowExecution.blocked(
                            plan = plan,
                            detail =
                                "Compositor window `${plan.windowId}` interleaves authored overlays before media inputs, which is outside the current image-overlay-stack compositor path.",
                        )
                    authoredNodeIds.size != authoredInputs.size ||
                        authoredInputs.any { input ->
                            segmentsById[input.segmentId]?.nodeId == null
                        } ->
                        NativeResolvedCompositorWindowExecution.blocked(
                            plan = plan,
                            detail =
                                "Compositor window `${plan.windowId}` has authored inputs without stable node ids.",
                        )
                    else ->
                        NativeResolvedCompositorWindowExecution.executable(
                            plan = plan,
                            baseClip = baseClip,
                            overlayImageClips = overlayImageClips,
                            authoredNodeIds = authoredNodeIds,
                        )
                }
            plan.windowId to execution
        }
    }

    private fun readMotionTextRenderTrack(value: Any?): NativeMotionTextRenderTrack? {
        val trackMap = value as? Map<*, *> ?: return null
        val canvasSizeMap = trackMap["canvasSize"] as? Map<*, *> ?: return null
        val canvasWidth = readDouble(canvasSizeMap["width"]).toFloat()
        val canvasHeight = readDouble(canvasSizeMap["height"]).toFloat()
        val sampleStepMs = readLong(trackMap["sampleStepMs"])
        val samples =
            (trackMap["samples"] as? List<*> ?: emptyList<Any?>())
                .mapNotNull { sampleEntry ->
                    val sample = sampleEntry as? Map<*, *> ?: return@mapNotNull null
                    NativeMotionTextRenderSample(
                        timeMs = readLong(sample["timeMs"]),
                        nodes =
                            (sample["nodes"] as? List<*> ?: emptyList<Any?>())
                                .mapNotNull { nodeEntry ->
                                    readMotionTextRenderNode(nodeEntry)
                                },
                    )
                }.sortedBy { it.timeMs }
        if (samples.isEmpty()) {
            return null
        }
        return NativeMotionTextRenderTrack(
            canvasWidth = canvasWidth,
            canvasHeight = canvasHeight,
            sampleStepMs = sampleStepMs.coerceAtLeast(1L),
            samples = samples,
        )
    }

    private fun readMotionTextRasterContract(value: Any?): NativeMotionTextRasterContract? {
        val contractMap = value as? Map<*, *> ?: return null
        val policyMap = contractMap["rasterizationPolicy"] as? Map<*, *> ?: return null
        return NativeMotionTextRasterContract(
            contractVersion = contractMap["contractVersion"]?.toString() ?: "motion-text-raster.unknown",
            layoutEngineId = contractMap["layoutEngineId"]?.toString() ?: "shaped_paragraph_layout",
            blurEngineId = contractMap["blurEngineId"]?.toString() ?: "gaussian_layer_blur",
            blurColorResolutionMode =
                contractMap["blurColorResolutionMode"]?.toString()
                    ?: "alpha_mask_colorized",
            rasterizationPolicy =
                NativeMotionTextRasterizationPolicy(
                    blurSigmaScale = readDouble(policyMap["blurSigmaScale"]).toFloat(),
                    blurSpreadMultiplier = readDouble(policyMap["blurSpreadMultiplier"]).toFloat(),
                    minimumLayoutPaddingPx =
                        readDouble(policyMap["minimumLayoutPaddingPx"]).toFloat(),
                    minimumFontSizePx = readDouble(policyMap["minimumFontSizePx"]).toFloat(),
                    fontPaddingRatio = readDouble(policyMap["fontPaddingRatio"]).toFloat(),
                ),
        )
    }

    private fun readMotionTextRasterProgram(value: Any?): NativeMotionTextRasterProgram? {
        val programMap = value as? Map<*, *> ?: return null
        val canvasSizeMap = programMap["canvasSize"] as? Map<*, *> ?: return null
        val policyMap = programMap["rasterizationPolicy"] as? Map<*, *> ?: return null
        val canvasWidth = readDouble(canvasSizeMap["width"]).toFloat()
        val canvasHeight = readDouble(canvasSizeMap["height"]).toFloat()
        val nodes =
            (programMap["nodes"] as? List<*> ?: emptyList<Any?>())
                .mapNotNull { nodeEntry -> readMotionTextRasterProgramNode(nodeEntry) }
        if (nodes.isEmpty()) {
            return null
        }
        return NativeMotionTextRasterProgram(
            contractVersion = programMap["contractVersion"]?.toString() ?: "motion-text-raster.unknown",
            layoutEngineId = programMap["layoutEngineId"]?.toString() ?: "shaped_paragraph_layout",
            blurEngineId = programMap["blurEngineId"]?.toString() ?: "gaussian_layer_blur",
            blurColorResolutionMode =
                programMap["blurColorResolutionMode"]?.toString()
                    ?: "alpha_mask_colorized",
            canvasWidth = canvasWidth,
            canvasHeight = canvasHeight,
            rasterizationPolicy =
                NativeMotionTextRasterizationPolicy(
                    blurSigmaScale = readDouble(policyMap["blurSigmaScale"]).toFloat(),
                    blurSpreadMultiplier = readDouble(policyMap["blurSpreadMultiplier"]).toFloat(),
                    minimumLayoutPaddingPx =
                        readDouble(policyMap["minimumLayoutPaddingPx"]).toFloat(),
                    minimumFontSizePx = readDouble(policyMap["minimumFontSizePx"]).toFloat(),
                    fontPaddingRatio = readDouble(policyMap["fontPaddingRatio"]).toFloat(),
                ),
            nodes = nodes,
        )
    }

    private fun readMotionTextRasterProgramNode(value: Any?): NativeMotionTextRasterProgramNode? {
        val nodeMap = value as? Map<*, *> ?: return null
        val projectRange = nodeMap["projectRange"] as? Map<*, *> ?: return null
        val typography = nodeMap["typography"] as? Map<*, *> ?: return null
        val effects = nodeMap["effects"] as? Map<*, *> ?: return null
        val layout = nodeMap["layout"] as? Map<*, *> ?: return null
        val canvasOffset = layout["canvasOffset"] as? Map<*, *> ?: return null
        return NativeMotionTextRasterProgramNode(
            id = nodeMap["id"]?.toString() ?: return null,
            targetElementId = nodeMap["targetElementId"]?.toString() ?: return null,
            sceneId = nodeMap["sceneId"]?.toString() ?: "",
            layerId = nodeMap["layerId"]?.toString() ?: "",
            projectRangeStartMs = readLong(projectRange["startMs"]),
            projectRangeEndExclusiveMs = readLong(projectRange["endExclusiveMs"]),
            fullText = nodeMap["fullText"]?.toString() ?: "",
            revealUnit = nodeMap["revealUnit"]?.toString() ?: "wholeText",
            fontSize = readDouble(typography["fontSize"]).toFloat(),
            letterSpacing = readDouble(typography["letterSpacing"]).toFloat(),
            colorArgb = readLong(typography["colorArgb"]).toInt(),
            fontFamily = typography["fontFamily"]?.toString()?.takeIf { it.isNotBlank() },
            fontWeight = readLong(typography["fontWeight"]).toInt().takeIf { it > 0 } ?: 700,
            fontStyle = typography["fontStyle"]?.toString() ?: "normal",
            lineHeight = readDouble(typography["lineHeight"]).toFloat().takeIf { it > 0f } ?: 1f,
            textAlignment = typography["textAlignment"]?.toString() ?: "center",
            opacity = readDouble(effects["opacity"]).toFloat(),
            blurAmount = readDouble(effects["blurAmount"]).toFloat(),
            blendMode = effects["blendMode"]?.toString() ?: "normal",
            canvasOffsetX = readDouble(canvasOffset["x"]).toFloat(),
            canvasOffsetY = readDouble(canvasOffset["y"]).toFloat(),
            scaleX = readDouble(layout["scaleX"]).toFloat(),
            scaleY = readDouble(layout["scaleY"]).toFloat(),
            rotationDegrees = readDouble(layout["rotationDegrees"]).toFloat(),
            anchor = layout["anchor"]?.toString() ?: "center",
            zIndex = readLong(layout["zIndex"]).toInt(),
            layerOpacity = readDouble(nodeMap["layerOpacity"]).toFloat(),
            animationKinds =
                (nodeMap["animationKinds"] as? List<*>)
                    ?.mapNotNull { it?.toString() }
                    ?.toSet()
                    ?: emptySet(),
            animationBlocks =
                (nodeMap["animationBlocks"] as? List<*> ?: emptyList<Any?>())
                    .mapNotNull { readMotionTextProgramAnimationBlock(it) },
            channels =
                (nodeMap["channels"] as? List<*> ?: emptyList<Any?>())
                    .mapNotNull { readMotionTextScalarChannel(it) },
            layerChannels =
                (nodeMap["layerChannels"] as? List<*> ?: emptyList<Any?>())
                    .mapNotNull { readMotionTextScalarChannel(it) },
            channelPropertyIds =
                (nodeMap["channelPropertyIds"] as? List<*>)
                    ?.mapNotNull { it?.toString() }
                    ?.toSet()
                    ?: emptySet(),
            layerChannelPropertyIds =
                (nodeMap["layerChannelPropertyIds"] as? List<*>)
                    ?.mapNotNull { it?.toString() }
                    ?.toSet()
                    ?: emptySet(),
            name = nodeMap["name"]?.toString(),
            presetId = nodeMap["presetId"]?.toString(),
        )
    }

    private fun readAuthoredVisualSurfaceProgram(value: Any?): NativeAuthoredVisualSurfaceProgram? {
        val programMap = value as? Map<*, *> ?: return null
        val canvasSizeMap = programMap["canvasSize"] as? Map<*, *> ?: return null
        val canvasWidth = readDouble(canvasSizeMap["width"]).toFloat()
        val canvasHeight = readDouble(canvasSizeMap["height"]).toFloat()
        val nodes =
            (programMap["nodes"] as? List<*> ?: emptyList<Any?>())
                .mapNotNull { nodeEntry -> readAuthoredVisualSurfaceProgramNode(nodeEntry) }
        if (nodes.isEmpty()) {
            return null
        }
        return NativeAuthoredVisualSurfaceProgram(
            contractVersion =
                programMap["contractVersion"]?.toString()
                    ?: "authored-visual-surface.unknown",
            canvasWidth = canvasWidth,
            canvasHeight = canvasHeight,
            nodes = nodes,
        )
    }

    private fun readAuthoredVisualSurfaceProgramNode(value: Any?): NativeAuthoredVisualSurfaceNode? {
        val nodeMap = value as? Map<*, *> ?: return null
        val projectRange = nodeMap["projectRange"] as? Map<*, *> ?: return null
        val layout = nodeMap["layout"] as? Map<*, *> ?: return null
        val effects = nodeMap["effects"] as? Map<*, *> ?: return null
        return NativeAuthoredVisualSurfaceNode(
            id = nodeMap["id"]?.toString() ?: return null,
            targetElementId = nodeMap["targetElementId"]?.toString() ?: return null,
            sceneId = nodeMap["sceneId"]?.toString() ?: "",
            layerId = nodeMap["layerId"]?.toString() ?: "",
            elementKind = nodeMap["elementKind"]?.toString() ?: "unknown",
            projectRangeStartMs = readLong(projectRange["startMs"]),
            projectRangeEndExclusiveMs = readLong(projectRange["endExclusiveMs"]),
            sourceKind = nodeMap["sourceKind"]?.toString() ?: "unknown",
            sourceId = nodeMap["sourceId"]?.toString() ?: "",
            sourceAssetId = nodeMap["sourceAssetId"]?.toString(),
            sourceLabel = nodeMap["sourceLabel"]?.toString(),
            shapeKind = nodeMap["shapeKind"]?.toString(),
            basePositionX = readDouble(layout["basePositionX"]).toFloat(),
            basePositionY = readDouble(layout["basePositionY"]).toFloat(),
            baseScaleX = readDouble(layout["baseScaleX"]).toFloat(),
            baseScaleY = readDouble(layout["baseScaleY"]).toFloat(),
            baseRotationDegrees = readDouble(layout["baseRotationDegrees"]).toFloat(),
            baseWidth = readDouble(layout["baseWidth"]).toFloat(),
            baseHeight = readDouble(layout["baseHeight"]).toFloat(),
            baseCornerRadius = readDouble(layout["baseCornerRadius"]).toFloat(),
            opacity = readDouble(effects["opacity"]).toFloat(),
            blurAmount = readDouble(effects["blurAmount"]).toFloat(),
            layerOpacity = readDouble(effects["layerOpacity"]).toFloat(),
            blendMode = effects["blendMode"]?.toString() ?: "normal",
            zIndex = readLong(layout["zIndex"]).toInt(),
            channels =
                (nodeMap["channels"] as? List<*> ?: emptyList<Any?>())
                    .mapNotNull { readMotionTextScalarChannel(it) },
            layerChannels =
                (nodeMap["layerChannels"] as? List<*> ?: emptyList<Any?>())
                    .mapNotNull { readMotionTextScalarChannel(it) },
        )
    }

    private fun readMotionTextRenderNode(value: Any?): NativeMotionTextRenderNode? {
        val nodeMap = value as? Map<*, *> ?: return null
        val offsetMap = nodeMap["canvasOffset"] as? Map<*, *> ?: return null
        return NativeMotionTextRenderNode(
            id = nodeMap["id"]?.toString() ?: return null,
            text = nodeMap["text"]?.toString() ?: "",
            fullText = nodeMap["fullText"]?.toString() ?: "",
            revealUnit = nodeMap["revealUnit"]?.toString() ?: "wholeText",
            revealProgress =
                when (val rawRevealProgress = nodeMap["revealProgress"]) {
                    is Int -> rawRevealProgress.toFloat()
                    is Long -> rawRevealProgress.toFloat()
                    is Float -> rawRevealProgress
                    is Double -> rawRevealProgress.toFloat()
                    is String -> rawRevealProgress.toFloatOrNull()
                    else -> null
                },
            hasRevealAnimation =
                when (val rawHasRevealAnimation = nodeMap["hasRevealAnimation"]) {
                    is Boolean -> rawHasRevealAnimation
                    is String -> rawHasRevealAnimation == "true" || rawHasRevealAnimation == "1"
                    is Number -> rawHasRevealAnimation.toInt() != 0
                    else -> false
                },
            animationKinds =
                (nodeMap["animationKinds"] as? List<*>)
                    ?.mapNotNull { it?.toString() }
                    ?.toSet()
                    ?: emptySet(),
            animationProgressByKind =
                (nodeMap["animationProgressByKind"] as? Map<*, *>)
                    ?.mapNotNull { entry ->
                        val key = entry.key?.toString() ?: return@mapNotNull null
                        val value =
                            when (val rawValue = entry.value) {
                                is Int -> rawValue.toFloat()
                                is Long -> rawValue.toFloat()
                                is Float -> rawValue
                                is Double -> rawValue.toFloat()
                                is String -> rawValue.toFloatOrNull()
                                else -> null
                            }
                        value?.let { key to it.coerceIn(0f, 1f) }
                    }
                    ?.toMap()
                    ?: emptyMap(),
            canvasOffsetX = readDouble(offsetMap["x"]).toFloat(),
            canvasOffsetY = readDouble(offsetMap["y"]).toFloat(),
            scaleX = readDouble(nodeMap["scaleX"]).toFloat(),
            scaleY = readDouble(nodeMap["scaleY"]).toFloat(),
            rotationDegrees = readDouble(nodeMap["rotationDegrees"]).toFloat(),
            opacity = readDouble(nodeMap["opacity"]).toFloat(),
            blurAmount = readDouble(nodeMap["blurAmount"]).toFloat(),
            fontSize = readDouble(nodeMap["fontSize"]).toFloat(),
            letterSpacing = readDouble(nodeMap["letterSpacing"]).toFloat(),
            colorArgb = readLong(nodeMap["colorArgb"]).toInt(),
            fontFamily = nodeMap["fontFamily"]?.toString()?.takeIf { it.isNotBlank() },
            fontWeight = readLong(nodeMap["fontWeight"]).toInt().takeIf { it > 0 } ?: 700,
            fontStyle = nodeMap["fontStyle"]?.toString() ?: "normal",
            lineHeight = readDouble(nodeMap["lineHeight"]).toFloat().takeIf { it > 0f } ?: 1f,
            textAlignment = nodeMap["textAlignment"]?.toString() ?: "center",
            anchor = nodeMap["anchor"]?.toString() ?: "center",
            blendMode = nodeMap["blendMode"]?.toString() ?: "normal",
            zIndex = readLong(nodeMap["zIndex"]).toInt(),
            presetId = nodeMap["presetId"]?.toString(),
        )
    }

    private fun readMotionTextProgram(value: Any?): NativeMotionTextProgram? {
        val programMap = value as? Map<*, *> ?: return null
        val canvasSizeMap = programMap["canvasSize"] as? Map<*, *> ?: return null
        val canvasWidth = readDouble(canvasSizeMap["width"]).toFloat()
        val canvasHeight = readDouble(canvasSizeMap["height"]).toFloat()
        val nodes =
            (programMap["nodes"] as? List<*> ?: emptyList<Any?>())
                .mapNotNull { nodeEntry ->
                    readMotionTextProgramNode(nodeEntry)
                }
        if (nodes.isEmpty()) {
            return null
        }
        return NativeMotionTextProgram(
            canvasWidth = canvasWidth,
            canvasHeight = canvasHeight,
            nodes = nodes,
        )
    }

    private fun readMotionTextProgramNode(value: Any?): NativeMotionTextProgramNode? {
        val nodeMap = value as? Map<*, *> ?: return null
        val projectRange = nodeMap["projectRange"] as? Map<*, *> ?: return null
        return NativeMotionTextProgramNode(
            id = nodeMap["id"]?.toString() ?: return null,
            targetElementId = nodeMap["targetElementId"]?.toString() ?: return null,
            sceneId = nodeMap["sceneId"]?.toString() ?: "",
            layerId = nodeMap["layerId"]?.toString() ?: "",
            projectRangeStartMs = readLong(projectRange["startMs"]),
            projectRangeEndExclusiveMs = readLong(projectRange["endExclusiveMs"]),
            fullText = nodeMap["fullText"]?.toString() ?: "",
            revealUnit = nodeMap["revealUnit"]?.toString() ?: "wholeText",
            basePositionX = readDouble(nodeMap["basePositionX"]).toFloat(),
            basePositionY = readDouble(nodeMap["basePositionY"]).toFloat(),
            baseScaleX = readDouble(nodeMap["baseScaleX"]).toFloat(),
            baseScaleY = readDouble(nodeMap["baseScaleY"]).toFloat(),
            baseRotationDegrees = readDouble(nodeMap["baseRotationDegrees"]).toFloat(),
            baseOpacity = readDouble(nodeMap["baseOpacity"]).toFloat(),
            baseBlurAmount = readDouble(nodeMap["baseBlurAmount"]).toFloat(),
            baseFontSize = readDouble(nodeMap["baseFontSize"]).toFloat(),
            baseLetterSpacing = readDouble(nodeMap["baseLetterSpacing"]).toFloat(),
            layerOpacity = readDouble(nodeMap["layerOpacity"]).toFloat(),
            colorArgb = readLong(nodeMap["colorArgb"]).toInt(),
            fontFamily = nodeMap["fontFamily"]?.toString()?.takeIf { it.isNotBlank() },
            fontWeight = readLong(nodeMap["fontWeight"]).toInt().takeIf { it > 0 } ?: 700,
            fontStyle = nodeMap["fontStyle"]?.toString() ?: "normal",
            lineHeight = readDouble(nodeMap["lineHeight"]).toFloat().takeIf { it > 0f } ?: 1f,
            textAlignment = nodeMap["textAlignment"]?.toString() ?: "center",
            anchor = nodeMap["anchor"]?.toString() ?: "center",
            blendMode = nodeMap["blendMode"]?.toString() ?: "normal",
            zIndex = readLong(nodeMap["zIndex"]).toInt(),
            animationKinds =
                (nodeMap["animationKinds"] as? List<*>)
                    ?.mapNotNull { it?.toString() }
                    ?.toSet()
                    ?: emptySet(),
            animationBlocks =
                (nodeMap["animationBlocks"] as? List<*> ?: emptyList<Any?>())
                    .mapNotNull { readMotionTextProgramAnimationBlock(it) },
            channels =
                (nodeMap["channels"] as? List<*> ?: emptyList<Any?>())
                    .mapNotNull { readMotionTextScalarChannel(it) },
            layerChannels =
                (nodeMap["layerChannels"] as? List<*> ?: emptyList<Any?>())
                    .mapNotNull { readMotionTextScalarChannel(it) },
            name = nodeMap["name"]?.toString(),
            presetId = nodeMap["presetId"]?.toString(),
        )
    }

    private fun readMotionTextProgramAnimationBlock(
        value: Any?,
    ): NativeMotionTextProgramAnimationBlock? {
        val blockMap = value as? Map<*, *> ?: return null
        val projectRange = blockMap["projectRange"] as? Map<*, *> ?: return null
        return NativeMotionTextProgramAnimationBlock(
            id = blockMap["id"]?.toString() ?: return null,
            kind = blockMap["kind"]?.toString() ?: return null,
            projectRangeStartMs = readLong(projectRange["startMs"]),
            projectRangeEndExclusiveMs = readLong(projectRange["endExclusiveMs"]),
            interpolation =
                readMotionInterpolationSpec(blockMap["interpolation"], blockMap["interpolationKind"]),
            parameters = readMotionPropertyValueMap(blockMap["parameters"]),
            revealUnit = blockMap["revealUnit"]?.toString(),
            revealStaggerMs =
                (blockMap["revealStaggerMs"] as? Number)?.toLong()
                    ?: blockMap["revealStaggerMs"]?.toString()?.toLongOrNull(),
        )
    }

    private fun readMotionTextScalarChannel(value: Any?): NativeMotionScalarChannel? {
        val channelMap = value as? Map<*, *> ?: return null
        val projectRange = channelMap["projectRange"] as? Map<*, *> ?: return null
        val activeRange = channelMap["activeRange"] as? Map<*, *> ?: return null
        return NativeMotionScalarChannel(
            id = channelMap["id"]?.toString() ?: return null,
            propertyId = channelMap["propertyId"]?.toString() ?: return null,
            projectRangeStartMs = readLong(projectRange["startMs"]),
            projectRangeEndExclusiveMs = readLong(projectRange["endExclusiveMs"]),
            activeRangeStartMs = readLong(activeRange["startMs"]),
            activeRangeEndExclusiveMs = readLong(activeRange["endExclusiveMs"]),
            beforeStart = channelMap["beforeStart"]?.toString() ?: "clamp",
            afterEnd = channelMap["afterEnd"]?.toString() ?: "clamp",
            baseValue =
                channelMap["baseValue"]?.let { readDouble(it).toFloat() },
            fallbackValue = readDouble(channelMap["fallbackValue"]).toFloat(),
            keyframes =
                (channelMap["keyframes"] as? List<*> ?: emptyList<Any?>())
                    .mapNotNull { keyframeEntry ->
                        val keyframe = keyframeEntry as? Map<*, *> ?: return@mapNotNull null
                        NativeMotionScalarKeyframe(
                            timeMs = readLong(keyframe["timeMs"]),
                            value = readDouble(keyframe["value"]).toFloat(),
                            interpolation =
                                readMotionInterpolationSpec(
                                    keyframe["interpolation"],
                                    keyframe["interpolationKind"],
                                ),
                        )
                    }
                    .sortedBy { it.timeMs },
        )
    }

    private fun readMotionInterpolationSpec(
        interpolationValue: Any?,
        fallbackKindValue: Any?,
    ): NativeMotionInterpolationSpec {
        val interpolationMap = interpolationValue as? Map<*, *>
        val kind =
            interpolationMap?.get("kind")?.toString()
                ?: fallbackKindValue?.toString()
                ?: "__missing__"
        val bezierMap = interpolationMap?.get("bezier") as? Map<*, *>
        val springMap = interpolationMap?.get("spring") as? Map<*, *>
        val bounceMap = interpolationMap?.get("bounce") as? Map<*, *>
        val elasticMap = interpolationMap?.get("elastic") as? Map<*, *>
        return NativeMotionInterpolationSpec(
            kind = kind,
            bezier =
                bezierMap?.let {
                    NativeMotionBezierControlPoints(
                        x1 = readDouble(it["x1"]).toFloat(),
                        y1 = readDouble(it["y1"]).toFloat(),
                        x2 = readDouble(it["x2"]).toFloat(),
                        y2 = readDouble(it["y2"]).toFloat(),
                    )
                },
            spring =
                springMap?.let {
                    NativeMotionSpringSpec(
                        stiffness = readDouble(it["stiffness"]).toFloat(),
                        damping = readDouble(it["damping"]).toFloat(),
                        mass = readDouble(it["mass"]).toFloat(),
                        initialVelocity = readDouble(it["initialVelocity"]).toFloat(),
                    )
                },
            bounce =
                bounceMap?.let {
                    NativeMotionBounceSpec(
                        amplitude = readFloatOrDefault(it["amplitude"], 0.18f),
                        bounces = readIntOrDefault(it["bounces"], 3),
                        decay = readFloatOrDefault(it["decay"], 8.0f),
                    )
                },
            elastic =
                elasticMap?.let {
                    NativeMotionElasticSpec(
                        amplitude = readFloatOrDefault(it["amplitude"], 0.14f),
                        period = readFloatOrDefault(it["period"], 0.28f),
                        decay = readFloatOrDefault(it["decay"], 8.0f),
                    )
                },
        )
    }

    private fun readSceneNestedChannelCount(value: Any?): Int {
        val scenes = value as? List<*> ?: return 0
        var total = 0
        scenes.forEach { sceneEntry ->
            val scene = sceneEntry as? Map<*, *> ?: return@forEach
            total += readNestedCount(scene["propertyChannels"])
            val layers = scene["layers"] as? List<*> ?: emptyList<Any?>()
            layers.forEach layerLoop@ { layerEntry ->
                val layer = layerEntry as? Map<*, *> ?: return@layerLoop
                total += readNestedCount(layer["propertyChannels"])
                val elements = layer["elements"] as? List<*> ?: emptyList<Any?>()
                elements.forEach elementLoop@ { elementEntry ->
                    val element = elementEntry as? Map<*, *> ?: return@elementLoop
                    total += readNestedCount(element["propertyChannels"])
                }
            }
        }
        return total
    }

    private fun buildExportComposition(
        compositionMap: Map<String, Any?>,
        preset: String,
        requestedFrameRate: Int?,
    ): NativeExportComposition {
        val assetsById = HashMap<String, Map<*, *>>()
        val assets = compositionMap["assets"] as? List<*> ?: emptyList<Any?>()
        assets.forEach { assetEntry ->
            val asset = assetEntry as? Map<*, *> ?: return@forEach
            val assetId = asset["assetId"]?.toString()
            if (!assetId.isNullOrBlank()) {
                assetsById[assetId] = asset
            }
        }
        val trackMaps =
            (compositionMap["tracks"] as? List<*> ?: emptyList<Any?>())
                .mapNotNull { it as? Map<*, *> }
        val visualCompositorGraph =
            readVisualCompositorGraph(compositionMap["visualCompositorGraph"])
                ?: throw IllegalArgumentException("Visual compositor graph is missing.")
        val audioTrack =
            trackMaps.firstOrNull { track ->
                val clips = track["clips"] as? List<*> ?: emptyList<Any?>()
                val kind = track["kind"]?.toString() ?: ""
                clips.isNotEmpty() && kind == "audio"
            }
        val outputFrameRate = resolveOutputFrameRate(compositionMap, requestedFrameRate)
        val outputSize = resolvePresetOutputSize(compositionMap, preset)
        val timelineDurationMs = readDurationMs(compositionMap)
        val canonicalEffectsGraph = readCanonicalEffectsGraph(compositionMap["canonicalEffectsGraph"])
        val motionTextRasterContract =
            readMotionTextRasterContract(compositionMap["motionTextRasterContract"])
        val motionTextRasterProgram =
            readMotionTextRasterProgram(compositionMap["motionTextRasterProgram"])
        val authoredVisualSurfaceProgram =
            readAuthoredVisualSurfaceProgram(compositionMap["authoredVisualSurfaceProgram"])
        val motionTextProgram = readMotionTextProgram(compositionMap["motionTextProgram"])
        val motionTextRenderTrack = readMotionTextRenderTrack(compositionMap["motionTextRenderTrack"])
        val motionTextRuntime =
            NativeMotionTextRuntimeBundle(
                program = motionTextProgram,
                rasterProgram = motionTextRasterProgram,
                rasterContract = motionTextRasterContract,
                renderTrack = motionTextRenderTrack,
            )
        val authoredVisualSurfaceRuntime =
            NativeAuthoredVisualSurfaceRuntimeBundle(program = authoredVisualSurfaceProgram)
        val visualClips =
            buildNativeVisualClipsFromGraph(
                visualCompositorGraph = visualCompositorGraph,
                trackMaps = trackMaps,
                assetsById = assetsById,
            )
        val resolvedCompositorExecutions =
            resolveCompositorWindowExecutions(
                clips = visualClips,
                visualCompositorGraph = visualCompositorGraph,
            )
        val visualAssemblyDiagnostics =
            buildVisualAssemblyDiagnostics(
                clips = visualClips,
                visualCompositorGraph = visualCompositorGraph,
                resolvedCompositorExecutions = resolvedCompositorExecutions,
            )
        val canonicalEffectsDiagnostics =
            canonicalEffectsGraph?.let(::buildCanonicalEffectsDiagnostics)
        val authoredVisualSurfaceDiagnostics =
            buildAuthoredVisualSurfaceDiagnostics(
                visualCompositorGraph = visualCompositorGraph,
                runtimeBundle = authoredVisualSurfaceRuntime,
            )
        val usesIndependentMotionTextOverlayClock =
            outputSize != null &&
                visualCompositorGraph.motionTextOverlayWindows.isNotEmpty() &&
                motionTextRuntime.hasOverlaySource()
        val motionTextOverlayGlBlurDecision =
            when {
                !usesIndependentMotionTextOverlayClock ->
                    NativeMotionTextGlBlurDecision(
                        executionMode = NativeMotionTextBlurExecutionMode.SOFTWARE_LOCAL,
                        reasonCode = "overlay_sequence_unavailable",
                        reasonDetail =
                            "Media3 GL blur requires the independent motion-text overlay sequence.",
                    )
                outputSize == null ->
                    NativeMotionTextGlBlurDecision(
                        executionMode = NativeMotionTextBlurExecutionMode.SOFTWARE_LOCAL,
                        reasonCode = "missing_output_size",
                        reasonDetail = "Output size is unavailable for GL blur scaling.",
                    )
                else ->
                    resolveMotionTextGlBlurDecision(
                        motionTextRuntime = motionTextRuntime,
                        outputSize = outputSize,
                        durationMs = timelineDurationMs,
                        outputFrameRate = outputFrameRate,
                    )
            }
        val motionTextParityDiagnostics =
            if (motionTextRuntime.isAvailableForParity()) {
                MotionTextCanvasOverlay(
                    runtimeBundle = motionTextRuntime,
                    clipTimelineStartMs = 0L,
                    blurExecutionMode = motionTextOverlayGlBlurDecision.executionMode,
                    glBlurSigmaPx = motionTextOverlayGlBlurDecision.sigmaPx,
                    glBlurDecisionCode = motionTextOverlayGlBlurDecision.reasonCode,
                    glBlurDecisionDetail = motionTextOverlayGlBlurDecision.reasonDetail,
                ).buildParityDiagnostics()
            } else {
                null
            }
        val audioClips =
            buildNativeExportClips(
                track = audioTrack,
                assetsById = assetsById,
                forcedTrackKind = NativeExportClipKind.AUDIO,
            )
        val visualSequenceAssembly =
            buildEditedSequence(
                clips = visualClips,
                enabledTrackTypes = setOf(C.TRACK_TYPE_AUDIO, C.TRACK_TYPE_VIDEO),
                outputFrameRate = outputFrameRate,
                outputSize = outputSize,
                motionTextRuntime = motionTextRuntime,
                visualAssemblyWindows = visualCompositorGraph.windows,
                resolvedCompositorExecutions = resolvedCompositorExecutions,
                attachMotionTextOverlayToMediaClips = !usesIndependentMotionTextOverlayClock,
            )
        val motionTextOverlaySequenceAssembly =
            if (usesIndependentMotionTextOverlayClock) {
                buildMotionTextOverlaySequence(
                    durationMs =
                        visualSequenceAssembly?.durationMs
                            ?.takeIf { duration -> duration > 0L }
                            ?: timelineDurationMs,
                    outputFrameRate = outputFrameRate,
                    outputSize =
                        outputSize
                            ?: throw IllegalArgumentException(
                                "Motion text export requires a resolved output size.",
                            ),
                    motionTextRuntime = motionTextRuntime,
                    glBlurDecision = motionTextOverlayGlBlurDecision,
                    overlayWindows = visualCompositorGraph.motionTextOverlayWindows,
                )
            } else {
                null
            }
        val audioSequenceAssembly =
            buildEditedSequence(
                clips = audioClips,
                enabledTrackTypes = setOf(C.TRACK_TYPE_AUDIO),
                outputFrameRate = null,
                outputSize = null,
                motionTextRuntime = null,
                visualAssemblyWindows = emptyList(),
                resolvedCompositorExecutions = emptyMap(),
            )
        val sequences =
            listOfNotNull(
                motionTextOverlaySequenceAssembly?.sequence,
                visualSequenceAssembly?.sequence,
                audioSequenceAssembly?.sequence,
            )
        val assembledDurationMs =
            maxOf(
                motionTextOverlaySequenceAssembly?.durationMs ?: 0L,
                visualSequenceAssembly?.durationMs ?: 0L,
                audioSequenceAssembly?.durationMs ?: 0L,
            )
        val executionDurationMs =
            assembledDurationMs.takeIf { it > 0L } ?: timelineDurationMs
        return NativeExportComposition(
            composition = Composition.Builder(sequences).build(),
            clips = visualClips + audioClips,
            durationMs = executionDurationMs,
            timelineDurationMs = timelineDurationMs,
            executionDurationMs = executionDurationMs,
            expectsAudio = audioClips.isNotEmpty(),
            outputSize = outputSize,
            motionTextParityDiagnostics = motionTextParityDiagnostics,
            canonicalEffectsDiagnostics = canonicalEffectsDiagnostics,
            authoredVisualSurfaceDiagnostics = authoredVisualSurfaceDiagnostics,
            visualAssemblyDiagnostics = visualAssemblyDiagnostics,
        )
    }

    private fun buildNativeExportClips(
        track: Map<*, *>?,
        assetsById: Map<String, Map<*, *>>,
        forcedTrackKind: NativeExportClipKind?,
    ): List<NativeExportClip> {
        if (track == null) {
            return emptyList()
        }
        val clips = mutableListOf<NativeExportClip>()
        val clipEntries = track["clips"] as? List<*> ?: emptyList<Any?>()
        clipEntries.forEach { clipEntry ->
            val clip = clipEntry as? Map<*, *> ?: return@forEach
            val assetId = clip["assetId"]?.toString() ?: return@forEach
            val asset = assetsById[assetId] ?: return@forEach
            val sourceUri = asset["sourceUri"]?.toString() ?: return@forEach
            val assetKind =
                forcedTrackKind
                    ?: when (asset["kind"]?.toString()) {
                        "image" -> NativeExportClipKind.IMAGE
                        "audio" -> NativeExportClipKind.AUDIO
                        else -> NativeExportClipKind.VIDEO
                    }
            clips.add(
                NativeExportClip(
                    clipId = clip["clipId"]?.toString() ?: assetId,
                    sourceUri = sourceUri,
                    assetKind = assetKind,
                    timelineStartMs = readLong(clip["timelineStartMs"]),
                    timelineDurationMs = readLong(clip["timelineDurationMs"]),
                    sourceStartMs = readLong(clip["sourceStartMs"]),
                    sourceDurationMs = readLong(clip["sourceDurationMs"]),
                    playbackRate = readDouble(clip["playbackRate"]).toFloat(),
                ),
            )
        }
        return clips
    }

    private fun buildNativeVisualClipsFromGraph(
        visualCompositorGraph: NativeVisualCompositorGraph,
        trackMaps: List<Map<*, *>>,
        assetsById: Map<String, Map<*, *>>,
    ): List<NativeExportClip> {
        val visualClipLookup = linkedMapOf<String, NativeExportClip>()
        trackMaps.forEach { track ->
            val kind = track["kind"]?.toString() ?: ""
            if (kind != "video" && kind != "image") {
                return@forEach
            }
            buildNativeExportClips(track, assetsById, null).forEach { clip ->
                visualClipLookup[clip.clipId] = clip
            }
        }
        val splitClips =
            visualCompositorGraph.mediaSegments.flatMap { segment ->
                val clipId =
                    segment.clipId
                        ?: throw IllegalArgumentException(
                            "Visual compositor media segment `${segment.id}` is missing clipId.",
                        )
                val clip =
                    visualClipLookup[clipId]
                        ?: throw IllegalArgumentException(
                            "Visual compositor graph references unknown media clip `$clipId`.",
                        )
                val overlappingWindows =
                    visualCompositorGraph.windows.filter { window ->
                        window.timelineStartMs < segment.timelineEndExclusiveMs &&
                            window.timelineEndExclusiveMs > segment.timelineStartMs
                    }.sortedBy { window -> window.timelineStartMs }
                require(overlappingWindows.isNotEmpty()) {
                    "Visual assembly windows do not cover media segment `${segment.id}`."
                }
                val canStayAsSingleMediaExecution =
                    overlappingWindows.all { window ->
                        window.supportsCurrentBackend &&
                            !window.requiresVisualCompositor &&
                            (window.policy == "mediaOnly" ||
                                window.policy == "mediaWithAuthoredOverlay")
                    }
                if (canStayAsSingleMediaExecution) {
                    val routePolicy =
                        if (overlappingWindows.any { window ->
                                window.policy == "mediaWithAuthoredOverlay"
                            }
                        ) {
                            "mediaTimelineRouteWithAuthoredOverlay"
                        } else {
                            "mediaTimelineRoute"
                        }
                    return@flatMap listOf(
                        clip.copy(
                            graphLayerId = segment.layerId,
                            graphSegmentId = segment.id,
                            graphWindowId = overlappingWindows.singleOrNull()?.id,
                            graphWindowPolicy = routePolicy,
                            graphZOrder = segment.zOrder,
                            coveredWindowIds = overlappingWindows.map { window -> window.id },
                        ),
                    )
                }
                var coverageCursorMs = segment.timelineStartMs
                val splitSegmentClips = mutableListOf<NativeExportClip>()
                overlappingWindows.forEach { window ->
                    val splitStartMs = maxOf(window.timelineStartMs, segment.timelineStartMs)
                    val splitEndExclusiveMs =
                        minOf(window.timelineEndExclusiveMs, segment.timelineEndExclusiveMs)
                    if (splitEndExclusiveMs <= splitStartMs) {
                        return@forEach
                    }
                    require(splitStartMs == coverageCursorMs) {
                        "Visual assembly windows leave an uncovered gap inside media segment `${segment.id}`."
                    }
                    coverageCursorMs = splitEndExclusiveMs
                    val requestedTimelineDurationMs =
                        (splitEndExclusiveMs - splitStartMs).coerceAtLeast(1L)
                    val clipTimelineStartOffsetMs =
                        (splitStartMs - clip.timelineStartMs).coerceAtLeast(0L)
                    val clipTimelineEndOffsetMs =
                        (splitEndExclusiveMs - clip.timelineStartMs)
                            .coerceAtLeast(clipTimelineStartOffsetMs)
                    val maxSourceEndExclusiveMs =
                        clip.sourceStartMs + clip.sourceDurationMs
                    val splitSourceStartMs =
                        (clip.sourceStartMs +
                            mapTimelineOffsetToSourceOffsetMs(
                                timelineOffsetMs = clipTimelineStartOffsetMs,
                                clipTimelineDurationMs = clip.timelineDurationMs,
                                clipSourceDurationMs = clip.sourceDurationMs,
                            )).coerceAtMost(
                            (maxSourceEndExclusiveMs - 1L).coerceAtLeast(clip.sourceStartMs),
                        )
                    val splitSourceEndExclusiveMs =
                        (clip.sourceStartMs +
                            mapTimelineOffsetToSourceOffsetMs(
                                timelineOffsetMs = clipTimelineEndOffsetMs,
                                clipTimelineDurationMs = clip.timelineDurationMs,
                                clipSourceDurationMs = clip.sourceDurationMs,
                            ))
                            .coerceAtMost(maxSourceEndExclusiveMs)
                    val splitSourceDurationMs =
                        (splitSourceEndExclusiveMs - splitSourceStartMs).coerceAtLeast(1L)
                    splitSegmentClips +=
                        clip.copy(
                            timelineStartMs = splitStartMs,
                            timelineDurationMs = requestedTimelineDurationMs,
                            sourceStartMs = splitSourceStartMs,
                            sourceDurationMs = splitSourceDurationMs,
                            graphLayerId = segment.layerId,
                            graphSegmentId = segment.id,
                            graphWindowId = window.id,
                            graphWindowPolicy = window.policy,
                            graphZOrder = segment.zOrder,
                            coveredWindowIds = listOf(window.id),
                        )
                }
                require(coverageCursorMs == segment.timelineEndExclusiveMs) {
                    "Visual assembly windows do not fully cover media segment `${segment.id}`."
                }
                splitSegmentClips
            }
        return splitClips
            .sortedWith(
                compareBy<NativeExportClip>(
                    { it.timelineStartMs },
                    { it.graphZOrder ?: 0 },
                    { it.graphWindowId ?: "" },
                ),
            ).mapIndexed { index, clip ->
                clip.copy(graphAssemblyOrder = index)
            }
    }

    private fun mapTimelineOffsetToSourceOffsetMs(
        timelineOffsetMs: Long,
        clipTimelineDurationMs: Long,
        clipSourceDurationMs: Long,
    ): Long {
        if (clipSourceDurationMs <= 0L || timelineOffsetMs <= 0L) {
            return 0L
        }
        if (clipTimelineDurationMs <= 0L || timelineOffsetMs >= clipTimelineDurationMs) {
            return clipSourceDurationMs.coerceAtLeast(0L)
        }
        val normalizedProgress = timelineOffsetMs.toDouble() / clipTimelineDurationMs.toDouble()
        return (clipSourceDurationMs * normalizedProgress)
            .roundToLong()
            .coerceIn(0L, clipSourceDurationMs)
    }

    private fun buildEditedSequence(
        clips: List<NativeExportClip>,
        enabledTrackTypes: Set<Int>,
        outputFrameRate: Int?,
        outputSize: OutputSize?,
        motionTextRuntime: NativeMotionTextRuntimeBundle?,
        visualAssemblyWindows: List<NativeVisualAssemblyWindow>,
        resolvedCompositorExecutions: Map<String, NativeResolvedCompositorWindowExecution>,
        attachMotionTextOverlayToMediaClips: Boolean = true,
    ): NativeEditedSequenceAssembly? {
        if (clips.isEmpty()) {
            return null
        }
        var assembledDurationMs = 0L
        val sequenceBuilder =
            EditedMediaItemSequence.Builder(enabledTrackTypes).apply {
                clips.forEach { clip ->
                    val clipWindowRouting =
                        if (clip.assetKind == NativeExportClipKind.AUDIO) {
                            null
                        } else {
                            buildClipWindowRoutingPlan(clip, visualAssemblyWindows)
                        }
                    val unresolvedBlockedWindows =
                        clipWindowRouting?.blockedWindows?.filter { window ->
                            val execution = resolvedCompositorExecutions[window.id]
                            execution == null || !execution.isExecutable
                        } ?: emptyList()
                    if (clipWindowRouting != null && unresolvedBlockedWindows.isNotEmpty()) {
                        throw IllegalArgumentException(
                            buildCompositorRequiredWindowMessage(
                                unresolvedBlockedWindows.first(),
                            ),
                        )
                    }
                    val authoritativeWindow =
                        if (clip.assetKind == NativeExportClipKind.AUDIO) {
                            null
                        } else {
                            require(clipWindowRouting != null)
                            when (clip.graphWindowPolicy) {
                                "mediaTimelineRoute",
                                "mediaTimelineRouteWithAuthoredOverlay",
                                -> null
                                else -> {
                                    require(clipWindowRouting.overlappingWindows.size == 1) {
                                        "Visual clip `${clip.clipId}` spans multiple window policies and must be split before export."
                                    }
                                    clipWindowRouting.overlappingWindows.single()
                                }
                            }
                        }
                    val compositorExecution =
                        authoritativeWindow?.takeIf { window ->
                            window.executionOwner == "nativeVisualCompositor"
                        }?.let { window ->
                            resolvedCompositorExecutions[window.id]
                                ?: throw IllegalArgumentException(
                                    "Compositor window `${window.id}` is missing a resolved execution plan.",
                                )
                        }
                    if (authoritativeWindow != null) {
                        require(clip.graphWindowId == authoritativeWindow.id) {
                            "Visual clip `${clip.clipId}` lost its authoritative window provenance."
                        }
                        require(clip.graphWindowPolicy == authoritativeWindow.policy) {
                            "Visual clip `${clip.clipId}` route drifted from window `${authoritativeWindow.id}`."
                        }
                    }
                    if (compositorExecution != null) {
                        if (!compositorExecution.isExecutable) {
                            throw IllegalArgumentException(compositorExecution.detail)
                        }
                        if (clip.graphSegmentId != compositorExecution.baseSegmentId) {
                            return@forEach
                        }
                    }
                    val mediaItemBuilder =
                        MediaItem.Builder()
                            .setUri(clip.sourceUri)
                            .setMediaId(clip.clipId)
                    if (clip.assetKind != NativeExportClipKind.IMAGE) {
                        mediaItemBuilder.setClippingConfiguration(
                            MediaItem.ClippingConfiguration.Builder()
                                .setStartPositionMs(clip.sourceStartMs)
                                .setEndPositionMs(clip.sourceStartMs + clip.sourceDurationMs)
                                .build(),
                        )
                    }
                    val mediaItem = mediaItemBuilder.build()
                    val editedItemBuilder =
                        EditedMediaItem.Builder(mediaItem).apply {
                            when (clip.assetKind) {
                                NativeExportClipKind.IMAGE -> {
                                    val effectiveFrameRate =
                                        if (outputFrameRate != null && outputFrameRate > 0) {
                                            outputFrameRate
                                        } else {
                                            30
                                        }
                                    if (effectiveFrameRate > 0) {
                                        setFrameRate(effectiveFrameRate)
                                    }
                                    setRemoveAudio(true)
                                    setDurationUs(clip.timelineDurationMs.coerceAtLeast(1L) * 1000L)
                                }

                                NativeExportClipKind.AUDIO -> {
                                    setRemoveVideo(true)
                                }

                                NativeExportClipKind.VIDEO -> {
                                    val effectiveFrameRate =
                                        if (outputFrameRate != null && outputFrameRate > 0) {
                                            outputFrameRate
                                        } else {
                                            30
                                        }
                                    if (effectiveFrameRate > 0) {
                                        setFrameRate(effectiveFrameRate)
                                    }
                                }
                            }
                            if (kotlin.math.abs(clip.playbackRate - 1.0f) > 0.001f) {
                                setSpeed(ConstantSpeedProvider(clip.playbackRate))
                            }
                            if (clip.assetKind != NativeExportClipKind.AUDIO) {
                                val videoEffects = mutableListOf<Effect>()
                                if (outputSize != null) {
                                    videoEffects +=
                                        Presentation.createForWidthAndHeight(
                                            outputSize.width,
                                            outputSize.height,
                                                Presentation.LAYOUT_SCALE_TO_FIT,
                                        )
                                }
                                val overlayItems = mutableListOf<TextureOverlay>()
                                if (compositorExecution != null) {
                                    val compositorWindow =
                                        authoritativeWindow
                                            ?: throw IllegalArgumentException(
                                                "Compositor route for `${clip.clipId}` is missing its authoritative window.",
                                            )
                                    compositorExecution.overlayImageClips.forEach { overlayClip ->
                                        overlayItems +=
                                            WindowImageCanvasOverlay(
                                                context = appContext,
                                                overlayClip = overlayClip,
                                                clipTimelineStartMs = clip.timelineStartMs,
                                                allowedTimelineWindows = listOf(compositorWindow),
                                            )
                                    }
                                    if (attachMotionTextOverlayToMediaClips &&
                                        motionTextRuntime?.hasOverlaySource() == true &&
                                        compositorExecution.authoredNodeIds.isNotEmpty()
                                    ) {
                                        overlayItems +=
                                            MotionTextCanvasOverlay(
                                                runtimeBundle = motionTextRuntime,
                                                clipTimelineStartMs = clip.timelineStartMs,
                                                allowedTimelineWindows = listOf(compositorWindow),
                                                allowedNodeIds =
                                                    compositorExecution.authoredNodeIds.toSet(),
                                                orderedNodeIds =
                                                    compositorExecution.authoredNodeIds,
                                            )
                                    }
                                } else {
                                    val overlayWindows =
                                        when (clip.graphWindowPolicy) {
                                            "mediaWithAuthoredOverlay" ->
                                                authoritativeWindow?.let(::listOf) ?: emptyList()
                                            "mediaOnly" -> emptyList()
                                            "mediaTimelineRouteWithAuthoredOverlay" ->
                                                clipWindowRouting?.overlayWindows ?: emptyList()
                                            "mediaTimelineRoute" -> emptyList()
                                            null -> emptyList()
                                            else ->
                                                throw IllegalArgumentException(
                                                    "Visual clip `${clip.clipId}` resolved to unsupported route `${clip.graphWindowPolicy}`.",
                                                )
                                    }
                                    val hasOverlappingAuthoredOverlay =
                                        overlayWindows.isNotEmpty()
                                    if (attachMotionTextOverlayToMediaClips &&
                                        motionTextRuntime?.hasOverlaySource() == true &&
                                        hasOverlappingAuthoredOverlay
                                    ) {
                                        overlayItems +=
                                            MotionTextCanvasOverlay(
                                                runtimeBundle = motionTextRuntime,
                                                clipTimelineStartMs = clip.timelineStartMs,
                                                allowedTimelineWindows = overlayWindows,
                                            )
                                    }
                                }
                                if (overlayItems.isNotEmpty()) {
                                    videoEffects += OverlayEffect(overlayItems)
                                }
                                if (videoEffects.isNotEmpty()) {
                                    setEffects(Effects(emptyList(), videoEffects))
                                }
                        }
                    }
                    addItem(editedItemBuilder.build())
                    assembledDurationMs += clip.timelineDurationMs
                }
            }
        return NativeEditedSequenceAssembly(
            sequence = sequenceBuilder.build(),
            durationMs = assembledDurationMs,
        )
    }

    private fun buildMotionTextOverlaySequence(
        durationMs: Long,
        outputFrameRate: Int?,
        outputSize: OutputSize,
        motionTextRuntime: NativeMotionTextRuntimeBundle,
        glBlurDecision: NativeMotionTextGlBlurDecision,
        overlayWindows: List<NativeVisualAssemblyWindow>,
    ): NativeEditedSequenceAssembly? {
        if (durationMs <= 0L || overlayWindows.isEmpty()) {
            return null
        }
        if (!motionTextRuntime.hasOverlaySource()) {
            return null
        }
        val effectiveFrameRate =
            outputFrameRate?.takeIf { frameRate -> frameRate > 0 } ?: 30
        val glBlurSigmaPx =
            glBlurDecision.sigmaPx.takeIf { sigma ->
                glBlurDecision.executionMode == NativeMotionTextBlurExecutionMode.MEDIA3_GL_SEQUENCE &&
                    sigma != null &&
                    sigma > 0.05f
            }
        val sequenceGlEffects = buildMotionTextSequenceGlEffects(glBlurDecision)
        val transparentOverlayAsset = ensureTransparentOverlayAsset(outputSize)
        val mediaItem =
            MediaItem.Builder()
                .setUri(transparentOverlayAsset.absolutePath)
                .setMediaId("motion-text-overlay-track")
                .setMimeType(MimeTypes.IMAGE_PNG)
                .setImageDurationMs(durationMs.coerceAtLeast(1L))
                .build()
        val videoEffects =
            mutableListOf<Effect>(
                Presentation.createForWidthAndHeight(
                    outputSize.width,
                    outputSize.height,
                    Presentation.LAYOUT_SCALE_TO_FIT,
                ),
                OverlayEffect(
                    listOf(
                        MotionTextCanvasOverlay(
                            runtimeBundle = motionTextRuntime,
                            clipTimelineStartMs = 0L,
                            allowedTimelineWindows = overlayWindows,
                            glBlurSigmaPx = glBlurSigmaPx,
                            blurExecutionMode = glBlurDecision.executionMode,
                            glBlurDecisionCode = glBlurDecision.reasonCode,
                            glBlurDecisionDetail = glBlurDecision.reasonDetail,
                        ),
                    ),
                ),
            )
        videoEffects += sequenceGlEffects
        val editedItem =
            EditedMediaItem.Builder(mediaItem)
                .setFrameRate(effectiveFrameRate)
                .setRemoveAudio(true)
                .setDurationUs(durationMs.coerceAtLeast(1L) * 1000L)
                .setEffects(Effects(emptyList(), videoEffects))
                .build()
        val sequence =
            EditedMediaItemSequence.Builder(setOf(C.TRACK_TYPE_VIDEO))
                .addItem(editedItem)
                .build()
        return NativeEditedSequenceAssembly(
            sequence = sequence,
            durationMs = durationMs,
        )
    }

    private fun resolveMotionTextGlBlurDecision(
        motionTextRuntime: NativeMotionTextRuntimeBundle,
        outputSize: OutputSize,
        durationMs: Long,
        outputFrameRate: Int?,
    ): NativeMotionTextGlBlurDecision {
        val rasterProgram =
            motionTextRuntime.rasterProgram
                ?: return NativeMotionTextGlBlurDecision(
                    executionMode = NativeMotionTextBlurExecutionMode.SOFTWARE_LOCAL,
                    reasonCode = "missing_raster_program",
                    reasonDetail = "Media3 GL blur currently requires a motion-text raster program.",
                )
        val blurEngineId =
            rasterProgram.blurEngineId
                .takeIf { it.isNotBlank() }
                ?: motionTextRuntime.rasterContract?.blurEngineId
                ?: NativeMotionTextRasterContract.DEFAULT.blurEngineId
        if (blurEngineId != "gaussian_layer_blur") {
            return NativeMotionTextGlBlurDecision(
                executionMode = NativeMotionTextBlurExecutionMode.SOFTWARE_LOCAL,
                reasonCode = "unsupported_blur_contract",
                reasonDetail =
                    "GL sequence blur currently supports gaussian_layer_blur only, received `$blurEngineId`.",
            )
        }
        if (rasterProgram.nodes.isEmpty()) {
            return NativeMotionTextGlBlurDecision(
                executionMode = NativeMotionTextBlurExecutionMode.SOFTWARE_LOCAL,
                reasonCode = "empty_raster_program",
                reasonDetail = "Motion-text raster program has no nodes to blur.",
            )
        }
        if (durationMs <= 0L) {
            return NativeMotionTextGlBlurDecision(
                executionMode = NativeMotionTextBlurExecutionMode.SOFTWARE_LOCAL,
                reasonCode = "missing_duration",
                reasonDetail = "GL sequence blur requires a positive timeline duration.",
            )
        }
        val effectiveFrameRate =
            outputFrameRate?.takeIf { frameRate -> frameRate > 0 } ?: 30
        rasterProgram.nodes.forEach { node ->
            if (node.blendMode != "normal") {
                return NativeMotionTextGlBlurDecision(
                    executionMode = NativeMotionTextBlurExecutionMode.SOFTWARE_LOCAL,
                    reasonCode = "unsupported_blend_mode",
                    reasonDetail =
                        "Node `${node.id}` uses `${node.blendMode}`; the first GL blur lane supports normal blend only.",
                )
            }
        }
        val effectSegments =
            buildMotionTextSequenceEffectSegments(
                rasterProgram = rasterProgram,
                outputSize = outputSize,
                durationMs = durationMs,
                outputFrameRate = effectiveFrameRate,
            ) ?: return NativeMotionTextGlBlurDecision(
                executionMode = NativeMotionTextBlurExecutionMode.SOFTWARE_LOCAL,
                reasonCode = "non_uniform_timeline_effects",
                reasonDetail =
                    "Motion-text nodes do not resolve to one shared blur/opacity timeline, so the generic sequence-level GL effect stack cannot own them yet.",
            )
        if (effectSegments.isEmpty()) {
            return NativeMotionTextGlBlurDecision(
                executionMode = NativeMotionTextBlurExecutionMode.SOFTWARE_LOCAL,
                reasonCode = "blur_not_requested",
                reasonDetail =
                    "Motion-text nodes do not currently request blur or post-blur alpha scaling on the isolated overlay sequence.",
            )
        }
        val sigmaPx = effectSegments.maxOfOrNull { segment -> segment.blurSigmaPx } ?: 0f
        if (sigmaPx <= 0.05f) {
            return NativeMotionTextGlBlurDecision(
                executionMode = NativeMotionTextBlurExecutionMode.SOFTWARE_LOCAL,
                reasonCode = "sigma_below_threshold",
                reasonDetail =
                    "Resolved GL blur sigma `${formatMotionTextDecisionValue(sigmaPx)}` is below the activation threshold.",
            )
        }
        return NativeMotionTextGlBlurDecision(
            executionMode = NativeMotionTextBlurExecutionMode.MEDIA3_GL_SEQUENCE,
            sigmaPx = sigmaPx,
            effectSegments = effectSegments,
            reasonCode = "enabled_timeline_sequence_effects",
            reasonDetail =
                "Shared blur/opacity timeline maps to ${effectSegments.size} isolated overlay-sequence GL effect segment(s) with max sigma `${formatMotionTextDecisionValue(sigmaPx)}`.",
        )
    }

    private fun buildMotionTextSequenceEffectSegments(
        rasterProgram: NativeMotionTextRasterProgram,
        outputSize: OutputSize,
        durationMs: Long,
        outputFrameRate: Int,
    ): List<NativeMotionTextGlEffectSegment>? {
        val referenceCanvasWidth =
            rasterProgram.canvasWidth.takeIf { it > 0f } ?: outputSize.width.toFloat()
        val referenceCanvasHeight =
            rasterProgram.canvasHeight.takeIf { it > 0f } ?: outputSize.height.toFloat()
        val outputScale =
            minOf(
                outputSize.width.toFloat() / referenceCanvasWidth,
                outputSize.height.toFloat() / referenceCanvasHeight,
            ).coerceAtLeast(0.01f)
        val sampleStepMs =
            (1000.0 / outputFrameRate.coerceAtLeast(1).toDouble()).roundToLong().coerceAtLeast(1L)
        val boundaries = linkedSetOf<Long>()
        var cursorMs = 0L
        while (cursorMs < durationMs) {
            boundaries += cursorMs
            cursorMs += sampleStepMs
        }
        boundaries += durationMs
        val sortedBoundaries = boundaries.toMutableList().sorted()
        val segments = mutableListOf<NativeMotionTextGlEffectSegment>()
        for (index in 0 until sortedBoundaries.lastIndex) {
            val startMs = sortedBoundaries[index]
            val endMs = sortedBoundaries[index + 1]
            if (endMs <= startMs) {
                continue
            }
            val sampleTimeMs =
                minOf(
                    durationMs - 1L,
                    startMs + ((endMs - startMs) / 2L),
                ).coerceAtLeast(0L)
            val firstNode = rasterProgram.nodes.first()
            val referenceBlurAmount =
                evaluateRasterNodeBlurAmount(firstNode, sampleTimeMs) ?: return null
            val referenceOpacity =
                evaluateRasterNodeOpacity(firstNode, sampleTimeMs) ?: return null
            val nodesAreUniform =
                rasterProgram.nodes.drop(1).all { node ->
                    val blurAmount = evaluateRasterNodeBlurAmount(node, sampleTimeMs) ?: return null
                    val opacity = evaluateRasterNodeOpacity(node, sampleTimeMs) ?: return null
                    abs(blurAmount - referenceBlurAmount) <= 0.05f &&
                        abs(opacity - referenceOpacity) <= 0.02f
                }
            if (!nodesAreUniform) {
                return null
            }
            val sigmaPx =
                (referenceBlurAmount.coerceAtLeast(0f) *
                    rasterProgram.rasterizationPolicy.blurSigmaScale *
                    outputScale).coerceAtLeast(0f)
            val alphaScale = referenceOpacity.coerceIn(0f, 1f)
            val contributesEffect = sigmaPx > 0.05f || alphaScale < 0.999f
            if (!contributesEffect) {
                continue
            }
            val previousSegment = segments.lastOrNull()
            if (previousSegment != null &&
                previousSegment.endTimeUs == (startMs * 1000L) &&
                abs(previousSegment.blurSigmaPx - sigmaPx) <= 0.05f &&
                abs(previousSegment.alphaScale - alphaScale) <= 0.02f
            ) {
                segments[segments.lastIndex] =
                    previousSegment.copy(endTimeUs = endMs * 1000L)
            } else {
                segments +=
                    NativeMotionTextGlEffectSegment(
                        startTimeUs = startMs * 1000L,
                        endTimeUs = endMs * 1000L,
                        blurSigmaPx = sigmaPx,
                        alphaScale = alphaScale,
                    )
            }
        }
        return segments
    }

    private fun resolveConstantNodeBlurAmount(
        node: NativeMotionTextRasterProgramNode,
    ): Float? {
        val blurChannels =
            (node.channels + node.layerChannels)
                .filter { channel -> channel.propertyId == "visual.blur.amount" }
        if (blurChannels.isEmpty()) {
            return node.blurAmount
        }
        val resolvedValues =
            blurChannels.map { channel ->
                resolveConstantScalarChannelValue(channel)
                    ?: return null
            }
        val referenceValue = resolvedValues.firstOrNull() ?: return node.blurAmount
        if (resolvedValues.any { value -> abs(value - referenceValue) > 0.05f }) {
            return null
        }
        if (abs(node.blurAmount - referenceValue) > 0.05f) {
            return null
        }
        return referenceValue
    }

    private fun resolveConstantScalarChannelValue(
        channel: NativeMotionScalarChannel,
    ): Float? {
        val referenceValue = channel.baseValue ?: channel.fallbackValue
        if (abs(channel.fallbackValue - referenceValue) > 0.05f) {
            return null
        }
        if (channel.keyframes.any { keyframe -> abs(keyframe.value - referenceValue) > 0.05f }) {
            return null
        }
        return referenceValue
    }

    private fun buildMotionTextSequenceGlEffects(
        glBlurDecision: NativeMotionTextGlBlurDecision,
    ): List<Effect> {
        if (glBlurDecision.executionMode != NativeMotionTextBlurExecutionMode.MEDIA3_GL_SEQUENCE) {
            return emptyList()
        }
        if (glBlurDecision.effectSegments.isEmpty()) {
            return emptyList()
        }
        val effects = mutableListOf<Effect>()
        glBlurDecision.effectSegments.forEach { segment ->
            if (segment.blurSigmaPx > 0.05f) {
                effects +=
                    TimestampWrapper(
                        GaussianBlur(segment.blurSigmaPx),
                        segment.startTimeUs,
                        segment.endTimeUs,
                    )
            }
            if (segment.alphaScale < 0.999f) {
                effects +=
                    TimestampWrapper(
                        AlphaScale(segment.alphaScale),
                        segment.startTimeUs,
                        segment.endTimeUs,
                    )
            }
        }
        return effects
    }

    private fun evaluateRasterNodeBlurAmount(
        node: NativeMotionTextRasterProgramNode,
        timeMs: Long,
    ): Float? =
        evaluateUniformScalarChannelsAtTime(
            channels = node.channels + node.layerChannels,
            propertyId = "visual.blur.amount",
            timeMs = timeMs,
            baseValue = node.blurAmount,
        )

    private fun evaluateRasterNodeOpacity(
        node: NativeMotionTextRasterProgramNode,
        timeMs: Long,
    ): Float? {
        val nodeOpacity =
            evaluateUniformScalarChannelsAtTime(
                channels = node.channels,
                propertyId = "visual.opacity",
                timeMs = timeMs,
                baseValue = node.opacity,
            ) ?: return null
        val layerOpacity =
            evaluateUniformScalarChannelsAtTime(
                channels = node.layerChannels,
                propertyId = "visual.opacity",
                timeMs = timeMs,
                baseValue = node.layerOpacity,
            ) ?: return null
        return (nodeOpacity * layerOpacity).coerceIn(0f, 1f)
    }

    private fun evaluateUniformScalarChannelsAtTime(
        channels: List<NativeMotionScalarChannel>,
        propertyId: String,
        timeMs: Long,
        baseValue: Float,
    ): Float? {
        val relevantChannels =
            channels.filter { channel -> channel.propertyId == propertyId }
        if (relevantChannels.isEmpty()) {
            return baseValue
        }
        val resolvedValues =
            relevantChannels.map { channel ->
                sampleScalarChannelValue(channel, timeMs)
            }
        val referenceValue = resolvedValues.firstOrNull() ?: return baseValue
        if (resolvedValues.any { value -> abs(value - referenceValue) > 0.05f }) {
            return null
        }
        return referenceValue
    }

    private fun sampleScalarChannelValue(
        channel: NativeMotionScalarChannel,
        timeMs: Long,
    ): Float {
        val activeStart = channel.activeRangeStartMs
        val activeEnd = channel.activeRangeEndExclusiveMs
        if (timeMs < activeStart || timeMs >= activeEnd) {
            return channel.fallbackValue
        }
        val keyframes = channel.keyframes
        if (keyframes.isEmpty()) {
            return channel.baseValue ?: channel.fallbackValue
        }
        val first = keyframes.first()
        val last = keyframes.last()
        if (timeMs <= first.timeMs) {
            return first.value
        }
        if (timeMs >= last.timeMs) {
            return last.value
        }
        for (index in 0 until keyframes.lastIndex) {
            val current = keyframes[index]
            val next = keyframes[index + 1]
            if (timeMs < current.timeMs || timeMs > next.timeMs) {
                continue
            }
            if (timeMs == current.timeMs) {
                return current.value
            }
            if (timeMs == next.timeMs) {
                return next.value
            }
            if (current.interpolation.kind == "hold") {
                return current.value
            }
            val durationMs = (next.timeMs - current.timeMs).coerceAtLeast(1L)
            val rawProgress =
                ((timeMs - current.timeMs).toFloat() / durationMs.toFloat()).coerceIn(0f, 1f)
            val curvedProgress = sampleCurveProgress(current.interpolation, rawProgress)
            return current.value + ((next.value - current.value) * curvedProgress)
        }
        return channel.fallbackValue
    }

    private fun sampleCurveProgress(
        interpolation: NativeMotionInterpolationSpec,
        progress: Float,
    ): Float {
        return when (interpolation.kind) {
            "linear" -> progress
            "hold" -> 0f
            "easeIn" -> progress * progress
            "easeOut" -> {
                val inverse = 1f - progress
                1f - (inverse * inverse)
            }
            "easeInOut" ->
                if (progress < 0.5f) {
                    2f * progress * progress
                } else {
                    val inverse = (-2f * progress) + 2f
                    1f - ((inverse * inverse) / 2f)
                }
            "cubicBezier" -> sampleBezierProgress(interpolation, progress)
            "spring" -> sampleSpringProgress(interpolation.spring, progress)
            "bounce" -> sampleBounceProgress(interpolation.bounce, progress)
            "elastic" -> sampleElasticProgress(interpolation.elastic, progress)
            else ->
                throw IllegalStateException(
                    "Unsupported export interpolation kind in authored-surface effect planner: ${interpolation.kind}",
                )
        }
    }

    private fun sampleBezierProgress(
        interpolation: NativeMotionInterpolationSpec,
        progress: Float,
    ): Float {
        val bezier =
            interpolation.bezier
                ?: throw IllegalStateException(
                    "cubicBezier export interpolation is missing bezier control points.",
                )
        if (progress <= 0f || progress >= 1f) {
            return progress
        }
        var parameter = progress
        repeat(6) {
            val curveX =
                sampleCubicBezierCoordinate(
                    parameter,
                    bezier.x1,
                    bezier.x2,
                ) - progress
            if (abs(curveX) <= 0.0005f) {
                return sampleCubicBezierCoordinate(parameter, bezier.y1, bezier.y2).coerceIn(0f, 1f)
            }
            val derivative =
                sampleCubicBezierDerivative(parameter, bezier.x1, bezier.x2)
            if (abs(derivative) <= 0.00001f) {
                return@repeat
            }
            parameter = (parameter - (curveX / derivative)).coerceIn(0f, 1f)
        }
        var low = 0f
        var high = 1f
        repeat(14) {
            parameter = (low + high) / 2f
            val curveX = sampleCubicBezierCoordinate(parameter, bezier.x1, bezier.x2)
            if (curveX < progress) {
                low = parameter
            } else {
                high = parameter
            }
        }
        return sampleCubicBezierCoordinate(parameter, bezier.y1, bezier.y2).coerceIn(0f, 1f)
    }

    private fun sampleCubicBezierCoordinate(
        t: Float,
        control1: Float,
        control2: Float,
    ): Float {
        val oneMinusT = 1f - t
        val oneMinusT2 = oneMinusT * oneMinusT
        val t2 = t * t
        return (
            (3f * oneMinusT2 * t * control1) +
                (3f * oneMinusT * t2 * control2) +
                (t2 * t)
            ).coerceIn(0f, 1f)
    }

    private fun sampleCubicBezierDerivative(
        t: Float,
        control1: Float,
        control2: Float,
    ): Float {
        val oneMinusT = 1f - t
        return (
            (3f * oneMinusT * oneMinusT * control1) +
                (6f * oneMinusT * t * (control2 - control1)) +
                (3f * t * t * (1f - control2))
            )
    }

    private fun sampleSpringProgress(
        spring: NativeMotionSpringSpec?,
        progress: Float,
    ): Float {
        val t = progress.coerceIn(0f, 1f).toDouble()
        if (t <= 0.0) {
            return 0f
        }
        if (t >= 1.0) {
            return 1f
        }
        val spec =
            spring
                ?: NativeMotionSpringSpec(
                    stiffness = 220f,
                    damping = 18f,
                    mass = 1f,
                    initialVelocity = 0f,
                )
        val stiffness = spec.stiffness.toDouble().coerceAtLeast(0.0001)
        val mass = spec.mass.toDouble().coerceAtLeast(0.0001)
        val damping = spec.damping.toDouble().coerceAtLeast(0.0)
        val naturalFrequency = sqrt(stiffness / mass)
        if (!naturalFrequency.isFinite() || naturalFrequency <= 0.0) {
            return progress
        }
        val dampingRatio = damping / (2.0 * sqrt(stiffness * mass))
        val initialVelocity = spec.initialVelocity.toDouble()
        val result =
            if (dampingRatio < 1.0 - 0.0001) {
                val dampedFrequency =
                    naturalFrequency * sqrt(1.0 - (dampingRatio * dampingRatio))
                val coefficient =
                    ((dampingRatio * naturalFrequency) - initialVelocity) / dampedFrequency
                val envelope = exp(-dampingRatio * naturalFrequency * t)
                1.0 -
                    (
                        envelope *
                            (
                                cos(dampedFrequency * t) +
                                    (coefficient * sin(dampedFrequency * t))
                                )
                        )
            } else if (abs(dampingRatio - 1.0) <= 0.0001) {
                val envelope = exp(-naturalFrequency * t)
                1.0 - ((1.0 + ((naturalFrequency - initialVelocity) * t)) * envelope)
            } else {
                val sqrtTerm = sqrt((dampingRatio * dampingRatio) - 1.0)
                val rootOne = -naturalFrequency * (dampingRatio - sqrtTerm)
                val rootTwo = -naturalFrequency * (dampingRatio + sqrtTerm)
                val coefficientOne = (-initialVelocity - rootTwo) / (rootOne - rootTwo)
                val coefficientTwo = 1.0 - coefficientOne
                1.0 -
                    (
                        (coefficientOne * exp(rootOne * t)) +
                            (coefficientTwo * exp(rootTwo * t))
                        )
            }
        return result.toFloat()
    }

    private fun sampleBounceProgress(
        bounce: NativeMotionBounceSpec?,
        progress: Float,
    ): Float {
        val t = progress.coerceIn(0f, 1f).toDouble()
        if (t <= 0.0) {
            return 0f
        }
        if (t >= 1.0) {
            return 1f
        }
        val spec =
            bounce
                ?: NativeMotionBounceSpec(
                    amplitude = 0.18f,
                    bounces = 3,
                    decay = 8.0f,
                )
        val base = sampleEaseOutQuadratic(t)
        if (spec.amplitude <= 0f || spec.bounces <= 0) {
            return base.toFloat()
        }
        val oscillation =
            spec.amplitude.toDouble() *
                (1.0 - t).pow(0.65) *
                exp(-spec.decay.toDouble() * t) *
                abs(sin(PI * spec.bounces.toDouble() * t))
        return (base + oscillation).toFloat()
    }

    private fun sampleElasticProgress(
        elastic: NativeMotionElasticSpec?,
        progress: Float,
    ): Float {
        val t = progress.coerceIn(0f, 1f).toDouble()
        if (t <= 0.0) {
            return 0f
        }
        if (t >= 1.0) {
            return 1f
        }
        val spec =
            elastic
                ?: NativeMotionElasticSpec(
                    amplitude = 0.14f,
                    period = 0.28f,
                    decay = 8.0f,
                )
        val base = sampleEaseOutQuadratic(t)
        if (spec.amplitude <= 0f) {
            return base.toFloat()
        }
        val period = spec.period.toDouble().coerceAtLeast(0.0001)
        val amplitude = spec.amplitude.toDouble()
        val decay = spec.decay.toDouble()
        val raw =
            base +
                (
                    amplitude *
                        sin((2.0 * PI / period) * t) *
                        exp(-decay * t)
                    )
        val endRaw =
            1.0 +
                (
                    amplitude *
                        sin(2.0 * PI / period) *
                        exp(-decay)
                    )
        return (raw - (t * (endRaw - 1.0))).toFloat()
    }

    private fun sampleEaseOutQuadratic(progress: Double): Double {
        val inverse = 1.0 - progress
        return 1.0 - (inverse * inverse)
    }

    private fun formatMotionTextDecisionValue(value: Float): String =
        "%.2f".format(Locale.US, value)

    private fun ensureTransparentOverlayAsset(outputSize: OutputSize): File {
        val overlayAssetDir = File(appContext.cacheDir, "export-overlay-assets")
        if (!overlayAssetDir.exists()) {
            overlayAssetDir.mkdirs()
        }
        val assetFile =
            File(
                overlayAssetDir,
                "transparent-${outputSize.width}x${outputSize.height}.png",
            )
        if (assetFile.exists() && assetFile.length() > 0L) {
            return assetFile
        }
        val bitmap =
            Bitmap.createBitmap(
                outputSize.width.coerceAtLeast(2),
                outputSize.height.coerceAtLeast(2),
                Bitmap.Config.ARGB_8888,
            )
        return try {
            bitmap.eraseColor(android.graphics.Color.TRANSPARENT)
            assetFile.outputStream().use { stream ->
                check(bitmap.compress(Bitmap.CompressFormat.PNG, 100, stream)) {
                    "Failed to encode transparent motion-text overlay asset."
                }
            }
            assetFile
        } finally {
            bitmap.recycle()
        }
    }

    private fun createOutputFile(
        preset: String,
        requestedFileName: String?,
    ): File {
        val baseMoviesDir = appContext.getExternalFilesDir(Environment.DIRECTORY_MOVIES)
        val exportDir =
            File(
                baseMoviesDir ?: appContext.filesDir,
                "exports",
            )
        if (!exportDir.exists()) {
            exportDir.mkdirs()
        }
        val safeRequestedFileName =
            requestedFileName
                ?.trim()
                ?.takeIf { it.isNotEmpty() }
                ?.let { fileName ->
                    if (fileName.endsWith(".mp4", ignoreCase = true)) {
                        fileName
                    } else {
                        "$fileName.mp4"
                    }
                }
        val fileName =
            safeRequestedFileName
                ?: "ingene-export-${preset}-${System.currentTimeMillis()}.mp4"
        val outputFile = File(exportDir, fileName)
        if (outputFile.exists()) {
            outputFile.delete()
        }
        return outputFile
    }

    private fun readLong(value: Any?): Long {
        return when (value) {
            is Int -> value.toLong()
            is Long -> value
            is Double -> value.toLong()
            is Float -> value.toLong()
            is String -> value.toLongOrNull() ?: 0L
            else -> 0L
        }
    }

    private fun readInt(value: Any?): Int = readLong(value).toInt()

    private fun readIntOrDefault(value: Any?, fallback: Int): Int {
        return when (value) {
            is Int -> value
            is Long -> value.toInt()
            is Double -> value.toInt()
            is Float -> value.toInt()
            is String -> value.toIntOrNull() ?: fallback
            else -> fallback
        }
    }

    private fun readDouble(value: Any?): Double {
        return when (value) {
            is Int -> value.toDouble()
            is Long -> value.toDouble()
            is Float -> value.toDouble()
            is Double -> value
            is String -> value.toDoubleOrNull() ?: 1.0
            else -> 1.0
        }
    }

    private fun readFloatOrDefault(value: Any?, fallback: Float): Float {
        return when (value) {
            is Int -> value.toFloat()
            is Long -> value.toFloat()
            is Double -> value.toFloat()
            is Float -> value
            is String -> value.toFloatOrNull() ?: fallback
            else -> fallback
        }
    }

    private fun readBoolean(value: Any?): Boolean {
        return when (value) {
            is Boolean -> value
            is Int -> value != 0
            is Long -> value != 0L
            is Float -> value != 0f
            is Double -> value != 0.0
            is String -> value == "true" || value == "1" || value == "yes"
            else -> false
        }
    }

    private fun resolveOutputFrameRate(
        compositionMap: Map<String, Any?>,
        requestedFrameRate: Int?,
    ): Int? {
        if (requestedFrameRate != null && requestedFrameRate > 0) {
            return requestedFrameRate
        }
        val format = compositionMap["format"] as? Map<*, *> ?: return null
        val numerator = readLong(format["frameRateNumerator"])
        val denominator = readLong(format["frameRateDenominator"])
        if (numerator <= 0L || denominator <= 0L) {
            return null
        }
        val frameRate = (numerator.toDouble() / denominator.toDouble()).roundToInt()
        return frameRate.takeIf { it > 0 }
    }

    private fun resolveRequestedExportProfile(
        exportProfileMap: Map<String, Any?>,
    ): NativeRequestedExportProfile {
        return NativeRequestedExportProfile(
            resolutionPreset =
                exportProfileMap["resolutionPreset"]?.toString()?.takeIf { it.isNotBlank() }
                    ?: "fullHd1080p",
            frameRate = readInt(exportProfileMap["frameRate"]).takeIf { it > 0 },
            videoCodec =
                exportProfileMap["videoCodec"]?.toString()?.takeIf { it.isNotBlank() }
                    ?: "automatic",
            bitrateMode =
                exportProfileMap["bitrateMode"]?.toString()?.takeIf { it.isNotBlank() }
                    ?: "auto",
            audioBitrate = readInt(exportProfileMap["audioBitrate"]).takeIf { it > 0 },
            manualVideoBitrate =
                readInt(exportProfileMap["manualVideoBitrate"]).takeIf { it > 0 },
        )
    }

    private fun resolveEncoderPlan(
        outputSize: OutputSize?,
        outputFrameRate: Int?,
        expectsAudio: Boolean,
        requestedProfile: NativeRequestedExportProfile,
    ): NativeExportEncoderPlan? {
        if (outputSize == null || outputFrameRate == null || outputFrameRate <= 0) {
            return null
        }
        val mimeType = resolveRequestedVideoMimeType(requestedProfile)
        val supportedEncoders = EncoderUtil.getSupportedEncoders(mimeType)
        if (supportedEncoders.isEmpty()) {
            throw IllegalArgumentException(
                "No ${formatVideoCodecLabel(mimeType)} export encoder is available on this device.",
            )
        }
        val selectedEncoder =
            supportedEncoders.firstOrNull { codecInfo ->
                runCatching {
                    val capabilities = codecInfo.getCapabilitiesForType(mimeType)
                    val videoCapabilities = capabilities.videoCapabilities ?: return@runCatching false
                    val theoreticalSupport =
                        videoCapabilities.areSizeAndRateSupported(
                            outputSize.width,
                            outputSize.height,
                            outputFrameRate.toDouble(),
                        )
                    if (!theoreticalSupport) {
                        return@runCatching false
                    }
                    val achievableFrameRates =
                        runCatching {
                            videoCapabilities.getAchievableFrameRatesFor(
                                outputSize.width,
                                outputSize.height,
                            )
                        }.getOrNull()
                    if (achievableFrameRates == null) {
                        return@runCatching true
                    }
                    outputFrameRate.toDouble() <= achievableFrameRates.upper + 0.5
                }.getOrDefault(false)
            }
                ?: throw IllegalArgumentException(
                    "Requested export profile ${outputSize.width}x${outputSize.height} @ ${outputFrameRate}fps is not supported by the current ${formatVideoCodecLabel(mimeType)} encoder path on this device.",
                )
        val requestedVideoBitrate =
            calculateRequestedVideoBitrate(
                width = outputSize.width,
                height = outputSize.height,
                frameRate = outputFrameRate,
                mimeType = mimeType,
                bitrateMode = requestedProfile.bitrateMode,
                manualVideoBitrate = requestedProfile.manualVideoBitrate,
            )
        val clampedVideoBitrate =
            runCatching {
                val bitrateRange = EncoderUtil.getSupportedBitrateRange(selectedEncoder, mimeType)
                requestedVideoBitrate.coerceIn(bitrateRange.lower, bitrateRange.upper)
            }.getOrElse { requestedVideoBitrate }
        val bitrateMode =
            resolvePreferredBitrateMode(
                codecInfo = selectedEncoder,
                mimeType = mimeType,
                requestedMode = requestedProfile.bitrateMode,
            )
        val videoEncoderSettings =
            VideoEncoderSettings.Builder()
                .setBitrate(clampedVideoBitrate)
                .setBitrateMode(bitrateMode)
                .setiFrameIntervalSeconds(1.0f)
                .build()
        val audioBitrate =
            if (expectsAudio) {
                resolveRequestedAudioBitrate(
                    requestedAudioBitrate = requestedProfile.audioBitrate,
                    bitrateMode = requestedProfile.bitrateMode,
                )
            } else {
                null
            }
        val audioEncoderSettings =
            if (audioBitrate == null) {
                null
            } else {
                AudioEncoderSettings.Builder()
                    .setBitrate(audioBitrate)
                    .build()
            }
        return NativeExportEncoderPlan(
            frameRate = outputFrameRate,
            videoBitrate = clampedVideoBitrate,
            audioBitrate = audioBitrate,
            encoderName = selectedEncoder.name,
            videoMimeType = mimeType,
            audioMimeType = if (audioBitrate == null) null else MimeTypes.AUDIO_AAC,
            selectedVideoCodec = formatVideoCodecPresetName(mimeType),
            videoEncoderSettings = videoEncoderSettings,
            audioEncoderSettings = audioEncoderSettings,
        )
    }

    private fun suspendPreviewForActiveExport() {
        if (previewSuspendedForActiveExport) {
            return
        }
        previewTransportManager?.suspendPreviewOutputForExport()
        previewSuspendedForActiveExport = previewTransportManager != null
    }

    private fun resumePreviewAfterActiveExport() {
        if (!previewSuspendedForActiveExport) {
            return
        }
        previewTransportManager?.resumePreviewOutputAfterExport()
        previewSuspendedForActiveExport = false
    }

    private fun calculateRequestedVideoBitrate(
        width: Int,
        height: Int,
        frameRate: Int,
        mimeType: String,
        bitrateMode: String,
        manualVideoBitrate: Int?,
    ): Int {
        if (bitrateMode == "manual" && manualVideoBitrate != null && manualVideoBitrate > 0) {
            return manualVideoBitrate
        }
        val pixelsPerSecond = width.toLong() * height.toLong() * frameRate.toLong()
        val compressionFactor =
            when (bitrateMode) {
                "qualityPriority" -> if (mimeType == MimeTypes.VIDEO_H265) 0.14 else 0.22
                "sizePriority" -> if (mimeType == MimeTypes.VIDEO_H265) 0.07 else 0.11
                else -> if (mimeType == MimeTypes.VIDEO_H265) 0.10 else 0.16
            }
        val targetBitrate = (pixelsPerSecond * compressionFactor).roundToLong()
        return targetBitrate
            .coerceAtLeast(8_000_000L)
            .coerceAtMost(80_000_000L)
            .toInt()
    }

    private fun resolveRequestedAudioBitrate(
        requestedAudioBitrate: Int?,
        bitrateMode: String,
    ): Int {
        val requested =
            requestedAudioBitrate ?: when (bitrateMode) {
                "qualityPriority" -> 320_000
                "sizePriority" -> 128_000
                else -> 256_000
            }
        return requested.coerceIn(128_000, 320_000)
    }

    private fun resolveRequestedVideoMimeType(
        requestedProfile: NativeRequestedExportProfile,
    ): String {
        return when (requestedProfile.videoCodec) {
            "h265Hevc" -> MimeTypes.VIDEO_H265
            else -> MimeTypes.VIDEO_H264
        }
    }

    private fun resolvePreferredBitrateMode(
        codecInfo: MediaCodecInfo,
        mimeType: String,
        requestedMode: String,
    ): Int {
        val preferredModes =
            when (requestedMode) {
                "qualityPriority" ->
                    listOf(
                        MediaCodecInfo.EncoderCapabilities.BITRATE_MODE_CQ,
                        MediaCodecInfo.EncoderCapabilities.BITRATE_MODE_VBR,
                        MediaCodecInfo.EncoderCapabilities.BITRATE_MODE_CBR,
                    )
                "sizePriority", "manual" ->
                    listOf(
                        MediaCodecInfo.EncoderCapabilities.BITRATE_MODE_CBR,
                        MediaCodecInfo.EncoderCapabilities.BITRATE_MODE_VBR,
                        MediaCodecInfo.EncoderCapabilities.BITRATE_MODE_CQ,
                    )
                else ->
                    listOf(
                        MediaCodecInfo.EncoderCapabilities.BITRATE_MODE_VBR,
                        MediaCodecInfo.EncoderCapabilities.BITRATE_MODE_CQ,
                        MediaCodecInfo.EncoderCapabilities.BITRATE_MODE_CBR,
                    )
            }
        return preferredModes.firstOrNull { mode ->
            EncoderUtil.isBitrateModeSupported(codecInfo, mimeType, mode)
        } ?: MediaCodecInfo.EncoderCapabilities.BITRATE_MODE_VBR
    }

    private fun formatVideoCodecLabel(mimeType: String): String {
        return when (mimeType) {
            MimeTypes.VIDEO_H265 -> "H.265 / HEVC"
            else -> "H.264 / AVC"
        }
    }

    private fun formatVideoCodecPresetName(mimeType: String): String {
        return when (mimeType) {
            MimeTypes.VIDEO_H265 -> "h265Hevc"
            else -> "h264Avc"
        }
    }

    private fun resolvePresetOutputSize(
        compositionMap: Map<String, Any?>,
        preset: String,
    ): OutputSize? {
        val format = compositionMap["format"] as? Map<*, *> ?: return null
        val canvasWidth = readLong(format["canvasWidth"]).toInt()
        val canvasHeight = readLong(format["canvasHeight"]).toInt()
        if (canvasWidth <= 0 || canvasHeight <= 0) {
            return null
        }
        if (preset == "originalCanvas") {
            return OutputSize(
                width = roundDimensionToEven(canvasWidth),
                height = roundDimensionToEven(canvasHeight),
            )
        }
        if (preset == "sourceMatch") {
            return resolveSourceMatchOutputSize(
                compositionMap = compositionMap,
            )
        }
        val isLandscape = canvasWidth >= canvasHeight
        val (maxWidth, maxHeight) =
            when (preset) {
                "draft720p" -> if (isLandscape) 1280 to 720 else 720 to 1280
                "fullHd1080p" -> if (isLandscape) 1920 to 1080 else 1080 to 1920
                "quadHd1440p" -> if (isLandscape) 2560 to 1440 else 1440 to 2560
                "ultraHd2160p" -> if (isLandscape) 3840 to 2160 else 2160 to 3840
                else -> canvasWidth to canvasHeight
            }
        val scale =
            kotlin.math.min(
                maxWidth.toDouble() / canvasWidth.toDouble(),
                maxHeight.toDouble() / canvasHeight.toDouble(),
            )
        return OutputSize(
            width = roundDimensionToEven((canvasWidth * scale).roundToInt()),
            height = roundDimensionToEven((canvasHeight * scale).roundToInt()),
        )
    }

    private fun resolveSourceMatchOutputSize(
        compositionMap: Map<String, Any?>,
    ): OutputSize? {
        val format = compositionMap["format"] as? Map<*, *> ?: return null
        val canvasWidth = readLong(format["canvasWidth"]).toInt()
        val canvasHeight = readLong(format["canvasHeight"]).toInt()
        if (canvasWidth <= 0 || canvasHeight <= 0) {
            return null
        }
        val assetMaps =
            (compositionMap["assets"] as? List<*> ?: emptyList<Any?>())
                .mapNotNull { it as? Map<*, *> }
        val largestVisualAsset =
            assetMaps
                .filter { asset ->
                    val kind = asset["kind"]?.toString()
                    val width = readLong(asset["width"]).toInt()
                    val height = readLong(asset["height"]).toInt()
                    (kind == "video" || kind == "image") && width > 0 && height > 0
                }.maxByOrNull { asset ->
                    val width = readLong(asset["width"]).toLong()
                    val height = readLong(asset["height"]).toLong()
                    width * height
                }
        val maxWidth =
            largestVisualAsset?.let { readLong(it["width"]).toInt() }
                ?: canvasWidth
        val maxHeight =
            largestVisualAsset?.let { readLong(it["height"]).toInt() }
                ?: canvasHeight
        val scale =
            kotlin.math.min(
                maxWidth.toDouble() / canvasWidth.toDouble(),
                maxHeight.toDouble() / canvasHeight.toDouble(),
            )
        return OutputSize(
            width = roundDimensionToEven((canvasWidth * scale).roundToInt()),
            height = roundDimensionToEven((canvasHeight * scale).roundToInt()),
        )
    }

    private fun validateOutputFile(
        outputPath: String,
        expectedDurationMs: Long,
        timelineDurationMs: Long,
        expectedHasAudio: Boolean,
        expectedOutputSize: OutputSize?,
        expectedOutputFrameRate: Int?,
        expectedVideoTrackMime: String?,
        expectedAudioTrackMime: String?,
    ): OutputValidationResult {
        val outputFile = File(outputPath)
        if (!outputFile.exists()) {
            return OutputValidationResult(
                isValid = false,
                failureReason = "Export output file was not created.",
            )
        }
        val fileSizeBytes = outputFile.length()
        if (fileSizeBytes <= 0L) {
            return OutputValidationResult(
                isValid = false,
                failureReason = "Export output file is empty.",
            )
        }
        var retriever: MediaMetadataRetriever? = null
        var extractor: MediaExtractor? = null
        return try {
            retriever = MediaMetadataRetriever()
            retriever.setDataSource(outputFile.absolutePath)
            extractor = MediaExtractor()
            extractor.setDataSource(outputFile.absolutePath)
            val durationMs =
                retriever
                    .extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION)
                    ?.toLongOrNull()
                    ?: 0L
            val width =
                retriever
                    .extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_WIDTH)
                    ?.toIntOrNull()
            val height =
                retriever
                    .extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_HEIGHT)
                    ?.toIntOrNull()
            val videoRotationDegrees =
                retriever
                    .extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_ROTATION)
                    ?.toIntOrNull()
                    ?: 0
            val hasVideo =
                retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_HAS_VIDEO) ==
                    "yes" ||
                    (width != null && width > 0 && height != null && height > 0)
            val hasAudio =
                retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_HAS_AUDIO) ==
                    "yes"
            val mimeType =
                retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_MIMETYPE)
            var videoTrackCount = 0
            var audioTrackCount = 0
            val trackMimeTypes = mutableListOf<String>()
            var actualVideoTrackMime: String? = null
            var actualAudioTrackMime: String? = null
            var actualVideoFrameRate: Int? = null
            var trackWidth: Int? = null
            var trackHeight: Int? = null
            for (trackIndex in 0 until extractor.trackCount) {
                val format = extractor.getTrackFormat(trackIndex)
                val trackMimeType = format.getString(android.media.MediaFormat.KEY_MIME)
                if (!trackMimeType.isNullOrBlank()) {
                    trackMimeTypes += trackMimeType
                    when {
                        trackMimeType.startsWith("video/") -> {
                            videoTrackCount += 1
                            actualVideoTrackMime ?: run { actualVideoTrackMime = trackMimeType }
                            if (actualVideoFrameRate == null &&
                                format.containsKey(android.media.MediaFormat.KEY_FRAME_RATE)
                            ) {
                                actualVideoFrameRate =
                                    format.getInteger(android.media.MediaFormat.KEY_FRAME_RATE)
                            }
                            if (format.containsKey(android.media.MediaFormat.KEY_WIDTH)) {
                                trackWidth = format.getInteger(android.media.MediaFormat.KEY_WIDTH)
                            }
                            if (format.containsKey(android.media.MediaFormat.KEY_HEIGHT)) {
                                trackHeight = format.getInteger(android.media.MediaFormat.KEY_HEIGHT)
                            }
                        }
                        trackMimeType.startsWith("audio/") -> {
                            audioTrackCount += 1
                            actualAudioTrackMime ?: run { actualAudioTrackMime = trackMimeType }
                        }
                    }
                }
            }
            val effectiveExpectedVideoTrackMime = expectedVideoTrackMime ?: MimeTypes.VIDEO_H264
            val effectiveExpectedAudioTrackMime =
                expectedAudioTrackMime
                    ?: if (expectedHasAudio || audioTrackCount > 0) MimeTypes.AUDIO_AAC else null
            val effectiveVideoTrackCount =
                when {
                    videoTrackCount > 0 -> videoTrackCount
                    hasVideo -> 1
                    else -> 0
                }
            val effectiveAudioTrackCount =
                when {
                    audioTrackCount > 0 -> audioTrackCount
                    hasAudio -> 1
                    else -> 0
                }
            val effectiveTrackMimeTypes =
                if (trackMimeTypes.isNotEmpty()) {
                    trackMimeTypes.toList()
                } else {
                    buildList {
                        if (!mimeType.isNullOrBlank()) {
                            add(mimeType)
                        }
                    }
                }
            val durationDeltaMs = kotlin.math.abs(durationMs - expectedDurationMs)
            val durationToleranceMs =
                kotlin.math.max(250L, (expectedDurationMs * 0.03).toLong())
            val frameRateDelta =
                if (expectedOutputFrameRate != null && actualVideoFrameRate != null) {
                    kotlin.math.abs(actualVideoFrameRate - expectedOutputFrameRate)
                } else {
                    null
                }
            val isFrameRateWithinTolerance = frameRateDelta == null || frameRateDelta <= 2
            val resolutionMatchesExpectation =
                matchesExpectedOutputSize(
                    metadataWidth = width,
                    metadataHeight = height,
                    trackWidth = trackWidth,
                    trackHeight = trackHeight,
                    videoRotationDegrees = videoRotationDegrees,
                    expectedOutputSize = expectedOutputSize,
                )
            val reportedWidth = width ?: trackWidth
            val reportedHeight = height ?: trackHeight
            fun invalidValidation(reason: String): OutputValidationResult =
                OutputValidationResult(
                    isValid = false,
                    failureReason = reason,
                    fileSizeBytes = fileSizeBytes,
                    durationMs = durationMs,
                    expectedDurationMs = expectedDurationMs,
                    timelineDurationMs = timelineDurationMs,
                    durationDeltaMs = durationDeltaMs,
                    hasVideo = hasVideo,
                    expectedHasAudio = expectedHasAudio,
                    expectedWidth = expectedOutputSize?.width,
                    expectedHeight = expectedOutputSize?.height,
                    expectedFrameRate = expectedOutputFrameRate,
                    expectedVideoTrackMime = effectiveExpectedVideoTrackMime,
                    expectedAudioTrackMime = effectiveExpectedAudioTrackMime,
                    hasAudio = hasAudio,
                    videoTrackCount = effectiveVideoTrackCount,
                    audioTrackCount = effectiveAudioTrackCount,
                    actualVideoTrackMime = actualVideoTrackMime,
                    actualAudioTrackMime = actualAudioTrackMime,
                    actualFrameRate = actualVideoFrameRate,
                    trackMimeTypes = effectiveTrackMimeTypes,
                    isDurationWithinTolerance = durationDeltaMs <= durationToleranceMs,
                    isFrameRateWithinTolerance = isFrameRateWithinTolerance,
                    width = reportedWidth,
                    height = reportedHeight,
                    videoRotationDegrees = videoRotationDegrees,
                    mimeType = mimeType,
                ).also {
                    Log.e(
                        TAG,
                        "Output validation failed: reason=$reason expectedDuration=${expectedDurationMs}ms actualDuration=${durationMs}ms timelineDuration=${timelineDurationMs}ms delta=${durationDeltaMs}ms routeVideoTracks=$effectiveVideoTrackCount routeAudioTracks=$effectiveAudioTrackCount fps=$actualVideoFrameRate size=${reportedWidth}x${reportedHeight} rotation=$videoRotationDegrees",
                    )
                }
            if (durationMs <= 0L) {
                invalidValidation("Export output has no readable duration.")
            } else if (!hasVideo) {
                invalidValidation("Export output has no readable video track.")
            } else if (effectiveVideoTrackCount != 1) {
                invalidValidation(
                    "Export output must contain exactly one video track (found $effectiveVideoTrackCount).",
                )
            } else if (actualVideoTrackMime != null &&
                actualVideoTrackMime != effectiveExpectedVideoTrackMime) {
                invalidValidation(
                    "Export output video codec does not match the baseline expectation.",
                )
            } else if (expectedHasAudio && !hasAudio) {
                invalidValidation("Export output is missing the expected audio track.")
            } else if (expectedHasAudio && effectiveAudioTrackCount != 1) {
                invalidValidation(
                    "Export output must contain exactly one audio track when audio is expected (found $effectiveAudioTrackCount).",
                )
            } else if (!expectedHasAudio && effectiveAudioTrackCount > 1) {
                invalidValidation(
                    "Export output contains more than one audio track outside the current baseline.",
                )
            } else if (effectiveExpectedAudioTrackMime != null &&
                actualAudioTrackMime != null &&
                actualAudioTrackMime != effectiveExpectedAudioTrackMime) {
                invalidValidation(
                    "Export output audio codec does not match the baseline expectation.",
                )
            } else if (!resolutionMatchesExpectation) {
                invalidValidation(
                    buildResolutionMismatchFailureReason(
                        expectedOutputSize = expectedOutputSize,
                        actualWidth = reportedWidth,
                        actualHeight = reportedHeight,
                        videoRotationDegrees = videoRotationDegrees,
                    ),
                )
            } else if (expectedDurationMs > 0L && durationDeltaMs > durationToleranceMs) {
                invalidValidation(
                    buildDurationMismatchFailureReason(
                        expectedDurationMs = expectedDurationMs,
                        timelineDurationMs = timelineDurationMs,
                        actualDurationMs = durationMs,
                        durationDeltaMs = durationDeltaMs,
                    ),
                )
            } else {
                OutputValidationResult(
                    isValid = true,
                    fileSizeBytes = fileSizeBytes,
                    durationMs = durationMs,
                    expectedDurationMs = expectedDurationMs,
                    timelineDurationMs = timelineDurationMs,
                    durationDeltaMs = durationDeltaMs,
                    hasVideo = hasVideo,
                    expectedHasAudio = expectedHasAudio,
                    expectedWidth = expectedOutputSize?.width,
                    expectedHeight = expectedOutputSize?.height,
                    expectedFrameRate = expectedOutputFrameRate,
                    expectedVideoTrackMime = expectedVideoTrackMime,
                    expectedAudioTrackMime = expectedAudioTrackMime,
                    hasAudio = hasAudio,
                    videoTrackCount = effectiveVideoTrackCount,
                    audioTrackCount = effectiveAudioTrackCount,
                    actualVideoTrackMime = actualVideoTrackMime,
                    actualAudioTrackMime = actualAudioTrackMime,
                    actualFrameRate = actualVideoFrameRate,
                    trackMimeTypes = effectiveTrackMimeTypes,
                    isDurationWithinTolerance = durationDeltaMs <= durationToleranceMs,
                    isFrameRateWithinTolerance = isFrameRateWithinTolerance,
                    width = reportedWidth,
                    height = reportedHeight,
                    videoRotationDegrees = videoRotationDegrees,
                    mimeType = mimeType,
                )
            }
        } catch (_: Exception) {
            OutputValidationResult(
                isValid = false,
                failureReason = "Export output metadata could not be read.",
            )
        } finally {
            retriever?.release()
            extractor?.release()
        }
    }

    private fun roundDimensionToEven(value: Int): Int {
        val clampedValue = value.coerceAtLeast(2)
        return if (clampedValue % 2 == 0) clampedValue else clampedValue - 1
    }

    private fun buildDurationMismatchFailureReason(
        expectedDurationMs: Long,
        timelineDurationMs: Long,
        actualDurationMs: Long,
        durationDeltaMs: Long,
    ): String {
        val executionDetail = "execution=${expectedDurationMs}ms"
        val timelineDetail =
            if (timelineDurationMs > 0L && timelineDurationMs != expectedDurationMs) {
                ", timeline=${timelineDurationMs}ms"
            } else {
                ""
            }
        return "Export duration deviates from execution truth by ${durationDeltaMs}ms ($executionDetail$timelineDetail, actual=${actualDurationMs}ms)."
    }

    private fun matchesExpectedOutputSize(
        metadataWidth: Int?,
        metadataHeight: Int?,
        trackWidth: Int?,
        trackHeight: Int?,
        videoRotationDegrees: Int,
        expectedOutputSize: OutputSize?,
    ): Boolean {
        if (expectedOutputSize == null) {
            return true
        }
        val tolerancePx = 2
        val candidates =
            buildList<Pair<Int, Int>> {
                if (metadataWidth != null && metadataHeight != null) {
                    add(metadataWidth to metadataHeight)
                }
                if (trackWidth != null && trackHeight != null) {
                    add(trackWidth to trackHeight)
                }
            }.distinct()
        if (candidates.isEmpty()) {
            return false
        }
        return candidates.any { (candidateWidth, candidateHeight) ->
            val directMatch =
                kotlin.math.abs(candidateWidth - expectedOutputSize.width) <= tolerancePx &&
                    kotlin.math.abs(candidateHeight - expectedOutputSize.height) <= tolerancePx
            val rotatedMatch =
                videoRotationDegrees % 180 != 0 &&
                    kotlin.math.abs(candidateHeight - expectedOutputSize.width) <= tolerancePx &&
                    kotlin.math.abs(candidateWidth - expectedOutputSize.height) <= tolerancePx
            directMatch || rotatedMatch
        }
    }

    private fun buildResolutionMismatchFailureReason(
        expectedOutputSize: OutputSize?,
        actualWidth: Int?,
        actualHeight: Int?,
        videoRotationDegrees: Int,
    ): String {
        val expectedLabel =
            if (expectedOutputSize == null) {
                "unknown"
            } else {
                "${expectedOutputSize.width}x${expectedOutputSize.height}"
            }
        val actualLabel =
            if (actualWidth == null || actualHeight == null) {
                "unknown"
            } else {
                "${actualWidth}x${actualHeight}"
            }
        val rotationLabel =
            if (videoRotationDegrees == 0) {
                ""
            } else {
                " (rotation ${videoRotationDegrees}deg)"
            }
        return "Export output resolution does not match the expected preset size. Expected $expectedLabel, got $actualLabel$rotationLabel."
    }
}

private data class NativeExportClip(
    val clipId: String,
    val sourceUri: String,
    val assetKind: NativeExportClipKind,
    val timelineStartMs: Long,
    val timelineDurationMs: Long,
    val sourceStartMs: Long,
    val sourceDurationMs: Long,
    val playbackRate: Float,
    val graphLayerId: String? = null,
    val graphSegmentId: String? = null,
    val graphWindowId: String? = null,
    val graphWindowPolicy: String? = null,
    val graphZOrder: Int? = null,
    val graphAssemblyOrder: Int? = null,
    val coveredWindowIds: List<String> = emptyList(),
)

private data class NativeExportComposition(
    val composition: Composition,
    val clips: List<NativeExportClip>,
    val durationMs: Long,
    val timelineDurationMs: Long,
    val executionDurationMs: Long,
    val expectsAudio: Boolean,
    val outputSize: OutputSize?,
    val motionTextParityDiagnostics: NativeMotionTextParityDiagnostics?,
    val canonicalEffectsDiagnostics: NativeCanonicalEffectsDiagnostics?,
    val authoredVisualSurfaceDiagnostics: NativeAuthoredVisualSurfaceDiagnostics?,
    val visualAssemblyDiagnostics: NativeVisualAssemblyDiagnostics?,
)

private data class NativeEditedSequenceAssembly(
    val sequence: EditedMediaItemSequence,
    val durationMs: Long,
)

private data class OutputSize(
    val width: Int,
    val height: Int,
)

private data class NativeRequestedExportProfile(
    val resolutionPreset: String,
    val frameRate: Int?,
    val videoCodec: String,
    val bitrateMode: String,
    val audioBitrate: Int?,
    val manualVideoBitrate: Int?,
)

private data class NativeExportEncoderPlan(
    val frameRate: Int,
    val videoBitrate: Int,
    val audioBitrate: Int?,
    val encoderName: String,
    val videoMimeType: String,
    val audioMimeType: String?,
    val selectedVideoCodec: String,
    val videoEncoderSettings: VideoEncoderSettings,
    val audioEncoderSettings: AudioEncoderSettings?,
)

private data class ResolvedOutputFile(
    val file: File,
    val contentUri: Uri,
    val mimeType: String,
)

private data class NativeMotionContractSummary(
    val sceneCount: Int,
    val elementCount: Int,
    val textElementCount: Int,
    val nonTextElementCount: Int,
    val channelCount: Int,
    val cameraCount: Int,
    val textAnimationCount: Int,
    val effectCount: Int,
    val transitionCount: Int,
)

private data class NativeMotionTextRenderTrackSummary(
    val sampleCount: Int,
    val sampleStepMs: Long,
    val totalNodeInstances: Long,
)

private data class NativeMotionTextProgramSummary(
    val nodeCount: Int,
)

private data class NativeMotionTextRasterizationPolicy(
    val blurSigmaScale: Float,
    val blurSpreadMultiplier: Float,
    val minimumLayoutPaddingPx: Float,
    val minimumFontSizePx: Float,
    val fontPaddingRatio: Float,
) {
    companion object {
        val DEFAULT =
            NativeMotionTextRasterizationPolicy(
                blurSigmaScale = 0.18f,
                blurSpreadMultiplier = 3f,
                minimumLayoutPaddingPx = 2f,
                minimumFontSizePx = 12f,
                fontPaddingRatio = 0.08f,
            )
    }
}

private data class NativeMotionTextRasterContract(
    val contractVersion: String,
    val layoutEngineId: String,
    val blurEngineId: String,
    val blurColorResolutionMode: String,
    val rasterizationPolicy: NativeMotionTextRasterizationPolicy,
) {
    companion object {
        val DEFAULT =
            NativeMotionTextRasterContract(
                contractVersion = "motion-text-raster.default",
                layoutEngineId = "shaped_paragraph_layout",
                blurEngineId = "gaussian_layer_blur",
                blurColorResolutionMode = "alpha_mask_colorized",
                rasterizationPolicy = NativeMotionTextRasterizationPolicy.DEFAULT,
            )
    }
}

private data class NativeMotionTextRasterProgram(
    val contractVersion: String,
    val layoutEngineId: String,
    val blurEngineId: String,
    val blurColorResolutionMode: String,
    val canvasWidth: Float,
    val canvasHeight: Float,
    val rasterizationPolicy: NativeMotionTextRasterizationPolicy,
    val nodes: List<NativeMotionTextRasterProgramNode>,
) {
    val nodesById: Map<String, NativeMotionTextRasterProgramNode>
        get() = nodes.associateBy { node -> node.id }
}

private data class NativeMotionTextRasterProgramNode(
    val id: String,
    val targetElementId: String,
    val sceneId: String,
    val layerId: String,
    val projectRangeStartMs: Long,
    val projectRangeEndExclusiveMs: Long,
    val fullText: String,
    val revealUnit: String,
    val fontSize: Float,
    val letterSpacing: Float,
    val colorArgb: Int,
    val fontFamily: String?,
    val fontWeight: Int,
    val fontStyle: String,
    val lineHeight: Float,
    val textAlignment: String,
    val opacity: Float,
    val blurAmount: Float,
    val blendMode: String,
    val canvasOffsetX: Float,
    val canvasOffsetY: Float,
    val scaleX: Float,
    val scaleY: Float,
    val rotationDegrees: Float,
    val anchor: String,
    val zIndex: Int,
    val layerOpacity: Float,
    val animationKinds: Set<String>,
    val animationBlocks: List<NativeMotionTextProgramAnimationBlock>,
    val channels: List<NativeMotionScalarChannel>,
    val layerChannels: List<NativeMotionScalarChannel>,
    val channelPropertyIds: Set<String>,
    val layerChannelPropertyIds: Set<String>,
    val name: String? = null,
    val presetId: String? = null,
)

internal data class NativeAuthoredVisualSurfaceProgram(
    val contractVersion: String,
    val canvasWidth: Float,
    val canvasHeight: Float,
    val nodes: List<NativeAuthoredVisualSurfaceNode>,
) {
    val nodesById: Map<String, NativeAuthoredVisualSurfaceNode>
        get() = nodes.associateBy { node -> node.id }
}

internal data class NativeAuthoredVisualSurfaceNode(
    val id: String,
    val targetElementId: String,
    val sceneId: String,
    val layerId: String,
    val elementKind: String,
    val projectRangeStartMs: Long,
    val projectRangeEndExclusiveMs: Long,
    val sourceKind: String,
    val sourceId: String,
    val sourceAssetId: String?,
    val sourceLabel: String?,
    val shapeKind: String?,
    val basePositionX: Float,
    val basePositionY: Float,
    val baseScaleX: Float,
    val baseScaleY: Float,
    val baseRotationDegrees: Float,
    val baseWidth: Float,
    val baseHeight: Float,
    val baseCornerRadius: Float,
    val opacity: Float,
    val blurAmount: Float,
    val layerOpacity: Float,
    val blendMode: String,
    val zIndex: Int,
    val channels: List<NativeMotionScalarChannel>,
    val layerChannels: List<NativeMotionScalarChannel>,
)

private data class NativeVisualCompositorGraphSummary(
    val layerCount: Int,
    val segmentCount: Int,
    val windowCount: Int,
    val gapWindowCount: Int,
    val mediaOnlyWindowCount: Int,
    val mediaWithAuthoredOverlayWindowCount: Int,
    val compositorRequiredWindowCount: Int,
    val compositorWindowExecutionPlanCount: Int,
    val mediaLayerCount: Int,
    val authoredLayerCount: Int,
    val maxConcurrentVisualSegments: Int,
    val requiresVisualCompositor: Boolean,
    val requirementReasons: List<String>,
)

private data class NativeVisualLayer(
    val id: String,
    val kind: String,
    val sourceTruthKind: String,
    val rendererOwnerId: String,
    val zOrder: Int,
    val supportsCurrentBackend: Boolean,
    val trackKind: String?,
)

private data class NativeVisualSegment(
    val id: String,
    val layerId: String,
    val sourceTruthKind: String,
    val rendererOwnerId: String,
    val timelineStartMs: Long,
    val timelineEndExclusiveMs: Long,
    val zOrder: Int,
    val trackKind: String?,
    val clipId: String?,
    val nodeId: String?,
)

private data class NativeVisualAssemblyWindow(
    val id: String,
    val timelineStartMs: Long,
    val timelineEndExclusiveMs: Long,
    val policy: String,
    val executionOwner: String,
    val requiresVisualCompositor: Boolean,
    val supportsCurrentBackend: Boolean,
    val activeLayerIds: List<String>,
    val activeSegmentIds: List<String>,
)

private data class NativeCompositorExecutionInput(
    val segmentId: String,
    val layerId: String,
    val role: String,
    val sourceTruthKind: String,
    val rendererOwnerId: String,
    val zOrder: Int,
    val trackKind: String?,
    val clipId: String?,
    val nodeId: String?,
)

private data class NativeCompositorWindowExecutionPlan(
    val windowId: String,
    val timelineStartMs: Long,
    val timelineEndExclusiveMs: Long,
    val executionOwner: String,
    val orderedLayerIds: List<String>,
    val orderedSegmentIds: List<String>,
    val mediaSegmentIds: List<String>,
    val authoredSegmentIds: List<String>,
    val executionInputs: List<NativeCompositorExecutionInput>,
)

private data class NativeVisualCompositorGraph(
    val summary: NativeVisualCompositorGraphSummary,
    val layers: List<NativeVisualLayer>,
    val segments: List<NativeVisualSegment>,
    val windows: List<NativeVisualAssemblyWindow>,
    val compositorWindowExecutionPlans: List<NativeCompositorWindowExecutionPlan>,
) {
    val mediaSegments: List<NativeVisualSegment>
        get() =
            segments.filter { segment ->
                segment.sourceTruthKind == "canonicalTracks" &&
                    segment.clipId != null &&
                    segment.rendererOwnerId == "media3_transformer_visual_track"
            }

    val authoredOverlaySegments: List<NativeVisualSegment>
        get() =
            segments.filter { segment ->
                segment.sourceTruthKind != "canonicalTracks"
            }

    val motionTextOverlaySegments: List<NativeVisualSegment>
        get() =
            segments.filter { segment ->
                segment.sourceTruthKind == "motionTextProgram" &&
                    segment.rendererOwnerId == "app_motion_text_program_renderer"
            }

    val authoredOverlayWindows: List<NativeVisualAssemblyWindow>
        get() {
            val overlaySegmentIds = authoredOverlaySegments.mapTo(linkedSetOf()) { it.id }
            return windows.filter { window ->
                window.activeSegmentIds.any { segmentId -> segmentId in overlaySegmentIds }
            }
        }

    val motionTextOverlayWindows: List<NativeVisualAssemblyWindow>
        get() {
            val overlaySegmentIds = motionTextOverlaySegments.mapTo(linkedSetOf()) { it.id }
            return windows.filter { window ->
                window.activeSegmentIds.any { segmentId -> segmentId in overlaySegmentIds }
            }
        }
}

private data class NativeClipWindowRoutingPlan(
    val clipId: String,
    val overlappingWindows: List<NativeVisualAssemblyWindow>,
    val mediaOnlyWindows: List<NativeVisualAssemblyWindow>,
    val overlayWindows: List<NativeVisualAssemblyWindow>,
    val blockedWindows: List<NativeVisualAssemblyWindow>,
)

private data class NativeResolvedCompositorWindowExecution(
    val windowId: String,
    val executionOwner: String,
    val result: String,
    val detail: String,
    val orderedLayerIds: List<String>,
    val orderedSegmentIds: List<String>,
    val mediaSegmentIds: List<String>,
    val authoredSegmentIds: List<String>,
    val baseSegmentId: String?,
    val baseClipId: String?,
    val overlayImageClips: List<NativeExportClip>,
    val authoredNodeIds: List<String>,
    val isExecutable: Boolean,
) {
    fun toDiagnostics(): NativeVisualCompositorRouteDiagnostics =
        NativeVisualCompositorRouteDiagnostics(
            windowId = windowId,
            executionOwner = executionOwner,
            result = result,
            detail = detail,
            baseClipId = baseClipId,
            overlayClipIds = overlayImageClips.map { clip -> clip.clipId },
            orderedLayerIds = orderedLayerIds,
            orderedSegmentIds = orderedSegmentIds,
            mediaSegmentIds = mediaSegmentIds,
            authoredSegmentIds = authoredSegmentIds,
            authoredNodeIds = authoredNodeIds,
            isExecutable = isExecutable,
        )

    companion object {
        fun blocked(
            plan: NativeCompositorWindowExecutionPlan,
            detail: String,
        ): NativeResolvedCompositorWindowExecution =
            NativeResolvedCompositorWindowExecution(
                windowId = plan.windowId,
                executionOwner = plan.executionOwner,
                result = "blocked",
                detail = detail,
                orderedLayerIds = plan.orderedLayerIds,
                orderedSegmentIds = plan.orderedSegmentIds,
                mediaSegmentIds = plan.mediaSegmentIds,
                authoredSegmentIds = plan.authoredSegmentIds,
                baseSegmentId = plan.mediaSegmentIds.firstOrNull(),
                baseClipId = null,
                overlayImageClips = emptyList(),
                authoredNodeIds = emptyList(),
                isExecutable = false,
            )

        fun executable(
            plan: NativeCompositorWindowExecutionPlan,
            baseClip: NativeExportClip,
            overlayImageClips: List<NativeExportClip>,
            authoredNodeIds: List<String>,
        ): NativeResolvedCompositorWindowExecution =
            NativeResolvedCompositorWindowExecution(
                windowId = plan.windowId,
                executionOwner = plan.executionOwner,
                result = "executed_image_overlay_stack",
                detail =
                    "Native compositor consumed plan `${plan.windowId}` through the current image-overlay stack path.",
                orderedLayerIds = plan.orderedLayerIds,
                orderedSegmentIds = plan.orderedSegmentIds,
                mediaSegmentIds = plan.mediaSegmentIds,
                authoredSegmentIds = plan.authoredSegmentIds,
                baseSegmentId =
                    plan.executionInputs.firstOrNull { input -> input.role == "baseMedia" }?.segmentId,
                baseClipId = baseClip.clipId,
                overlayImageClips = overlayImageClips,
                authoredNodeIds = authoredNodeIds,
                isExecutable = true,
            )
    }
}

private data class NativeVisualAssemblyRouteDiagnostics(
    val clipId: String,
    val graphSegmentId: String?,
    val graphLayerId: String?,
    val graphWindowId: String?,
    val coveredWindowIds: List<String>,
    val graphZOrder: Int?,
    val graphAssemblyOrder: Int?,
    val route: String,
    val timelineStartMs: Long,
    val timelineEndExclusiveMs: Long,
    val activeLayerIds: List<String>,
    val activeSegmentIds: List<String>,
) {
    fun toMap(): Map<String, Any?> =
        mapOf(
            "clipId" to clipId,
            "graphSegmentId" to graphSegmentId,
            "graphLayerId" to graphLayerId,
            "graphWindowId" to graphWindowId,
            "coveredWindowIds" to coveredWindowIds,
            "graphZOrder" to graphZOrder,
            "graphAssemblyOrder" to graphAssemblyOrder,
            "route" to route,
            "timelineStartMs" to timelineStartMs,
            "timelineEndExclusiveMs" to timelineEndExclusiveMs,
            "activeLayerIds" to activeLayerIds,
            "activeSegmentIds" to activeSegmentIds,
        )
}

private data class NativeVisualCompositorRouteDiagnostics(
    val windowId: String,
    val executionOwner: String,
    val result: String,
    val detail: String,
    val baseClipId: String?,
    val overlayClipIds: List<String>,
    val orderedLayerIds: List<String>,
    val orderedSegmentIds: List<String>,
    val mediaSegmentIds: List<String>,
    val authoredSegmentIds: List<String>,
    val authoredNodeIds: List<String>,
    val isExecutable: Boolean,
) {
    fun toMap(): Map<String, Any?> =
        mapOf(
            "windowId" to windowId,
            "executionOwner" to executionOwner,
            "result" to result,
            "detail" to detail,
            "baseClipId" to baseClipId,
            "overlayClipIds" to overlayClipIds,
            "orderedLayerIds" to orderedLayerIds,
            "orderedSegmentIds" to orderedSegmentIds,
            "mediaSegmentIds" to mediaSegmentIds,
            "authoredSegmentIds" to authoredSegmentIds,
            "authoredNodeIds" to authoredNodeIds,
            "isExecutable" to isExecutable,
        )
}

private data class NativeVisualAssemblyDiagnostics(
    val status: String,
    val routeCount: Int,
    val mediaOnlyRouteCount: Int,
    val overlayRouteCount: Int,
    val blockedRouteCount: Int,
    val compositorWindowCount: Int,
    val executableCompositorWindowCount: Int,
    val blockedCompositorWindowCount: Int,
    val firstBlockedWindowId: String?,
    val firstBlockedClipId: String?,
    val firstBlockedDetail: String?,
    val routes: List<NativeVisualAssemblyRouteDiagnostics>,
    val compositorRoutes: List<NativeVisualCompositorRouteDiagnostics>,
) {
    fun toMap(): Map<String, Any?> =
        mapOf(
            "status" to status,
            "routeCount" to routeCount,
            "mediaOnlyRouteCount" to mediaOnlyRouteCount,
            "overlayRouteCount" to overlayRouteCount,
            "blockedRouteCount" to blockedRouteCount,
            "compositorWindowCount" to compositorWindowCount,
            "executableCompositorWindowCount" to executableCompositorWindowCount,
            "blockedCompositorWindowCount" to blockedCompositorWindowCount,
            "firstBlockedWindowId" to firstBlockedWindowId,
            "firstBlockedClipId" to firstBlockedClipId,
            "firstBlockedDetail" to firstBlockedDetail,
            "routes" to routes.map { route -> route.toMap() },
            "compositorRoutes" to compositorRoutes.map { route -> route.toMap() },
        )
}

private data class NativeCanonicalEffectsGraph(
    val schemaVersion: String,
    val nodes: List<NativeCanonicalEffectsNode>,
    val operations: List<NativeCanonicalEffectsOperation>,
)

private data class NativeCanonicalEffectsNode(
    val id: String,
    val label: String,
    val kind: String,
    val sourceTruthKind: String,
    val backendSupport: List<NativeCanonicalEffectsBackendSupport>,
    val targetAddress: String? = null,
    val detail: String? = null,
)

private data class NativeCanonicalEffectsOperation(
    val id: String,
    val label: String,
    val kind: String,
    val sourceTruthKind: String,
    val backendSupport: List<NativeCanonicalEffectsBackendSupport>,
    val targetNodeId: String? = null,
    val targetAddress: String? = null,
    val propertyId: String? = null,
    val detail: String? = null,
)

private data class NativeCanonicalEffectsBackendSupport(
    val backendId: String,
    val status: String,
    val detail: String? = null,
)

internal data class NativeCanonicalEffectsDiagnostics(
    val currentBackendId: String,
    val nodeCount: Int,
    val operationCount: Int,
    val relevantNodeCount: Int,
    val relevantOperationCount: Int,
    val supportedNodeCount: Int,
    val baselineOnlyNodeCount: Int,
    val approximationNodeCount: Int,
    val blockedNodeCount: Int,
    val supportedOperationCount: Int,
    val baselineOnlyOperationCount: Int,
    val approximationOperationCount: Int,
    val blockedOperationCount: Int,
    val firstBlockedNodeId: String? = null,
    val firstBlockedOperationId: String? = null,
    val firstBlockedDetail: String? = null,
    val nodeKinds: List<String> = emptyList(),
    val operationKinds: List<String> = emptyList(),
) {
    fun toMap(): Map<String, Any?> =
        mapOf(
            "currentBackendId" to currentBackendId,
            "nodeCount" to nodeCount,
            "operationCount" to operationCount,
            "relevantNodeCount" to relevantNodeCount,
            "relevantOperationCount" to relevantOperationCount,
            "supportedNodeCount" to supportedNodeCount,
            "baselineOnlyNodeCount" to baselineOnlyNodeCount,
            "approximationNodeCount" to approximationNodeCount,
            "blockedNodeCount" to blockedNodeCount,
            "supportedOperationCount" to supportedOperationCount,
            "baselineOnlyOperationCount" to baselineOnlyOperationCount,
            "approximationOperationCount" to approximationOperationCount,
            "blockedOperationCount" to blockedOperationCount,
            "firstBlockedNodeId" to firstBlockedNodeId,
            "firstBlockedOperationId" to firstBlockedOperationId,
            "firstBlockedDetail" to firstBlockedDetail,
            "nodeKinds" to nodeKinds,
            "operationKinds" to operationKinds,
        )
}

internal data class NativeAuthoredVisualSurfaceDiagnostics(
    val status: String,
    val runtimePathKind: String,
    val nodeCount: Int,
    val imageNodeCount: Int,
    val shapeNodeCount: Int,
    val maskNodeCount: Int,
    val videoNodeCount: Int,
    val animatedNodeCount: Int,
    val blurCapableNodeCount: Int,
    val compositorOwnedSegmentCount: Int,
    val programBackedSegmentCount: Int,
    val missingProgramNodeCount: Int,
    val sampleCount: Int,
    val activeNodeCount: Int,
    val activeAnimatedNodeCount: Int,
    val activeBlurNodeCount: Int,
    val normalBlendNodeCount: Int,
    val surfaceEffectEligibleNodeCount: Int,
    val maxConcurrentActiveNodeCount: Int,
    val maxResolvedBlurAmount: Float,
    val firstMissingProgramNodeId: String? = null,
    val firstResolvedNodeId: String? = null,
    val sourceKinds: List<String> = emptyList(),
    val detail: String? = null,
) {
    fun toMap(): Map<String, Any?> =
        mapOf(
            "status" to status,
            "runtimePathKind" to runtimePathKind,
            "nodeCount" to nodeCount,
            "imageNodeCount" to imageNodeCount,
            "shapeNodeCount" to shapeNodeCount,
            "maskNodeCount" to maskNodeCount,
            "videoNodeCount" to videoNodeCount,
            "animatedNodeCount" to animatedNodeCount,
            "blurCapableNodeCount" to blurCapableNodeCount,
            "compositorOwnedSegmentCount" to compositorOwnedSegmentCount,
            "programBackedSegmentCount" to programBackedSegmentCount,
            "missingProgramNodeCount" to missingProgramNodeCount,
            "sampleCount" to sampleCount,
            "activeNodeCount" to activeNodeCount,
            "activeAnimatedNodeCount" to activeAnimatedNodeCount,
            "activeBlurNodeCount" to activeBlurNodeCount,
            "normalBlendNodeCount" to normalBlendNodeCount,
            "surfaceEffectEligibleNodeCount" to surfaceEffectEligibleNodeCount,
            "maxConcurrentActiveNodeCount" to maxConcurrentActiveNodeCount,
            "maxResolvedBlurAmount" to maxResolvedBlurAmount,
            "firstMissingProgramNodeId" to firstMissingProgramNodeId,
            "firstResolvedNodeId" to firstResolvedNodeId,
            "sourceKinds" to sourceKinds,
            "detail" to detail,
        )
}

internal data class NativeMotionTextParityDiagnostics(
    val status: String,
    val referencePathKind: String,
    val runtimePathKind: String,
    val blurExecutionMode: String,
    val glBlurSigmaPx: Float?,
    val glBlurDecisionCode: String,
    val glBlurDecisionDetail: String?,
    val sampleCount: Int,
    val sampledNodeCount: Int,
    val comparedNodeCount: Int,
    val missingRuntimeNodeCount: Int,
    val unexpectedRuntimeNodeCount: Int,
    val driftNodeCount: Int,
    val textMismatchCount: Int,
    val revealUnitMismatchCount: Int,
    val anchorMismatchCount: Int,
    val alignmentMismatchCount: Int,
    val blendModeMismatchCount: Int,
    val maxPositionDeltaPx: Float,
    val maxScaleDelta: Float,
    val maxRotationDelta: Float,
    val maxOpacityDelta: Float,
    val maxBlurDelta: Float,
    val maxFontSizeDelta: Float,
    val maxLetterSpacingDelta: Float,
    val maxRevealProgressDelta: Float,
    val worstNodeId: String? = null,
    val worstTimeMs: Long? = null,
) {
    fun toMap(): Map<String, Any?> =
        mapOf(
            "status" to status,
            "referencePathKind" to referencePathKind,
            "runtimePathKind" to runtimePathKind,
            "blurExecutionMode" to blurExecutionMode,
            "glBlurSigmaPx" to glBlurSigmaPx,
            "glBlurDecisionCode" to glBlurDecisionCode,
            "glBlurDecisionDetail" to glBlurDecisionDetail,
            "sampleCount" to sampleCount,
            "sampledNodeCount" to sampledNodeCount,
            "comparedNodeCount" to comparedNodeCount,
            "missingRuntimeNodeCount" to missingRuntimeNodeCount,
            "unexpectedRuntimeNodeCount" to unexpectedRuntimeNodeCount,
            // Compatibility aliases for older UI/client fields.
            "missingProgramNodeCount" to missingRuntimeNodeCount,
            "unexpectedProgramNodeCount" to unexpectedRuntimeNodeCount,
            "driftNodeCount" to driftNodeCount,
            "textMismatchCount" to textMismatchCount,
            "revealUnitMismatchCount" to revealUnitMismatchCount,
            "anchorMismatchCount" to anchorMismatchCount,
            "alignmentMismatchCount" to alignmentMismatchCount,
            "blendModeMismatchCount" to blendModeMismatchCount,
            "maxPositionDeltaPx" to maxPositionDeltaPx,
            "maxScaleDelta" to maxScaleDelta,
            "maxRotationDelta" to maxRotationDelta,
            "maxOpacityDelta" to maxOpacityDelta,
            "maxBlurDelta" to maxBlurDelta,
            "maxFontSizeDelta" to maxFontSizeDelta,
            "maxLetterSpacingDelta" to maxLetterSpacingDelta,
            "maxRevealProgressDelta" to maxRevealProgressDelta,
            "worstNodeId" to worstNodeId,
            "worstTimeMs" to worstTimeMs,
        )
}

private data class NativeMotionTextProgram(
    val canvasWidth: Float,
    val canvasHeight: Float,
    val nodes: List<NativeMotionTextProgramNode>,
)

private data class NativeMotionTextProgramNode(
    val id: String,
    val targetElementId: String,
    val sceneId: String,
    val layerId: String,
    val projectRangeStartMs: Long,
    val projectRangeEndExclusiveMs: Long,
    val fullText: String,
    val revealUnit: String,
    val basePositionX: Float,
    val basePositionY: Float,
    val baseScaleX: Float,
    val baseScaleY: Float,
    val baseRotationDegrees: Float,
    val baseOpacity: Float,
    val baseBlurAmount: Float,
    val baseFontSize: Float,
    val baseLetterSpacing: Float,
    val layerOpacity: Float,
    val colorArgb: Int,
    val fontFamily: String?,
    val fontWeight: Int,
    val fontStyle: String,
    val lineHeight: Float,
    val textAlignment: String,
    val anchor: String,
    val blendMode: String,
    val zIndex: Int,
    val animationKinds: Set<String>,
    val animationBlocks: List<NativeMotionTextProgramAnimationBlock>,
    val channels: List<NativeMotionScalarChannel>,
    val layerChannels: List<NativeMotionScalarChannel>,
    val name: String? = null,
    val presetId: String? = null,
)

private data class NativeMotionTextProgramAnimationBlock(
    val id: String,
    val kind: String,
    val projectRangeStartMs: Long,
    val projectRangeEndExclusiveMs: Long,
    val interpolation: NativeMotionInterpolationSpec,
    val parameters: Map<String, Map<String, Any?>>,
    val revealUnit: String? = null,
    val revealStaggerMs: Long? = null,
)

internal data class NativeMotionScalarChannel(
    val id: String,
    val propertyId: String,
    val projectRangeStartMs: Long,
    val projectRangeEndExclusiveMs: Long,
    val activeRangeStartMs: Long,
    val activeRangeEndExclusiveMs: Long,
    val beforeStart: String,
    val afterEnd: String,
    val baseValue: Float?,
    val fallbackValue: Float,
    val keyframes: List<NativeMotionScalarKeyframe>,
)

internal data class NativeMotionScalarKeyframe(
    val timeMs: Long,
    val value: Float,
    val interpolation: NativeMotionInterpolationSpec,
)

internal data class NativeMotionInterpolationSpec(
    val kind: String,
    val bezier: NativeMotionBezierControlPoints? = null,
    val spring: NativeMotionSpringSpec? = null,
    val bounce: NativeMotionBounceSpec? = null,
    val elastic: NativeMotionElasticSpec? = null,
)

internal data class NativeMotionBezierControlPoints(
    val x1: Float,
    val y1: Float,
    val x2: Float,
    val y2: Float,
)

internal data class NativeMotionSpringSpec(
    val stiffness: Float,
    val damping: Float,
    val mass: Float,
    val initialVelocity: Float,
)

internal data class NativeMotionBounceSpec(
    val amplitude: Float,
    val bounces: Int,
    val decay: Float,
)

internal data class NativeMotionElasticSpec(
    val amplitude: Float,
    val period: Float,
    val decay: Float,
)

internal data class NativeMotionTextRenderTrack(
    val canvasWidth: Float,
    val canvasHeight: Float,
    val sampleStepMs: Long,
    val samples: List<NativeMotionTextRenderSample>,
)

private data class NativeMotionTextRuntimeBundle(
    val program: NativeMotionTextProgram?,
    val rasterProgram: NativeMotionTextRasterProgram?,
    val rasterContract: NativeMotionTextRasterContract?,
    val renderTrack: NativeMotionTextRenderTrack?,
) {
    fun hasOverlaySource(): Boolean = program != null || renderTrack != null

    fun hasDeterministicRuntime(): Boolean = rasterProgram != null || program != null

    fun isAvailableForParity(): Boolean = hasDeterministicRuntime() && renderTrack != null
}

internal data class NativeAuthoredVisualSurfaceRuntimeBundle(
    val program: NativeAuthoredVisualSurfaceProgram?,
) {
    fun hasSurfaceNodes(): Boolean = program?.nodes?.isNotEmpty() == true
}

private enum class NativeMotionTextBlurExecutionMode {
    SOFTWARE_LOCAL,
    MEDIA3_GL_SEQUENCE,
}

private data class NativeMotionTextGlEffectSegment(
    val startTimeUs: Long,
    val endTimeUs: Long,
    val blurSigmaPx: Float,
    val alphaScale: Float,
)

private data class NativeMotionTextGlBlurDecision(
    val executionMode: NativeMotionTextBlurExecutionMode,
    val sigmaPx: Float? = null,
    val effectSegments: List<NativeMotionTextGlEffectSegment> = emptyList(),
    val reasonCode: String,
    val reasonDetail: String? = null,
)

internal data class NativeMotionTextRenderSample(
    val timeMs: Long,
    val nodes: List<NativeMotionTextRenderNode>,
)

internal data class NativeMotionTextRenderNode(
    val id: String,
    val text: String,
    val fullText: String,
    val revealUnit: String,
    val revealProgress: Float?,
    val hasRevealAnimation: Boolean,
    val animationKinds: Set<String>,
    val animationProgressByKind: Map<String, Float>,
    val resolvedRevealKind: String? = null,
    val resolvedRevealElapsedMs: Long? = null,
    val resolvedRevealDurationMs: Long? = null,
    val resolvedRevealStaggerMs: Long? = null,
    val canvasOffsetX: Float,
    val canvasOffsetY: Float,
    val scaleX: Float,
    val scaleY: Float,
    val rotationDegrees: Float,
    val opacity: Float,
    val blurAmount: Float,
    val fontSize: Float,
    val letterSpacing: Float,
    val colorArgb: Int,
    val fontFamily: String?,
    val fontWeight: Int,
    val fontStyle: String,
    val lineHeight: Float,
    val textAlignment: String,
    val anchor: String,
    val blendMode: String,
    val zIndex: Int,
    val presetId: String? = null,
)

private enum class NativeExportClipKind {
    VIDEO,
    IMAGE,
    AUDIO,
}

private class ConstantSpeedProvider(
    private val speed: Float,
) : SpeedProvider {
    override fun getNextSpeedChangeTimeUs(timeUs: Long): Long = C.TIME_UNSET

    override fun getSpeed(timeUs: Long): Float = speed
}

private data class OutputValidationResult(
    val isValid: Boolean,
    val failureReason: String? = null,
    val fileSizeBytes: Long = 0L,
    val durationMs: Long = 0L,
    val expectedDurationMs: Long = 0L,
    val timelineDurationMs: Long = 0L,
    val durationDeltaMs: Long = 0L,
    val hasVideo: Boolean = false,
    val expectedHasAudio: Boolean = false,
    val expectedWidth: Int? = null,
    val expectedHeight: Int? = null,
    val expectedFrameRate: Int? = null,
    val expectedVideoTrackMime: String? = null,
    val expectedAudioTrackMime: String? = null,
    val hasAudio: Boolean? = null,
    val videoTrackCount: Int = 0,
    val audioTrackCount: Int = 0,
    val actualVideoTrackMime: String? = null,
    val actualAudioTrackMime: String? = null,
    val actualFrameRate: Int? = null,
    val trackMimeTypes: List<String> = emptyList(),
    val isDurationWithinTolerance: Boolean = false,
    val isFrameRateWithinTolerance: Boolean? = null,
    val width: Int? = null,
    val height: Int? = null,
    val videoRotationDegrees: Int? = null,
    val mimeType: String? = null,
) {
    fun toMap(): Map<String, Any?> =
        mapOf(
            "fileSizeBytes" to fileSizeBytes,
            "durationMs" to durationMs,
            "expectedDurationMs" to expectedDurationMs,
            "timelineDurationMs" to timelineDurationMs,
            "durationDeltaMs" to durationDeltaMs,
            "hasVideo" to hasVideo,
            "expectedHasAudio" to expectedHasAudio,
            "expectedWidth" to expectedWidth,
            "expectedHeight" to expectedHeight,
            "expectedFrameRate" to expectedFrameRate,
            "expectedVideoTrackMime" to expectedVideoTrackMime,
            "expectedAudioTrackMime" to expectedAudioTrackMime,
            "hasAudio" to hasAudio,
            "videoTrackCount" to videoTrackCount,
            "audioTrackCount" to audioTrackCount,
            "actualVideoTrackMime" to actualVideoTrackMime,
            "actualAudioTrackMime" to actualAudioTrackMime,
            "actualFrameRate" to actualFrameRate,
            "trackMimeTypes" to trackMimeTypes,
            "isDurationWithinTolerance" to isDurationWithinTolerance,
            "isFrameRateWithinTolerance" to isFrameRateWithinTolerance,
            "width" to width,
            "height" to height,
            "videoRotationDegrees" to videoRotationDegrees,
            "mimeType" to mimeType,
        )
}

private class WindowImageCanvasOverlay(
    context: Context,
    private val overlayClip: NativeExportClip,
    private val clipTimelineStartMs: Long,
    private val allowedTimelineWindows: List<NativeVisualAssemblyWindow>,
) : CanvasOverlay(true) {
    private val imageBitmap by lazy(LazyThreadSafetyMode.NONE) {
        runCatching { decodeBitmap(context, overlayClip.sourceUri) }.getOrNull()
    }
    private val imagePaint =
        Paint(Paint.ANTI_ALIAS_FLAG).apply {
            isFilterBitmap = true
            isDither = true
        }

    override fun onDraw(canvas: Canvas, presentationTimeUs: Long) {
        clearOverlayCanvas(canvas)
        val bitmap = imageBitmap ?: return
        val globalTimelineMs =
            (clipTimelineStartMs + (presentationTimeUs / 1000L)).coerceAtLeast(0L)
        if (allowedTimelineWindows.none { window ->
                globalTimelineMs >= window.timelineStartMs &&
                    globalTimelineMs < window.timelineEndExclusiveMs
            }
        ) {
            return
        }
        val canvasWidth = canvas.width.toFloat().coerceAtLeast(1f)
        val canvasHeight = canvas.height.toFloat().coerceAtLeast(1f)
        val bitmapWidth = bitmap.width.toFloat().coerceAtLeast(1f)
        val bitmapHeight = bitmap.height.toFloat().coerceAtLeast(1f)
        val scale = kotlin.math.min(canvasWidth / bitmapWidth, canvasHeight / bitmapHeight)
        val destinationWidth = bitmapWidth * scale
        val destinationHeight = bitmapHeight * scale
        val left = (canvasWidth - destinationWidth) / 2f
        val top = (canvasHeight - destinationHeight) / 2f
        val destinationRect =
            RectF(
                left,
                top,
                left + destinationWidth,
                top + destinationHeight,
            )
        canvas.drawBitmap(bitmap, null, destinationRect, imagePaint)
    }

    companion object {
        private fun decodeBitmap(
            context: Context,
            sourceUri: String,
        ) = Uri.parse(sourceUri).let { uri ->
            when (uri.scheme?.lowercase()) {
                null, "", "file" -> BitmapFactory.decodeFile(uri.path ?: sourceUri)
                else ->
                    context.contentResolver.openInputStream(uri)?.use { input ->
                        BitmapFactory.decodeStream(input)
                    }
            }
        }
    }
}

private fun clearOverlayCanvas(canvas: Canvas) {
    // Media3 CanvasOverlay reuses the same backing bitmap across frames, so each
    // frame must explicitly clear the canvas to avoid ghosting/stale overlays.
    canvas.drawColor(0, PorterDuff.Mode.CLEAR)
}

private class MotionTextCanvasOverlay(
    private val runtimeBundle: NativeMotionTextRuntimeBundle,
    private val clipTimelineStartMs: Long,
    private val allowedTimelineWindows: List<NativeVisualAssemblyWindow> = emptyList(),
    private val allowedNodeIds: Set<String>? = null,
    private val orderedNodeIds: List<String> = emptyList(),
    private val blurExecutionMode: NativeMotionTextBlurExecutionMode =
        NativeMotionTextBlurExecutionMode.SOFTWARE_LOCAL,
    private val glBlurSigmaPx: Float? = null,
    private val glBlurDecisionCode: String = "software_local_default",
    private val glBlurDecisionDetail: String? = null,
) : CanvasOverlay(true) {
    private val textPaint =
        TextPaint(Paint.ANTI_ALIAS_FLAG).apply {
            textAlign = Paint.Align.LEFT
            isSubpixelText = true
            isDither = true
            isLinearText = true
        }
    private val motionTextProgram: NativeMotionTextProgram? = runtimeBundle.program
    private val motionTextRasterProgram: NativeMotionTextRasterProgram? = runtimeBundle.rasterProgram
    private val motionTextRasterContract: NativeMotionTextRasterContract? = runtimeBundle.rasterContract
    private val renderTrack: NativeMotionTextRenderTrack? = runtimeBundle.renderTrack
    private val rasterPolicy: NativeMotionTextRasterizationPolicy =
        motionTextRasterProgram?.rasterizationPolicy
            ?: motionTextRasterContract?.rasterizationPolicy
            ?: NativeMotionTextRasterContract.DEFAULT.rasterizationPolicy
    private val resolvedRasterContract: NativeMotionTextRasterContract =
        motionTextRasterContract ?: NativeMotionTextRasterContract.DEFAULT
    private val resolvedBlurEngineId: String =
        motionTextRasterProgram?.blurEngineId
            ?.takeIf { it.isNotBlank() }
            ?: resolvedRasterContract.blurEngineId
    private val resolvedBlurColorResolutionMode: String =
        motionTextRasterProgram?.blurColorResolutionMode
            ?.takeIf { it.isNotBlank() }
            ?: resolvedRasterContract.blurColorResolutionMode

    fun buildParityDiagnostics(): NativeMotionTextParityDiagnostics? {
        val track = renderTrack ?: return null
        val runtimePathKind =
            when {
                motionTextRasterProgram != null -> "raster_program"
                motionTextProgram != null -> "program"
                else -> return null
            }
        return Stage6MotionTextParityProbe.buildDiagnostics(
            renderTrack = track,
            runtimePathKind = runtimePathKind,
            blurExecutionMode = blurExecutionMode.name.lowercase(),
            glBlurSigmaPx = glBlurSigmaPx,
            glBlurDecisionCode = glBlurDecisionCode,
            glBlurDecisionDetail = glBlurDecisionDetail,
            resolveRuntimeNodes = ::resolveNodes,
        )
    }

    override fun onDraw(canvas: Canvas, presentationTimeUs: Long) {
        clearOverlayCanvas(canvas)
        val globalTimelineMs =
            (clipTimelineStartMs + (presentationTimeUs / 1000L)).coerceAtLeast(0L)
        if (allowedTimelineWindows.isNotEmpty() &&
            allowedTimelineWindows.none { window ->
                globalTimelineMs >= window.timelineStartMs &&
                    globalTimelineMs < window.timelineEndExclusiveMs
            }
        ) {
            return
        }
        val nodes = resolveNodes(globalTimelineMs)
        if (nodes.isEmpty()) {
            return
        }
        nodes.sortedWith(nodeComparator()).forEach { node ->
            drawNode(canvas, node)
        }
    }

    private fun resolveNodes(timeMs: Long): List<NativeMotionTextRenderNode> {
        val rasterProgram = motionTextRasterProgram
        if (rasterProgram != null) {
            return resolveRasterProgramNodes(rasterProgram, timeMs)
        }
        val program = motionTextProgram
        if (program != null) {
            return resolveProgramNodes(program, timeMs)
        }
        val renderTrack = renderTrack ?: return emptyList()
        return resolveSampledNodes(renderTrack, timeMs)
    }

    private fun resolveRasterProgramNodes(
        program: NativeMotionTextRasterProgram,
        timeMs: Long,
    ): List<NativeMotionTextRenderNode> {
        return program.nodes.mapNotNull { node ->
            evaluateRasterProgramNode(node, timeMs)
        }.filter(::isAllowedNode)
            .sortedWith(nodeComparator())
    }

    private fun resolveProgramNodes(
        program: NativeMotionTextProgram,
        timeMs: Long,
    ): List<NativeMotionTextRenderNode> {
        return program.nodes.mapNotNull { node ->
            evaluateProgramNode(node, timeMs)
        }.filter(::isAllowedNode)
            .sortedWith(nodeComparator())
    }

    private fun evaluateRasterProgramNode(
        node: NativeMotionTextRasterProgramNode,
        timeMs: Long,
    ): NativeMotionTextRenderNode? {
        if (timeMs < node.projectRangeStartMs || timeMs >= node.projectRangeEndExclusiveMs) {
            return null
        }
        val positionX =
            evaluateScalarProperty(
                channels = node.channels,
                propertyId = "transform.position.x",
                timeMs = timeMs,
                baseValue = node.canvasOffsetX,
            )
        val positionY =
            evaluateScalarProperty(
                channels = node.channels,
                propertyId = "transform.position.y",
                timeMs = timeMs,
                baseValue = node.canvasOffsetY,
            )
        val scaleX =
            evaluateScalarProperty(
                channels = node.channels,
                propertyId = "transform.scale.x",
                timeMs = timeMs,
                baseValue = node.scaleX,
            )
        val scaleY =
            evaluateScalarProperty(
                channels = node.channels,
                propertyId = "transform.scale.y",
                timeMs = timeMs,
                baseValue = node.scaleY,
            )
        val rotationDegrees =
            evaluateScalarProperty(
                channels = node.channels,
                propertyId = "transform.rotation.degrees",
                timeMs = timeMs,
                baseValue = node.rotationDegrees,
            )
        val elementOpacity =
            evaluateScalarProperty(
                channels = node.channels,
                propertyId = "visual.opacity",
                timeMs = timeMs,
                baseValue = node.opacity,
            )
        val layerOpacity =
            evaluateScalarProperty(
                channels = node.layerChannels,
                propertyId = "visual.opacity",
                timeMs = timeMs,
                baseValue = node.layerOpacity,
            )
        val blurAmount =
            evaluateScalarProperty(
                channels = node.channels,
                propertyId = "visual.blur.amount",
                timeMs = timeMs,
                baseValue = node.blurAmount,
            )
        val fontSize =
            evaluateScalarProperty(
                channels = node.channels,
                propertyId = "text.fontSize",
                timeMs = timeMs,
                baseValue = node.fontSize,
            )
        val letterSpacing =
            evaluateScalarProperty(
                channels = node.channels,
                propertyId = "text.letterSpacing",
                timeMs = timeMs,
                baseValue = node.letterSpacing,
            )
        val revealState = resolveRevealState(node.animationBlocks, timeMs)
        val revealProgress =
            revealState?.progress
                ?: evaluateScalarProperty(
                    channels = node.channels,
                    propertyId = "text.revealProgress",
                    timeMs = timeMs,
                    baseValue = 1f,
                )
        val animationProgressByKind = evaluateAnimationProgressByKind(node.animationBlocks, timeMs)
        val combinedOpacity = (elementOpacity * layerOpacity).coerceIn(0f, 1f)
        if (combinedOpacity <= 0.0001f) {
            return null
        }
        return NativeMotionTextRenderNode(
            id = node.id,
            text = node.fullText,
            fullText = node.fullText,
            revealUnit = revealState?.revealUnit ?: node.revealUnit,
            revealProgress = revealProgress.coerceIn(0f, 1f),
            hasRevealAnimation =
                revealState != null ||
                    node.animationKinds.contains("typewriter") ||
                    node.animationKinds.contains("letterReveal") ||
                    node.animationKinds.contains("wordReveal"),
            animationKinds = node.animationKinds,
            animationProgressByKind = animationProgressByKind,
            resolvedRevealKind = revealState?.kind,
            resolvedRevealElapsedMs = revealState?.elapsedMs,
            resolvedRevealDurationMs = revealState?.durationMs,
            resolvedRevealStaggerMs = revealState?.staggerMs,
            canvasOffsetX = positionX,
            canvasOffsetY = positionY,
            scaleX = scaleX,
            scaleY = scaleY,
            rotationDegrees = rotationDegrees,
            opacity = combinedOpacity,
            blurAmount = blurAmount.coerceAtLeast(0f),
            fontSize = fontSize.coerceAtLeast(1f),
            letterSpacing = letterSpacing,
            colorArgb = node.colorArgb,
            fontFamily = node.fontFamily,
            fontWeight = node.fontWeight,
            fontStyle = node.fontStyle,
            lineHeight = node.lineHeight.coerceAtLeast(0.1f),
            textAlignment = node.textAlignment,
            anchor = node.anchor,
            blendMode = node.blendMode,
            zIndex = node.zIndex,
            presetId = node.presetId,
        )
    }

    private fun evaluateProgramNode(
        node: NativeMotionTextProgramNode,
        timeMs: Long,
    ): NativeMotionTextRenderNode? {
        if (timeMs < node.projectRangeStartMs || timeMs >= node.projectRangeEndExclusiveMs) {
            return null
        }
        val rasterNode = motionTextRasterProgram?.nodesById?.get(node.id)
        val positionX =
            evaluateScalarProperty(
                channels = node.channels,
                propertyId = "transform.position.x",
                timeMs = timeMs,
                baseValue = rasterNode?.canvasOffsetX ?: node.basePositionX,
            )
        val positionY =
            evaluateScalarProperty(
                channels = node.channels,
                propertyId = "transform.position.y",
                timeMs = timeMs,
                baseValue = rasterNode?.canvasOffsetY ?: node.basePositionY,
            )
        val scaleX =
            evaluateScalarProperty(
                channels = node.channels,
                propertyId = "transform.scale.x",
                timeMs = timeMs,
                baseValue = rasterNode?.scaleX ?: node.baseScaleX,
            )
        val scaleY =
            evaluateScalarProperty(
                channels = node.channels,
                propertyId = "transform.scale.y",
                timeMs = timeMs,
                baseValue = rasterNode?.scaleY ?: node.baseScaleY,
            )
        val rotationDegrees =
            evaluateScalarProperty(
                channels = node.channels,
                propertyId = "transform.rotation.degrees",
                timeMs = timeMs,
                baseValue = rasterNode?.rotationDegrees ?: node.baseRotationDegrees,
            )
        val elementOpacity =
            evaluateScalarProperty(
                channels = node.channels,
                propertyId = "visual.opacity",
                timeMs = timeMs,
                baseValue = rasterNode?.opacity ?: node.baseOpacity,
            )
        val layerOpacity =
            evaluateScalarProperty(
                channels = node.layerChannels,
                propertyId = "visual.opacity",
                timeMs = timeMs,
                baseValue = rasterNode?.layerOpacity ?: node.layerOpacity,
            )
        val blurAmount =
            evaluateScalarProperty(
                channels = node.channels,
                propertyId = "visual.blur.amount",
                timeMs = timeMs,
                baseValue = rasterNode?.blurAmount ?: node.baseBlurAmount,
            )
        val fontSize =
            evaluateScalarProperty(
                channels = node.channels,
                propertyId = "text.fontSize",
                timeMs = timeMs,
                baseValue = rasterNode?.fontSize ?: node.baseFontSize,
            )
        val letterSpacing =
            evaluateScalarProperty(
                channels = node.channels,
                propertyId = "text.letterSpacing",
                timeMs = timeMs,
                baseValue = rasterNode?.letterSpacing ?: node.baseLetterSpacing,
            )
        val revealState = resolveRevealState(node.animationBlocks, timeMs)
        val revealProgress =
            revealState?.progress
                ?: evaluateScalarProperty(
                    channels = node.channels,
                    propertyId = "text.revealProgress",
                    timeMs = timeMs,
                    baseValue = 1f,
                )
        val animationProgressByKind = evaluateAnimationProgressByKind(node.animationBlocks, timeMs)
        val combinedOpacity = (elementOpacity * layerOpacity).coerceIn(0f, 1f)
        if (combinedOpacity <= 0.0001f) {
            return null
        }
        return NativeMotionTextRenderNode(
            id = node.id,
            text = rasterNode?.fullText ?: node.fullText,
            fullText = rasterNode?.fullText ?: node.fullText,
            revealUnit = revealState?.revealUnit ?: (rasterNode?.revealUnit ?: node.revealUnit),
            revealProgress = revealProgress.coerceIn(0f, 1f),
            hasRevealAnimation =
                revealState != null ||
                    (rasterNode?.animationKinds ?: node.animationKinds).contains("typewriter") ||
                    (rasterNode?.animationKinds ?: node.animationKinds).contains("letterReveal") ||
                    (rasterNode?.animationKinds ?: node.animationKinds).contains("wordReveal"),
            animationKinds = rasterNode?.animationKinds ?: node.animationKinds,
            animationProgressByKind = animationProgressByKind,
            resolvedRevealKind = revealState?.kind,
            resolvedRevealElapsedMs = revealState?.elapsedMs,
            resolvedRevealDurationMs = revealState?.durationMs,
            resolvedRevealStaggerMs = revealState?.staggerMs,
            canvasOffsetX = positionX,
            canvasOffsetY = positionY,
            scaleX = scaleX,
            scaleY = scaleY,
            rotationDegrees = rotationDegrees,
            opacity = combinedOpacity,
            blurAmount = blurAmount.coerceAtLeast(0f),
            fontSize = fontSize.coerceAtLeast(1f),
            letterSpacing = letterSpacing,
            colorArgb = rasterNode?.colorArgb ?: node.colorArgb,
            fontFamily = rasterNode?.fontFamily ?: node.fontFamily,
            fontWeight = rasterNode?.fontWeight ?: node.fontWeight,
            fontStyle = rasterNode?.fontStyle ?: node.fontStyle,
            lineHeight = (rasterNode?.lineHeight ?: node.lineHeight).coerceAtLeast(0.1f),
            textAlignment = rasterNode?.textAlignment ?: node.textAlignment,
            anchor = rasterNode?.anchor ?: node.anchor,
            blendMode = rasterNode?.blendMode ?: node.blendMode,
            zIndex = rasterNode?.zIndex ?: node.zIndex,
            presetId = rasterNode?.presetId ?: node.presetId,
        )
    }

    private fun evaluateScalarProperty(
        channels: List<NativeMotionScalarChannel>,
        propertyId: String,
        timeMs: Long,
        baseValue: Float,
    ): Float {
        val channel = channels.firstOrNull { it.propertyId == propertyId }
        return if (channel == null) {
            baseValue
        } else {
            evaluateScalarChannel(channel, timeMs)
        }
    }

    private fun evaluateScalarChannel(
        channel: NativeMotionScalarChannel,
        timeMs: Long,
    ): Float {
        val activeStart = channel.activeRangeStartMs
        val activeEnd = channel.activeRangeEndExclusiveMs
        if (timeMs < activeStart || timeMs >= activeEnd) {
            return channel.fallbackValue
        }
        val keyframes = channel.keyframes
        if (keyframes.isEmpty()) {
            return channel.baseValue ?: channel.fallbackValue
        }
        val first = keyframes.first()
        val last = keyframes.last()
        if (timeMs <= first.timeMs) {
            return first.value
        }
        if (timeMs >= last.timeMs) {
            return last.value
        }
        for (index in 0 until keyframes.lastIndex) {
            val current = keyframes[index]
            val next = keyframes[index + 1]
            if (timeMs < current.timeMs || timeMs > next.timeMs) {
                continue
            }
            if (timeMs == current.timeMs) {
                return current.value
            }
            if (timeMs == next.timeMs) {
                return next.value
            }
            if (current.interpolation.kind == "hold") {
                return current.value
            }
            val durationMs = (next.timeMs - current.timeMs).coerceAtLeast(1L)
            val rawProgress =
                ((timeMs - current.timeMs).toFloat() / durationMs.toFloat()).coerceIn(0f, 1f)
            val curvedProgress = curveProgress(current.interpolation, rawProgress)
            return lerp(current.value, next.value, curvedProgress)
        }
        return channel.fallbackValue
    }

    private fun evaluateAnimationProgressByKind(
        blocks: List<NativeMotionTextProgramAnimationBlock>,
        timeMs: Long,
    ): Map<String, Float> {
        if (blocks.isEmpty()) {
            return emptyMap()
        }
        val progressByKind = linkedMapOf<String, Float>()
        blocks.forEach { block ->
            val progress = evaluateBlockProgress(block, timeMs)
            if (progress <= 0f && timeMs < block.projectRangeStartMs) {
                return@forEach
            }
            val previous = progressByKind[block.kind]
            if (previous == null || progress > previous) {
                progressByKind[block.kind] = progress
            }
        }
        return progressByKind
    }

    private fun resolveRevealState(
        blocks: List<NativeMotionTextProgramAnimationBlock>,
        timeMs: Long,
    ): NativeResolvedRevealState? {
        val revealBlocks =
            blocks
                .filter { block ->
                    block.kind == "typewriter" ||
                        block.kind == "letterReveal" ||
                        block.kind == "wordReveal"
                }.sortedBy { it.projectRangeStartMs }
        if (revealBlocks.isEmpty()) {
            return null
        }
        val chosenBlock =
            revealBlocks.firstOrNull { timeMs in it.projectRangeStartMs until it.projectRangeEndExclusiveMs }
                ?: revealBlocks.lastOrNull { timeMs >= it.projectRangeStartMs }
                ?: revealBlocks.first()
        val durationMs =
            (chosenBlock.projectRangeEndExclusiveMs - chosenBlock.projectRangeStartMs)
                .coerceAtLeast(1L)
        val elapsedMs =
            (timeMs - chosenBlock.projectRangeStartMs).coerceIn(0L, durationMs)
        return NativeResolvedRevealState(
            kind = chosenBlock.kind,
            progress = evaluateBlockProgress(chosenBlock, timeMs),
            elapsedMs = elapsedMs,
            durationMs = durationMs,
            staggerMs = chosenBlock.revealStaggerMs,
            revealUnit = chosenBlock.revealUnit,
        )
    }

    private fun evaluateBlockProgress(
        block: NativeMotionTextProgramAnimationBlock,
        timeMs: Long,
    ): Float {
        if (timeMs <= block.projectRangeStartMs) {
            return 0f
        }
        if (timeMs >= block.projectRangeEndExclusiveMs) {
            return 1f
        }
        val durationMs =
            (block.projectRangeEndExclusiveMs - block.projectRangeStartMs).coerceAtLeast(1L)
        val rawProgress =
            ((timeMs - block.projectRangeStartMs).toFloat() / durationMs.toFloat()).coerceIn(0f, 1f)
        return curveProgress(block.interpolation, rawProgress)
    }

    private fun curveProgress(
        interpolation: NativeMotionInterpolationSpec,
        progress: Float,
    ): Float {
        return when (interpolation.kind) {
            "linear" -> progress
            "hold" -> 0f
            "easeIn" -> progress * progress
            "easeOut" -> {
                val inverse = 1f - progress
                1f - (inverse * inverse)
            }
            "easeInOut" ->
                if (progress < 0.5f) {
                    2f * progress * progress
                } else {
                    val inverse = (-2f * progress) + 2f
                    1f - ((inverse * inverse) / 2f)
                }
            "cubicBezier" -> evaluateBezierProgress(interpolation, progress)
            "spring" -> evaluateSpringProgress(interpolation.spring, progress)
            "bounce" -> evaluateBounceProgress(interpolation.bounce, progress)
            "elastic" -> evaluateElasticProgress(interpolation.elastic, progress)
            else ->
                throw IllegalStateException(
                    "Unsupported export interpolation kind at runtime: ${interpolation.kind}",
                )
        }
    }

    private fun evaluateBezierProgress(
        interpolation: NativeMotionInterpolationSpec,
        progress: Float,
    ): Float {
        val bezier =
            interpolation.bezier
                ?: throw IllegalStateException(
                    "cubicBezier export interpolation is missing bezier control points.",
                )
        if (progress <= 0f || progress >= 1f) {
            return progress
        }
        var parameter = progress
        repeat(6) {
            val curveX =
                cubicBezierCoordinate(
                    parameter,
                    bezier.x1,
                    bezier.x2,
                ) - progress
            if (abs(curveX) <= 0.0005f) {
                return cubicBezierCoordinate(parameter, bezier.y1, bezier.y2).coerceIn(0f, 1f)
            }
            val derivative = cubicBezierDerivative(parameter, bezier.x1, bezier.x2)
            if (abs(derivative) <= 0.00001f) {
                return@repeat
            }
            parameter = (parameter - (curveX / derivative)).coerceIn(0f, 1f)
        }
        var low = 0f
        var high = 1f
        repeat(14) {
            parameter = (low + high) / 2f
            val curveX = cubicBezierCoordinate(parameter, bezier.x1, bezier.x2)
            if (curveX < progress) {
                low = parameter
            } else {
                high = parameter
            }
        }
        return cubicBezierCoordinate(parameter, bezier.y1, bezier.y2).coerceIn(0f, 1f)
    }

    private fun evaluateSpringProgress(
        spring: NativeMotionSpringSpec?,
        progress: Float,
    ): Float {
        val t = progress.coerceIn(0f, 1f).toDouble()
        if (t <= 0.0) {
            return 0f
        }
        if (t >= 1.0) {
            return 1f
        }
        val spec = spring ?: NativeMotionSpringSpec(
            stiffness = 220f,
            damping = 18f,
            mass = 1f,
            initialVelocity = 0f,
        )
        val stiffness = spec.stiffness.toDouble().coerceAtLeast(0.0001)
        val mass = spec.mass.toDouble().coerceAtLeast(0.0001)
        val damping = spec.damping.toDouble().coerceAtLeast(0.0)
        val naturalFrequency = sqrt(stiffness / mass)
        if (!naturalFrequency.isFinite() || naturalFrequency <= 0.0) {
            return progress
        }
        val dampingRatio = damping / (2.0 * sqrt(stiffness * mass))
        val initialVelocity = spec.initialVelocity.toDouble()
        val result =
            if (dampingRatio < 1.0 - 0.0001) {
                val dampedFrequency =
                    naturalFrequency * sqrt(1.0 - (dampingRatio * dampingRatio))
                val coefficient =
                    ((dampingRatio * naturalFrequency) - initialVelocity) / dampedFrequency
                val envelope = exp(-dampingRatio * naturalFrequency * t)
                1.0 -
                    (
                        envelope *
                            (
                                cos(dampedFrequency * t) +
                                    (coefficient * sin(dampedFrequency * t))
                                )
                        )
            } else if (abs(dampingRatio - 1.0) <= 0.0001) {
                val envelope = exp(-naturalFrequency * t)
                1.0 - ((1.0 + ((naturalFrequency - initialVelocity) * t)) * envelope)
            } else {
                val sqrtTerm = sqrt((dampingRatio * dampingRatio) - 1.0)
                val rootOne = -naturalFrequency * (dampingRatio - sqrtTerm)
                val rootTwo = -naturalFrequency * (dampingRatio + sqrtTerm)
                val coefficientOne = (-initialVelocity - rootTwo) / (rootOne - rootTwo)
                val coefficientTwo = 1.0 - coefficientOne
                1.0 -
                    (
                        (coefficientOne * exp(rootOne * t)) +
                            (coefficientTwo * exp(rootTwo * t))
                        )
            }
        return result.toFloat()
    }

    private fun evaluateBounceProgress(
        bounce: NativeMotionBounceSpec?,
        progress: Float,
    ): Float {
        val t = progress.coerceIn(0f, 1f).toDouble()
        if (t <= 0.0) {
            return 0f
        }
        if (t >= 1.0) {
            return 1f
        }
        val spec = bounce ?: NativeMotionBounceSpec(
            amplitude = 0.18f,
            bounces = 3,
            decay = 8.0f,
        )
        val base = easeOutQuadratic(t)
        if (spec.amplitude <= 0f || spec.bounces <= 0) {
            return base.toFloat()
        }
        val oscillation =
            spec.amplitude.toDouble() *
                (1.0 - t).pow(0.65) *
                exp(-spec.decay.toDouble() * t) *
                abs(sin(PI * spec.bounces.toDouble() * t))
        return (base + oscillation).toFloat()
    }

    private fun evaluateElasticProgress(
        elastic: NativeMotionElasticSpec?,
        progress: Float,
    ): Float {
        val t = progress.coerceIn(0f, 1f).toDouble()
        if (t <= 0.0) {
            return 0f
        }
        if (t >= 1.0) {
            return 1f
        }
        val spec = elastic ?: NativeMotionElasticSpec(
            amplitude = 0.14f,
            period = 0.28f,
            decay = 8.0f,
        )
        val base = easeOutQuadratic(t)
        if (spec.amplitude <= 0f) {
            return base.toFloat()
        }
        val period = spec.period.toDouble().coerceAtLeast(0.0001)
        val amplitude = spec.amplitude.toDouble()
        val decay = spec.decay.toDouble()
        val raw =
            base +
                (
                    amplitude *
                        sin((2.0 * PI / period) * t) *
                        exp(-decay * t)
                    )
        val endRaw =
            1.0 +
                (
                    amplitude *
                        sin(2.0 * PI / period) *
                        exp(-decay)
                    )
        return (raw - (t * (endRaw - 1.0))).toFloat()
    }

    private fun easeOutQuadratic(progress: Double): Double {
        val inverse = 1.0 - progress
        return 1.0 - (inverse * inverse)
    }

    private fun cubicBezierCoordinate(
        t: Float,
        control1: Float,
        control2: Float,
    ): Float {
        val oneMinusT = 1f - t
        val oneMinusT2 = oneMinusT * oneMinusT
        val t2 = t * t
        return (
            (3f * oneMinusT2 * t * control1) +
                (3f * oneMinusT * t2 * control2) +
                (t2 * t)
            ).coerceIn(0f, 1f)
    }

    private fun cubicBezierDerivative(
        t: Float,
        control1: Float,
        control2: Float,
    ): Float {
        val oneMinusT = 1f - t
        return (
            (3f * oneMinusT * oneMinusT * control1) +
                (6f * oneMinusT * t * (control2 - control1)) +
                (3f * t * t * (1f - control2))
            )
    }

    private fun resolveSampledNodes(
        renderTrack: NativeMotionTextRenderTrack,
        timeMs: Long,
    ): List<NativeMotionTextRenderNode> {
        if (renderTrack.samples.isEmpty()) {
            return emptyList()
        }
        var low = 0
        var high = renderTrack.samples.lastIndex
        while (low <= high) {
            val mid = (low + high) ushr 1
            val sampleTime = renderTrack.samples[mid].timeMs
            when {
                sampleTime < timeMs -> low = mid + 1
                sampleTime > timeMs -> high = mid - 1
                else ->
                    return renderTrack.samples[mid].nodes
                        .filter(::isAllowedNode)
                        .sortedWith(nodeComparator())
            }
        }
        val insertion = low.coerceIn(0, renderTrack.samples.lastIndex)
        val leftIndex = (insertion - 1).coerceAtLeast(0)
        val rightIndex = insertion.coerceAtMost(renderTrack.samples.lastIndex)
        val left = renderTrack.samples[leftIndex]
        val right = renderTrack.samples[rightIndex]
        if (left.timeMs == right.timeMs) {
            return left.nodes.filter(::isAllowedNode).sortedWith(nodeComparator())
        }
        if (left.nodes.isEmpty()) {
            return right.nodes.filter(::isAllowedNode).sortedWith(nodeComparator())
        }
        if (right.nodes.isEmpty()) {
            return left.nodes.filter(::isAllowedNode).sortedWith(nodeComparator())
        }
        val blend =
            ((timeMs - left.timeMs).toFloat() / (right.timeMs - left.timeMs).toFloat())
                .coerceIn(0f, 1f)
        val leftById = left.nodes.associateBy { it.id }
        val rightById = right.nodes.associateBy { it.id }
        val orderedIds = linkedSetOf<String>()
        left.nodes.forEach { orderedIds += it.id }
        right.nodes.forEach { orderedIds += it.id }
        return orderedIds.mapNotNull { id ->
            interpolateNode(
                left = leftById[id],
                right = rightById[id],
                blend = blend,
            )
        }.filter(::isAllowedNode)
            .sortedWith(nodeComparator())
    }

    private fun isAllowedNode(node: NativeMotionTextRenderNode): Boolean {
        val gate = allowedNodeIds ?: return true
        return node.id in gate
    }

    private fun nodeComparator(): Comparator<NativeMotionTextRenderNode> {
        if (orderedNodeIds.isEmpty()) {
            return compareBy<NativeMotionTextRenderNode>({ it.zIndex }, { it.id })
        }
        val orderByNodeId =
            orderedNodeIds.withIndex().associate { indexed -> indexed.value to indexed.index }
        return compareBy<NativeMotionTextRenderNode>(
            { orderByNodeId[it.id] ?: Int.MAX_VALUE },
            { it.zIndex },
            { it.id },
        )
    }

    private fun interpolateNode(
        left: NativeMotionTextRenderNode?,
        right: NativeMotionTextRenderNode?,
        blend: Float,
    ): NativeMotionTextRenderNode? {
        if (left == null && right == null) {
            return null
        }
        if (left == null) {
            return right?.let { fadeNode(it, blend) }
        }
        if (right == null) {
            return left.let { fadeNode(it, 1f - blend) }
        }
        val canInterpolateReveal =
            left.hasRevealAnimation &&
                right.hasRevealAnimation &&
                left.fullText == right.fullText &&
                left.revealUnit == right.revealUnit &&
                left.colorArgb == right.colorArgb
        if (!canInterpolateReveal && (left.text != right.text || left.colorArgb != right.colorArgb)) {
            return if (blend < 0.5f) left else right
        }
        return NativeMotionTextRenderNode(
            id = left.id,
            text = if (canInterpolateReveal) left.fullText else left.text,
            fullText = if (canInterpolateReveal) left.fullText else left.fullText,
            revealUnit = if (canInterpolateReveal) left.revealUnit else left.revealUnit,
            revealProgress =
                if (canInterpolateReveal) {
                    lerp(left.revealProgress ?: 1f, right.revealProgress ?: 1f, blend)
                } else {
                    if (blend < 0.5f) left.revealProgress else right.revealProgress
                },
            hasRevealAnimation = canInterpolateReveal || left.hasRevealAnimation || right.hasRevealAnimation,
            animationKinds = left.animationKinds + right.animationKinds,
            animationProgressByKind =
                mergeAnimationProgress(
                    left = left.animationProgressByKind,
                    right = right.animationProgressByKind,
                    blend = blend,
                ),
            resolvedRevealKind =
                if (blend < 0.5f) left.resolvedRevealKind else right.resolvedRevealKind,
            resolvedRevealElapsedMs =
                if (blend < 0.5f) left.resolvedRevealElapsedMs else right.resolvedRevealElapsedMs,
            resolvedRevealDurationMs =
                if (blend < 0.5f) left.resolvedRevealDurationMs else right.resolvedRevealDurationMs,
            resolvedRevealStaggerMs =
                if (blend < 0.5f) left.resolvedRevealStaggerMs else right.resolvedRevealStaggerMs,
            canvasOffsetX = lerp(left.canvasOffsetX, right.canvasOffsetX, blend),
            canvasOffsetY = lerp(left.canvasOffsetY, right.canvasOffsetY, blend),
            scaleX = lerp(left.scaleX, right.scaleX, blend),
            scaleY = lerp(left.scaleY, right.scaleY, blend),
            rotationDegrees = lerp(left.rotationDegrees, right.rotationDegrees, blend),
            opacity = lerp(left.opacity, right.opacity, blend),
            blurAmount = lerp(left.blurAmount, right.blurAmount, blend),
            fontSize = lerp(left.fontSize, right.fontSize, blend),
            letterSpacing = lerp(left.letterSpacing, right.letterSpacing, blend),
            colorArgb = left.colorArgb,
            fontFamily = if (blend < 0.5f) left.fontFamily else right.fontFamily,
            fontWeight = if (blend < 0.5f) left.fontWeight else right.fontWeight,
            fontStyle = if (blend < 0.5f) left.fontStyle else right.fontStyle,
            lineHeight = lerp(left.lineHeight, right.lineHeight, blend).coerceAtLeast(0.1f),
            textAlignment = if (blend < 0.5f) left.textAlignment else right.textAlignment,
            anchor = if (blend < 0.5f) left.anchor else right.anchor,
            blendMode = if (blend < 0.5f) left.blendMode else right.blendMode,
            zIndex = if (blend < 0.5f) left.zIndex else right.zIndex,
            presetId = if (blend < 0.5f) left.presetId else right.presetId,
        )
    }

    private fun fadeNode(
        node: NativeMotionTextRenderNode,
        opacityFactor: Float,
    ): NativeMotionTextRenderNode {
        val clampedFactor = opacityFactor.coerceIn(0f, 1f)
        return NativeMotionTextRenderNode(
            id = node.id,
            text = node.text,
            fullText = node.fullText,
            revealUnit = node.revealUnit,
            revealProgress = node.revealProgress,
            hasRevealAnimation = node.hasRevealAnimation,
            animationKinds = node.animationKinds,
            animationProgressByKind = node.animationProgressByKind,
            resolvedRevealKind = node.resolvedRevealKind,
            resolvedRevealElapsedMs = node.resolvedRevealElapsedMs,
            resolvedRevealDurationMs = node.resolvedRevealDurationMs,
            resolvedRevealStaggerMs = node.resolvedRevealStaggerMs,
            canvasOffsetX = node.canvasOffsetX,
            canvasOffsetY = node.canvasOffsetY,
            scaleX = node.scaleX,
            scaleY = node.scaleY,
            rotationDegrees = node.rotationDegrees,
            opacity = node.opacity * clampedFactor,
            blurAmount = node.blurAmount,
            fontSize = node.fontSize,
            letterSpacing = node.letterSpacing,
            colorArgb = node.colorArgb,
            fontFamily = node.fontFamily,
            fontWeight = node.fontWeight,
            fontStyle = node.fontStyle,
            lineHeight = node.lineHeight,
            textAlignment = node.textAlignment,
            anchor = node.anchor,
            blendMode = node.blendMode,
            zIndex = node.zIndex,
            presetId = node.presetId,
        )
    }

    private fun lerp(
        left: Float,
        right: Float,
        blend: Float,
    ): Float = left + ((right - left) * blend)

    private fun mergeAnimationProgress(
        left: Map<String, Float>,
        right: Map<String, Float>,
        blend: Float,
    ): Map<String, Float> {
        if (left.isEmpty() && right.isEmpty()) {
            return emptyMap()
        }
        val keys = linkedSetOf<String>()
        keys += left.keys
        keys += right.keys
        return keys.associateWith { key ->
            lerp(left[key] ?: 0f, right[key] ?: 0f, blend).coerceIn(0f, 1f)
        }
    }

    private fun drawNode(canvas: Canvas, node: NativeMotionTextRenderNode) {
        val displayText = resolveDisplayText(node)
        if (displayText.isBlank() || node.opacity <= 0f) {
            return
        }
        val referenceCanvasWidth =
            motionTextRasterProgram?.canvasWidth
                ?: motionTextProgram?.canvasWidth
                ?: renderTrack?.canvasWidth
                ?: canvas.width.toFloat()
        val referenceCanvasHeight =
            motionTextRasterProgram?.canvasHeight
                ?: motionTextProgram?.canvasHeight
                ?: renderTrack?.canvasHeight
                ?: canvas.height.toFloat()
        val canvasScaleX =
            if (referenceCanvasWidth > 0f) {
                canvas.width / referenceCanvasWidth
            } else {
                1f
            }
        val canvasScaleY =
            if (referenceCanvasHeight > 0f) {
                canvas.height / referenceCanvasHeight
            } else {
                1f
            }
        val effectiveScale =
            kotlin.math.min(canvasScaleX, canvasScaleY).coerceAtLeast(0.01f)
        val centerX = (canvas.width / 2f) + (node.canvasOffsetX * canvasScaleX)
        val centerY = (canvas.height / 2f) + (node.canvasOffsetY * canvasScaleY)
        val effectiveFontSize =
            (node.fontSize * effectiveScale).coerceAtLeast(rasterPolicy.minimumFontSizePx)
        val resolvedColor = node.colorArgb
        val compositeAlpha =
            if (blurExecutionMode == NativeMotionTextBlurExecutionMode.MEDIA3_GL_SEQUENCE) {
                255
            } else {
                (255f * node.opacity.coerceIn(0f, 1f)).roundToInt().coerceIn(0, 255)
            }
        textPaint.color = resolvedColor
        textPaint.textSize = effectiveFontSize
        textPaint.typeface = resolveTypeface(node.fontFamily, node.fontWeight, node.fontStyle)
        textPaint.letterSpacing = 0f
        textPaint.xfermode = resolveBlendMode(node.blendMode)
        textPaint.maskFilter = null
        canvas.save()
        val layerCheckpoint =
            if (compositeAlpha < 255) {
                canvas.saveLayerAlpha(null, compositeAlpha)
            } else {
                canvas.saveLayer(null, null)
            }
        canvas.translate(centerX, centerY)
        canvas.rotate(node.rotationDegrees)
        canvas.scale(
            node.scaleX.coerceAtLeast(0.01f),
            node.scaleY.coerceAtLeast(0.01f),
        )
        val previewBlurSigma =
            (node.blurAmount * rasterPolicy.blurSigmaScale * effectiveScale).coerceAtLeast(0f)
        val letterSpacingPx = node.letterSpacing * effectiveScale
        val blurRadius = previewBlurSigma
        val blurKernelSpreadPx = previewBlurSigma * rasterPolicy.blurSpreadMultiplier
        val layoutPaddingPx =
            kotlin.math.ceil(
                    maxOf(
                        blurKernelSpreadPx.toDouble(),
                        kotlin.math.abs(letterSpacingPx).toDouble(),
                        (effectiveFontSize * rasterPolicy.fontPaddingRatio).toDouble(),
                    ),
                )
                .toInt()
                .coerceAtLeast(rasterPolicy.minimumLayoutPaddingPx.roundToInt().coerceAtLeast(0))
        val fillLayout =
            buildTextLayout(
                text = displayText,
                paint = textPaint,
                letterSpacingPx = letterSpacingPx,
                horizontalPaddingPx = layoutPaddingPx,
                lineHeightMultiplier = node.lineHeight,
                textAlignment = node.textAlignment,
            )
        val fillAnchorOffset =
            resolveAnchorOffset(
                anchor = node.anchor,
                width = fillLayout.width.toFloat(),
                height = fillLayout.height.toFloat(),
            )
        if (blurRadius > 0.05f &&
            blurExecutionMode == NativeMotionTextBlurExecutionMode.SOFTWARE_LOCAL
        ) {
            val blurRasterPaint =
                TextPaint(textPaint).apply {
                    xfermode = null
                    isSubpixelText = false
                    isLinearText = false
                }
            val blurLayout =
                buildTextLayout(
                    text = displayText,
                    paint = blurRasterPaint,
                    letterSpacingPx = letterSpacingPx,
                    horizontalPaddingPx = layoutPaddingPx,
                    lineHeightMultiplier = node.lineHeight,
                    textAlignment = node.textAlignment,
                )
            val blurAnchorOffset =
                resolveAnchorOffset(
                    anchor = node.anchor,
                    width = blurLayout.width.toFloat(),
                    height = blurLayout.height.toFloat(),
                )
            val drewRasterizedBlur =
                drawRasterizedBlurLayer(
                    canvas = canvas,
                    layout = blurLayout,
                    paint = blurRasterPaint,
                    translateX = blurAnchorOffset.first,
                    translateY = blurAnchorOffset.second,
                    blurSigma = previewBlurSigma,
                    blurEngineId = resolvedBlurEngineId,
                    blurColorResolutionMode = resolvedBlurColorResolutionMode,
                )
            if (!drewRasterizedBlur) {
                val fallbackBlurPaint =
                    TextPaint(blurRasterPaint).apply {
                        maskFilter = BlurMaskFilter(blurRadius, BlurMaskFilter.Blur.NORMAL)
                    }
                val fallbackBlurLayout =
                    buildTextLayout(
                        text = displayText,
                        paint = fallbackBlurPaint,
                        letterSpacingPx = letterSpacingPx,
                        horizontalPaddingPx = layoutPaddingPx,
                        lineHeightMultiplier = node.lineHeight,
                        textAlignment = node.textAlignment,
                    )
                canvas.save()
                canvas.translate(blurAnchorOffset.first, blurAnchorOffset.second)
                fallbackBlurLayout.draw(canvas)
                canvas.restore()
                fallbackBlurPaint.maskFilter = null
            }
        } else {
            canvas.save()
            canvas.translate(fillAnchorOffset.first, fillAnchorOffset.second)
            fillLayout.draw(canvas)
            canvas.restore()
        }
        textPaint.xfermode = null
        canvas.restoreToCount(layerCheckpoint)
        canvas.restore()
    }

    private fun drawRasterizedBlurLayer(
        canvas: Canvas,
        layout: MeasuredTextLayout,
        paint: TextPaint,
        translateX: Float,
        translateY: Float,
        blurSigma: Float,
        blurEngineId: String,
        blurColorResolutionMode: String,
    ): Boolean {
        if (blurSigma <= 0.05f || layout.width <= 0 || layout.height <= 0) {
            return false
        }
        if (blurEngineId != "gaussian_layer_blur") {
            Log.w(
                "Stage6ExportManager",
                "Unsupported motion text blur engine `$blurEngineId`; using BlurMaskFilter fallback.",
            )
            return false
        }
        return runCatching {
            val sourceBitmap =
                Bitmap.createBitmap(
                    layout.width.coerceAtLeast(1),
                    layout.height.coerceAtLeast(1),
                    Bitmap.Config.ARGB_8888,
                )
            try {
                val offscreenCanvas = Canvas(sourceBitmap)
                layout.draw(offscreenCanvas)
                val blurredBitmap =
                    when (blurColorResolutionMode) {
                        "premultiplied_text_color" ->
                            gaussianBlurBitmap(
                                sourceBitmap = sourceBitmap,
                                sigma = blurSigma,
                            )
                        "alpha_mask",
                        "alpha_mask_colorized",
                        "colorized_alpha_mask" ->
                            gaussianBlurAlphaMaskBitmap(
                                sourceBitmap = sourceBitmap,
                                sigma = blurSigma,
                                resolvedColor = paint.color,
                            )
                        else -> {
                            Log.w(
                                "Stage6ExportManager",
                                "Unknown motion text blur color mode `$blurColorResolutionMode`; defaulting to premultiplied gaussian blur.",
                            )
                            gaussianBlurBitmap(
                                sourceBitmap = sourceBitmap,
                                sigma = blurSigma,
                            )
                        }
                    }
                try {
                    canvas.save()
                    canvas.translate(translateX, translateY)
                    canvas.drawBitmap(blurredBitmap, 0f, 0f, null)
                    canvas.restore()
                } finally {
                    if (blurredBitmap !== sourceBitmap) {
                        blurredBitmap.recycle()
                    }
                }
            } finally {
                sourceBitmap.recycle()
            }
        }.onFailure { error ->
            Log.w(
                "Stage6ExportManager",
                "Motion text raster blur failed for ${layout.width}x${layout.height} sigma=$blurSigma; using BlurMaskFilter fallback.",
                error,
            )
        }.isSuccess
    }

    private fun gaussianBlurBitmap(
        sourceBitmap: Bitmap,
        sigma: Float,
    ): Bitmap {
        if (sigma <= 0.05f) {
            return sourceBitmap
        }
        val width = sourceBitmap.width
        val height = sourceBitmap.height
        if (width <= 0 || height <= 0) {
            return sourceBitmap
        }
        val radius =
            kotlin.math.ceil((sigma * 3f).toDouble()).toInt().coerceAtLeast(1)
        val kernel = buildGaussianKernel(radius, sigma)
        val sourcePixels = IntArray(width * height)
        val horizontalPixels = IntArray(width * height)
        val outputPixels = IntArray(width * height)
        sourceBitmap.getPixels(sourcePixels, 0, width, 0, 0, width, height)
        blurHorizontalPremultiplied(
            source = sourcePixels,
            destination = horizontalPixels,
            width = width,
            height = height,
            radius = radius,
            kernel = kernel,
        )
        blurVerticalPremultiplied(
            source = horizontalPixels,
            destination = outputPixels,
            width = width,
            height = height,
            radius = radius,
            kernel = kernel,
        )
        return Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888).apply {
            setPixels(outputPixels, 0, width, 0, 0, width, height)
        }
    }

    private fun gaussianBlurAlphaMaskBitmap(
        sourceBitmap: Bitmap,
        sigma: Float,
        resolvedColor: Int,
    ): Bitmap {
        if (sigma <= 0.05f) {
            return sourceBitmap
        }
        val width = sourceBitmap.width
        val height = sourceBitmap.height
        if (width <= 0 || height <= 0) {
            return sourceBitmap
        }
        val radius =
            kotlin.math.ceil((sigma * 3f).toDouble()).toInt().coerceAtLeast(1)
        val kernel = buildGaussianKernel(radius, sigma)
        val sourcePixels = IntArray(width * height)
        val sourceAlpha = IntArray(width * height)
        val horizontalAlpha = IntArray(width * height)
        val outputAlpha = IntArray(width * height)
        sourceBitmap.getPixels(sourcePixels, 0, width, 0, 0, width, height)
        for (index in sourcePixels.indices) {
            sourceAlpha[index] = (sourcePixels[index] ushr 24) and 0xFF
        }
        blurHorizontalAlpha(
            source = sourceAlpha,
            destination = horizontalAlpha,
            width = width,
            height = height,
            radius = radius,
            kernel = kernel,
        )
        blurVerticalAlpha(
            source = horizontalAlpha,
            destination = outputAlpha,
            width = width,
            height = height,
            radius = radius,
            kernel = kernel,
        )
        val rgbColor = resolvedColor and 0x00FFFFFF
        val outputPixels =
            IntArray(width * height) { index ->
                val alpha = outputAlpha[index].coerceIn(0, 255)
                (alpha shl 24) or rgbColor
            }
        return Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888).apply {
            setPixels(outputPixels, 0, width, 0, 0, width, height)
        }
    }

    private fun buildGaussianKernel(
        radius: Int,
        sigma: Float,
    ): FloatArray {
        val safeSigma = sigma.coerceAtLeast(0.1f)
        val kernel = FloatArray((radius * 2) + 1)
        val sigmaSquared = safeSigma * safeSigma
        var totalWeight = 0f
        for (index in kernel.indices) {
            val distance = index - radius
            val weight =
                kotlin.math.exp(
                    -((distance * distance).toDouble()) / (2.0 * sigmaSquared.toDouble()),
                ).toFloat()
            kernel[index] = weight
            totalWeight += weight
        }
        if (totalWeight <= 0f) {
            return kernel.apply { this[radius] = 1f }
        }
        for (index in kernel.indices) {
            kernel[index] /= totalWeight
        }
        return kernel
    }

    private fun blurHorizontalPremultiplied(
        source: IntArray,
        destination: IntArray,
        width: Int,
        height: Int,
        radius: Int,
        kernel: FloatArray,
    ) {
        for (y in 0 until height) {
            val rowOffset = y * width
            for (x in 0 until width) {
                var accumAlpha = 0f
                var accumRed = 0f
                var accumGreen = 0f
                var accumBlue = 0f
                for (kernelIndex in kernel.indices) {
                    val offset = kernelIndex - radius
                    val sampleX = (x + offset).coerceIn(0, width - 1)
                    val color = source[rowOffset + sampleX]
                    val alpha = ((color ushr 24) and 0xFF).toFloat()
                    val red = ((color ushr 16) and 0xFF).toFloat()
                    val green = ((color ushr 8) and 0xFF).toFloat()
                    val blue = (color and 0xFF).toFloat()
                    val weight = kernel[kernelIndex]
                    val alphaFactor = alpha / 255f
                    accumAlpha += alpha * weight
                    accumRed += (red * alphaFactor) * weight
                    accumGreen += (green * alphaFactor) * weight
                    accumBlue += (blue * alphaFactor) * weight
                }
                destination[rowOffset + x] =
                    packPremultipliedColor(
                        alpha = accumAlpha,
                        red = accumRed,
                        green = accumGreen,
                        blue = accumBlue,
                    )
            }
        }
    }

    private fun blurHorizontalAlpha(
        source: IntArray,
        destination: IntArray,
        width: Int,
        height: Int,
        radius: Int,
        kernel: FloatArray,
    ) {
        for (y in 0 until height) {
            val rowOffset = y * width
            for (x in 0 until width) {
                var accumAlpha = 0f
                for (kernelIndex in kernel.indices) {
                    val offset = kernelIndex - radius
                    val sampleX = (x + offset).coerceIn(0, width - 1)
                    val weight = kernel[kernelIndex]
                    accumAlpha += source[rowOffset + sampleX].toFloat() * weight
                }
                destination[rowOffset + x] = accumAlpha.roundToInt().coerceIn(0, 255)
            }
        }
    }

    private fun blurVerticalPremultiplied(
        source: IntArray,
        destination: IntArray,
        width: Int,
        height: Int,
        radius: Int,
        kernel: FloatArray,
    ) {
        for (y in 0 until height) {
            for (x in 0 until width) {
                var accumAlpha = 0f
                var accumRed = 0f
                var accumGreen = 0f
                var accumBlue = 0f
                for (kernelIndex in kernel.indices) {
                    val offset = kernelIndex - radius
                    val sampleY = (y + offset).coerceIn(0, height - 1)
                    val color = source[(sampleY * width) + x]
                    val alpha = ((color ushr 24) and 0xFF).toFloat()
                    val red = ((color ushr 16) and 0xFF).toFloat()
                    val green = ((color ushr 8) and 0xFF).toFloat()
                    val blue = (color and 0xFF).toFloat()
                    val weight = kernel[kernelIndex]
                    accumAlpha += alpha * weight
                    accumRed += red * weight
                    accumGreen += green * weight
                    accumBlue += blue * weight
                }
                destination[(y * width) + x] =
                    packUnpremultipliedColor(
                        alpha = accumAlpha,
                        red = accumRed,
                        green = accumGreen,
                        blue = accumBlue,
                    )
            }
        }
    }

    private fun blurVerticalAlpha(
        source: IntArray,
        destination: IntArray,
        width: Int,
        height: Int,
        radius: Int,
        kernel: FloatArray,
    ) {
        for (y in 0 until height) {
            for (x in 0 until width) {
                var accumAlpha = 0f
                for (kernelIndex in kernel.indices) {
                    val offset = kernelIndex - radius
                    val sampleY = (y + offset).coerceIn(0, height - 1)
                    val weight = kernel[kernelIndex]
                    accumAlpha += source[(sampleY * width) + x].toFloat() * weight
                }
                destination[(y * width) + x] = accumAlpha.roundToInt().coerceIn(0, 255)
            }
        }
    }

    private fun packPremultipliedColor(
        alpha: Float,
        red: Float,
        green: Float,
        blue: Float,
    ): Int {
        val resolvedAlpha = alpha.roundToInt().coerceIn(0, 255)
        val resolvedRed = red.roundToInt().coerceIn(0, resolvedAlpha)
        val resolvedGreen = green.roundToInt().coerceIn(0, resolvedAlpha)
        val resolvedBlue = blue.roundToInt().coerceIn(0, resolvedAlpha)
        return (resolvedAlpha shl 24) or
            (resolvedRed shl 16) or
            (resolvedGreen shl 8) or
            resolvedBlue
    }

    private fun packUnpremultipliedColor(
        alpha: Float,
        red: Float,
        green: Float,
        blue: Float,
    ): Int {
        val resolvedAlpha = alpha.roundToInt().coerceIn(0, 255)
        if (resolvedAlpha <= 0) {
            return 0
        }
        val resolvedRed =
            ((red * 255f) / resolvedAlpha.toFloat()).roundToInt().coerceIn(0, 255)
        val resolvedGreen =
            ((green * 255f) / resolvedAlpha.toFloat()).roundToInt().coerceIn(0, 255)
        val resolvedBlue =
            ((blue * 255f) / resolvedAlpha.toFloat()).roundToInt().coerceIn(0, 255)
        return (resolvedAlpha shl 24) or
            (resolvedRed shl 16) or
            (resolvedGreen shl 8) or
            resolvedBlue
    }

    private fun buildTextLayout(
        text: String,
        paint: TextPaint,
        letterSpacingPx: Float,
        horizontalPaddingPx: Int = 0,
        lineHeightMultiplier: Float = 1f,
        textAlignment: String = "center",
    ): MeasuredTextLayout {
        val safeText = text.ifEmpty { " " }
        val layoutPaint =
            TextPaint(paint).apply {
                letterSpacing =
                    if (textSize > 0f) {
                        letterSpacingPx / textSize
                    } else {
                        0f
                    }
            }
        val contentWidth =
            safeText
                .split('\n')
                .maxOfOrNull { line ->
                    Layout.getDesiredWidth(line.ifEmpty { " " }, layoutPaint).toDouble()
                }
                ?.toFloat()
                ?.coerceAtLeast(1f)
                ?: layoutPaint.measureText(" ").coerceAtLeast(1f)
        val layoutWidth = kotlin.math.ceil(contentWidth.toDouble()).toInt().coerceAtLeast(1)
        val staticLayout =
            StaticLayout.Builder
                .obtain(safeText, 0, safeText.length, layoutPaint, layoutWidth)
                .setAlignment(resolveTextAlignment(textAlignment))
                .setIncludePad(false)
                .setLineSpacing(0f, lineHeightMultiplier.coerceAtLeast(0.1f))
                .setTextDirection(TextDirectionHeuristics.LTR)
                .build()
        val width = layoutWidth + (horizontalPaddingPx * 2)
        val height = staticLayout.height + (horizontalPaddingPx * 2)
        return MeasuredTextLayout(
            width = width.coerceAtLeast(1),
            height = height.coerceAtLeast(1),
            layout = staticLayout,
            horizontalPaddingPx = horizontalPaddingPx,
        )
    }

    private fun resolveTypeface(
        fontFamily: String?,
        fontWeight: Int,
        fontStyle: String,
    ): Typeface {
        val isItalic = fontStyle == "italic"
        val style =
            when {
                fontWeight >= 600 && isItalic -> Typeface.BOLD_ITALIC
                fontWeight >= 600 -> Typeface.BOLD
                isItalic -> Typeface.ITALIC
                else -> Typeface.NORMAL
            }
        return Typeface.create(fontFamily, style)
    }

    private fun resolveAnchorOffset(
        anchor: String,
        width: Float,
        height: Float,
    ): Pair<Float, Float> {
        return when (anchor) {
            "topLeft" -> 0f to 0f
            "topCenter" -> (-width / 2f) to 0f
            "topRight" -> (-width) to 0f
            "centerLeft" -> 0f to (-height / 2f)
            "centerRight" -> (-width) to (-height / 2f)
            "bottomLeft" -> 0f to (-height)
            "bottomCenter" -> (-width / 2f) to (-height)
            "bottomRight" -> (-width) to (-height)
            else -> (-width / 2f) to (-height / 2f)
        }
    }

    private fun resolveDisplayText(node: NativeMotionTextRenderNode): String {
        if (!node.hasRevealAnimation || node.fullText.isBlank()) {
            return node.text
        }
        val normalizedProgress = (node.revealProgress ?: 1f).coerceIn(0f, 1f)
        if (normalizedProgress <= 0f) {
            return ""
        }
        if (normalizedProgress >= 1f) {
            return node.fullText
        }
        return when (node.revealUnit) {
            "word" -> {
                val words =
                    node.fullText
                        .trim()
                        .split(Regex("\\s+"))
                        .filter { it.isNotBlank() }
                if (words.isEmpty()) {
                    ""
                } else {
                    val count = resolveRevealCount(words.size, normalizedProgress, node)
                    words.take(count).joinToString(" ")
                }
            }
            "letter" -> {
                val codePointCount = node.fullText.codePointCount(0, node.fullText.length)
                val count = resolveRevealCount(codePointCount, normalizedProgress, node)
                if (count <= 0) {
                    ""
                } else {
                    val endIndex = node.fullText.offsetByCodePoints(0, count)
                    node.fullText.substring(0, endIndex)
                }
            }
            else -> node.fullText
        }
    }

    private fun resolveRevealCount(
        totalUnits: Int,
        normalizedProgress: Float,
        node: NativeMotionTextRenderNode,
    ): Int {
        if (totalUnits <= 0) {
            return 0
        }
        val curvedCount =
            kotlin.math.ceil(totalUnits * normalizedProgress.toDouble()).toInt().coerceIn(0, totalUnits)
        val staggerMs = node.resolvedRevealStaggerMs ?: return curvedCount
        val elapsedMs = node.resolvedRevealElapsedMs ?: return curvedCount
        val durationMs = node.resolvedRevealDurationMs ?: return curvedCount
        if (staggerMs <= 0L || durationMs <= 0L) {
            return curvedCount
        }
        val effectiveStepMs =
            kotlin.math.min(
                    staggerMs.toDouble(),
                    durationMs.toDouble() / totalUnits.coerceAtLeast(1).toDouble(),
                )
                .coerceAtLeast(1.0)
        val sequentialCount =
            if (elapsedMs <= 0L) {
                0
            } else {
                (kotlin.math.floor(elapsedMs.toDouble() / effectiveStepMs).toInt() + 1)
                    .coerceIn(0, totalUnits)
            }
        return kotlin.math.min(totalUnits, kotlin.math.max(curvedCount, sequentialCount))
    }

    private fun resolveBlendMode(blendMode: String): PorterDuffXfermode? {
        val porterDuffMode =
            when (blendMode) {
                "multiply" -> PorterDuff.Mode.MULTIPLY
                "screen" -> PorterDuff.Mode.SCREEN
                "overlay" -> PorterDuff.Mode.OVERLAY
                "darken" -> PorterDuff.Mode.DARKEN
                "lighten" -> PorterDuff.Mode.LIGHTEN
                "plus" -> PorterDuff.Mode.ADD
                else -> null
            }
        return porterDuffMode?.let(::PorterDuffXfermode)
    }

    private fun resolveTextAlignment(textAlignment: String): Layout.Alignment {
        return when (textAlignment) {
            "start", "left" -> Layout.Alignment.ALIGN_NORMAL
            "end", "right" -> Layout.Alignment.ALIGN_OPPOSITE
            else -> Layout.Alignment.ALIGN_CENTER
        }
    }
}

private data class MeasuredTextLayout(
    val width: Int,
    val height: Int,
    val layout: StaticLayout,
    val horizontalPaddingPx: Int,
) {
    fun draw(
        canvas: Canvas,
    ) {
        canvas.save()
        canvas.translate(horizontalPaddingPx.toFloat(), horizontalPaddingPx.toFloat())
        layout.draw(canvas)
        canvas.restore()
    }
}

private data class NativeResolvedRevealState(
    val kind: String,
    val progress: Float,
    val elapsedMs: Long,
    val durationMs: Long,
    val staggerMs: Long?,
    val revealUnit: String?,
)
