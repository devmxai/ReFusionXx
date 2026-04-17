package com.refusion.app

import android.content.Context
import android.graphics.Bitmap
import android.media.MediaExtractor
import android.media.MediaFormat
import android.media.MediaMetadataRetriever
import android.net.Uri
import android.os.Handler
import android.os.Build
import android.os.Looper
import android.util.LruCache
import android.util.Size
import androidx.media3.common.C
import androidx.media3.common.MediaItem
import androidx.media3.common.MediaMetadata
import androidx.media3.common.PlaybackParameters
import androidx.media3.common.PlaybackException
import androidx.media3.common.Player
import androidx.media3.common.VideoSize
import androidx.media3.common.util.UnstableApi
import androidx.media3.datasource.RawResourceDataSource
import androidx.media3.exoplayer.DefaultRenderersFactory
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.exoplayer.SeekParameters
import androidx.media3.transformer.Composition
import androidx.media3.transformer.CompositionPlayer
import androidx.media3.transformer.EditedMediaItem
import androidx.media3.transformer.EditedMediaItemSequence
import io.flutter.plugin.common.EventChannel
import java.io.ByteArrayOutputStream
import kotlin.math.roundToLong

@UnstableApi
class Stage5TransportManager(context: Context) {
    companion object {
        const val METHOD_CHANNEL_NAME = "com.refusion.app/stage5_transport"
        const val EVENT_CHANNEL_NAME = "com.refusion.app/stage5_transport_events"
        const val PREVIEW_VIEW_TYPE = "com.refusion.app/stage5_preview"
        const val TIMELINE_SCRUB_VIEW_TYPE = "com.refusion.app/stage5_timeline_scrub"
        private const val PLAYBACK_POSITION_EMIT_INTERVAL_MS = 33L
        private const val SCRUB_POSITION_EMIT_INTERVAL_MS = 16L
        // Cross-source playback continuity benefits from warming the next adjacent item
        // earlier than the original baseline.
        private const val MULTI_ITEM_PRELOAD_DURATION_US = 12_000_000L
        private const val SOURCE_CONTIGUITY_TOLERANCE_MS = 1L
        private const val LOW_LATENCY_VIDEO_JOINING_TIME_MS = 350L
        private const val SCRUB_SETTLE_WATCHDOG_MS = 320L
        private const val SCRUB_SETTLE_MAX_WATCHDOG_ATTEMPTS = 3
        private const val SCRUB_SETTLE_TOLERANCE_MS = 12L
        private const val DISPLAYABLE_END_EPSILON_MS = 1L
        // Composition-based multi-clip preview remains future-gated until it can preserve
        // live scrub parity with the accepted Exo baseline.
        private const val ENABLE_COMPOSITION_TIMELINE_PREVIEW = false
    }

    private val appContext = context.applicationContext
    private val mainHandler = Handler(Looper.getMainLooper())

    private var exoPlayer: ExoPlayer? = null
    private var compositionPlayer: CompositionPlayer? = null
    private var activePlayer: Player? = null
    private var eventSink: EventChannel.EventSink? = null
    private var videoWidth = 0
    private var videoHeight = 0
    private var latestError: String? = null
    private var lastRequestedPositionMs = 0L
    private var currentSourceKind = "idle"
    private var currentSourceLabel: String? = null
    private var timelineSegments: List<TimelineSegment> = emptyList()
    private var timelineRuns: List<TimelineRun> = emptyList()
    private var timelineDurationMs = 0L
    private var timelineSegmentOffsetsMs = LongArray(0)
    private var timelineRunEndOffsetsMs = LongArray(0)
    private var singleSourceTimelineUri: Uri? = null
    private var activeTimelineRunIndex = 0
    private var activeTimelineSegmentIndex = 0
    private var lastAppliedPlaybackRate: Float? = null
    private var isScrubSettling = false
    private var scrubSettleTargetPositionMs: Long? = null
    private var scrubSettlePositionSatisfied = false
    private var scrubSettleRenderedFirstFrameSeen = false
    private var scrubSettleWatchdogAttempts = 0
    private var timelinePlaybackBackend = TimelinePlaybackBackend.NONE
    private var isPreviewOutputSuppressed = false
    private val playerObservers = LinkedHashSet<(Player) -> Unit>()
    private val previewRetentionObservers = LinkedHashSet<(Boolean) -> Unit>()
    private val previewOutputSuppressionObservers = LinkedHashSet<(Boolean) -> Unit>()
    private val scrubSettlingObservers = LinkedHashSet<(Boolean) -> Unit>()
    private val audioSignatureCache = HashMap<String, AudioSignature?>()
    private val thumbnailCache =
        object : LruCache<String, ByteArray>(12 * 1024 * 1024) {
            override fun sizeOf(key: String, value: ByteArray): Int = value.size
        }
    private data class TimelineSegment(
        val clipId: String,
        val sourceUri: Uri,
        val sourceLabel: String,
        val startMs: Long,
        val endMs: Long,
        val timelineDurationMs: Long,
        val playbackRate: Double,
        val isFullSource: Boolean,
    ) {
        val sourceDurationMs: Long
            get() = (endMs - startMs).coerceAtLeast(0L)
    }

    private data class TimelineSeekPoint(
        val segmentIndex: Int,
        val itemIndex: Int,
        val itemPositionMs: Long,
        val sourcePositionMs: Long,
    )

    private data class AudioSignature(
        val mimeType: String,
        val sampleRate: Int?,
        val channelCount: Int?,
        val codecString: String?,
    )

    private data class TimelineRun(
        val sourceUri: Uri,
        val sourceLabel: String,
        val startSegmentIndex: Int,
        val segments: List<TimelineSegment>,
        val startTimelineOffsetMs: Long,
        val windowStartMs: Long,
        val windowEndMs: Long,
    ) {
        val durationMs: Long
            get() = segments.fold(0L) { sum, segment -> sum + segment.timelineDurationMs }

        val endSegmentIndexInclusive: Int
            get() = startSegmentIndex + segments.lastIndex
    }

    private enum class TimelineBoundaryType {
        SAME_SOURCE_CONTIGUOUS,
        SAME_SOURCE_GAPPED,
        CROSS_SOURCE,
    }

    private enum class TimelinePlaybackBackend {
        NONE,
        SINGLE_SOURCE_EXO,
        RUNS_EXO,
        COMPOSITION,
    }

    val player: Player
        get() = activePlayer ?: ensurePlayer().also { activatePlayer(it) }

    private val stateEmitter =
        object : Runnable {
            override fun run() {
                updateTimelinePlaybackWindow()
                emitState()
            }
        }
    private val scrubSettleWatchdog =
        object : Runnable {
            override fun run() {
                if (!isScrubSettling) {
                    return
                }
                val targetPositionMs = scrubSettleTargetPositionMs
                val player = activePlayer ?: exoPlayer ?: compositionPlayer
                val playbackState = player?.playbackState ?: Player.STATE_IDLE
                if (targetPositionMs != null) {
                    scrubSettlePositionSatisfied =
                        kotlin.math.abs(currentTimelinePositionMs() - targetPositionMs) <=
                            SCRUB_SETTLE_TOLERANCE_MS ||
                            playbackState == Player.STATE_ENDED
                }
                scrubSettleWatchdogAttempts += 1
                if (scrubSettlePositionSatisfied && scrubSettleRenderedFirstFrameSeen) {
                    finishScrubSettle(forcePositionUpdate = true)
                    return
                }
                if (scrubSettleWatchdogAttempts >= SCRUB_SETTLE_MAX_WATCHDOG_ATTEMPTS) {
                    scrubSettleRenderedFirstFrameSeen = true
                    scrubSettlePositionSatisfied = true
                    finishScrubSettle(forcePositionUpdate = true)
                    return
                }
                mainHandler.postDelayed(this, SCRUB_SETTLE_WATCHDOG_MS)
            }
        }

    private val playerListener =
        object : Player.Listener {
            override fun onPlaybackStateChanged(playbackState: Int) {
                maybeFinishScrubSettle()
                updateTimelinePlaybackWindow()
                emitState()
            }

