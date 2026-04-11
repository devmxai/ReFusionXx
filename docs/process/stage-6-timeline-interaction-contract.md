# Stage 6 Timeline Interaction Contract

## Goal

- make clip selection, deselection, and playback interaction behave like a professional mobile editor
- keep timeline interaction logic in Flutter without moving transport ownership out of native `Media3`

## Contract

- tap on a clip selects that clip only
- tap on empty timeline space clears selection
- tap on another clip moves selection to that clip
- playback must not auto-select any clip
- selection must not rebind preview or transport by itself
- edit tools become valid only when a selected imported clip exists
- delete on the main video track behaves as ripple delete and closes the removed gap

## Scope For This Slice

This slice now covers all of the following:

1. document the interaction contract as the active Stage 6 sub-slice
2. remove selection side effects from preview and transport
3. make selected clips visibly readable on device
4. activate contextual edit tools only for a selected imported clip
5. implement the first core clip operations:
   - delete
   - duplicate
   - split at playhead
   - trim left
   - trim right

Still deferred after this slice:

- advanced selection polish beyond the current readable selected state
- multi-select
- undo/redo
- cross-track edit behaviors
- export-aware timeline truth

## Exit Gate For This Slice

This slice may be considered complete only when:

- selecting a clip changes selection state only
- clearing selection does not disturb transport
- playback does not auto-select clips
- current preview binding survives selection changes
- selected clips are visually obvious on device
- edit tools activate only for a selected imported clip
- delete, duplicate, split, trim left, and trim right work on the selected imported clip
- after split/delete/trim, native playback must remain aligned to the surviving clip windows
- docs and README reflect this new baseline truthfully

## Current Implementation Status

The current baseline now also includes:

- selection remains Flutter UI state only:
  - tapping a clip changes selection only
  - tapping empty timeline space clears selection only
  - selection no longer rebinds preview or transport by itself
- the edit toolbar now stays visually fixed:
  - edit icons remain visible in their original left-side position
  - the play/pause control remains in its original position
  - no helper text is shown inside the toolbar
- contextual edit activation now follows the approved contract:
  - edit icons stay disabled by default
  - edit icons become active only when a selected imported clip exists
  - split/trim validity is now checked at action time instead of driving toolbar activation through playhead position

Latest accepted baseline now treats this slice as functionally accepted for the current saved version:

- physical-device behavior is now accepted for:
  - clip selection and deselection
  - fixed toolbar layout
  - no helper text in the toolbar
  - active/inactive behavior driven by selected imported clip truth instead of playhead movement
- this slice is therefore no longer treated as the primary Stage 6 blocker

What remains outside this slice:

- future regressions must still be caught by the final combined Stage 6 device pass
- playback-through-seam quality remains tracked separately under:
  - [stage-6-seam-boundary-stabilization.md](/Users/mx/Documents/InGeneBMFPro/docs/process/stage-6-seam-boundary-stabilization.md)
