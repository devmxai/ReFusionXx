# TRUEFRAME CORE

Status: official global execution-engine architecture plan
Audience: Codex 5.3 writer agent and future ReFusion engineering agents
Project: `/Users/mx/Documents/ReFusionXx`
Branch: `codex/unified-keyframe-ops-foundation-20260426`
Created from checkpoint: `95d1232`
First implementation slice: `TRUEFRAME ONE` Manual Transition FX

## 0. Executive Decision

ReFusion must not build a professional engine for Manual Transition only.

The correct architecture is:

```text
TRUEFRAME CORE = global composition/layer/effect execution engine
TRUEFRAME ONE  = first vertical slice: Manual Transition FX
```

The core engine must understand every renderable object in the app:

- video layers,
- image layers,
- text layers,
- shape layers,
- masks,
- groups,
- precomps / scene clips,
- transitions,
- generated scene program layers,
- future adjustment/camera/effect-control layers.

Manual Transition remains the first implementation target because it is the
place where the current split renderer problem is most visible:

```text
Stage5 native preview renderer
+ Professional transition compositor
+ Stage6 export renderer
= multiple execution truths
```

The long-term engine must be one source of truth:

```text
UniversalMotionGraph / authoring truth
-> MasterFrameEvaluation / value truth
-> MasterVisualProgram / renderer-neutral visual truth
-> MasterRenderGraph / execution graph truth
-> TrueFrameRenderBackend adapters
-> RendererPresentationProof
```

The rule is:

```text
Not necessarily the same rendering code.
Always the same execution truth.
```

Preview, live scrub, playback, and export may use different quality settings and
different backend adapters. They may not reinterpret animation, keyframes,
effects, time, source mapping, or render order independently.

## 1. Why This Plan Exists

The previous `TRUEFRAME ONE` plan correctly diagnosed the Manual Transition
problem, but its main contract names were transition-specific:

```text
TransitionExecutionGraph
TransitionRuntimeEvaluator
NativeTransitionRenderBackend
TransitionFrameState
```

Those names are safe only as first-slice aliases. They must not become the
permanent architecture. If they do, ReFusion will eventually have:

```text
TransitionExecutionGraph
ShapeExecutionGraph
TextExecutionGraph
SceneExecutionGraph
ExportGraph
```

That would recreate the same split architecture that is breaking Motion Blur
today.

The professional target is one core engine:

```text
TrueFrameExecutionGraph
CoreRuntimeEvaluator
TrueFrameRenderBackend
NodeFrameState
CoreSamplingPlan
```

Then Manual Transition, text, image, shape, video, generated scenes, and export
become vertical slices over the same core.

## 2. External Professional Alignment

This architecture is aligned with professional motion/compositing systems:

- After Effects models the world as projects, compositions, layers, properties,
  keyframes, and expressions. A layer/property model is the authoring truth;
  renderers evaluate those properties at time.
  Reference: `https://ae-scripting.docsforadobe.dev/introduction/objectmodel/`
- After Effects motion blur is a composition/layer concept with shutter angle,
  shutter phase, samples per frame, and adaptive sample limit. This implies
  temporal evaluation over time, not Gaussian blur after the fact.
  Reference: `https://ae-scripting.docsforadobe.dev/item/compitem/`
- Apple Motion uses objects, groups, layers, effects, filters, behaviors,
  keyframes, canvas preview settings, and render settings over the same project
  model.
  Reference: `https://support.apple.com/guide/motion/welcome/mac`
- DaVinci Resolve/Fusion uses a node tree to express how effects, masks,
  transforms, merges, titles, and animations are connected. The graph, not each
  UI panel, defines execution order.
  Reference: `https://www.blackmagicdesign.com/ca/products/davinciresolve/fusion`
