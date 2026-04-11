# Stage 6 Timeline Professionalization - Stage 2 Professional Live Scrub Engine

## Status

Implementation parked at an accepted interim baseline.

The first accepted slices of Stage 2 are now built, verified locally, and
installed on the connected Android device.

Stage 2 is not closed yet, but deep scrub work is paused for now because the
current scrub result is good enough to move forward to `Stage 3`.

## Purpose

Stage 2 exists to make timeline scrubbing feel immediate, stable, and
professional across:

- short and long clips
- the start, middle, and end of the timeline
- zoomed-in and zoomed-out states
- repeated scrub-release-scrub interaction on mobile

## Implemented So Far

The following Stage 2 slices are now implemented:

1. a dedicated live scrub preview path was added so active scrub no longer
   relies on the generic `seekTo` path for every move
2. Flutter screen scrub updates now route to the preview scrub path during
   active scrub, while non-scrub time jumps still use the normal seek path
3. native scrub settle logic now avoids forcing an immediate exact settle when
   the latest preview position is already close enough to the final target
4. a short deferred exact-settle path now gives the preview path a chance to
   land naturally before a stronger final correction is applied

Primary implementation files:

- [timeline_panel.dart](/Users/mx/Documents/InGeneBMFPro/sources/ui/fusionx-clean-ui-2/lib/features/editor/presentation/widgets/timeline_panel.dart)
- [fusionx_clean_ui_screen.dart](/Users/mx/Documents/InGeneBMFPro/sources/ui/fusionx-clean-ui-2/lib/features/editor/presentation/screens/fusionx_clean_ui_screen.dart)
- [stage5_native_transport_controller.dart](/Users/mx/Documents/InGeneBMFPro/sources/ui/fusionx-clean-ui-2/lib/core/engine/stage5_native_transport_controller.dart)
- [MainActivity.kt](/Users/mx/Documents/InGeneBMFPro/sources/ui/fusionx-clean-ui-2/android/app/src/main/kotlin/com/fusionx/fusionx_clean_ui_2/MainActivity.kt)
- [Stage5TransportManager.kt](/Users/mx/Documents/InGeneBMFPro/sources/ui/fusionx-clean-ui-2/android/app/src/main/kotlin/com/fusionx/fusionx_clean_ui_2/Stage5TransportManager.kt)

## Scientific / Engineering Outcome So Far

The engineering effect of the implemented slices is:

- less dependence on the heavy generic seek path during active scrub
- clearer separation between:
  - live preview while the finger is down
  - final exact correction after release
- reduced probability of a visibly delayed final frame caused by duplicate
  end-of-scrub seek behavior

This stage therefore already improves the scrub system structurally, not only
visually.

## What Remains Open In Stage 2

Stage 2 still needs the following before closure:

1. confirm on device that the remaining delayed last-frame effect is either
   gone or reduced to an acceptable professional level
2. continue reducing scrub lag near the end of the timeline so it is not worse
   than scrub near the start
3. ensure repeated quick scrub-release-scrub interaction does not feel blocked
   or sticky
4. reduce any remaining mismatch between live scrub display and native preview
   under high pressure

## Real-Device Acceptance Set

Run these exact checks on the connected device:

1. scrub near the start of a short clip
2. scrub near the end of the same clip
3. scrub near the start of a longer clip
4. scrub near the end of that longer clip
5. release on a frame and confirm no obvious delayed extra frame appears
6. repeat scrub-release-scrub quickly and confirm responsiveness remains stable

## Closure Rule

Stage 2 may be closed only when:

1. local verification passes
2. APK installs on the connected device
3. the device acceptance set above passes
4. the remaining end-of-scrub artifact is no longer visible enough to be
   considered a professional quality gap

## Handoff Note

If work pauses here and later resumes with the instruction:

`continue timeline plan`

the next implementation target should remain:

- continue `Stage 3 - Zoom And Ruler Canonicalization`
- return to `Stage 2` only if scrub regressions reappear or Stage 3 exposes a
  scrub dependency that truly blocks progress

## References

- [Stage 6 Timeline Professionalization Master Plan](/Users/mx/Documents/InGeneBMFPro/docs/process/stage-6-timeline-professionalization-master-plan.md)
- [Stage 6 Timeline Professionalization - Stage 1 Single Playback Clock Ownership](/Users/mx/Documents/InGeneBMFPro/docs/process/stage-6-timeline-professionalization-stage-1-single-playback-clock-ownership.md)
- [Stage 6 Timeline Professionalization - Stage 3 Zoom And Ruler Canonicalization](/Users/mx/Documents/InGeneBMFPro/docs/process/stage-6-timeline-professionalization-stage-3-zoom-and-ruler-canonicalization.md)
