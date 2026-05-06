package com.refusion.app

import android.graphics.RenderEffect
import android.graphics.RuntimeShader
import android.os.Build
import kotlin.math.max

class Stage5EdgeFillShaderPass {
    companion object {
        // language=AGSL
        private const val EDGE_FILL_SHADER = """
            uniform shader sourceImage;
            uniform float2 resolution;
            uniform float2 canvasSize;
            uniform float amount;
            uniform float mode;
            uniform float seamFeatherPx;
            uniform float seamOverlapPx;
            uniform float overscanScale;
            uniform float2 validSourceMinPx;
            uniform float2 validSourceMaxPx;
            uniform float3 inverseRow0;
            uniform float3 inverseRow1;

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

            float2 viewToCanvas(float2 coord) { return coord * (canvasSize / max(resolution, float2(1.0))); }
            float2 canvasToView(float2 coord) { return coord * (resolution / max(canvasSize, float2(1.0))); }

            float2 applyInverse(float2 coord) {
                float x = dot(inverseRow0, float3(coord, 1.0));
                float y = dot(inverseRow1, float3(coord, 1.0));
                return float2(x, y);
            }

            half4 main(float2 coord) {
                float2 canvasCoord = viewToCanvas(coord);
                float2 remappedCanvasCoord = applyInverse(canvasCoord);
                float2 sourceMin = validSourceMinPx;
                float2 sourceMax = validSourceMaxPx;
                float2 sourceCenter = (sourceMin + sourceMax) * 0.5;
                float2 sourceHalf = max(float2(0.5), (sourceMax - sourceMin) * 0.5);
                float overscan = max(1.0, overscanScale);
                float2 tileHalf = max(float2(0.5), sourceHalf * overscan);
                float2 tileMin = sourceCenter - tileHalf;
                float2 tileMax = sourceCenter + tileHalf;

                bool inX = remappedCanvasCoord.x >= sourceMin.x && remappedCanvasCoord.x <= sourceMax.x;
                bool inY = remappedCanvasCoord.y >= sourceMin.y && remappedCanvasCoord.y <= sourceMax.y;
                if (inX && inY) {
                    return sourceImage.eval(canvasToView(remappedCanvasCoord));
                }

                float fillMode = mode;
                float sx = remappedCanvasCoord.x;
                float sy = remappedCanvasCoord.y;

                if (fillMode < 0.5) {
                    // reflect
                    sx = mirrorCoord(remappedCanvasCoord.x, tileMin.x, tileMax.x);
                    sy = mirrorCoord(remappedCanvasCoord.y, tileMin.y, tileMax.y);
                } else if (fillMode < 1.5) {
                    // replicate/clamp
                    sx = clamp(remappedCanvasCoord.x, tileMin.x, tileMax.x);
                    sy = clamp(remappedCanvasCoord.y, tileMin.y, tileMax.y);
                } else {
                    // wrap
                    sx = wrapCoord(remappedCanvasCoord.x, tileMin.x, tileMax.x);
                    sy = wrapCoord(remappedCanvasCoord.y, tileMin.y, tileMax.y);
                }

                float2 sampleCoord = canvasToView(float2(sx, sy));
                half4 filled = sourceImage.eval(sampleCoord);
                float2 edgeCoord = clamp(remappedCanvasCoord, sourceMin, sourceMax);
                half4 edgeColor = sourceImage.eval(canvasToView(edgeCoord));
                float outsideDistancePx = max(
                    max(sourceMin.x - remappedCanvasCoord.x, remappedCanvasCoord.x - sourceMax.x),
                    max(sourceMin.y - remappedCanvasCoord.y, remappedCanvasCoord.y - sourceMax.y)
                );
                float seamStartPx = max(0.0, seamOverlapPx);
                float seamEndPx = seamStartPx + max(0.001, seamFeatherPx);
                float seamT = smoothstep(seamStartPx, seamEndPx, max(0.0, outsideDistancePx));
                return mix(edgeColor, filled, half(seamT));
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
        if (normalizedDirective.mode.equals("off", ignoreCase = true)) {
            return RenderEffectResult(
                renderEffect = null,
                fallbackReason = "edge_fill_mode_off",
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
                setFloatUniform(
                    "canvasSize",
                    max(1f, normalizedDirective.canvasWidth.toFloat()),
                    max(1f, normalizedDirective.canvasHeight.toFloat()),
                )
                setFloatUniform("amount", normalizedDirective.amount.toFloat().coerceIn(0f, 1f))
                setFloatUniform("mode", modeValue(normalizedDirective.mode))
                setFloatUniform(
                    "seamFeatherPx",
                    max(0.5f, normalizedDirective.softnessPx.toFloat().coerceIn(0f, 64f)),
                )
                setFloatUniform("seamOverlapPx", 1.0f)
                setFloatUniform(
                    "overscanScale",
                    max(1f, normalizedDirective.overscanScale.toFloat()),
                )
                val safeCanvasWidth = max(1f, normalizedDirective.canvasWidth.toFloat())
                val safeCanvasHeight = max(1f, normalizedDirective.canvasHeight.toFloat())
                val minX = (normalizedDirective.sourceRectLeft.toFloat() * safeCanvasWidth)
                val minY = (normalizedDirective.sourceRectTop.toFloat() * safeCanvasHeight)
                val maxX = (normalizedDirective.sourceRectRight.toFloat() * safeCanvasWidth)
                val maxY = (normalizedDirective.sourceRectBottom.toFloat() * safeCanvasHeight)
                val pixelSafeMinX = (minX + 0.5f).coerceAtMost(maxX - 0.5f)
                val pixelSafeMinY = (minY + 0.5f).coerceAtMost(maxY - 0.5f)
                val pixelSafeMaxX = (maxX - 0.5f).coerceAtLeast(minX + 0.5f)
                val pixelSafeMaxY = (maxY - 0.5f).coerceAtLeast(minY + 0.5f)
                setFloatUniform(
                    "validSourceMinPx",
                    pixelSafeMinX,
                    pixelSafeMinY,
                )
                setFloatUniform(
                    "validSourceMaxPx",
                    pixelSafeMaxX,
                    pixelSafeMaxY,
                )
                val inverse = normalizedDirective.inverseTransformMatrix3x3
                val inverse00 = inverse.getOrElse(0) { 1.0 }.toFloat()
                val inverse01 = inverse.getOrElse(1) { 0.0 }.toFloat()
                val inverse02 = inverse.getOrElse(2) { 0.0 }.toFloat()
                val inverse10 = inverse.getOrElse(3) { 0.0 }.toFloat()
                val inverse11 = inverse.getOrElse(4) { 1.0 }.toFloat()
                val inverse12 = inverse.getOrElse(5) { 0.0 }.toFloat()
                setFloatUniform("inverseRow0", inverse00, inverse01, inverse02)
                setFloatUniform("inverseRow1", inverse10, inverse11, inverse12)
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
            "reflect" -> 0f
            "blurredreflect" -> 0f
            "blurredbackground" -> 0f
            "autooverscan" -> 0f
            "replicate" -> 1f
            "wrap" -> 2f
            "color" -> 1f
            else -> 0f
        }
    }
}
