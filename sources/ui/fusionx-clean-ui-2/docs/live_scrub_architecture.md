# Live Scrub Architecture

## Status

This document is the source of truth for `ReFusion` live scrub architecture.
It replaces ad-hoc seek tuning as the primary design reference.

## Implementation Progress

- `Stage 0`: complete
- `Stage 1`: complete
- `Stage 2`: in progress

### Stage 1 completed work

- `LiveScrubPipeline` foundation added
- playback/scrub transport wrappers added
- main timeline scrub begin/present/end routed through the pipeline
- editor-screen playback and scrub lifecycle routed through pipeline-backed
  helpers instead of direct transport orchestration
- auxiliary transport resets normalized through the same session-ending path

### Stage 2 progress so far

- in-memory scrub preview source catalog added
- scrub sessions now resolve primary/adjacent visual clip sources before
  preview dispatch
- preview thumbnail warmup is now tied to scrub-session source selection as the
  first proxy-preparation slice
- Android-side timed frame preview extraction path added
- Flutter transport now exposes `loadMediaFramePreview(...)` for proxy frame
  requests
- editor preview overlay can now present proxy scrub frames above the native
  surface during scrub sessions
- proxy frame path is currently augmentative, not authoritative, so the
  transport-backed live scrub path remains active while proxy cadence is tuned
- proxy runtime presentation is temporarily gated off in user-facing builds
  until it reaches parity; the architecture and extraction path remain in place
  for continued Stage 2 work without regressing live scrub behavior
- the current user-facing path now favors transport-backed live scrub with
  display-aligned dispatch cadence over seek flooding, as an interim stability
  step while proxy preview parity is still under construction
- post-release scrub momentum is temporarily disabled in the user-facing path
  so the frame under the playhead at release remains authoritative
- scrub seek policy is now adaptive per jump size: short deltas prefer exact
  seek semantics, while larger jumps stay on lighter scrub-safe behavior
- directional seek semantics are now applied for larger scrub jumps so reverse
  scrub resolves against previous sync points instead of behaving like forward
  scrub with extra hitching

### Stage 2 remaining work

- strengthen proxy frame routing so all scrub updates prefer the proxy path
  consistently without regressions
- improve proxy frame cadence and fallback rules for slow/medium/fast drag
- re-enable proxy runtime presentation only after it no longer introduces stale
  or delayed frames over the authoritative transport preview
- preserve the current pipeline contracts while swapping the preview source

## Problem Statement

The current editor still routes scrub interactions through a seek-driven preview
path:

`finger -> Flutter timeline -> MethodChannel -> Stage5 -> Media3/ExoPlayer seek -> decoder -> canvas`

This path can be improved, but it cannot reliably deliver editor-grade live
scrub parity across slow, medium, and fast drag speeds for arbitrary compressed
media. The limitations are most visible with:

- GOP-heavy video
- HEVC/H.265 clips
- seam crossings between adjacent clips
- mixed aspect ratios and mixed source encodes
- exact final-frame presentation after a fast release

## Product Requirement

For the user, live scrub must feel like one continuous transport system:

- slow drag: exact and visually dense
- medium drag: smooth and proportional
- fast drag: still visually alive, not frozen or stale
- release: final frame appears immediately and matches the playhead position
- seam crossing: no hitch, no black frame, no stale frame flash

## Non-Goals

The target is not to guarantee that every real decoded source frame is shown
during extreme scrub velocity on every codec and every device using the
playback player alone. That is not realistic on a pure seek-based preview path.

## Core Decision

`Media3/ExoPlayer` remains the playback engine.

`Live Scrub Preview` becomes a separate preview path.

The user sees one scrub system. Internally there are two coordinated paths:

1. `Playback Path`
2. `Scrub Preview Path`

At release time, the playback path performs one exact settle.

## Target Architecture

### 1. Timeline Gesture Layer

Responsibilities:

- capture drag intent
- maintain 1:1 playhead movement
- classify velocity without changing the meaning of the drag
- never apply artificial timeline damping

### 2. Live Scrub Pipeline

