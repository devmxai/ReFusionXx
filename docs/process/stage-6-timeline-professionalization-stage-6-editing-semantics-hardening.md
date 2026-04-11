# Stage 6 Timeline Professionalization - Stage 6 Editing Semantics Hardening

## Status

Accepted and closed for the current structural-edit baseline.

Stage 6 is no longer the active execution target.

Stage 7 now owns the active timeline workstream.

Documentation rule for this stage:

- every accepted Stage 6 slice must update this file
- and must also update the master plan if the recorded execution state changes

## Purpose

Stage 6 exists to move structural editing from UI-correct behavior to
editor-correct semantics, with special focus on:

- canonical split behavior
- canonical duplicate behavior
- canonical delete behavior
- explicit gap policy
- explicit ripple policy boundaries

## Implemented So Far

The following Stage 6 slice is now implemented:

1. `split`, `duplicate`, and `delete` now build a canonical structural-edit
   plan before mutating the timeline, in
   [fusionx_clean_ui_screen.dart](/Users/mx/Documents/InGeneBMFPro/sources/ui/fusionx-clean-ui-2/lib/features/editor/presentation/screens/fusionx_clean_ui_screen.dart)
2. structural edit application now passes through one shared
   `_applyStructuralEditPlan(...)` path instead of three separate ad hoc
   handlers, in
   [fusionx_clean_ui_screen.dart](/Users/mx/Documents/InGeneBMFPro/sources/ui/fusionx-clean-ui-2/lib/features/editor/presentation/screens/fusionx_clean_ui_screen.dart)
3. `duplicate` now clears inherited `splitGroupId`, so a duplicated clip does
   not accidentally stay semantically coupled to an older split sibling, in
   [timeline_mock_models.dart](/Users/mx/Documents/InGeneBMFPro/sources/ui/fusionx-clean-ui-2/lib/features/editor/presentation/models/timeline_mock_models.dart)
4. structural edit plans now record explicit `gap policy` and `ripple policy`
   metadata instead of leaving them entirely implicit in separate handlers, in
   [fusionx_clean_ui_screen.dart](/Users/mx/Documents/InGeneBMFPro/sources/ui/fusionx-clean-ui-2/lib/features/editor/presentation/screens/fusionx_clean_ui_screen.dart)
5. track-local structural edits now normalize split-group semantics under the
   explicit gapless-track policy, so orphaned or broken split-group markers are
   cleared after delete/duplicate/split chains, in
   [fusionx_clean_ui_screen.dart](/Users/mx/Documents/InGeneBMFPro/sources/ui/fusionx-clean-ui-2/lib/features/editor/presentation/screens/fusionx_clean_ui_screen.dart)
6. `targetTime` after structural edits is now resolved through explicit
   `ripple policy` logic instead of each edit handler deciding it independently,
   in
   [fusionx_clean_ui_screen.dart](/Users/mx/Documents/InGeneBMFPro/sources/ui/fusionx-clean-ui-2/lib/features/editor/presentation/screens/fusionx_clean_ui_screen.dart)
7. structural edit plans now build through one canonical helper that resolves
   next tracks, target time, selection, and preview asset under explicit edit
   semantics, in
   [fusionx_clean_ui_screen.dart](/Users/mx/Documents/InGeneBMFPro/sources/ui/fusionx-clean-ui-2/lib/features/editor/presentation/screens/fusionx_clean_ui_screen.dart)
8. `delete` now preserves deterministic adjacent selection semantics and lets
   preview follow the surviving selected clip instead of dropping immediately to
   null selection/preview, in
   [fusionx_clean_ui_screen.dart](/Users/mx/Documents/InGeneBMFPro/sources/ui/fusionx-clean-ui-2/lib/features/editor/presentation/screens/fusionx_clean_ui_screen.dart)
9. structural edit preview resolution now prefers the visual clip that matches
   the resolved post-edit `targetTime`, so preview does not fall back to an
   unrelated first visual asset after delete/split/duplicate, in
   [fusionx_clean_ui_screen.dart](/Users/mx/Documents/InGeneBMFPro/sources/ui/fusionx-clean-ui-2/lib/features/editor/presentation/screens/fusionx_clean_ui_screen.dart)
