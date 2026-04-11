# Stage 5B Professional Scrub Upgrade

Status: `CLOSED`

## Scope

- solve the scrub-preview quality problem inside `Stage 5`
- keep the scope limited to the fixed native sample
- do not open `Stage 6`
- do not add real import, timeline truth, BMFLite processing, or export work in this slice

## Stage 5B Exit Gate

`Stage 5B` may be marked complete only when all of the following are true on the fixed native sample:

- play remains stable before and after scrub sessions
- drag scrubbing updates preview visibly during drag, not only after release
- no `play/pause` oscillation or transport-state drift is observed
- no large mid-clip regions collapse back to frame `0`
- docs explicitly record that:
  - `Stage 5B` is closed
  - full `Stage 5` is still open until the remaining non-scrub Stage 5 scope is completed

## Why This Slice Exists

- the current `Stage 5` slice proved:
  - native preview ownership works
  - play works
  - final settle seek works
- the current `Stage 5` slice did **not** close professional scrub quality
- the documented scrub investigation shows why:
  - current stack is pinned to `Media3 1.1.1`
  - current stack lacks newer official scrubbing APIs
  - current fixed sample has sparse keyframes
  - sync-seeking during drag can resolve to frame `0`

References:

- [stage-5-scrub-investigation.md](/Users/mx/Documents/InGeneBMFPro/docs/research/stage-5-scrub-investigation.md)
- [stage-5-native-transport-and-preview-integration.md](/Users/mx/Documents/InGeneBMFPro/docs/process/stage-5-native-transport-and-preview-integration.md)

## Official Foundations

- `Media3 1.8.0` introduces official scrubbing mode APIs
- `Media3 1.8.0` requires `minCompileSdk=35`
- `Media3 1.8.0` also requires `minSdk 21`
- official Android guidance requires `AGP 8.6.0+` for `compileSdk 35`
- official Media3 frame-extraction guidance exists for seek-bar and editing previews

Primary references:

- [Media3 release notes](https://developer.android.com/jetpack/androidx/releases/media3)
- [ExoPlayer API](https://developer.android.com/reference/androidx/media3/exoplayer/ExoPlayer)
- [ScrubbingModeParameters](https://developer.android.com/reference/androidx/media3/exoplayer/ScrubbingModeParameters)
- [SeekParameters](https://developer.android.com/reference/androidx/media3/exoplayer/SeekParameters)
- [Why is seeking in my video slow?](https://developer.android.com/media/media3/exoplayer/troubleshooting#why-is-seeking-in-my-video-slow)
- [Extract video frames](https://developer.android.com/media/media3/inspector/extract-frames)
- [About AGP](https://developer.android.com/build/releases/about-agp)
- [AGP 8.6.0 release notes](https://developer.android.com/build/releases/past-releases/agp-8-6-0-release-notes)

## Strict Boundaries

- Flutter remains host/presenter only
- native Android / Media3 remains transport authority
- `PlayerView` preview path stays in place for the first pass
- no renderer rewrite in the first pass
- no proxy-generation pipeline in the first pass
- no user-media import in the first pass

## Migration Impact Map

Primary files expected to change:

- [android/settings.gradle](/Users/mx/Documents/InGeneBMFPro/sources/ui/fusionx-clean-ui-2/android/settings.gradle)
- [android/build.gradle](/Users/mx/Documents/InGeneBMFPro/sources/ui/fusionx-clean-ui-2/android/build.gradle)
- [android/app/build.gradle](/Users/mx/Documents/InGeneBMFPro/sources/ui/fusionx-clean-ui-2/android/app/build.gradle)
- [Stage5TransportManager.kt](/Users/mx/Documents/InGeneBMFPro/sources/ui/fusionx-clean-ui-2/android/app/src/main/kotlin/com/fusionx/fusionx_clean_ui_2/Stage5TransportManager.kt)
- [stage5_native_transport_controller.dart](/Users/mx/Documents/InGeneBMFPro/sources/ui/fusionx-clean-ui-2/lib/core/engine/stage5_native_transport_controller.dart)
- [fusionx_clean_ui_screen.dart](/Users/mx/Documents/InGeneBMFPro/sources/ui/fusionx-clean-ui-2/lib/features/editor/presentation/screens/fusionx_clean_ui_screen.dart)
- [timeline_panel.dart](/Users/mx/Documents/InGeneBMFPro/sources/ui/fusionx-clean-ui-2/lib/features/editor/presentation/widgets/timeline_panel.dart)
- [native_media_thumbnailer.dart](/Users/mx/Documents/InGeneBMFPro/sources/ui/fusionx-clean-ui-2/lib/core/media/native_media_thumbnailer.dart)

## Phase Plan

### Phase 0 - Freeze Stage 5A Baseline

Goal:

- freeze the current slice as the comparison baseline before changing the toolchain

Tasks:

- keep the current fixed-sample native transport path unchanged
- keep `Add` and clip-edit controls disabled in sample mode
- preserve the current sample timeline representation
- record one device-baseline observation for:
  - play stability
  - current scrub behavior
  - current timeline visibility behavior

Exit gate:

- current Stage 5A baseline is documented and reproducible
- `flutter analyze` passes

### Phase 1 - Android Toolchain Uplift

Goal:

- raise the Android build stack to the minimum official level that can adopt newer Media3 scrubbing APIs

Tasks:

- upgrade AGP to a version officially supporting `compileSdk 35`
- upgrade Gradle wrapper to the version required by that AGP
- align Kotlin/JVM settings with the upgraded Android stack
- raise compile SDK to `35`
- rebuild the app before changing scrub logic

Strict rule:

- upgrade only to the minimum official toolchain level required to unlock Media3 scrubbing mode
- do not change scrub behavior in this phase
- do not change preview renderer in this phase

Exit gate:

- project builds and installs with the upgraded toolchain
- current Stage 5 sample still plays correctly after the toolchain uplift

Implementation status:

- completed locally
- applied versions:
  - AGP `8.6.0`
  - Gradle `8.7`
  - Kotlin plugin `1.9.24`
  - Java target `17`
  - `compileSdk 35`
  - `targetSdk 35`
  - `minSdk 21`
  - `Media3 1.8.0`
- local verification:
  - `flutter analyze` passed
  - `./gradlew :app:assembleDebug` passed
  - rebuilt APK installed successfully on device `R3CT10LKLSX`

### Phase 2 - Replace Hand-Rolled Scrub Logic With Official Media3 Scrubbing

Goal:

- replace the current `CLOSEST_SYNC` / `EXACT` fallback flow with official native scrubbing APIs

Tasks:

- update Media3 dependencies to a scrubbing-capable official version
- switch native drag lifecycle to:
  - `setScrubbingModeEnabled(true)` on drag start
  - `setScrubbingModeEnabled(false)` on drag end
- start with `ScrubbingModeParameters.DEFAULT`
- simplify Flutter-side scrub dispatch so Flutter does not fight native transport ownership
- preserve one final settle seek only if on-device behavior proves it is still needed

Exit gate:

- during drag, preview updates visibly on-device before release
- no `play/pause` oscillation returns
- no large mid-clip region falls back to frame `0`
- play resumes deterministically after scrub release

Implementation status:

- completed locally, pending device acceptance
- applied changes:
  - native transport now enters scrubbing mode with `setScrubbingModeEnabled(true)` on drag start
  - native transport exits scrubbing mode with `setScrubbingModeEnabled(false)` on drag end
  - native transport now starts from `ScrubbingModeParameters.DEFAULT`
  - final settle seek moved into native transport on scrub release
  - the extra Flutter-side scrub timer layer was removed so Flutter no longer double-throttles native seeks
  - one bounded `~16ms` coalescing layer remains in `TimelinePanel` as the single active Flutter-side dispatch limiter

### Phase 3 - Add Professional Timeline Preview Support

Goal:

- improve scrub usability and visual confidence without pretending exact decode on every raw delta

Tasks:

- turn the current thumbnail seam into a real native-backed thumbnail pipeline
- prefer official Media3 frame extraction if the chosen Media3 version supports it in our toolchain target
- otherwise use official Android `MediaMetadataRetriever` as the bounded fallback
- cache and reuse thumbnails for the fixed sample timeline

Strict rule:

- this phase is optional for the first proof of live scrub
- do not start this phase until native scrubbing mode is proven on-device in `Phase 2`

Exit gate:

- the sample clip shows real filmstrip thumbnails
- filmstrip generation is async and cached
- timeline preview remains truthful to the fixed-sample scope

### Phase 4 - Physical Device Validation

Goal:

- validate scrub quality on a real Android device only

Tasks:

- test on physical device in profile or debug as appropriate
- verify:
  - cold launch
  - stable play/pause
  - tap seek
  - slow forward scrub
  - slow backward scrub
  - scrub while playing
  - extended scrub session without drift or ANR
- keep evidence:
  - one screen recording
  - one `logcat` capture
  - README update

Exit gate:

- scrub behavior is accepted as professional enough for the fixed-sample Stage 5 scope
- no transport-state drift is observed
- docs are updated before any move toward `Stage 6`

Implementation status:

- completed and accepted on physical device `R3CT10LKLSX`
- user acceptance date: `2026-04-06`
- accepted result:
  - scrub now works well and is considered professional enough for the current fixed-sample scope
  - the result is not claimed as perfect `100%`, but it is accepted and closed for this slice
- explicit deferral kept:
  - `Phase 3` thumbnail filmstrip support remains deferred

## Explicit Deferrals

- real gallery import
- real timeline truth
- BMFLite processing/effects integration in the transport path
- export
- proxy generation for user media
- shuttle/JKL mode as a separate feature
- renderer migration away from `PlatformView` in the first pass

## Single Next Allowed Step

- preserve this accepted snapshot before any new implementation begins
