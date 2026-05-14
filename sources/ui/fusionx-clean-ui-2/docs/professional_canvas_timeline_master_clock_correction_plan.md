# Professional Canvas Timeline Master Clock Correction Plan

Short name: `PCTMC`

Status: isolated corrective architecture and execution plan

Package: `com.refusion.app`

Date: 2026-05-14

Primary purpose: correct the structural split between ReFusion canvas editing,
timeline editing, master clock evaluation, keyframe authoring, MCP apply, and
preview/export proof before adding broader creative libraries or more effects.

This plan is intentionally isolated. It does not replace:

- `docs/professional_unified_creative_truth_apply_spine_plan.md`
- `docs/professional_native_creative_library_engine_plan.md`
- `docs/professional_canvas_timeline.md`
- `docs/professional_refusion_motion_keyframe_engine.md`
- `docs/PNCLE-05C.UNIVERSAL-LAYER-UPDATE-IDENTITY-HARDENING.md`

Instead, it provides the missing correction layer that makes those plans
operationally safe:

```text
Canvas
Timeline
MCP
Script
Templates
        |
        v
one command boundary
        |
        v
one layer/element identity model
        |
        v
one property graph
        |
        v
one master clock / frame evaluator
        |
        v
one preview/export proof contract
```

No feature may claim professional canvas/timeline behavior while bypassing this
correction path.

---

## 0. Why This Plan Exists

Recent MCP/device failures show a deeper architecture problem:

- A user-selected Story/Reels composition can receive a square background.
- A text edit plus animation can create a duplicate text layer instead of
  updating the existing one.
- Motion/effects can target the wrong layer when identity is unresolved.
- Effects can appear late because apply waits for cloud sync/diagnostics rather
  than a direct local apply path.
- Proof can be accepted from data/metadata before visual rendering is proven.

These failures are symptoms of one structural issue:

```text
ReFusion has strong pieces, but they are not yet forced through one shared
canvas + timeline + clock + keyframe + renderer contract.
```

The correction goal is not to make ReFusion an HTML engine.

The correction goal is:

```text
Keep ReFusion native.
Adopt the professional contracts seen in OpenCut, HyperFrames, and Remotion.
Make every visual/editable thing deterministic, targetable, seekable, and
provable.
```

---

## 1. Reference Review Inputs

Every implementation slice under this plan must include a pre-build report that
explicitly references these systems.

### 1.1 Current ReFusion Inputs

Required files to read before any slice:

- `docs/professional_canvas_timeline.md`
- `docs/professional_refusion_motion_keyframe_engine.md`
- `docs/professional_unified_creative_truth_apply_spine_plan.md`
- `docs/professional_checkpoint_policy.md`
- `lib/features/editor/domain/models/professional_motion_models.dart`
- `lib/features/editor/domain/models/professional_motion_animation_models.dart`
- `lib/features/editor/domain/services/timeline_clock_coordinator.dart`
- `lib/features/editor/domain/services/master_keyframe_value_evaluator.dart`
- `lib/features/editor/presentation/services/master_frame_evaluation_read_adapter.dart`
- `lib/features/editor/presentation/models/timeline_mock_models.dart`
- `lib/features/editor/presentation/widgets/preview_stage.dart`
- `lib/features/editor/presentation/widgets/unified_canvas_transform_overlay.dart`
- `lib/features/editor/presentation/screens/fusionx_clean_ui_screen.dart`

### 1.2 OpenCut Inputs

Local reference path:

```text
research/hyperframe_and_remotion/repos/opencut
```

Required OpenCut files:

- `apps/web/src/timeline/types.ts`
- `apps/web/src/animation/types.ts`
- `apps/web/src/animation/resolve.ts`
- `apps/web/src/timeline/update-pipeline.ts`
- `apps/web/src/core/managers/timeline-manager.ts`
- `apps/web/src/commands/timeline/element/update-elements.ts`
- `apps/web/src/preview/controllers/preview-interaction-controller.ts`
- `apps/web/src/preview/controllers/transform-handle-controller.ts`
- `apps/web/src/services/renderer/canvas-renderer.ts`
- `docs/keyframes.md`
- `docs/effects-renderer.md`

OpenCut lessons to adopt:

- canvas interaction writes preview overlays first, then commits through
  command/history;
