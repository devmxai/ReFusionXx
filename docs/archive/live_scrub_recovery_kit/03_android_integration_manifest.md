# 03 - Android Integration Manifest

Android owns active live scrub. The current baseline uses a native platform
view for touch capture and a dedicated decoder-backed overlay for frame output.

## MainActivity Registration

File:

```text
android/app/src/main/kotlin/com/fusionx/fusionx_clean_ui_2/MainActivity.kt
```

Required objects:

```text
Stage5ScrubPreviewProxyManager
Stage5NativeScrubEngine
Stage5TransportManager
Stage5PreviewPlatformViewFactory
Stage5TimelineScrubPlatformViewFactory
```

Required platform view registration:

```text
com.refusion.app/stage5_native_preview
com.refusion.app/stage5_timeline_scrub
```

Required MethodChannel calls:

```text
primeScrubPreviewSources
awaitTimelineScrubReady
settleAfterScrub
```

## Stage5TimelineScrubPlatformView

File:

```text
Stage5TimelineScrubPlatformView.kt
```

Responsibilities:

- parse Flutter scrub config
- receive Android `MotionEvent`
- convert x-position to timeline position
- call `Stage5NativeScrubEngine.scrubTimelinePosition(...)`
- emit only high-level callbacks to Flutter

It must not:

- call ExoPlayer directly
- call transport seek directly
- render through Flutter

## Stage5NativeScrubEngine

File:

```text
Stage5NativeScrubEngine.kt
```

Responsibilities:

- own active scrub session state
- resolve timeline position to active descriptor
- map timeline time to source time
- request preview proxy media
- configure and drive `Stage5SurfaceScrubDecoder`
- present output through `Stage5ScrubRenderHost`
- warm current and adjacent descriptors near boundaries

The engine is stateful. Do not call it from multiple owners.

## Stage5SurfaceScrubDecoder

File:

```text
Stage5SurfaceScrubDecoder.kt
```

Responsibilities:

- own `MediaExtractor`
- own `MediaCodec`
- decode into a native `Surface`
- seek/render source positions during active scrub

This is the hot path. Do not add blocking metadata work, Transformer export
work, or player coordination here.

## Stage5ScrubPreviewProxyManager

File:

```text
Stage5ScrubPreviewProxyManager.kt
```

Responsibilities:

- prepare low-latency proxy media for scrub
- resolve playback URI for the scrub decoder
- notify `Stage5NativeScrubEngine` when proxy media is ready

Proxy policy changes are high risk. Any change here can make scrub fall back
to heavy original media and degrade immediately.

## Stage5PreviewPlatformView

File:

```text
Stage5PreviewPlatformView.kt
```

Responsibilities:

- host the playback `PlayerView`
- host `Stage5ScrubOverlayTextureView`
- expose `Stage5ScrubRenderHost`
- toggle scrub overlay visibility during active scrub and settle

The overlay must visually match preview aspect handling. If preview geometry is
changed, scrub overlay geometry must be validated in the same change.

## Stage5TransportManager

File:

```text
Stage5TransportManager.kt
```

Transport owns normal playback and final settle. It must not become the active
scrub renderer.

Allowed scrub-related responsibility:

```text
settleAfterScrub(positionMs)
```

Forbidden during active scrub:

```text
player.seekTo(...)
player.setMediaItem(...)
player.setMediaItems(...)
player.prepare()
```

