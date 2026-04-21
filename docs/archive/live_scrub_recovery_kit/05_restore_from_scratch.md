# 05 - Restore From Scratch

Use this when restoring live scrub into a clean project or after a regression.

## Step 0 - Acquire The Reference

```bash
git clone https://github.com/devmxai/refusion-stable-live-scrub-beta10.git
cd refusion-stable-live-scrub-beta10
git checkout stable-live-scrub-beta10
```

Reference app root:

```text
sources/ui/fusionx-clean-ui-2
```

## Step 1 - Prepare Destination Project

The destination must have:

- Flutter Android app
- Android package id decided
- Kotlin Android embedding
- Media3 ExoPlayer dependency
- Media3 Transformer dependency if scrub proxy generation is retained
- Android platform views enabled through Flutter embedding

If the package id is not `com.refusion.app`, update platform view type strings
consistently.

Required platform view type:

```text
<package-id>/stage5_timeline_scrub
```

Current baseline value:

```text
com.refusion.app/stage5_timeline_scrub
```

## Step 2 - Copy Native Core

Copy native engine files:

```bash
cp Stage5NativeScrubEngine.kt <dest>/android/app/src/main/kotlin/<package_path>/
cp Stage5SurfaceScrubDecoder.kt <dest>/android/app/src/main/kotlin/<package_path>/
cp Stage5TimelineScrubPlatformView.kt <dest>/android/app/src/main/kotlin/<package_path>/
cp Stage5ScrubOverlayTextureView.kt <dest>/android/app/src/main/kotlin/<package_path>/
cp Stage5ScrubRenderHost.kt <dest>/android/app/src/main/kotlin/<package_path>/
cp Stage5ScrubPreviewProxyManager.kt <dest>/android/app/src/main/kotlin/<package_path>/
```

Then update the Kotlin package declaration if the destination package differs.

## Step 3 - Wire Native Hosts

In `MainActivity`:

- instantiate `Stage5ScrubPreviewProxyManager`
- instantiate `Stage5NativeScrubEngine`
- register `Stage5TimelineScrubPlatformViewFactory`
- expose `primeScrubPreviewSources`
- expose `awaitTimelineScrubReady`
- expose `settleAfterScrub`
- release scrub engine/proxy manager on activity cleanup

In the native preview platform view:

- create `Stage5ScrubOverlayTextureView`
- implement `Stage5ScrubRenderHost`
- attach overlay above playback view
- preserve aspect ratio transform
- show overlay during active scrub/settle and hide it after safe handoff

## Step 4 - Copy Flutter Bridge

Copy:

```bash
cp live_scrub_preview_sources.dart <dest>/lib/core/engine/
cp native_timeline_scrub_surface.dart <dest>/lib/features/editor/presentation/widgets/
```

Then port scrub bridge methods from:

```text
stage5_native_transport_controller.dart
```

Required methods:

```text
primeScrubPreviewSources
awaitTimelineScrubReady
settleAfterScrubPositionMs
```

## Step 5 - Integrate Timeline Host

In the destination timeline UI:

- mount `NativeTimelineScrubSurface` above the timeline interactive layer
- pass visible scrub regions
- pass current timeline position
- pass timeline duration
- pass `secondsPerPixel` or equivalent mapping
- pass preview source descriptors
- forward callbacks:
  - scrub start
  - scrub time changed
  - scrub end

Do not send touch moves through Flutter per frame.

## Step 6 - Integrate Media Descriptors

For every clip, build a descriptor with:

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

The descriptor must be stable for the same clip unless the clip's media window
or source changes.

## Step 7 - Integrate Final Settle

On scrub end:

```text
update timeline current time
call settleAfterScrubPositionMs(finalPositionMs)
do not call per-frame seek retroactively
```

## Step 8 - Run Validation

Run the full matrix in:

```text
06_validation_matrix.md
```

Do not declare the restore complete until all required checks pass.