- timeline elements carry stable identity, timing, params, effects, and
  animations;
- keyframes are local to element time;
- update pipelines enforce derived rules such as duration/keyframe clamping;
- renderer consumes resolved values rather than UI-only metadata;
- effects are definitions with params and render passes, not loose payloads.

### 1.3 HyperFrames Inputs

Local reference path:

```text
research/hyperframe_and_remotion/repos/hyperframes
```

Required HyperFrames files:

- `AGENTS.md`
- `DOCS_GUIDELINES.md`
- `skills/gsap/SKILL.md`

HyperFrames lessons to adopt:

- composition timing must be explicit;
- animation timelines must be paused and seek-driven;
- render-critical motion must not depend on timers, async event handlers, or
  uncontrolled playback;
- every animation target must have stable identity;
- layout should be inspectable before motion is layered on top.

### 1.4 Remotion Inputs

Local reference path:

```text
research/hyperframe_and_remotion/repos/remotion
```

Required Remotion files:

- `packages/core/src/Composition.tsx`
- `packages/core/src/CompositionManager.tsx`
- `packages/core/src/use-current-frame.ts`
- `packages/core/src/use-video-config.ts`
- `packages/core/src/ResolveCompositionConfig.tsx`

Remotion lessons to adopt:

- composition metadata must be explicit and validated:
  width, height, fps, duration, id;
- frame time is deterministic;
- sequence/local-time projection is explicit;
- updates are identity/props driven, not random re-insertion;
- preview and render read the same composition truth.

---

## 2. Non-Negotiable Product Contract

### 2.1 One Canvas/Timeline Truth

Canvas and timeline are not separate systems.

They are two editors over the same authored data.

Required product behavior:

```text
Move on canvas
-> writes same property path the timeline lane shows

Edit lane in timeline
-> updates same value the canvas renders

Scrub/play/export
-> evaluates same serialized property graph
```

Forbidden behavior:

```text
canvas-only transform
timeline-only keyframe
MCP-only layer mutation
preview-only effect
export-only renderer path
metadata-only proof
```

### 2.2 Composition Spec Is Authoritative

The active composition spec is a hard contract:

```text
compositionId
width
height
aspectRatio
fps
duration
safe zones
origin
timeline id
current playhead
revision
```

No MCP command, manual UI command, script import, or template may infer its own
canvas size when an active composition exists.

If the user selects Story/Reels, a background must fill the active Story/Reels
canvas. A square payload must be canonicalized or blocked.

### 2.3 Stable Universal Identity

Every editable/renderable object must have a canonical address:

```text
projectId
compositionId
sceneId
trackId
layerId
elementId
sourceId
effectInstanceId when applicable
propertyPath when applicable
```

This address must be used by:

- canvas selection;
- timeline selection;
- MCP target resolution;
- script/template imports;
- keyframe channels;
- effect stacks;
- renderer proof;
- undo/redo commands.

### 2.4 Command Boundary

Every mutation must enter a command boundary.

Required command families:

```text
insertLayer
updateLayer
deleteLayer
setProperty
addKeyframe
moveKeyframe
setKeyframeValue
deleteKeyframe
applyEffect
updateEffectParam
removeEffect
reorderEffect
setCompositionSpec
previewTransactionBegin
previewTransactionUpdate
previewTransactionCommit
previewTransactionDiscard
```

The same command family must support:

- Manual UI;
- MCP;
- Script;
- Templates;
- future tools.

### 2.5 Preview Transaction Before Commit

Canvas gestures must not directly mutate final graph state on every pointer
move.

Required behavior:

```text
pointer down
-> begin preview transaction

pointer move
-> update preview overlay/evaluated draft

pointer cancel
-> discard preview transaction

pointer up
-> commit through command/history
```

This adopts the OpenCut pattern while staying native.

### 2.6 Master Clock Owns Evaluation Time

No rendering path may invent time.

Required time model:

```text
rootTime
sceneLocalTime
layerLocalTime
elementLocalTime
transitionLocalTime
frameIndex
fps
phase
authority
revision
```

All evaluation must consume a `TimelineClockSnapshot` or an equivalent master
clock snapshot.

### 2.7 Property Graph Owns Animation

Every animatable property must be represented as a channel:

```text
MotionPropertyChannel
  channelId
  targetAddress
  propertyDefinition
  baseValue
  activeRange
  keyframes[]
  interpolation/easing
```

Required initial property paths:

```text
transform.position.x
transform.position.y
transform.scale.x
transform.scale.y
transform.rotation
opacity
visual.width
visual.height
shape.cornerRadius
shape.fillColor
shape.strokeColor
shape.strokeWidth
text.content
text.fontSize
text.fillColor
text.align
effects.blur.amount
effects.glow.intensity
effects.shadow.distance
effects.shadow.opacity
```

### 2.8 Renderer Proof Is Required

No operation may claim success from DB write, row existence, timeline revision,
or metadata alone.

Required proof chain:

```text
command accepted
target resolved
graph mutated
timeline projected
frame evaluated
preview renderer drew expected visual state
export renderer conformance declared
ack includes renderer proof
```

For background/solid:

```text
visualBounds == canvasBounds
coverage >= 0.99
compositionSpec matches active user choice
```

For update:

```text
layerCountAfter == layerCountBefore
canonicalTargetId unchanged
changedProperties contain requested properties
```

For motion/effect:

```text
channel/effect instance attached to same target
frame evaluation changes expected property over time
preview/export renderer conformance exists
```

---

## 3. Current ReFusion Assessment

### 3.1 Strong Foundations Already Present

ReFusion already has meaningful infrastructure:

- `MotionProjectFormat` and `MotionFrameRate`;
- `MotionPropertyDefinition`, `MotionPropertyTarget`,
  `MotionPropertyValue`;
- `MotionPropertyChannelModel` and `MotionKeyframeModel`;
- `UnifiedKeyframeOperations`;
- `TimelineClockCoordinator`;
- `MasterKeyframeValueEvaluator`;
- `MasterFrameEvaluationReadAdapter`;
- `MotionShapePreviewOverlay`, `MotionImagePreviewOverlay`,
  `MotionTextPreviewOverlay`;
- `UnifiedCanvasTransformOverlay`;
- MCP universal identity/planner infrastructure.

This plan must not discard those systems.

It must converge them.

### 3.2 Critical Gaps

#### Gap A - Timeline Data Is Not Yet Full Creative Truth

`TimelineClipData` is still closer to a presentation/timeline clip model than a
complete professional editable element model.

It does not fully own:

- params;
- all property channels;
- effect stacks;
- renderer binding;
- full layer/element identity;
- command/history state.

Correction:

```text
Timeline rows must become projections of canonical layer/element graph data,
not a parallel source of creative state.
```

#### Gap B - Canvas Mutations Still Bypass One Command Path

Canvas handlers can update motion project state, property channels, or fallback
clip transforms through different branches.

Correction:

```text
Canvas tools must only emit preview transactions and final commands.
```

#### Gap C - MCP Apply Is Not Yet Same As Manual Apply

MCP remote layers are dispatched per kind and can still lower through special
paths.

Correction:

```text
MCP must lower into the same command and property graph path as Manual UI.
```

#### Gap D - Composition Spec Is Not Yet Enforced Everywhere

Active canvas size can be lost between user composition choice, cloud context,
MCP payload, and local apply.

Correction:

```text
Composition spec must be included in active context, command validation,
canonicalization, frame evaluation, and proof.
```

#### Gap E - Keyframes Exist But Are Not Universally Projected

Keyframe models and operations exist, but the timeline, scoped timeline, canvas,
MCP, and effects are not all forced to author/evaluate the same channels.

Correction:

```text
All direct animation and effect parameter animation must use the same channel
model and evaluator.
```

#### Gap F - Proof Is Not Yet Visual/Renderer-Strict

Some proof paths can still infer success from represented data.

Correction:

```text
Proof must be renderer-backed and target-specific.
```

#### Gap G - Apply Latency Still Depends On Polling/Diagnostics

MCP live apply can wait on cloud polling and diagnostic reads.

Correction:

```text
Fast apply must fetch only pending commands and affected targets first.
Diagnostics must be asynchronous and non-blocking.
```

---

## 4. Target Architecture

### 4.1 Corrected Native Spine

