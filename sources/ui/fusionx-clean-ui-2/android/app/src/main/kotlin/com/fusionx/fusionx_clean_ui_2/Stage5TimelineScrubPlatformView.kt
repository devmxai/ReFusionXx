package com.refusion.app

import android.content.Context
import android.view.MotionEvent
import android.view.View
import android.view.ViewConfiguration
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory
import kotlin.math.abs
import kotlin.math.roundToLong

private data class Stage5TimelineScrubSurfaceConfig(
    val currentPositionMs: Long,
    val timelineDurationMs: Long,
    val timelineOffsetMs: Long,
    val secondsWidth: Double,
    val timelineFps: Double,
    val targetWidth: Int,
    val targetHeight: Int,
    val tapEnabled: Boolean,
    val regions: List<Stage5TimelineScrubViewportRegion>,
    val previewSources: List<Stage5NativeScrubSourceDescriptor>,
)

private data class Stage5TimelineScrubViewportRegion(
    val left: Float,
    val top: Float,
    val width: Float,
    val height: Float,
) {
    fun contains(
        x: Float,
        y: Float,
    ): Boolean = x >= left && x <= left + width && y >= top && y <= top + height
}

class Stage5TimelineScrubPlatformViewFactory(
    private val binaryMessenger: BinaryMessenger,
    private val nativeScrubEngine: Stage5NativeScrubEngine,
) : PlatformViewFactory(StandardMessageCodec.INSTANCE) {
    override fun create(
        context: Context,
        viewId: Int,
        args: Any?,
    ): PlatformView {
        val arguments = (args as? Map<*, *>)?.mapKeys { (key, _) -> key.toString() } ?: emptyMap()
        return Stage5TimelineScrubPlatformView(
            context = context,
            viewId = viewId,
            binaryMessenger = binaryMessenger,
            nativeScrubEngine = nativeScrubEngine,
            initialArguments = arguments,
        )
    }
}

