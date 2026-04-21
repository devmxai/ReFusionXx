# 07 - Forbidden Changes

These changes are forbidden unless the task is explicitly a live scrub task and
the validation matrix is run afterward.

## During Active Scrub

Never reintroduce:

```text
ExoPlayer.seekTo(...) per touch move
ExoPlayer.setMediaItem(...) per touch move
ExoPlayer.setMediaItems(...) per touch move
ExoPlayer.prepare() per touch move
Flutter MethodChannel dispatch for every touch move
Flutter bitmap/canvas active scrub rendering
player surface as the active scrub frame source
```

## Native Engine Hot Path

Do not add:

```text
MediaMetadataRetriever calls in active render loop
Media3 Transformer work in active render loop
network or filesystem scans in active render loop
blocking locks shared with timeline/export code
unbounded proxy generation competing with active decoder
```

## Flutter Timeline

Do not make timeline UI changes that silently change:

```text
scrub regions
scrub hit-test behavior
scrub callback order
current time ownership
clip descriptor source windows
preview source descriptors
```

If a timeline UI feature needs to affect these, the change must be reviewed as
a live scrub change.

## Preview Geometry

Do not change:

```text
aspect ratio reporting
source width/height semantics
canvas fit/fill behavior
native preview visibility gating
scrub overlay transform
```

without validating scrub overlay parity.

## Proxy Policy

Do not make proxy validation stricter if the fallback is heavy source decode
during active scrub.

High-risk changes:

```text
duration validation
temporary proxy replacement
cache key changes
previewUri acceptance rules
raw source fallback behavior
proxy generation concurrency
```

Any such change must be tested with high-resolution and cross-clip media.

## Export And Transition Work

Export and transition features must not mutate live scrub contracts as a side
effect.

If export, transitions, AI effects, or 4K support change clip timing,
source windows, preview media, dimensions, or timeline placement, they must
prove that the resulting scrub descriptors are unchanged or intentionally
updated with validation.

