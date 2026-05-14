# Open Source Video Editor Reference Deep Research

Date: 2026-05-15

Scope: compare the local research references against ReFusion's native Flutter
canvas/timeline/master-clock direction. This is an architecture extraction
report, not an implementation plan and not runtime code.

Local reference roots:

- `research/hyperframe_and_remotion/repos/fluvie`
- `research/hyperframe_and_remotion/repos/opencut`
- `research/hyperframe_and_remotion/repos/opentimelineio`
- `research/hyperframe_and_remotion/repos/mlt`
- `research/hyperframe_and_remotion/repos/libopenshot`
- `research/hyperframe_and_remotion/repos/glaxnimate`
- `research/hyperframe_and_remotion/repos/olive`
- `research/hyperframe_and_remotion/repos/hyperframes`
- `research/hyperframe_and_remotion/repos/remotion`

Primary ReFusion problem this research answers:

```text
How should ReFusion make canvas, timeline, MCP/manual edits, keyframes,
effects, frame evaluation, preview, and export agree through one native truth?
```

---

## 1. Executive Ranking

### 1.1 Best References For ReFusion

| Rank | Reference | Use For ReFusion | Reason |
|---|---|---|---|
| 1 | OpenCut | Unified element identity, update commands, keyframe channels, effects registry, preview renderer boundary | Closest modern editor architecture to our current UI/MCP problem. Strong update-vs-insert separation. |
| 2 | Fluvie | Flutter-native frame rendering, composition metadata, layer stack, frame capture/export | Closest runtime technology because it is Flutter and frame-based. |
| 3 | OpenTimelineIO | Canonical timeline/time-range language | Best reference for making timeline semantics explicit and portable. |
| 4 | Glaxnimate | Shape/text/vector animation model, animatable transform, command-based property changes | Best reference for professional shape/text/keyframe authoring. |
| 5 | MLT | Native NLE service model: producer/filter/transition/tractor/multitrack | Best low-level NLE mental model for render graph separation. |
| 6 | libopenshot | Clip/keyframe/effect/timeline compositing concepts | Useful for native clip property/keyframe/effect design, but LGPL and C++/Qt integration make direct embedding less attractive. |
| 7 | HyperFrames | AI authoring, registry/catalog, deterministic seek adapters, effect recipe catalog | Excellent for agent-facing creative patterns, not a native Flutter editor model. |
| 8 | Remotion | Composition metadata, frame determinism, sequence-local frame, motion blur sampling | Strong conceptual reference, but source-available license and React runtime mean inspiration only. |
| 9 | Olive | Advanced NLE UI/render/cache/keyframe concepts | Useful as a professional editor reference, but GPL and alpha-like complexity make it study-only. |

### 1.2 Main Conclusion

No single project should be embedded wholesale inside ReFusion.

The correct path is a native synthesis:

```text
OpenCut command/update/effects/keyframe contracts
+ Fluvie Flutter frame rendering discipline
+ OpenTimelineIO time-range vocabulary
+ Glaxnimate shape/text/animatable property model
+ MLT/libopenshot NLE render graph concepts
+ HyperFrames/Remotion deterministic authoring lessons
= ReFusion native creative truth spine
```

---

## 2. License And Embedding Reality

| Reference | License Observed Locally | Direct Embedding Recommendation |
|---|---|---|
| Fluvie | MIT | Possible from a licensing perspective, but prefer architectural extraction first. |
| OpenCut | MIT | Strong candidate for contract-level inspiration; code reuse may be possible, but it is web/TS/Rust. |
| OpenTimelineIO | Apache-2.0 | Safe as a schema/adaptor reference; direct library integration can be considered later. |
| MLT | LGPL-2.1+ | Do not embed casually in mobile Flutter; study the architecture. |
| libopenshot | LGPL-3+ | Avoid direct embedding unless legal/distribution strategy is explicit. Study keyframe/effect patterns. |
| Glaxnimate | GPL-3.0-or-later in source headers | Study only; do not embed directly into proprietary/mobile runtime without legal review. |
| Olive | GPL-3.0 | Study only. |
| HyperFrames | Apache-2.0 | Safe to study; code/runtime is HTML/browser-oriented, not our native truth. |
| Remotion | Custom Remotion License | Inspiration only unless license terms are satisfied. |

