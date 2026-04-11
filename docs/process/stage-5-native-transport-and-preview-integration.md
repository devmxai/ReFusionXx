# Stage 5 Native Transport And Preview Integration

Status: `CLOSED`

## Goal

- connect the real playback, seek, scrub, and preview path without making Flutter the transport authority

## Locked Inputs

- [stage-4-architecture-lock.md](/Users/mx/Documents/InGeneBMFPro/docs/process/stage-4-architecture-lock.md)
- [README.md](/Users/mx/Documents/InGeneBMFPro/README.md)

## Stage 5 Rules

- Flutter may host and present the preview shell
- Flutter must not own the transport clock
- Media3/native owns transport and preview state
- BMFLite remains the processing engine, not the transport owner
- real gallery import is still out of scope until Stage 6

## Hot Reload Policy In This Stage

- use hot reload for:
  - widget hierarchy
  - layout and styling
  - non-native interaction polish
- rebuild/redeploy for:
  - Android native code
  - platform channel changes
  - Media3 integration
  - BMFLite or C++ changes

## Historical Next Step

- the implementation branch for this stage is preserved in the accepted `Stage 5B` snapshot

## Current Implementation State

- first Stage 5 slice has now been implemented in:
  `/Users/mx/Documents/InGeneBMFPro/sources/ui/fusionx-clean-ui-2`
- implemented scope:
  - one fixed Android sample source copied from the official BMFLite assets
  - Android `Media3` transport owner
  - Flutter `MethodChannel` + `EventChannel` bridge
  - Android `PlatformView` preview surface using `PlayerView`
  - Flutter play button and timeline time changes routed to native transport
  - mock add/edit controls disabled while this fixed-sample slice is active
  - real import still deferred

## Toolchain Compatibility Notes

- Stage 5 originally started on:
  - AGP `7.3.0`
  - Gradle `7.5`
  - `compileSdk 33`
  - `Media3 1.1.1`
- `Stage 5B` raised the Android stack to the minimum official level needed for Media3 scrubbing mode:
  - AGP `8.6.0`
  - Gradle `8.7`
  - Kotlin plugin `1.9.24`
  - Java target `17`
  - `compileSdk 35`
  - `targetSdk 35`
  - `minSdk 21`
  - `Media3 1.8.0`
- the `minSdk 21` uplift was required by the `Media3 1.8.0` library manifest

## Final Validation Status

- `flutter analyze` passes
- Stage 5B debug build succeeded:
  `/Users/mx/Documents/InGeneBMFPro/sources/ui/fusionx-clean-ui-2/build/app/outputs/apk/debug/app-debug.apk`
- debug build was installed on the physical device with `adb install -r`
- app process launched on device
- Stage 5 closure summary:
  - native sample playback, seek, and scrub were accepted on the physical device
  - the final scrub-quality uplift was documented and closed through `Stage 5B`
  - the next stage opened after that snapshot is `Stage 6 - Real Import And Timeline Truth`
- corrective Stage 5 work now applied:
  - added a read-only sample clip to the timeline while fixed-sample transport is active
  - blocked programmatic timeline sync from toggling scrubbing state
  - added throttled native seek dispatch during active scrubbing
  - preserved a final exact seek after scrub release
- historical blocker before `Stage 5B`:
  - investigation confirmed that the remaining scrub problem was architectural in the earlier slice:
    - the project was still pinned to `Media3 1.1.1`
    - that version lacked the newer dedicated scrubbing APIs
    - the current Stage 5 sample has sparse keyframes, so sync-seeking could resolve to frame `0`
  - see:
    [stage-5-scrub-investigation.md](/Users/mx/Documents/InGeneBMFPro/docs/research/stage-5-scrub-investigation.md)

## Hand-off

- this document is now historical
- the live stage reference is:
  [stage-6-real-import-and-timeline-truth.md](/Users/mx/Documents/InGeneBMFPro/docs/process/stage-6-real-import-and-timeline-truth.md)
