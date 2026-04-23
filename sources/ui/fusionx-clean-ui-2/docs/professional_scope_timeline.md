# Professional Scope Timeline

Status: planning document only. No runtime code is implemented by this file.

This document is the strict execution plan for building `Scoped Layer Timeline`
inside ReFusionXx.

The goal is to let the user double click a layer and enter a professional
layer-local timeline where animation and FX can be authored with keyframes,
without rebuilding the existing timeline and without regressing the current
Live Scrub quality.

Related architecture:

- `docs/professional_canvas_timeline.md` owns the broader canvas/timeline
  property architecture.
- `docs/professional_direct_text_effects_and_scriptable_motion.md` owns the
  direct text effects and scriptable motion system that must lower into the
  same property graph.
- `docs/live_scrub_migration_mandate.md` is the binding protected-system
  directive and must be read before implementation.
- This document owns only the scoped-layer timeline product plan.

## 0. Non-Negotiable Directives

### 0.1 Do Not Rebuild The Timeline

The existing timeline source code is the foundation.

The scoped timeline must reuse:

- `TimelinePanel`
- current ruler/playhead behavior
- current scroll/zoom behavior
- current clip visual cards
- current selection styling
- current trim/cut/duplicate primitives where applicable
- current native live scrub integration

Forbidden:

- building a separate `ScopeTimeline` engine from scratch
- forking `TimelinePanel`
- duplicating timeline gesture logic
- creating a second timeline model that drifts from the root timeline
- replacing the root timeline just to support scope mode

The scoped timeline is a `projection / mode` over the existing timeline, not a
new timeline product.

### 0.2 Do Not Touch Live Scrub

The current Live Scrub path is a protected system boundary.

Forbidden unless separately approved by the user:

- editing `NativeTimelineScrubSurface`
- editing `Stage5TimelineScrubPlatformView`
- editing `Stage5NativeScrubEngine`
- editing `Stage5SurfaceScrubDecoder`
- editing `Stage5ScrubOverlayTextureView`
- creating a scope-specific scrub path
- creating a fallback scrub path
- changing native scrub ownership
- changing transport settle handoff
- changing decoder/proxy behavior as a side effect of scope work

If any phase appears to require a Live Scrub change, work must stop and report:

- why the Live Scrub path is involved
- which files are involved
- what the smallest possible change would be
- what regression risk exists

No Live Scrub-related change may be hidden inside a scope/timeline task.

### 0.3 Architecture Dependency

Scoped Layer Timeline must consume the shared property architecture defined in:

`docs/professional_canvas_timeline.md`

This scope plan must not redefine:

- shared property graph
- canvas/timeline convergence
- global property evaluator
- export property contract
- Live Scrub ownership rules

Those belong to the canvas/timeline architecture plan.

### 0.4 First Implementation Point

The first user-facing implementation point of this scope plan remains:

`double click / double tap on a supported layer opens Scoped Layer Timeline`.

Supported in the first pass:

- `text`
- `image`

Deferred:

- `video` until text/image scope is stable
- `audio` until a dedicated audio studio plan exists

### 0.5 Scope Must Be Safe During Scrub

While Live Scrub, horizontal drag, kinetic timeline scroll, trim drag, or any
pending scrub dispatch is active:

- do not enter scope
- do not exit scope
- do not add keyframes
- do not add FX
- do not mutate layer structure
- do not open animation/FX bottom sheets
- do not route selection-changing double taps

Live Scrub always wins over scope editing.

### 0.6 Scrub Parity Approval Gate

For any property or effect shipped through scoped authoring:

- playback preview
- scoped scrub preview
- root timeline Live Scrub
- export evaluation

must agree on the same serialized property data and timing model.

If parity cannot be reached without touching protected native scrub files, that
work must be split into a separate explicitly approved task. It may not be
hidden inside general scope implementation.

## 1. Product Definition

`Scoped Layer Timeline` means:

- user is in the root timeline
- user double clicks a layer
- the app enters a timeline view scoped to that layer
- the layer appears as the top source row
- animation lanes and FX lanes appear under it
- edits are stored in layer-local time
- preview remains full composition by default
- return button exits to root timeline

