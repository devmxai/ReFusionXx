# Stage 6 Timeline Professionalization - Stage 5 Gesture State Machine Lock

## Status

Closed at accepted baseline.

Stage 5 is no longer the active execution target.

Stage 4 is closed at the accepted trim baseline and Stage 6 now owns the
current active timeline workstream.

Documentation rule for this stage:

- every accepted Stage 5 slice must update this file
- and must also update the master plan if the recorded execution state changes

## Purpose

Stage 5 exists to make timeline interaction ownership explicit and deterministic
on mobile, with special focus on:

- one owner per pointer flow
- no hidden gesture ambiguity
- predictable transition rules between scrub, trim, zoom, and reorder
- preserving accepted UI and timing truth while interaction logic hardens

## Implemented So Far

The following Stage 5 slice is now implemented:

1. a canonical interaction-owner model now exists inside
   [timeline_panel.dart](/Users/mx/Documents/InGeneBMFPro/sources/ui/fusionx-clean-ui-2/lib/features/editor/presentation/widgets/timeline_panel.dart)
2. `scrub`, `trim`, `zoom`, and `reorder` now acquire and release an explicit
   owner instead of relying only on scattered boolean guards, in
   [timeline_panel.dart](/Users/mx/Documents/InGeneBMFPro/sources/ui/fusionx-clean-ui-2/lib/features/editor/presentation/widgets/timeline_panel.dart)
3. the only allowed promotion path in this first slice is `scrub -> zoom`,
   which preserves the accepted pinch-over-scrub behavior while still enforcing
   explicit ownership, in
   [timeline_panel.dart](/Users/mx/Documents/InGeneBMFPro/sources/ui/fusionx-clean-ui-2/lib/features/editor/presentation/widgets/timeline_panel.dart)
4. `pending` vs `active` interaction phase is now explicit for the owner model,
   so `scrub` and `reorder` no longer finalize as if they were fully active
   when the gesture never crossed into a real drag, in
   [timeline_panel.dart](/Users/mx/Documents/InGeneBMFPro/sources/ui/fusionx-clean-ui-2/lib/features/editor/presentation/widgets/timeline_panel.dart)
5. teardown rules are now stricter for pending interactions:
   - a pending scrub can end without emitting a false final scrub commit
   - a pending reorder can end without pretending a real reorder session
   happened
   in
   [timeline_panel.dart](/Users/mx/Documents/InGeneBMFPro/sources/ui/fusionx-clean-ui-2/lib/features/editor/presentation/widgets/timeline_panel.dart)
6. `tap/select` paths now also pass through the same owner model, so
   background tap, clip selection, and clip double tap no longer bypass the
   interaction state machine entirely, in
   [timeline_panel.dart](/Users/mx/Documents/InGeneBMFPro/sources/ui/fusionx-clean-ui-2/lib/features/editor/presentation/widgets/timeline_panel.dart)
7. a broader interaction-cancellation path now exists, so `scrub`, `zoom`,
   `trim`, `reorder`, and `tap` can be torn down through one shared owner-level
   cancellation entrypoint instead of each path relying only on scattered local
   cleanup, in
   [timeline_panel.dart](/Users/mx/Documents/InGeneBMFPro/sources/ui/fusionx-clean-ui-2/lib/features/editor/presentation/widgets/timeline_panel.dart)
8. external state changes now also use the owner-level cancellation path
   before playback start or trim-selection changes, which reduces hidden
   interaction residue when timeline state changes underneath an active gesture,
   in
   [timeline_panel.dart](/Users/mx/Documents/InGeneBMFPro/sources/ui/fusionx-clean-ui-2/lib/features/editor/presentation/widgets/timeline_panel.dart)

## Engineering Outcome So Far

The expected engineering effect of the implemented slice is:

- clearer ownership boundaries between major interaction modes
- fewer future regressions when adding more mobile gestures
- fewer false-positive finalize paths for gestures that never became active
- fewer hidden tap/select paths that bypass gesture ownership entirely
- a clearer base for broader teardown rules between owner transitions
- cleaner teardown when playback or selection state changes externally
- a stricter base for the next Stage 5 slices without changing accepted trim or
  scrub behavior

## What Remains Open In Stage 5

Stage 5 still needs the following before closure:

1. reorder, scrub, trim, zoom, and tap/select must be verified against each
   other on device
2. no hidden fallback path should bypass the owner model
3. owner transition policy still needs stricter device validation under fast
   mixed interactions

## Real-Device Acceptance Set

Run these exact checks on the connected device:

1. scrub in empty areas and confirm trim/reorder do not steal the gesture
2. pinch from inside the timeline and confirm scrub yields only to zoom
3. trim a selected clip and confirm scrub/reorder do not interfere
4. start reorder and confirm trim/zoom do not hijack the interaction

## Handoff Note

If work pauses here and later resumes with:

`continue timeline plan`

the next implementation target should remain:

- continue from `Stage 6 - Editing Semantics Hardening`
- preserve the accepted Stage 5 interaction-owner baseline

## References

- [Stage 6 Timeline Professionalization Master Plan](/Users/mx/Documents/InGeneBMFPro/docs/process/stage-6-timeline-professionalization-master-plan.md)
- [Stage 6 Timeline Professionalization - Stage 4 Trim Interaction Hardening](/Users/mx/Documents/InGeneBMFPro/docs/process/stage-6-timeline-professionalization-stage-4-trim-interaction-hardening.md)