- Media3 Transformer is useful as a media editing/export backbone implemented
  over MediaCodec and OpenGL, but Media3/CanvasOverlay is an adapter/backend
  layer, not ReFusion's universal composition truth.
  References:
  `https://developer.android.google.cn/media/media3/transformer`
  `https://developer.android.com/reference/androidx/media3/effect/CanvasOverlay`

Implication for ReFusion:

```text
TRUEFRAME CORE owns semantic truth.
Backends execute that truth.
No backend invents its own meaning.
```

## 3. Relationship To Existing ReFusion Plans

This plan does not replace the already built universal motion foundation.

It depends on it.

Authoritative existing contracts:

- `professional_universal_motion_engine_plan.md`
- `professional_canva_layer_unification_plan.md`
- `professional_composition_timeline_migration_plan.md`
- `professional_refusion_motion_keyframe_engine.md`
- `professional_checkpoint_policy.md`

TRUEFRAME CORE must not create a second master engine beside:

```text
UniversalMotionGraph
MasterFrameEvaluation
MasterVisualProgram
MasterRenderGraph
RendererPresentationProof
```

Instead, TRUEFRAME CORE makes that chain executable and render-owned across
preview, live scrub, playback, and export.

Preferred naming alignment:

```text
UniversalMotionGraph      = authoring/channel truth
MasterFrameEvaluation     = evaluated value truth at time
MasterVisualProgram       = renderer-neutral visual instruction truth
MasterRenderGraph         = execution DAG truth
TrueFrameRenderBackend    = backend execution adapters
RendererPresentationProof = displayed/exported frame proof
```

If a `TrueFrameExecutionGraph` model is introduced, it must be a concrete
renderer-execution form of `MasterRenderGraph`, not a parallel truth.

## 4. Core Architecture

### 4.1 Full Execution Chain

```text
User authoring / playback / scrub / export request
-> TimelineClockCoordinator
-> MasterTimeSnapshot
-> MasterTimeDomainMapper
-> UniversalMotionGraph
-> UniversalMotionTargetResolver
-> MasterKeyframeValueEvaluator
-> MasterValueTruthRegistry
-> MasterFrameEvaluation
-> MasterVisualProgram
-> MasterRenderGraph / TrueFrameExecutionGraph
-> CoreRuntimeEvaluator
-> TrueFrameRenderBackend adapter
-> RendererPresentationProof
```

Every scope is a view into this chain:

- root composition timeline,
- scene contents timeline,
- layer scope timeline,
- transition timeline,
- text timeline,
- shape timeline,
- image/video layer timeline,
- export timeline.

No scope is allowed to become its own animation engine.

### 4.2 Core Node Model

Every renderable thing becomes a node:

```text
VideoLayerNode
ImageLayerNode
TextLayerNode
ShapeLayerNode
MaskNode
EffectStackNode
TransitionNode
GroupNode
PrecompNode
SceneClipNode
AdjustmentNode
CameraNode
OutputSurfaceNode
```

Every node must have stable identity:

```text
nodeId
sourceId
targetId
layerId
scopeId
rootTimeRange
localTimeRange
sourceTimeMapping
zOrder
blendMode
bounds
surfacePolicy
diagnostics
```

### 4.3 Node Channels

Core channels must not be transition-specific.

Minimum common channel families:

```text
transform.position
transform.scale
transform.rotation
transform.anchor
transform.opacity
visual.crop
visual.mask
visual.blur.gaussian
visual.blur.motion
visual.color
style.text.*
style.shape.*
source.timeRemap
source.speed
effect.<effectId>.<property>
```

All channels must carry:

```text
units
value type
interpolation model
coordinate space
time domain
owner target
expression state
revision
```

## 5. CoreRuntimeEvaluator

The evaluator is the brain.

It must answer:

```text
What exactly is this node at this exact time?
```

Required API shape:

```text
evaluateCompositionAt(rootTime)
evaluateNodeAt(nodeId, rootTime)
evaluateEffectStackAt(nodeId, rootTime)
buildSamplingPlan(nodeId, rootTime, qualityMode)
```

