# Stage 6 Timeline Professionalization - Stage 1 Single Playback Clock Ownership

## Status

Closed.

Local verification passed.

Real-device acceptance passed on the connected Android device after repeated
validation of `Play`, `Pause`, playback follow, and visible clock agreement.

## Purpose

Stage 1 exists to remove playback-time ambiguity from the timeline UI.

The timeline must stop behaving as if playback is driven by:

- editor time in one place
- playback samples in another place
- local visual motion in a third place

This stage creates one clear playback-display path before scrub and gesture
hardening continue in later stages.

## Implementation Scope Completed So Far

The following work is now implemented:

1. separate `editor time`, `display time`, and `playback sample time` ownership
   inside [fusionx_clean_ui_screen.dart](/Users/mx/Documents/InGeneBMFPro/sources/ui/fusionx-clean-ui-2/lib/features/editor/presentation/screens/fusionx_clean_ui_screen.dart)
2. bind `TimelinePanel` to external playback samples instead of relying only on
   widget rebuild timing in [timeline_panel.dart](/Users/mx/Documents/InGeneBMFPro/sources/ui/fusionx-clean-ui-2/lib/features/editor/presentation/widgets/timeline_panel.dart)
3. bind `TimelinePanel` to external display time while not actively animating
   playback, so the panel follows one display clock outside play mode too in
   [timeline_panel.dart](/Users/mx/Documents/InGeneBMFPro/sources/ui/fusionx-clean-ui-2/lib/features/editor/presentation/widgets/timeline_panel.dart)
4. prevent play-start visual follow from beginning before first confirmed
   forward transport motion in
   [timeline_panel.dart](/Users/mx/Documents/InGeneBMFPro/sources/ui/fusionx-clean-ui-2/lib/features/editor/presentation/widgets/timeline_panel.dart)
5. snap scroll to the playback start anchor before visual follow begins, so the
   timeline does not begin from an older scroll position in
   [timeline_panel.dart](/Users/mx/Documents/InGeneBMFPro/sources/ui/fusionx-clean-ui-2/lib/features/editor/presentation/widgets/timeline_panel.dart)
6. stop play/pause transitions from routing state changes through stale
   `isPlaying` assumptions inside
   [fusionx_clean_ui_screen.dart](/Users/mx/Documents/InGeneBMFPro/sources/ui/fusionx-clean-ui-2/lib/features/editor/presentation/screens/fusionx_clean_ui_screen.dart)
7. sync `display time` and `playback sample time` together immediately before
   `Play` in
   [fusionx_clean_ui_screen.dart](/Users/mx/Documents/InGeneBMFPro/sources/ui/fusionx-clean-ui-2/lib/features/editor/presentation/screens/fusionx_clean_ui_screen.dart)

## What This Stage Must Guarantee

When Stage 1 is accepted, the following must be true:

1. first `Play` does not jump backward
2. first `Play` does not move forward then return then move again
3. `Pause` stops on the visible frame without UI bounce
4. timeline follow during playback no longer shows visible bounce caused by two
   competing clocks
5. timeline header and track movement remain driven by one display-time path

## Closure Summary

This stage is now treated as closed because the accepted device pass confirmed:

- first `Play` no longer snaps backward
- the stronger forward-then-return jump was removed
- `Pause` now settles on the visible frame without major UI bounce
- header, playhead, and track motion now follow one practical display-time path

Minor future polish can still happen later, but it is no longer a `Stage 1`
blocker.

## Real-Device Acceptance Set

Run these exact checks on the connected device:

1. open a real imported video in the timeline
2. press `Play` from a paused position near the start
3. repeat `Play` from a paused position near the middle
4. repeat `Play` from a paused position near the end
5. press `Pause` during each case above
6. confirm:
   - no backward snap
   - no forward-then-return jump
   - no pause bounce
   - no obvious clock disagreement between header, playhead, and track motion

## Closure Evidence

Stage 1 was closed only after:

1. local verification passed
2. APK was repeatedly installed on the connected device
3. the device acceptance set above was tested
4. the result was accepted as strong enough to continue to `Stage 2`

## References

- [Stage 6 Timeline Professionalization Master Plan](/Users/mx/Documents/InGeneBMFPro/docs/process/stage-6-timeline-professionalization-master-plan.md)
- [Stage 6 Timeline Professionalization - Stage 0 Baseline Freeze](/Users/mx/Documents/InGeneBMFPro/docs/process/stage-6-timeline-professionalization-stage-0-baseline-freeze.md)
- [Stage 6 Timeline Professionalization - Stage 2 Professional Live Scrub Engine](/Users/mx/Documents/InGeneBMFPro/docs/process/stage-6-timeline-professionalization-stage-2-professional-live-scrub-engine.md)
