# Stage 6 Timeline Professionalization - Track Manipulation And Interaction Plan

Last updated: April 10, 2026

Status: `ACTIVE EXECUTION REFERENCE`

Type: `scoped timeline execution plan`

Purpose:

- open a dedicated plan for the next timeline-focused workstream
- improve track movement, clip movement, and manipulation quality without
  losing the current canonical timeline truth
- define and maintain the exact execution order while code changes progress in
  this area

Primary references:

- [Stage 6 Timeline Professionalization Master Plan](/Users/mx/Documents/InGeneBMFPro/docs/process/stage-6-timeline-professionalization-master-plan.md)
- [Stage 6 Timeline Professionalization - Stage 9 Performance Hardening](/Users/mx/Documents/InGeneBMFPro/docs/process/stage-6-timeline-professionalization-stage-9-performance-hardening.md)
- [Stage 6 Timeline Interaction Contract](/Users/mx/Documents/InGeneBMFPro/docs/process/stage-6-timeline-interaction-contract.md)
- [Stage 6 Timeline Precision And Canonical Time Model](/Users/mx/Documents/InGeneBMFPro/docs/process/stage-6-timeline-precision-and-canonical-time-model.md)

## Relationship To The Existing Stage Chain

This document does **not** replace the master plan.

It is a scoped execution guide for the next timeline workstream while:

- the master plan remains the global truth
- Stage 9 remains the active stage in the recorded state
- export/effects work is intentionally paused at a documented handoff point

## Goal

Make timeline manipulation feel more professional in areas such as:

- track movement
- clip dragging
- possible lane reassignment
- touch ownership during move/reorder
- edge auto-scroll during drag
- selected clip feedback while moving
- preventing accidental conflicts between:
  - scrub
  - trim
  - clip move
  - track move

## Scope

This plan is for timeline manipulation quality only.

It may include:

- clip drag/reposition interaction
- track/lane movement or lane-targeting rules if the current UX supports them
- stronger movement hit targets and ownership
- drag preview / insertion preview / seam preview
- protected gesture arbitration during manipulation
- mobile ergonomics and edge-follow behavior

It must not silently redefine:

- canonical timeline time
- accepted trim semantics
- scrub ownership
- native playback ownership

## Non-Negotiable Rules

- Flutter remains the only owner of canonical timeline truth
- native transport may preview the result, but must not become the timeline
  owner
- movement visuals may preview placement, but may not redefine placement truth
- no move/reorder UX may degrade:
  - trim
  - scrub
  - zoom
  - playhead precision
- no track manipulation slice may be accepted without real-device testing

## Current Assumptions

Current timeline baseline already has:

- accepted Stage 0 through Stage 8 baseline state
- active Stage 9 performance baseline
- motion/text timeline integration baseline
- stronger structural edit semantics
- speed metadata foundation

This means the next timeline work should build on:

- canonical timeline coordinates
- already-accepted edit semantics
- existing state-machine boundaries

It must not reopen old solved issues unless regression is proven.

## Latest Pushed Implementation Checkpoint

The first manipulation-adjacent UI slice after opening this plan is now pushed
in `BETA1`.

What changed in this pushed snapshot:

- timeline lane visuals under the ruler were returned to a more neutral
  monochrome style
- the earlier left-side color extension under timeline rows was removed
- the timeline now starts with no pre-seeded empty media/text tracks
- a track is now created only when the first asset or text preset of that type
  is actually inserted
- text preset insertion now ensures a text track exists before the first
  generated text clip is added
- scrub can now start from the general timeline background, including the empty
  spacer below the ruler and the empty space below the last visible track, not
  only from track surfaces
- long-press clip reorder now morphs the active row into compact cards with a
  clearer same-track magnetic insertion feel
- non-video clip movement now shifts clips in time with real preserved gaps
  instead of using reorder-only semantics
- moved text clips now respect their real shifted runtime start time
- non-video clip movement no longer auto-jumps the playhead

Code references:

- [timeline_panel.dart](/Users/mx/Documents/InGeneBMFPro/sources/ui/fusionx-clean-ui-2/lib/features/editor/presentation/widgets/timeline_panel.dart)
- [fusionx_clean_ui_screen.dart](/Users/mx/Documents/InGeneBMFPro/sources/ui/fusionx-clean-ui-2/lib/features/editor/presentation/screens/fusionx_clean_ui_screen.dart)

Verification completed for this pushed snapshot:

- `dart format`
- `flutter analyze`
- `flutter build apk --debug`

Current remaining acceptance work:

- focused on-device validation for first-insert track creation with:
  - video
  - image
  - audio
  - text preset
- focused on-device validation that scrub behavior is correct from:
  - track surfaces
  - empty timeline regions
- focused on-device validation that reorder behavior is correct for:
  - animated entry feel
  - same-track magnetic insertion
  - gapless drop result
- focused on-device validation that non-video movement is correct for:
  - exact drop precision
  - preserved empty gaps
  - moved-text runtime timing

Verification completed for this pushed snapshot:

- `dart format`
- `flutter analyze`
- `flutter build apk --debug`
- `adb install` succeeded on the connected device

## Current Problem Shape

This next workstream is expected to focus on one or more of these gaps:

1. movement ownership may still feel weaker than scrub/trim ownership
2. track/clip movement feedback may not be explicit enough on mobile
3. auto-scroll/follow during drag may not yet feel professional
4. insertion targeting between clips or lanes may not be strict enough
5. movement and selection chrome may still be too light for precise editing

## Execution Order

### Part 1: Truth Freeze For Manipulation

Before changing behavior:

1. document the current movement behavior exactly
2. list the current accepted behaviors that must not regress
3. define whether the immediate target is:
   - clip movement only
   - or clip movement plus track/lane movement

Acceptance for Part 1:

- current behavior is documented clearly enough to compare before/after

### Part 2: Ownership And State Machine Review

Review and tighten:

- gesture ownership for move vs scrub vs trim
- selected-clip movement initiation rules
- cancellation rules
- when a drag becomes structural vs only visual preview

Acceptance for Part 2:

- one pointer flow has one explicit owner during manipulation

### Part 3: Canonical Placement And Lane Targeting

Implement or refine:

- canonical drag target calculation
- exact insertion/reposition target
- lane/track target resolution if supported
- no hidden geometry-only truth

Acceptance for Part 3:

- the final placement is derived from canonical time and target lane truth only

### Part 4: Mobile Interaction Quality

Implement or refine:

- stronger selected-clip affordance during movement
- edge auto-scroll while dragging
- visual insertion preview
- movement hysteresis / dead-zone policy where needed

Acceptance for Part 4:

- dragging feels predictable and readable on the connected device

### Part 5: Performance And Stability Guard

Validate:

- drag does not create heavy rebuild churn
- movement remains responsive on long and short timelines
- no visible playback/scrub regressions appear afterward

Acceptance for Part 5:

- manipulation remains smooth under real-device pressure

## Suggested First Concrete Slice

The safest first implementation slice is:

1. freeze current move/reorder behavior
2. tighten move-vs-scrub-vs-trim ownership
3. make selected-clip movement feedback clearer
4. only then decide whether to open lane/track movement itself

Why this first:

- it strengthens the interaction contract before adding deeper movement power
- it reduces the chance of regressing already accepted trim/scrub behavior

## Acceptance Matrix For This Workstream

Every accepted slice in this plan should be checked on the real device for:

1. drag a selected clip slowly across seams
2. drag a selected clip quickly across a long timeline
3. drag near the left/right edges and confirm auto-follow behavior
4. enter trim, exit trim, then drag and confirm ownership is still correct
5. scrub first, then drag, then scrub again and confirm no stuck mode remains
6. if lane/track movement is enabled later:
   confirm the target lane resolution is explicit and stable

## Handoff Rule

If timeline work pauses again later, this document must be updated with:

- what slice was actually implemented
- what remained untouched
- the exact next resume point

No timeline manipulation work should live only in chat.

If work resumes in a new thread, the immediate next step is:

1. install the current local build on the connected device
2. validate first-insert track creation for video/image/audio/text
3. then continue with manipulation ownership and lane-targeting work
