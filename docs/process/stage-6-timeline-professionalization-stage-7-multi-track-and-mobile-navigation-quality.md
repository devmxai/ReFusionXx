# Stage 6 Timeline Professionalization - Stage 7 Multi-Track And Mobile Navigation Quality

## Status

Parked at accepted interim baseline.

Stage 6 is accepted and closed at the current structural-edit semantics
baseline.

Stage 7 is accepted at the current interim mobile-navigation baseline and is
now parked for later refinement.

Documentation rule for this stage:

- every accepted Stage 7 slice must update this file
- and must also update the master plan if the recorded execution state changes

## Purpose

Stage 7 exists to make the timeline remain clear and touch-stable when the
mobile editor becomes visually dense, with special focus on:

- stable row behavior across all track kinds
- lower accidental vertical-scroll conflicts during horizontal interaction
- clearer track navigation under dense mixed media rows
- preserving practical touch targets at compact zoom levels

## Implemented So Far

The following Stage 7 slice is now implemented:

1. track rows now read from a canonical track-lane profile instead of relying
   on scattered per-row magic numbers for clip top, clip height, header top,
   and reorder-slot placement, in
   [timeline_panel.dart](/Users/mx/Documents/InGeneBMFPro/sources/ui/fusionx-clean-ui-2/lib/features/editor/presentation/widgets/timeline_panel.dart)
2. the timeline now uses a shared track-lane badge for row headers and reorder
   headers, so dense mixed track stacks keep a clearer visual identity on
   mobile, in
   [timeline_panel.dart](/Users/mx/Documents/InGeneBMFPro/sources/ui/fusionx-clean-ui-2/lib/features/editor/presentation/widgets/timeline_panel.dart)
3. vertical track navigation is now locked by one broader mobile-navigation
   rule while active horizontal owners are running, so scrub, zoom, reorder,
   and trim no longer rely on trim-only vertical locking, in
   [timeline_panel.dart](/Users/mx/Documents/InGeneBMFPro/sources/ui/fusionx-clean-ui-2/lib/features/editor/presentation/widgets/timeline_panel.dart)
4. track-lane badges now carry explicit per-track accent identity, so dense
   stacks are easier to scan quickly without relying only on icon shape, in
   [timeline_panel.dart](/Users/mx/Documents/InGeneBMFPro/sources/ui/fusionx-clean-ui-2/lib/features/editor/presentation/widgets/timeline_panel.dart)
5. track rows now preserve a wider left control column for the lane badge
   capture area instead of letting the visual badge tile define the effective
   mobile hit zone, in
   [timeline_panel.dart](/Users/mx/Documents/InGeneBMFPro/sources/ui/fusionx-clean-ui-2/lib/features/editor/presentation/widgets/timeline_panel.dart)
6. track rows and reorder rows now render a subtle accent-tinted lane underlay
   and separator rail, so dense multi-track stacks remain easier to scan on
   phone screens without relying only on clip colors, in
   [timeline_panel.dart](/Users/mx/Documents/InGeneBMFPro/sources/ui/fusionx-clean-ui-2/lib/features/editor/presentation/widgets/timeline_panel.dart)
7. active timeline rows and active reorder rows now emphasize their lane badge
   and lane underlay together, so the currently acted-on track remains easier
   to locate inside dense stacks on mobile, in
   [timeline_panel.dart](/Users/mx/Documents/InGeneBMFPro/sources/ui/fusionx-clean-ui-2/lib/features/editor/presentation/widgets/timeline_panel.dart)
8. dense track stacks now use a canonical stack-density profile for inter-row
   spacing, so timelines with more rows reduce vertical dead space without
   shrinking the row geometry or mobile touch targets themselves, in
   [timeline_panel.dart](/Users/mx/Documents/InGeneBMFPro/sources/ui/fusionx-clean-ui-2/lib/features/editor/presentation/widgets/timeline_panel.dart)
9. the timeline now reserves the left interaction column for manual horizontal
   panning and keeps scrub ownership on the right/content side, so mobile drag
   intent is clearer and accidental pan-vs-scrub conflicts are reduced, in
   [timeline_panel.dart](/Users/mx/Documents/InGeneBMFPro/sources/ui/fusionx-clean-ui-2/lib/features/editor/presentation/widgets/timeline_panel.dart)
10. manual horizontal panning now requires a stronger intent threshold before
    it activates, and vertical track scrolling only enables when the stacked
    track content actually overflows the viewport, in
    [timeline_panel.dart](/Users/mx/Documents/InGeneBMFPro/sources/ui/fusionx-clean-ui-2/lib/features/editor/presentation/widgets/timeline_panel.dart)

## Engineering Outcome So Far

The expected engineering effect of the implemented slice is:

- lower accidental vertical drift while horizontal interactions are active
- clearer track identification under dense multi-track stacks
- less row-layout fragility when future mobile navigation slices refine track
  metrics per kind
- safer foundations for later compact-density slices without reopening earlier
  single-track behavior regressions
- faster visual differentiation between `video / image / audio / text / lipSync`
  under dense mobile layouts
- stronger left-column control capture under dense mobile layouts
- clearer row separation when many tracks are stacked closely on phone screens
- faster reacquisition of the active row while selecting, trimming, or
  reordering inside dense stacks
- better vertical information density once track count grows, without paying
  for that compactness by shrinking row hit areas
- clearer separation between viewport panning intent and scrub intent on phone
  screens
- lower accidental horizontal panning from small left/right motion when the
  user meant to scrub or just touch the timeline
- cleaner vertical-navigation behavior when the timeline does not actually have
  enough rows to require up/down scrolling

## Current Recorded Policy

Current explicit mobile-navigation policy at this baseline:

- row geometry is now stage-owned through a canonical track-lane profile
- vertical scrolling is suppressed while active horizontal timeline ownership is
  present
- row header identity is explicit for `video`, `image`, `audio`, `text`, and
  `lipSync`
- row header identity also carries a stable accent cue per track kind
- the left control column now preserves a wider mobile hit/capture zone than
  the badge's visual tile alone
- row-level lane guidance is now explicit via subtle accent underlays and
  separators
- the currently active row is now visually emphasized at lane level instead of
  relying only on clip-level selection chrome
- dense track stacks now reduce only inter-row spacing through a canonical
  stack-density profile, while row height and capture metrics remain stable
- manual horizontal panning now belongs to the left interaction column, while
  scrub ownership remains on the right/content side of the timeline
- manual horizontal panning now requires a stronger activation threshold before
  it starts moving the viewport
- vertical track scrolling now activates only when the track stack exceeds the
  viewport height
- single-track accepted behavior remains the baseline that Stage 7 must not
  regress

## What Remains Open In Stage 7

Stage 7 still needs the following before closure:

1. verify dense multi-track interaction on device
2. verify row clarity across `video / image / audio / text / lipSync`
3. verify compact zoom levels do not make essential touch targets too hard to
   capture
4. decide whether additional per-track density tuning is necessary after device
   acceptance now that stack density is canonical

## Handoff Truth

If work resumes later, the next Stage 7 target should be:

- real-device dense multi-track acceptance
- then, only if needed, the next slice should tune per-track density metrics
  or compact touch preservation without regressing accepted single-track
  behavior