Required outputs:

```text
CompositionFrameState
NodeFrameState
EffectStackFrameState
CoreSamplingPlan
```

`NodeFrameState` must include:

```text
rootTimeMs
localTimeMs
sourceTimeMs
nodeId
sourceId
visibility
transformMatrix3x3
position
scale
rotation
anchor
opacity
crop
mask
gaussianBlurSigmaPx
motionBlurSamplingPlan
style values
effect values
bounds
blendMode
zOrder
diagnostics
```

The evaluator must be deterministic. The same graph, time, and quality profile
must produce the same state.

## 6. Motion Blur As A Core Effect

Motion Blur must be a generic temporal transform effect. It must not know
whether it is attached to a transition, text, shape, image, or video layer.

It only needs:

```text
renderable node
source content
transform over time
shutter model
sample times
sample weights
render surface
```

Required model:

```text
CoreMotionBlurSamplingPlan
  enabled
  nodeId
  rootTimeMs
  shutterOpenTimeMs
  shutterCloseTimeMs
  sampleTimesMs[]
  sampleWeights[]
  sampleNodeStates[]
  sampleTransforms[]
  sampleSourceStates[]
  amount
  shutterAngleDegrees
  shutterPhaseDegrees
  sampleCount
  adaptiveSampleLimit
  qualityMode
```

Required behavior:

- Position velocity creates linear streaks.
- Rotation velocity creates arc/circular blur around anchor.
- Scale velocity creates zoom/radial blur around anchor.
- Combined transforms produce combined temporal blur.
- No movement produces no blur.
- Slow movement produces subtle blur.
- Fast movement produces longer streaks.

Required implementation concept:

```text
For output frame at time T:
  evaluator builds shutter interval.
  evaluator builds sample times.
  for each sample time:
    evaluate the same node through the same graph.
    render source content using the sample transform.
  alpha-aware accumulate weighted samples.
  output one final frame.
```

Forbidden:

- Gaussian Blur as Motion Blur.
- Directional blur as the only Motion Blur.
- View transform tricks as final Motion Blur.
- TextureView snapshot overlays.
- `MediaMetadataRetriever.getFrameAtTime` in live/playback Motion Blur.
- Track-B-only sampling when shutter crosses an A/B boundary.
- silent fallback when sample plan cannot be executed.

## 7. TrueFrameRenderBackend

The backend executes the graph. It does not decide the meaning of keyframes or
effects.

Required adapter surface:

```text
renderPreviewFrame(graph, compositionState, outputSurface)
renderLiveScrubFrame(graph, compositionState, outputSurface)
renderPlaybackFrame(graph, compositionState, outputSurface)
renderExportFrame(graph, compositionState, exportTarget)
```

Preview/live/playback/export can differ by:

```text
sample count
resolution
caching strategy
frame budget
quality profile
```

They cannot differ by:

```text
property values
time mapping
effect order
interpolation
source identity
blend order
fallback meaning
```

Required backend diagnostics:

```text
backendId
backendVersion
adapterMode
graphRevision
stateRevision
executionOwner
surfaceOwner
sourceFrameProvider
effectStackOrder
sampleCount
canRender
firstFrameReady
fallbackUsed
fallbackReason
checksumBefore
checksumAfter
checksumDelta
presentedFrameTimeMs
actualFps
droppedFrames
```

## 8. Stage5, Professional Surface, And Stage6 Roles

### 8.1 Stage5

Stage5 may remain:

- playback transport,
- live scrub host,
- preview host,
- surface presenter,
- fallback presenter,
- diagnostics source.

Stage5 must not remain the semantic owner of:

- scale,
- rotation,
- opacity,
- Gaussian Blur,
- Motion Blur,
- effect order,
- sampling,
- source A/B interpretation.

### 8.2 Professional Transition Surface

