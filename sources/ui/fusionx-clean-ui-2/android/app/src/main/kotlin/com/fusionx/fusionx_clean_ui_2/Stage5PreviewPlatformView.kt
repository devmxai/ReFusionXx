package com.refusion.app

import android.content.Context
import android.graphics.Color
import android.graphics.RenderEffect
import android.graphics.Shader
import android.os.Build
import android.os.Handler
import android.os.Looper
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

class Stage5PreviewPlatformView(
    context: Context,
    private val stage5TransportManager: Stage5TransportManager,
    private val stage5NativeScrubEngine: Stage5NativeScrubEngine,
) : PlatformView, Stage5ScrubRenderHost {
    private val mainHandler = Handler(Looper.getMainLooper())
    private var latestPlayer: Player? = null
    private var isPreviewOutputSuppressed = false
    private var isScrubSurfaceVisible = false
    private var isPlayerContentSized = false
    @Volatile
    private var appliedScrubAspectRatio: Float? = null
    @Volatile
    private var isDisposed = false
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
    private val previewTransitionEffectObserver: (Stage5PreviewTransitionEffects) -> Unit = { effects ->
        runOnUiThreadIfActive {
            applyPreviewTransitionEffects(effects)
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
            setBackgroundColor(Color.BLACK)
            setShutterBackgroundColor(Color.BLACK)
            setKeepContentOnPlayerReset(true)
            alpha = 0f
            setAspectRatioListener { contentAspectRatio, _, _ ->
                // A mismatch only means the media and viewport have different
                // aspect ratios; RESIZE_MODE_FIT handles that with letterboxing.
                // Treating it as "not sized" hides valid video and exposes the
                // black preview background on clips with a different shape.
                val sized = contentAspectRatio > 0f
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
            setBackgroundColor(Color.BLACK)
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
        stage5TransportManager.addPreviewTransitionEffectObserver(
            previewTransitionEffectObserver,
        )
        stage5NativeScrubEngine.registerRenderHost(this)
    }

    override fun getView(): View = rootView

    override fun setScrubSurfaceVisible(visible: Boolean) {
        isScrubSurfaceVisible = visible
        runOnUiThreadIfActive {
            scrubOverlayView.alpha = if (visible) 1f else 0f
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
        stage5TransportManager.removePreviewTransitionEffectObserver(
            previewTransitionEffectObserver,
        )
        scrubOverlayView.releaseOutputSurface()
        mainHandler.removeCallbacksAndMessages(null)
        runOnUiThread {
            clearPreviewTransitionEffects()
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
        playerView.alpha =
            if (shouldAttachPlayerSurface && !isScrubSurfaceVisible && isPlayerContentSized) {
                1f
            } else {
                0f
            }
    }

    private fun applyPreviewTransitionEffects(effects: Stage5PreviewTransitionEffects) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) {
            return
        }
        val sigma = effects.blurSigmaPx.coerceIn(0f, 64f)
        val renderEffect =
            if (sigma > 0.05f) {
                RenderEffect.createBlurEffect(sigma, sigma, Shader.TileMode.CLAMP)
            } else {
                null
            }
        playerView.setRenderEffect(renderEffect)
        playerView.videoSurfaceView?.setRenderEffect(renderEffect)
        scrubOverlayView.setRenderEffect(renderEffect)
    }

    private fun clearPreviewTransitionEffects() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) {
            return
        }
        playerView.setRenderEffect(null)
        playerView.videoSurfaceView?.setRenderEffect(null)
        scrubOverlayView.setRenderEffect(null)
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
}
