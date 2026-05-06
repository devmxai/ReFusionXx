package com.refusion.app

import android.graphics.RenderEffect

class Stage5RuntimeEffectChainBuilder {
    data class ChainResult(
        val renderEffect: RenderEffect?,
        val chainOrder: String,
    )

    fun buildChain(
        edgeFillEffect: RenderEffect?,
        motionThenGaussianEffect: RenderEffect?,
    ): ChainResult {
        if (edgeFillEffect == null) {
            return ChainResult(
                renderEffect = motionThenGaussianEffect,
                chainOrder = "motionBlur->gaussian",
            )
        }
        if (motionThenGaussianEffect == null) {
            return ChainResult(
                renderEffect = edgeFillEffect,
                chainOrder = "edgeFill",
            )
        }
        // createChainEffect(outer, inner) => outer(inner(source)).
        return ChainResult(
            renderEffect = RenderEffect.createChainEffect(motionThenGaussianEffect, edgeFillEffect),
            chainOrder = "edgeFill->motionBlur->gaussian",
        )
    }
}
