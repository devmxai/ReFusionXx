# Live Scrub Migration Mandate

## Binding Directive

This document is the binding architectural directive for live scrub migration.
It supersedes interim scrub plans, transport-backed preview tuning, and any
partial hybrid implementation.

The live scrub display path must be rebuilt so that:

- `ExoPlayer` is completely removed from the active scrub display path
- `ExoPlayer.seekTo()` is never called during active scrub
- `ExoPlayer.setMediaItem()` is never called during active scrub
- no `ExoPlayer` method that triggers decode, demux, or surface render is
  called during active scrub
- the `ExoPlayer` surface is never the source of pixels shown during active
  scrub
- `ExoPlayer` is used only for playback and the final exact settle after
  touch-up

## Mandatory Execution Rule

This rule is mandatory:

- no individual implementation work may partially preserve the old hybrid scrub
  architecture once a stricter migration directive exists
- no future work may reintroduce transport-backed live scrub behavior as a
  shortcut
- no future work may leave dual scrub paths in place "temporarily" unless the
  phase explicitly ends with deletion of the obsolete path

## Required Layers

The live scrub system must be rebuilt as three separated layers:

1. `Frame Extraction Pipeline`
   A background extraction pipeline prepares indexed preview frames per clip.
2. `Dedicated Native Scrub Render Surface`
   A native-owned surface renders preview frames independently of `ExoPlayer`.
3. `Native Touch Event Capture`
   Timeline scrub touch-move events are handled natively with no per-frame
   Flutter round-trip.

## Phase Order

The required migration order is:

1. lock the directive and instrument current violations
2. build the background frame extraction pipeline
3. wire imported timeline media to extraction readiness
4. add the dedicated native scrub render surface over the playback surface
5. move active scrub touch handling to native
6. delete obsolete seek/coalescing/dispatch code from the active scrub path

The migration is not complete until all binary success criteria pass:

- zero `ExoPlayer.seekTo()` calls during active scrub
- continuous native scrub-surface drawing during active scrub
- no black frames, no final snap-only behavior, and no visible surface swap
- `ExoPlayer` decoder threads remain idle during active scrub
- scrub display remains functional even if `ExoPlayer` is hypothetically
  removed from the active scrub path