Practical rule:

```text
Use permissive projects for possible adapter/schema inspiration.
Use LGPL/GPL/custom-license projects as architecture references unless legal approves direct use.
```

---

## 3. Reference Findings

## 3.1 OpenCut

Important files inspected:

- `apps/web/src/timeline/types.ts`
- `apps/web/src/animation/types.ts`
- `apps/web/src/animation/resolve.ts`
- `apps/web/src/timeline/update-pipeline.ts`
- `apps/web/src/commands/timeline/element/update-elements.ts`
- `apps/web/src/effects/registry.ts`
- `apps/web/src/effects/definitions/blur.ts`
- `apps/web/src/commands/timeline/element/effects/add-effect.ts`
- `apps/web/src/commands/timeline/element/effects/update-effect-params.ts`
- `apps/web/src/services/renderer/canvas-renderer.ts`

### Architecture Observed

OpenCut models a scene as tracks containing typed elements. Every visual element
has stable identity, timing, params, optional animations, optional effects, and
optional masks.

Core pattern:

```text
SceneTracks
  -> Track
      -> TimelineElement(id, startTime, duration, trim, params, animations, effects)
```

The `ElementRef` contract is explicit:

```text
trackId + elementId
```

This is exactly what ReFusion needs to stop ambiguous MCP updates from turning
into inserts.

### Why It Matters For ReFusion

OpenCut separates:

```text
InsertElementCommand
UpdateElementsCommand
AddClipEffectCommand
UpdateClipEffectParamsCommand
UpsertKeyframeCommand
```

That means an agent cannot accidentally create a new layer when the semantic
intent is update. The command type and target identity decide the operation.

This directly maps to ReFusion's MCP bugs:

- text update becoming duplicate insert;
- shape update becoming new shape;
- animation targeting the wrong layer;
- effects being attached by metadata instead of exact target/effect instance.

### Strong Ideas To Adopt

1. Use `ElementRef(trackId, elementId)` or ReFusion equivalent for every manual,
   MCP, script, and template update.
2. Define `TimelineElement` as the universal editable unit across text, shape,
   solid/background, image, video, audio, effect control, mask.
3. Store `params`, `animations`, `effects`, and `masks` on the same canonical
   element object.
4. Route all updates through one `applyElementUpdate` pipeline.
5. Effects must be instances with `id`, `type`, `params`, and renderer pass
   declaration.
6. Effect update must target `elementId + effectId`, never just layer kind.
7. Animation keyframes must be relative to element local time, not random global
   fallback time.

### Specific Effect Lesson

OpenCut's blur is not just metadata. It defines:

- effect type: `blur`;
- params: `intensity` with default/min/max/step;
- renderer passes;
- sigma conversion from UI intensity to renderer-space sigma;
- multi-pass Gaussian blur construction.

For ReFusion this means:

```text
A professional effect is not complete until it has:
registry definition
parameter schema
renderer implementation
preview/export conformance
updatable effect instance identity
keyframable parameter path
```

---

## 3.2 Fluvie

Important files inspected:

- `lib/src/presentation/video_composition.dart`
- `lib/src/presentation/layer.dart`
- `lib/src/integration/render_service.dart`
- `lib/src/capture/frame_sequencer.dart`
- `lib/src/capture/frame_pipeline.dart`
- `lib/src/utils/interpolate.dart`
- `lib/src/declarative/animations/core/prop_animation.dart`

### Architecture Observed

Fluvie is very close to ReFusion technically because it is Flutter-native and
frame-based. The key root contract is `VideoCompositionData`:

```text
fps
durationInFrames
width
height
encoding
```

This is the same class of authority ReFusion is missing when MCP builds a square
background inside a Story/Reels composition.

Fluvie layers are frame-aware widgets:

```text
Layer(id, startFrame, endFrame, fadeInFrames, fadeOutFrames, opacity, blendMode, zIndex, transform)
```

A layer only renders if the current frame is inside its active window.

### Why It Matters For ReFusion

Fluvie confirms that a Flutter video/motion system can be deterministic if:

- composition metadata is available through the tree;
- current frame is explicit;
- layers evaluate visibility and opacity by frame;
- export loops frames deterministically;
- frame capture is exact-width/exact-height;
- encoding is fed by a bounded frame pipeline.

This is very relevant to the current ReFusion delay problem. ReFusion should not
wait on slow cloud/MCP sync to visually apply local effects. Local apply should
update the graph immediately, and proof/diagnostics can follow.

### Strong Ideas To Adopt

1. ReFusion needs a mandatory `ActiveCompositionSpec` available to every UI/MCP
   apply path:

```text
compositionId
width
height
fps
duration
pixelAspectRatio
safeArea/profile
```

2. Background/solid creation must default to `ActiveCompositionSpec.width/height`,
   not payload dimensions when intent is full-canvas background.
3. Preview/export frame capture must reject aspect mismatch instead of silently
   resizing or letterboxing for production proof.
4. Export should use a bounded frame pipeline concept for BMF/FFmpeg/native
   renderer work:

```text
frame evaluator -> frame capture/render -> bounded queue -> encoder
```

5. Frame rendering must be tied to master frame, not wall-clock widgets.

### Caution

Fluvie is not an interactive NLE editor. It is stronger for programmatic Flutter
video rendering than for live canvas/timeline editing. So it should influence
ReFusion's renderer/export spine, not replace the editor model.

---

## 3.3 OpenTimelineIO

Important files inspected:

- `src/opentimelineio/timeline.h`
- `src/opentimelineio/track.h`
- `src/opentimelineio/clip.h`
- `src/opentimelineio/stack.h`
- `src/opentimelineio/item.h`
- `docs/tutorials/time-ranges.md`

### Architecture Observed

OTIO is not a renderer. Its value is timeline semantics. It makes time ranges
explicit and differentiates:

```text
Clip time frame
Parent track time frame
Timeline/root time frame
source_range
trimmed_range
visible_range
range_in_parent
```

This maps strongly to ReFusion's need for root composition time, scene time,
clip time, transition time, and layer-local keyframe time.

### Why It Matters For ReFusion

Many editor bugs happen because a value is written in one time domain and read
in another. OTIO's language gives us a clean vocabulary to prevent this.

ReFusion should explicitly store/evaluate:

```text
rootTime
sceneTime
clipLocalTime
elementLocalTime
effectLocalTime
transitionProgress
```

### Strong Ideas To Adopt

1. Keep ReFusion's native graph, but use OTIO-style naming in docs/models.
2. Every element should expose:

```text
sourceRange
visibleRange
rangeInParent
trimmedRangeInRoot
```

3. Keyframes must declare which time domain they use.
4. MCP commands must not pass bare milliseconds/frames without domain.
5. Export proof must verify the same root-to-local projection used in preview.

---

## 3.4 MLT

Important files inspected:

- `src/framework/mlt_tractor.h`
- `src/framework/mlt_multitrack.h`
- `src/framework/mlt_playlist.h`
- `src/framework/mlt_producer.h`
- `src/framework/mlt_filter.h`
- `src/framework/mlt_transition.h`
- `src/framework/mlt_animation.h`
- `src/tests/test_tractor/test_tractor.cpp`
- `src/tests/test_properties/test_properties.cpp`

### Architecture Observed

MLT separates editing/rendering into services:

