# Stage 6 - Step 7 Precision Validation Matrix

## Status

Accepted validation reference.

This document defines the exact real-device validation matrix that must pass
before the current timeline-precision work is considered accepted enough to
continue later seam refinement and export-adjacent work.

This step validates:

- exact structural edit truth
- exact visible cut placement
- playhead/cut alignment
- scrub continuity across edited boundaries
- playback continuity across surviving seams

It does not open:

- new playback polish work
- export
- motion/keyframe implementation

## Required Device

- physical Android device:
  - `R3CT10LKLSX`

## Protected Baselines

These must remain intact while running the matrix:

- live scrub remains usable
- structural edit commit remains stable
- delete-middle does not resurrect removed time
- accepted playback baseline remains usable

## Validation Scenarios

### Scenario 1 - Multi-Split Exactness

Steps:

1. import one video clip `A`
2. move playhead to `1s`
3. perform `split`
4. move playhead to `3s`
5. perform `split`

Required result:

- the visible seams appear at the real playhead positions
- no visible jump suggests the cut moved forward or backward
- no runtime error appears

### Scenario 2 - Delete Middle Segment

Steps:

1. use the `A1 / A2 / A3` result from Scenario 1
2. select `A2`
3. delete it
4. play from timeline start

Required result:

- only `A1` then `A3` remain
- deleted time does not return
- preview/runtime do not play the removed middle window
- no crash or renderer collapse appears

### Scenario 3 - Trim After Split

Steps:

1. import one video clip
2. split it once
3. select one surviving side
4. trim left and trim right in separate attempts

Required result:

- trim starts and ends at the visible playhead coordinate
- the surviving clip window remains exact
- no deleted/trimmed time returns in playback

### Scenario 4 - Duplicate After Split

Steps:

1. split one clip
2. duplicate one surviving segment
3. play through the resulting sequence

Required result:

- duplicate inserts a new exact clip window
- duplicated time is visible exactly where inserted
- no source-window corruption appears

### Scenario 5 - Add Second Video After Edits

Steps:

1. edit clip `A` using split/delete or trim
2. import video `B`
3. play `A -> B`

Required result:

- edited `A` remains exact after `B` is added
- no deleted source region from `A` returns
- no structural collapse appears when multi-clip state expands

### Scenario 6 - Slow Scrub Across Cuts

Steps:

1. build a multi-clip edited sequence
2. scrub slowly across each visible seam
3. scrub back and forth multiple times

Required result:

- scrub remains live and usable
- no new black-screen collapse appears
- no `unexpected runtime error` appears
- no visible playhead/cut drift appears

### Scenario 7 - Fast Scrub Across Cuts

Steps:

1. repeat seam scrub using faster movement

Required result:

- timeline remains responsive
- no collapse of preview ownership
- no runtime error appears

### Scenario 8 - Playback Through Surviving Seams

Steps:

1. play through:
   - `A1 -> A3`
   - `A -> B`

Required result:

- no deleted region returns
- no structural edit mismatch appears
- only the already-known seam smoothness baseline is allowed
- no new regression is introduced by precision work

## Failure Rules

This step is not accepted if any of the following occur:

- a deleted region returns in playback
- a visible cut does not match the effective runtime cut
- playhead and cut marker clearly diverge again
- live scrub regresses
- renderer/runtime crashes return

## Reporting Format

Device feedback should be recorded using:

- `split exactness: ...`
- `delete-middle: ...`
- `trim/duplicate: ...`
- `scrub across cuts: ...`
- `playback through seams: ...`
- `runtime stability: ...`

## Acceptance Record

Accepted on the physical device after the required matrix completed without
re-opening:

- deleted-time resurrection
- visible/runtime cut mismatch
- playhead/cut drift
- live scrub regression
- runtime crash regression

Accepted result summary:

- split exactness: accepted
- delete-middle: accepted
- trim/duplicate: accepted
- scrub across cuts: accepted
- playback through seams: accepted within the current known seam baseline
- runtime stability: accepted

Monitor judgment:

- `Maxwell` approved closure of `Step 7`
- the precision foundation is now considered an accepted baseline
- `Stage 6` itself remains open and must continue through the closure checklist
- all later work must preserve this accepted precision baseline
