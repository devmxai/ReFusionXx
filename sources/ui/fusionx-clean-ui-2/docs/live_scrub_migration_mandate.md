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

## Protected Integration Rule

The current active live scrub path is a protected system boundary.

This means:

- `Scope Layer` work must not modify the active live scrub path as an
  unannounced or incidental side effect
- animation foundation work must not modify the active live scrub path as an
  unannounced or incidental side effect
- timeline UX work must not modify the active live scrub path as an incidental
  side effect
- no work may create a scope-specific scrub path, alternate scrub owner, or
  temporary scrub fork without explicit approval

If a future task discovers that a real change to the protected live scrub path
is required:

1. implementation must stop at that dependency boundary
2. the exact reason and affected files must be documented
3. the smallest possible change must be proposed
4. no change may be executed without explicit user approval

It is forbidden to force such a change through indirectly, or to weaken the
current scrub behavior under the claim that the larger feature "needs it."

This rule is intentionally strict about disclosure, not absolute prohibition.
If a professional-grade implementation truly requires a scoped and explicit
live scrub change, that change may be considered only after the dependency is
surfaced clearly and approved explicitly.

## Timeline Runtime Boundary

Future timeline, scope, transition, animation, and FX work must not call the
protected scrub or transport internals directly. Those features must pass
through the `TimelineRuntime` contracts defined in:

`docs/timeline_runtime_boundary.md`

This boundary is not a ban on live scrub evolution. It is the required safe
route for any feature that needs to interact with timeline runtime behavior.

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

## Implementation Snapshot

### Beta7 Now Okay

Status snapshot date: `2026-04-17`

This repository state is the current official checkpoint for the live scrub
migration on `main`.

The active live scrub path is now:

`Timeline touch -> Stage5TimelineScrubPlatformView -> Stage5NativeScrubEngine -> Stage5SurfaceScrubDecoder -> Stage5ScrubOverlayTextureView`

The playback and settle path remains:

`Stage5TransportManager -> ExoPlayer`

This means:

- `ExoPlayer` is no longer used as the per-frame renderer during active scrub
- the scrub preview is rendered by the native scrub engine through its own
  overlay surface
- `ExoPlayer` is reserved for playback and the final scrub settle handoff

### Current Native Scrub Engine

The current live scrub engine is decoder-backed and proxy-backed.

Implemented pieces:

- `Stage5NativeScrubEngine` owns descriptor resolution, scrub target updates,
  boundary warmup, and render-loop ownership
- `Stage5SurfaceScrubDecoder` keeps a dedicated native decoder path for scrub
  output
- `Stage5ScrubPreviewProxyManager` builds and serves low-latency preview proxy
  media for scrub playback
- `Stage5PreviewPlatformView` hosts the playback surface and the scrub overlay
  surface
- `Stage5ScrubOverlayTextureView` applies native aspect transforms for scrub
  content independently of the player surface
- `LiveScrubPreviewSourceDescriptor` now carries source dimensions so the
  native scrub overlay can fit content by source aspect ratio

### Timeline Playback Backend State

The current timeline playback backend is still owned by
`Stage5TransportManager`.

Backend modes currently in use:

- `SINGLE_SOURCE_EXO` for contiguous clips that can be represented as one
  source timeline
- `RUNS_EXO` for timelines that cross source boundaries
- `COMPOSITION` remains future-gated and is still disabled for timeline
  preview parity

### What Was Removed From The Hot Path

The following legacy behaviors are no longer part of the active live scrub
display path:

- transport-driven per-move scrub seeking through `ExoPlayer`
- player-backed preview rendering during active scrub
- frame-extraction and frame-store ownership of the hot scrub render path

Utility code such as thumbnail loading can still exist outside the hot path,
but it is not the active scrub renderer.

### Latest Fixes Included In This Snapshot

This snapshot includes the following boundary and stability fixes:

- cross-clip scrub deadlock fix:
  `Stage5NativeScrubEngine` no longer calls decoder force-seek while holding
  the engine lock; the force-seek request is deferred into the render snapshot
  and executed outside the engine lock
- scrub aspect handoff fix:
  scrub aspect ratio is now applied on the native overlay host before render,
  and the overlay texture view preserves a dedicated transform state per scrub
  aspect ratio
- boundary warmup:
  the scrub engine primes adjacent preview sources near clip boundaries
- run-boundary playback fix:
  `Stage5TransportManager` now advances from the current `RUNS_EXO` item to the
  next run instead of pausing at the end of the first run when the next clip is
  in a different source

### Known Remaining Gaps

The migration is significantly advanced, but the following items are still
open:

- cross-source live scrub can still feel slower than intra-source scrub because
  the decoder must rebind between different media sources
- the native scrub descriptor currently carries source dimensions only; full
  clip placement metadata such as canvas placement, crop, translation, and
  authored transform data is not yet transported into the scrub overlay path
- the most recent run-boundary playback fix was compiled and analyzed
  successfully, but the final on-device validation for that exact revision was
  interrupted by an `adb` device disconnect and still needs direct verification

### Validation State At This Checkpoint

Verified in this codebase state:

- active scrub rendering is native-owned, not `ExoPlayer`-owned
- multi-clip scrub no longer follows the earlier lock inversion path that
  caused `MotionEvent` ANR at source boundaries
- build validation passes:
  - `./gradlew app:compileDebugKotlin`
  - `flutter analyze`
  - `flutter build apk --debug`

Not yet declared complete:

- final 100% parity and stability across all cross-source boundary cases
- full clip-placement parity between playback surface and scrub overlay for all
  canvas arrangements
