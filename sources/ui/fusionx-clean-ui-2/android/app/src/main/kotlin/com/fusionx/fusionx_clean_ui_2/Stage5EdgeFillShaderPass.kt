package com.refusion.app

import android.graphics.RenderEffect
import android.graphics.RuntimeShader
import android.os.Build
import kotlin.math.max
import kotlin.math.min

class Stage5EdgeFillShaderPass {
    companion object {
        // language=AGSL
        private const val EDGE_FILL_SHADER = """
            uniform shader sourceImage;
            uniform float2 resolution;
            uniform float amount;
            uniform float mode;
            uniform float2 sourceRectMin;
            uniform float2 sourceRectMax;

            float mirrorCoord(float value, float low, float high) {
                float span = max(0.00001, high - low);
                float shifted = value - low;
                float period = span * 2.0;
                float wrapped = mod(shifted, period);
                if (wrapped < 0.0) wrapped += period;
                float mirrored = (wrapped <= span) ? wrapped : (period - wrapped);
                return low + mirrored;
            }

            float wrapCoord(float value, float low, float high) {
                float span = max(0.00001, high - low);
                float shifted = value - low;
                float wrapped = mod(shifted, span);
                if (wrapped < 0.0) wrapped += span;
                return low + wrapped;
            }

            half4 main(float2 coord) {
                float2 uv = coord / max(resolution, float2(1.0));
                float2 sourceMin = sourceRectMin;
                float2 sourceMax = sourceRectMax;
                bool inX = uv.x >= sourceMin.x && uv.x <= sourceMax.x;
                bool inY = uv.y >= sourceMin.y && uv.y <= sourceMax.y;
                if (inX && inY) {
                    return sourceImage.eval(coord);
                }

                float fillMode = mode;
                float sx = uv.x;
                float sy = uv.y;

                if (fillMode < 0.5) {
                    // reflect
                    sx = mirrorCoord(uv.x, sourceMin.x, sourceMax.x);
                    sy = mirrorCoord(uv.y, sourceMin.y, sourceMax.y);
                } else if (fillMode < 1.5) {
                    // replicate/clamp
                    sx = clamp(uv.x, sourceMin.x, sourceMax.x);
                    sy = clamp(uv.y, sourceMin.y, sourceMax.y);
                } else {
                    // wrap
                    sx = wrapCoord(uv.x, sourceMin.x, sourceMax.x);
                    sy = wrapCoord(uv.y, sourceMin.y, sourceMax.y);
                }

                float2 sampleCoord = float2(sx, sy) * resolution;
                half4 filled = sourceImage.eval(sampleCoord);
                half4 original = sourceImage.eval(coord);
                return mix(original, filled, half(clamp(amount, 0.0, 1.0)));
            }
        """
    }

    data class RenderEffectResult(
        val renderEffect: RenderEffect?,
        val fallbackReason: String?,
        val shaderAllocationCount: Int,
    )

    fun buildRenderEffect(
        directive: Stage5VisualRuntimeEdgeFillDirective?,
        targetWidthPx: Float,
        targetHeightPx: Float,
    ): RenderEffectResult {
        val normalizedDirective = directive?.takeIf { it.enabled && it.amount > 0.001 }
        if (normalizedDirective == null) {
            return RenderEffectResult(
                renderEffect = null,
                fallbackReason = directive?.fallbackReason ?: "edge_fill_disabled",
                shaderAllocationCount = 0,
            )
        }
        if (Build.VERSION.SDK_INT < 33) {
            return RenderEffectResult(
                renderEffect = null,
                fallbackReason = "runtime_shader_api_not_available",
                shaderAllocationCount = 0,
            )
        }
        return try {
            val shader = RuntimeShader(EDGE_FILL_SHADER).apply {
                setFloatUniform(
                    "resolution",
                    max(1f, targetWidthPx),
                    max(1f, targetHeightPx),
                )
                setFloatUniform("amount", normalizedDirective.amount.toFloat().coerceIn(0f, 1f))
                setFloatUniform("mode", modeValue(normalizedDirective.mode))
                setFloatUniform(
                    "sourceRectMin",
                    normalizedDirective.sourceRectLeft.toFloat().coerceIn(0f, 1f),
                    normalizedDirective.sourceRectTop.toFloat().coerceIn(0f, 1f),
                )
                setFloatUniform(
                    "sourceRectMax",
                    normalizedDirective.sourceRectRight.toFloat().coerceIn(0f, 1f),
                    normalizedDirective.sourceRectBottom.toFloat().coerceIn(0f, 1f),
                )
            }
            RenderEffectResult(
                renderEffect = RenderEffect.createRuntimeShaderEffect(shader, "sourceImage"),
                fallbackReason = normalizedDirective.fallbackReason,
                shaderAllocationCount = 1,
            )
        } catch (_: IllegalArgumentException) {
            RenderEffectResult(
                renderEffect = null,
                fallbackReason = "runtime_shader_compile_failed",
                shaderAllocationCount = 0,
            )
        }
    }

    private fun modeValue(mode: String): Float {
        return when (mode.lowercase()) {
            "replicate" -> 1f
            "wrap" -> 2f
            else -> 0f
        }
    }
}
