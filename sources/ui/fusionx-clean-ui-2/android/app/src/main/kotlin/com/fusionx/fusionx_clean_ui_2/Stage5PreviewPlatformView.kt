package com.refusion.app

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Color
import android.view.View
import android.widget.FrameLayout
import androidx.media3.common.Player
import androidx.media3.ui.AspectRatioFrameLayout
import androidx.media3.ui.PlayerView
import io.flutter.plugin.platform.PlatformView

class Stage5PreviewPlatformView(
    context: Context,
    private val stage5TransportManager: Stage5TransportManager,
    private val stage5NativeScrubEngine: Stage5NativeScrubEngine,
) : PlatformView, Stage5ScrubRenderHost {
    private var latestPlayer: Player? = null
    private var isPreviewOutputSuppressed = false
    private val playerObserver: (Player) -> Unit = { updatedPlayer ->
        latestPlayer = updatedPlayer
        if (!isPreviewOutputSuppressed) {
            playerView.player = updatedPlayer
        }
    }
    private val previewRetentionObserver: (Boolean) -> Unit = { shouldRetain ->
        playerView.setKeepContentOnPlayerReset(shouldRetain)
    }
    private val previewOutputSuppressionObserver: (Boolean) -> Unit = { shouldSuppress ->
        isPreviewOutputSuppressed = shouldSuppress
        playerView.player =
            if (shouldSuppress) {
                null
            } else {
                latestPlayer ?: stage5TransportManager.player
            }
    }

    private val playerView =
        PlayerView(context).apply {
            useController = false
            resizeMode = AspectRatioFrameLayout.RESIZE_MODE_FIT
            setShutterBackgroundColor(Color.TRANSPARENT)
            setKeepContentOnPlayerReset(true)
            latestPlayer = stage5TransportManager.player
            player = latestPlayer
        }
    private val scrubOverlayView =
        Stage5ScrubOverlayTextureView(context).apply {
            visibility = View.INVISIBLE
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
        stage5NativeScrubEngine.registerRenderHost(this)
    }

    override fun getView(): View = rootView

    override fun setScrubSurfaceVisible(visible: Boolean) {
        rootView.post {
            scrubOverlayView.visibility = if (visible) View.VISIBLE else View.INVISIBLE
            val shouldShowPlayer = !visible && !isPreviewOutputSuppressed
            playerView.visibility = if (shouldShowPlayer) View.VISIBLE else View.INVISIBLE
        }
    }

    override fun presentScrubFrame(bitmap: Bitmap) {
        scrubOverlayView.presentFrame(bitmap)
        rootView.post {
            scrubOverlayView.visibility = View.VISIBLE
            playerView.visibility = View.INVISIBLE
        }
    }

    override fun dispose() {
        stage5NativeScrubEngine.unregisterRenderHost(this)
        stage5TransportManager.removePlayerObserver(playerObserver)
        stage5TransportManager.removePreviewRetentionObserver(previewRetentionObserver)
        stage5TransportManager.removePreviewOutputSuppressionObserver(
            previewOutputSuppressionObserver,
        )
        playerView.player = null
    }
}
