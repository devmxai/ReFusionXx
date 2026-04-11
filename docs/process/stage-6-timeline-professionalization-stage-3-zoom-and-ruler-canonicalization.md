# Stage 6 Timeline Professionalization - Stage 3 Zoom And Ruler Canonicalization

## Status

Closed at accepted baseline.

Stage 3 is no longer the current execution target.

Stage 4 now owns the next timeline execution slice.

Documentation rule for this stage:

- every accepted Stage 3 slice must update this file
- and must also update the master plan if the recorded execution state changes

## Purpose

Stage 3 exists to make timeline zoom and ruler behavior mathematically
canonical, readable, and predictable across:

- very small zoom-out states
- medium editing zoom states
- high-precision seconds-plus-frames states
- fine frame-level inspection states

## Implemented So Far

The following Stage 3 slice is now implemented:

1. zoom gesture limits and damping are centralized into one canonical zoom
   profile inside
   [timeline_panel.dart](/Users/mx/Documents/InGeneBMFPro/sources/ui/fusionx-clean-ui-2/lib/features/editor/presentation/widgets/timeline_panel.dart)
2. ruler mode thresholds now resolve from one canonical ruler profile in
   [timeline_panel.dart](/Users/mx/Documents/InGeneBMFPro/sources/ui/fusionx-clean-ui-2/lib/features/editor/presentation/widgets/timeline_panel.dart)
3. second-based ruler spacing now uses an explicit nice-step ladder instead of
   only power-of-ten style expansion in
   [timeline_panel.dart](/Users/mx/Documents/InGeneBMFPro/sources/ui/fusionx-clean-ui-2/lib/features/editor/presentation/widgets/timeline_panel.dart)
4. boundary epsilon and second-label spacing rules are now centralized for
   coarse, normal, and seconds-plus-frames ruler states in
   [timeline_panel.dart](/Users/mx/Documents/InGeneBMFPro/sources/ui/fusionx-clean-ui-2/lib/features/editor/presentation/widgets/timeline_panel.dart)
5. `seconds + frames` ruler mode is now locked to true one-second anchors with
   real midpoint frame markers, instead of allowing non-canonical multi-second
   anchors in that mode, in
   [timeline_panel.dart](/Users/mx/Documents/InGeneBMFPro/sources/ui/fusionx-clean-ui-2/lib/features/editor/presentation/widgets/timeline_panel.dart)
6. fine-frame ruler spacing now shares the same canonical profile ownership for
   frame-step and duration-tolerance rules in
   [timeline_panel.dart](/Users/mx/Documents/InGeneBMFPro/sources/ui/fusionx-clean-ui-2/lib/features/editor/presentation/widgets/timeline_panel.dart)
7. fine-frame ruler mode now preserves readable whole-second anchors alongside
   frame markers, so frame-heavy zoom states still keep clear time context in
   [timeline_panel.dart](/Users/mx/Documents/InGeneBMFPro/sources/ui/fusionx-clean-ui-2/lib/features/editor/presentation/widgets/timeline_panel.dart)
8. boundary end labels in second-based ruler modes now preserve true
   fractional end duration when the content does not end exactly on a whole
   second, in
   [timeline_panel.dart](/Users/mx/Documents/InGeneBMFPro/sources/ui/fusionx-clean-ui-2/lib/features/editor/presentation/widgets/timeline_panel.dart)
9. boundary labels in frame-oriented ruler modes now avoid overstating the end
   time when the content ends between true frame boundaries, falling back to
   exact time formatting when needed, in
   [timeline_panel.dart](/Users/mx/Documents/InGeneBMFPro/sources/ui/fusionx-clean-ui-2/lib/features/editor/presentation/widgets/timeline_panel.dart)
10. pinch acquisition now chooses the strongest active pointer pair instead of
    relying only on the first two touches, and the activation threshold is
    slightly reduced for more reliable mobile zoom pickup, in
    [timeline_panel.dart](/Users/mx/Documents/InGeneBMFPro/sources/ui/fusionx-clean-ui-2/lib/features/editor/presentation/widgets/timeline_panel.dart)
11. the remaining ruler-painter spacing constants for label margins, label
    gaps, dot spacing, dot fade, and boundary safe insets are now moved into
    the canonical ruler profile, in
    [timeline_panel.dart](/Users/mx/Documents/InGeneBMFPro/sources/ui/fusionx-clean-ui-2/lib/features/editor/presentation/widgets/timeline_panel.dart)
