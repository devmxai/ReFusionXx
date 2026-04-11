# Stage 6 - Timeline Precision Gated Execution Plan

## Status

Active execution reference.

This document defines the exact execution order for timeline-precision work.

It is intentionally:

- incremental
- review-gated
- non-regressive
- aligned with official constraints

No step may begin until the previous step has:

- been implemented
- been verified on device
- been reviewed against the stated gate
- been accepted by the project monitor

Current accepted execution state:

- `Step 0 - Baseline Freeze`: accepted
- `Step 1 - Canonical Time Type Introduction`: accepted
- `Step 2 - Playhead Truth Migration`: accepted
- `Step 3 - Exact Clip Window Model Migration`: accepted
- `Step 4 - Structural Edit Math Migration`: accepted
- `Step 5 - Exact Flutter/Native Projection Contract`: accepted
- `Step 6 - Time-Exact Timeline Geometry`: accepted on real device
- `Step 7 - Precision Validation Matrix`: accepted on real device

## Core Rule

We are not allowed to "improve precision" by breaking:

- live scrub
- split/delete correctness
- playback baseline
- timeline usability

If a step improves precision but regresses the accepted runtime baseline, that step is rejected and must be corrected before the project moves forward.

## Non-Negotiable Architecture Rules

- Flutter remains the only owner of editor timeline truth
- preview/runtime remain projections of that truth
- no second hidden timeline truth may appear in native code
- no new floating-point edit truth may be introduced
- UI geometry may style clip display, but may not redefine timeline time
- official `Media3` limits must be respected honestly
- future `BMF/FFmpeg` export must consume the same canonical truth

## Global Working Method

Each step must follow this exact loop:

1. implement only the step scope
2. run local verification
3. install on device
4. test only the acceptance scenarios for that step
5. review with `Maxwell`
6. only then open the next step

## Step 0 - Baseline Freeze

Goal:

- freeze the currently accepted runtime baseline before precision migration

Protected baselines:

- split/delete currently works well enough to continue validation
- live scrub remains usable
- current playback still opens and runs on device

Required output:

- this baseline is treated as the "must not regress" reference for all later steps

Review gate:

- `Maxwell` confirms that the next step may touch time-model internals only

Reference:

- [Stage 6 - Timeline Precision Baseline Freeze](/Users/mx/Documents/InGeneBMFPro/docs/process/stage-6-timeline-precision-baseline-freeze.md)

## Step 1 - Canonical Time Type Introduction

Goal:

- introduce one exact project-owned time type without changing external behavior yet

Scope:

- add a canonical time representation
- define conversion helpers
- keep the old UI-facing seconds API temporarily as a compatibility layer

Required outcome:

- the project has an exact time primitive ready for migration
- no runtime behavior changes yet

Must not change:

- split behavior
- scrub behavior
- preview behavior
- timeline geometry

Acceptance checks:

- app still builds
- device baseline still behaves the same
- no new runtime errors

Monitor gate:

- `Maxwell` confirms the exact time primitive is introduced without changing ownership

## Step 2 - Playhead Truth Migration

Goal:

- migrate playhead truth from floating-point seconds to canonical time

Scope:

- internal playhead state
- current position ownership in Flutter
- exact conversion boundaries to display text only

Required outcome:

- playhead truth is exact internally
- UI labels may still display formatted seconds

Must not change:

- clip model yet
- structural edit math yet
- timeline geometry yet

Acceptance checks:

- playhead moves correctly
- scrubbing still updates preview
- no drift introduced in pause/play/seek

Monitor gate:

- `Maxwell` confirms that playhead truth is exact and still single-owned

## Step 3 - Exact Clip Window Model Migration

Goal:

- replace clip-domain floating-point edit truth with exact source/timeline coordinates

Scope:

- clip duration truth
- source offset truth
- source window ownership

Required outcome:

- clips are represented by exact windows, not approximate doubles
- the model can express:
  - source in
  - source out
  - duration
  - timeline placement

Must not change:

- native backend ownership
- preview backend selection

Acceptance checks:

- imported clips still open correctly
- track duration still computes correctly
- no visual regression required yet

Monitor gate:

- `Maxwell` confirms clip truth is now exact and canonical

## Step 4 - Structural Edit Math Migration

Goal:

- migrate `split`, `trim`, `delete`, and `duplicate` to exact edit math

Scope:

- split math
- trim left/right
- delete/ripple behavior
- duplicate placement

Required outcome:

- structural edits operate on exact canonical time
- no floating-point edit math remains in the mutation path

Must not change:

- seam playback policy
- scrub backend policy

Acceptance checks:

- split at playhead creates exact left/right windows
- delete-middle removes only the selected range
- surviving clips remain exact
- repeated structural edits do not reintroduce deleted time

Monitor gate:

- `Maxwell` confirms structural edit truth is exact and runtime-correct

## Step 5 - Exact Flutter/Native Projection Contract

Goal:

- ensure native preview receives a projection of exact truth, not approximate seconds ownership

Scope:

- Flutter -> native segment payload
- target seek payload
- exact-to-preview conversion boundary

Required outcome:

- exact source windows are projected to native deterministically
- any player-required rounding is isolated and explicit

Must not change:

- player ownership of preview only
- Flutter ownership of truth

Acceptance checks:

- imported multi-clip timelines still prepare correctly
- delete-middle still behaves correctly
- no new renderer/runtime collapse appears

Monitor gate:

- `Maxwell` confirms projection is exact and ownership boundaries remain clean

## Step 6 - Time-Exact Timeline Geometry

Goal:

- make the visible timeline derive from canonical time, not from approximate clip width

Scope:

- playhead placement
- seam placement
- split marker placement
- hit testing
- cut marker rendering

Required outcome:

- playhead, split point, seam marker, and runtime projection all derive from the same canonical timeline coordinate
- any minimum-width rendering becomes paint-only styling

Must not change:

- structural edit truth
- scrub baseline
- accepted playback baseline

Acceptance checks:

- visible cut seam sits exactly at the canonical cut position
- playhead and cut marker stay aligned
- green track no longer appears to "refresh" to a different time

Monitor gate:

- `Maxwell` confirms geometry is now a visual projection of exact time, not a competing truth

## Step 7 - Precision Validation Matrix

Goal:

- validate the exactness contract under real editing stress

Required scenarios:

1. split one clip at multiple points
2. delete middle clip after multiple splits
3. trim after split
4. duplicate after split
5. add second video after structural edits on the first
6. scrub across cut points slowly and quickly
7. play through surviving seams after delete

Required outcome:

- no deleted region returns
- no playhead drift
- no cut marker drift
- no mismatch between visible cut and actual runtime cut

Monitor gate:

- `Maxwell` confirms that precision work is accepted and that later seam refinement may continue on top of a stable truth model

## What We Will Not Do

- we will not chase preview polish before exact truth exists
- we will not patch seam hold by changing edit truth
- we will not let UI minimum width redefine clip time
- we will not let native runtime become the timeline owner
- we will not open export work during this execution sequence

## Exact Next Step

Timeline-precision work is now accepted as a protected baseline.

The next allowed work is:

- return to `Stage 6` closure work
- preserve the accepted precision baseline
- continue only through the official Stage 6 closure checklist

This plan does not itself authorize:

- export
- motion/keyframe implementation
- seam polish that breaks exact truth