10. structural edit plans now record explicit `selection anchor policy`, so
    `duplicate` and `split` move the playhead to the newly selected clip start
    instead of leaving time on an older sibling while selection moves forward,
    in
    [fusionx_clean_ui_screen.dart](/Users/mx/Documents/InGeneBMFPro/sources/ui/fusionx-clean-ui-2/lib/features/editor/presentation/screens/fusionx_clean_ui_screen.dart)
11. any structural edit now clears stale trim-mode state immediately, so
    `split/delete/duplicate` cannot leave hidden trim ownership or preview
    sessions attached to pre-edit topology, in
    [fusionx_clean_ui_screen.dart](/Users/mx/Documents/InGeneBMFPro/sources/ui/fusionx-clean-ui-2/lib/features/editor/presentation/screens/fusionx_clean_ui_screen.dart)
12. structural edit application now passes through a final canonicalization
    gate before state mutation, so `targetTime`, `selectedClipId`, and
    `previewAssetId` are revalidated against the resulting timeline topology, in
    [fusionx_clean_ui_screen.dart](/Users/mx/Documents/InGeneBMFPro/sources/ui/fusionx-clean-ui-2/lib/features/editor/presentation/screens/fusionx_clean_ui_screen.dart)
13. `delete` selection fallback is now resolved against the post-delete
    `targetTime` inside the edited gapless track, instead of choosing a
    surviving clip only by raw list index, in
    [fusionx_clean_ui_screen.dart](/Users/mx/Documents/InGeneBMFPro/sources/ui/fusionx-clean-ui-2/lib/features/editor/presentation/screens/fusionx_clean_ui_screen.dart)
14. structural edit plans now retain the edited track index and use it during
    final canonicalization, so selection can be recovered from the edited track
    by timeline time even if a previously chosen `selectedClipId` no longer
    resolves cleanly, in
    [fusionx_clean_ui_screen.dart](/Users/mx/Documents/InGeneBMFPro/sources/ui/fusionx-clean-ui-2/lib/features/editor/presentation/screens/fusionx_clean_ui_screen.dart)
15. trim commit preview resolution now yields to the post-trim timeline time
    when the playhead ends up beyond the trimmed clip, instead of blindly
    preferring the just-trimmed clip asset, in
    [fusionx_clean_ui_screen.dart](/Users/mx/Documents/InGeneBMFPro/sources/ui/fusionx-clean-ui-2/lib/features/editor/presentation/screens/fusionx_clean_ui_screen.dart)
16. clip reorder now re-anchors time and preview to the reordered clip start
    under the resulting timeline topology, instead of preserving older preview
    and time assumptions after the clip changes position, in
    [fusionx_clean_ui_screen.dart](/Users/mx/Documents/InGeneBMFPro/sources/ui/fusionx-clean-ui-2/lib/features/editor/presentation/screens/fusionx_clean_ui_screen.dart)
17. clip reorder now also clears stale trim-mode state before committing the
    new topology, so reordering cannot leave trim ownership or preview sessions
    attached to the old clip position, in
    [fusionx_clean_ui_screen.dart](/Users/mx/Documents/InGeneBMFPro/sources/ui/fusionx-clean-ui-2/lib/features/editor/presentation/screens/fusionx_clean_ui_screen.dart)
18. final structural canonicalization now only lets a preferred preview asset
    outrank timeline-time resolution when the edit is explicitly anchored to the
    selected clip start; structural-target edits now yield to the resulting
    timeline time instead of keeping a stale visual asset alive, in
    [fusionx_clean_ui_screen.dart](/Users/mx/Documents/InGeneBMFPro/sources/ui/fusionx-clean-ui-2/lib/features/editor/presentation/screens/fusionx_clean_ui_screen.dart)
19. clip reorder now runs through the same canonical structural-edit pipeline
    as split/duplicate/delete, instead of mutating timeline state through a
    parallel manual path, in
    [fusionx_clean_ui_screen.dart](/Users/mx/Documents/InGeneBMFPro/sources/ui/fusionx-clean-ui-2/lib/features/editor/presentation/screens/fusionx_clean_ui_screen.dart)

