# Professional Canvas And Timeline

Status: architecture plan only. No runtime code is implemented by this file.

This document is the official architecture plan for making the ReFusionXx
canvas and timeline behave like one professional authoring system.

It is intentionally separate from `professional_scope_timeline.md`.

`professional_scope_timeline.md` owns the scoped-layer user experience.

This document owns the shared canvas/timeline property model that scope,
preview, playback, live scrub parity, and export must all respect.

## 0. Purpose

The goal is to make canvas editing and timeline editing operate on the same
authored layer properties.

Related architecture:

- `docs/professional_scope_timeline.md` owns scoped-layer timeline UX
- `docs/professional_direct_text_effects_and_scriptable_motion.md` owns the
  direct text effects and scriptable motion architecture that compiles into the
  same shared property graph
- `docs/live_scrub_migration_mandate.md` remains the binding protected-system
  directive for live scrub and must be read before implementation

Professional behavior means:

- moving a layer on the canvas writes the same property that the timeline shows
- editing a property lane updates the same value the canvas renders
- playback, scrub, and export evaluate the same serialized property data
- no temporary or mock animation model is allowed to become a product path

This is the long-term foundation for:

- position animation
- scale animation
- rotation animation
- opacity animation
- text property animation
- FX parameter animation
- graph editing
- presets

## 1. Non-Negotiable Boundary

### 1.1 Single Source Of Truth

`Single source of truth` means one authoritative authoring model for:

- canvas edits
- timeline lane edits
- scoped-layer edits
- preview evaluation
- export evaluation
- undo/redo history

The shared model must own:

```text
layer identity
timeline span
property path
default value
keyframes
interpolation
easing
selection state
command history
```

It must eventually cover:

```text
transform.position.x
transform.position.y
transform.scale.x
transform.scale.y
transform.rotation
opacity
text.fillColor
text.fontSize
effects.blur.amount
effects.glow.intensity
```

### 1.2 What This Does Not Mean

This plan does not mean:

- rebuilding the root timeline
- replacing `TimelinePanel`
- creating a new scrub engine
- merging native Live Scrub ownership into Flutter authoring code
- changing decoder/proxy/transport ownership as a side effect of authoring work

This plan unifies:

- authoring
- property storage
- property evaluation
- command boundaries

It does not unilaterally unify:

- native render ownership
- native scrub ownership
- decoder ownership

Live Scrub remains a protected engine boundary.

## 2. Professional Reference Model

The target model follows the same architectural idea used by professional
motion tools:

- properties belong to layers
- properties can be keyframed over time
- canvas tools and timeline tools edit the same underlying property state
- graph/easing tools refine the same keyframes, not a duplicate curve
- effects are layer-local modifiers with animatable parameters

Official reference anchors:

- Adobe describes animation as changing layer/effect properties over time with
  keyframes: https://helpx.adobe.com/after-effects/using/animation-basics.html
- Apple Motion documents adding keyframes from the canvas, timeline, and
  inspector while evaluating the same property state:
  https://support.apple.com/guide/motion/add-keyframes-motn1474a02c/mac
- Apple Motion documents animation paths drawn and edited in the canvas:
  https://support.apple.com/ar-eg/guide/motion/motn14747e9e/mac
- Apple Motion documents a dedicated keyframe editor over the same underlying
  animation data:
  https://support.apple.com/en-gw/guide/motion/motn14749268/mac
- Alight Motion documents mobile animation easing as property-level timing
  control:
  https://support.alightmotion.com/hc/en-us/articles/10536934703889-Animation-Easing-Curves

## 3. Current Code Foundation

The current code already points in the right direction.

Known foundations:

- text/motion models already contain real transform-style properties
- canvas movement, scale, and rotation already write motion-capable state
- preview already evaluates text motion state into rendered transforms
- timeline already builds text clips from project entries
- scoped opacity keyframes now prove real lane-based evaluation can drive a
  visible effect

The problem is not that the app has no foundation.

