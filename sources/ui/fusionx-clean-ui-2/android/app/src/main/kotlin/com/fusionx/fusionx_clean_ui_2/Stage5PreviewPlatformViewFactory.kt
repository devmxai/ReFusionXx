package com.refusion.app

import android.content.Context
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory

class Stage5PreviewPlatformViewFactory(
    private val stage5TransportManager: Stage5TransportManager,
    private val stage5NativeScrubEngine: Stage5NativeScrubEngine,
) : PlatformViewFactory(StandardMessageCodec.INSTANCE) {
    override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
        return Stage5PreviewPlatformView(
            context,
            stage5TransportManager,
            stage5NativeScrubEngine,
        )
    }
}