## Engineering Outcome So Far

The expected engineering effect of the implemented slice is:

- cleaner source of truth for structural edits
- lower risk of semantic drift between delete, duplicate, and split
- a safer base for formal gap/ripple policy in later Stage 6 slices
- less chance that old split metadata survives after structural edits in a way
  that no longer matches the visible timeline
- clearer semantics for what should and should not ripple after each edit
- lower risk of selection/preview drift immediately after delete
- lower risk of preview jumping to an unrelated visual asset after structural edits
- lower risk of `time/selection/preview` disagreement after split or duplicate
- lower risk of stale trim ownership after topology-changing edits
- stronger guarantee that post-edit state is internally coherent even if future
  structural builders become more complex
- more time-true delete selection semantics when the removed clip sits before,
  under, or after the playhead
- stronger resilience under repeated structural edit chains when selection ids
  become stale mid-sequence
- lower risk of preview drift in mixed `split -> trim -> delete` style chains
- lower risk of stale preview/time semantics after immediate reordering
- lower risk of stale trim ownership after immediate reordering
- lower risk of stale preferred-preview carryover after structural-target edits
- lower risk of reorder drifting semantically away from the other structural edits

## Current Recorded Policy

Current explicit editing policy at this baseline:

- tracks are still gapless by default
- delete ripples only inside the edited track because clip lists remain
  sequential
- duplicate inserts adjacently after the selected clip
- split preserves source continuity and total duration inside the edited track
- structural edit plans now declare this policy explicitly in code, not only by
  behavior
- orphaned split-group markers are cleared during structural edit normalization
- `delete` uses `trackLocalDelete` ripple semantics for `targetTime`
- `duplicate` and `split` currently use `none` ripple semantics for `targetTime`
- `delete` now selects the nearest surviving sibling when one exists, instead
  of always clearing selection
- structural preview resolution now prefers the visual clip covering the
  post-edit `targetTime` before generic visual fallback ordering
- `duplicate` and `split` now anchor time to the newly selected clip start
  instead of preserving an older sibling position by accident
- topology-changing structural edits now forcibly exit trim-mode state
- every structural edit now passes through a final canonical state pass before
  mutating the live timeline
- `delete` now chooses the surviving selected clip by post-delete time
  semantics, not only by list position
- canonicalization now has edited-track context, not only free-floating ids
- trim commit preview now respects resulting timeline time when the trimmed clip
  no longer covers the current position
- reorder now follows the same time/preview truth contract as structural edits
- reorder now follows the same trim-state cleanup contract as structural edits
- structural-target edits now prefer canonical timeline-time preview resolution
  over stale preferred assets during final canonicalization
- reorder now uses the same canonical plan/apply/canonicalize contract as the
  rest of the structural editing family

## Closure Record

Stage 6 is accepted and closed at the current baseline with the following
explicit boundary:

1. repeated structural-edit hardening is now implemented for `split`,
   `duplicate`, `delete`, `trim`, and `reorder`
2. future non-gapless modes remain explicitly out of scope for this baseline
3. ripple variants beyond `trackLocalDelete` remain deferred beyond this
   baseline

## Real-Device Acceptance Set

Run these exact checks on the connected device:

1. split a clip repeatedly and confirm the right segment selection stays
   deterministic
2. duplicate a split child and confirm it no longer visually/semantically
   behaves like a split sibling
3. delete after split/trim and confirm timeline time and preview remain coherent
4. repeat mixed structural edits and confirm no hidden drift appears

## Handoff Note

If work pauses here and later resumes, Stage 6 should be treated as closed
baseline history.

The next active target is now Stage 7.

## References

- [Stage 6 Timeline Professionalization Master Plan](/Users/mx/Documents/InGeneBMFPro/docs/process/stage-6-timeline-professionalization-master-plan.md)
- [Stage 6 Timeline Professionalization - Stage 5 Gesture State Machine Lock](/Users/mx/Documents/InGeneBMFPro/docs/process/stage-6-timeline-professionalization-stage-5-gesture-state-machine-lock.md)
