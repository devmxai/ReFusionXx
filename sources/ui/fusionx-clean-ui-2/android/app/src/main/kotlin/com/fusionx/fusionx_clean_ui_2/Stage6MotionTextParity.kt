package com.fusionx.fusionx_clean_ui_2

import kotlin.math.abs
import kotlin.math.hypot

internal object Stage6MotionTextParityProbe {
    private const val PARITY_POSITION_TOLERANCE_PX = 1.5f
    private const val PARITY_SCALE_TOLERANCE = 0.02f
    private const val PARITY_ROTATION_TOLERANCE_DEGREES = 0.5f
    private const val PARITY_OPACITY_TOLERANCE = 0.03f
    private const val PARITY_BLUR_TOLERANCE = 0.5f
    private const val PARITY_FONT_SIZE_TOLERANCE = 0.75f
    private const val PARITY_LETTER_SPACING_TOLERANCE = 0.5f
    private const val PARITY_REVEAL_PROGRESS_TOLERANCE = 0.05f

    fun buildDiagnostics(
        renderTrack: NativeMotionTextRenderTrack,
        runtimePathKind: String,
        blurExecutionMode: String,
        glBlurSigmaPx: Float?,
        glBlurDecisionCode: String,
        glBlurDecisionDetail: String?,
        resolveRuntimeNodes: (Long) -> List<NativeMotionTextRenderNode>,
    ): NativeMotionTextParityDiagnostics? {
        if (renderTrack.samples.isEmpty()) {
            return null
        }
        var sampledNodeCount = 0
        var comparedNodeCount = 0
        var missingRuntimeNodeCount = 0
        var unexpectedRuntimeNodeCount = 0
        var driftNodeCount = 0
        var textMismatchCount = 0
        var revealUnitMismatchCount = 0
        var anchorMismatchCount = 0
        var alignmentMismatchCount = 0
        var blendModeMismatchCount = 0
        var maxPositionDeltaPx = 0f
        var maxScaleDelta = 0f
        var maxRotationDelta = 0f
        var maxOpacityDelta = 0f
        var maxBlurDelta = 0f
        var maxFontSizeDelta = 0f
        var maxLetterSpacingDelta = 0f
        var maxRevealProgressDelta = 0f
        var worstNodeId: String? = null
        var worstTimeMs: Long? = null
        var worstScore = 0f

        renderTrack.samples.forEach { sample ->
            val sampledById = sample.nodes.associateBy { it.id }
            val evaluatedById = resolveRuntimeNodes(sample.timeMs).associateBy { it.id }
            sampledNodeCount += sampledById.size
            missingRuntimeNodeCount += sampledById.keys.count { !evaluatedById.containsKey(it) }
            unexpectedRuntimeNodeCount += evaluatedById.keys.count { !sampledById.containsKey(it) }

            sampledById.forEach sampledNodeLoop@ { (nodeId, sampledNode) ->
                val evaluatedNode = evaluatedById[nodeId] ?: return@sampledNodeLoop
                comparedNodeCount += 1
                val positionDeltaPx =
                    hypot(
                        (sampledNode.canvasOffsetX - evaluatedNode.canvasOffsetX).toDouble(),
                        (sampledNode.canvasOffsetY - evaluatedNode.canvasOffsetY).toDouble(),
                    ).toFloat()
                val scaleDelta =
                    maxOf(
                        abs(sampledNode.scaleX - evaluatedNode.scaleX),
                        abs(sampledNode.scaleY - evaluatedNode.scaleY),
                    )
                val rotationDelta = abs(sampledNode.rotationDegrees - evaluatedNode.rotationDegrees)
                val opacityDelta = abs(sampledNode.opacity - evaluatedNode.opacity)
                val blurDelta = abs(sampledNode.blurAmount - evaluatedNode.blurAmount)
                val fontSizeDelta = abs(sampledNode.fontSize - evaluatedNode.fontSize)
                val letterSpacingDelta = abs(sampledNode.letterSpacing - evaluatedNode.letterSpacing)
                val revealProgressDelta =
                    abs((sampledNode.revealProgress ?: 1f) - (evaluatedNode.revealProgress ?: 1f))
                val textMismatch = sampledNode.text != evaluatedNode.text
                val revealUnitMismatch = sampledNode.revealUnit != evaluatedNode.revealUnit
                val anchorMismatch = sampledNode.anchor != evaluatedNode.anchor
                val alignmentMismatch = sampledNode.textAlignment != evaluatedNode.textAlignment
                val blendModeMismatch = sampledNode.blendMode != evaluatedNode.blendMode

                if (textMismatch) {
                    textMismatchCount += 1
                }
                if (revealUnitMismatch) {
                    revealUnitMismatchCount += 1
                }
                if (anchorMismatch) {
                    anchorMismatchCount += 1
                }
                if (alignmentMismatch) {
                    alignmentMismatchCount += 1
                }
                if (blendModeMismatch) {
                    blendModeMismatchCount += 1
                }

                maxPositionDeltaPx = maxOf(maxPositionDeltaPx, positionDeltaPx)
                maxScaleDelta = maxOf(maxScaleDelta, scaleDelta)
                maxRotationDelta = maxOf(maxRotationDelta, rotationDelta)
                maxOpacityDelta = maxOf(maxOpacityDelta, opacityDelta)
                maxBlurDelta = maxOf(maxBlurDelta, blurDelta)
                maxFontSizeDelta = maxOf(maxFontSizeDelta, fontSizeDelta)
                maxLetterSpacingDelta = maxOf(maxLetterSpacingDelta, letterSpacingDelta)
                maxRevealProgressDelta = maxOf(maxRevealProgressDelta, revealProgressDelta)

                val driftDetected =
                    textMismatch ||
                        revealUnitMismatch ||
                        anchorMismatch ||
                        alignmentMismatch ||
                        blendModeMismatch ||
                        positionDeltaPx > PARITY_POSITION_TOLERANCE_PX ||
                        scaleDelta > PARITY_SCALE_TOLERANCE ||
                        rotationDelta > PARITY_ROTATION_TOLERANCE_DEGREES ||
                        opacityDelta > PARITY_OPACITY_TOLERANCE ||
                        blurDelta > PARITY_BLUR_TOLERANCE ||
                        fontSizeDelta > PARITY_FONT_SIZE_TOLERANCE ||
                        letterSpacingDelta > PARITY_LETTER_SPACING_TOLERANCE ||
                        revealProgressDelta > PARITY_REVEAL_PROGRESS_TOLERANCE
                if (driftDetected) {
                    driftNodeCount += 1
                }

                val score =
                    (positionDeltaPx / PARITY_POSITION_TOLERANCE_PX) +
                        (scaleDelta / PARITY_SCALE_TOLERANCE) +
                        (rotationDelta / PARITY_ROTATION_TOLERANCE_DEGREES) +
                        (opacityDelta / PARITY_OPACITY_TOLERANCE) +
                        (blurDelta / PARITY_BLUR_TOLERANCE) +
                        (fontSizeDelta / PARITY_FONT_SIZE_TOLERANCE) +
                        (letterSpacingDelta / PARITY_LETTER_SPACING_TOLERANCE) +
                        (revealProgressDelta / PARITY_REVEAL_PROGRESS_TOLERANCE) +
                        (if (textMismatch) 1f else 0f) +
                        (if (revealUnitMismatch) 1f else 0f) +
                        (if (anchorMismatch) 1f else 0f) +
                        (if (alignmentMismatch) 1f else 0f) +
                        (if (blendModeMismatch) 1f else 0f)
                if (score > worstScore) {
                    worstScore = score
                    worstNodeId = nodeId
                    worstTimeMs = sample.timeMs
                }
            }
        }

        val status =
            if (driftNodeCount == 0 &&
                missingRuntimeNodeCount == 0 &&
                unexpectedRuntimeNodeCount == 0
            ) {
                "matched"
            } else {
                "drift_detected"
            }

        return NativeMotionTextParityDiagnostics(
            status = status,
            referencePathKind = "sampled_track",
            runtimePathKind = runtimePathKind,
            blurExecutionMode = blurExecutionMode,
            glBlurSigmaPx = glBlurSigmaPx,
            glBlurDecisionCode = glBlurDecisionCode,
            glBlurDecisionDetail = glBlurDecisionDetail,
            sampleCount = renderTrack.samples.size,
            sampledNodeCount = sampledNodeCount,
            comparedNodeCount = comparedNodeCount,
            missingRuntimeNodeCount = missingRuntimeNodeCount,
            unexpectedRuntimeNodeCount = unexpectedRuntimeNodeCount,
            driftNodeCount = driftNodeCount,
            textMismatchCount = textMismatchCount,
            revealUnitMismatchCount = revealUnitMismatchCount,
            anchorMismatchCount = anchorMismatchCount,
            alignmentMismatchCount = alignmentMismatchCount,
            blendModeMismatchCount = blendModeMismatchCount,
            maxPositionDeltaPx = maxPositionDeltaPx,
            maxScaleDelta = maxScaleDelta,
            maxRotationDelta = maxRotationDelta,
            maxOpacityDelta = maxOpacityDelta,
            maxBlurDelta = maxBlurDelta,
            maxFontSizeDelta = maxFontSizeDelta,
            maxLetterSpacingDelta = maxLetterSpacingDelta,
            maxRevealProgressDelta = maxRevealProgressDelta,
            worstNodeId = worstNodeId,
            worstTimeMs = worstTimeMs,
        )
    }
}