```text
Authoring Source
  - Manual canvas
  - Manual timeline
  - MCP
  - Script
  - Template
        |
        v
ProfessionalSceneCommand
        |
        v
Command Transaction Boundary
        |
        v
Universal Target Resolver
        |
        v
Canonical Layer/Element Graph
        |
        v
Property Channel Store
        |
        v
Timeline Projection
        |
        v
Master Clock / Time Projection
        |
        v
Master Frame Evaluator
        |
        v
Preview Renderer + Export Renderer
        |
        v
Renderer Proof / Ack
```

### 4.2 Canonical Layer Element Contract

Every visible object must be representable by:

```text
CreativeLayerElement
  projectId
  compositionId
  sceneId
  trackId
  layerId
  elementId
  kind
  role
  zIndex
  timelineSpan
  sourceSpan
  sourceBinding
  staticParams
  propertyChannels
  effectStack
  rendererBinding
  supportedEntrySurfaces
  proofState
```

This does not require replacing all current models in one pass.

Initial implementation may be a facade/projection over current models.

### 4.3 Canvas Tool Contract

Canvas tool responsibilities:

```text
hit test
select canonical target
show handles
preview transform
commit command
```

Canvas tool must not own:

```text
final animation state
timeline state
renderer success
MCP-specific identity
export-only state
```

### 4.4 Timeline Contract

Timeline responsibilities:

```text
show tracks/clips projected from graph
show property lanes projected from channels
edit time spans
edit keyframes
show effect stack lanes
scrub using master clock
```

Timeline must not own:

```text
separate animation values
separate keyframe model
separate effect metadata
```

### 4.5 Master Clock Contract

All preview and renderer requests must carry:

```text
TimelineClockSnapshot
RenderMode
FrameRate
CompositionSpec
TargetScope
Revision
```

No preview renderer or MCP proof evaluator may use stale `_currentTime` when a
master clock snapshot is available.

### 4.6 Effect Stack Contract

Effects are ordered, non-destructive layer-local instances:

```text
EffectInstance
  effectInstanceId
  targetElementId
  effectType
  enabled
  order
  params
  paramChannels
  rendererConformance
```

Initial effect definitions:

```text
gaussianBlur
motionBlur
glow
shadow
noise/grain
colorOverlay
```

No effect may be considered applied if it only exists in metadata.

---

## 5. Isolation Rules

This plan is corrective and isolated.

Allowed:

- domain models;
- facades/adapters;
- validation contracts;
- read-only inventory;
- projection layers;
- targeted tests;
- feature-flagged wiring;
- proof contracts;
- instrumentation.

Forbidden without explicit user approval:

- replacing `TimelinePanel`;
- rebuilding Live Scrub;
- changing Stage5 protected files;
- adding a second render engine;
- embedding Remotion/HyperFrames as editable runtime;
- shipping MCP-only capabilities;
- shipping UI-only capabilities;
- claiming success from metadata-only writes;
- inserting a new layer for unresolved update intent.

Protected boundary:

```text
Live Scrub remains protected.
Any required change to Stage5/native scrub must stop and request explicit
approval with file list, reason, risk, and rollback.
```

---

## 6. Execution Phases

### PCTMC-00 - Pre-Build Evaluation And Baseline Map

Goal:

Create a precise baseline of current canvas/timeline/clock/keyframe/render
paths before any code mutation.

Required output:

- current ReFusion path map;
- OpenCut comparison notes;
- HyperFrames deterministic timing notes;
- Remotion composition/frame notes;
- current gaps table;
- strict keep/wrap/upgrade/add/replace/block decision table.

Acceptance:

- no code changed;
- every current writer to canvas transform, timeline clip, keyframe, effect,
  MCP apply, and frame evaluation is inventoried;
- protected Live Scrub touch count is zero.

### PCTMC-01 - Composition Spec Authority

Goal:

Make active composition spec authoritative for Manual UI, MCP, preview, and
proof.

Build:

- `ProfessionalCompositionSpec` read model/facade;
- active canvas spec validator;
- MCP active context composition spec payload;
- background/full-canvas canonicalization contract;
- proof expectation for canvas bounds.

Acceptance:

- Story/Reels selection cannot produce square background unless explicitly
  creating a square shape;
- solid/background command canonicalizes to active canvas bounds;
- MCP context exposes width, height, fps, duration, aspect ratio;
- tests prove square payload in Story is corrected or blocked.