```text
producer -> source frames
filter -> modifies one producer/frame stream
transition -> combines streams
multitrack -> manages tracks
tractor -> orchestrates multitrack + filters + transitions
consumer -> output/render target
```

Animation is property-oriented:

```text
mlt_animation_item(frame, property, keyframe_type)
```

### Why It Matters For ReFusion

MLT is a mature reminder that effects and transitions should not be random UI
metadata. They must be part of a render graph with clear attachment points and
frame positions.

### Strong Ideas To Adopt

1. Treat ReFusion renderer as a graph of services:

```text
source layer producer
property evaluator
effect filter stack
transition/mask compositor
consumer/export target
```

2. Effects should be frame-processing services with in/out ranges and disabled
   state.
3. Track insert/remove must update effect/transition track attachment indices or
   equivalent stable target references.
4. Avoid copying MLT directly into mobile unless there is a deliberate native
   integration strategy.

---

## 3.5 libopenshot

Important files inspected:

- `src/Timeline.h`
- `src/Clip.h`
- `src/KeyFrame.h`
- `src/EffectBase.h`
- `src/effects/Blur.cpp`
- `src/effects/Brightness.cpp`
- `src/Frame.h`

### Architecture Observed

libopenshot centers on a `Timeline` that owns clips and effects and generates
frames by requested frame number.

Clip properties are keyframable. The examples show properties like:

```text
alpha
position
start/end
layer
scale/gravity
```

The `Keyframe` class is a collection of `Point`s and supports linear/bezier
interpolation, point add/remove/update, scale/stretch, and JSON serialization.

Effects derive from `EffectBase`, have order, parent clip, JSON, info, and an
`Apply()` contract in derived classes.

### Why It Matters For ReFusion

libopenshot is close to what ReFusion's native render/export model should feel
like:

```text
Timeline.GetFrame(frameNumber)
-> gather intersecting clips
-> sort layers
-> apply clip transforms/keyframes
-> apply effects
-> composite frame
```

ReFusion already has pieces of this, but the missing piece is making manual/MCP
writes feed the same evaluated clip/layer/effect model.

### Strong Ideas To Adopt

1. Native frame evaluator should be able to answer:

```text
getFrame(frameNumber, renderMode)
```

2. Layer order and effect order must be deterministic and serialized.
3. Keyframes should support point update/remove/scale/stretch, not only add.
4. Effect instances should have parent target, order, range, params, and JSON
   export/import.
5. Do not embed directly without license/legal and native distribution review.

---

## 3.6 Glaxnimate

Important files inspected:

- `src/core/model/document.hpp`
- `src/core/model/animation_container.hpp`
- `src/core/model/transform.hpp`
- `src/core/model/comp_graph.hpp`
- `src/core/model/document_node.hpp`
- `src/core/command/property_commands.hpp`
- `src/core/command/animation_commands.hpp`
- `src/core/command/shape_commands.hpp`
- `src/gui/graphics/document_scene.hpp`
- `src/gui/tools/rectangle_tool.cpp`
- `src/gui/tools/text_tool.cpp`

### Architecture Observed

Glaxnimate is a strong vector animation editor. It has:

- document object with current time;
- current composition;
- undo stack;
- record-to-keyframe mode;
- find-by-uuid/name/type;
- animation containers with first/last frame;
- animatable transform properties;
- property commands that support mergeable undo/redo;
- shape/text tools that operate through commands.

Transform is clean and explicit:

```text
anchor_point
position
scale
rotation
```

All are animatable.

### Why It Matters For ReFusion

This is the closest reference for ReFusion's native shape/text layer model.
OpenCut is better for timeline commands. Glaxnimate is better for professional
shape/text property design.

### Strong Ideas To Adopt

1. Every ReFusion layer property should be a typed property object, not loose
   payload data.
2. Canvas edits should use mergeable property commands:

```text
SetPropertyValue
SetMultipleProperties
```