            override fun onIsPlayingChanged(isPlaying: Boolean) {
                emitState()
            }

            override fun onPositionDiscontinuity(
                oldPosition: Player.PositionInfo,
                newPosition: Player.PositionInfo,
                reason: Int,
            ) {
                maybeFinishScrubSettle()
                updateTimelinePlaybackWindow()
                emitState()
            }

            override fun onRenderedFirstFrame() {
                if (isScrubSettling) {
                    scrubSettleRenderedFirstFrameSeen = true
                    maybeFinishScrubSettle()
                }
                emitState()
            }

            override fun onVideoSizeChanged(videoSize: VideoSize) {
                videoWidth = videoSize.width
                videoHeight = videoSize.height
                emitState()
            }

            override fun onPlayerError(error: PlaybackException) {
                finishScrubSettle(forcePositionUpdate = false)
                latestError = error.message ?: error.errorCodeName
                emitState()
                mainHandler.post { recoverFromPlaybackError() }
            }
        }

    fun initializeTransport(): Map<String, Any?> {
        val exo = ensurePlayer()
        activatePlayer(exo)
        latestError = null
        exo.setPreloadConfiguration(ExoPlayer.PreloadConfiguration.DEFAULT)
        exo.pause()
        exo.clearMediaItems()
        compositionPlayer?.pause()
        compositionPlayer?.stop()
        videoWidth = 0
        videoHeight = 0
        timelineSegments = emptyList()
        timelineRuns = emptyList()
        timelineDurationMs = 0L
        timelineSegmentOffsetsMs = LongArray(0)
        timelineRunEndOffsetsMs = LongArray(0)
        singleSourceTimelineUri = null
        activeTimelineRunIndex = 0
        activeTimelineSegmentIndex = 0
        timelinePlaybackBackend = TimelinePlaybackBackend.NONE
        currentSourceKind = "idle"
        currentSourceLabel = null
        latestError = null
        lastRequestedPositionMs = 0L
        lastAppliedPlaybackRate = null
        finishScrubSettle(forcePositionUpdate = false)
        emitPreviewRetentionPolicy()
        emitState()
        return buildState()
    }

    fun prepareSample(): Map<String, Any?> {
        val exo = ensurePlayer()
        activatePlayer(exo)
        latestError = null
        exo.setPreloadConfiguration(ExoPlayer.PreloadConfiguration.DEFAULT)
        val sampleUri = RawResourceDataSource.buildRawResourceUri(R.raw.stage5_sample)
        val currentUri = exo.currentMediaItem?.localConfiguration?.uri
        if (currentUri != sampleUri) {
            exo.setMediaItem(MediaItem.fromUri(sampleUri))
            videoWidth = 0
            videoHeight = 0
        }
        compositionPlayer?.pause()
        compositionPlayer?.stop()
        timelineSegments = emptyList()
        timelineRuns = emptyList()
        timelineDurationMs = 0L
        timelineSegmentOffsetsMs = LongArray(0)
        timelineRunEndOffsetsMs = LongArray(0)
        singleSourceTimelineUri = null
        activeTimelineRunIndex = 0
        activeTimelineSegmentIndex = 0
        timelinePlaybackBackend = TimelinePlaybackBackend.NONE
        currentSourceKind = "sample"
        currentSourceLabel = "BMFLite official sample"
        exo.pause()
        exo.seekTo(0)
        lastRequestedPositionMs = 0L
        lastAppliedPlaybackRate = null
        finishScrubSettle(forcePositionUpdate = false)
        emitPreviewRetentionPolicy()
        exo.prepare()
        emitState()
        return buildState()
    }

