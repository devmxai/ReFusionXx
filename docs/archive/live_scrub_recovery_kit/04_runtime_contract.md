# 04 - Runtime Contract

This is the exact behavior contract that must hold after restoring or porting
the live scrub engine.

## Ownership Contract

```text
Flutter:
  owns timeline data, viewport geometry, media descriptors, final state

Native timeline scrub view:
  owns active touch capture and timeline position calculation during gesture

Native scrub engine:
  owns active frame rendering during gesture

Transport/ExoPlayer:
  owns normal playback and final settle after touch-up only
```

## Active Scrub Contract

During active scrub:

- native receives touch move directly
- native computes timeline position
- native maps timeline position to source position
- native decoder renders frame to scrub overlay
- Flutter receives state callbacks only
- ExoPlayer does not seek per frame
- ExoPlayer does not become the displayed scrub frame source

## Final Settle Contract

On touch-up:

- native reports final timeline position
- Flutter updates timeline state
- Flutter calls `settleAfterScrubPositionMs`
- transport performs a single final settle
- scrub overlay hides only when playback surface has caught up or the settle
  watchdog completes

## Descriptor Contract

Every scrub descriptor must satisfy:

```text
timelineStartMs <= targetMs < timelineEndMs
sourcePositionMs = sourceStartMs + ((targetMs - timelineStartMs) * playbackRate)
sourcePositionMs is clamped to [sourceStartMs, sourceStartMs + sourceDurationMs]
scrubStoreKey remains stable for the same clip/media window
source dimensions represent the media used by scrub overlay aspect handling
```

## Viewport Region Contract

Scrub regions must be derived from the visible timeline viewport. They must
remain stable across:

- clip selection
- bottom tool changes
- export state changes
- transition panel changes
- non-structural UI rebuilds

Only true timeline geometry changes should change scrub regions:

- zoom
- scroll offset
- track height/layout
- clip start/end/duration
- trim/reorder/move state

## Proxy Contract

Preview proxy media is an optimization and should improve consistency. It must
not block active scrub indefinitely and must not silently force high-cost
original-media decode for every gesture.

Any proxy policy change must be tested with:

- short 720p video
- 1080p video
- long 4K video
- cross-clip scrub
- first scrub immediately after import

## Geometry Contract

The scrub overlay must match the playback preview's user-visible geometry.

Validate:

- portrait in portrait canvas
- square inside portrait canvas
- landscape inside portrait canvas
- second clip with different aspect ratio
- cross-clip scrub between different aspect ratios