This is similar in spirit to:

- After Effects: layer properties and effect properties animated with keyframes
- After Effects Graph Editor: value/speed graph for precise timing
- Alight Motion: mobile-first keyframe/easing/effect authoring per layer

Official reference anchors:

- Adobe describes animation as changing layer/effect properties over time with
  keyframes: https://helpx.adobe.com/after-effects/using/animation-basics.html
- Adobe Effects & Presets are applied to layers and can include keyframes,
  effects, and expressions:
  https://helpx.adobe.com/si/after-effects/using/effects-animation-presets-overview.html
- Alight Motion documents a large effect library and effect guides:
  https://support.alightmotion.com/hc/en-us/articles/10536991943569-Effects-Guide

## 2. Current Code Foundation

The implementation must build from the current code shape:

- Timeline engine:
  `lib/features/editor/presentation/widgets/timeline_panel.dart`
- Screen orchestrator:
  `lib/features/editor/presentation/screens/fusionx_clean_ui_screen.dart`
- Timeline models:
  `lib/features/editor/presentation/models/timeline_mock_models.dart`
- Time primitives:
  `lib/features/editor/presentation/models/timeline_time.dart`
- Existing scoped precedent:
  `_buildTransitionFocusScopedTracks(...)` in `fusionx_clean_ui_screen.dart`
- Current time offset support:
  `TimelinePanel.timeDisplayOffset`

Important finding:

`transition focus mode` already proves that the app can render a local/scoped
timeline projection through the same `TimelinePanel`. Scope Layer should reuse
that pattern, not invent a new one.

## 3. Core Architecture

### 3.1 Scope Session

Introduce a screen-level scope state:

```text
LayerScopeSession
  layerId
  layerKind
  globalStart
  duration
  localTime
  returnGlobalTime
  returnScroll
  returnZoom
  selectedLaneId
```

This is view state, not duplicated media state.

### 3.2 Scope Projection

Build scoped tracks by projection:

```text
root timeline data
-> selected layer
-> local 0..layerDuration projection
-> TimelineTrackData rows
-> existing TimelinePanel
```

No new timeline engine.

### 3.3 Time Mapping

All scope edits use local time.

```text
globalTime = layerGlobalStart + localTime
localTime = clamp(globalTime - layerGlobalStart, 0, layerDuration)
```

When rendering in `TimelinePanel`, use `timeDisplayOffset` so the UI can show
local time while native scrub and preview remain aligned with global project
time.

### 3.4 Scope Rows

In scope mode:

1. Row 1: selected source layer row.
2. Rows below: animation lanes.
3. Rows below animation: FX lanes.
4. Expanded FX lanes show parameter lanes.

The source row uses the same visual clip card style as root timeline.

## 4. Scoped Toolbar Contract

Root toolbar is not copied exactly. Scope toolbar is a profile of the same tools
surface.

Order:

1. Back to root timeline
2. Cut
3. Trim
4. Duplicate
5. Add Keyframe
6. Previous Keyframe
7. Next Keyframe
8. Easing / Graph
9. Animate
10. FX

`Delete` is not a primary scope toolbar action in the first implementation.

Reason:

- deleting the root layer while inside its child scope has high risk
- deleting individual keyframes/FX lanes is allowed later in scoped lanes
- root layer deletion remains a root timeline action

## 5. Phase Plan

### Phase 0 - Baseline Freeze And Guardrails

Goal:

Document and protect the current timeline and Live Scrub behavior before any
scope implementation.

Work:

- record current Live Scrub accepted baseline
- document forbidden files
- add review checklist for scope tasks
- define manual device validation matrix

Exit criteria:

- no runtime code changed
- plan exists and is accepted
- all implementers know that Live Scrub files are protected

### Phase 1 - Double Click Opens Scope Shell

Goal:

Double click / double tap on a supported text or image layer opens scoped mode.

Work:

- introduce `LayerScopeSession`
- route double tap on text/image clips to `enterLayerScope`
- preserve old text-edit behavior behind explicit edit action if needed
- capture return state
- render existing `TimelinePanel` in scoped mode
- add back button to return to root timeline

Allowed behavior:

- view scoped layer
- select scoped source row
- scrub within scoped local range
- return to root timeline

Not allowed yet:

- keyframe editing
- FX editing
- destructive edits
- video scope
- audio scope

Exit criteria:

- double tap text opens scope
- double tap image opens scope
- audio shows "coming later"
- video is disabled or behind future flag
- root timeline returns exactly as before
- Live Scrub still matches baseline

### Phase 2 - View/Select/Scrub-Only Projection

Goal:

Make scoped mode stable before authoring.

Work:

- map local playhead to global time
- clamp scrub to `0..layerDuration`
- preserve preview as full composition by default
- support `Solo Layer` as optional UI-only view state, not data mutation
- keep root preview source catalog unchanged

Exit criteria:

- scrub inside scope does not create a new scrub path
- root scrub still works after entering/exiting scope 10 times
- scroll/zoom state restores on exit
- selected layer remains selected on return

### Phase 3 - Scoped Toolbar Profile

Goal:

Replace root toolbar presentation with scoped toolbar profile.

Work:

- Back button
- local time readout
- Add Keyframe button disabled until Phase 5
- Prev/Next Keyframe disabled until Phase 5
- Animate button visible
- FX button visible
- unsupported actions show disabled state, not hidden behavior

Exit criteria:

- toolbar changes only in scope mode
- root toolbar is unchanged
- no action mutates timeline until its phase is implemented

### Phase 4 - Text Scope First Vertical Slice

Goal:

Text becomes the first fully supported professional scope type.

Work:

- show text source row
- show `Transform` group
- show `Opacity` lane
- show `Text Style` group placeholder
- consume the property contracts defined in
  `docs/professional_canvas_timeline.md`

First supported animation:

- Opacity

Reason:

- visually obvious
- low rendering risk
- safe for first keyframe authoring

Exit criteria:

- add opacity lane
- add two opacity keyframes
- preview changes opacity over time
- root timeline remains unchanged visually except text motion
- export path still receives deterministic motion data

### Phase 5 - Animate Bottom Sheet With Search

Goal:

Add professional animation selection without crowding the timeline.

Work:

- open `Animate` bottom sheet only inside scope
- search/autocomplete at top
- categories:
  - Transform
  - Opacity
  - Text
  - Entrance
  - Exit
  - Presets
- pressing plus adds a lane, not a clip

First items:

- Opacity
- Position
- Scale
- Rotation

Exit criteria:

- searching `opacity` finds Opacity
- plus inserts lane under source row
- duplicate lane prevention works
- no root timeline action changes

### Phase 6 - Keyframe Lane Authoring

Goal:

Add real keyframes inside scoped lanes.

Work:

- keyframe diamonds on lane
- add keyframe at current local time
- select keyframe
- delete keyframe
- drag keyframe in time
- snap to frame/project time grid
- previous/next keyframe navigation

Rules:

- keyframes store local time
- lanes clamp keys to `0..layerDuration`
- out-of-range keys after trim are preserved but inactive/hidden

Exit criteria:

- keyframes can be added/moved/deleted
- local/global time mapping remains correct
- undo/redo strategy is documented before broad rollout

### Phase 7 - Easing And Mobile Curve Editor

Goal:

Add professional timing control.

Start mobile-first:

- Linear
- Hold
- Ease In
- Ease Out
- Ease In-Out

Then add segment curve editor:

- select two keyframes
- edit curve segment
- copy/paste easing
- overshoot later

Later AE-style graph:

- value graph
- speed graph
- Bezier handles
- separate X/Y position channels

Exit criteria:

- easing is serialized deterministically
- preview and export evaluate the same curve
- curve changes do not affect Live Scrub path

### Phase 8 - FX Bottom Sheet And FX Stack

Goal:

Introduce layer-local FX as non-destructive stack.

Work:

- FX bottom sheet with search/autocomplete
- add FX stack item
- enable/disable FX
- reorder FX stack
- expand FX to parameter lanes
- parameter lanes can later receive keyframes

Initial FX candidates:

- Blur
- Brightness / Contrast
- Color Temperature
- Glow
- Shadow
- Mask Blur

Exit criteria:

- FX stack appears only inside scope
- FX changes preview without mutating root timeline structure
- disabled FX does not render
- export parity requirements are documented before shipping beyond preview

### Phase 9 - Image Scope

Goal:

Apply same scope architecture to image layers.

Work:

- image source row
- transform lanes
- opacity lane
- basic FX stack
- same keyframe/easing system

Exit criteria:

- text and image scope share architecture
- no special duplicate code path
- root timeline remains stable

### Phase 10 - Video Scope

Goal:

Enable video layers after text/image scope is stable.

Work:

- video source row
- transform lanes
- opacity lane
- crop/mask lanes
- FX stack
- speed/rate lanes later

Exit criteria:

- video scope does not alter decoder scrub ownership
- video scope does not create a new playback/preview path
- Live Scrub validates across root and scope

### Phase 11 - Graph Editor Upgrade

Goal:

Add advanced graph editing after the simple curve editor is stable.

Work:

- value graph
- speed graph
- property filtering
- show selected properties
- show animated properties
- snap graph keys to frames/current time
- Bezier direction handles

Exit criteria:

- graph editor edits same keyframes as lanes
- no duplicate curve storage
- export and preview use same interpolation model

### Phase 12 - Audio Scope Later

Goal:

Do not mix audio studio work with visual scope.

Audio scope is deferred to a separate plan.

Future audio scope may include:

- noise reduction
- reverb
- echo
- EQ
- volume automation
- waveform editing

Exit criteria before starting:

- visual scope is stable
- audio model is designed separately
- no attempt to force audio into visual scope model

## 6. Data Model Direction

Long-term model concepts:

```text
ScopeNode
LayerScopeSession
ScopedTimeMapping
AnimationTrack
EffectStack
EffectInstance
PropertyChannel
Keyframe
EasingSegment
PropertyPath
TimelineSpan
ScopeCommand
ScopeSnapshot
```

Important:

- keyframes belong to layer-local time
- effects belong to layer-local stack
- preview/export must evaluate the same serialized data
- presets must be inspectable, not black boxes
- broader canvas/timeline property ownership is defined in
  `docs/professional_canvas_timeline.md`

### 6.1 Layer Property Tree

Every scope exposes a collapsible property tree:

```text
Layer
  Transform
    Position
    Scale
    Rotation
    Anchor Point
  Opacity
  Type-specific controls
  Effects
  Presets
```

Every animatable row must have:

- stable `propertyPath`
- current value editor
- keyframe/stopwatch toggle
- add keyframe action
- reset action
- enable/visibility state where applicable

Examples:

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

These property paths must follow the durable canvas/timeline contract defined in
`docs/professional_canvas_timeline.md`.

### 6.2 Animated Property Track

The first real authoring model should be:

```text
AnimatedPropertyTrack
  id
  propertyPath
  valueKind
  defaultValue
  keyframes[]
```

Each keyframe must contain:

```text
Keyframe
  id
  propertyPath
  localTime
  value
  interpolation
  easing
  selected
```

MVP operations:

- add keyframe
- delete keyframe
- move keyframe
- copy/paste keyframe
- previous/next keyframe
- snap to playhead
- auto-key toggle

### 6.3 Scope Command Boundary

Scope edits must flow through explicit commands, not random UI mutations.

Initial command set:

```text
enterScope(layerId)
exitScope()
setProperty(propertyPath, value)
addKeyframe(propertyPath, localTime, value)
moveKeyframe(keyframeId, localTime)
deleteKeyframe(keyframeId)
addEffect(effectKind)
removeEffect(effectId)
reorderEffect(effectId, newIndex)
setEffectParameter(effectId, parameterPath, value)
applyPreset(presetId)
```

Every command should return or produce an authoritative snapshot:

```text
ScopeSnapshot
  scopeSession
  projectedTracks
  selectedPropertyPath
  selectedKeyframeIds
  effectStack
```

This prevents the scope UI from drifting away from the root editor state.

### 6.4 Effect Stack Contract

Each scope owns an ordered `EffectStack`.

Each effect instance has:

- stable id
- type/kind
- display name
- enabled state
- stack index
- parameter tracks
- reset defaults

Effect operations:

- enable/disable
- reorder
- duplicate
- delete
- reset
- expand/collapse
- animate parameters through the same keyframe model

### 6.5 Animation Presets

Animation presets are macro operations over properties/effects/keyframes.

Examples:

- Fade In
- Fade Out
- Pop In
- Slide Up
- Typewriter
- Glow Pulse
- Shake
- Blur In

Rules:

- presets are data, not hardcoded UI behavior
- presets must be previewable
- presets must be reversible through history
- applying a preset reveals the affected lanes/keyframes
- preset timing is relative to layer-local time

### 6.6 Autocomplete Search Contract

The `Animate` and `FX` bottom sheets should use a command-palette style search.

Search targets:

- properties
- effects
- presets
- actions

Examples:

```text
opacity
fade
scale
position
blur
glow
shake
typewriter
```

Results must be context-aware by layer type.

For example:

- text scope can show Typewriter
- image scope can show Blur/Scale/Opacity
- video scope can show Crop/Mask/Color/Opacity
- audio scope is not shown in this plan

## 7. Gesture Rules

Double click/tap must not fight existing gestures.

Rules:

- single tap selects
- double tap enters scope only when not scrubbing
- drag wins over double tap if movement threshold is crossed
- trim handles win over scope entry
- transition bridge taps remain transition actions
- background scrub remains scrub
- kinetic scroll blocks scope entry

If ambiguity exists:

Live Scrub and timeline manipulation win. Scope entry is cancelled.

## 8. Validation Matrix

Run after every phase:

- insert video
- insert text
- insert image
- live scrub root timeline
- select layer
- double tap layer
- enter scope
- scrub inside scope
- exit scope
- live scrub root timeline again
- trim root layer
- duplicate root layer
- delete root layer
- undo/redo if available
- export accepted simple project if phase touches render data

Mandatory Live Scrub checks:

- forward scrub
- backward scrub
- rapid back/forth scrub
- first clip scrub
- second clip scrub
- boundary scrub
- release frame stability
- no flicker
- no stale frame
- no decoder stall
- no surface detach

## 9. Stop Conditions

Stop immediately if any of these occurs:

- Live Scrub becomes slower
- Live Scrub stops showing during drag
- first scrub attempt fails
- second clip scrub regresses
- root timeline gestures conflict with scope entry
- `Stage5` files need modification
- `NativeTimelineScrubSurface` needs modification
- timeline is being rebuilt instead of projected
- keyframes require a data rewrite not covered by the phase

When a stop condition occurs:

1. stop implementation
2. document exact cause
3. show affected files
4. propose smallest safe path
5. wait for approval

## 10. Definition Of Done For First Release

The first scoped-layer release is complete only when:

- text layer double tap opens scope
- image layer double tap opens scope
- scoped timeline uses existing `TimelinePanel`
- Back returns to root timeline
- root timeline visual style is unchanged
- root Live Scrub quality is unchanged
- scoped time maps correctly to global time
- opacity animation lane works for text
- keyframes are local and deterministic
- root export/preview does not desync
- all validation matrix checks pass on device

## 11. Implementation Order Summary

1. Baseline and guardrails.
2. Double click opens scope shell.
3. View/select/scrub-only scope projection.
4. Scoped toolbar profile.
5. Text scope with opacity lane.
6. Animate bottom sheet with search.
7. Keyframe lane authoring.
8. Easing controls.
9. FX bottom sheet and stack.
10. Image scope.
11. Video scope.
12. Graph editor.
13. Audio studio in a separate future plan.

## 12. Final Rule

Professional Scope Timeline must make the existing timeline more powerful,
not replace it.

If a change weakens the current Live Scrub, the change is wrong for this plan.
