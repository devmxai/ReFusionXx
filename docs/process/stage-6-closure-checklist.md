# Stage 6 Closure Checklist

Status: `ACTIVE CHECKLIST`

## Purpose

- define the exact remaining work required to close `Stage 6 - Real Import And Timeline Truth`
- prevent jumping into export or later architecture work before the current editor baseline is actually stable
- keep the current accepted seam/scrub baseline protected while the last Stage 6 slices are finished

## Binding Rule

- `Stage 6` remains the only active open stage
- no export implementation may begin from this checklist
- every remaining item below must be validated on the physical Android device

## What Is Already Accepted

The following are already accepted enough to continue from this baseline:

- real `Add` opens the approved device-media bottom sheet
- real video/image items can be loaded from the device
- imported video can bind native preview and transport
- preview starts clean with no default sample or placeholder chrome
- picker ordering now follows newest-first
- thumbnail fill is materially improved compared with the original picker baseline
- multi-clip live scrub is currently preserved as an accepted working baseline
- same-source seam continuity is materially improved for split-created seams

These accepted items are not automatically “perfect”, but they are no longer the main blocker for Stage 6 closure.

## Remaining Stage 6 Closure Tracks

`Stage 6` may be closed only after all three tracks below are accepted.

### Track A - Timeline Interaction Contract Finalization

Goal:

- close the remaining uncertainty in clip selection and edit-tool behavior

Current status:

- accepted as the current working baseline

Required acceptance:

- tapping a clip selects that clip only
- tapping empty space clears selection only
- selection never rebinds preview/transport by itself
- edit tools remain visually fixed in their approved layout
- edit tools remain visible with no helper text
- edit tools activate only when a selected imported clip exists
- edit tools do not visually toggle because of playhead movement alone
- split / trim validation happens at action time without destabilizing the toolbar

Blocked if:

- the toolbar changes layout unexpectedly
- helper text returns
- tool activation still depends on playhead position instead of selection truth

### Track B - Edit Correctness And Seam Continuity Recovery

Goal:

- restore runtime-real structural edits and finish seam continuity for the main video track

Required acceptance:

- deleted timeline regions never reappear during playback
- surviving short pieces never expand back into the full original source
- split-created same-source seams remain at least as good as the currently accepted baseline
- same-source gapped seams created by deleting a middle region behave as true surviving neighbors
- adjacent clips from different source files play through with no obvious gap or heavy hitch
- no seam crash is reintroduced
- live scrub does not regress while improving playback-through-seam

Blocked if:

- a new fix regresses accepted scrub quality
- same-source seams get worse again
- deleted source time reappears during playback
- a short surviving piece still plays as if the full source were active
- playback through a cross-source seam still feels visibly broken on device

Execution reference:

- [stage-6-track-b-edit-correctness-and-seam-continuity-recovery.md](/Users/mx/Documents/InGeneBMFPro/docs/process/stage-6-track-b-edit-correctness-and-seam-continuity-recovery.md)

Current active focus inside `Track B`:

- `Phase 2A - Structural Edit Commit Recovery`
- then:
  - `Phase 2 - Structural Edit Projection Correctness`
  - `Phase 2B - Time-Exact Timeline Geometry`

### Track C - Bottom-Sheet Browsing Final Smoothness

Goal:

- make bottom-sheet browsing good enough to stop being a Stage 6 blocker

Required acceptance:

- newest-first ordering remains stable
- cards do not reshuffle while paging
- thumbnail fill remains stable
- no persistent blank-card groups remain
- scrolling is materially smooth enough for practical browsing on the physical device

Blocked if:

- newest-first ordering regresses
- cards flash, reshuffle, or go persistently blank
- scrolling remains obviously unstable enough to hinder browsing

## Validation Order

The remaining work must proceed in this order:

1. preserve the accepted `Track A - Timeline Interaction Contract Finalization` baseline
2. finish `Track B - Edit Correctness And Seam Continuity Recovery`
3. finish `Track C - Bottom-Sheet Browsing Final Smoothness`
4. run final Stage 6 device validation as one combined pass

This order is intentional:

- `Track A` is already the accepted editor-control contract baseline
- `Track B` protects playback correctness
- `Track C` finishes import usability

## Final Stage 6 Device Validation

Before `Stage 6` can be declared closed, all of the following must pass in one documented device pass:

1. open `Add`
2. browse newest-first media successfully
3. import a real video
4. import a second real video
5. select and deselect clips
6. use delete / duplicate / split / trim
7. scrub and play across same-source seams
8. scrub and play across cross-source seams
9. confirm no placeholder/mock media remains the source of truth

## Out Of Scope Until Stage 6 Closes

The following remain explicitly out of scope until this checklist is complete:

- real export implementation
- `Stage 7` opening
- BMFLite live runtime integration in the app
- motion-script / keyframe authoring
- transition engine
- multi-track compositing
- 4K performance work

## Next Stage Reference Only

After this checklist is complete and `Stage 6` is formally closed, the next future-gated reference is:

- [future-stage-7-export-contract-and-native-orchestration-baseline.md](/Users/mx/Documents/InGeneBMFPro/docs/process/future-stage-7-export-contract-and-native-orchestration-baseline.md)

If `Track B` formally records a current-path seam ceiling before closure, the corresponding future preview-architecture reference is:

- [future-preview-architecture-composition-based-multi-clip-evaluation.md](/Users/mx/Documents/InGeneBMFPro/docs/process/future-preview-architecture-composition-based-multi-clip-evaluation.md)
