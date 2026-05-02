# Professional Normal Transitions Engine

Status: active implementation, foundation in progress.

Owner scope: normal timeline transitions only.

This document defines the professional architecture for non-AI transitions in
ReFusion. AI Transition generation is explicitly outside this plan. The target
is to build a stable foundation first, then add one preset at a time while also
testing imported scripts from external agents against the same internal graph.

## 1. Strict Rules

These rules are mandatory before any implementation begins.

1. Do not touch or regress the Stage 5 / Stage 5B Live Scrub path unless a
   separate approved transition-scrub task explicitly allows it.
2. Do not change clip structural truth to make transitions work. Clip start,
   trim, duration, and source handles remain canonical.
3. The transition overlap is a derived logical region, not a mutation of clip
   boundaries.
4. Normal transitions must be separated from AI Transition. No `aiGenerated`,
   `AiTransitionDraftData`, AI model state, or AI clip job state may be part of
   the normal transition catalog.
5. Presets and imported scripts must compile to the same internal graph. No
   parallel preset runtime and script runtime.
6. No executable script runtimes, eval, dynamic code execution, remote imports,
   or arbitrary shader source in user scripts.
7. Do not claim professional transition support from the current Flutter
   overlay/thumbnail preview. That is a temporary UI aid only.
8. Do not claim export parity while transition export remains blocked in the
   export composition layer.
9. Every transition edit must be undoable and redoable through the same command
   history used for professional timeline edits.
10. Every phase must pass real-device validation before the next preset is added.

## 2. Current Code Reality

The current app has partial transition UI and state, but no professional
transition engine yet.

Existing presentation state:

- `lib/features/editor/presentation/models/timeline_mock_models.dart`
  - `TimelineTransitionPreset`
  - `TimelineTransitionCurve`
  - `TimelineTrackTransitionData`
  - `TimelineTrackData.transitions`
  - `TimelineTrackData.transitionForBoundary(...)`

Existing UI:

- `lib/features/editor/presentation/widgets/transition_browser_bottom_sheet.dart`
  - `TransitionBrowserBottomSheet`
- `lib/features/editor/presentation/widgets/transition_inspector_bottom_sheet.dart`
  - `TransitionInspectorBottomSheet`
- `lib/features/editor/presentation/widgets/timeline_panel.dart`
  - boundary transition chrome and tap callback

Existing preview:

- `lib/features/editor/presentation/widgets/timeline_transition_preview_overlay.dart`
  - Flutter overlay preview only
  - uses simple opacity/scale logic and incoming thumbnails
  - not a dual-source compositor
  - not export parity

Existing Professional Motion foundations:

- `lib/features/editor/domain/models/professional_motion_fx_models.dart`
  - `MotionTransitionKind`
  - `MotionTransitionBindingModel`
- `lib/features/editor/domain/models/professional_motion_compilation_models.dart`
  - `MotionResolvedTransitionModel`
- `lib/features/editor/domain/models/professional_motion_evaluation_models.dart`
  - `MotionTransitionEvaluationState`

Existing export truth:

- `lib/features/editor/domain/models/export_composition_models.dart`
  - transition nodes are modeled as canonical operations
  - transition export parity is explicitly blocked
  - `unsupportedMotionTransition` remains a baseline blocker

Conclusion: the safe resume point is not UI polish. The safe resume point is
canonical normal transition modeling, overlap validation, command history, and
then a real dual-source compositor path.

## 3. Target Architecture

The final architecture is:

```text
TransitionDefinition / JSON DSL
        ↓
TransitionCatalog validation
        ↓
TransitionInstance
        ↓
PropertyChannels + Keyframes + Parameters
        ↓
TransitionWindow derived from clip boundary
        ↓
Shared Transition Evaluator
        ↓
Preview dual-source compositor
        ↓
Export compositor / Media3 integration path
```

There must be one semantic path. Presets, manual edits, and imported scripts all
produce the same `TransitionInstance` shape.

## 4. Domain Model Plan

### 4.1 TransitionNode

The timeline-level object. It represents a transition attached to the boundary
between two adjacent clips on one visual track.

Required fields:

- `id`
- `trackId`
- `leftClipId`
- `rightClipId`
- `definitionId`
- `duration`
- `alignment`
- `enabled`
- `schemaVersion`
- `parameterValues`
- `instanceId`

Derived fields, never stored as primary truth:

- `boundaryTime`
- `overlapStart`
- `overlapEnd`
- `progressAt(time)`
- `leftSourceSampleTime`
- `rightSourceSampleTime`

### 4.2 TransitionDefinition

Catalog definition for a preset or script template.

Required fields:

- `definitionId`
- `schemaVersion`
- `label`
- `category`
- `rendererTier`
- `defaultDurationMs`
- `minDurationMs`
- `maxDurationMs`
- `parameterSchema`
- `capabilities`
- `handlePolicy`
- `previewSupport`
- `exportSupport`
- `fallbackPolicy`
- `integrityHash`

Renderer tiers:

- `primitive`
- `glsl`
- `multiPassDeferred`

### 4.3 TransitionInstance

Resolved editable instance created from a preset or imported script.

Required fields:

- `id`
- `nodeId`
- `definitionId`
- `sourceKind`
- `sourceHash`
- `parameterValues`
- `propertyChannels`
- `effects`
- `easingCurves`
- `editState`

Allowed `sourceKind` values:

- `builtInPreset`
- `importedScript`
- `manual`
- `detachedManual`

### 4.4 TransitionCatalog

The official registry for normal transitions.

Responsibilities:

- load built-in preset JSON definitions
- validate schema version
- validate parameter schema
- validate required capabilities
- reject unknown renderer tiers
- reject unsafe script features
- expose category lists to UI
- provide integrity hash diagnostics

Categories:

- `Basic`
- `Motion`
- `Blur`
- `Wipe`
- `Light`
- `Distort`
- `Custom`

## 5. Overlap Contract

The overlap is a logical playback/render window around the boundary between two
clips. It must not alter clip structure.

Rules:

1. `boundaryTime = leftClip.start + leftClip.duration`
2. `overlapStart = boundaryTime - leadingDuration`
3. `overlapEnd = boundaryTime + trailingDuration`
4. `duration = overlapEnd - overlapStart`
5. `minOverlap = 100ms`
6. `maxOverlap = min(leftAvailableTail, rightAvailableHead, 5000ms)`
7. If handles are insufficient, the app must clamp, reject, or show a clear
   diagnostic. It must not silently extend media or alter clip boundaries.
8. End semantics must be deterministic and preferably end-exclusive:
   `[overlapStart, overlapEnd)`.

The first baseline may use symmetric overlap. Later versions can support:

- outgoing-heavy
- incoming-heavy
- cut-centered
- handle-aware manual alignment

## 6. Script DSL Plan

Scripts are declarative data, not executable code.

Supported input:

- pasted JSON
- uploaded `.json`

Not supported:

- executable JavaScript
- executable UI component code
- expressions requiring runtime eval
- remote imports
- arbitrary GLSL pasted by a user

### 6.1 Script Shape

External agents should target this shape:

```json
{
  "kind": "refusion.transition",
  "schemaVersion": "1.0.0",
  "id": "smooth-cross-dissolve",
  "name": "Smooth Cross Dissolve",
  "rendererType": "primitive",
  "defaultDurationMs": 2000,
  "requires": ["dual-texture", "opacity", "timeline-overlap"],
  "parameters": [
    {
      "name": "softness",
      "type": "number",
      "default": 0.5,
      "range": [0.0, 1.0],
      "ui": "slider"
    }
  ],
  "channels": [
    {
      "target": "from",
      "property": "opacity",
      "keyframes": [
        { "t": 0.0, "value": 1.0, "easing": "linear" },
        { "t": 1.0, "value": 0.0, "easing": "linear" }
      ]
    },
    {
      "target": "to",
      "property": "opacity",
      "keyframes": [
        { "t": 0.0, "value": 0.0, "easing": "linear" },
        { "t": 1.0, "value": 1.0, "easing": "linear" }
      ]
    }
  ]
}
```