### PCTMC-02 - Canonical Layer Element Identity Facade

Goal:

Expose one read-only canonical identity view over current layers, timeline
clips, motion elements, media, text, shapes, and MCP ids.

Build:

- `CanonicalCreativeTargetAddress`;
- `CreativeLayerElementView`;
- identity resolver from:
  - motion project;
  - timeline tracks;
  - MCP remote ids;
  - selected clip;
  - canvas node;
- ambiguity/blocker diagnostics.

Acceptance:

- every visible text/shape/image/video/background has one canonical address;
- ambiguous targets block update intent;
- fallback to selected/single visual target is disabled for MCP mutation unless
  explicitly allowed by a safe rule.

### PCTMC-03 - Canvas Preview Transaction Layer

Goal:

Make canvas gestures transactional instead of direct final mutation paths.

Build:

- preview transaction model;
- begin/update/commit/discard API;
- bridge from current canvas handlers into transaction API;
- command commit wrapper;
- no behavior change outside the feature flag.

Acceptance:

- move/scale/rotation preview is immediate;
- cancel discards preview;
- pointer up commits once;
- commit produces a reversible command record;
- no direct MCP side effect is introduced.

### PCTMC-04 - Unified Property Path Catalog

Goal:

Create one official catalog for transform, visual, text, shape, and effect
properties.

Build:

- property path registry;
- supported target kinds;
- value kinds;
- default values;
- renderer conformance declaration;
- manual UI/MCP/script support declarations.

Acceptance:

- no property lane exists without registry entry;
- no MCP mutation can target an unknown property path;
- initial property set covers position, scale, rotation, opacity, size,
  corner radius, text color/size, blur amount.

### PCTMC-05 - Property Channel Store Convergence

Goal:

Make static values and keyframed values use one channel access path.

Build:

- channel lookup by canonical target + property path;
- static/base value update path;
- auto-key explicit policy;
- existing channel reuse;
- keyframe collision policy.

Acceptance:

- editing canvas value and editing timeline lane update same channel or base
  value;
- no duplicate channel for same target/property;
- keyframe at same time updates existing keyframe unless policy rejects;
- tests cover trim/local-time behavior.

### PCTMC-06 - Timeline Lane Projection From Channels

Goal:

Timeline lanes become projections of property channels, not a second truth.

Build:

- lane projection adapter;
- lane identity -> channel identity mapping;
- local-time projection;
- editable lane metadata;
- read-only compatibility adapter for legacy lanes.

Acceptance:

- timeline lane value equals evaluated channel value;
- moving a keyframe changes channel data;
- deleting a lane keyframe deletes channel keyframe;
- legacy lane data is either migrated or marked adapter-only.

### PCTMC-07 - Master Frame Evaluator Mandate

Goal:

All preview/playback/scrub/export-facing evaluated values come from master
clock + frame evaluator.

Build:

- evaluator input contract;
- required clock snapshot adapter;
- frame index computation from fps;
- scene/layer/element local-time projection;
- diagnostics for missing/stale time.

Acceptance:

- preview and timeline inspect the same evaluated value at the same time;
- scrub/playback cannot evaluate from stale `_currentTime`;
- tests compare root time vs layer local time vs element local time.

### PCTMC-08 - Manual UI And MCP Command Convergence

Goal:

Manual UI and MCP emit the same command family.

Build:

- command lowering map:
  - manual canvas move -> `setProperty`;
  - manual timeline keyframe -> `addKeyframe`;
  - MCP text update -> `updateLayer/setProperty`;
  - MCP background -> `insertLayer/updateLayer` with full-canvas role;
  - MCP animation -> channel writes;
  - MCP effect -> effect instance + param channels;
- fail-closed unresolved update policy;
- command diagnostics.

Acceptance:

- same action from UI and MCP produces same graph mutation shape;
- update does not insert new layer;
- background obeys active composition spec;
- proof includes canonical command id and target address.

### PCTMC-09 - Native Effect Stack Correction

Goal:

Effects become first-class native stack items attached to canonical targets with
animatable params.

Build:

- effect instance model/facade;
- effect stack ordering;
- param property paths;
- renderer conformance declarations;
- preview/export support matrix;
- initial blur/glow/shadow/noise records.

Acceptance:

- effect apply creates effect instance, not metadata-only success;
- param changes update same effect instance;
- param animation writes property channels;
- preview/export unsupported states block honest proof.

### PCTMC-10 - Renderer Proof And Ack Correction

Goal:

Proof reports real visual/render state.

Build:

- visual bounds proof;
- target count proof;
- layer count before/after proof;
- evaluated frame proof;
- renderer conformance proof;
- MCP ack payload update.

Acceptance:

- background proof validates canvas coverage;
- update proof validates unchanged target identity;
- motion proof validates evaluated property changes across time;
- effect proof validates renderer support or blocks;
- no metadata-only proof can pass.

### PCTMC-11 - Performance And Apply Latency Correction

Goal:

Make interactive apply immediate and diagnostics non-blocking.

Build:

- fast apply queue;
- affected-target-only layer fetch;
- pending-command priority;
- diagnostics background sync;
- timing instrumentation;
- apply latency budget.

Acceptance:

- simple MCP background/text/shape update appears within target budget;
- diagnostics cannot delay first visual apply;
- latency metrics are logged and testable.

Initial target budgets:

```text
local manual canvas preview update: < 16ms target, < 33ms acceptable
manual commit visible result: < 100ms
MCP pending command visible result after receipt: < 250ms target, < 750ms acceptable
cloud polling delay: measured separately, not counted as local apply time
```

### PCTMC-12 - Export Parity Gate

Goal:

Ensure preview truth and export truth do not diverge.

Build:

- export renderer conformance declarations per property/effect;
- frame evaluator reuse proof;
- unsupported property/effect blockers;
- golden/sample export tests where possible.

Acceptance:

- no property is marked production-ready without export decision;
- preview-only capabilities are feature-gated or clearly labeled;
- export does not use a separate hidden animation model.

---

## 7. First Practical Build Slice

The first implementation slice must be small and corrective:

```text
PCTMC-00 + PCTMC-01 + PCTMC-02
```

Do not begin canvas transaction rewiring before these pass.

Reason:

Without composition spec authority and canonical target identity, any canvas
transaction work may preserve the same ambiguity in a cleaner wrapper.

### Slice 1 Deliverables

- baseline comparison report;
- active composition spec contract/facade;
- canonical target identity facade;
- read-only discovery/test tools;
- background Story/Reels vs square proof test;
- ambiguous MCP update blocker test.

### Slice 1 Non-Goals

- no new visual effects;
- no Stage5 changes;
- no TimelinePanel replacement;
- no broad MCP tool expansion;
- no export renderer rewrite;
- no Remotion/HyperFrames embedding.

---

## 8. Required Decision Table Per Slice

Every slice must include this table before implementation:

| Area | Current ReFusion | OpenCut Lesson | HyperFrames Lesson | Remotion Lesson | Decision |
|---|---|---|---|---|---|
| Composition spec | TBD | TBD | TBD | TBD | keep/wrap/upgrade/add/replace/block |
| Identity | TBD | TBD | TBD | TBD | keep/wrap/upgrade/add/replace/block |
| Canvas edit | TBD | TBD | TBD | TBD | keep/wrap/upgrade/add/replace/block |
| Timeline lane | TBD | TBD | TBD | TBD | keep/wrap/upgrade/add/replace/block |
| Keyframe | TBD | TBD | TBD | TBD | keep/wrap/upgrade/add/replace/block |
| Effect | TBD | TBD | TBD | TBD | keep/wrap/upgrade/add/replace/block |
| Renderer proof | TBD | TBD | TBD | TBD | keep/wrap/upgrade/add/replace/block |

No slice may proceed with `TBD` values.

---

## 9. Validation Matrix

Run the relevant subset after each slice.

### 9.1 Composition Spec Tests

- create Story/Reels composition;
- add MCP background with no dimensions;
- add MCP background with square dimensions;
- add manual background;
- verify visual bounds equal canvas bounds;
- verify MCP active context reports correct dimensions.

### 9.2 Identity Tests

- insert text, update text, add animation to same text;
- insert shape, update corner radius;
- insert background, update color;
- insert image/video, update transform;
- verify layer count does not increase on update intent.

### 9.3 Canvas Transaction Tests

- move preview;
- cancel move;
- commit move;
- undo move;
- scale preview;
- rotate preview;
- verify timeline lane/property value matches canvas state.