3. Transform must include anchor separately from position.
4. Text and shape tools must create/update document nodes with stable UUIDs.
5. Record-to-keyframe mode should be explicit:

```text
if recordToKeyframe:
  property change -> keyframe at current time
else:
  property change -> static/base value
```

This is directly relevant to canvas transform + timeline keyframe consistency.

---

## 3.7 Olive

Important files inspected:

- `app/widget/timelinewidget/timelinewidget.h`
- `app/widget/keyframeview/keyframeview.h`
- `app/widget/curvewidget/curveview.h`
- `app/widget/nodeparamview/*`
- `app/render/renderer.h`
- `app/render/framemanager.h`
- `app/render/rendermanager.h`

### Architecture Observed

Olive is a heavier professional NLE architecture with:

- timeline widget and editing tools;
- time-based widgets;
- keyframe views;
- node parameter editing;
- renderer abstraction;
- texture/frame manager;
- color-managed rendering;
- preview caching.

### Why It Matters For ReFusion

Olive should not be copied, but it validates that a serious editor separates:

```text
timeline interaction widgets
node/property editing
keyframe/curve editing
render manager
frame/texture cache
viewer output
```

### Strong Ideas To Adopt

1. ReFusion's timeline panel should not directly own creative truth forever.
2. Timeline UI should be a projection over graph/channel data.
3. Keyframe editor should operate on selected property channels, not per-widget
   ad-hoc state.
4. Frame/cache management should be a first-class subsystem for preview speed.
5. GPL means study-only unless legal changes strategy.

---

## 3.8 HyperFrames

Important files inspected:

- `README.md`
- `packages/core/src/index.ts`
- `packages/core/src/core.types.ts`
- `packages/engine/src/services/frameCapture.ts`
- `packages/engine/src/services/streamingEncoder.ts`
- `packages/engine/src/services/parallelCoordinator.ts`
- `packages/player/src/direct-timeline-clock.ts`
- `registry/registry.json`
- `registry/blocks/*/registry-item.json`
- `registry/components/*/registry-item.json`

### Architecture Observed

HyperFrames is built around HTML composition authoring, deterministic seeking,
agent skills, a registry/catalog, frame capture, and encoder pipeline.

Important value for ReFusion is not the HTML runtime. The value is the product
surface:

```text
agents know how to author scenes
registry provides ready blocks/components
runtime must be seekable
preview and render use the same deterministic frame contract
```

### Why It Matters For ReFusion

HyperFrames explains why agents produce rich results: they have:

- a catalog;
- snippets;
- skills;
- deterministic animation recipes;
- explicit composition tags/metadata;
- validator/linter expectations.

ReFusion needs a native equivalent:

```text
Native Creative Registry
Native Scene Recipes
Native Effect Recipes
Native Text/Shape Presets
Native Animation Recipe Library
Native Capability Discovery for MCP
```

### Strong Ideas To Adopt

1. Build a ReFusion registry like HyperFrames catalog, but output native
   SceneCommand/Graph, not HTML.
2. Keep agent authoring constrained by capability discovery.
3. Every registry item should include:

```text
name
description
inputs
layer types
property paths
effect stack
renderer conformance
preview/export support
example prompt
fallback behavior
```

4. Add lints against wall-clock animation, metadata-only effects, and unresolved
   target updates.

---

## 3.9 Remotion

Important files inspected:

- `packages/core/src/Composition.tsx`
- `packages/core/src/CompositionManager.tsx`
- `packages/core/src/use-current-frame.ts`
- `packages/core/src/use-video-config.ts`
- `packages/core/src/ResolveCompositionConfig.tsx`
- `packages/motion-blur/src/CameraMotionBlur.tsx`
- `packages/motion-blur/src/Trail.tsx`

### Architecture Observed

Remotion enforces composition identity and video config:

```text
id
width
height
fps
durationInFrames
props/schema
```

`useCurrentFrame()` returns frame relative to sequence context, not arbitrary
wall-clock time.