The problem is that canvas-authored motion and scoped timeline lanes are not
yet one formal property graph.

This plan exists to remove that split.

## 4. Target Architecture

### 4.1 Shared Property Graph

The authoritative flow must be:

```text
canvas gesture
or timeline lane edit
or scope command
-> command boundary
-> shared property graph
-> evaluator
-> preview/playback/live scrub overlay/export
```

No UI surface owns animation state directly.

UI surfaces only issue commands and render snapshots.

### 4.2 Property Channel

Each animatable property is represented as a durable channel:

```text
PropertyChannel
  id
  layerId
  propertyPath
  valueKind
  defaultValue
  keyframes[]
```

Each keyframe is represented as:

```text
Keyframe
  id
  propertyPath
  localTime
  value
  interpolation
  easing
```

Rules:

- keyframes use layer-local time when attached to a layer span
- root/global time is used only for projection, playback, scrub, and export
  alignment
- values must be real authored values, not display-only markers
- no lane may invent keyframes for decoration

### 4.3 Command Boundary

All canvas/timeline property edits must flow through explicit commands.

Initial command set:

```text
setProperty(layerId, propertyPath, value)
addKeyframe(layerId, propertyPath, localTime, value)
moveKeyframe(layerId, keyframeId, localTime)
setKeyframeValue(layerId, keyframeId, value)
deleteKeyframe(layerId, keyframeId)
setInterpolation(layerId, keyframeId, interpolation)
applyPreset(layerId, presetId, localStartTime)
```

This protects:

- undo/redo
- duplicate
- trim
- delete
- export parity
- scoped timeline projection

### 4.4 Canvas Role

The canvas is the visual editor for property values.

Canvas behavior:

- move writes `transform.position.x/y`
- scale writes `transform.scale.x/y`
- rotate writes `transform.rotation`
- opacity controls write `opacity`
- text controls write typed text property paths

If the current time has an active keyframe for that property, the canvas updates
that keyframe.

If there is no active keyframe, behavior must be explicit:

- update the default/static value, or
- create a keyframe only when auto-key is enabled

No hidden auto-key behavior is allowed.

### 4.5 Timeline Role

The timeline is the temporal editor for the same properties.

Timeline behavior:

- shows property lanes
- shows real keyframes
- edits keyframe time
- edits keyframe value through value controls
- edits interpolation/easing
- filters animated properties
- later supports graph editing

The timeline must not store a separate copy of canvas property state.

### 4.6 Scope Timeline Role

Scoped Layer Timeline is a projection over the same property graph.

It may:

- focus one layer
- display layer-local time
- show property lanes under that layer
- expose Animate and FX commands

It may not:

- define a separate property model
- own a separate animation engine
- fork `TimelinePanel`
- create scope-only keyframe semantics

## 5. Animate And FX Domains

`Animate` and `FX` are separate product domains.

They may share:

- property channels
- keyframes
- easing
- graph editing primitives
- command/history infrastructure

They must remain separate in meaning:

- `Animate` edits direct layer properties such as position, scale, rotation,
  opacity, text style, and presets built from those properties
- `FX` adds ordered non-destructive effect instances with animatable parameters

FX parameters use property paths like:

```text
effects.blur.amount
effects.glow.intensity
effects.shadow.distance
```

This prevents short-term UI convenience from collapsing two different editing
domains into one confusing lane type.

## 6. Evaluation Contract

Every property shipped through this system must evaluate consistently in:

- canvas preview
- playback preview
- scoped timeline scrub
- root timeline Live Scrub overlay
- export

Evaluation rules:

- no mock values
- no decorative keyframes
- no duplicate evaluator for one property
- no playback-only effect path
- no scrub-only effect path
- preview and export must read the same serialized property data

If a property cannot satisfy this contract yet, it may stay behind a feature
gate, but it may not ship as a fake lane.

## 7. Live Scrub Protection

Live Scrub remains protected.