### 9.4 Keyframe Tests

- add keyframe from canvas;
- add keyframe from timeline;
- move keyframe;
- edit value;
- duplicate layer;
- trim layer;
- verify local time behavior.

### 9.5 Effect Stack Tests

- apply blur;
- update blur amount;
- keyframe blur amount;
- apply glow after blur;
- reorder effects;
- remove effect;
- verify preview/export conformance status.

### 9.6 Proof Tests

- proof rejects metadata-only layer;
- proof rejects unresolved target update;
- proof rejects wrong canvas bounds;
- proof rejects unsupported renderer path;
- proof accepts graph + timeline + evaluator + renderer match.

### 9.7 Performance Tests

- manual preview update timing;
- manual commit timing;
- MCP command receipt to local visual apply timing;
- diagnostics non-blocking proof;
- repeated command duplicate suppression.

---

## 10. Metrics

Each checkpoint must report:

```text
composition_spec_match_rate
canonical_target_resolution_rate
ambiguous_target_block_rate
metadata_only_success_count
parallel_truth_path_count
canvas_timeline_value_mismatch_count
preview_export_conformance_gap_count
mcp_update_insert_regression_count
local_apply_latency_ms_p50
local_apply_latency_ms_p95
renderer_proof_pass_rate
```

Required target before declaring this correction complete:

```text
composition_spec_match_rate = 100%
metadata_only_success_count = 0
parallel_truth_path_count = 0 for corrected surfaces
canvas_timeline_value_mismatch_count = 0 for corrected properties
mcp_update_insert_regression_count = 0 for corrected layer types
renderer_proof_pass_rate = 100% for supported properties/effects
```

---

## 11. Risk Register

| Risk | Impact | Mitigation |
|---|---|---|
| Accidentally touching Live Scrub | High | stop and request explicit approval |
| Creating another facade that becomes parallel truth | High | all facades must be read-only or commit through command boundary |
| Fixing MCP but not Manual UI | High | command convergence required |
| Fixing UI but not MCP | High | same command family required |
| Adding effect metadata without renderer path | High | renderer conformance gate |
| Breaking existing canvas transform UX | Medium | preview transaction behind flag first |
| Slowing apply with proof checks | Medium | fast visual apply first, diagnostics/proof staged |
| Over-scoping the first slice | High | PCTMC-00/01/02 only |

---

## 12. Rollout Governance

### Definition Of Ready

A slice may start only when:

- pre-build comparison report exists;
- current ReFusion path is mapped;
- OpenCut/HyperFrames/Remotion lessons are listed;
- decision table has no `TBD`;
- protected path impact is explicitly `none` or separately approved;
- smallest verification tests are named.

### Definition Of Done

A slice is complete only when:

- code/doc changes match the slice scope;
- focused tests pass;
- no unrelated files are staged;
- checkpoint commit is created and pushed;
- rollback command is reported;
- proof/metrics are updated where relevant;
- remaining blockers are listed.

### Stop Conditions

Stop immediately if:

- implementation requires Stage5/protected Live Scrub changes;
- a UI-only or MCP-only path is introduced;
- a metadata-only visual success appears;
- unresolved update intent would insert a new layer;
- canvas and timeline values disagree after a corrected operation;
- proof claims renderer success without renderer evidence.

---

## 13. Relationship To PUCTAS And PNCLE

`PUCTAS` is the broad apply spine.

`PNCLE` is the native creative library/capability registry direction.

`PCTMC` is the correction layer that makes both safe for canvas/timeline
authoring.

Recommended dependency order:

```text
PCTMC-00/01/02
-> PNCLE-05C identity hardening continuation
-> PUCTAS command/apply convergence
-> PCTMC-03/04/05 canvas transaction + property graph
-> PCTMC-06/07 timeline/evaluator mandate
-> PCTMC-08 MCP/manual command convergence
-> PCTMC-09/10 effects/proof
-> PCTMC-11/12 performance/export parity
```

This order prevents jumping into effects, templates, or agent creativity before
the canvas/timeline/time truth is stable.

---

## 14. Final Rule

ReFusion must become:

```text
one native professional editor
with many entry surfaces
but only one creative truth
```

If a change makes canvas, timeline, MCP, preview, or export disagree, the change
is not professional enough for this plan.

