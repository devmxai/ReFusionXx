package com.refusion.app

import kotlin.math.abs

internal data class NativeAuthoredVisualSurfaceResolvedNode(
    val id: String,
    val targetElementId: String,
    val elementKind: String,
    val sourceKind: String,
    val sourceId: String,
    val sourceAssetId: String?,
    val shapeKind: String?,
    val positionX: Float,
    val positionY: Float,
    val scaleX: Float,
    val scaleY: Float,
    val rotationDegrees: Float,
    val width: Float,
    val height: Float,
    val cornerRadius: Float,
    val opacity: Float,
    val blurAmount: Float,
    val blendMode: String,
    val zIndex: Int,
    val isAnimated: Boolean,
)

internal data class NativeAuthoredVisualSurfaceRuntimeSummary(
    val sampleCount: Int,
    val activeNodeCount: Int,
    val activeAnimatedNodeCount: Int,
    val activeBlurNodeCount: Int,
    val normalBlendNodeCount: Int,
    val surfaceEffectEligibleNodeCount: Int,
    val maxConcurrentActiveNodeCount: Int,
    val maxResolvedBlurAmount: Float,
    val firstResolvedNodeId: String? = null,
)

internal object Stage6AuthoredVisualSurfaceRuntimeEvaluator {
    fun summarizeRuntime(
        program: NativeAuthoredVisualSurfaceProgram,
        sampleTimesMs: List<Long>,
    ): NativeAuthoredVisualSurfaceRuntimeSummary {
        val effectiveSampleTimes =
            sampleTimesMs
                .filter { timeMs -> timeMs >= 0L }
                .distinct()
                .sorted()
                .ifEmpty {
                    program.nodes
                        .map { node ->
                            val startMs = node.projectRangeStartMs.coerceAtLeast(0L)
                            val endExclusiveMs = node.projectRangeEndExclusiveMs.coerceAtLeast(startMs + 1L)
                            startMs + ((endExclusiveMs - startMs) / 2L)
                        }.distinct()
                        .sorted()
                }

        val activeNodeIds = linkedSetOf<String>()
        val activeAnimatedNodeIds = linkedSetOf<String>()
        val activeBlurNodeIds = linkedSetOf<String>()
        val normalBlendNodeIds = linkedSetOf<String>()
        val surfaceEffectEligibleNodeIds = linkedSetOf<String>()
        var maxConcurrentActiveNodeCount = 0
        var maxResolvedBlurAmount = 0f
        var firstResolvedNodeId: String? = null

        effectiveSampleTimes.forEach { timeMs ->
            val resolvedNodes = resolveNodes(program, timeMs)
            if (firstResolvedNodeId == null) {
                firstResolvedNodeId = resolvedNodes.firstOrNull()?.id
            }
            maxConcurrentActiveNodeCount = maxOf(maxConcurrentActiveNodeCount, resolvedNodes.size)
            resolvedNodes.forEach { node ->
                activeNodeIds += node.id
                if (node.isAnimated) {
                    activeAnimatedNodeIds += node.id
                }
                if (node.blurAmount > 0.05f) {
                    activeBlurNodeIds += node.id
                }
                if (node.blendMode == "normal") {
                    normalBlendNodeIds += node.id
                    surfaceEffectEligibleNodeIds += node.id
                }
                maxResolvedBlurAmount = maxOf(maxResolvedBlurAmount, node.blurAmount)
            }
        }

        return NativeAuthoredVisualSurfaceRuntimeSummary(
            sampleCount = effectiveSampleTimes.size,
            activeNodeCount = activeNodeIds.size,
            activeAnimatedNodeCount = activeAnimatedNodeIds.size,
            activeBlurNodeCount = activeBlurNodeIds.size,
            normalBlendNodeCount = normalBlendNodeIds.size,
            surfaceEffectEligibleNodeCount = surfaceEffectEligibleNodeIds.size,
            maxConcurrentActiveNodeCount = maxConcurrentActiveNodeCount,
            maxResolvedBlurAmount = maxResolvedBlurAmount,
            firstResolvedNodeId = firstResolvedNodeId,
        )
    }

