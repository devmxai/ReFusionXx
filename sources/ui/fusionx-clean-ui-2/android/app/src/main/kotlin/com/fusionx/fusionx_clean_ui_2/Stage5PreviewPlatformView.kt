package com.refusion.app

import android.content.Context
import android.graphics.Color
import android.graphics.Matrix
import android.os.Handler
import android.os.Looper
import android.os.Build
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
import kotlin.math.sqrt

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
    private var runtimeTransformMatrix3x3: List<Double>? = null
    private var runtimeOpacity = 1.0
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
    ) {
        runtimeTransformMatrix3x3 = transformMatrix3x3
        runtimeOpacity = ((opacity ?: 1.0).coerceIn(0.0, 1.0))
        runOnUiThreadIfActive(waitForCompletion = true) {
            scrubOverlayView.setRuntimeVisualState(
                transformMatrix3x3 = transformMatrix3x3,
                opacity = opacity,
            )
            applyRuntimeStateToPlayerView()
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
        playerView.alpha =
            (baseAlpha * runtimeOpacity.toFloat().coerceIn(0f, 1f)).coerceIn(0f, 1f)
    }

    private fun applyRuntimeStateToPlayerView() {
        val matrixValues = runtimeTransformMatrix3x3
        if (matrixValues == null || matrixValues.size != 9) {
            if (Build.VERSION.SDK_INT >= 29) {
                playerView.animationMatrix = null
            } else {
                playerView.translationX = 0f
                playerView.translationY = 0f
                playerView.scaleX = 1f
                playerView.scaleY = 1f
                playerView.rotation = 0f
            }
            return
        }
        val m00 = matrixValues[0].toFloat()
        val m01 = matrixValues[1].toFloat()
        val tx = matrixValues[2].toFloat()
        val m10 = matrixValues[3].toFloat()
        val m11 = matrixValues[4].toFloat()
        val ty = matrixValues[5].toFloat()
        if (!m00.isFinite() || !m01.isFinite() || !tx.isFinite() ||
            !m10.isFinite() || !m11.isFinite() || !ty.isFinite()
        ) {
            return
        }
        val viewWidth = playerView.width.toFloat().coerceAtLeast(1f)
        val viewHeight = playerView.height.toFloat().coerceAtLeast(1f)
        val centerX = viewWidth / 2f
        val centerY = viewHeight / 2f
        val matrix =
            Matrix().apply {
                setValues(
                    floatArrayOf(
                        m00,
                        m01,
                        tx,
                        m10,
                        m11,
                        ty,
                        0f,
                        0f,
                        1f,
                    ),
                )
                postTranslate(
                    centerX - (m00 * centerX + m01 * centerY),
                    centerY - (m10 * centerX + m11 * centerY),
                )
            }
        if (Build.VERSION.SDK_INT >= 29) {
            playerView.animationMatrix = matrix
            return
        }
        val values = FloatArray(9)
        matrix.getValues(values)
        val sx = sqrt((values[0] * values[0]) + (values[3] * values[3]))
        val sy = sqrt((values[1] * values[1]) + (values[4] * values[4]))
        val rotationDegrees = Math.toDegrees(atan2(values[3], values[0]).toDouble()).toFloat()
        playerView.pivotX = centerX
        playerView.pivotY = centerY
        playerView.translationX = values[2]
        playerView.translationY = values[5]
        playerView.scaleX = if (sx.isFinite()) sx else 1f
        playerView.scaleY = if (sy.isFinite()) sy else 1f
        playerView.rotation = if (rotationDegrees.isFinite()) rotationDegrees else 0f
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