12. active pinch zoom now rebases cleanly when the participating pointer pair
    changes during the gesture, reducing jumpiness when fingers are added,
    removed, or repositioned mid-zoom, in
    [timeline_panel.dart](/Users/mx/Documents/InGeneBMFPro/sources/ui/fusionx-clean-ui-2/lib/features/editor/presentation/widgets/timeline_panel.dart)
13. fine-frame ruler mode now uses a canonical whole-second anchor cadence
    chosen from the same nice-second ladder, instead of always trying to label
    every single second regardless of zoom density, in
    [timeline_panel.dart](/Users/mx/Documents/InGeneBMFPro/sources/ui/fusionx-clean-ui-2/lib/features/editor/presentation/widgets/timeline_panel.dart)
14. ruler viewport overscan and boundary-label priority ownership are now
    explicitly centralized in the canonical ruler profile, further reducing
    remaining paint-level magic numbers in
    [timeline_panel.dart](/Users/mx/Documents/InGeneBMFPro/sources/ui/fusionx-clean-ui-2/lib/features/editor/presentation/widgets/timeline_panel.dart)
15. start and end boundary labels now use edge-safe placement while their
    true anchor remains visible, instead of disappearing early just because the
    full label box would cross a safe inset, in
    [timeline_panel.dart](/Users/mx/Documents/InGeneBMFPro/sources/ui/fusionx-clean-ui-2/lib/features/editor/presentation/widgets/timeline_panel.dart)
16. fallback clip interiors now use stable fixed icon tiers instead of
    free repeated icons tied directly to width division, and the clip body no
    longer implicitly animates its width during zoom, in
    [timeline_panel.dart](/Users/mx/Documents/InGeneBMFPro/sources/ui/fusionx-clean-ui-2/lib/features/editor/presentation/widgets/timeline_panel.dart)

## Engineering Outcome So Far

The expected engineering effect of the implemented slice is:

- more stable ruler step selection as zoom changes
- fewer ad-hoc spacing values scattered across the timeline painter
- clearer long-term ownership of zoom and ruler thresholds
- mathematically correct `seconds + frames` labeling with true second anchors
- better whole-time orientation while operating in fine-frame zoom states
- exact end-of-content boundary labeling in second-based ruler modes
- safer exact end-of-content labeling even while the ruler is in frame-focused modes
- stronger multi-touch zoom pickup from mixed touch positions inside the timeline
- substantially less painter-level magic-number drift inside ruler layout behavior
- smoother continuity for pinch gestures when active fingers change mid-gesture
- more readable frame-heavy zoom states because whole-second anchors now thin
  out canonically instead of depending only on collision pruning
- cleaner ruler ownership for viewport overscan and boundary-label selection
- more reliable exact start/end readability near viewport edges without
  returning to permanently pinned labels
- more stable placeholder/fallback clip appearance during zoom because icon
  density now changes only at a few deliberate tiers instead of reflowing
  continuously with width
- a safer base for later work on frame readability and end-of-content labeling

## Closure Result

Stage 3 is accepted as closed on the current real-device baseline.

Accepted closure truth:

1. zoom behavior is now mathematically stable enough for current scope
2. ruler modes are canonical enough for professional editing use
3. end-of-content labeling is accepted as truthful across the supported zoom
   states
4. fallback clip interiors no longer reflow chaotically during zoom
5. any remaining future refinements now belong to later stages or to a future
   reopen only if a real regression is found

## Real-Device Acceptance Set Used For Closure

Run these exact checks on the connected device:

1. zoom out heavily and confirm ruler labels stay readable
2. zoom to a normal edit range and confirm second spacing remains sensible
3. zoom into seconds-plus-frames range and confirm labels do not become random
4. confirm the last visible end label always matches the true content end

## Handoff Note

If work pauses here and later resumes with:

`continue timeline plan`

the next implementation target should now be:

- open `Stage 4 - Trim Interaction Hardening`
- start with trim handle capture reliability

## References

- [Stage 6 Timeline Professionalization Master Plan](/Users/mx/Documents/InGeneBMFPro/docs/process/stage-6-timeline-professionalization-master-plan.md)
- [Stage 6 Timeline Professionalization - Stage 2 Professional Live Scrub Engine](/Users/mx/Documents/InGeneBMFPro/docs/process/stage-6-timeline-professionalization-stage-2-professional-live-scrub-engine.md)