    fun resolveNodes(
        program: NativeAuthoredVisualSurfaceProgram,
        timeMs: Long,
        allowedNodeIds: Set<String>? = null,
    ): List<NativeAuthoredVisualSurfaceResolvedNode> =
        program.nodes
            .mapNotNull { node -> evaluateNode(node, timeMs) }
            .filter { node -> allowedNodeIds == null || node.id in allowedNodeIds }
            .sortedWith(compareBy<NativeAuthoredVisualSurfaceResolvedNode>({ it.zIndex }, { it.id }))

    private fun evaluateNode(
        node: NativeAuthoredVisualSurfaceNode,
        timeMs: Long,
    ): NativeAuthoredVisualSurfaceResolvedNode? {
        if (timeMs < node.projectRangeStartMs || timeMs >= node.projectRangeEndExclusiveMs) {
            return null
        }
        val positionX =
            evaluateScalarProperty(
                channels = node.channels,
                propertyId = "transform.position.x",
                timeMs = timeMs,
                baseValue = node.basePositionX,
            )
        val positionY =
            evaluateScalarProperty(
                channels = node.channels,
                propertyId = "transform.position.y",
                timeMs = timeMs,
                baseValue = node.basePositionY,
            )
        val scaleX =
            evaluateScalarProperty(
                channels = node.channels,
                propertyId = "transform.scale.x",
                timeMs = timeMs,
                baseValue = node.baseScaleX,
            )
        val scaleY =
            evaluateScalarProperty(
                channels = node.channels,
                propertyId = "transform.scale.y",
                timeMs = timeMs,
                baseValue = node.baseScaleY,
            )
        val rotationDegrees =
            evaluateScalarProperty(
                channels = node.channels,
                propertyId = "transform.rotation.degrees",
                timeMs = timeMs,
                baseValue = node.baseRotationDegrees,
            )
        val width =
            evaluateScalarProperty(
                channels = node.channels,
                propertyId = "shape.width",
                timeMs = timeMs,
                baseValue = node.baseWidth,
            ).coerceAtLeast(0f)
        val height =
            evaluateScalarProperty(
                channels = node.channels,
                propertyId = "shape.height",
                timeMs = timeMs,
                baseValue = node.baseHeight,
            ).coerceAtLeast(0f)
        val cornerRadius =
            evaluateScalarProperty(
                channels = node.channels,
                propertyId = "shape.cornerRadius",
                timeMs = timeMs,
                baseValue = node.baseCornerRadius,
            ).coerceAtLeast(0f)
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
            ).coerceAtLeast(0f)
        val combinedOpacity = (elementOpacity * layerOpacity).coerceIn(0f, 1f)
        if (combinedOpacity <= 0.0001f) {
            return null
        }
        return NativeAuthoredVisualSurfaceResolvedNode(
            id = node.id,
            targetElementId = node.targetElementId,
            elementKind = node.elementKind,
            sourceKind = node.sourceKind,
            sourceId = node.sourceId,
            sourceAssetId = node.sourceAssetId,
            shapeKind = node.shapeKind,
            positionX = positionX,
            positionY = positionY,
            scaleX = scaleX,
            scaleY = scaleY,
            rotationDegrees = rotationDegrees,
            width = width,
            height = height,
            cornerRadius = cornerRadius,
            opacity = combinedOpacity,
            blurAmount = blurAmount,
            blendMode = node.blendMode,
            zIndex = node.zIndex,
            isAnimated = node.channels.isNotEmpty() || node.layerChannels.isNotEmpty(),
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
            return current.value + ((next.value - current.value) * curvedProgress)
        }
        return channel.fallbackValue
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
            else ->
                throw IllegalStateException(
                    "Unsupported export interpolation kind in authored visual surface runtime: ${interpolation.kind}",
                )
        }.coerceIn(0f, 1f)
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
                cubicBezierCoordinate(parameter, bezier.x1, bezier.x2) - progress
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
}
