# Stage 6 Timeline Professionalization - Stage 8 Motion And Text Timeline Integration

## Status

Closed.

Stage 7 is parked at an accepted interim baseline.

Stage 8 is accepted as closed at the current baseline.

Documentation rule for this stage:

- every accepted Stage 8 slice must update this file
- and must also update the master plan if the recorded execution state changes

## Purpose

Stage 8 exists to make motion/text a real participant in canonical timeline
truth, with special focus on:

- text and motion entries obeying the same visible timeline contract as clips
- timeline duration reflecting motion/text truth when it extends beyond media
- selection context resolving against the editor-visible timeline, not only the
  raw media tracks
- preparing later keyframe/effects work without creating a second hidden
  timing layer

## Implemented So Far

The following Stage 8 slice is now implemented:

1. the screen now exposes a canonical `_timelineTruthTracks` getter that uses
   the editor-visible display tracks, including generated motion/text timeline
   entries, in
   [fusionx_clean_ui_screen.dart](/Users/mx/Documents/InGeneBMFPro/sources/ui/fusionx-clean-ui-2/lib/features/editor/presentation/screens/fusionx_clean_ui_screen.dart)
2. timeline duration truth now reads from `_timelineTruthTracks` instead of the
   raw `_tracks` list alone, so visible motion/text entries can participate in
   timeline duration canonicalization, in
   [fusionx_clean_ui_screen.dart](/Users/mx/Documents/InGeneBMFPro/sources/ui/fusionx-clean-ui-2/lib/features/editor/presentation/screens/fusionx_clean_ui_screen.dart)
3. selected clip context now resolves against `_timelineTruthTracks`, so a
   selected motion/text timeline entry is interpreted through the same visible
   timeline structure the user is acting on, in
   [fusionx_clean_ui_screen.dart](/Users/mx/Documents/InGeneBMFPro/sources/ui/fusionx-clean-ui-2/lib/features/editor/presentation/screens/fusionx_clean_ui_screen.dart)
4. motion/text timeline selection now uses one canonical selection path that
   aligns active tab, preview asset, and timeline time together for timeline
   taps, text edit opening, and text preset insertion, in
   [fusionx_clean_ui_screen.dart](/Users/mx/Documents/InGeneBMFPro/sources/ui/fusionx-clean-ui-2/lib/features/editor/presentation/screens/fusionx_clean_ui_screen.dart)
5. deleting a selected motion/text timeline entry now removes the underlying
   text element and its animation bindings from the motion project itself,
   while cleaning text-edit preview state and keeping selection/preview
   fallback deterministic, in
   [fusionx_clean_ui_screen.dart](/Users/mx/Documents/InGeneBMFPro/sources/ui/fusionx-clean-ui-2/lib/features/editor/presentation/screens/fusionx_clean_ui_screen.dart)
6. duplicating a selected motion/text timeline entry now creates a new motion
   text element with fresh ids, duplicated properties, duplicated animation
   binding state, and a shifted timeline range directly after the source
   element, in
   [fusionx_clean_ui_screen.dart](/Users/mx/Documents/InGeneBMFPro/sources/ui/fusionx-clean-ui-2/lib/features/editor/presentation/screens/fusionx_clean_ui_screen.dart)
7. selected motion/text timeline entries now participate in trim/timing range
   editing through the same timeline trim chrome, with trim commits mutating
   the motion project range and binding active range directly instead of
   pretending the text entry is a media clip, in
   [fusionx_clean_ui_screen.dart](/Users/mx/Documents/InGeneBMFPro/sources/ui/fusionx-clean-ui-2/lib/features/editor/presentation/screens/fusionx_clean_ui_screen.dart)
8. motion/text post-edit resolution now flows through one canonical state
   resolver so delete, duplicate, and trim all re-derive selected clip,
   timeline time, and preview anchor from the updated motion project instead
   of relying on stale pre-edit timeline state, in
   [fusionx_clean_ui_screen.dart](/Users/mx/Documents/InGeneBMFPro/sources/ui/fusionx-clean-ui-2/lib/features/editor/presentation/screens/fusionx_clean_ui_screen.dart)
9. motion/text trim preview now updates live display time and preview anchor
   from a preview-only projected motion project, so trim dragging can preview
   the adjusted text/motion range before commit without pretending it is an
   imported-media transport preview, in
   [fusionx_clean_ui_screen.dart](/Users/mx/Documents/InGeneBMFPro/sources/ui/fusionx-clean-ui-2/lib/features/editor/presentation/screens/fusionx_clean_ui_screen.dart)