Motion blur is implemented by repeated sub-frame or offset-frame samples of the
same child content.

### Why It Matters For ReFusion

Remotion's most useful lesson is deterministic frame thinking:

```text
frame -> component props/state -> visual output
```

For ReFusion this should become:

```text
masterFrame -> graph/channel evaluation -> native preview/export output
```

### Strong Ideas To Adopt

1. Composition spec must be mandatory and validated before agent creation.
2. Current frame must be a read from the master clock/evaluator, not UI time.
3. Motion blur should be modeled as temporal sampling:

```text
samples
shutterAngle
sampleFrameOffset
blend/opacity policy
```

4. Updating a component/layer means updating identity-bound props, not inserting
   another component.
5. Due to license and React runtime, use Remotion for concepts only.

---

## 4. Cross-System Matrix

| Concern | Best Reference | What ReFusion Should Do |
|---|---|---|
| Composition size/fps/duration authority | Fluvie + Remotion | Create mandatory `ActiveCompositionSpec` consumed by UI/MCP/export. |
| Timeline schema | OpenTimelineIO + OpenCut | Introduce canonical element/track/time-range contract. |
| Update vs insert | OpenCut + Glaxnimate | Commands must declare insert/update; unresolved update must fail closed. |
| Canvas edits | Glaxnimate + OpenCut | Preview transaction -> property command -> graph/channel commit. |
| Keyframes | OpenCut + libopenshot + MLT | Property channels with local-time keyframes, interpolation, update/remove/stretch. |
| Effects | OpenCut + MLT + libopenshot | Effect registry + effect instance identity + renderer pass + parameter channels. |
| Shapes/text | Glaxnimate | Typed document nodes with animatable transform and property commands. |
| Frame evaluator | Remotion + libopenshot + ReFusion existing evaluator | One master frame evaluator feeds preview and export. |
| Flutter frame capture/export | Fluvie | Bounded frame pipeline and exact target dimensions. |
| Agent creative catalog | HyperFrames | Native registry recipes, not HTML embedding. |
| Render/cache performance | Olive + Fluvie + HyperFrames | Fast local apply first, background diagnostics/proof second. |
| Export parity | Fluvie + HyperFrames + libopenshot | Preview/export must evaluate the same graph and property paths. |

---

## 5. Where ReFusion Already Has Strong Pieces

Files inspected:

- `domain/models/professional_motion_models.dart`
- `domain/models/professional_motion_animation_models.dart`
- `domain/services/timeline_clock_coordinator.dart`
- `domain/services/master_keyframe_value_evaluator.dart`
- `presentation/services/master_frame_evaluation_read_adapter.dart`
- `presentation/services/mcp_scene_command_dispatcher.dart`
- `presentation/services/mcp_text_layer_resolution.dart`
- `presentation/services/mcp_shape_layer_resolution.dart`

ReFusion already has important foundations:

- `TimelineClockCoordinator` with phase/authority concepts;
- `MasterKeyframeValueEvaluator` with interpolation and velocity/acceleration;
- `MasterFrameEvaluationReadAdapter` that evaluates channels by clock;
- `MotionTargetKind`, `MotionLayerKind`, `MotionElementKind`, `MotionPropertyGroup`;
- keyframe interpolation types including spring/bounce/elastic;
- text/shape identity resolvers emerging for MCP.

This is good. It means we do not need to throw away the system.

The gap is not lack of theory. The gap is enforcement:

```text
not every UI/MCP/manual/template operation is forced through those models yet
```

---

## 6. ReFusion Gaps Against References

### 6.1 Composition Spec Gap

Observed problem:

```text
User chooses Story/Reels, MCP creates square background.
```

Reference lessons:

- Fluvie root composition provides `width`, `height`, `fps`, `durationInFrames`.
- Remotion composition registration validates width/height/fps/duration.
- HyperFrames composition root declares `data-width`, `data-height`, timing.

Required ReFusion correction:

```text
MCP must never infer canvas dimensions.
MCP must read ActiveCompositionSpec.
Background intent must snap to composition bounds unless explicitly requested otherwise.
```

### 6.2 Universal Identity Gap

Observed problem:

```text
Update text + add animation -> duplicate text layer with animation.
```

Reference lessons:

- OpenCut update command targets `trackId + elementId`.
- Glaxnimate property command targets a specific property object.
- Remotion updates by identity/props.

Required ReFusion correction:

```text
All layer types need UniversalLayerIdentity, not only text/shape partial fixes.
If intent is update and target is unresolved, block. Never insert.
```

### 6.3 Property Graph Gap

Observed problem:

```text
Canvas values, timeline lanes, MCP payloads, and renderer values can diverge.
```

Reference lessons:

- OpenCut stores params + animations + effects on element.
- Glaxnimate uses typed properties and property commands.
- MLT/libopenshot evaluate properties at frame time.

Required ReFusion correction:

```text
Every editable property must have a canonical property path.
Canvas, timeline, MCP, export all write/read that path.
```

### 6.4 Effect Stack Gap

Observed problem:

```text
Effect can be delayed or appear as metadata success before visual proof.
```

Reference lessons:

- OpenCut effect definitions include params and renderer passes.
- MLT filters process frames and have in/out/disabled semantics.
- libopenshot effects have order and parent clip.

Required ReFusion correction:

```text
Effect = registry definition + instance id + target id + params + renderer path + conformance.
No metadata-only effect success.
```

### 6.5 Preview/Export Proof Gap

Observed problem:

```text
System can say applied before renderer proves it.
```

Reference lessons:

- Fluvie captures exact target frames.
- HyperFrames has render/runtime conformance concepts.
- OpenCut renderer resolves tree then builds frame descriptor then renders.

Required ReFusion correction:

```text
Proof must include graph mutation + frame evaluator result + renderer evidence.
```

### 6.6 Latency Gap

Observed problem:

```text
Effects/backgrounds can appear after 10-60 seconds.
```

Reference lessons:

- OpenCut local commands update editor state directly.
- Fluvie separates capture/encoding pipeline from composition state.
- Olive separates preview/cache/render management.

Required ReFusion correction:

```text
Local apply must be immediate.
Cloud/MCP sync and diagnostics must not block visual graph mutation.
```

---

## 7. Recommended Native ReFusion Synthesis

### 7.1 Canonical Editable Unit

```text
CreativeElement
  id
  stableAliases
  kind: text | shape | background | image | video | audio | camera | effectControl | mask
  trackId
  parentSceneId
  timeRange
  sourceRange
  zOrder
  params
  propertyChannels
  effectStack
  masks
  rendererConformance
```

This combines OpenCut element identity, OTIO ranges, Glaxnimate typed
properties, and ReFusion motion models.

### 7.2 Canonical Command Boundary

```text
CreateElementCommand
UpdateElementCommand
DeleteElementCommand
MoveElementCommand
UpsertKeyframeCommand
UpdateKeyframeCommand
AddEffectInstanceCommand
UpdateEffectInstanceCommand
RemoveEffectInstanceCommand
```

All entry points must use the same command family:

```text
Manual UI
MCP
Script
Templates
Import
```

### 7.3 Mandatory Target Resolution Rule

```text
insert intent:
  may create new element

update intent:
  must resolve canonical element id
  if unresolved -> block with actionable reason

motion/effect intent:
  must resolve canonical element id
  if effect update -> must resolve effect instance id or explicitly add new effect
```

### 7.4 Native Effect Stack Contract

```text
EffectDefinition
  id
  name
  paramSchema
  defaultParams
  supportedTargets
  rendererPasses
  previewSupport
  exportSupport
  keyframableParams
  fallbackPolicy

EffectInstance
  id
  definitionId
  targetElementId
  params
  enabled
  order
  activeRange
  paramChannels
```