Important: external scripts must use semantic targets such as `from`, `to`, and
`transition`, not app clip IDs. The app applies the script to the currently
selected boundary and resolves real clip IDs internally.

### 6.2 Validation Pipeline

Import must run through:

1. parse
2. schema validation
3. semantic validation
4. capability validation
5. budget validation
6. normalization
7. dry-run compilation
8. diagnostics report
9. creation of editable `TransitionInstance`

Validation must reject:

- unknown schema versions without migration support
- unknown targets
- unknown properties
- out-of-range keyframe times
- keyframe values outside property schema
- unsupported renderer tiers
- missing required capabilities
- too many keyframes/effects for the device budget

### 6.3 Agent Contract

A separate agent-facing guide should be created after Phase 1. It must tell
external agents:

- produce JSON only
- do not include clip IDs
- use `from` and `to`
- keep keyframe times normalized from `0.0` to `1.0`
- declare required capabilities
- declare parameters with UI metadata
- prefer built-in primitives before GLSL
- never write executable code; output declarative transition JSON only

## 7. Renderer Strategy

### Tier 1: Primitive Compositor

First implementation target.

Supported transition families:

- cross dissolve
- dip to black
- slide
- push
- scale / zoom

Implementation idea:

- GPU composition
- two textures
- opacity
- transform
- crop/fit rules
- no custom user shader

### Tier 2: Registered GLSL Shaders

Only after Tier 1 preview/export parity is stable.

Supported transition families:

- blur dissolve
- luma wipe
- displacement
- RGB split
- glitch
- light leak

Rules:

- GLSL assets must be app-owned and registered by `shaderId`.
- User scripts may reference `shaderId`, but may not provide arbitrary shader
  source.
- Each shader must have a uniform schema and fallback.
- Each shader must pass preview/export parity tests.

Asset target:

```text
assets/transitions/shaders/
assets/transitions/presets/
assets/transitions/thumbnails/
```

### Tier 3: Deferred Multi-Pass

Not part of first baseline.

Examples:

- particles
- fluids
- simulation-driven transitions
- heavy multi-pass distortions

These require separate performance and export investigation.

## 8. Preview And Export Parity

Professional transition support is not complete until preview and export share
the same semantic evaluator.

Preview path:

- dual-source compositor
- `textureA`
- `textureB`
- raw progress
- eased progress
- shared parameter evaluation
- real video frames, not thumbnail-only transition output

Export path:

- same transition graph
- same evaluator
- same parameter mapping
- compatible compositor path for encoded frames
- audio crossfade handled as a separate explicit export operation

Media3 remains useful for the export backbone, decoding/encoding integration,
and supported effects. It must not be treated as a complete transition engine
for true two-source crossfades by itself.

## 9. UI Plan

UI should be layered from safe to advanced.

### 9.1 Picker

Transition picker bottom sheet:

- categories
- search
- built-in presets
- custom imported scripts
- capability badges
- unsupported states

The AI card must be removed from the normal transition picker path or moved to a
separate AI-only entry point.

### 9.2 Timeline Chrome

Timeline boundary marker:

- visible transition token between adjacent clips
- selected / inactive state
- duration handle later
- no structural clip mutation

### 9.3 Inspector

Quick parameters:

- duration
- alignment
- top preset parameters
- curve/easing
- delete
- open manual scope later

### 9.4 Script Import

Import paths:

- paste JSON
- upload JSON

On success:

- show parsed name
- show validation summary
- create editable transition
- expose generated channels/keyframes

On failure:

- show exact error list
- no partial state mutation

### 9.5 Manual Transition Scope Timeline

This is not the first baseline renderer task.

It should arrive after:

- canonical transition model
- script import
- first primitive transition
- command history
- preview parity baseline

The scope timeline should expose:

- `from` clip lanes
- `to` clip lanes
- transition parameter lanes
- keyframes
- curve editing
- script source/metadata

## 10. Command History Requirements

All transition changes must be commands:

- add transition
- remove transition
- change duration
- change alignment
- change preset parameter
- import script
- detach script to manual
- edit keyframe
- move keyframe
- change easing

No direct state mutation path should become the final implementation.

## 11. Phased Implementation Plan

Current checkpoint:

- Phase 0 complete: audit and protection rules are documented.
- Phase 1 complete: canonical normal transition domain models exist.
- Phase 2 partially complete: overlap and handle validation exists at the
  authoring-service level for the first preset.
- Phase 3 complete for the normal-transition state container: add/update/remove
  are undoable and redoable in the dedicated command history service.
- Phase 4 partially complete: built-in JSON definitions and external JSON
  validation/import exist for the first preset family.
- Phase 5 in progress: `cross_dissolve` is now exposed through the current
  transition picker and routed through the normal transition authoring adapter.
- Phase 6 is not complete: current visual feedback is still the temporary
  Flutter overlay, not the final dual-source compositor.
- Phase 7 is not started: export parity remains blocked until the compositor
  path is built.

### Phase 0: Baseline Freeze And Audit

Goal:

- confirm current transition state
- document existing UI/model/export blockers
- record Live Scrub and Stage 6 protection rules

Exit criteria:

- audit accepted
- current git checkpoint exists
- no code changes to transition runtime

### Phase 1: Canonical Normal Transition Domain

Goal:

- create normal transition domain models independent from AI/mock
- define `TransitionDefinition`, `TransitionNode`, `TransitionInstance`,
  `TransitionCatalog`

No UI renderer yet.

Exit criteria:

- unit tests for construction and serialization
- AI fields absent from normal transition domain
- no Stage5 changes

### Phase 2: Overlap And Handle Validation

Goal:

- implement derived overlap contract
- validate handles
- add diagnostics for insufficient overlap

Exit criteria:

- clip boundaries remain unchanged
- min/max overlap tests pass
- precision tests pass
- no Live Scrub regression outside transition windows

### Phase 3: Command History Integration

Goal:

- make transition add/remove/update undoable
- route transition state changes through commands

Exit criteria:

- undo/redo works for add/remove/duration/parameter edit
- no direct final state mutation path for transition edits

### Phase 4: Catalog And DSL Import Foundation

Goal:

- load built-in preset JSON definitions
- import external JSON scripts
- validate and dry-run compile into `TransitionInstance`

Exit criteria:

- valid script imports
- invalid script reports precise diagnostics
- script does not need clip IDs
- preset and script compile to the same internal graph

### Phase 5: UI Binding Without Production Renderer

Goal:

- connect picker/inspector to canonical normal transitions
- remove AI from normal transition flow
- show imported custom scripts in `Custom`

Exit criteria:

- no export claim
- no professional preview claim
- existing overlay can remain clearly temporary

### Phase 6: First Primitive Renderer - Cross Dissolve

Goal:

- build first real two-source primitive transition
- target: `cross_dissolve`

Exit criteria:

- preview reads outgoing and incoming frames
- duration/overlap correct
- external cross dissolve script compiles and renders
- real-device validation passes
- no Live Scrub quality regression outside transition windows

Current implementation note:

- the first Cross Dissolve frame planner exists in the professional video
  compositor domain. It computes deterministic A/B opacity and source-time
  samples from the generic render plan, and detects missing source coverage so
  a real renderer cannot silently fall back to frozen frames. Preview/export
  connection remains open.

### Phase 7: Export Parity For Cross Dissolve

Goal:

- export `cross_dissolve` through the shared transition graph

Exit criteria:

- transition export no longer blocked for cross dissolve
- preview/export parity probe passes
- audio crossfade behavior is explicit
- unsupported transitions still block honestly

### Phase 8: Preset-By-Preset Rollout

Add only one transition family at a time.

Order:

1. `dip_to_black`
2. `push_left/right/up/down`
3. `slide_left/right/up/down`
4. `zoom_in_camera`
5. `blur_dissolve`
6. `luma_wipe`
7. `light_leak`
8. `rgb_split`
9. `glitch`

Each preset must pass:

- built-in preset test
- imported script test
- UI parameter test
- preview test
- export parity test when export support is claimed
- real-device validation

### Phase 9: Manual Transition Scope Timeline

Goal:

- expose editable lanes/keyframes for selected transition
- allow script-generated graph to become manually editable

Exit criteria:

- keyframes are stable by ID
- duration retiming scales normalized keyframes
- manual edits remain undoable
- exported result matches preview

### Phase 10: Tier 2 Shader Pack

Goal:

- introduce registered GLSL transitions only after Tier 1 is stable

Exit criteria:

- shader registry exists
- uniform schema exists
- capability gating exists
- preview/export parity exists for each shader preset

## 12. Preset Acceptance Gate

No preset is accepted just because it looks good once.

For every preset:

1. It must exist as a `TransitionDefinition`.
2. It must have a JSON DSL representation.
3. It must compile to `TransitionInstance`.
4. It must expose editable parameters.
5. It must support undo/redo.
6. It must have deterministic overlap behavior.
7. It must run on a real device.
8. If export is claimed, preview/export parity must pass.
9. If unsupported on a device, it must fail with a clear capability message.

## 13. External Agent Script Testing

For each preset family, test at least three external scripts:

1. minimal script
2. parameter-heavy script
3. agent-generated creative script

The app should accept only scripts that match the official DSL. External agents
should not invent API names. If they do, validation must reject the script with
actionable errors.

## 14. What Not To Build First

Do not start with:

- glitch shader
- blur dissolve shader
- manual scope timeline
- heavy transition pack
- AI transition integration
- export parity for every transition
- arbitrary executable-code import

Start with:

1. model
2. overlap
3. command history
4. DSL validation
5. cross dissolve
6. export parity for cross dissolve

## 15. Final Definition Of Done

The normal transitions system is professional only when:

- normal transitions are independent from AI transitions
- presets and scripts share one graph
- scripts are validated JSON only
- transitions do not mutate clip boundaries
- Stage5 Live Scrub baseline remains protected
- Stage6 precision baseline remains protected
- first primitive transition previews from real dual video sources
- export path uses the same transition graph
- unsupported transitions block honestly
- every accepted preset passes real-device validation

## 16. Current Slice: Transition Preview Safety

The previous `Distortion Zoom Transition In V1` experiment is removed from the
preset browser. Device logs showed repeated codec start/stop/release churn
because that version extracted source frames and composed bitmaps per render
request. That is not acceptable for playback or Live Scrub.

The attempted Flutter-side `Zoom In Camera` surface transform is also removed
from the preset browser. Android native preview is a PlatformView, and applying
Flutter transforms or blur to that surface can leak the preview into the
timeline overlay and break native timeline scrub hit-testing. Zoom-family
transitions must return only through a native compositor surface that owns its
own clipping, transform, and output ordering.

Contracts added:

- The transition no longer invokes native per-frame source extraction.
- Playback and Live Scrub remain on the normal video preview path.
- `Zoom In Camera` and `Distortion Zoom Transition In V1` remain hidden until
  the native compositor path can transform video without PlatformView leakage
  or codec churn.
- Thumbnail zooms, poster frames, decorative speed lines, Gaussian-only blur,
  Flutter overlays, timeline-area drawing, and transformed single-surface
  previews made from still images remain rejected.

Verification expectation:

- adding the preset must not break normal playback or Live Scrub outside the
  transition window;
- the outgoing side must use the playing tail of video A;
- the incoming side must use the playing head of video B;
- the incoming zoom-settle phase must not expose black canvas borders;
- unsupported source coverage must fail closed rather than freeze a boundary
  frame.

Interactive preview ownership:

- while a professional native transition render plan is active, the normal
  single-video preview surface is suppressed so the transition surface is the
  authoritative canvas for A/B sampling;
- transient interactive surface registration or presentation failures are
  retried with diagnostics;
- permanent source pixel blockers remain hard blockers and must not fall back
  to Flutter overlays, thumbnails, or poster frames.

ANR safety gate:

- the current `Distortion Zoom Transition In V1` renderer performs exact source
  frame extraction and bitmap composition per render request, so it is allowed
  only for stationary preview frames;
- playback and Live Scrub must not invoke this renderer until a cached,
  nonblocking native decoder/frame pipeline is implemented;
- if a mode cannot be rendered without blocking play or timeline auto-scroll,
  the transition must fail closed for that mode rather than retrying repeatedly.
