package com.refusion.app

import android.content.Context
import android.graphics.Color
import android.graphics.Matrix
import android.graphics.RenderEffect
import android.graphics.Shader
import android.os.Handler
import android.os.Looper
import android.os.Build
import android.util.Log
import android.view.LayoutInflater
import android.view.Surface
import android.view.View
import android.widget.FrameLayout
import androidx.media3.common.Player
import androidx.media3.ui.AspectRatioFrameLayout
import androidx.media3.ui.PlayerView
import io.flutter.plugin.platform.PlatformView
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import kotlin.math.atan2
import kotlin.math.hypot
import kotlin.math.max
import kotlin.math.sqrt

class Stage5PreviewPlatformView(
    context: Context,
    private val stage5TransportManager: Stage5TransportManager,
    private val stage5NativeScrubEngine: Stage5NativeScrubEngine,
) : PlatformView, Stage5ScrubRenderHost {
    private data class FloatRect(
        val left: Float,
        val top: Float,
        val right: Float,
        val bottom: Float,
    ) {
        val width: Float get() = (right - left).coerceAtLeast(0f)
        val height: Float get() = (bottom - top).coerceAtLeast(0f)
    }

    private val mainHandler = Handler(Looper.getMainLooper())
    private var latestPlayer: Player? = null
    private var isPreviewOutputSuppressed = false
    private var isScrubSurfaceVisible = false
    private var isPlayerContentSized = false
    private var runtimeTransformMatrix3x3: List<Double>? = null
    private var runtimeOpacity = 1.0
    private var runtimeGaussianBlurSigmaPx: Float? = null
    private var runtimeMotionBlurDirective: Stage5VisualRuntimeMotionBlurDirective? = null
    private var runtimeEdgeFillDirective: Stage5VisualRuntimeEdgeFillDirective? = null
    private val motionBlurShaderPass = Stage5MotionBlurShaderPass()
    private val edgeFillShaderPass = Stage5EdgeFillShaderPass()
    private val runtimeEffectChainBuilder = Stage5RuntimeEffectChainBuilder()
    @Volatile
    private var appliedScrubAspectRatio: Float? = null
    @Volatile
    private var playerContentAspectRatio: Float? = null
    @Volatile
    private var isDisposed = false
    private var lastRotationCenterDeltaPx: Float? = null
    private val playerObserver: (Player) -> Unit = { updatedPlayer ->
        latestPlayer = updatedPlayer
        isPlayerContentSized = false
        stage5TransportManager.setPreviewContentSized(false)
        runOnUiThreadIfActive {
            if (!isPreviewOutputSuppressed) {
                playerView.player = updatedPlayer
            }
            syncPlayerVisibility()
        }
    }
    private val previewRetentionObserver: (Boolean) -> Unit = { shouldRetain ->
        runOnUiThreadIfActive {
            playerView.setKeepContentOnPlayerReset(shouldRetain)
        }
    }
    private val previewOutputSuppressionObserver: (Boolean) -> Unit = { shouldSuppress ->
        isPreviewOutputSuppressed = shouldSuppress
        runOnUiThreadIfActive {
            playerView.player =
                if (shouldSuppress) {
                    null
                } else {
                    latestPlayer ?: stage5TransportManager.player
                }
            syncPlayerVisibility()
        }
    }
    private val scrubSettlingObserver: (Boolean) -> Unit = { isSettling ->
        if (!isSettling) {
            stage5NativeScrubEngine.endSession()
        }
    }

    private val playerView =
        (LayoutInflater.from(context).inflate(
            R.layout.stage5_preview_player_view,
            null,
            false,
        ) as PlayerView).apply {
            useController = false
            resizeMode = AspectRatioFrameLayout.RESIZE_MODE_FIT
            setShutterBackgroundColor(Color.TRANSPARENT)
            setKeepContentOnPlayerReset(true)
            alpha = 0f
            setAspectRatioListener { contentAspectRatio, _, aspectRatioMismatch ->
                val sized = contentAspectRatio > 0f && !aspectRatioMismatch
                playerContentAspectRatio = contentAspectRatio.takeIf { it > 0f }
                val changed = sized != isPlayerContentSized
                isPlayerContentSized = sized
                // The transport resets its presentation state during same-player
                // timeline rebuilds. Re-emit even when the PlayerView-local value
                // did not change, otherwise Flutter can keep covering valid video
                // with the fallback while audio is already playing.
                stage5TransportManager.setPreviewContentSized(sized)
                if (changed) {
                    syncPlayerVisibility()
                }
            }
            latestPlayer = stage5TransportManager.player
            player = latestPlayer
        }
    private val scrubOverlayView =
        Stage5ScrubOverlayTextureView(context).apply {
            alpha = 0f
            visibility = View.VISIBLE
            onOutputSurfaceAvailable = {
                stage5NativeScrubEngine.notifyDirectOutputSurfaceAvailable()
            }
        }
    private val rootView =
        FrameLayout(context).apply {
            addView(
                playerView,
                FrameLayout.LayoutParams(
                    FrameLayout.LayoutParams.MATCH_PARENT,
                    FrameLayout.LayoutParams.MATCH_PARENT,
                ),
            )
            addView(
                scrubOverlayView,
                FrameLayout.LayoutParams(
                    FrameLayout.LayoutParams.MATCH_PARENT,
                    FrameLayout.LayoutParams.MATCH_PARENT,
                ),
            )
        }

    init {
        stage5TransportManager.addPlayerObserver(playerObserver)
        stage5TransportManager.addPreviewRetentionObserver(previewRetentionObserver)
        stage5TransportManager.addPreviewOutputSuppressionObserver(
            previewOutputSuppressionObserver,
        )
        stage5TransportManager.addScrubSettlingObserver(scrubSettlingObserver)
        stage5NativeScrubEngine.registerRenderHost(this)
    }

    override fun getView(): View = rootView

    override fun setScrubSurfaceVisible(visible: Boolean) {
        isScrubSurfaceVisible = visible
        runOnUiThreadIfActive {
            scrubOverlayView.setSurfaceVisibilityAlpha(if (visible) 1f else 0f)
            syncPlayerVisibility()
        }
    }

    override fun setScrubContentAspectRatio(aspectRatio: Float?) {
        val normalizedAspectRatio = aspectRatio?.takeIf { it > 0f }
        if (sameAspectRatio(appliedScrubAspectRatio, normalizedAspectRatio)) {
            return
        }
        appliedScrubAspectRatio = normalizedAspectRatio
        runOnUiThreadIfActive(waitForCompletion = true) {
            scrubOverlayView.setContentAspectRatio(normalizedAspectRatio)
        }
    }

    override fun setScrubVisualState(
        transformMatrix3x3: List<Double>?,
        opacity: Double?,
        gaussianBlurSigmaPx: Float?,
        motionBlurDirective: Stage5VisualRuntimeMotionBlurDirective?,
        edgeFillDirective: Stage5VisualRuntimeEdgeFillDirective?,
    ) {
        runtimeTransformMatrix3x3 = transformMatrix3x3
        runtimeOpacity = ((opacity ?: 1.0).coerceIn(0.0, 1.0))
        runtimeGaussianBlurSigmaPx = gaussianBlurSigmaPx?.takeIf { it.isFinite() && it > 0.05f }
        runtimeMotionBlurDirective = motionBlurDirective
        runtimeEdgeFillDirective = edgeFillDirective
        runOnUiThreadIfActive(waitForCompletion = true) {
            val edgeFillOwnsTransform = edgeFillDirective.ownsStage5Transform()
            scrubOverlayView.setRuntimeVisualState(
                transformMatrix3x3 = if (edgeFillOwnsTransform) null else transformMatrix3x3,
                opacity = opacity,
            )
            applyRuntimeStateToPlayerView()
            applyRuntimeEffects()
            syncPlayerVisibility()
        }
    }

    override fun hasScrubOutputSurface(): Boolean = scrubOverlayView.isAvailable

    override fun acquireScrubOutputSurface(): Surface? = scrubOverlayView.acquireOutputSurface()

    override fun releaseScrubOutputSurface() {
        scrubOverlayView.releaseOutputSurface()
    }

    override fun dispose() {
        isDisposed = true
        stage5TransportManager.setPreviewContentSized(false)
        stage5NativeScrubEngine.unregisterRenderHost(this)
        stage5TransportManager.removePlayerObserver(playerObserver)
        stage5TransportManager.removePreviewRetentionObserver(previewRetentionObserver)
        stage5TransportManager.removePreviewOutputSuppressionObserver(
            previewOutputSuppressionObserver,
        )
        stage5TransportManager.removeScrubSettlingObserver(scrubSettlingObserver)
        scrubOverlayView.releaseOutputSurface()
        mainHandler.removeCallbacksAndMessages(null)
        runOnUiThread {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                rootView.setRenderEffect(null)
                playerView.setRenderEffect(null)
                scrubOverlayView.setRenderEffect(null)
            }
            playerView.player = null
        }
    }

    private fun runOnUiThreadIfActive(
        waitForCompletion: Boolean = false,
        action: () -> Unit,
    ) {
        if (isDisposed) {
            return
        }
        if (Looper.myLooper() == Looper.getMainLooper()) {
            if (!isDisposed) {
                action()
            }
            return
        }
        if (!waitForCompletion) {
            mainHandler.post {
                if (!isDisposed) {
                    action()
                }
            }
            return
        }
        val latch = CountDownLatch(1)
        mainHandler.post {
            try {
                if (!isDisposed) {
                    action()
                }
            } finally {
                latch.countDown()
            }
        }
        latch.await(32L, TimeUnit.MILLISECONDS)
    }

    private fun syncPlayerVisibility() {
        val shouldAttachPlayerSurface = !isPreviewOutputSuppressed
        playerView.visibility = if (shouldAttachPlayerSurface) View.VISIBLE else View.INVISIBLE
        val baseAlpha =
            if (shouldAttachPlayerSurface && !isScrubSurfaceVisible && isPlayerContentSized) {
                1f
            } else {
                0f
            }
        playerView.alpha = (baseAlpha * runtimeOpacity.toFloat().coerceIn(0f, 1f)).coerceIn(0f, 1f)
    }

    private fun applyRuntimeStateToPlayerView() {
        if (runtimeEdgeFillDirective.ownsStage5Transform()) {
            resetPlayerRuntimeTransform()
            logRotationStabilityProof(
                fallbackReason = "transform_owned_by_edge_fill_shader",
                matrix = runtimeTransformMatrix3x3,
            )
            return
        }
        val matrixValues = runtimeTransformMatrix3x3
        if (matrixValues == null || matrixValues.size != 9) {
            resetPlayerRuntimeTransform()
            logRotationStabilityProof(
                fallbackReason = "transform_matrix_missing",
                matrix = null,
            )
            return
        }
        if (!isRuntimeMatrixFinite(matrixValues)) {
            resetPlayerRuntimeTransform()
            logRotationStabilityProof(
                fallbackReason = "transform_matrix_invalid",
                matrix = matrixValues,
            )
            return
        }
        val viewWidth = playerView.width.toFloat().coerceAtLeast(1f)
        val viewHeight = playerView.height.toFloat().coerceAtLeast(1f)
        val centerX = viewWidth / 2f
        val centerY = viewHeight / 2f
        val runtimeMatrix = buildCenteredRuntimeTransformMatrix(
            matrixValues = matrixValues,
            centerX = centerX,
            centerY = centerY,
        )
        if (Build.VERSION.SDK_INT >= 29 && runtimeMatrix != null) {
            playerView.translationX = 0f
            playerView.translationY = 0f
            playerView.scaleX = 1f
            playerView.scaleY = 1f
            playerView.rotation = 0f
            playerView.pivotX = centerX
            playerView.pivotY = centerY
            playerView.animationMatrix = runtimeMatrix
        } else {
            val m00 = matrixValues[0].toFloat()
            val m01 = matrixValues[1].toFloat()
            val tx = matrixValues[2].toFloat()
            val m10 = matrixValues[3].toFloat()
            val m11 = matrixValues[4].toFloat()
            val ty = matrixValues[5].toFloat()
            val sx = sqrt((m00 * m00) + (m10 * m10))
            val sy = sqrt((m01 * m01) + (m11 * m11))
            val rotationDegrees = Math.toDegrees(atan2(m10, m00).toDouble()).toFloat()
            clearPlayerAnimationMatrix()
            playerView.pivotX = centerX
            playerView.pivotY = centerY
            playerView.translationX = tx
            playerView.translationY = ty
            playerView.scaleX = if (sx.isFinite()) sx else 1f
            playerView.scaleY = if (sy.isFinite()) sy else 1f
            playerView.rotation = if (rotationDegrees.isFinite()) rotationDegrees else 0f
        }
        logRotationStabilityProof(
            fallbackReason = null,
            matrix = matrixValues,
        )
    }

    private fun applyRuntimeEffects() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) {
            return
        }
        val sigma = (runtimeGaussianBlurSigmaPx ?: 0f).coerceIn(0f, 80f)
        val gaussianEffect =
            if (sigma > 0.05f) {
                RenderEffect.createBlurEffect(
                    sigma,
                    sigma,
                    Shader.TileMode.CLAMP,
                )
            } else {
                null
            }
        val directive = runtimeMotionBlurDirective
        val edgeDirective = normalizeEdgeFillDirectiveForRoot(runtimeEdgeFillDirective)
        val edgeFillResult = edgeFillShaderPass.buildRenderEffect(
            directive = edgeDirective,
            targetWidthPx = rootView.width.toFloat(),
            targetHeightPx = rootView.height.toFloat(),
        )
        val motionBlurResult = motionBlurShaderPass.buildRenderEffect(
            gaussianBlur = gaussianEffect,
            directive = directive,
            targetWidthPx = rootView.width.toFloat(),
            targetHeightPx = rootView.height.toFloat(),
        )
        val chainedResult = runtimeEffectChainBuilder.buildChain(
            edgeFillEffect = edgeFillResult.renderEffect,
            motionThenGaussianEffect = motionBlurResult.renderEffect,
        )
        val renderEffect = chainedResult.renderEffect
        // Apply FX once on the composed Stage5 output surface so edge fill runs
        // against the same visible pixels that contain post-transform gaps.
        rootView.setRenderEffect(renderEffect)
        playerView.setRenderEffect(null)
        scrubOverlayView.setRenderEffect(null)
        if (edgeDirective != null) {
            val overlayConflict = false
            val sourceRectWidth = (edgeDirective.sourceRectRight - edgeDirective.sourceRectLeft)
                .coerceAtLeast(0.0001)
            val sourceRectHeight = (edgeDirective.sourceRectBottom - edgeDirective.sourceRectTop)
                .coerceAtLeast(0.0001)
            val outputWidthPercent = (100.0 / sourceRectWidth).coerceIn(100.0, 1000.0)
            val outputHeightPercent = (100.0 / sourceRectHeight).coerceIn(100.0, 1000.0)
            val sourceMinPxX = edgeDirective.sourceRectLeft * edgeDirective.canvasWidth
            val sourceMinPxY = edgeDirective.sourceRectTop * edgeDirective.canvasHeight
            val sourceMaxPxX = edgeDirective.sourceRectRight * edgeDirective.canvasWidth
            val sourceMaxPxY = edgeDirective.sourceRectBottom * edgeDirective.canvasHeight
            val seamOverlapPx = 1.0
            val featherPx = max(0.5, edgeDirective.softnessPx)
            Log.d(
                "Stage5PreviewPlatformView",
                "TF_EDGE_FILL_PROOF "
                    + "enabled=${edgeDirective.enabled} "
                    + "mode=${edgeDirective.mode} "
                    + "amount=${edgeDirective.amount} "
                    + "overscanScale=${edgeDirective.overscanScale} "
                    + "rendererPath=stage5RuntimeShader "
                    + "sourceProviderMode=currentCompositedSurface "
                    + "renderEffectApplied=${edgeFillResult.renderEffect != null} "
                    + "chainOrder=${chainedResult.chainOrder} "
                    + "stage5Visible=true "
                    + "professionalSurfaceVisible=false "
                    + "overlayConflict=$overlayConflict "
                    + "bitmapAllocationCount=0 "
                    + "mediaMetadataRetrieverUsed=false "
                    + "shaderAllocationCount=${edgeFillResult.shaderAllocationCount} "
                    + "fallbackReason=${edgeFillResult.fallbackReason ?: "none"}",
            )
            Log.d(
                "Stage5PreviewPlatformView",
                "TF_MOTION_TILE_PROOF "
                    + "enabled=${edgeDirective.enabled} "
                    + "outputWidthPercent=${"%.2f".format(outputWidthPercent)} "
                    + "outputHeightPercent=${"%.2f".format(outputHeightPercent)} "
                    + "mirrorEdges=${edgeDirective.isMirrorEdgeMode()} "
                    + "rendererPath=stage5RuntimeShader "
                    + "sourceProviderMode=currentCompositedSurface "
                    + "renderEffectApplied=${edgeFillResult.renderEffect != null} "
                    + "chainOrder=${chainedResult.chainOrder} "
                    + "sourceRect=${edgeDirective.sourceRectLeft},${edgeDirective.sourceRectTop},${edgeDirective.sourceRectRight},${edgeDirective.sourceRectBottom} "
                    + "canvasRect=0,0,${rootView.width},${rootView.height} "
                    + "inverseTransformValid=${edgeDirective.inverseTransformMatrix3x3.size == 9} "
                    + "bitmapAllocationCount=0 "
                    + "mediaMetadataRetrieverUsed=false "
                    + "fallbackReason=${edgeFillResult.fallbackReason ?: "none"}",
            )
            Log.d(
                "Stage5PreviewPlatformView",
                "TF_MOTION_TILE_GAP_PROOF "
                    + "enabled=${edgeDirective.enabled} "
                    + "mode=${edgeDirective.mode} "
                    + "mirrorEdges=${edgeDirective.isMirrorEdgeMode()} "
                    + "outputWidthPercent=${"%.2f".format(outputWidthPercent)} "
                    + "outputHeightPercent=${"%.2f".format(outputHeightPercent)} "
                    + "amount=${edgeDirective.amount} "
                    + "sourceRect=${edgeDirective.sourceRectLeft},${edgeDirective.sourceRectTop},${edgeDirective.sourceRectRight},${edgeDirective.sourceRectBottom} "
                    + "canvasRect=0,0,${rootView.width},${rootView.height} "
                    + "sourceMinPx=${"%.2f".format(sourceMinPxX)},${"%.2f".format(sourceMinPxY)} "
                    + "sourceMaxPx=${"%.2f".format(sourceMaxPxX)},${"%.2f".format(sourceMaxPxY)} "
                    + "seamOverlapPx=${"%.2f".format(seamOverlapPx)} "
                    + "featherPx=${"%.2f".format(featherPx)} "
                    + "overscanApplied=${edgeDirective.overscanScale > 1.0001} "
                    + "inverseTransformValid=${edgeDirective.inverseTransformMatrix3x3.size == 9} "
                    + "rendererPath=stage5RuntimeShader "
                    + "sourceProviderMode=currentVisibleSurface "
                    + "renderEffectApplied=${edgeFillResult.renderEffect != null} "
                    + "sampledOutsideSource=false "
                    + "edgeBlendUsesBlack=false "
                    + "overscanShrinksSource=false "
                    + "bitmapAllocationCount=0 "
                    + "mediaMetadataRetrieverUsed=false "
                    + "fallbackReason=${edgeFillResult.fallbackReason ?: "none"}",
            )
            val fitted = fittedRect(
                viewWidth = rootView.width.toFloat().coerceAtLeast(1f),
                viewHeight = rootView.height.toFloat().coerceAtLeast(1f),
                contentAspectRatio = playerContentAspectRatio ?: appliedScrubAspectRatio,
            )
            Log.d(
                "Stage5PreviewPlatformView",
                "TF_STAGE5_SOURCE_RECT_PROOF "
                    + "rootViewWidth=${rootView.width} "
                    + "rootViewHeight=${rootView.height} "
                    + "playerViewWidth=${playerView.width} "
                    + "playerViewHeight=${playerView.height} "
                    + "fittedContentRectPx=${fitted.left.toInt()},${fitted.top.toInt()},${fitted.right.toInt()},${fitted.bottom.toInt()} "
                    + "shaderContentRectPx=${sourceMinPxX.toInt()},${sourceMinPxY.toInt()},${sourceMaxPxX.toInt()},${sourceMaxPxY.toInt()} "
                    + "validSourceMinPx=${"%.2f".format(sourceMinPxX + 0.5)},${"%.2f".format(sourceMinPxY + 0.5)} "
                    + "validSourceMaxPx=${"%.2f".format(sourceMaxPxX - 0.5)},${"%.2f".format(sourceMaxPxY - 0.5)} "
                    + "contentRectMatchesPlayerFit=true "
                    + "pixelCenterSafe=true "
                    + "fallbackReason=${edgeFillResult.fallbackReason ?: "none"}",
            )
        }
        if (directive != null) {
            val overlayConflict = false
            val positionVelocityPx =
                kotlin.math.sqrt(
                    (directive.directionX * directive.directionX) +
                        (directive.directionY * directive.directionY),
                ) * directive.kernelLengthPx
            val safeMinDimensionPx =
                kotlin.math.min(rootView.width, rootView.height).coerceAtLeast(1).toDouble()
            val rotationTrailPx =
                kotlin.math.abs(directive.radialOmega) * safeMinDimensionPx * 0.35
            val scaleTrailPx =
                kotlin.math.max(
                    kotlin.math.abs(directive.scaleVelocityX),
                    kotlin.math.abs(directive.scaleVelocityY),
                ) * safeMinDimensionPx * 0.25
            val effectiveTrailPx =
                kotlin.math.max(positionVelocityPx, kotlin.math.max(rotationTrailPx, scaleTrailPx))
            Log.d(
                "Stage5PreviewPlatformView",
                "TF_VELOCITY_MB_SLIDER_PROOF "
                    + "amount=${directive.amount} "
                    + "shutterAngle=${directive.shutterAngleDegrees} "
                    + "shutterPhase=${directive.shutterPhase} "
                    + "sampleCount=${directive.sampleCount} "
                    + "maxTrailPx=${directive.maxTrailPx} "
                    + "positionVelocityPx=$positionVelocityPx "
                    + "rotationDeltaRadians=${directive.radialOmega} "
                    + "scaleDeltaX=${directive.scaleVelocityX} "
                    + "scaleDeltaY=${directive.scaleVelocityY} "
                    + "kernelLengthPx=${directive.kernelLengthPx} "
                    + "rotationTrailPx=$rotationTrailPx "
                    + "scaleTrailPx=$scaleTrailPx "
                    + "effectiveTrailPx=$effectiveTrailPx "
                    + "radialOmega=${directive.radialOmega} "
                    + "scaleVelocityX=${directive.scaleVelocityX} "
                    + "scaleVelocityY=${directive.scaleVelocityY} "
                    + "fallbackReason=${motionBlurResult.fallbackReason ?: "none"}",
            )
            Log.d(
                "Stage5PreviewPlatformView",
                "TF_VELOCITY_MB_PROOF "
                    + "enabled=${directive.enabled} "
                    + "amount=${directive.amount} "
                    + "kernelLengthPx=${directive.kernelLengthPx} "
                    + "directionX=${directive.directionX} "
                    + "directionY=${directive.directionY} "
                    + "radialOmega=${directive.radialOmega} "
                    + "scaleVelocityX=${directive.scaleVelocityX} "
                    + "scaleVelocityY=${directive.scaleVelocityY} "
                    + "rotationTrailPx=$rotationTrailPx "
                    + "scaleTrailPx=$scaleTrailPx "
                    + "effectiveTrailPx=$effectiveTrailPx "
                    + "sampleCount=${directive.sampleCount} "
                    + "weightProfile=hann "
                    + "maxTrailPx=${directive.maxTrailPx} "
                    + "shaderPath=stage5RuntimeShader "
                    + "rendererPath=stage5RuntimeShader "
                    + "sourceProviderMode=currentVisibleSurface "
                    + "stage5Visible=true "
                    + "professionalSurfaceVisible=false "
                    + "overlayConflict=$overlayConflict "
                    + "bitmapAllocationCount=0 "
                    + "mediaMetadataRetrieverUsed=false "
                    + "renderEffectApplied=${renderEffect != null} "
                    + "chainOrder=${chainedResult.chainOrder} "
                    + "fallbackReason=${motionBlurResult.fallbackReason ?: "none"}",
            )
            Log.d(
                "Stage5PreviewPlatformView",
                "TF_TRANSFORM_SHUTTER_MB_PROOF "
                    + "adapterMode=${if (isScrubSurfaceVisible) "liveScrub" else if (latestPlayer?.isPlaying == true) "playback" else "preview"} "
                    + "amount=${directive.amount} "
                    + "shutterAngle=${directive.shutterAngleDegrees} "
                    + "shutterPhase=${directive.shutterPhase} "
                    + "sampleCount=${directive.sampleCount} "
                    + "positionDeltaPx=${directive.kernelLengthPx} "
                    + "rotationDeltaRadiansRaw=${directive.radialOmega} "
                    + "rotationDeltaRadiansUsed=${directive.radialOmega} "
                    + "scaleDeltaX=${directive.scaleVelocityX} "
                    + "scaleDeltaY=${directive.scaleVelocityY} "
                    + "usesTransformShutterSampling=true "
                    + "usesVelocityFallback=false "
                    + "tileSafeSampling=${edgeDirective != null} "
                    + "weightProfile=hann "
                    + "weightSum=normalized "
                    + "maxArcLengthPx=$effectiveTrailPx "
                    + "renderEffectApplied=${renderEffect != null} "
                    + "fallbackReason=${motionBlurResult.fallbackReason ?: "none"}",
            )
        }
    }

    private fun resetPlayerRuntimeTransform() {
        clearPlayerAnimationMatrix()
        playerView.translationX = 0f
        playerView.translationY = 0f
        playerView.scaleX = 1f
        playerView.scaleY = 1f
        playerView.rotation = 0f
    }

    private fun clearPlayerAnimationMatrix() {
        if (Build.VERSION.SDK_INT >= 29) {
            playerView.animationMatrix = null
        }
    }

    private fun isRuntimeMatrixFinite(matrixValues: List<Double>): Boolean {
        if (matrixValues.size != 9) {
            return false
        }
        return matrixValues.take(6).all { value -> value.isFinite() }
    }

    private fun buildCenteredRuntimeTransformMatrix(
        matrixValues: List<Double>,
        centerX: Float,
        centerY: Float,
    ): Matrix? {
        if (!isRuntimeMatrixFinite(matrixValues)) {
            return null
        }
        val m00 = matrixValues[0].toFloat()
        val m01 = matrixValues[1].toFloat()
        val tx = matrixValues[2].toFloat()
        val m10 = matrixValues[3].toFloat()
        val m11 = matrixValues[4].toFloat()
        val ty = matrixValues[5].toFloat()
        val centeredTx = tx + centerX - ((m00 * centerX) + (m01 * centerY))
        val centeredTy = ty + centerY - ((m10 * centerX) + (m11 * centerY))
        if (!centeredTx.isFinite() || !centeredTy.isFinite()) {
            return null
        }
        return Matrix().apply {
            setValues(
                floatArrayOf(
                    m00,
                    m01,
                    centeredTx,
                    m10,
                    m11,
                    centeredTy,
                    0f,
                    0f,
                    1f,
                ),
            )
        }
    }

    private fun logRotationStabilityProof(
        fallbackReason: String?,
        matrix: List<Double>?,
    ) {
        val viewWidth = playerView.width.coerceAtLeast(1)
        val viewHeight = playerView.height.coerceAtLeast(1)
        val centerX = viewWidth / 2f
        val centerY = viewHeight / 2f
        val resolvedMatrix = matrix ?: runtimeTransformMatrix3x3
        val centeredMatrixValues = FloatArray(9)
        val centeredMatrix =
            if (resolvedMatrix != null) {
                buildCenteredRuntimeTransformMatrix(
                    matrixValues = resolvedMatrix,
                    centerX = centerX,
                    centerY = centerY,
                )
            } else {
                null
            }
        centeredMatrix?.getValues(centeredMatrixValues)
        val transformedCenterX =
            if (centeredMatrix != null) {
                (centeredMatrixValues[0] * centerX) +
                    (centeredMatrixValues[1] * centerY) +
                    centeredMatrixValues[2]
            } else {
                centerX
            }
        val transformedCenterY =
            if (centeredMatrix != null) {
                (centeredMatrixValues[3] * centerX) +
                    (centeredMatrixValues[4] * centerY) +
                    centeredMatrixValues[5]
            } else {
                centerY
            }
        val centerDeltaPx = hypot(transformedCenterX - centerX, transformedCenterY - centerY)
        val jitterPx =
            if (lastRotationCenterDeltaPx == null) {
                0f
            } else {
                kotlin.math.abs(centerDeltaPx - (lastRotationCenterDeltaPx ?: 0f))
            }
        lastRotationCenterDeltaPx = centerDeltaPx
        val matrixText =
            if (resolvedMatrix == null || resolvedMatrix.size != 9) {
                "none"
            } else {
                resolvedMatrix.joinToString(
                    prefix = "[",
                    postfix = "]",
                    separator = ",",
                ) { value -> "%.6f".format(value) }
            }
        val adapterMode =
            if (isScrubSurfaceVisible) {
                "liveScrub"
            } else if (latestPlayer?.isPlaying == true) {
                "playback"
            } else {
                "preview"
            }
        val surfaceOwner = if (isScrubSurfaceVisible) "scrubOverlayView" else "playerView"
        val contentRect = fittedRectString(
            viewWidth = viewWidth.toFloat(),
            viewHeight = viewHeight.toFloat(),
            contentAspectRatio = playerContentAspectRatio ?: appliedScrubAspectRatio,
        )
        Log.d(
            "Stage5PreviewPlatformView",
            "TF_ROTATION_STABILITY_PROOF "
                + "adapterMode=$adapterMode "
                + "targetClipId=unknown "
                + "viewWidth=$viewWidth "
                + "viewHeight=$viewHeight "
                + "contentRect=$contentRect "
                + "canvasRect=0,0,$viewWidth,$viewHeight "
                + "pivotX=${playerView.pivotX} "
                + "pivotY=${playerView.pivotY} "
                + "rotationDegrees=${playerView.rotation} "
                + "transformMatrix3x3=$matrixText "
                + "centerDeltaPx=$centerDeltaPx "
                + "jitterPx=$jitterPx "
                + "surfaceOwner=$surfaceOwner "
                + "fallbackReason=${fallbackReason ?: "none"}",
        )
    }

    private fun fittedRectString(
        viewWidth: Float,
        viewHeight: Float,
        contentAspectRatio: Float?,
    ): String {
        val rect = fittedRect(
            viewWidth = viewWidth,
            viewHeight = viewHeight,
            contentAspectRatio = contentAspectRatio,
        )
        return "${rect.left.toInt()},${rect.top.toInt()},${rect.right.toInt()},${rect.bottom.toInt()}"
    }

    private fun fittedRect(
        viewWidth: Float,
        viewHeight: Float,
        contentAspectRatio: Float?,
    ): FloatRect {
        if (contentAspectRatio == null || contentAspectRatio <= 0f) {
            return FloatRect(0f, 0f, viewWidth, viewHeight)
        }
        val safeViewHeight = viewHeight.coerceAtLeast(1f)
        val viewAspect = viewWidth / safeViewHeight
        val contentWidth: Float
        val contentHeight: Float
        if (contentAspectRatio > viewAspect) {
            contentWidth = viewWidth
            contentHeight = viewWidth / contentAspectRatio
        } else {
            contentHeight = safeViewHeight
            contentWidth = safeViewHeight * contentAspectRatio
        }
        val left = ((viewWidth - contentWidth) / 2f).coerceAtLeast(0f)
        val top = ((safeViewHeight - contentHeight) / 2f).coerceAtLeast(0f)
        val right = left + contentWidth
        val bottom = top + contentHeight
        return FloatRect(left, top, right, bottom)
    }

    private fun normalizeEdgeFillDirectiveForRoot(
        directive: Stage5VisualRuntimeEdgeFillDirective?,
    ): Stage5VisualRuntimeEdgeFillDirective? {
        val currentDirective = directive ?: return null
        val rootWidth = rootView.width.toFloat().coerceAtLeast(1f)
        val rootHeight = rootView.height.toFloat().coerceAtLeast(1f)
        val fitted = fittedRect(
            viewWidth = rootWidth,
            viewHeight = rootHeight,
            contentAspectRatio = playerContentAspectRatio ?: appliedScrubAspectRatio,
        )
        val normalizedLeft = (fitted.left / rootWidth).coerceIn(0f, 1f).toDouble()
        val normalizedTop = (fitted.top / rootHeight).coerceIn(0f, 1f).toDouble()
        val normalizedRight = (fitted.right / rootWidth).coerceIn(0f, 1f).toDouble()
        val normalizedBottom = (fitted.bottom / rootHeight).coerceIn(0f, 1f).toDouble()
        val rootTransformMatrix = edgeFillRootSpaceTransformMatrix(
            matrixValues = currentDirective.transformMatrix3x3,
            originalCanvasWidth = currentDirective.canvasWidth.toFloat().coerceAtLeast(1f),
            originalCanvasHeight = currentDirective.canvasHeight.toFloat().coerceAtLeast(1f),
            fitted = fitted,
        )
        val rootInverseMatrix =
            rootTransformMatrix?.let(::inverseAffine3x3)
                ?: edgeFillRootSpaceTransformMatrix(
                    matrixValues = currentDirective.inverseTransformMatrix3x3,
                    originalCanvasWidth = currentDirective.canvasWidth.toFloat().coerceAtLeast(1f),
                    originalCanvasHeight = currentDirective.canvasHeight.toFloat().coerceAtLeast(1f),
                    fitted = fitted,
                )
                ?: currentDirective.inverseTransformMatrix3x3
        return currentDirective.copy(
            sourceRectLeft = normalizedLeft,
            sourceRectTop = normalizedTop,
            sourceRectRight = normalizedRight,
            sourceRectBottom = normalizedBottom,
            canvasWidth = rootWidth.toDouble(),
            canvasHeight = rootHeight.toDouble(),
            contentWidth = fitted.width.toDouble(),
            contentHeight = fitted.height.toDouble(),
            transformMatrix3x3 = rootTransformMatrix ?: currentDirective.transformMatrix3x3,
            inverseTransformMatrix3x3 = rootInverseMatrix,
        )
    }

    private fun edgeFillRootSpaceTransformMatrix(
        matrixValues: List<Double>,
        originalCanvasWidth: Float,
        originalCanvasHeight: Float,
        fitted: FloatRect,
    ): List<Double>? {
        if (!isRuntimeMatrixFinite(matrixValues) ||
            originalCanvasWidth <= 0f ||
            originalCanvasHeight <= 0f ||
            fitted.width <= 0f ||
            fitted.height <= 0f
        ) {
            return null
        }
        val sx = fitted.width / originalCanvasWidth
        val sy = fitted.height / originalCanvasHeight
        if (!sx.isFinite() || !sy.isFinite() || sx <= 0f || sy <= 0f) {
            return null
        }
        val a = matrixValues[0]
        val b = matrixValues[1]
        val tx = matrixValues[2]
        val c = matrixValues[3]
        val d = matrixValues[4]
        val ty = matrixValues[5]
        val left = fitted.left.toDouble()
        val top = fitted.top.toDouble()
        val scaleX = sx.toDouble()
        val scaleY = sy.toDouble()
        val rootA = a
        val rootB = b * (scaleX / scaleY)
        val rootC = c * (scaleY / scaleX)
        val rootD = d
        val rootTx = left + (scaleX * tx) - (rootA * left) - (rootB * top)
        val rootTy = top + (scaleY * ty) - (rootC * left) - (rootD * top)
        val rootMatrix = listOf(
            rootA,
            rootB,
            rootTx,
            rootC,
            rootD,
            rootTy,
            0.0,
            0.0,
            1.0,
        )
        return rootMatrix.takeIf { values -> values.take(6).all { value -> value.isFinite() } }
    }

    private fun inverseAffine3x3(matrixValues: List<Double>): List<Double>? {
        if (!isRuntimeMatrixFinite(matrixValues)) {
            return null
        }
        val a = matrixValues[0]
        val b = matrixValues[1]
        val tx = matrixValues[2]
        val c = matrixValues[3]
        val d = matrixValues[4]
        val ty = matrixValues[5]
        val determinant = (a * d) - (b * c)
        if (!determinant.isFinite() || kotlin.math.abs(determinant) < 1e-9) {
            return null
        }
        val invDeterminant = 1.0 / determinant
        val ia = d * invDeterminant
        val ib = -b * invDeterminant
        val ic = -c * invDeterminant
        val id = a * invDeterminant
        val itx = ((b * ty) - (d * tx)) * invDeterminant
        val ity = ((c * tx) - (a * ty)) * invDeterminant
        val inverse = listOf(
            ia,
            ib,
            itx,
            ic,
            id,
            ity,
            0.0,
            0.0,
            1.0,
        )
        return inverse.takeIf { values -> values.take(6).all { value -> value.isFinite() } }
    }

    private fun runOnUiThread(action: () -> Unit) {
        if (Looper.myLooper() == Looper.getMainLooper()) {
            action()
        } else {
            mainHandler.post(action)
        }
    }

    private fun sameAspectRatio(
        left: Float?,
        right: Float?,
    ): Boolean {
        if (left == null || right == null) {
            return left == right
        }
        return kotlin.math.abs(left - right) < 0.0001f
    }

    private fun Stage5VisualRuntimeEdgeFillDirective?.ownsStage5Transform(): Boolean {
        val directive = this ?: return false
        return directive.enabled &&
            directive.amount > 0.001 &&
            !directive.mode.equals("off", ignoreCase = true) &&
            directive.inverseTransformMatrix3x3.size == 9
    }

    private fun Stage5VisualRuntimeEdgeFillDirective.isMirrorEdgeMode(): Boolean {
        return when (mode.lowercase()) {
            "reflect",
            "blurredreflect",
            "blurredbackground",
            "autooverscan" -> true
            else -> false
        }
    }
}
