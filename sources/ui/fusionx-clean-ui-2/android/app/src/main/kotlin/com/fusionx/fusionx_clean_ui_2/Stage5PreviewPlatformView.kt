package com.refusion.app

import android.content.Context
import android.graphics.Color
import android.view.View
import androidx.media3.common.Player
import androidx.media3.ui.AspectRatioFrameLayout
import androidx.media3.ui.PlayerView
import io.flutter.plugin.platform.PlatformView

class Stage5PreviewPlatformView(
    context: Context,
    private val stage5TransportManager: Stage5TransportManager,
) : PlatformView {
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

    init {
        stage5TransportManager.addPlayerObserver(playerObserver)
        stage5TransportManager.addPreviewRetentionObserver(previewRetentionObserver)
        stage5TransportManager.addPreviewOutputSuppressionObserver(
            previewOutputSuppressionObserver,
        )
    }

    override fun getView(): View = playerView

    override fun dispose() {
        stage5TransportManager.removePlayerObserver(playerObserver)
        stage5TransportManager.removePreviewRetentionObserver(previewRetentionObserver)
        stage5TransportManager.removePreviewOutputSuppressionObserver(
            previewOutputSuppressionObserver,
        )
        playerView.player = null
    }
}