The professional transition surface becomes a backend adapter surface, not an
independent effect interpreter.

It must consume:

```text
MasterRenderGraph / TrueFrameExecutionGraph
CoreRuntimeEvaluator output
NodeFrameState / CompositionFrameState
CoreSamplingPlan
```

### 8.3 Stage6 Export

Stage6 export must not rebuild effect meaning from raw maps.

Correct export path:

```text
Stage6ExportManager
-> MasterRenderGraph / TrueFrameExecutionGraph
-> CoreRuntimeEvaluator
-> TrueFrameRenderBackend export adapter
-> Media3 / BMF / encoder path
```

Media3 remains a useful backbone for decode/encode and some effects. It is not
the authoring truth and not the whole execution engine.

## 9. Immediate Safety Slice

Before any deep backend migration, fix the current black/frozen frame risk.

Implement:

```text
STAGE5_ACTIVE
PREPARE_PROFESSIONAL_SURFACE
WAIT_FIRST_FRAME
PROFESSIONAL_ACTIVE
FALLBACK_TO_STAGE5
```

Rules:

- Do not hide Stage5 when Motion Blur is enabled.
- Hide Stage5 only after:

  ```text
  firstFrameReady == true
  canRenderFrame == true
  framePresented == true
  surfaceAttached == true
  ```

- If first frame times out, keep Stage5 visible.
- If backend cannot render, keep Stage5 visible.
- If fallback occurs, log the explicit reason.
- Never show a black frame.
- Never freeze the previous frame silently.

This is the first implementation checkpoint because it stops user-visible
regression while the real backend is built.

## 10. TRUEFRAME ONE As First Vertical Slice

`TRUEFRAME ONE` remains valid, but its meaning is refined:

```text
TRUEFRAME ONE = Manual Transition FX over TRUEFRAME CORE
```

The slice must prove the global architecture with:

- outgoing/incoming video nodes,
- transition node,
- transform channels,
- Gaussian Blur,
- Motion Blur,
- A/B boundary sampling,
- preview/live/playback surface handoff,
- export adapter readiness gates,
- renderer proof diagnostics.

It must not introduce permanent transition-only truth.

The first slice may use transition-specific wrappers for safety, but every new
wrapper must map to a core concept:

```text
ManualTransitionExecutionSlice -> CoreExecutionGraph specialization
TransitionFrameState           -> NodeFrameState / CompositionFrameState
MotionBlurSamplingPlan         -> CoreMotionBlurSamplingPlan
NativeTransitionRenderBackend  -> TrueFrameRenderBackend adapter
```

## 11. Implementation Phases

### Phase A - Documentation And Naming Realignment

Tasks:

- Update `TRUEFRAME ONE` to reference this core plan.
- Mark transition-specific names as first-slice aliases.
- Add guard wording that no transition-only engine may become permanent.

Checkpoint:

```text
checkpoint: generalize trueframe as core execution plan
```

### Phase B - Surface Handoff Safety

Tasks:

- Add first-frame-ready handoff state.
- Keep Stage5 visible until professional backend proves readiness.
- Add timeout fallback to Stage5.
- Add diagnostics.

Checkpoint:

```text
checkpoint: add trueframe surface handoff safety
```

### Phase C - Universal Target Resolution

Tasks:

- Ensure video, image, text, shape, transition roles, groups, and scene clips
  resolve to stable layer/node targets.
- Manual Transition outgoing/incoming/both must resolve to core nodes.
- No raw clip ID should be used as final render/effect target.

Checkpoint:

```text
checkpoint: add trueframe universal target resolver slice
```

### Phase D - Core Graph Slice

Tasks:

- Project Manual Transition into `MasterRenderGraph`/`TrueFrameExecutionGraph`
  without inventing a parallel truth.
- Include source nodes, transform nodes, effect nodes, blend/composite nodes, and
  output surface node.

Checkpoint:

```text
checkpoint: project manual transition into trueframe core graph
```

### Phase E - Core Runtime Evaluator Slice

Tasks:

- Evaluate outgoing/incoming node frame states at root time.
- Evaluate transform/effect values from `MasterFrameEvaluation`.
- Build generic motion blur sampling plans from node state over time.

Checkpoint:

```text
checkpoint: evaluate manual transition through trueframe core
```

### Phase F - Backend Adapter Slice

Tasks:

- Add `TrueFrameRenderBackend` contract.
- Route Manual Transition preview/live/playback through a backend adapter.
- Keep Stage5 as presenter/fallback, not semantic owner.

Checkpoint:

```text
checkpoint: add trueframe manual transition backend adapter
```

### Phase G - Core Motion Blur Slice

Tasks:

- Render Motion Blur from `CoreMotionBlurSamplingPlan`.
- Use temporal transform sampling.
- Prove position/scale/rotation/combined behavior.
- Avoid Gaussian, snapshot overlay, and `MediaMetadataRetriever` live loops.

Checkpoint:

```text
checkpoint: render core motion blur for manual transition
```

### Phase H - Export Adapter Slice

Tasks:

- Make Stage6 consume the same graph/evaluator state for Manual Transition.
- Use higher quality profile for export.
- Keep preview/export meaning identical.

Checkpoint:

```text
checkpoint: route manual transition export through trueframe core
```

### Phase I - Expand Beyond Transition

Only after Manual Transition proves the core path:

1. Video layer slice.
2. Image layer slice.
3. Shape layer slice.
4. Text layer slice.
5. Group/precomp slice.
6. Scene clip/generated scene slice.
7. Adjustment/effect-control slice.

Each slice must add no new engine. It adds a new node family to TRUEFRAME CORE.

Phase I progress:

- Phase I.A foundation is complete: projected core graph now expands explicit
  `videoLayer`, `imageLayer`, `textLayer`, and `shapeLayer` families (plus
  compatibility stubs for `groupPrecomp`, `sceneClipInstance`, and
  `adjustmentControl`) from existing master graph truth.
- Phase I.B runtime state is complete: `NodeFrameState` now carries
  `resolvedLayerFamilies` from the same core graph node set, so quality adapters
  consume one canonical layer-family truth at runtime.
- Phase I.C parity coverage is complete: projection/runtime tests now explicitly
  lock `groupPrecomp`, `sceneClipInstance`, and `adjustmentControl` family
  resolution (`test/trueframe_execution_graph_adapter_test.dart` and
  `test/trueframe_core_runtime_evaluator_test.dart`) so these families cannot
  silently regress while transition-focused slices continue.
- Phase I.D backend routing contract is complete: `TrueFrameRenderBackend` now
  exposes node-family routing (`routeNodeFamilies`) with explicit owners
  (`stage5Presenter`, `professionalCompositor`, `exportAdapter`, `blocked`),
  phase-I family support checks, and explicit blockers for unsupported families.
  Covered by `test/trueframe_render_backend_test.dart`.
- Phase I.E explicit family-hint propagation is complete: `MasterVisualSurface`
  now carries `coreLayerFamilyHint`, `MasterRenderGraphAdapter` projects it into
  graph node attributes, and `TrueFrameExecutionGraphAdapter` resolves
  group/scene-clip/adjustment families from this canonical hint only (legacy
  target-name fallback removed). Covered by
  `test/master_render_graph_adapter_test.dart`,
  `test/trueframe_execution_graph_adapter_test.dart`, and
  `test/trueframe_core_runtime_evaluator_test.dart`.
- Phase I.F screen/backend integration is complete for transition preview
  ownership routing: `FusionXCleanUiScreen` now routes professional surface
  decisions through `routeNodeFamilies(...)` with families derived from active
  transition visual kinds, instead of calling the transition-only route
  contract directly. Guarded by
  `test/universal_motion_engine_guard_test.dart`.
