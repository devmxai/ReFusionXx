package com.refusion.app

import android.Manifest
import android.content.pm.PackageManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

class MainActivity: FlutterActivity() {
    companion object {
        private const val MEDIA_PERMISSION_REQUEST_CODE = 4106
    }

    private lateinit var stage5TransportManager: Stage5TransportManager
    private lateinit var stage5NativeScrubEngine: Stage5NativeScrubEngine
    private lateinit var stage5ScrubPreparationManager: Stage5ScrubPreparationManager
    private lateinit var stage6ExportManager: Stage6ExportManager
    private lateinit var deviceMediaLibraryManager: DeviceMediaLibraryManager
    private val mediaQueryExecutor: ExecutorService = Executors.newSingleThreadExecutor()
    private val mediaThumbnailExecutor: ExecutorService = Executors.newFixedThreadPool(4)
    private val mainHandler = Handler(Looper.getMainLooper())
    private var pendingMediaTab: String? = null
    private var pendingMediaResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        stage5TransportManager = Stage5TransportManager(applicationContext)
        stage5ScrubPreparationManager = Stage5ScrubPreparationManager(applicationContext)
        stage5NativeScrubEngine =
            Stage5NativeScrubEngine(
                scrubPreparationManager = stage5ScrubPreparationManager,
            )
        stage6ExportManager =
            Stage6ExportManager(
                appContext = applicationContext,
                previewTransportManager = stage5TransportManager,
            )
        deviceMediaLibraryManager = DeviceMediaLibraryManager(applicationContext)

