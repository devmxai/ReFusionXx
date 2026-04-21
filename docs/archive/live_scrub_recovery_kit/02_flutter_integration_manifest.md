# 02 - Flutter Integration Manifest

Flutter is responsible for timeline truth, media descriptors, viewport regions,
and final scrub callbacks. Flutter must not draw active scrub frames and must
not dispatch per-frame player seeks during active live scrub.

## Required Flutter Concepts

### LiveScrubPreviewSourceDescriptor

File:

```text
lib/core/engine/live_scrub_preview_sources.dart
```

Purpose:

- describes each timeline clip to the native scrub engine
- carries source URI, optional preview URI, timeline window, source window,
  playback rate, and source dimensions
- is serialized to the Android platform view config

Fields that must remain semantically stable:

```text
sourceId
scrubStoreKey
sourceUri
previewUri
timelineStartMs
timelineEndMs
sourceStartMs
sourceDurationMs
playbackRate
sourceWidth
sourceHeight
```

### NativeTimelineScrubSurface

File:

```text
lib/features/editor/presentation/widgets/native_timeline_scrub_surface.dart
```

Responsibilities:

- hosts the Android platform view `com.refusion.app/stage5_timeline_scrub`
- sends immutable scrub config snapshots to native
- forwards only high-level callbacks back to Flutter:
  - `scrubStart`
  - `scrubTimeChanged`
  - `scrubEnd`
- gates hit testing to configured scrub regions

It must not:

- render frames in Flutter
- call player seek per move
- mutate timeline data during native touch move

### Stage5NativeTransportController

File:

```text
lib/core/engine/stage5_native_transport_controller.dart
```

Required scrub methods:

```text
primeScrubPreviewSources(...)
awaitTimelineScrubReady(...)
settleAfterScrubPositionMs(...)
```

These methods are bridge calls. They are not the active frame renderer.

## Required FusionXCleanUiScreen Responsibilities

File:

```text
lib/features/editor/presentation/screens/fusionx_clean_ui_screen.dart
```

Required responsibilities:

- build `LiveScrubPreviewSourceDescriptor` list from current timeline clips
- keep current timeline position synchronized
- pause playback on scrub start
- update timeline time on scrub time changed
- call final settle once on scrub end
- prime native scrub readiness after imports and structural timeline edits

Critical methods to port or preserve:

```text
_buildLiveScrubPreviewSourceDescriptors
_scheduleScrubFramePreparationForTimelineTracks
_flushNativeTimelineScrubConfig
_awaitNativeTimelineScrubReadiness
_handleScrubStateChanged
_handleTimelineTimeChanged
_handleTimelineScrubFinalized
_syncVideoTimelineTransport
```

## Required TimelinePanel Responsibilities

File:

```text
lib/features/editor/presentation/widgets/timeline_panel.dart
```

Required responsibilities:

- compute scrub regions over the timeline viewport
- mount `NativeTimelineScrubSurface` over allowed timeline areas
- keep selection, trim, reorder, and scale gestures from fighting native scrub
- forward native scrub callbacks upward

Critical methods/areas:

```text
_buildUnifiedNativeScrubRegions
_buildUnifiedNativeScrubOverlay
_handleNativeScrubStart
_handleNativeScrubTimeChanged
_handleNativeScrubEnd
scrubSurfaceBuilder
```

## Integration Rule

Flutter owns configuration and final state. Native owns active gesture
rendering. If a future feature breaks this split, live scrub quality will
regress.