10. motion/text timing truth now prefers the canonical binding `activeRange`
    when available, and the same timing contract is used by visible timeline
    entries, post-edit resolution, trim preview projection, and text preset
    insertion, creating the correct baseline for later keyframe/effects timing
    participation without a second hidden timeline, in
    [fusionx_clean_ui_screen.dart](/Users/mx/Documents/InGeneBMFPro/sources/ui/fusionx-clean-ui-2/lib/features/editor/presentation/screens/fusionx_clean_ui_screen.dart)

## Engineering Outcome So Far

The expected engineering effect of the implemented slice is:

- the timeline no longer treats generated text/motion clips as visual-only when
  computing canonical visible duration
- selection semantics now align better with what the timeline panel actually
  renders for text/motion
- future motion timing work can build on one visible timeline truth instead of
  a split between `_tracks` and generated display entries
- motion/text selection now re-enters the same timeline-time and preview
  contract instead of leaving tab/selection/preview loosely coupled
- motion/text clips now participate in at least one real editing semantic
  through project-owned deletion, without pretending to be media clips
- motion/text clips now participate in a second real editing semantic through
  project-owned duplication with fresh ids and timeline-valid shifted ranges
- motion/text clips now participate in an initial timing/range semantic through
  project-owned trim commits that update both project range and binding range
- repeated motion/text edits now re-enter one canonical post-edit state
  contract, reducing drift between selection, visible time, and preview anchor
- motion/text trim now has live preview feedback on the same visible timeline
  contract instead of jumping directly from old range to final commit only
- future motion timing can now build on one canonical timing range contract
  shared by element state and binding state, instead of inventing a separate
  timeline later

## Current Recorded Policy

Current explicit motion/text timeline policy at this baseline:

- Flutter remains the only owner of canonical editor timeline truth
- native preview remains the owner of playback transport only
- generated motion/text timeline entries may participate in read-side timeline
  truth
- motion/text entry selection must keep active tab, preview anchor, and visible
  timeline time aligned through one canonical path
- motion/text deletion must mutate the motion project and animation bindings,
  not the raw media track model
- motion/text duplication must clone project-owned text state with fresh ids and
  valid shifted ranges, not reuse media-track duplication semantics
- motion/text trim must mutate project-owned ranges and binding active ranges,
  not route through imported-media trim assumptions
- motion/text post-edit state must be resolved from the updated project truth,
  not from stale pre-edit display tracks or preview assumptions
- motion/text trim preview must remain Flutter-owned timeline truth and must
  not hijack imported-media preview transport assumptions
- future keyframe/effects timing must extend the same canonical motion/text
  timing contract rather than bypassing it with a separate timing layer
- structural media edits still mutate raw `_tracks` and do not yet mutate
  motion/text entries through the same edit pipeline
- no motion-specific timing layer may bypass the canonical visible timeline

## What Remains Open In Stage 8

No Stage 8 implementation work remains open at this accepted baseline.

Device-facing acceptance at the current baseline is considered sufficient for
closure because:

- motion/text read-side timeline truth is in place
- motion/text selection/preview/time alignment is in place
- motion/text delete/duplicate/trim semantics are in place
- motion/text trim preview is in place
- the canonical timing-range contract is in place

Further work from here should no longer reopen Stage 8 unless a real regression
appears in motion/text timeline truth.

## Handoff Truth

If work resumes later, Stage 8 should be treated as a closed dependency layer
for later motion work.

## Current Resume Point

The accepted Stage 8 baseline is:

- motion/text entries now participate in visible timeline truth on the read side
- motion/text selection now aligns:
  - selected clip id
  - active tab
  - preview anchor
  - current timeline time
- motion/text deletion now mutates the motion project itself and removes the
  associated animation bindings
- motion/text duplication now mutates the motion project itself and clones the
  associated text timing/binding state into a fresh adjacent entry
- motion/text trim now mutates the motion project timing range and binding
  active range directly from timeline trim commits
- motion/text delete/duplicate/trim now share one canonical post-edit
  selection/time/preview resolver based on the updated project truth
- motion/text trim preview now projects through a preview-only canonical
  resolver before commit, keeping live feedback aligned with final semantics
- motion/text visible timeline timing now shares one canonical range contract
  with binding active ranges, which is the intended extension point for future
  keyframe/effects timing work

If work resumes later, do not resume inside Stage 8 by default.

Resume from one of these instead:

1. the next dedicated motion feature stage such as time remapping / speed graph
2. or later keyframe/effects timing work on top of the canonical timing-range
   contract