This plan may require authored property values to be visible during Live Scrub,
but it does not authorize broad native scrub rewrites.

If parity requires touching protected scrub files:

1. stop the canvas/timeline implementation
2. document the exact reason
3. identify the smallest affected file set
4. describe regression risk
5. request explicit approval

No Live Scrub change may be hidden inside a property authoring task.

## 8. Execution Plan

### Phase 1 - Foundation Audit And Contract

Goal:

Write the exact property/channel contract that current canvas motion and scoped
timeline lanes must converge on.

Deliverables:

- current property inventory
- supported property paths
- identity/span model
- command contract
- lifecycle rules for trim/duplicate/delete
- preview/export ownership notes

Exit criteria:

- no second temporary property model
- known gaps are written as blockers
- first vertical slice can be implemented without guessing

### Phase 2 - Opacity Consolidation

Goal:

Make the existing scoped `opacity` implementation the reference vertical slice.

Deliverables:

- one opacity property channel
- real keyframes
- shared evaluator
- playback parity
- scrub parity
- export path decision documented

Exit criteria:

- opacity is no longer a scoped-only feature
- opacity behaves the same from canvas, timeline, playback, scrub, and export
  where supported

### Phase 3 - Position

Goal:

Add true position authoring on the shared property graph.

Deliverables:

- `transform.position.x`
- `transform.position.y`
- canvas move writes the same channels
- scoped lane edits the same channels
- keyframes evaluate in preview and scrub

Exit criteria:

- moving on canvas and editing in timeline produce the same serialized result

### Phase 4 - Scale

Goal:

Add true scale authoring.

Deliverables:

- `transform.scale.x`
- `transform.scale.y`
- uniform/non-uniform behavior defined
- canvas handles and timeline lanes agree

Exit criteria:

- scale keyframes preview and scrub with no separate mock path

### Phase 5 - Rotation

Goal:

Add true rotation authoring.

Deliverables:

- `transform.rotation`
- canvas rotation handles write the same property
- timeline value controls edit the same keyframes

Exit criteria:

- rotation behavior is deterministic across preview, scrub, and export planning

### Phase 6 - Easing And Graph Preparation

Goal:

Add timing quality without changing the property contract.

Deliverables:

- linear
- hold
- ease in
- ease out
- ease in-out
- graph editor data preparation

Exit criteria:

- easing edits the same keyframes
- no duplicate curve storage

### Phase 7 - FX Parameter Channels

Goal:

Make FX parameters part of the same authoring contract.

Deliverables:

- effect instance identity
- parameter property paths
- parameter keyframes
- parameter evaluator

Exit criteria:

- FX parameter animation uses the same primitives as direct layer animation

## 9. Validation Matrix

Run after each property phase:

- create layer
- select layer on canvas
- edit property on canvas
- inspect property lane
- add keyframe
- edit value
- move playhead
- playback
- live scrub
- exit and re-enter scope if scoped UI is involved
- duplicate layer
- trim layer
- delete layer
- undo/redo if available
- export sample if export path is touched

Required parity checks:

- canvas value equals lane value
- lane value equals preview value
- playback value equals scrub value
- scrub release frame is stable
- duplicate keeps authored properties correctly
- trim handles local-time behavior correctly

## 10. Relationship To Scope Timeline

`professional_scope_timeline.md` should not own this architecture.

It depends on this document.

Scope Timeline is responsible for:

- opening scoped mode
- projecting one layer into local time
- rendering source row and property lanes through `TimelinePanel`
- exposing scoped toolbar actions
- keeping scope gestures safe

Professional Canvas And Timeline is responsible for:

- shared property graph
- canvas/timeline convergence
- property evaluation
- command/history boundaries
- scrub/play/export parity rules

This separation keeps the project from mixing a broad animation architecture
plan into one scoped UI feature.

## 11. Final Rule

The canvas and timeline must become two editors over one authored property
system.

If a change makes the canvas and timeline disagree, or creates a second hidden
animation model, the change is wrong for this plan.