Responsibilities:

- start/end scrub session
- route frame requests to the preview path
- coordinate exact settle at release
- expose telemetry for QA and debugging

### 3. Playback Controller

Responsibilities:

- play
- pause
- exact seek
- final settle after scrub release

### 4. Scrub Preview Controller

Responsibilities:

- own the preview-specific session
- present frames during drag
- switch preview strategies without changing UI behavior

### 5. Preview Source

Responsibilities:

- provide low-latency visual feedback during drag
- avoid stressing the playback decoder with exact seek for every move

The preview source can evolve across stages:

- Stage 1: transport-backed preview contract
- Stage 2: proxy preview media
- Stage 3: seam-aware preview routing
- Stage 4: frame cache / GPU-backed path

### 6. Exact Settle Coordinator

Responsibilities:

- perform one exact settle at release
- guarantee that the final visible frame matches the playhead
- avoid double-settle behavior and stale-frame flashes

### 7. Error Recovery

Responsibilities:

- recover from decoder/renderer failure
- rebuild preview path if needed
- keep the editor interactive

## Implementation Stages

### Stage 0: Foundation

Deliverables:

- architecture document
- `PlaybackController` contract
- `ScrubPreviewController` contract
- `LiveScrubPipeline` orchestration contract
- scrub flow moved behind these abstractions

Success criteria:

- no direct scrub orchestration from UI to transport without pipeline mediation

### Stage 1: Transport-Backed Pipeline

Deliverables:

- current native transport wrapped by playback/scrub controllers
- unified scrub session lifecycle
- removal of redundant forced preview dispatch
- release handled by one settle path only

Success criteria:

- scrub behavior becomes architecturally coherent
- telemetry is easier to reason about

### Stage 2: Proxy Preview Source

Deliverables:

- lightweight preview source derived from imported clips
- proxy-prepared preview assets or frame source
- live scrub driven by proxy path rather than exact player seek on every move

Success criteria:

- reduced decoder pressure
- improved slow/medium/fast scrub continuity

### Stage 3: Seam-Aware Preview

Deliverables:

- prewarm adjacent clip preview
- clean seam routing across clip boundaries
- no stale last-frame retention when crossing into the next clip

Success criteria:

- no visible seam hitch on scrub

### Stage 4: Exact Release Settle

Deliverables:

- one exact settle after release
- no stale-frame flash before final frame

Success criteria:

- final frame appears immediately and correctly

### Stage 5: Adaptive Internal Quality

Deliverables:

- same public scrub mode for the user
- internal quality tiers for slow/medium/fast drag
- all tiers use the same preview path family

Success criteria:

- drag speed changes quality strategy, not architecture

### Stage 6: Error Resilience

Deliverables:

- codec error recovery
- safe end-of-clip presentation
- renderer reset without editor freeze

Success criteria:

- no black frame freeze
- no transport dead-end after decoder failure

### Stage 7: Validation

Validation matrix:

- H.264
- HEVC
- same-source contiguous clips
- mixed-source clips
- mixed aspect ratios
- slow scrub
- medium scrub
- fast scrub
- release near seam
- release at end-of-clip

## Quality Gates

The system is considered accepted only if:

- playhead movement is proportional to drag movement
- scrub does not start with a stale pause frame
- fast release does not show an old frame before the final frame
- seam crossing remains live and readable
- end-of-clip does not produce a black frame
- decoder errors do not freeze the session

## Current Legacy Constraints

The current transport path is still seek-driven. Official `Media3` guidance
confirms that compressed video seek latency is dominated by synchronization
frame access and decode work. This means a seek-only preview path is not a
complete solution for editor-grade live scrub.

References:

- Android Developers `Media3` troubleshooting
- Android Developers `ScrubbingModeParameters`
- Android Developers `SeekParameters`
- BMF/BMFLite architecture and GPU media processing references

## Migration Rule

Any future scrub work must move the system further toward this architecture.
No new scrub-specific workaround should bypass the pipeline contracts or
reintroduce multiple competing scrub paths.
