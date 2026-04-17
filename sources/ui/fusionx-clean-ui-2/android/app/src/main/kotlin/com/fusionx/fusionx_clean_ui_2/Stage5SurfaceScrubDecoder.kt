package com.refusion.app

import android.content.Context
import android.media.MediaCodec
import android.media.MediaExtractor
import android.media.MediaFormat
import android.net.Uri
import android.os.Build
import android.view.Surface
import kotlin.math.abs

class Stage5SurfaceScrubDecoder(
    private val appContext: Context,
) {
    companion object {
        private const val IO_TIMEOUT_US = 2_000L
        private const val SAME_FRAME_EPSILON_US = 16_000L
        private const val SEEK_BACKWARD_TOLERANCE_US = 33_000L
        private const val MAX_CONTINUOUS_DECODE_AHEAD_US = 1_500_000L
    }

    private var extractor: MediaExtractor? = null
    private var codec: MediaCodec? = null
    private var configuredPlaybackUri: String? = null
    private var configuredSurface: Surface? = null
    private var selectedTrackIndex: Int = -1
    private var decoderPrimed = false
    private var inputEnded = false
    private var lastRenderedPresentationUs = Long.MIN_VALUE
    private var lastQueuedSampleTimeUs = Long.MIN_VALUE
    private var lastSeekTargetUs = Long.MIN_VALUE

    @Synchronized
    fun ensureConfigured(
        playbackUri: String,
        outputSurface: Surface,
    ): Boolean {
        if (!outputSurface.isValid) {
            return false
        }
        val currentCodec = codec
        if (currentCodec != null && configuredPlaybackUri == playbackUri) {
            if (configuredSurface !== outputSurface && Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                currentCodec.setOutputSurface(outputSurface)
            }
            configuredSurface = outputSurface
            return true
        }
        releaseDecoder()
        val newExtractor = MediaExtractor()
        applyExtractorDataSource(newExtractor, playbackUri)
        val trackIndex = selectVideoTrack(newExtractor)
        if (trackIndex < 0) {
            newExtractor.release()
            return false
        }
        newExtractor.selectTrack(trackIndex)
        val format = newExtractor.getTrackFormat(trackIndex)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            runCatching {
                format.setInteger(MediaFormat.KEY_LOW_LATENCY, 1)
            }
        }
        val mimeType = format.getString(MediaFormat.KEY_MIME) ?: run {
            newExtractor.release()
            return false
        }
        val newCodec = MediaCodec.createDecoderByType(mimeType)
        return try {
            newCodec.configure(format, outputSurface, null, 0)
            newCodec.start()
            extractor = newExtractor
            codec = newCodec
            configuredPlaybackUri = playbackUri
            configuredSurface = outputSurface
            selectedTrackIndex = trackIndex
            resetDecoderState()
            true
        } catch (error: Throwable) {
            runCatching { newCodec.stop() }
            newCodec.release()
            newExtractor.release()
            false
        }
    }

    @Synchronized
    fun renderToPosition(
        positionMs: Long,
        shouldContinue: () -> Boolean,
    ): Boolean {
        val currentExtractor = extractor ?: return false
        val currentCodec = codec ?: return false
        val targetUs = positionMs.coerceAtLeast(0L) * 1_000L

        if (shouldSeekToTarget(targetUs)) {
            if (!seekToTarget(targetUs)) {
                return false
            }
        } else if (
            lastRenderedPresentationUs != Long.MIN_VALUE &&
            abs(lastRenderedPresentationUs - targetUs) <= SAME_FRAME_EPSILON_US
        ) {
            return true
        }

        val bufferInfo = MediaCodec.BufferInfo()
        var pendingOutputBufferIndex = -1
        var pendingPresentationTimeUs = Long.MIN_VALUE
        var renderedFrame = false

        try {
            while (shouldContinue()) {
                if (!inputEnded) {
                    queueNextInputSample(currentExtractor, currentCodec)
                }

                when (val outputBufferIndex = currentCodec.dequeueOutputBuffer(bufferInfo, IO_TIMEOUT_US)) {
                    MediaCodec.INFO_TRY_AGAIN_LATER -> {
                        if (inputEnded) {
                            if (pendingOutputBufferIndex >= 0) {
                                currentCodec.releaseOutputBuffer(pendingOutputBufferIndex, true)
                                lastRenderedPresentationUs = pendingPresentationTimeUs
                                pendingOutputBufferIndex = -1
                                pendingPresentationTimeUs = Long.MIN_VALUE
                                return true
                            }
                            return renderedFrame || lastRenderedPresentationUs != Long.MIN_VALUE
                        }
                    }

                    MediaCodec.INFO_OUTPUT_BUFFERS_CHANGED,
                    MediaCodec.INFO_OUTPUT_FORMAT_CHANGED -> Unit

                    else -> {
                        if (outputBufferIndex < 0) {
                            continue
                        }
                        val hasRenderableContent =
                            bufferInfo.size > 0 &&
                                bufferInfo.flags and MediaCodec.BUFFER_FLAG_CODEC_CONFIG == 0
                        if (!hasRenderableContent) {
                            currentCodec.releaseOutputBuffer(outputBufferIndex, false)
                            if (bufferInfo.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0) {
                                inputEnded = true
                                if (pendingOutputBufferIndex >= 0) {
                                    currentCodec.releaseOutputBuffer(pendingOutputBufferIndex, true)
                                    lastRenderedPresentationUs = pendingPresentationTimeUs
                                    pendingOutputBufferIndex = -1
                                    pendingPresentationTimeUs = Long.MIN_VALUE
                                    return true
                                }
                                return renderedFrame || lastRenderedPresentationUs != Long.MIN_VALUE
                            }
                            continue
                        }

                        val presentationTimeUs = bufferInfo.presentationTimeUs
                        if (pendingOutputBufferIndex < 0) {
                            if (presentationTimeUs >= targetUs) {
                                currentCodec.releaseOutputBuffer(outputBufferIndex, true)
                                lastRenderedPresentationUs = presentationTimeUs
                                return true
                            }
                            pendingOutputBufferIndex = outputBufferIndex
                            pendingPresentationTimeUs = presentationTimeUs
                            renderedFrame = true
                        } else if (presentationTimeUs < targetUs) {
                            currentCodec.releaseOutputBuffer(pendingOutputBufferIndex, false)
                            pendingOutputBufferIndex = outputBufferIndex
                            pendingPresentationTimeUs = presentationTimeUs
                            renderedFrame = true
                        } else {
                            val renderPending =
                                abs(pendingPresentationTimeUs - targetUs) <=
                                    abs(presentationTimeUs - targetUs)
                            if (renderPending) {
                                currentCodec.releaseOutputBuffer(pendingOutputBufferIndex, true)
                                currentCodec.releaseOutputBuffer(outputBufferIndex, false)
                                lastRenderedPresentationUs = pendingPresentationTimeUs
                            } else {
                                currentCodec.releaseOutputBuffer(pendingOutputBufferIndex, false)
                                currentCodec.releaseOutputBuffer(outputBufferIndex, true)
                                lastRenderedPresentationUs = presentationTimeUs
                            }
                            pendingOutputBufferIndex = -1
                            pendingPresentationTimeUs = Long.MIN_VALUE
                            return true
                        }

                        if (bufferInfo.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0) {
                            inputEnded = true
                            if (pendingOutputBufferIndex >= 0) {
                                currentCodec.releaseOutputBuffer(pendingOutputBufferIndex, true)
                                lastRenderedPresentationUs = pendingPresentationTimeUs
                                pendingOutputBufferIndex = -1
                                pendingPresentationTimeUs = Long.MIN_VALUE
                                return true
                            }
                            return renderedFrame || lastRenderedPresentationUs != Long.MIN_VALUE
                        }
                    }
                }
            }
        } finally {
            if (pendingOutputBufferIndex >= 0) {
                runCatching {
                    currentCodec.releaseOutputBuffer(pendingOutputBufferIndex, false)
                }
            }
        }
        return renderedFrame
    }

    @Synchronized
    fun release() {
        releaseDecoder()
    }

    private fun shouldSeekToTarget(targetUs: Long): Boolean {
        if (!decoderPrimed) {
            return true
        }
        if (lastRenderedPresentationUs != Long.MIN_VALUE &&
            targetUs + SEEK_BACKWARD_TOLERANCE_US < lastRenderedPresentationUs
        ) {
            return true
        }
        if (inputEnded && targetUs > lastRenderedPresentationUs + SEEK_BACKWARD_TOLERANCE_US) {
            return true
        }
        if (lastRenderedPresentationUs != Long.MIN_VALUE &&
            targetUs - lastRenderedPresentationUs > MAX_CONTINUOUS_DECODE_AHEAD_US
        ) {
            return true
        }
        if (lastQueuedSampleTimeUs != Long.MIN_VALUE &&
            targetUs > lastQueuedSampleTimeUs + MAX_CONTINUOUS_DECODE_AHEAD_US
        ) {
            return true
        }
        return false
    }

    private fun seekToTarget(targetUs: Long): Boolean {
        val currentExtractor = extractor ?: return false
        val currentCodec = codec ?: return false
        return try {
            currentCodec.flush()
            currentExtractor.seekTo(targetUs, MediaExtractor.SEEK_TO_PREVIOUS_SYNC)
            resetDecoderState()
            decoderPrimed = true
            lastSeekTargetUs = targetUs
            true
        } catch (_: Throwable) {
            false
        }
    }

    private fun queueNextInputSample(
        currentExtractor: MediaExtractor,
        currentCodec: MediaCodec,
    ) {
        val inputBufferIndex = currentCodec.dequeueInputBuffer(IO_TIMEOUT_US)
        if (inputBufferIndex < 0) {
            return
        }
        val inputBuffer = currentCodec.getInputBuffer(inputBufferIndex)
        if (inputBuffer == null) {
            currentCodec.queueInputBuffer(
                inputBufferIndex,
                0,
                0,
                0L,
                MediaCodec.BUFFER_FLAG_END_OF_STREAM,
            )
            inputEnded = true
            return
        }
        val sampleSize = currentExtractor.readSampleData(inputBuffer, 0)
        if (sampleSize < 0) {
            currentCodec.queueInputBuffer(
                inputBufferIndex,
                0,
                0,
                0L,
                MediaCodec.BUFFER_FLAG_END_OF_STREAM,
            )
            inputEnded = true
            return
        }
        val sampleTimeUs = currentExtractor.sampleTime.coerceAtLeast(0L)
        currentCodec.queueInputBuffer(
            inputBufferIndex,
            0,
            sampleSize,
            sampleTimeUs,
            currentExtractor.sampleFlags,
        )
        lastQueuedSampleTimeUs = sampleTimeUs
        currentExtractor.advance()
    }

    private fun resetDecoderState() {
        decoderPrimed = false
        inputEnded = false
        lastRenderedPresentationUs = Long.MIN_VALUE
        lastQueuedSampleTimeUs = Long.MIN_VALUE
        lastSeekTargetUs = Long.MIN_VALUE
    }

    private fun releaseDecoder() {
        runCatching { codec?.stop() }
        codec?.release()
        codec = null
        extractor?.release()
        extractor = null
        configuredPlaybackUri = null
        configuredSurface = null
        selectedTrackIndex = -1
        resetDecoderState()
    }

    private fun selectVideoTrack(extractor: MediaExtractor): Int {
        for (trackIndex in 0 until extractor.trackCount) {
            val trackFormat = extractor.getTrackFormat(trackIndex)
            val mimeType = trackFormat.getString(MediaFormat.KEY_MIME) ?: continue
            if (mimeType.startsWith("video/")) {
                return trackIndex
            }
        }
        return -1
    }

    private fun applyExtractorDataSource(
        extractor: MediaExtractor,
        uriString: String,
    ) {
        val parsedUri = Uri.parse(uriString)
        if (parsedUri.scheme.isNullOrBlank()) {
            extractor.setDataSource(uriString)
        } else {
            extractor.setDataSource(appContext, parsedUri, null)
        }
    }
}
