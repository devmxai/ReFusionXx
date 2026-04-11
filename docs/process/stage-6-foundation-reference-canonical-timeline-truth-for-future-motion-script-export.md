# Stage 6 Foundation Reference - Canonical Timeline Truth For Future Motion, Script, And Export Layers

## Status

- document type: foundation reference
- execution status: reference only
- implementation authority: current `Stage 6` foundation work only
- explicitly not a motion implementation plan

This document exists to connect two truths that must not drift apart:

1. exact editor timeline truth
2. future motion / script / keyframe / export truth

It defines the shared foundation that both systems must use.

Companion future-architecture reference:

- [Professional Motion](/Users/mx/Documents/InGeneBMFPro/docs/process/professional-motion-architecture.md)

## Why This Document Exists

The project already has two valid but separate architecture threads:

- exact timeline precision and playhead/cut correctness
- future motion/script/keyframe architecture above `BMF`

If those are built separately, the project risks:

- one timeline truth for editing
- another timeline truth for motion authoring
- a third interpretation inside export/runtime

That would permanently weaken the editor.

This document prevents that outcome.

## Executive Verdict

The project must build **one canonical timeline truth** now, during `Stage 6` foundation work, so that future:

- keyframes
- motion scripts
- structured motion JSON
- transitions
- text animation
- camera motion
- export
- `BMF/FFmpeg` execution

all consume the same exact model later.

This means:

- timeline precision is not separate from motion architecture
- timeline precision is the foundation under motion architecture
- motion implementation still remains deferred
- but motion compatibility must be designed into the timeline model now

## Reviewed Consensus

This document reflects the combined conclusions of:

- timeline precision review
- current codebase review
- `Media3` constraints
- `BMF/FFmpeg` execution-layer constraints
- NLE behavior expectations
- monitor review

### Consensus Summary

- exact editor truth must be application-owned
- preview/runtime must be a projection, not the owner
- `double seconds` are not sufficient as long-term edit truth
- future motion/keyframes must anchor to the same canonical time domain
- future `BMF` execution should receive normalized runtime data, not raw editor/UI state

## The Single Shared Foundation

The project must standardize on one shared foundation made of five parts:

1. canonical time model
2. canonical timeline truth
3. canonical clip/layer/scene identity
4. normalization boundary
5. execution projection boundary

Everything else must sit above or below this, never beside it.

## Part 1 - Canonical Time Model

### Requirement

The project must stop treating floating-point seconds as the source of truth.

The project must own one exact time representation, for example:

- `TimelineTime(value, timescale)`
- or an equivalent integer tick model

This should behave conceptually like:

- `CMTime`
- `pts * time_base`

### Why It Matters

Without this:

- `split` cannot remain exact after repeated edits
- `trim` cannot remain exact under mixed rates
- keyframes cannot anchor exactly
- script timing cannot be deterministic
- export timing cannot safely mirror editor timing

### Rule

All of these must eventually use canonical time, not floating-point seconds:

- playhead
- clip in/out
- clip duration
- timeline placement
- keyframe times
- animation ranges
- transition windows
- export ranges

## Part 2 - Canonical Timeline Truth

The editor must own one authoritative timeline model.

At minimum, that model must define:

- ordered tracks/layers
- ordered clips/items
- exact timeline placement
- exact source windows
- exact playhead position
- exact ripple/delete semantics

This truth must remain application-owned.

Native preview must not reinterpret deleted time back into existence.

Future motion authoring must not introduce a second hidden timeline.

## Part 3 - Canonical Clip / Layer / Scene Identity

To support both editing and future motion authoring, the model must treat these as first-class concepts:

- project
- scene
- layer/track
- clip/item
- property target
- animation target

This means a future keyframe must be able to say, in exact terms:

- animate `opacity`
- on this target
- from this canonical time
- to this canonical time

without inventing a new identity system later.

## Part 4 - Normalization Boundary

Future motion/script architecture must not read raw editor UI state directly.

There must be a normalization / compile boundary that produces resolved runtime data.

That normalized data should eventually include:

- resolved clip windows
- resolved layer stack
- resolved visibility windows
- resolved transition windows
- resolved property curves
- resolved text/camera/effect instructions

This boundary is where future:

- script interpretation
- JSON validation
- preset expansion
- keyframe evaluation

must happen.

## Part 5 - Execution Projection Boundary

Below the normalized model, execution backends should only receive a projection of truth.

That includes:

- `Media3` preview/transport
- future export path
- future `BMF/FFmpeg` execution

This creates a strict rule:

- execution does not own the edit model
- execution consumes the resolved model

## What This Means For Motion / Script / Keyframes

Future motion systems must anchor to the same exact timeline model.

### Motion Script

A future motion script must reference:

- canonical target ids
- canonical timeline time
- canonical property names

Not:

- approximate preview positions
- current screen pixels
- player-internal time only

### Keyframes

Keyframes must eventually store:

- target id
- property id
- exact key time
- value
- interpolation/easing data

And those key times must use the same canonical time model as:

- playhead
- cuts
- trims
- transitions

### Properties

Properties such as:

- opacity
- position
- scale
- rotation
- blur
- crop
- text reveal

must evaluate against the same canonical time domain.

## What This Means For Preview

Preview may remain approximate in performance behavior during drag.

But preview must never redefine editor truth.

This means:

- scrub throttling is allowed
- seek coalescing is allowed
- player rounding is allowed where required

But:

- cut position is not allowed to move because preview is approximate
- keyframe timing is not allowed to move because preview is approximate
- seam geometry is not allowed to redefine canonical time

## What This Means For Export And BMF

Future `BMF` use remains valid only if it consumes the same normalized canonical model.

That means the export path should eventually receive:

- exact clip windows
- exact timeline placement
- exact animation timing
- exact property instructions

not:

- raw widget state
- floating-point approximation leftovers

## What We Must Build Now

Inside current `Stage 6` foundation work, the project should build only the foundation needed for this future compatibility.

That means the current active responsibility is:

1. exact time model
2. exact playhead truth
3. exact clip window truth
4. exact structural edit truth
5. exact Flutter/native projection contract
6. exact timeline geometry

This is enough to make future motion work attach cleanly later.

## What We Must Not Build Yet

This document does **not** authorize implementation of:

- keyframe engine
- motion script interpreter
- animation preset system
- text motion runtime
- transition authoring system
- camera motion authoring
- `BMF` motion execution
- export implementation

Those remain future work.

## Current Recommended Build Sequence

The correct order remains:

1. `Stage 6` exact timeline foundation
2. normalize the timeline truth
3. close the precision model
4. then open motion/keyframe authoring above it
5. then connect future `BMF/export` execution below it

This sequence is intentional.

If the project reverses it, motion authoring will be forced to sit on unstable timing semantics.

## Professional Rule Of Thumb

The project should think in this order:

- exact truth first
- exact geometry second
- authoring systems third
- execution systems fourth

Not:

- player behavior first
- motion UX first
- truth later

## Exact Next Use Of This Document

Use this document now as a foundation rule while executing:

- [Stage 6 - Timeline Precision And Canonical Time Model](/Users/mx/Documents/InGeneBMFPro/docs/process/stage-6-timeline-precision-and-canonical-time-model.md)
- [Stage 6 - Timeline Precision Gated Execution Plan](/Users/mx/Documents/InGeneBMFPro/docs/process/stage-6-timeline-precision-gated-execution-plan.md)

Its purpose is:

- to keep current timeline work compatible with future motion/script/export layers
- without opening those layers prematurely
