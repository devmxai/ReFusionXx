# 08 - Regression Triage

Use this checklist when live scrub regresses.

## First Question

Did the change touch any of these files?

```text
fusionx_clean_ui_screen.dart
timeline_panel.dart
native_timeline_scrub_surface.dart
native_preview_surface.dart
live_scrub_preview_sources.dart
stage5_native_transport_controller.dart
MainActivity.kt
Stage5TransportManager.kt
Stage5PreviewPlatformView.kt
Stage5TimelineScrubPlatformView.kt
Stage5NativeScrubEngine.kt
Stage5SurfaceScrubDecoder.kt
Stage5ScrubPreviewProxyManager.kt
Stage5ScrubOverlayTextureView.kt
Stage6ExportManager.kt
```

If yes, assume live scrub is affected until proven otherwise.

## Common Symptoms And Likely Causes

### Only last frame appears after lifting finger

Likely causes:

- active scrub touch events not reaching native view
- native scrub surface missing or hit-test gated out
- Flutter/player settle path working, active native path not working

Check:

```text
NativeTimelineScrubSurface mounted
regions are non-empty
Stage5TimelineScrubPlatformView receives MotionEvent
Stage5NativeScrubEngine.scrubTimelinePosition is called
```

### First scrub after import fails, second/third scrub works

Likely causes:

- descriptors not flushed before first gesture
- preview proxy/source not primed
- playhead moved to a seam or newly inserted clip unexpectedly
- readiness scheduled asynchronously but not awaited where needed

Check:

```text
_flushNativeTimelineScrubConfig
_scheduleScrubFramePreparationForTimelineTracks
awaitTimelineScrubReady
current timeline time after structural edit
```

### Scrub works backward but stutters forward

Likely causes:

- decoder forward path cannot keep up
- proxy not ready and source GOP is heavy
- exactness policy rejects usable near frames

Check:

```text
Stage5SurfaceScrubDecoder.renderToPosition
Stage5ScrubPreviewProxyManager.resolvePlaybackUri
proxy readiness
source/proxy URI switching
```

### Scrub geometry differs from normal preview

Likely causes:

- source dimensions not passed correctly
- overlay aspect transform differs from playback preview transform
- second clip aspect ratio not reflected in scrub descriptor

Check:

```text
LiveScrubPreviewSourceDescriptor.sourceWidth/sourceHeight
Stage5ScrubOverlayTextureView.setContentAspectRatio
Stage5PreviewPlatformView scrub overlay sizing
```

### Slow scrub jitters at high or normal timeline zoom

Likely causes:

- Flutter UI follow depends only on native millisecond samples, so slow finger
  movement quantizes into visible forward/back jumps
- a visual transform layer moves the timeline while `ScrollController` stays at
  an older offset
- active scrub receives two competing UI time writers: pointer delta and native
  sample callbacks
- scrub config is stale at touch start, so native start time and Flutter display
  time disagree

Check:

```text
TimelinePanel pointer-delta scrub handoff
_handleNativeScrubStart anchor time
_handleGlobalPointerMove during _isNativeScrubbing
_applyNativeScrubUiTime drives ScrollController directly
NativeTimelineScrubSurface does not push config during active scrub
```

Rule:

```text
Native remains the active frame renderer.
Flutter timeline chrome should follow pointer delta during active scrub.
Native scrubTimeChanged samples are fallback UI timing when pointer ownership is
not available, not a second competing UI writer.
```

### Black flash or wrong final frame on lift

Likely causes:

- overlay hides before player catches up
- final settle races with scrub overlay output
- transport seek fights scrub final position

Check:

```text
Stage5TransportManager.settleAfterScrub
scrub settling observer
NativePreviewSurface frame-loss behavior
Stage5PreviewPlatformView overlay visibility
```

## Golden Comparison

Always compare against:

```bash
git clone https://github.com/devmxai/refusion-stable-live-scrub-beta10.git
cd refusion-stable-live-scrub-beta10
git checkout stable-live-scrub-beta10
```

Then inspect diffs for the files listed above.

## Triage Rule

Do not change more than one scrub boundary at a time.

Preferred order:

1. verify Flutter hit-test/regions
2. verify descriptor contents
3. verify native MotionEvent entry
4. verify engine target mapping
5. verify decoder URI and frame render
6. verify final settle handoff
