package com.refusion.app

import android.content.Context
import android.media.MediaCodec
import android.media.MediaExtractor
import android.media.MediaFormat
import android.net.Uri
import android.os.Build
import android.view.Surface

class Stage5SurfaceScrubDecoder(
    private val appContext: Context,
) {
    private var extractor: MediaExtractor? = null
    private var codec: MediaCodec? = null
    private var configuredPlaybackUri: String? = null
    private var configuredSurface: Surface? = null
    private var selectedTrackIndex: Int = -1

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
                configuredSurface = outputSurface
            } else {
                configuredSurface = outputSurface
            }
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
            true
        } catch (error: Throwable) {
            runCatching { newCodec.stop() }
            newCodec.release()
            newExtractor.release()
            false
        }
    }

    fun renderToPosition(
        positionMs: Long,
        shouldContinue: () -> Boolean,
    ): Boolean {
        val currentExtractor = extractor ?: return false
        val currentCodec = codec ?: return false
        val targetUs = positionMs.coerceAtLeast(0L) * 1000L
        currentCodec.flush()
        currentExtractor.seekTo(targetUs, MediaExtractor.SEEK_TO_PREVIOUS_SYNC)

        var inputEnded = false
        var renderedFrame = false
        val bufferInfo = MediaCodec.BufferInfo()

        while (shouldContinue()) {
            if (!inputEnded) {
                val inputBufferIndex = currentCodec.dequeueInputBuffer(5_000L)
                if (inputBufferIndex >= 0) {
                    val inputBuffer = currentCodec.getInputBuffer(inputBufferIndex)
                    if (inputBuffer != null) {
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
                        } else {
                            currentCodec.queueInputBuffer(
                                inputBufferIndex,
                                0,
                                sampleSize,
                                currentExtractor.sampleTime,
                                currentExtractor.sampleFlags,
                            )
                            currentExtractor.advance()
                        }
                    }
                }
            }

            when (val outputBufferIndex = currentCodec.dequeueOutputBuffer(bufferInfo, 5_000L)) {
                MediaCodec.INFO_TRY_AGAIN_LATER -> {
                    if (inputEnded) {
                        return renderedFrame
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
                    currentCodec.releaseOutputBuffer(outputBufferIndex, hasRenderableContent)
                    if (hasRenderableContent) {
                        renderedFrame = true
                        if (bufferInfo.presentationTimeUs >= targetUs) {
                            return true
                        }
                    }
                    if (bufferInfo.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0) {
                        return renderedFrame
                    }
                }
            }
        }
        return renderedFrame
    }

    fun release() {
        releaseDecoder()
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