private class Stage5TimelineScrubInputView(
    context: Context,
    private val channel: MethodChannel,
    private val nativeScrubEngine: Stage5NativeScrubEngine,
) : View(context) {
    private val displayDensity = context.resources.displayMetrics.density.coerceAtLeast(1f)
    private val touchSlop =
        ViewConfiguration.get(context).scaledTouchSlop.toFloat() / displayDensity
    private var config =
        Stage5TimelineScrubSurfaceConfig(
            currentPositionMs = 0L,
            timelineDurationMs = 0L,
            timelineOffsetMs = 0L,
            secondsWidth = 1.0,
            timelineFps = 30.0,
            targetWidth = 480,
            targetHeight = 854,
            tapEnabled = false,
            regions = emptyList(),
            previewSources = emptyList(),
        )
    private var pointerId = MotionEvent.INVALID_POINTER_ID
    private var downX = 0f
    private var gestureStartPositionMs = 0L
    private var gesturePositionMs = 0L
    private var stableGestureFrameIndex: Long? = null
    private var stableGesturePositionMs = 0L
    private var scrubbing = false
    private var multiTouchSuppressed = false
    private var configuredPreviewSources: List<Stage5NativeScrubSourceDescriptor> = emptyList()
    private var configuredTargetWidth: Int = 0
    private var configuredTargetHeight: Int = 0

    private fun resolvePointerRawX(
        event: MotionEvent,
        pointerIndex: Int,
    ): Float {
        val rootOffsetX = event.rawX - event.getX(0)
        return rootOffsetX + event.getX(pointerIndex)
    }

    private fun toLogicalPixels(value: Float): Float = value / displayDensity

    private fun frameDurationMs(): Double {
        val fps = config.timelineFps.takeIf { it.isFinite() && it > 0.0 } ?: 30.0
        return 1000.0 / fps.coerceIn(1.0, 240.0)
    }

    private fun positionToFrameIndex(positionMs: Long): Long {
        val frameDurationMs = frameDurationMs()
        return (positionMs.toDouble() / frameDurationMs).roundToLong()
    }

    private fun frameIndexToPositionMs(frameIndex: Long): Long {
        val frameDurationMs = frameDurationMs()
        return (frameIndex.toDouble() * frameDurationMs)
            .roundToLong()
            .coerceIn(
                config.timelineOffsetMs,
                config.timelineOffsetMs + config.timelineDurationMs,
            )
    }

    private fun stabilizeGesturePositionMs(rawPositionMs: Long): Long {
        val frameDurationMs = frameDurationMs()
        if (!frameDurationMs.isFinite() || frameDurationMs <= 0.0) {
            stableGesturePositionMs = rawPositionMs
            return rawPositionMs
        }
        val previousFrame =
            stableGestureFrameIndex ?: positionToFrameIndex(stableGesturePositionMs)
        val rawFrame = rawPositionMs.toDouble() / frameDurationMs
        // A small hysteresis band prevents slow finger noise around a frame
        // boundary from alternating previous/next rendered frames.
        val shouldAdvanceFrame =
            rawFrame >= previousFrame.toDouble() + 0.62 ||
                rawFrame <= previousFrame.toDouble() - 0.62
        if (!shouldAdvanceFrame) {
            return stableGesturePositionMs
        }
        val nextFrame = rawFrame.roundToLong()
        stableGestureFrameIndex = nextFrame
        stableGesturePositionMs = frameIndexToPositionMs(nextFrame)
        return stableGesturePositionMs
    }

    private fun resolveRawGesturePositionMs(
        event: MotionEvent,
        pointerIndex: Int,
    ): Long {
        val currentX = resolvePointerRawX(event, pointerIndex)
        val logicalCurrentX = toLogicalPixels(currentX)
        val totalDx = logicalCurrentX - downX
        val secondsWidth = config.secondsWidth.coerceAtLeast(0.0001)
        val deltaMs = ((totalDx / secondsWidth) * 1000.0).roundToLong()
        return (gestureStartPositionMs - deltaMs)
            .coerceIn(
                config.timelineOffsetMs,
                config.timelineOffsetMs + config.timelineDurationMs,
            )
    }

    private fun resolveGesturePositionMs(
        event: MotionEvent,
        pointerIndex: Int,
    ): Long = stabilizeGesturePositionMs(resolveRawGesturePositionMs(event, pointerIndex))

    fun updateConfig(nextConfig: Stage5TimelineScrubSurfaceConfig) {
        val previousConfig = config
        val previousSources =
            if (configuredPreviewSources.isNotEmpty()) {
                configuredPreviewSources
            } else {
                previousConfig.previewSources
            }
        config = nextConfig
        if (!scrubbing) {
            gesturePositionMs = nextConfig.currentPositionMs
            stableGesturePositionMs = nextConfig.currentPositionMs
            stableGestureFrameIndex = positionToFrameIndex(nextConfig.currentPositionMs)
        }
        val shouldReconfigure =
            configuredPreviewSources != nextConfig.previewSources ||
                configuredTargetWidth != nextConfig.targetWidth ||
                configuredTargetHeight != nextConfig.targetHeight
        if (!shouldReconfigure) {
            if (!scrubbing && previousConfig.currentPositionMs != nextConfig.currentPositionMs) {
                val previousDescriptor =
                    resolveDescriptorForPosition(previousSources, previousConfig.currentPositionMs)
                val nextDescriptor =
                    resolveDescriptorForPosition(previousSources, nextConfig.currentPositionMs)
                if (previousDescriptor?.scrubStoreKey != nextDescriptor?.scrubStoreKey) {
                    nativeScrubEngine.primeTimelinePosition(nextConfig.currentPositionMs)
                }
            }
            return
        }
        configuredPreviewSources = nextConfig.previewSources
        configuredTargetWidth = nextConfig.targetWidth
        configuredTargetHeight = nextConfig.targetHeight
        nativeScrubEngine.configurePreviewSources(
            previewSources = nextConfig.previewSources,
            targetWidth = nextConfig.targetWidth,
            targetHeight = nextConfig.targetHeight,
            initialTimelinePositionMs = nextConfig.currentPositionMs,
        )
    }

    private fun resolveDescriptorForPosition(
        descriptors: List<Stage5NativeScrubSourceDescriptor>,
        positionMs: Long,
    ): Stage5NativeScrubSourceDescriptor? {
        if (descriptors.isEmpty()) {
            return null
        }
        return descriptors.firstOrNull { descriptor ->
            descriptor.containsPosition(positionMs)
        } ?: descriptors.lastOrNull { descriptor ->
            descriptor.timelineStartMs <= positionMs
        } ?: descriptors.firstOrNull()
    }

    private fun acceptsPoint(
        x: Float,
        y: Float,
    ): Boolean {
        if (config.regions.isEmpty()) {
            return true
        }
        return config.regions.any { region -> region.contains(x, y) }
    }

    private fun suppressGestureForMultiTouch() {
        if (scrubbing) {
            gesturePositionMs = config.currentPositionMs
            nativeScrubEngine.commitFinalTimelinePosition(gesturePositionMs)
            channel.invokeMethod(
                "scrubEnd",
                mapOf("positionMs" to gesturePositionMs),
            )
        } else {
            gesturePositionMs = config.currentPositionMs
        }
        stableGesturePositionMs = config.currentPositionMs
        stableGestureFrameIndex = positionToFrameIndex(config.currentPositionMs)
        scrubbing = false
        multiTouchSuppressed = true
        parent?.requestDisallowInterceptTouchEvent(false)
    }

    override fun onTouchEvent(event: MotionEvent): Boolean {
        when (event.actionMasked) {
            MotionEvent.ACTION_DOWN -> {
                val logicalX = toLogicalPixels(event.x)
                val logicalY = toLogicalPixels(event.y)
                if (!acceptsPoint(logicalX, logicalY)) {
                    return false
                }
                pointerId = event.getPointerId(0)
                downX = toLogicalPixels(event.rawX)
                gestureStartPositionMs = config.currentPositionMs
                gesturePositionMs = config.currentPositionMs
                stableGesturePositionMs = config.currentPositionMs
                stableGestureFrameIndex = positionToFrameIndex(config.currentPositionMs)
                scrubbing = false
                multiTouchSuppressed = false
                nativeScrubEngine.primeTimelinePosition(gesturePositionMs)
                parent?.requestDisallowInterceptTouchEvent(true)
                return true
            }

            MotionEvent.ACTION_POINTER_DOWN -> {
                suppressGestureForMultiTouch()
                return true
            }

            MotionEvent.ACTION_POINTER_UP -> {
                if (multiTouchSuppressed || event.pointerCount > 1) {
                    return true
                }
            }

            MotionEvent.ACTION_MOVE -> {
                if (multiTouchSuppressed || event.pointerCount > 1) {
                    if (!multiTouchSuppressed) {
                        suppressGestureForMultiTouch()
                    }
                    return true
                }
                val activeIndex = event.findPointerIndex(pointerId)
                if (activeIndex < 0) {
                    return false
                }
                val currentX = resolvePointerRawX(event, activeIndex)
                val logicalCurrentX = toLogicalPixels(currentX)
                val totalDx = logicalCurrentX - downX
                if (!scrubbing && abs(totalDx) < touchSlop) {
                    return true
                }
                if (!scrubbing) {
                    nativeScrubEngine.activatePrimedSession()
                    scrubbing = true
                    channel.invokeMethod(
                        "scrubStart",
                        mapOf("positionMs" to gesturePositionMs),
                    )
                }
                val nextPositionMs = resolveGesturePositionMs(event, activeIndex)
                if (nextPositionMs == gesturePositionMs) {
                    return true
                }
                gesturePositionMs = nextPositionMs
                nativeScrubEngine.scrubTimelinePosition(gesturePositionMs)
                channel.invokeMethod(
                    "scrubTimeChanged",
                    mapOf("positionMs" to gesturePositionMs),
                )
                return true
            }

            MotionEvent.ACTION_UP -> {
                if (multiTouchSuppressed) {
                    resetGesture()
                    return true
                }
                val wasScrubbing = scrubbing
                val tapped = !wasScrubbing && config.tapEnabled
                if (wasScrubbing) {
                    val activeIndex = event.findPointerIndex(pointerId)
                    if (activeIndex >= 0) {
                        gesturePositionMs = resolveGesturePositionMs(event, activeIndex)
                    }
                    nativeScrubEngine.commitFinalTimelinePosition(gesturePositionMs)
                    channel.invokeMethod(
                        "scrubEnd",
                        mapOf("positionMs" to gesturePositionMs),
                    )
                } else if (tapped) {
                    channel.invokeMethod(
                        "tap",
                        mapOf("positionMs" to config.currentPositionMs),
                    )
                }
                resetGesture()
                return true
            }

            MotionEvent.ACTION_CANCEL -> {
                if (multiTouchSuppressed) {
                    resetGesture()
                    return true
                }
                if (scrubbing) {
                    val activeIndex = event.findPointerIndex(pointerId)
                    if (activeIndex >= 0) {
                        gesturePositionMs = resolveGesturePositionMs(event, activeIndex)
                    }
                    nativeScrubEngine.commitFinalTimelinePosition(gesturePositionMs)
                    channel.invokeMethod(
                        "scrubEnd",
                        mapOf("positionMs" to gesturePositionMs),
                    )
                }
                resetGesture()
                return true
            }
        }
        return super.onTouchEvent(event)
    }

    private fun resetGesture() {
        pointerId = MotionEvent.INVALID_POINTER_ID
        downX = 0f
        gestureStartPositionMs = config.currentPositionMs
        scrubbing = false
        gesturePositionMs = config.currentPositionMs
        stableGesturePositionMs = config.currentPositionMs
        stableGestureFrameIndex = null
        multiTouchSuppressed = false
        parent?.requestDisallowInterceptTouchEvent(false)
    }
}