### 7.5 Frame Evaluation Contract

```text
MasterFrameEvaluationInput
  compositionSpec
  rootFrame
  renderMode
  creativeGraph

MasterFrameEvaluationOutput
  visibleElements
  evaluatedProperties
  evaluatedEffects
  diagnostics
  rendererProofRequirements
```

Preview and export must consume this output, not separate UI payloads.

---

## 8. What To Do First

The strongest immediate corrective sequence is:

```text
1. ActiveCompositionSpec Authority
2. Universal CreativeElement Identity
3. Command Boundary for Insert vs Update
4. Property Path Catalog
5. Effect Instance Contract
6. Master Frame Evaluation Proof
7. Preview/Export Parity Tests
```

This aligns with the previously created `PCTMC` plan and should happen before
expanding the creative library aggressively.

---

## 9. Concrete Mapping To Existing ReFusion Problems

| Current Failure | Best Reference Lesson | Required ReFusion Fix |
|---|---|---|
| Story/Reels becomes square | Fluvie/Remotion composition spec | MCP apply reads active spec; background dimensions canonicalize to canvas. |
| Text update duplicates layer | OpenCut update command + Glaxnimate property command | Update intent must target existing `CreativeElement`; unresolved update blocks. |
| Animation goes to wrong target | OpenCut `SelectedKeyframeRef` and local-time channels | Motion command requires target id + property path + local time domain. |
| Shape update might insert shape | Glaxnimate document node/property command | Shape is same universal identity path as text, not separate ad hoc branch. |
| Effect appears late | OpenCut local command + renderer passes | Local graph mutation immediately invalidates preview; diagnostics are async. |
| Effect metadata success | MLT/libopenshot/OpenCut renderer effect model | Effect must have renderer conformance and proof before success. |
| Preview/export mismatch | Fluvie exact frame capture + libopenshot frame generation | Preview/export use same evaluator output. |

---

## 10. Deep Research Verdict

### 10.1 Most Important Source To Study Next

OpenCut should be studied first in detail.

Reason:

```text
OpenCut directly answers our highest-risk bugs:
identity, update-vs-insert, keyframes, effects, renderer boundary, timeline commands.
```

### 10.2 Most Important Source To Extract Into Native Flutter

Fluvie should be studied second.

Reason:

```text
Fluvie proves the Flutter side of deterministic frame capture, exact dimensions,
composition metadata, and frame pipeline.
```

### 10.3 Most Important Source For Shapes/Text

Glaxnimate should be studied third.

Reason:

```text
It has the cleanest professional property/animation model for vector/text nodes,
including record-to-keyframe behavior and mergeable property commands.
```

### 10.4 Most Important Source For Long-Term Export/NLE Thinking

MLT + libopenshot should be studied as render architecture references.

Reason:

```text
They show mature producer/filter/transition/timeline/keyframe/effect separation.
```

### 10.5 Most Important Source For Agent Creative Library

HyperFrames should guide the registry and recipe authoring layer.

Reason:

```text
It explains why agents can build rich scenes: catalog + skills + deterministic
recipes + validation.
```

### 10.6 Most Important Source For Frame Determinism

Remotion remains useful conceptually.

Reason:

```text
Composition metadata, current frame, sequence-local frame, and temporal sampling
are highly relevant, even if the runtime should not be embedded.
```

---

## 11. Final Architectural Rule

ReFusion should not become OpenCut, Fluvie, MLT, Glaxnimate, HyperFrames, or
Remotion.

ReFusion should become:

```text
A native Flutter/BMF editor with:
- OpenCut-grade command and identity discipline
- Fluvie-grade Flutter frame determinism
- OTIO-grade time-range language
- Glaxnimate-grade shape/text property model
- MLT/libopenshot-grade render/effect graph thinking
- HyperFrames-grade agent catalog/recipes
- Remotion-grade frame/config determinism
```

That is the most professional synthesis for our current architecture.
