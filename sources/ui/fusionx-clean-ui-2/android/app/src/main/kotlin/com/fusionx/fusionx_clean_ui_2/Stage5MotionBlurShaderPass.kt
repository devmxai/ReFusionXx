package com.refusion.app

import android.graphics.RenderEffect
import android.graphics.RuntimeShader
import android.os.Build
import kotlin.math.max

class Stage5MotionBlurShaderPass {
    companion object {
        private const val MAX_SAMPLES = 12

        // language=AGSL
        private const val MOTION_BLUR_SHADER = """
            uniform shader sourceImage;
            uniform float2 resolution;
            uniform float amount;
            uniform float kernelLengthPx;
            uniform float2 direction;
            uniform float radialOmega;
            uniform float2 scaleVelocity;
            uniform float2 anchorNorm;
            uniform float shutterPhase;
            uniform float sampleCount;

            half4 main(float2 coord) {
                float count = clamp(sampleCount, 1.0, 12.0);
                float2 anchor = anchorNorm * resolution;
                float2 fromAnchor = coord - anchor;
                float2 linearVelocity = direction * kernelLengthPx;
                float2 radialVelocity = float2(-fromAnchor.y, fromAnchor.x) * radialOmega;
                float2 zoomVelocity = fromAnchor * scaleVelocity;
                float2 velocity = (linearVelocity + radialVelocity + zoomVelocity) * amount;

                half4 accum = half4(0.0);
                float weightAccum = 0.0;
                for (int i = 0; i < 12; i++) {
                    if (float(i) >= count) {
                        break;
                    }
                    float normalized = (count <= 1.0) ? 0.0 : (float(i) / (count - 1.0)) - 0.5;
                    float phase = clamp(shutterPhase, -1.0, 1.0) * 0.5;
                    float t = normalized + phase;
                    float weight = 1.0 / count;
                    accum += sourceImage.eval(coord + (velocity * t)) * half(weight);
                    weightAccum += weight;
                }
                if (weightAccum <= 0.0) {
                    return sourceImage.eval(coord);
                }
                return accum;
            }
        """
    }

    data class RenderEffectResult(
        val renderEffect: RenderEffect?,
        val fallbackReason: String?,
    )

    fun buildRenderEffect(
        gaussianBlur: RenderEffect?,
        directive: Stage5VisualRuntimeMotionBlurDirective?,
        targetWidthPx: Float,
        targetHeightPx: Float,
    ): RenderEffectResult {
        val normalizedDirective = directive?.takeIf { it.enabled && it.amount > 0.001 }
        if (normalizedDirective == null) {
            return RenderEffectResult(
                renderEffect = gaussianBlur,
                fallbackReason = directive?.fallbackReason ?: "motion_blur_disabled",
            )
        }
        if (Build.VERSION.SDK_INT < 33) {
            return RenderEffectResult(
                renderEffect = gaussianBlur,
                fallbackReason = "runtime_shader_api_not_available",
            )
        }
        if (normalizedDirective.kernelLengthPx <= 0.5) {
            return RenderEffectResult(
                renderEffect = gaussianBlur,
                fallbackReason = "motion_blur_velocity_zero",
            )
        }
        return try {
            val shader = RuntimeShader(MOTION_BLUR_SHADER).apply {
                setFloatUniform(
                    "resolution",
                    max(1f, targetWidthPx),
                    max(1f, targetHeightPx),
                )
                setFloatUniform("amount", normalizedDirective.amount.toFloat())
                setFloatUniform(
                    "kernelLengthPx",
                    normalizedDirective.kernelLengthPx.toFloat().coerceAtLeast(0f),
                )
                setFloatUniform(
                    "direction",
                    normalizedDirective.directionX.toFloat(),
                    normalizedDirective.directionY.toFloat(),
                )
                setFloatUniform("radialOmega", normalizedDirective.radialOmega.toFloat())
                setFloatUniform(
                    "scaleVelocity",
                    normalizedDirective.scaleVelocityX.toFloat(),
                    normalizedDirective.scaleVelocityY.toFloat(),
                )
                setFloatUniform(
                    "anchorNorm",
                    normalizedDirective.anchorXNormalized.toFloat().coerceIn(0f, 1f),
                    normalizedDirective.anchorYNormalized.toFloat().coerceIn(0f, 1f),
                )
                setFloatUniform("shutterPhase", normalizedDirective.shutterPhase.toFloat())
                setFloatUniform(
                    "sampleCount",
                    normalizedDirective.sampleCount.coerceIn(1, MAX_SAMPLES).toFloat(),
                )
            }
            val motionBlurEffect =
                RenderEffect.createRuntimeShaderEffect(shader, "sourceImage")
            val combinedEffect =
                if (gaussianBlur != null) {
                    RenderEffect.createChainEffect(gaussianBlur, motionBlurEffect)
                } else {
                    motionBlurEffect
                }
            RenderEffectResult(
                renderEffect = combinedEffect,
                fallbackReason = normalizedDirective.fallbackReason,
            )
        } catch (_: IllegalArgumentException) {
            RenderEffectResult(
                renderEffect = gaussianBlur,
                fallbackReason = "runtime_shader_compile_failed",
            )
        }
    }
}
