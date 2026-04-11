# Stage 6 Timeline Professionalization - Stage 9 Performance Hardening

## Status

Implementation active.

Stage 7 remains parked at an accepted interim baseline.

Stage 8 is accepted as closed at its current baseline.

Stage 9 is now the active execution target.

Current scoped next-workstream planning reference:

- [Stage 6 Timeline Professionalization - Track Manipulation And Interaction Plan](/Users/mx/Documents/InGeneBMFPro/docs/process/stage-6-timeline-professionalization-track-manipulation-and-interaction-plan.md)

Documentation rule for this stage:

- every accepted Stage 9 slice must update this file
- and must also update the master plan if the recorded execution state changes

Current relation to the newer manipulation workstream:

- Stage 9 remains the active recorded stage
- export/effects remains paused at its documented handoff
- the latest local timeline work has opened a first manipulation-adjacent UI
  slice without closing Stage 9

## Purpose

Stage 9 exists to make the timeline resilient under real device pressure,
without changing accepted timing behavior.

Primary focus:

- reduce hot rebuild surfaces
- reduce repeated projection work in hot paths
- preserve accepted scrub/playback/trim semantics
- prepare later time-remapping work on a stronger performance baseline

## Implemented So Far

The following Stage 9 slice is now implemented:

1. the screen now caches the current `motion/text -> timeline projection`
   pipeline so the current motion project no longer rebuilds visible text
   entries, generated text track, and display tracks from scratch on every hot
   path read, in
   [fusionx_clean_ui_screen.dart](/Users/mx/Documents/InGeneBMFPro/sources/ui/fusionx-clean-ui-2/lib/features/editor/presentation/screens/fusionx_clean_ui_screen.dart)
2. the current-state cache now serves:
   - motion/text timeline entries
   - generated text track
   - visible display tracks
   when the active motion project, active binding list, and motion revision
   have not changed, in
   [fusionx_clean_ui_screen.dart](/Users/mx/Documents/InGeneBMFPro/sources/ui/fusionx-clean-ui-2/lib/features/editor/presentation/screens/fusionx_clean_ui_screen.dart)
3. current-state motion/text lookup paths such as selected entry lookup and
   fallback resolution now reuse the cached projection instead of rebuilding
   the same current entry list repeatedly, in
   [fusionx_clean_ui_screen.dart](/Users/mx/Documents/InGeneBMFPro/sources/ui/fusionx-clean-ui-2/lib/features/editor/presentation/screens/fusionx_clean_ui_screen.dart)

## Engineering Outcome So Far

The expected engineering effect of the implemented slice is:

- lower repeated CPU work in the read-heavy motion/text timeline path
- less avoidable projection churn during selection, preview, trim, and overlay
  updates
- a safer baseline before future `time remapping / speed graph` work increases
  timeline pressure

## Current Recorded Policy

Current explicit Stage 9 policy at this baseline:

- performance work must not change canonical timeline truth
- performance work must not change accepted interaction semantics
- performance slices should prefer memoization, subtree isolation, and hot-path
  reduction before larger rewrites

## What Remains Open In Stage 9

Stage 9 still needs the following before closure:

1. identify and reduce additional hot rebuild surfaces in the editor screen and
   timeline panel
2. verify on device that playback remains smooth under current accepted
   scenarios
3. verify on device that scrub remains smooth under short and long clips
4. decide whether timeline-panel subtree isolation needs another dedicated
   Stage 9 slice
5. prepare a later `post-speed-graph` performance pass if time remapping adds
   pressure in playback/scrub/preview paths

## Handoff Truth

If work resumes later, the next Stage 9 target should be:

- isolate another hot rebuild surface, preferably in the screen/timeline bridge
- then perform on-device acceptance for playback and scrub under stress

## Current Resume Point

The current accepted Stage 9 baseline is:

- current motion/text timeline projection is memoized for the active editor state
- current display tracks reuse cached text-track projection when the motion
  state has not changed
- current motion/text lookup paths no longer rebuild the same entry list
  repeatedly in the common case

If work resumes later, resume from:

1. on-device acceptance for current playback/scrub smoothness
2. then the next implementation slice should target:
   - another hot rebuild surface
   - or subtree isolation between static editor chrome and rapidly changing
     timeline state

If the team intentionally switches from Stage 9 hot-path work to manipulation
/ UX work first, use:

- [Stage 6 Timeline Professionalization - Track Manipulation And Interaction Plan](/Users/mx/Documents/InGeneBMFPro/docs/process/stage-6-timeline-professionalization-track-manipulation-and-interaction-plan.md)

This does not close Stage 9. It only records the correct scoped plan for the
next timeline manipulation workstream.

## Latest Pushed Timeline UI Checkpoint

The `BETA1` pushed snapshot now also includes:

- neutral monochrome lane chrome in
  [timeline_panel.dart](/Users/mx/Documents/InGeneBMFPro/sources/ui/fusionx-clean-ui-2/lib/features/editor/presentation/widgets/timeline_panel.dart)
- removal of the earlier colorful left-side lane extension in
  [timeline_panel.dart](/Users/mx/Documents/InGeneBMFPro/sources/ui/fusionx-clean-ui-2/lib/features/editor/presentation/widgets/timeline_panel.dart)
- insertion-driven track creation instead of pre-seeded empty tracks in
  [fusionx_clean_ui_screen.dart](/Users/mx/Documents/InGeneBMFPro/sources/ui/fusionx-clean-ui-2/lib/features/editor/presentation/screens/fusionx_clean_ui_screen.dart)
- guaranteed text-track creation before the first inserted text preset in
  [fusionx_clean_ui_screen.dart](/Users/mx/Documents/InGeneBMFPro/sources/ui/fusionx-clean-ui-2/lib/features/editor/presentation/screens/fusionx_clean_ui_screen.dart)
- dedicated background scrub gesture coverage for the spacer below the ruler
  and the empty timeline area below the last visible track in
  [timeline_panel.dart](/Users/mx/Documents/InGeneBMFPro/sources/ui/fusionx-clean-ui-2/lib/features/editor/presentation/widgets/timeline_panel.dart)
- animated entry from the normal timeline row geometry into compact reorder
  cards during long-press clip reorder
- softer magnetic same-track insertion motion with a clearer temporary
  insertion gap and rightward downstream push during reorder preview
- true non-video timeline movement with preserved gaps for overlay/text/audio-
  style clips
- runtime-correct shifted timing for motion-text clips
- stable non-video movement that no longer auto-jumps the playhead
- successful verification and install on the connected device:
  - `flutter analyze`
  - `flutter build apk --debug`
  - `adb install`

It does not close Stage 9 or the manipulation workstream.

The next focused on-device truth remains:

1. verify first-insert track creation for video/image/audio/text
2. verify scrub behavior from both track surfaces and empty timeline regions
3. verify same-track reorder feel and gapless drop behavior
4. verify non-video movement precision and moved-text runtime timing
