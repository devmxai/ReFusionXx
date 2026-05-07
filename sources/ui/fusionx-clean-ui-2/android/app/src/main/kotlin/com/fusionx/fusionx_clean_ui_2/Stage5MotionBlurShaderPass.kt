package com.refusion.app

import android.graphics.RenderEffect
import android.graphics.RuntimeShader
import android.os.Build
import kotlin.math.abs
import kotlin.math.max
import kotlin.math.min

class Stage5MotionBlurShaderPass {
    companion object {
        private const val MAX_SAMPLES = 32

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
            uniform float shutterAngleDegrees;
            uniform float shutterPhase;
            uniform float sampleCount;
            uniform float weightProfile;
            uniform float tileSafeSampling;

            float sampleWeight(float x) {
                // Hann window with a tiny floor to avoid overly hard endpoints.
                float hann = 0.5 - (0.5 * cos(6.2831853 * x));
                return max(0.0001, hann);
            }

            float mirrorCoord(float value, float low, float high) {
                float span = max(0.00001, high - low);
                float shifted = value - low;
                float period = span * 2.0;
                float wrapped = mod(shifted, period);
                if (wrapped < 0.0) wrapped += period;
                float mirrored = (wrapped <= span) ? wrapped : (period - wrapped);
                return low + mirrored;
            }

            float2 safeSampleCoord(float2 coord) {
                float2 low = float2(0.5, 0.5);
                float2 high = max(low, resolution - float2(0.5, 0.5));
                if (tileSafeSampling > 0.5) {
                    return float2(
                        mirrorCoord(coord.x, low.x, high.x),
                        mirrorCoord(coord.y, low.y, high.y)
                    );
                }
                return clamp(coord, low, high);
            }

            half4 sampleSource(float2 coord) {
                return sourceImage.eval(safeSampleCoord(coord));
            }

            half4 main(float2 coord) {
                float count = clamp(sampleCount, 1.0, 32.0);
                float2 anchor = anchorNorm * resolution;
                float2 linearDelta = direction * kernelLengthPx;

                half4 accum = half4(0.0);
                float weightAccum = 0.0;
                for (int i = 0; i < 32; i++) {
                    if (float(i) >= count) {
                        break;
                    }
                    float samplePosition = ((float(i) + 0.5) / count) - 0.5;
                    float phase = clamp(shutterPhase, -1.0, 1.0) * 0.5;
                    float t = samplePosition + phase;
                    // Dart sends calibrated transform deltas with amount and
                    // shutter already applied exactly once. The shader only
                    // distributes those deltas over the shutter samples.
                    float scaledT = t;
                    float theta = radialOmega * scaledT;
                    float c = cos(-theta);
                    float s = sin(-theta);
                    float2 translated = coord - (linearDelta * scaledT);
                    float2 centered = translated - anchor;
                    float scaleX = max(0.01, 1.0 + (scaleVelocity.x * scaledT));
                    float scaleY = max(0.01, 1.0 + (scaleVelocity.y * scaledT));
                    float2 unscaled = float2(centered.x / scaleX, centered.y / scaleY);
                    float2 unrotated =
                        float2(
                            (unscaled.x * c) - (unscaled.y * s),
                            (unscaled.x * s) + (unscaled.y * c)
                        );
                    float2 sampleCoord = anchor + unrotated;
                    float x = (float(i) + 0.5) / count;
                    float weight = sampleWeight(x);
                    accum += sampleSource(sampleCoord) * half(weight);
                    weightAccum += weight;
                }
                if (weightAccum <= 0.0) {
                    return sampleSource(coord);
                }
                return accum / half(weightAccum);
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
        tileSafeSampling: Boolean = false,
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
        val effectiveTrailPx =
            effectiveTrailPx(
                directive = normalizedDirective,
                targetWidthPx = targetWidthPx,
                targetHeightPx = targetHeightPx,
            )
        if (effectiveTrailPx <= 0.5f) {
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
                setFloatUniform(
                    "shutterAngleDegrees",
                    normalizedDirective.shutterAngleDegrees.toFloat().coerceIn(0f, 720f),
                )
                setFloatUniform("shutterPhase", normalizedDirective.shutterPhase.toFloat())
                setFloatUniform(
                    "sampleCount",
                    normalizedDirective.sampleCount.coerceIn(1, MAX_SAMPLES).toFloat(),
                )
                setFloatUniform("weightProfile", 1f)
                setFloatUniform("tileSafeSampling", if (tileSafeSampling) 1f else 0f)
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

    private fun effectiveTrailPx(
        directive: Stage5VisualRuntimeMotionBlurDirective,
        targetWidthPx: Float,
        targetHeightPx: Float,
    ): Float {
        val minDimensionPx = max(1f, min(targetWidthPx, targetHeightPx))
        val linearTrailPx = directive.kernelLengthPx.toFloat().coerceAtLeast(0f)
        val rotationTrailPx = abs(directive.radialOmega.toFloat()) * minDimensionPx * 0.35f
        val scaleTrailPx =
            max(
                abs(directive.scaleVelocityX.toFloat()),
                abs(directive.scaleVelocityY.toFloat()),
            ) * minDimensionPx * 0.25f
        return max(linearTrailPx, max(rotationTrailPx, scaleTrailPx))
    }
}