    fun loadMediaThumbnail(sourceUri: String, targetWidth: Int, targetHeight: Int): ByteArray? {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
            return null
        }
        val safeWidth = targetWidth.coerceIn(96, 256)
        val safeHeight = targetHeight.coerceIn(128, 384)
        val cacheKey = "$sourceUri|$safeWidth|$safeHeight"
        thumbnailCache.get(cacheKey)?.let { return it }
        val bitmap =
            appContext.contentResolver.loadThumbnail(
                Uri.parse(sourceUri),
                Size(safeWidth, safeHeight),
                null,
            ) ?: return null
        val bytes =
            ByteArrayOutputStream().use { output ->
                bitmap.compress(Bitmap.CompressFormat.JPEG, 82, output)
                output.toByteArray()
            }
        bitmap.recycle()
        thumbnailCache.put(cacheKey, bytes)
        return bytes
    }

    private fun loadMediaFramePreviewBitmap(
        sourceUri: String,
        positionMs: Long,
        targetWidth: Int,
        targetHeight: Int,
    ): Bitmap? {
        val safeWidth = targetWidth.coerceIn(120, 480)
        val safeHeight = targetHeight.coerceIn(180, 854)
        val safePositionMs = positionMs.coerceAtLeast(0L)
        var retriever: MediaMetadataRetriever? = null
        var bitmap: Bitmap? = null
        return try {
            retriever = MediaMetadataRetriever()
            retriever.setDataSource(appContext, Uri.parse(sourceUri))
            val bucketedPositionMs = (safePositionMs / 33L) * 33L
            val timeUs = bucketedPositionMs * 1000L
            bitmap =
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
                    retriever.getScaledFrameAtTime(
                        timeUs,
                        MediaMetadataRetriever.OPTION_CLOSEST,
                        safeWidth,
                        safeHeight,
                    )
                } else {
                    retriever.getFrameAtTime(timeUs, MediaMetadataRetriever.OPTION_CLOSEST)
                }
                    ?: retriever.getFrameAtTime(
                        timeUs,
                        MediaMetadataRetriever.OPTION_CLOSEST_SYNC,
                    )
            val resolvedBitmap = bitmap ?: return null
            if (resolvedBitmap.width == safeWidth && resolvedBitmap.height == safeHeight) {
                resolvedBitmap
            } else {
                Bitmap.createScaledBitmap(resolvedBitmap, safeWidth, safeHeight, true).also {
                    if (resolvedBitmap !== it) {
                        resolvedBitmap.recycle()
                    }
                }
            }
        } finally {
            retriever?.release()
        }
    }

    fun loadMediaFramePreview(
        sourceUri: String,
        positionMs: Long,
        targetWidth: Int,
        targetHeight: Int,
    ): ByteArray? {
        val safeWidth = targetWidth.coerceIn(120, 480)
        val safeHeight = targetHeight.coerceIn(180, 854)
        val safePositionMs = positionMs.coerceAtLeast(0L)
        val bucketedPositionMs = (safePositionMs / 33L) * 33L
        val cacheKey = "$sourceUri|frame|$bucketedPositionMs|$safeWidth|$safeHeight"
        thumbnailCache.get(cacheKey)?.let { return it }

        val bitmap =
            loadMediaFramePreviewBitmap(
                sourceUri = sourceUri,
                positionMs = bucketedPositionMs,
                targetWidth = safeWidth,
                targetHeight = safeHeight,
            ) ?: return null
        return try {
            val bytes =
                ByteArrayOutputStream().use { output ->
                    bitmap.compress(Bitmap.CompressFormat.JPEG, 84, output)
                    output.toByteArray()
                }
            thumbnailCache.put(cacheKey, bytes)
            bytes
        } finally {
            bitmap.recycle()
        }
    }

    fun renderMediaFramePreviewBitmap(
        sourceUri: String,
        positionMs: Long,
        targetWidth: Int,
        targetHeight: Int,
    ): Bitmap? =
        loadMediaFramePreviewBitmap(
            sourceUri = sourceUri,
            positionMs = positionMs,
            targetWidth = targetWidth,
            targetHeight = targetHeight,
        )

    fun prepareImportedMedia(sourceUri: String, sourceLabel: String): Map<String, Any?> {
        val exo = ensurePlayer()
        activatePlayer(exo)
        latestError = null
        exo.setPreloadConfiguration(ExoPlayer.PreloadConfiguration.DEFAULT)
        val importedUri = Uri.parse(sourceUri)
        val currentUri = exo.currentMediaItem?.localConfiguration?.uri
        if (currentUri != importedUri) {
            exo.setMediaItem(MediaItem.fromUri(importedUri))
            videoWidth = 0
            videoHeight = 0
        }
        compositionPlayer?.pause()
        compositionPlayer?.stop()
        timelineSegments = emptyList()
        timelineRuns = emptyList()
        timelineDurationMs = 0L
        timelineSegmentOffsetsMs = LongArray(0)
        timelineRunEndOffsetsMs = LongArray(0)
        singleSourceTimelineUri = null
        activeTimelineRunIndex = 0
        activeTimelineSegmentIndex = 0
        timelinePlaybackBackend = TimelinePlaybackBackend.NONE
        currentSourceKind = "imported"
        currentSourceLabel = sourceLabel
        exo.pause()
        exo.seekTo(0)
        lastRequestedPositionMs = 0L
        lastAppliedPlaybackRate = null
        finishScrubSettle(forcePositionUpdate = false)
        emitPreviewRetentionPolicy()
        exo.prepare()
        emitState()
        return buildState()
    }

    fun prepareTimelineSegments(
        segmentMaps: List<Map<String, Any?>>,
        startPositionMs: Long,
    ): Map<String, Any?> {
        latestError = null
        val segments =
            segmentMaps.mapNotNull { entry ->
                val clipId = entry["clipId"]?.toString()?.takeIf { it.isNotBlank() } ?: return@mapNotNull null
                val sourceUriValue =
                    entry["sourceUri"]?.toString()?.takeIf { it.isNotBlank() } ?: return@mapNotNull null
                val sourceLabel =
                    entry["sourceLabel"]?.toString()?.takeIf { it.isNotBlank() } ?: "Imported clip"
                val startMs =
                    when (val value = entry["startMs"]) {
                        is Int -> value.toLong()
                        is Long -> value
                        is Double -> value.toLong()
                        else -> 0L
                    }.coerceAtLeast(0L)
                val endMs =
                    when (val value = entry["endMs"]) {
                        is Int -> value.toLong()
                        is Long -> value
                        is Double -> value.toLong()
                        else -> startMs
                    }.coerceAtLeast(startMs)
                val sourceDurationMs = (endMs - startMs).coerceAtLeast(0L)
                val playbackRate =
                    when (val value = entry["playbackRate"]) {
                        is Int -> value.toDouble()
                        is Long -> value.toDouble()
                        is Float -> value.toDouble()
                        is Double -> value
                        else -> 1.0
                    }.coerceAtLeast(0.01)
                val timelineDurationMs =
                    when (val value = entry["timelineDurationMs"]) {
                        is Int -> value.toLong()
                        is Long -> value
                        is Double -> value.toLong()
                        else -> 0L
                    }.let { explicitDuration ->
                        when {
                            explicitDuration > 0L -> explicitDuration
                            sourceDurationMs <= 0L -> 0L
                            else -> (sourceDurationMs / playbackRate).roundToLong()
                        }
                    }.coerceAtLeast(1L)
                TimelineSegment(
                    clipId = clipId,
                    sourceUri = Uri.parse(sourceUriValue),
                    sourceLabel = sourceLabel,
                    startMs = startMs,
                    endMs = endMs,
                    timelineDurationMs = timelineDurationMs,
                    playbackRate = playbackRate,
                    isFullSource = (entry["isFullSource"] as? Boolean) == true,
                ).takeIf { it.sourceDurationMs > 0L }
            }

        activePlayer?.pause()
        finishScrubSettle(forcePositionUpdate = false)
        resetTimelineProjectionForStructuralCommit()

        if (segments.isEmpty()) {
            val exo = ensurePlayer()
            activatePlayer(exo)
            timelineSegments = emptyList()
            timelineRuns = emptyList()
            timelineDurationMs = 0L
            timelineSegmentOffsetsMs = LongArray(0)
            timelineRunEndOffsetsMs = LongArray(0)
            timelinePlaybackBackend = TimelinePlaybackBackend.NONE
            currentSourceKind = "idle"
            currentSourceLabel = null
            exo.clearMediaItems()
            compositionPlayer?.pause()
            compositionPlayer?.stop()
            videoWidth = 0
            videoHeight = 0
            emitPreviewRetentionPolicy()
            emitState()
            return buildState()
        }

        timelineSegments = segments
        timelineDurationMs = segments.fold(0L) { sum, segment -> sum + segment.timelineDurationMs }
        timelineRuns = buildTimelineRuns(segments)
        timelineSegmentOffsetsMs = buildTimelineSegmentOffsets(segments)
        timelineRunEndOffsetsMs = buildTimelineRunEndOffsets(timelineRuns)
        currentSourceKind = "timeline"
        currentSourceLabel = if (segments.size == 1) segments.first().sourceLabel else "Timeline sequence"
        lastRequestedPositionMs = startPositionMs.coerceIn(0L, timelineDurationMs)
        val sharedUri = sharedTimelineSourceUri(segments)
        if (sharedUri != null) {
            return prepareSingleSourceTimeline(
                sourceUri = sharedUri,
                startPositionMs = lastRequestedPositionMs,
            )
        }

        singleSourceTimelineUri = null
        activeTimelineRunIndex = 0
        activeTimelineSegmentIndex = 0
        videoWidth = 0
        videoHeight = 0
        if (!ENABLE_COMPOSITION_TIMELINE_PREVIEW || !canUseCompositionTimelinePreview(segments)) {
            return prepareRunTimeline(startPositionMs = lastRequestedPositionMs)
        }
        return prepareCompositionTimeline(startPositionMs = lastRequestedPositionMs)
    }

    fun play() {
        latestError = null
        if (isScrubSettling) {
            finishScrubSettle(forcePositionUpdate = false)
        }
        recoverFromTimelineEndedStateIfNeeded()
        if (timelineSegments.isNotEmpty()) {
            applyPlaybackRateForSegmentIndex(activeTimelineSegmentIndex)
        }
        player.play()
        emitState()
    }

    fun pause() {
        player.pause()
        emitState()
    }

    fun seekTo(positionMs: Long) {
        val safePositionMs = positionMs.coerceAtLeast(0L)
        lastRequestedPositionMs = safePositionMs
        finishScrubSettle(forcePositionUpdate = false)
        performResolvedSeek(safePositionMs)
        emitState()
    }

    fun settleAfterScrub(positionMs: Long) {
        val safePositionMs = positionMs.coerceAtLeast(0L)
        lastRequestedPositionMs = safePositionMs
        player.pause()
        beginExactScrubSettle(safePositionMs)
        emitPreviewRetentionPolicy()
        emitState()
    }

    fun addPlayerObserver(observer: (Player) -> Unit) {
        playerObservers.add(observer)
        observer(player)
    }

    fun removePlayerObserver(observer: (Player) -> Unit) {
        playerObservers.remove(observer)
    }

    fun addPreviewRetentionObserver(observer: (Boolean) -> Unit) {
        previewRetentionObservers.add(observer)
        observer(shouldRetainPreviewContentOnReset())
    }

    fun removePreviewRetentionObserver(observer: (Boolean) -> Unit) {
        previewRetentionObservers.remove(observer)
    }

    fun addPreviewOutputSuppressionObserver(observer: (Boolean) -> Unit) {
        previewOutputSuppressionObservers.add(observer)
        observer(isPreviewOutputSuppressed)
    }

    fun removePreviewOutputSuppressionObserver(observer: (Boolean) -> Unit) {
        previewOutputSuppressionObservers.remove(observer)
    }

    fun addScrubSettlingObserver(observer: (Boolean) -> Unit) {
        scrubSettlingObservers.add(observer)
        observer(isScrubSettling)
    }

    fun removeScrubSettlingObserver(observer: (Boolean) -> Unit) {
        scrubSettlingObservers.remove(observer)
    }

    fun suspendPreviewOutputForExport() {
        if (isPreviewOutputSuppressed) {
            return
        }
        activePlayer?.pause()
        isPreviewOutputSuppressed = true
        emitPreviewOutputSuppressionState()
        emitState()
    }

    fun resumePreviewOutputAfterExport() {
        if (!isPreviewOutputSuppressed) {
            return
        }
        isPreviewOutputSuppressed = false
        emitPreviewOutputSuppressionState()
        emitState()
    }

    fun attachEventSink(events: EventChannel.EventSink) {
        eventSink = events
        emitState()
    }

    fun detachEventSink() {
        eventSink = null
        cancelStateEmitter()
    }

    fun release() {
        detachEventSink()
        finishScrubSettle(forcePositionUpdate = false)
        exoPlayer?.let { currentPlayer ->
            currentPlayer.removeListener(playerListener)
            currentPlayer.release()
        }
        compositionPlayer?.let { currentPlayer ->
            currentPlayer.removeListener(playerListener)
            currentPlayer.release()
        }
        exoPlayer = null
        compositionPlayer = null
        activePlayer = null
    }

    private fun ensurePlayer(): ExoPlayer {
        exoPlayer?.let { return it }
        val renderersFactory =
            DefaultRenderersFactory(appContext)
                .forceEnableMediaCodecAsynchronousQueueing()
                .setAllowedVideoJoiningTimeMs(LOW_LATENCY_VIDEO_JOINING_TIME_MS)
                .experimentalSetEnableMediaCodecVideoRendererPrewarming(true)
        val createdPlayer =
            ExoPlayer.Builder(appContext, renderersFactory)
                .setUseLazyPreparation(false)
                .build()
                .apply {
                    repeatMode = Player.REPEAT_MODE_OFF
                    playWhenReady = false
                    setVideoScalingMode(C.VIDEO_SCALING_MODE_SCALE_TO_FIT)
                    setSeekParameters(SeekParameters.EXACT)
                    addListener(playerListener)
                }
        exoPlayer = createdPlayer
        return createdPlayer
    }

    private fun ensureCompositionPlayer(): CompositionPlayer {
        compositionPlayer?.let { return it }
        val createdPlayer =
            CompositionPlayer.Builder(appContext)
                .setLooper(Looper.getMainLooper())
                .build()
                .apply {
                    repeatMode = Player.REPEAT_MODE_OFF
                    playWhenReady = false
                    addListener(playerListener)
                }
        compositionPlayer = createdPlayer
        return createdPlayer
    }

    private fun beginExactScrubSettle(positionMs: Long) {
        val safePositionMs = positionMs.coerceAtLeast(0L)
        lastRequestedPositionMs = safePositionMs
        isScrubSettling = true
        scrubSettleTargetPositionMs = safePositionMs
        scrubSettlePositionSatisfied = false
        scrubSettleRenderedFirstFrameSeen = false
        scrubSettleWatchdogAttempts = 0
        mainHandler.removeCallbacks(scrubSettleWatchdog)
        mainHandler.postDelayed(scrubSettleWatchdog, SCRUB_SETTLE_WATCHDOG_MS)
        (activePlayer as? ExoPlayer)?.setSeekParameters(SeekParameters.EXACT)
        performResolvedSeek(safePositionMs)
        emitScrubSettlingState()
    }

    private fun recoverFromPlaybackError() {
        if (timelineSegments.isEmpty()) {
            return
        }
        val recoverPositionMs =
            safeDisplayableEndPosition(lastRequestedPositionMs.coerceIn(0L, timelineDurationMs))
        finishScrubSettle(forcePositionUpdate = false)
        exoPlayer?.let { currentPlayer ->
            currentPlayer.removeListener(playerListener)
            currentPlayer.release()
        }
        compositionPlayer?.let { currentPlayer ->
            currentPlayer.removeListener(playerListener)
            currentPlayer.release()
        }
        exoPlayer = null
        compositionPlayer = null
        activePlayer = null
        latestError = null
        val sharedUri = sharedTimelineSourceUri(timelineSegments)
        if (sharedUri != null) {
            prepareSingleSourceTimeline(sourceUri = sharedUri, startPositionMs = recoverPositionMs)
            return
        }
        if (!ENABLE_COMPOSITION_TIMELINE_PREVIEW || !canUseCompositionTimelinePreview(timelineSegments)) {
            prepareRunTimeline(startPositionMs = recoverPositionMs)
            return
        }
        prepareCompositionTimeline(startPositionMs = recoverPositionMs)
    }

    private fun emitState() {
        eventSink?.success(buildState())
        syncStateEmitterSchedule()
    }

    private fun syncStateEmitterSchedule() {
        cancelStateEmitter()
        if (eventSink == null) {
            return
        }
        val intervalMs = currentStateEmitterIntervalMs() ?: return
        mainHandler.postDelayed(stateEmitter, intervalMs)
    }

    private fun cancelStateEmitter() {
        mainHandler.removeCallbacks(stateEmitter)
    }

    private fun currentStateEmitterIntervalMs(): Long? {
        val activePlayer = activePlayer ?: exoPlayer ?: compositionPlayer
        return when {
            isScrubSettling -> SCRUB_POSITION_EMIT_INTERVAL_MS
            activePlayer?.playWhenReady == true -> PLAYBACK_POSITION_EMIT_INTERVAL_MS
            else -> null
        }
    }

    private fun recoverFromTimelineEndedStateIfNeeded() {
        if (timelineSegments.isEmpty()) {
            return
        }
        val activePlayer = activePlayer ?: exoPlayer ?: compositionPlayer ?: return
        if (activePlayer.playbackState != Player.STATE_ENDED) {
            return
        }
        if (timelineDurationMs <= 0L) {
            return
        }
        val recoveryPositionMs = (timelineDurationMs - 1L).coerceAtLeast(0L)
        if (currentTimelinePositionMs() < timelineDurationMs) {
            return
        }
        lastRequestedPositionMs = recoveryPositionMs
        performResolvedSeek(recoveryPositionMs)
    }

    private fun buildState(): Map<String, Any?> {
        val activePlayer = activePlayer ?: exoPlayer ?: compositionPlayer
        val durationMs =
            if (timelineSegments.isNotEmpty()) {
                timelineDurationMs
            } else {
                activePlayer?.duration
                    ?.takeIf { it >= 0L }
                    ?: 0L
            }
        val positionMs =
            if (timelineSegments.isNotEmpty()) {
                currentTimelinePositionMs()
            } else {
                activePlayer?.currentPosition ?: 0L
            }
        val playbackState = activePlayer?.playbackState ?: Player.STATE_IDLE
        val isPlaying = if (isScrubSettling) false else activePlayer?.playWhenReady ?: false
        return mapOf(
            "isReady" to (playbackState == Player.STATE_READY),
            "isPlaying" to isPlaying,
            "durationMs" to durationMs,
            "positionMs" to positionMs.coerceAtLeast(0L),
            "playbackState" to playbackState,
            "videoWidth" to videoWidth,
            "videoHeight" to videoHeight,
            "isScrubbing" to false,
            "isScrubSettling" to isScrubSettling,
            "sourceKind" to currentSourceKind,
            "sourceLabel" to currentSourceLabel,
            "error" to latestError,
        )
    }

    private fun performResolvedSeek(positionMs: Long) {
        val safePositionMs = positionMs.coerceAtLeast(0L)
        if (timelineSegments.isNotEmpty()) {
            if (isCompositionTimelineMode()) {
                val clampedPositionMs = safePositionMs.coerceIn(0L, timelineDurationMs)
                val seekPoint = resolveTimelineSeekPoint(globalPositionMs = clampedPositionMs)
                activeTimelineSegmentIndex = seekPoint.segmentIndex
                activeTimelineRunIndex = 0
                player.seekTo(clampedPositionMs)
                return
            }
            val rawSeekPoint =
                if (isRunTimelineMode()) {
                    resolveTimelineRunSeekPoint(globalPositionMs = safePositionMs)
                } else {
                    resolveTimelineSeekPoint(globalPositionMs = safePositionMs)
                }
            val seekPoint = rawSeekPoint
            activeTimelineSegmentIndex = seekPoint.segmentIndex
            activeTimelineRunIndex = seekPoint.itemIndex
            if (isSingleSourceTimelineMode()) {
                applyPlaybackRateForSegmentIndex(seekPoint.segmentIndex)
                player.seekTo(seekPoint.sourcePositionMs)
            } else {
                applyPlaybackRateForSegmentIndex(seekPoint.segmentIndex)
                player.seekTo(seekPoint.itemIndex, seekPoint.itemPositionMs)
            }
        } else {
            player.seekTo(safePositionMs)
        }
    }

    private fun safeDisplayableEndPosition(durationMs: Long): Long =
        if (durationMs <= 0L) {
            0L
        } else {
            (durationMs - DISPLAYABLE_END_EPSILON_MS).coerceAtLeast(0L)
        }

    private fun resetTimelineProjectionForStructuralCommit() {
        exoPlayer?.let { exo ->
            exo.pause()
            exo.playWhenReady = false
            exo.setPlaybackSpeed(1.0f)
            exo.setSeekParameters(SeekParameters.EXACT)
            exo.stop()
            exo.clearMediaItems()
        }
        compositionPlayer?.let { currentPlayer ->
            currentPlayer.pause()
            currentPlayer.stop()
        }
        singleSourceTimelineUri = null
        activeTimelineRunIndex = 0
        activeTimelineSegmentIndex = 0
        timelinePlaybackBackend = TimelinePlaybackBackend.NONE
        videoWidth = 0
        videoHeight = 0
        lastAppliedPlaybackRate = null
    }

    private fun maybeFinishScrubSettle() {
        if (!isScrubSettling) {
            return
        }
        val targetPositionMs = scrubSettleTargetPositionMs ?: return
        val activePlayer = activePlayer ?: exoPlayer ?: compositionPlayer ?: return
        val playbackState = activePlayer.playbackState
        if (playbackState == Player.STATE_IDLE) {
            return
        }
        val settledPositionMs = currentTimelinePositionMs()
        if (kotlin.math.abs(settledPositionMs - targetPositionMs) > SCRUB_SETTLE_TOLERANCE_MS &&
            playbackState != Player.STATE_ENDED
        ) {
            return
        }
        scrubSettlePositionSatisfied = true
        if (playbackState == Player.STATE_ENDED) {
            scrubSettleRenderedFirstFrameSeen = true
        }
        if (!scrubSettleRenderedFirstFrameSeen) {
            return
        }
        finishScrubSettle(forcePositionUpdate = false)
    }

    private fun finishScrubSettle(forcePositionUpdate: Boolean) {
        val hadPendingSettle = isScrubSettling || scrubSettleTargetPositionMs != null
        mainHandler.removeCallbacks(scrubSettleWatchdog)
        isScrubSettling = false
        scrubSettleTargetPositionMs = null
        scrubSettlePositionSatisfied = false
        scrubSettleRenderedFirstFrameSeen = false
        scrubSettleWatchdogAttempts = 0
        emitScrubSettlingState()
        if (forcePositionUpdate && hadPendingSettle) {
            emitState()
        }
    }

    private fun sourceOffsetForTimelineOffset(
        segment: TimelineSegment,
        timelineOffsetMs: Long,
    ): Long {
        val clampedTimelineOffset = timelineOffsetMs.coerceIn(0L, segment.timelineDurationMs)
        if (segment.timelineDurationMs <= 0L || segment.sourceDurationMs <= 0L) {
            return 0L
        }
        if (clampedTimelineOffset >= segment.timelineDurationMs) {
            return segment.sourceDurationMs
        }
        return ((clampedTimelineOffset.toDouble() / segment.timelineDurationMs.toDouble()) *
            segment.sourceDurationMs.toDouble())
            .roundToLong()
            .coerceIn(0L, segment.sourceDurationMs)
    }

    private fun timelineOffsetForSourceOffset(
        segment: TimelineSegment,
        sourceOffsetMs: Long,
    ): Long {
        val clampedSourceOffset = sourceOffsetMs.coerceIn(0L, segment.sourceDurationMs)
        if (segment.timelineDurationMs <= 0L || segment.sourceDurationMs <= 0L) {
            return 0L
        }
        if (clampedSourceOffset >= segment.sourceDurationMs) {
            return segment.timelineDurationMs
        }
        return ((clampedSourceOffset.toDouble() / segment.sourceDurationMs.toDouble()) *
            segment.timelineDurationMs.toDouble())
            .roundToLong()
            .coerceIn(0L, segment.timelineDurationMs)
    }

    private fun applyPlaybackRateForSegmentIndex(segmentIndex: Int) {
        val rate =
            timelineSegments
                .getOrNull(segmentIndex)
                ?.playbackRate
                ?.toFloat()
                ?.coerceAtLeast(0.01f) ?: 1.0f
        runCatching {
            if (lastAppliedPlaybackRate != rate) {
                lastAppliedPlaybackRate = rate
                activePlayer?.setPlaybackParameters(PlaybackParameters(rate, rate))
            }
        }
    }

    private fun currentTimelinePositionMs(): Long {
        val activePlayer = activePlayer ?: exoPlayer ?: compositionPlayer ?: return 0L
        if (timelineSegments.isEmpty()) {
            return activePlayer.currentPosition.coerceAtLeast(0L)
        }
        if (isCompositionTimelineMode()) {
            val positionMs = activePlayer.currentPosition.coerceIn(0L, timelineDurationMs)
            activeTimelineSegmentIndex =
                resolveTimelineSeekPoint(globalPositionMs = positionMs).segmentIndex
            return positionMs
        }
        if (isSingleSourceTimelineMode()) {
            val currentIndex =
                activeTimelineSegmentIndex.coerceIn(0, timelineSegments.lastIndex)
            val offsetMs = timelineSegmentOffsetsMs.getOrElse(currentIndex) { 0L }
            val activeSegment = timelineSegments[currentIndex]
            val sourceOffset =
                (activePlayer.currentPosition - activeSegment.startMs)
                    .coerceIn(0L, activeSegment.sourceDurationMs)
            val segmentOffset = timelineOffsetForSourceOffset(activeSegment, sourceOffset)
            return (offsetMs + segmentOffset).coerceIn(0L, timelineDurationMs)
        }
        if (isRunTimelineMode()) {
            val currentRunIndex =
                (exoPlayer?.currentMediaItemIndex ?: activeTimelineRunIndex)
                    .coerceIn(0, timelineRuns.lastIndex)
            val run = timelineRuns[currentRunIndex]
            val sourcePositionMs =
                (run.windowStartMs + activePlayer.currentPosition)
                    .coerceIn(run.windowStartMs, run.windowEndMs)
            val segmentIndex =
                resolveSegmentIndexForRunSourcePosition(
                    sourcePositionMs = sourcePositionMs,
                    runIndex = currentRunIndex,
                    preferredSegmentIndex = activeTimelineSegmentIndex,
                )
            activeTimelineRunIndex = currentRunIndex
            activeTimelineSegmentIndex = segmentIndex
            val offsetMs = timelineSegmentOffsetsMs.getOrElse(segmentIndex) {
                run.startTimelineOffsetMs
            }
            val activeSegment = timelineSegments[segmentIndex]
            val sourceOffset =
                (sourcePositionMs - activeSegment.startMs)
                    .coerceIn(0L, activeSegment.sourceDurationMs)
            val segmentOffset = timelineOffsetForSourceOffset(activeSegment, sourceOffset)
            return (offsetMs + segmentOffset).coerceIn(0L, timelineDurationMs)
        }
        val currentIndex =
            activePlayer.currentMediaItemIndex.coerceIn(0, timelineSegments.lastIndex)
        val offsetMs = timelineSegmentOffsetsMs.getOrElse(currentIndex) { 0L }
        return (offsetMs + activePlayer.currentPosition.coerceAtLeast(0L))
            .coerceIn(0L, timelineDurationMs)
    }

    private fun resolveTimelineSeekPoint(globalPositionMs: Long): TimelineSeekPoint {
        if (timelineSegments.isEmpty()) {
            val safePositionMs = globalPositionMs.coerceAtLeast(0L)
            return TimelineSeekPoint(
                segmentIndex = 0,
                itemIndex = 0,
                itemPositionMs = safePositionMs,
                sourcePositionMs = safePositionMs,
            )
        }
        val clampedPosition = globalPositionMs.coerceIn(0L, timelineDurationMs)
        val index = findSegmentIndexForTimelinePosition(clampedPosition)
        val segment = timelineSegments[index]
        val accumulatedMs = timelineSegmentOffsetsMs.getOrElse(index) { 0L }
        val maxItemPositionMs =
            if (index == timelineSegments.lastIndex) {
                safeDisplayableEndPosition(segment.sourceDurationMs)
            } else {
                segment.sourceDurationMs
            }
        val segmentTimelineOffset = (clampedPosition - accumulatedMs)
            .coerceIn(0L, segment.timelineDurationMs)
        val sourceOffsetMs = sourceOffsetForTimelineOffset(segment, segmentTimelineOffset)
        val itemPositionMs = sourceOffsetMs
            .coerceIn(0L, maxItemPositionMs)
        return TimelineSeekPoint(
            segmentIndex = index,
            itemIndex = index,
            itemPositionMs = itemPositionMs,
            sourcePositionMs = (segment.startMs + sourceOffsetMs)
                .coerceIn(
                    segment.startMs,
                    safeDisplayableEndPosition(segment.endMs).coerceAtLeast(segment.startMs),
                ),
        )
    }

    private fun prepareSingleSourceTimeline(
        sourceUri: Uri,
        startPositionMs: Long,
    ): Map<String, Any?> {
        val exo = ensurePlayer()
        activatePlayer(exo)
        exo.setPreloadConfiguration(ExoPlayer.PreloadConfiguration.DEFAULT)
        singleSourceTimelineUri = sourceUri
        timelineRuns = emptyList()
        timelinePlaybackBackend = TimelinePlaybackBackend.SINGLE_SOURCE_EXO
        val seekPoint = resolveTimelineSeekPoint(globalPositionMs = startPositionMs)
        activeTimelineRunIndex = 0
        activeTimelineSegmentIndex = seekPoint.segmentIndex
        exo.setMediaItem(MediaItem.fromUri(sourceUri), seekPoint.sourcePositionMs)
        applyPlaybackRateForSegmentIndex(seekPoint.segmentIndex)
        videoWidth = 0
        videoHeight = 0
        compositionPlayer?.pause()
        compositionPlayer?.stop()
        exo.prepare()
        emitPreviewRetentionPolicy()

        emitState()
        return buildState()
    }

    private fun prepareCompositionTimeline(startPositionMs: Long): Map<String, Any?> {
        val compositionPlayer = ensureCompositionPlayer()
        val exo = ensurePlayer()
        activatePlayer(compositionPlayer)
        exo.pause()
        exo.clearMediaItems()
        timelinePlaybackBackend = TimelinePlaybackBackend.COMPOSITION
        val seekPoint = resolveTimelineSeekPoint(globalPositionMs = startPositionMs)
        activeTimelineRunIndex = 0
        activeTimelineSegmentIndex = seekPoint.segmentIndex
        val sequence =
            EditedMediaItemSequence.Builder(setOf(C.TRACK_TYPE_AUDIO, C.TRACK_TYPE_VIDEO))
                .apply {
                    timelineSegments.forEach { segment ->
                        val mediaItem =
                            MediaItem.Builder()
                                .setUri(segment.sourceUri)
                                .setMediaId(segment.clipId)
                                .setMediaMetadata(
                                    MediaMetadata.Builder().setTitle(segment.sourceLabel).build(),
                                ).apply {
                                    if (!segment.isFullSource) {
                                        setClippingConfiguration(
                                            MediaItem.ClippingConfiguration.Builder()
                                                .setStartPositionMs(segment.startMs)
                                                .setEndPositionMs(segment.endMs)
                                                .build(),
                                        )
                                    }
                                }.build()
                        addItem(
                            EditedMediaItem.Builder(mediaItem)
                                .setDurationUs(segment.timelineDurationMs * 1_000L)
                                .build(),
                        )
                    }
                }.build()
        val composition = Composition.Builder(sequence).build()
        videoWidth = 0
        videoHeight = 0
        compositionPlayer.setComposition(composition, startPositionMs)
        compositionPlayer.prepare()
        emitPreviewRetentionPolicy()
        return buildState()
    }

    private fun prepareRunTimeline(startPositionMs: Long): Map<String, Any?> {
        val exo = ensurePlayer()
        activatePlayer(exo)
        exo.setPreloadConfiguration(
            if (timelineSegments.size > 1) {
                ExoPlayer.PreloadConfiguration(MULTI_ITEM_PRELOAD_DURATION_US)
            } else {
                ExoPlayer.PreloadConfiguration.DEFAULT
            },
        )
        timelinePlaybackBackend = TimelinePlaybackBackend.RUNS_EXO
        val mediaItems = buildTimelineRunMediaItems(timelineRuns)
        val seekPoint = resolveTimelineRunSeekPoint(startPositionMs)
        activeTimelineRunIndex = seekPoint.itemIndex
        activeTimelineSegmentIndex = seekPoint.segmentIndex
        compositionPlayer?.pause()
        compositionPlayer?.stop()
        exo.setMediaItems(mediaItems, seekPoint.itemIndex, seekPoint.itemPositionMs)
        applyPlaybackRateForSegmentIndex(seekPoint.segmentIndex)
        exo.prepare()
        emitPreviewRetentionPolicy()
        return buildState()
    }

    private fun buildTimelineMediaItems(segments: List<TimelineSegment>): List<MediaItem> =
        segments.map { segment ->
            MediaItem.Builder()
                .setUri(segment.sourceUri)
                .setMediaId(segment.clipId)
                .setMediaMetadata(
                    MediaMetadata.Builder().setTitle(segment.sourceLabel).build(),
                ).apply {
                    if (!segment.isFullSource) {
                        setClippingConfiguration(
                            MediaItem.ClippingConfiguration.Builder()
                                .setStartPositionMs(segment.startMs)
                                .setEndPositionMs(segment.endMs)
                                .build(),
                        )
                    }
                }.build()
        }

    private fun buildTimelineRunMediaItems(runs: List<TimelineRun>): List<MediaItem> =
        runs.mapIndexed { index, run ->
            val runSegments = run.segments
            val isSingleFullSource = runSegments.size == 1 && runSegments.first().isFullSource
            MediaItem.Builder()
                .setUri(run.sourceUri)
                .setMediaId("run-${index}-${runSegments.first().clipId}")
                .setMediaMetadata(
                    MediaMetadata.Builder().setTitle(run.sourceLabel).build(),
                ).apply {
                    if (!isSingleFullSource) {
                        setClippingConfiguration(
                            MediaItem.ClippingConfiguration.Builder()
                                .setStartPositionMs(run.windowStartMs)
                                .setEndPositionMs(run.windowEndMs)
                                .build(),
                        )
                    }
                }.build()
        }

    private fun buildTimelineRuns(segments: List<TimelineSegment>): List<TimelineRun> {
        if (segments.isEmpty()) {
            return emptyList()
        }
        val runs = mutableListOf<TimelineRun>()
        var startTimelineOffsetMs = 0L
        var index = 0
        while (index < segments.size) {
            val firstSegment = segments[index]
            val runSegments = mutableListOf<TimelineSegment>()
            runSegments.add(firstSegment)
            var lastIndex = index
            while (
                lastIndex + 1 < segments.size &&
                    classifyBoundary(
                        left = segments[lastIndex],
                        right = segments[lastIndex + 1],
                    ) == TimelineBoundaryType.SAME_SOURCE_CONTIGUOUS
            ) {
                lastIndex += 1
                runSegments.add(segments[lastIndex])
            }
            val run =
                TimelineRun(
                    sourceUri = firstSegment.sourceUri,
                    sourceLabel = firstSegment.sourceLabel,
                    startSegmentIndex = index,
                    segments = runSegments.toList(),
                    startTimelineOffsetMs = startTimelineOffsetMs,
                    windowStartMs = runSegments.first().startMs,
                    windowEndMs = runSegments.last().endMs,
                )
            runs.add(run)
            startTimelineOffsetMs += run.durationMs
            index = lastIndex + 1
        }
        return runs
    }

    private fun areSourceAdjacent(
        previousEndMs: Long,
        nextStartMs: Long,
    ): Boolean = kotlin.math.abs(nextStartMs - previousEndMs) <= SOURCE_CONTIGUITY_TOLERANCE_MS

    private fun classifyBoundary(
        left: TimelineSegment,
        right: TimelineSegment,
    ): TimelineBoundaryType {
        if (left.sourceUri != right.sourceUri) {
            return TimelineBoundaryType.CROSS_SOURCE
        }
        if (areSourceAdjacent(previousEndMs = left.endMs, nextStartMs = right.startMs)) {
            return TimelineBoundaryType.SAME_SOURCE_CONTIGUOUS
        }
        return TimelineBoundaryType.SAME_SOURCE_GAPPED
    }

    private fun sharedTimelineSourceUri(segments: List<TimelineSegment>): Uri? {
        val firstUri = segments.firstOrNull()?.sourceUri ?: return null
        for (index in 0 until segments.lastIndex) {
            val left = segments[index]
            val right = segments[index + 1]
            if (left.sourceUri != firstUri) {
                return null
            }
            if (right.startMs < left.endMs) {
                return null
            }
            if (classifyBoundary(left = left, right = right) != TimelineBoundaryType.SAME_SOURCE_CONTIGUOUS) {
                return null
            }
        }
        if (segments.last().sourceUri != firstUri) {
            return null
        }
        return firstUri
    }

    private fun isSingleSourceTimelineMode(): Boolean =
        currentSourceKind == "timeline" &&
            timelinePlaybackBackend == TimelinePlaybackBackend.SINGLE_SOURCE_EXO &&
            singleSourceTimelineUri != null &&
            timelineSegments.isNotEmpty()

    private fun isRunTimelineMode(): Boolean =
        currentSourceKind == "timeline" &&
            timelinePlaybackBackend == TimelinePlaybackBackend.RUNS_EXO &&
            timelineRuns.isNotEmpty()

    private fun isCompositionTimelineMode(): Boolean =
        currentSourceKind == "timeline" &&
            timelinePlaybackBackend == TimelinePlaybackBackend.COMPOSITION &&
            timelineSegments.isNotEmpty()

    private fun activatePlayer(nextPlayer: Player) {
        val previousPlayer = activePlayer
        if (previousPlayer === nextPlayer) {
            return
        }
        previousPlayer?.pause()
        activePlayer = nextPlayer
        playerObservers.forEach { observer -> observer(nextPlayer) }
    }

    private fun shouldRetainPreviewContentOnReset(): Boolean = isScrubSettling

    private fun emitPreviewRetentionPolicy() {
        val shouldRetain = shouldRetainPreviewContentOnReset()
        previewRetentionObservers.forEach { observer -> observer(shouldRetain) }
    }

    private fun emitPreviewOutputSuppressionState() {
        previewOutputSuppressionObservers.forEach { observer ->
            observer(isPreviewOutputSuppressed)
        }
    }

    private fun emitScrubSettlingState() {
        scrubSettlingObservers.forEach { observer ->
            observer(isScrubSettling)
        }
    }

    private fun canUseCompositionTimelinePreview(segments: List<TimelineSegment>): Boolean {
        if (segments.any { kotlin.math.abs(it.playbackRate - 1.0) > 0.001 }) {
            return false
        }
        val uniqueSourceUris = segments.map { it.sourceUri }.distinct()
        val signatures = uniqueSourceUris.map { sourceUri -> resolveAudioSignature(sourceUri) }
        val firstSignature = signatures.firstOrNull() ?: return false
        return signatures.all { it == firstSignature }
    }

    private fun resolveAudioSignature(sourceUri: Uri): AudioSignature? {
        val cacheKey = sourceUri.toString()
        if (audioSignatureCache.containsKey(cacheKey)) {
            return audioSignatureCache[cacheKey]
        }
        val signature =
            runCatching {
                val extractor = MediaExtractor()
                try {
                    extractor.setDataSource(appContext, sourceUri, emptyMap())
                    var resolvedSignature: AudioSignature? = null
                    for (trackIndex in 0 until extractor.trackCount) {
                        val format = extractor.getTrackFormat(trackIndex)
                        val mimeType = format.getString(MediaFormat.KEY_MIME) ?: continue
                        if (!mimeType.startsWith("audio/")) {
                            continue
                        }
                        resolvedSignature =
                            AudioSignature(
                            mimeType = mimeType,
                            sampleRate =
                                if (format.containsKey(MediaFormat.KEY_SAMPLE_RATE)) {
                                    format.getInteger(MediaFormat.KEY_SAMPLE_RATE)
                                } else {
                                    null
                                },
                            channelCount =
                                if (format.containsKey(MediaFormat.KEY_CHANNEL_COUNT)) {
                                    format.getInteger(MediaFormat.KEY_CHANNEL_COUNT)
                                } else {
                                    null
                                },
                            codecString =
                                if (format.containsKey(MediaFormat.KEY_CODECS_STRING)) {
                                    format.getString(MediaFormat.KEY_CODECS_STRING)
                                } else {
                                    null
                                },
                        )
                        break
                    }
                    resolvedSignature
                } finally {
                    extractor.release()
                }
            }.getOrNull()
        audioSignatureCache[cacheKey] = signature
        return signature
    }

    private fun updateTimelinePlaybackWindow() {
        if (isCompositionTimelineMode()) {
            val positionMs = (activePlayer ?: compositionPlayer)?.currentPosition?.coerceAtLeast(0L) ?: 0L
            if (timelineSegments.isNotEmpty()) {
                activeTimelineSegmentIndex =
                    resolveTimelineSeekPoint(
                        globalPositionMs = positionMs.coerceIn(0L, timelineDurationMs),
                    ).segmentIndex
            }
            return
        }
        if (isRunTimelineMode()) {
            updateRunTimelinePlaybackWindow()
            return
        }
        if (!isSingleSourceTimelineMode()) {
            return
        }
        val activePlayer = exoPlayer ?: return
        if (timelineSegments.isEmpty()) {
            return
        }

        var currentIndex = activeTimelineSegmentIndex.coerceIn(0, timelineSegments.lastIndex)
        val sourcePositionMs = activePlayer.currentPosition.coerceAtLeast(0L)
        var activeSegment = timelineSegments[currentIndex]

        if (sourcePositionMs < activeSegment.startMs || sourcePositionMs >= activeSegment.endMs) {
            currentIndex = resolveSegmentIndexForSourcePosition(sourcePositionMs, currentIndex)
            activeTimelineSegmentIndex = currentIndex
            activeSegment = timelineSegments[currentIndex]
        }

        if (sourcePositionMs < activeSegment.endMs) {
            applyPlaybackRateForSegmentIndex(currentIndex)
            return
        }

        val nextIndex = currentIndex + 1
        if (nextIndex > timelineSegments.lastIndex) {
            val safeEndPositionMs = safeDisplayableEndPosition(activeSegment.endMs)
            if (activePlayer.currentPosition != safeEndPositionMs) {
                activePlayer.seekTo(safeEndPositionMs)
            }
            if (activePlayer.playWhenReady || activePlayer.isPlaying) {
                activePlayer.pause()
            }
            lastRequestedPositionMs = timelineDurationMs
            return
        }

        activeTimelineSegmentIndex = nextIndex
        applyPlaybackRateForSegmentIndex(nextIndex)
        val nextStartMs = timelineSegments[nextIndex].startMs
        if (activePlayer.currentPosition != nextStartMs) {
            activePlayer.seekTo(nextStartMs)
        }
    }

    private fun updateRunTimelinePlaybackWindow() {
        val activePlayer = exoPlayer ?: return
        if (timelineRuns.isEmpty() || timelineSegments.isEmpty()) {
            return
        }

        val runIndex = activePlayer.currentMediaItemIndex.coerceIn(0, timelineRuns.lastIndex)
        val run = timelineRuns[runIndex]
        val sourcePositionMs =
            (run.windowStartMs + activePlayer.currentPosition)
                .coerceIn(run.windowStartMs, run.windowEndMs)
        val segmentIndex =
            resolveSegmentIndexForRunSourcePosition(
                sourcePositionMs = sourcePositionMs,
                runIndex = runIndex,
                preferredSegmentIndex = activeTimelineSegmentIndex,
            )
        activeTimelineRunIndex = runIndex
        activeTimelineSegmentIndex = segmentIndex
        val activeSegment = timelineSegments[segmentIndex]

        if (sourcePositionMs < activeSegment.endMs) {
            applyPlaybackRateForSegmentIndex(segmentIndex)
            return
        }

        val nextSegmentIndex = segmentIndex + 1
        if (nextSegmentIndex > run.endSegmentIndexInclusive) {
            val safeFinalItemPositionMs =
                safeDisplayableEndPosition(
                    (run.windowEndMs - run.windowStartMs).coerceAtLeast(0L),
                )
            if (activePlayer.currentPosition != safeFinalItemPositionMs) {
                activePlayer.seekTo(runIndex, safeFinalItemPositionMs)
            }
            if (activePlayer.playWhenReady || activePlayer.isPlaying) {
                activePlayer.pause()
            }
            lastRequestedPositionMs = timelineDurationMs
            return
        }

        val nextSegment = timelineSegments[nextSegmentIndex]
        activeTimelineSegmentIndex = nextSegmentIndex
        applyPlaybackRateForSegmentIndex(nextSegmentIndex)
        if (nextSegment.startMs <= activeSegment.endMs) {
            return
        }

        val nextItemPositionMs =
            (nextSegment.startMs - run.windowStartMs)
                .coerceIn(0L, (run.windowEndMs - run.windowStartMs).coerceAtLeast(0L))
        if (activePlayer.currentPosition != nextItemPositionMs) {
            activePlayer.seekTo(runIndex, nextItemPositionMs)
        }
    }

    private fun resolveTimelineRunSeekPoint(globalPositionMs: Long): TimelineSeekPoint {
        if (timelineRuns.isEmpty()) {
            return resolveTimelineSeekPoint(globalPositionMs = globalPositionMs)
        }
        val clampedPosition = globalPositionMs.coerceIn(0L, timelineDurationMs)
        val segmentIndex = findSegmentIndexForTimelinePosition(clampedPosition)
        val runIndex = findRunIndexForTimelinePosition(clampedPosition)
        val run = timelineRuns[runIndex]
        val segment = timelineSegments[segmentIndex]
        val accumulatedMs = timelineSegmentOffsetsMs.getOrElse(segmentIndex) {
            run.startTimelineOffsetMs
        }
        val maxItemPositionMs =
            if (segmentIndex == run.endSegmentIndexInclusive) {
                safeDisplayableEndPosition(run.windowEndMs - run.windowStartMs)
            } else {
                (segment.startMs - run.windowStartMs + segment.sourceDurationMs)
                    .coerceAtLeast(0L)
            }
        val segmentTimelineOffset =
            (clampedPosition - accumulatedMs).coerceIn(0L, segment.timelineDurationMs)
        val sourceOffsetMs = sourceOffsetForTimelineOffset(segment, segmentTimelineOffset)
        val itemPositionMs =
            (segment.startMs - run.windowStartMs + sourceOffsetMs)
                .coerceIn(0L, maxItemPositionMs)
        return TimelineSeekPoint(
            segmentIndex = segmentIndex,
            itemIndex = runIndex,
            itemPositionMs = itemPositionMs,
            sourcePositionMs = (run.windowStartMs + itemPositionMs)
                .coerceIn(
                    run.windowStartMs,
                    safeDisplayableEndPosition(run.windowEndMs).coerceAtLeast(run.windowStartMs),
                ),
        )
    }

    private fun resolveSegmentIndexForRunSourcePosition(
        sourcePositionMs: Long,
        runIndex: Int,
        preferredSegmentIndex: Int,
    ): Int {
        if (timelineRuns.isEmpty() || timelineSegments.isEmpty()) {
            return 0
        }
        val run = timelineRuns[runIndex.coerceIn(0, timelineRuns.lastIndex)]
        if (sourcePositionMs >= run.windowEndMs) {
            return run.endSegmentIndexInclusive
        }
        if (sourcePositionMs <= run.windowStartMs) {
            return run.startSegmentIndex
        }
        val clampedPreferred =
            preferredSegmentIndex.coerceIn(run.startSegmentIndex, run.endSegmentIndexInclusive)
        val preferredSegment = timelineSegments[clampedPreferred]
        if (
            sourcePositionMs >= preferredSegment.startMs &&
                sourcePositionMs < preferredSegment.endMs
        ) {
            return clampedPreferred
        }
        for (index in clampedPreferred + 1..run.endSegmentIndexInclusive) {
            val segment = timelineSegments[index]
            if (sourcePositionMs >= segment.startMs && sourcePositionMs < segment.endMs) {
                return index
            }
        }
        for (index in run.startSegmentIndex until clampedPreferred) {
            val segment = timelineSegments[index]
            if (sourcePositionMs >= segment.startMs && sourcePositionMs < segment.endMs) {
                return index
            }
        }
        return clampedPreferred
    }

    private fun buildTimelineSegmentOffsets(segments: List<TimelineSegment>): LongArray {
        val offsets = LongArray(segments.size)
        var accumulatedMs = 0L
        for (index in segments.indices) {
            offsets[index] = accumulatedMs
            accumulatedMs += segments[index].timelineDurationMs
        }
        return offsets
    }

    private fun buildTimelineRunEndOffsets(runs: List<TimelineRun>): LongArray =
        LongArray(runs.size) { index -> runs[index].startTimelineOffsetMs + runs[index].durationMs }

    private fun findSegmentIndexForTimelinePosition(positionMs: Long): Int {
        if (timelineSegments.isEmpty()) {
            return 0
        }
        val clampedPosition = positionMs.coerceIn(0L, timelineDurationMs)
        var low = 0
        var high = timelineSegments.lastIndex
        while (low <= high) {
            val mid = (low + high).ushr(1)
            val startMs = timelineSegmentOffsetsMs.getOrElse(mid) { 0L }
            val endMs =
                if (mid == timelineSegments.lastIndex) {
                    timelineDurationMs
                } else {
                    timelineSegmentOffsetsMs[mid + 1]
                }
            if (clampedPosition < startMs) {
                high = mid - 1
            } else if (clampedPosition >= endMs) {
                low = mid + 1
            } else {
                return mid
            }
        }
        return low.coerceIn(0, timelineSegments.lastIndex)
    }

    private fun findRunIndexForTimelinePosition(positionMs: Long): Int {
        if (timelineRuns.isEmpty()) {
            return 0
        }
        val clampedPosition = positionMs.coerceIn(0L, timelineDurationMs)
        var low = 0
        var high = timelineRuns.lastIndex
        while (low <= high) {
            val mid = (low + high).ushr(1)
            val startMs = timelineRuns[mid].startTimelineOffsetMs
            val endMs = timelineRunEndOffsetsMs.getOrElse(mid) { timelineDurationMs }
            if (clampedPosition < startMs) {
                high = mid - 1
            } else if (clampedPosition >= endMs) {
                low = mid + 1
            } else {
                return mid
            }
        }
        return low.coerceIn(0, timelineRuns.lastIndex)
    }

    private fun resolveSegmentIndexForSourcePosition(
        sourcePositionMs: Long,
        preferredIndex: Int,
    ): Int {
        if (timelineSegments.isEmpty()) {
            return 0
        }
        val clampedPreferred = preferredIndex.coerceIn(0, timelineSegments.lastIndex)
        val preferredSegment = timelineSegments[clampedPreferred]
        if (sourcePositionMs >= preferredSegment.startMs && sourcePositionMs < preferredSegment.endMs) {
            return clampedPreferred
        }
        for (index in clampedPreferred + 1 until timelineSegments.size) {
            val segment = timelineSegments[index]
            if (sourcePositionMs >= segment.startMs && sourcePositionMs < segment.endMs) {
                return index
            }
        }
        for (index in 0 until clampedPreferred) {
            val segment = timelineSegments[index]
            if (sourcePositionMs >= segment.startMs && sourcePositionMs < segment.endMs) {
                return index
            }
        }
        return clampedPreferred
    }
}