class Stage5TimelineScrubPlatformView(
    context: Context,
    viewId: Int,
    binaryMessenger: BinaryMessenger,
    nativeScrubEngine: Stage5NativeScrubEngine,
    initialArguments: Map<String, Any?>,
) : PlatformView, MethodChannel.MethodCallHandler {
    private val channel =
        MethodChannel(
            binaryMessenger,
            "${Stage5TransportManager.TIMELINE_SCRUB_VIEW_TYPE}/$viewId",
        )
    private val inputView =
        Stage5TimelineScrubInputView(
            context = context,
            channel = channel,
            nativeScrubEngine = nativeScrubEngine,
        )

    init {
        channel.setMethodCallHandler(this)
        inputView.updateConfig(parseConfig(initialArguments))
    }

    override fun getView(): View = inputView

    override fun dispose() {
        channel.setMethodCallHandler(null)
    }

    override fun onMethodCall(
        call: MethodCall,
        result: MethodChannel.Result,
    ) {
        when (call.method) {
            "updateConfig" -> {
                val arguments =
                    (call.arguments as? Map<*, *>)?.mapKeys { (key, _) -> key.toString() }
                        ?: emptyMap()
                inputView.updateConfig(parseConfig(arguments))
                result.success(null)
            }

            else -> result.notImplemented()
        }
    }

    private fun parseConfig(arguments: Map<String, Any?>): Stage5TimelineScrubSurfaceConfig {
        val previewSources =
            (arguments["previewSources"] as? List<*>)?.mapNotNull { entry ->
                val map = (entry as? Map<*, *>)?.mapKeys { (key, _) -> key.toString() }
                    ?: return@mapNotNull null
                val scrubStoreKey = map["scrubStoreKey"]?.toString().orEmpty()
                if (scrubStoreKey.isBlank()) {
                    return@mapNotNull null
                }
                Stage5NativeScrubSourceDescriptor(
                    clipId = map["clipId"]?.toString().orEmpty(),
                    assetId = map["assetId"]?.toString().orEmpty(),
                    scrubStoreKey = scrubStoreKey,
                    sourceUri = map["sourceUri"]?.toString().orEmpty(),
                    previewUri = map["previewUri"]?.toString(),
                    timelineStartMs = (map["timelineStartMs"] as? Number)?.toLong() ?: 0L,
                    timelineEndMs = (map["timelineEndMs"] as? Number)?.toLong() ?: 0L,
                    durationMs = (map["durationMs"] as? Number)?.toLong() ?: 0L,
                    sourceStartMs = (map["sourceStartMs"] as? Number)?.toLong() ?: 0L,
                    sourceDurationMs = (map["sourceDurationMs"] as? Number)?.toLong() ?: 0L,
                    playbackRate = (map["playbackRate"] as? Number)?.toDouble() ?: 1.0,
                    sourceWidth = (map["sourceWidth"] as? Number)?.toInt(),
                    sourceHeight = (map["sourceHeight"] as? Number)?.toInt(),
                    transformMatrix3x3 =
                        (map["transformMatrix3x3"] as? List<*>)?.mapNotNull { value ->
                            (value as? Number)?.toDouble()
                        }?.takeIf { values -> values.size == 9 }
                            ?: listOf(1.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0),
                    opacity = (map["opacity"] as? Number)?.toDouble() ?: 1.0,
                    effectProgramIds =
                        (map["effectProgramIds"] as? List<*>)?.mapNotNull { value ->
                            value?.toString()
                        } ?: emptyList(),
                    transitionRole = map["transitionRole"]?.toString() ?: "none",
                    transitionId = map["transitionId"]?.toString(),
                    transitionProgress = (map["transitionProgress"] as? Number)?.toDouble(),
                    transitionTimelineStartMs = (map["transitionTimelineStartMs"] as? Number)?.toLong(),
                    transitionTimelineEndMs = (map["transitionTimelineEndMs"] as? Number)?.toLong(),
                    runtimeBlockers =
                        (map["runtimeBlockers"] as? List<*>)?.mapNotNull { value ->
                            value?.toString()
                        } ?: emptyList(),
                )
            } ?: emptyList()
        val regions =
            (arguments["regions"] as? List<*>)?.mapNotNull { entry ->
                val map = (entry as? Map<*, *>)?.mapKeys { (key, _) -> key.toString() }
                    ?: return@mapNotNull null
                val width = (map["width"] as? Number)?.toFloat() ?: return@mapNotNull null
                val height = (map["height"] as? Number)?.toFloat() ?: return@mapNotNull null
                if (width <= 0f || height <= 0f) {
                    return@mapNotNull null
                }
                Stage5TimelineScrubViewportRegion(
                    left = (map["left"] as? Number)?.toFloat() ?: 0f,
                    top = (map["top"] as? Number)?.toFloat() ?: 0f,
                    width = width,
                    height = height,
                )
            } ?: emptyList()
        return Stage5TimelineScrubSurfaceConfig(
            currentPositionMs = (arguments["currentPositionMs"] as? Number)?.toLong() ?: 0L,
            timelineDurationMs = (arguments["timelineDurationMs"] as? Number)?.toLong() ?: 0L,
            timelineOffsetMs = (arguments["timelineOffsetMs"] as? Number)?.toLong() ?: 0L,
            secondsWidth = (arguments["secondsWidth"] as? Number)?.toDouble() ?: 1.0,
            timelineFps = (arguments["timelineFps"] as? Number)?.toDouble() ?: 30.0,
            targetWidth = (arguments["targetWidth"] as? Number)?.toInt() ?: 480,
            targetHeight = (arguments["targetHeight"] as? Number)?.toInt() ?: 854,
            tapEnabled = arguments["tapEnabled"] == true,
            regions = regions,
            previewSources = previewSources,
        )
    }
}
