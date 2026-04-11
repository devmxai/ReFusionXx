# Feature Plan - Speed (Normal And Curve)

## Status

Implementation active.

This is an independent feature plan.

It is not part of the timeline professionalization stage chain, even though it
depends on the timeline foundation already built.

## Purpose

This feature adds professional clip speed authoring to the editor, starting
with:

- `Normal` constant speed for a selected video clip
- a future `Curve` mode for speed ramps and speed points

The implementation must remain:

- clip-level
- timeline-aware
- preview-safe
- extensible toward future time remapping

## Product Direction

The first user-facing entry point is a `Speed` icon in the bottom dock.

When a speed-editable video clip is selected:

- tapping `Speed` opens a bottom sheet
- the sheet exposes:
  - `Normal`
  - `Curve`
- `Normal` uses a centered slider plus preset chips
- `Curve` is future-gated until the timeline and native transport support
  non-linear time mapping

## Architecture Rules

Speed must not be implemented as a fake player-global shortcut for authored
clip speed.

Authoring truth must eventually live at the clip level:

- clip speed metadata belongs to `TimelineClipData`
- timeline truth must eventually distinguish:
  - source span
  - timeline span
  - playback rate
- native transport must later receive rate-aware segment payloads

## Planned Slices

1. `Slice 1 - UI And Metadata Foundation`
- add `Speed` entry to the bottom dock
- add a speed bottom sheet with `Normal / Curve`
- add clip-level speed metadata foundation
- show saved speed metadata visually on the timeline clip

2. `Slice 2 - Constant Speed Timeline Semantics`
- make `Normal` speed change clip timing truth
- add source-span vs timeline-span separation
- keep split / duplicate / trim semantics correct

3. `Slice 3 - Native Preview / Playback Integration`
- extend transport payloads with speed-aware clip data
- make playback, scrub, and seek respect clip speed
- keep UI time, preview time, and native time aligned

4. `Slice 4 - Curve Foundation`
- define curve data model
- define point/segment ownership
- prepare non-linear time mapping without breaking `Normal`

## Implemented So Far

The feature now goes beyond metadata-only foundation:

1. `Speed` is a first-class bottom-dock entry
2. a dedicated speed bottom sheet now exists with:
   - compact `Normal / Curve` tabs
   - centered slider
   - `Play`
   - `Apply`
   - no dark barrier over the editor background
   - a shorter, more compact presentation tuned for the current editor shell
3. clip-level speed truth now exists in `TimelineClipData` with:
   - source span
   - timeline span
   - playback rate
4. `Apply` now changes the selected video clip timing truth:
   - timeline duration updates from the chosen speed
   - the clip remains tied to its original source span
5. split/trim math now begins respecting constant speed authoring
6. timeline transport payloads now carry:
   - source start/end
   - timeline duration
   - playback rate
7. native transport now begins honoring constant per-segment speed in
   timeline playback/scrub mapping
8. clips with non-default speed render a visible speed badge on the timeline

## Current Remaining Work

The feature is no longer a UI-only slice, but it is not fully closed yet.

What still remains:

- repeated real-device acceptance for:
  - `apply -> play`
  - `slow -> fast -> normal`
  - `split -> speed -> play`
  - `speed -> trim -> play`
- evaluate the perceived smoothness ceiling for low-fps sources versus true
  high-frame-rate or future interpolation workflows
- hardening duplicate/reorder behavior under authored speed
- audio policy decisions for slow/fast ranges
- full `Curve` implementation

## Handoff Truth

If work resumes later, the next correct target is:

- real-device acceptance and hardening of `Normal` speed
- then duplicate/reorder semantics under speed
- then future `Curve` foundation