        flutterEngine.platformViewsController.registry.registerViewFactory(
            Stage5TransportManager.PREVIEW_VIEW_TYPE,
            Stage5PreviewPlatformViewFactory(
                stage5TransportManager,
                stage5NativeScrubEngine,
            ),
        )

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            Stage5TransportManager.METHOD_CHANNEL_NAME,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "initializeTransport" -> result.success(stage5TransportManager.initializeTransport())
                "prepareSample" -> result.success(stage5TransportManager.prepareSample())
                "prepareImportedMedia" -> {
                    val sourceUri = call.argument<String>("sourceUri")
                    val sourceLabel = call.argument<String>("sourceLabel")
                    if (sourceUri.isNullOrBlank() || sourceLabel.isNullOrBlank()) {
                        result.error(
                            "invalid_media_source",
                            "Imported media source is missing required data.",
                            null,
                        )
                    } else {
                        result.success(
                            stage5TransportManager.prepareImportedMedia(
                                sourceUri = sourceUri,
                                sourceLabel = sourceLabel,
                            ),
                        )
                    }
                }
                "prepareTimelineSegments" -> {
                    val rawSegments = call.argument<List<Any?>>("segments") ?: emptyList()
                    val segments =
                        rawSegments.mapNotNull { entry ->
                            (entry as? Map<*, *>)?.mapKeys { (key, _) -> key.toString() }
                        }
                    val startPositionMs =
                        call.argument<Number>("startPositionMs")?.toLong() ?: 0L
                    result.success(
                        stage5TransportManager.prepareTimelineSegments(
                            segmentMaps = segments,
                            startPositionMs = startPositionMs,
                        ),
                    )
                }
                "loadDeviceMedia" -> {
                    val tab = call.argument<String>("tab") ?: "video"
                    val offset = call.argument<Int>("offset") ?: 0
                    val limit = call.argument<Int>("limit") ?: 24
                    loadDeviceMedia(tab, offset, limit, result)
                }
                "loadMediaThumbnail" -> {
                    val sourceUri = call.argument<String>("sourceUri")
                    val targetWidth = call.argument<Int>("targetWidth") ?: 192
                    val targetHeight = call.argument<Int>("targetHeight") ?: 288
                    if (sourceUri.isNullOrBlank()) {
                        result.error(
                            "invalid_thumbnail_source",
                            "Media thumbnail source is missing.",
                            null,
                        )
                    } else {
                        mediaThumbnailExecutor.execute {
                            runCatching {
                                stage5TransportManager.loadMediaThumbnail(
                                    sourceUri = sourceUri,
                                    targetWidth = targetWidth,
                                    targetHeight = targetHeight,
                                )
                            }.onSuccess { thumbnailBytes ->
                                mainHandler.post {
                                    result.success(thumbnailBytes)
                                }
                            }.onFailure { error ->
                                mainHandler.post {
                                    result.error(
                                        "thumbnail_load_failed",
                                        error.message ?: "Unable to load media thumbnail.",
                                        null,
                                    )
                                }
                            }
                        }
                    }
                }
                "loadMediaFramePreview" -> {
                    val sourceUri = call.argument<String>("sourceUri")
                    val positionMs = call.argument<Int>("positionMs") ?: 0
                    val targetWidth = call.argument<Int>("targetWidth") ?: 320
                    val targetHeight = call.argument<Int>("targetHeight") ?: 568
                    if (sourceUri.isNullOrBlank()) {
                        result.error(
                            "invalid_frame_preview_source",
                            "Media frame preview source is missing.",
                            null,
                        )
                    } else {
                        mediaThumbnailExecutor.execute {
                            runCatching {
                                stage5TransportManager.loadMediaFramePreview(
                                    sourceUri = sourceUri,
                                    positionMs = positionMs.toLong(),
                                    targetWidth = targetWidth,
                                    targetHeight = targetHeight,
                                )
                            }.onSuccess { frameBytes ->
                                mainHandler.post {
                                    result.success(frameBytes)
                                }
                            }.onFailure { error ->
                                mainHandler.post {
                                    result.error(
                                        "frame_preview_load_failed",
                                        error.message ?: "Unable to load media frame preview.",
                                        null,
                                    )
                                }
                            }
                        }
                    }
                }
                "prepareScrubFrameStore" -> {
                    val assetId = call.argument<String>("assetId")
                    val sourceUri = call.argument<String>("sourceUri")
                    val durationMs = call.argument<Number>("durationMs")?.toLong() ?: 0L
                    val sourceWidth = call.argument<Int>("sourceWidth")
                    val sourceHeight = call.argument<Int>("sourceHeight")
                    val targetWidth = call.argument<Int>("targetWidth") ?: 240
                    val targetHeight = call.argument<Int>("targetHeight") ?: 426
                    if (assetId.isNullOrBlank() || sourceUri.isNullOrBlank()) {
                        result.error(
                            "invalid_scrub_store_request",
                            "Scrub frame store request is missing asset or source data.",
                            null,
                        )
                    } else {
                        runCatching {
                            stage5ScrubPreparationManager.prepareStore(
                                Stage5ScrubFrameStoreRequest(
                                    assetId = assetId,
                                    sourceUri = sourceUri,
                                    durationMs = durationMs,
                                    sourceWidth = sourceWidth,
                                    sourceHeight = sourceHeight,
                                    previewWidth = targetWidth,
                                    previewHeight = targetHeight,
                                ),
                            )
                        }.onSuccess { status ->
                            result.success(status.toMap())
                        }.onFailure { error ->
                            result.error(
                                "scrub_store_prepare_failed",
                                error.message ?: "Unable to prepare scrub frame store.",
                                null,
                            )
                        }
                    }
                }
                "getScrubFrameStoreStatus" -> {
                    val assetId = call.argument<String>("assetId")
                    if (assetId.isNullOrBlank()) {
                        result.success(null)
                    } else {
                        result.success(
                            stage5ScrubPreparationManager.getStatus(assetId)?.toMap(),
                        )
                    }
                }
                "ensureScrubPreviewTexture" -> {
                    val targetWidth = call.argument<Int>("targetWidth") ?: 480
                    val targetHeight = call.argument<Int>("targetHeight") ?: 854
                    runCatching {
                        stage5NativeScrubEngine.ensureTexture(
                            targetWidth = targetWidth,
                            targetHeight = targetHeight,
                        )
                    }.onSuccess(result::success)
                        .onFailure { error ->
                            result.error(
                                "scrub_texture_init_failed",
                                error.message ?: "Unable to initialize scrub texture.",
                                null,
                            )
                        }
                }
                "beginScrubPreviewTextureSession" -> {
                    val scrubStoreKey = call.argument<String>("scrubStoreKey")
                    val positionMs = call.argument<Int>("positionMs") ?: 0
                    val targetWidth = call.argument<Int>("targetWidth") ?: 480
                    val targetHeight = call.argument<Int>("targetHeight") ?: 854
                    if (scrubStoreKey.isNullOrBlank()) {
                        result.error(
                            "invalid_scrub_session_store",
                            "Scrub session store key is missing.",
                            null,
                        )
                    } else {
                        runCatching {
                            stage5NativeScrubEngine.beginSession(
                                    scrubStoreKey = scrubStoreKey,
                                    positionMs = positionMs.toLong(),
                                    targetWidth = targetWidth,
                                    targetHeight = targetHeight,
                                )
                        }.onSuccess {
                            result.success(null)
                        }.onFailure { error ->
                            result.error(
                                "scrub_session_begin_failed",
                                error.message ?: "Unable to begin scrub session.",
                                null,
                            )
                        }
                    }
                }
                "renderScrubPreviewTextureFrame" -> {
                    val scrubStoreKey = call.argument<String>("scrubStoreKey")
                    val positionMs = call.argument<Int>("positionMs") ?: 0
                    val targetWidth = call.argument<Int>("targetWidth") ?: 480
                    val targetHeight = call.argument<Int>("targetHeight") ?: 854
                    if (scrubStoreKey.isNullOrBlank()) {
                        result.error(
                            "invalid_scrub_texture_store",
                            "Scrub texture store key is missing.",
                            null,
                        )
                    } else {
                        runCatching {
                            stage5NativeScrubEngine.updateTarget(
                                scrubStoreKey = scrubStoreKey,
                                positionMs = positionMs.toLong(),
                                targetWidth = targetWidth,
                                targetHeight = targetHeight,
                            )
                        }.onSuccess {
                            result.success(null)
                        }
                            .onFailure { error ->
                                result.error(
                                    "scrub_texture_render_failed",
                                    error.message ?: "Unable to render scrub preview frame.",
                                    null,
                                )
                            }
                    }
                }
                "clearScrubPreviewTexture" -> {
                    runCatching {
                        stage5NativeScrubEngine.clearTexture()
                    }.onSuccess {
                        result.success(null)
                    }.onFailure { error ->
                        result.error(
                            "scrub_texture_clear_failed",
                            error.message ?: "Unable to clear scrub texture.",
                            null,
                        )
                    }
                }
                "disposeScrubPreviewTexture" -> {
                    runCatching {
                        stage5NativeScrubEngine.disposeTexture()
                    }.onSuccess {
                        result.success(null)
                    }.onFailure { error ->
                        result.error(
                            "scrub_texture_dispose_failed",
                            error.message ?: "Unable to dispose scrub texture.",
                            null,
                        )
                    }
                }
                "endScrubPreviewTextureSession" -> {
                    runCatching {
                        stage5NativeScrubEngine.endSession()
                    }.onSuccess {
                        result.success(null)
                    }.onFailure { error ->
                        result.error(
                            "scrub_session_end_failed",
                            error.message ?: "Unable to end scrub session.",
                            null,
                        )
                    }
                }
                "loadMediaThumbnails" -> {
                    val rawRequests = call.argument<List<Any?>>("requests") ?: emptyList()
                    val targetWidth = call.argument<Int>("targetWidth") ?: 192
                    val targetHeight = call.argument<Int>("targetHeight") ?: 288
                    val requests =
                        rawRequests.mapNotNull { entry ->
                            (entry as? Map<*, *>)?.mapKeys { (key, _) -> key.toString() }
                        }
                    mediaThumbnailExecutor.execute {
                        val thumbnails = HashMap<String, ByteArray?>()
                        requests.forEach { request ->
                            val assetId = request["assetId"]?.toString()
                            val sourceUri = request["sourceUri"]?.toString()
                            if (assetId.isNullOrBlank() || sourceUri.isNullOrBlank()) {
                                return@forEach
                            }
                            thumbnails[assetId] =
                                runCatching {
                                    stage5TransportManager.loadMediaThumbnail(
                                        sourceUri = sourceUri,
                                        targetWidth = targetWidth,
                                        targetHeight = targetHeight,
                                    )
                                }.getOrNull()
                        }
                        mainHandler.post {
                            result.success(thumbnails)
                        }
                    }
                }
                "play" -> {
                    stage5TransportManager.play()
                    result.success(null)
                }
                "pause" -> {
                    stage5TransportManager.pause()
                    result.success(null)
                }
                "seekTo" -> {
                    val positionMs = call.argument<Number>("positionMs")?.toLong() ?: 0L
                    stage5TransportManager.seekTo(positionMs)
                    result.success(null)
                }
                "previewScrubTo" -> {
                    val positionMs = call.argument<Number>("positionMs")?.toLong() ?: 0L
                    stage5TransportManager.previewScrubTo(positionMs)
                    result.success(null)
                }
                "setScrubbing" -> {
                    val isScrubbing = call.argument<Boolean>("isScrubbing") ?: false
                    val finalPositionMs = call.argument<Number>("finalPositionMs")?.toLong()
                    stage5TransportManager.setScrubbing(isScrubbing, finalPositionMs)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }

        EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            Stage5TransportManager.EVENT_CHANNEL_NAME,
        ).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
                    stage5TransportManager.attachEventSink(events)
                }

                override fun onCancel(arguments: Any?) {
                    stage5TransportManager.detachEventSink()
                }
            },
        )

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            Stage6ExportManager.METHOD_CHANNEL_NAME,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "exportTimeline" -> {
                    val composition =
                        call.argument<Map<String, Any?>>("composition")
                            ?.mapKeys { (key, _) -> key.toString() }
                            ?: emptyMap()
                    val preset = call.argument<String>("preset") ?: "fullHd1080p"
                    val requestedFrameRate =
                        call.argument<Number>("requestedFrameRate")?.toInt()
                    val requestedFileName = call.argument<String>("requestedFileName")
                    result.success(
                        stage6ExportManager.exportTimeline(
                            compositionMap = composition,
                            preset = preset,
                            requestedFrameRate = requestedFrameRate,
                            requestedFileName = requestedFileName,
                        ),
                    )
                }
                "cancelExport" -> {
                    val jobId = call.argument<String>("jobId")
                    if (jobId.isNullOrBlank()) {
                        result.error(
                            "invalid_export_job",
                            "Export job id is missing.",
                            null,
                        )
                    } else {
                        result.success(stage6ExportManager.cancelExport(jobId))
                    }
                }
                "openExportOutput" -> {
                    val outputPath = call.argument<String>("outputPath")
                    val mimeType = call.argument<String>("mimeType")
                    if (outputPath.isNullOrBlank()) {
                        result.error(
                            "invalid_export_output",
                            "Export output path is missing.",
                            null,
                        )
                    } else {
                        result.success(
                            stage6ExportManager.openExportOutput(
                                outputPath = outputPath,
                                mimeType = mimeType,
                            ),
                        )
                    }
                }
                "shareExportOutput" -> {
                    val outputPath = call.argument<String>("outputPath")
                    val mimeType = call.argument<String>("mimeType")
                    if (outputPath.isNullOrBlank()) {
                        result.error(
                            "invalid_export_output",
                            "Export output path is missing.",
                            null,
                        )
                    } else {
                        result.success(
                            stage6ExportManager.shareExportOutput(
                                outputPath = outputPath,
                                mimeType = mimeType,
                            ),
                        )
                    }
                }
                "saveExportOutputToGallery" -> {
                    val outputPath = call.argument<String>("outputPath")
                    val mimeType = call.argument<String>("mimeType")
                    if (outputPath.isNullOrBlank()) {
                        result.error(
                            "invalid_export_output",
                            "Export output path is missing.",
                            null,
                        )
                    } else {
                        result.success(
                            stage6ExportManager.saveExportOutputToGallery(
                                outputPath = outputPath,
                                mimeType = mimeType,
                            ),
                        )
                    }
                }
                else -> result.notImplemented()
            }
        }

        EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            Stage6ExportManager.EVENT_CHANNEL_NAME,
        ).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
                    stage6ExportManager.attachEventSink(events)
                }

                override fun onCancel(arguments: Any?) {
                    stage6ExportManager.detachEventSink()
                }
            },
        )
    }

    private fun loadDeviceMedia(
        tab: String,
        offset: Int,
        limit: Int,
        result: MethodChannel.Result,
    ) {
        val requiredPermissions = requiredMediaPermissions(tab)
        if (requiredPermissions.isEmpty() || hasAnyPermission(requiredPermissions)) {
            loadDeviceMediaAsync(tab, offset, limit, result)
            return
        }
        if (pendingMediaResult != null) {
            result.error(
                "media_request_busy",
                "Another media access request is already in progress.",
                null,
            )
            return
        }
        pendingMediaTab = tab
        pendingMediaResult = result
        ActivityCompat.requestPermissions(
            this,
            requiredPermissions.toTypedArray(),
            MEDIA_PERMISSION_REQUEST_CODE,
        )
    }

    private fun requiredMediaPermissions(tab: String): List<String> =
        when {
            Build.VERSION.SDK_INT >= 34 && tab == "image" ->
                listOf(
                    Manifest.permission.READ_MEDIA_IMAGES,
                    Manifest.permission.READ_MEDIA_VISUAL_USER_SELECTED,
                )
            Build.VERSION.SDK_INT >= 34 ->
                listOf(
                    Manifest.permission.READ_MEDIA_VIDEO,
                    Manifest.permission.READ_MEDIA_VISUAL_USER_SELECTED,
                )
            Build.VERSION.SDK_INT >= 33 && tab == "image" ->
                listOf(Manifest.permission.READ_MEDIA_IMAGES)
            Build.VERSION.SDK_INT >= 33 ->
                listOf(Manifest.permission.READ_MEDIA_VIDEO)
            else -> listOf(Manifest.permission.READ_EXTERNAL_STORAGE)
        }

    private fun hasAnyPermission(permissions: List<String>): Boolean =
        permissions.any { permission ->
            ContextCompat.checkSelfPermission(this, permission) ==
                PackageManager.PERMISSION_GRANTED
        }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != MEDIA_PERMISSION_REQUEST_CODE) {
            return
        }
        val result = pendingMediaResult ?: return
        val tab = pendingMediaTab ?: "video"
        pendingMediaResult = null
        pendingMediaTab = null
        if (grantResults.any { it == PackageManager.PERMISSION_GRANTED }) {
            loadDeviceMediaAsync(tab, 0, 24, result)
            return
        }
        result.error(
            "media_access_denied",
            "Media library access was denied.",
            null,
        )
    }

    override fun onDestroy() {
        if (::stage5TransportManager.isInitialized && isFinishing) {
            stage5TransportManager.release()
        }
        if (::stage5NativeScrubEngine.isInitialized) {
            stage5NativeScrubEngine.release()
        }
        mediaQueryExecutor.shutdownNow()
        mediaThumbnailExecutor.shutdownNow()
        super.onDestroy()
    }

    private fun loadDeviceMediaAsync(
        tab: String,
        offset: Int,
        limit: Int,
        result: MethodChannel.Result,
    ) {
        mediaQueryExecutor.execute {
            runCatching {
                deviceMediaLibraryManager.queryMediaPage(
                    tab = tab,
                    offset = offset,
                    limit = limit,
                )
            }.onSuccess { page ->
                mainHandler.post {
                    result.success(page)
                }
            }.onFailure { error ->
                mainHandler.post {
                    result.error(
                        "media_query_failed",
                        error.message ?: "Unable to load device media.",
                        null,
                    )
                }
            }
        }
    }
}