- Phase I.G backend API cleanup is complete: transition-only routing API has
  been removed from the public `TrueFrameRenderBackend` contract. Only the
  generalized `routeNodeFamilies(...)` API remains exposed, with internal
  transition ownership logic kept private to backend implementation and guarded
  by `test/universal_motion_engine_guard_test.dart`.

Checkpoint:

```text
checkpoint: expand trueframe core layer families beyond transition
```

## 12. Acceptance Criteria

TRUEFRAME CORE is credible only when:

- every visible object can resolve to a core node;
- every keyframe/effect value goes through master evaluation;
- every backend consumes the same graph/evaluator state;
- every Motion Blur sample comes from core time sampling;
- preview/live/playback/export differ by quality, not semantics;
- no renderer silently bypasses the core;
- no fallback is silent;
- every frame can report its execution owner and surface owner;
- legacy paths are blocked or removed after proof.

Manual Transition is complete only when:

- Rotation, Scale, Position, Gaussian Blur, and Motion Blur use core truth;
- A and B participate correctly across shutter windows;
- Stage5 does not black/freeze;
- live scrub and playback match;
- export uses the same meaning;
- diagnostics prove visible pixel/frame delta for Motion Blur.

## 13. Unified Work And Checkpoint Rules

This is the single workflow source for TRUEFRAME work. Slice documents may add
feature-specific validation scenarios, but they must not redefine checkpoint,
GitHub, install, or protected-file rules.

Do not update Codex skills or local skill files as part of TRUEFRAME work yet.
Skill updates are intentionally paused until TRUEFRAME CORE has a production
proof. If a new invariant is discovered, update the relevant repo documentation
and checkpoint it to GitHub instead.

Before every slice:

```bash
git status -sb
git rev-parse --short HEAD
```

The writer must read:

```text
sources/ui/fusionx-clean-ui-2/docs/professional_checkpoint_policy.md
sources/ui/fusionx-clean-ui-2/docs/professional_refusion_motion_keyframe_engine.md
sources/ui/fusionx-clean-ui-2/docs/trueframe_core_execution_engine_plan.md
```

If the slice is a vertical slice such as Manual Transition, also read the
slice-specific document.

Protected Stage5 / Live Scrub files may be edited only when the slice explicitly
requires handoff, surface ownership, host/presenter behavior, or parity
diagnostics. The work log and final report must state why the protected file was
touched.

After every completed slice:

```text
verify
-> stage only related files
-> commit focused checkpoint
-> push branch
-> install on connected wireless device when app/native/rendering behavior changed
-> report checkpoint date, branch, commit hash, verification, install result, and rollback command
```

Checkpoint commit format:

```text
checkpoint: <short phase result>
```

Each checkpoint report must include:

```text
date/time
branch
commit hash
commit message
files changed
verification performed
device install result, if applicable
known risks
rollback command
```

For native/rendering slices:

```bash
cd /Users/mx/Documents/ReFusionXx/sources/ui/fusionx-clean-ui-2
flutter test <targeted tests>
flutter build apk --debug
adb devices -l
adb mdns services
flutter install --debug -d <ip:port>
```

If `flutter install` hangs:

```bash
adb -s <ip:port> push build/app/outputs/flutter-apk/app-debug.apk /data/local/tmp/refusion-debug.apk
adb -s <ip:port> shell pm install -r -t --user 0 /data/local/tmp/refusion-debug.apk
```

Documentation-only updates do not require APK install.

GitHub push is mandatory after every completed build slice, including
documentation slices that define official implementation rules.

## 14. Writer Agent Rule

Do not build a transition engine.

Build TRUEFRAME CORE.

Use Manual Transition as the first proof slice.

If a proposed implementation cannot later support video/image/text/shape with
the same evaluator, same sampling plan, same effect order, and same proof
contract, reject it before coding.
