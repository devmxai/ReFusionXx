# Professional Universal Motion Engine Plan

Status: official writer-agent implementation plan  
Package: `com.refusion.app`  
Date: 2026-05-04  
Scope: Master Clock, Master Live Scrub, Master Timeline, all scoped timelines, text/image/shape/video layers, transitions, preview, playback, and export parity

Reference alignment:

- Adobe After Effects composition/layer/property/keyframe model
- Adobe After Effects keyframe interpolation and expression model
- Adobe After Effects SmartFX pre-render/render separation
- OpenTimelineIO timeline/time schema concepts
- Android Media3 playlist/preload/seek/effects/export concepts
- Remotion deterministic frame-based rendering concepts

## 0. Purpose

This plan defines the connected path for turning the current ReFusion motion
foundation into one universal professional engine.

The goal is not to patch Scale, Rotation, Live Scrub, Transition Timeline, Shape
Timeline, or Text Timeline one by one. The goal is to make every visible frame
come from one millisecond-accurate chain:

```text
TimelineClockCoordinator
-> MasterTimeSnapshot
-> MasterTimeDomainMapper
-> UniversalMotionGraph
-> MasterKeyframeValueEvaluator
-> MasterValueTruthRegistry
-> MasterFrameEvaluation
-> MasterVisualProgram
-> MasterRenderGraph
-> Renderer Adapter
-> Presentation Proof
```

Every timeline surface is a view into this engine. No timeline surface is
allowed to become its own animation engine.

## 1. Mandatory Reading

Before editing code under this plan, the writer agent must read:

1. `/Users/mx/.codex/skills/refusion-development-guardrails/SKILL.md`
2. `docs/professional_checkpoint_policy.md`
3. `docs/professional_refusion_motion_keyframe_engine.md`
4. `docs/master_clock_value_truth_foundation_plan.md`
5. `docs/master_live_scrub_professional_plan.md`
6. `docs/professional_canva_layer_unification_plan.md`
7. this file, `docs/professional_universal_motion_engine_plan.md`

Then run:

```bash
git status -sb
git rev-parse --short HEAD
```

Every completed slice must be verified, committed, pushed, and reported as a
focused checkpoint according to `docs/professional_checkpoint_policy.md`.

## 2. Current Diagnosis

The current foundation is real but not universal yet.

Known professional gaps that must be closed:

- `FusionXCleanUiScreen._masterFrameEvaluationForMode(...)` passes only
  `_manualMotionPropertyChannels` into `MasterFrameEvaluationReadAdapter`.
  Therefore the master evaluator is not yet reading every authored
  text/image/shape/video/transition channel.
- `_liveScrubVisualProgramForTransitionRuntimeBridge(...)` rebuilds a
  `MasterFrameEvaluation` with empty `evaluatedChannels` and empty `channels`
  for a non-manual transition bridge branch. This drops already-authored master
  channel values.
- `MasterLiveScrubProgramAdapter` currently maps only opacity, position, scale,
  rotation, and gaussianBlur into Live Scrub surfaces. Other authored
  text/image/shape/video/crop/mask/effect properties become unsupported
  diagnostics instead of renderer-parity values.
- `SceneLayerScopeTimelineAdapter` supports shape layers structurally, but
  shape tracks are still projected through text track/content kinds in parts of
  the UI projection. That is acceptable as a temporary visual compatibility
  layer, but it is not a final professional shape timeline contract.

These are symptoms of the same root issue:

```text
Some authored motion channels are still collected, evaluated, projected, or
rendered through local feature paths instead of one universal engine path.
```

## 3. Non-Negotiable Rules

- Do not create another clock.
- Do not create another keyframe evaluator.
- Do not create another value/unit registry.
- Do not calculate motion values inside renderer-specific code.
- Do not let preview, playback, Live Scrub, export, or transition rendering use
  different answers for the same time/property pair.
- Do not use UI slider values directly as renderer values.
- Do not use source media position as master time.
- Do not use `currentPosition` as proof that a frame is visually presented.
- Do not use thumbnails, boundary stills, poster frames, or transition-only
  fallbacks as professional render output.
- Do not hide unsupported properties by silently dropping them.
- Do not keep legacy/manual/transition bridges if they bypass
  `MasterFrameEvaluation`.
- Do not touch protected Stage5 / Live Scrub files unless the user explicitly
  approves that exact Live Scrub implementation slice.
- Do not ship hybrid execution where old and new engines both drive the same
  frame path.
- Do not leave dead code or dormant fallbacks connected to production routing.

If a feature cannot be represented in the universal chain, the feature is not
production-ready.

### 3.1 Legacy Decommissioning Mandate

This is a mandatory migration rule:

```text
Universal path adoption requires legacy path decommissioning.
```

Meaning:

- once a workflow is migrated to the universal engine, old execution links for
  that same workflow must be removed or hard-blocked in production;
- keeping both paths active as a silent fallback is not accepted;
- every migration slice must include explicit `legacy detach` evidence;
- every migration slice must include an `rg`-based check that old entry points
  are either deleted, blocked, or test-only.

Required migration evidence per slice:

- old entry points list
- action per entry point: `deleted`, `blocked`, or `kept for compatibility`
- reason for any compatibility keep
- tests proving the universal path is the active production owner
- rollback command for the slice

## 4. Architecture Target

### 4.1 Single Ownership Chain

```text
User input / playback transport / export sampler
-> TimelineClockCoordinator commit
-> immutable TimelineClockSnapshot
-> MasterTimeSnapshot
-> MasterTimeDomainMapper projections
-> UniversalMotionGraph channel selection
-> MasterKeyframeValueEvaluator
-> MasterValueTruthRegistry unit mapping
-> MasterFrameEvaluation
-> MasterVisualProgram
-> MasterRenderGraph
-> Preview / Live Scrub / Playback / Export adapter
-> RendererPresentationProof
```

### 4.1.1 Clock And Native Boundary Contract

The universal engine must carry forward the official Master Clock contract.

Required upstream owner:

```text
TimelineClockCoordinator
-> MasterClockNativeBridge
-> immutable clock snapshot
-> MasterTimeSnapshot
```

Required fields:

- `MasterClockPhase`
- `MasterClockAuthority`
- `MasterRenderMode`
- `MasterTimeScope`
- root time
- presentation time
- frame index
- commit frame number
- monotonic measurement metadata
- source revision

Rules:

- `TimelineClockCoordinator` is the only mutable editor time authority.
- `MasterClockNativeBridge` is the only approved screen/native clock boundary.
- native player sample time may update master time only through approved
  authority arbitration.
- raw native `currentPosition`, raw `seekTo`, or renderer-local sample clocks
  must not be used as evaluation truth.
- every clock write must declare phase, authority, and render mode.
- invalid phase/authority transitions must be rejected, not silently accepted.
- Live Scrub release and play-start handoff must use the last committed master
  time and matching source revision.

### 4.2 Timeline Surfaces Are Scopes

The app may have many timeline surfaces:

- Root Composition Timeline
- Scene Contents Timeline
- Scene Scope Timeline
- Layer Scope Timeline
- Transition Scope Timeline
- Text Timeline
- Shape Timeline
- Image Timeline
- Video Timeline
- Source Media Timeline
- Export Sampling Timeline

But these are all scopes and projections. They must not own separate clocks,
separate keyframe data, or separate renderer math.

Each timeline surface must answer:

```text
scope id
scope kind
root time range
local time range
target ids
visible channel ids
editable channel ids
time projection to/from root
```

## 5. Core Data Contracts

### 5.1 UniversalMotionGraph

Purpose: one project-level graph of all editable authored motion.

Required contents:

- stable project id
- root composition id
- scene clips
- source scenes
- layers
- elements
- effects
- masks
- transitions
- sources/assets
- channels
- keyframes
- interpolation/easing
- property assignments
- draw order
- diagnostics

Rule:

```text
All authored animation must enter this graph before it can preview, scrub,
playback, or export.
```

### 5.2 UniversalMotionTarget

Purpose: one stable target identity for every animated object.

Required target kinds:

- rootComposition
- sceneClipInstance
- sourceScene
- layer
- element
- effectInstance
- mask
- transition
- sourceMedia

Required identity fields:

- `targetId`
- `rootCompositionId`
- `sceneClipId`
- `sourceSceneId`
- `layerId`
- `elementId`
- `effectInstanceId`
- `transitionId`
- `sourceAssetId`

Unused identity fields must be null, not guessed.

### 5.2.1 Universal Target Resolver Contract

The target resolver must run before universal channel collection.

Purpose: prevent raw clips, transition bridge ids, or UI track ids from becoming
permanent animation targets.

Canonical video/image/text/shape target path:

```text
MotionLayerModel
-> MotionElementModel
-> MotionElementSourceBinding
-> MotionPropertyTarget
-> MotionPropertyChannelModel
```

Transition target policy:

- outgoing source must resolve to a stable layer/element/source target;
- incoming source must resolve to a stable layer/element/source target;
- transition-wide controls must resolve to a transition target;
- both-source controls must write explicit outgoing and incoming channels, not a
  hidden shared value.

Rules:

- raw timeline clip ids may be adapter inputs, not graph targets.
- ambiguous targets must produce blockers.
- missing layer/element/source ownership must produce blockers.
- target ids must survive rename, trim, scrub, playback, export, and import.
- target resolution must not create renderer-only targets.

### 5.3 UniversalTimelineScope

Purpose: one model for every timeline surface.

Required scope kinds:

- rootComposition
- sceneContents
- sourceScene
- layer
- transition
- text
- shape
- image
- video
- export

Required fields:

- `scopeId`
- `scopeKind`
- `rootStart`
- `rootEnd`
- `localStart`
- `localEnd`
- `frameRate`
- `rootToLocal`
- `localToRoot`
- `targetIds`
- `visibleChannelIds`
- `editableChannelIds`
- `diagnostics`

### 5.3.1 TimeDomain And TimeProjection Contract

Every scope must use explicit domain projection. A renderer or keyframe
operation may not infer local time by subtracting offsets inline.

Required time domains:

- rootComposition
- sceneClipInstance
- sourceScene
- layer
- element
- transition
- sourceMedia
- exportSample

Required projection fields:

- source domain
- target domain
- root time
- local time
- valid range
- source in/out
- playback rate
- transition progress when applicable
- projection policy
- diagnostics

Required policies:

- `rejectOutsideRange`
- `allowGapAsBlank`
- `clampForDisplayOnly`
- `transitionWindowOnly`
- `sourceMediaExact`

Rules:

- keyframe evaluation uses projected domain time.
- source media sampling uses source-media time.
- transition progress is derived from projected transition time.
- timeline gaps are blank visual regions, not stale frames.
- export sampling uses the same projection as preview/playback.
- a projection outside valid range must block or blank according to policy; it
  must not silently clamp into a visible stale frame.

### 5.3.2 Property Schema And Value Truth Contract

Every property must have a formal schema before renderer wiring.

Required schema fields:

- stable property id
- display path
- owner target kinds
- value kind
- dimensionality
- UI unit
- engine unit
- renderer unit
- default value
- static value policy
- interpolation support
- expression support
- coordinate space
- render-affecting flag
- supported render modes
- unsupported-mode blocker

Rules:

- UI values are never renderer values.
- renderer adapters must consume mapped renderer units from
  `MasterValueTruthRegistry`.
- unsupported properties must become blockers or diagnostics.
- compound properties such as position and scale must preserve component
  identity while supporting grouped editing.
- text style, text layout, shape geometry, crop, mask, image/video visual
  metadata, effects, and transition controls must be schema entries, not custom
  renderer fields.

### 5.3.3 Unified Keyframe Operation Contract

All keyframe authoring must go through shared identity-based operations.

Required operations:

- add keyframe
- move keyframe
- set keyframe value
- delete keyframe
- set interpolation
- apply Easy Ease
- grouped compound add/move/delete
- script/import lower into keyframes
- transition preset lower into keyframes

Rules:

- every keyframe has a stable id.
- operations target keyframe ids, not visual indexes.
- collisions at the same time are resolved deterministically.
- moving a grouped position/scale keyframe preserves sibling channels when the
  edit is semantically grouped.
- Layer Scope, Transition Scope, Scene Scope, scripts, imports, prompt patches,
  and inspector edits must share the same operation service.
- renderer adapters may not mutate keyframes.

### 5.3.4 Transaction And Undo Contract

Every authoring mutation must be a reversible transaction.

Required transaction coverage:

- add/move/delete keyframe
- value edit
- interpolation edit
- apply transition preset
- import scene program
- apply motion patch
- add/remove layer
- target resolver migration
- scope projection migration

Rules:

- each transaction records before/after graph revision.
- each transaction records affected targets and channels.
- undo/redo must restore graph, selection, and scope-local time where
  applicable.
- renderer state is derived after transaction commit; it is not transaction
  truth.

### 5.4 MasterVisualProgram

Purpose: one renderer-neutral visual instruction set for the evaluated frame.

Required frame data:

- `MasterTimeSnapshot`
- active scopes
- active scene clips
- active layer surfaces
- active source media samples
- evaluated transforms
- evaluated opacity
- evaluated crop/trim/mask data
- evaluated text style/layout values
- evaluated shape geometry/style values
- evaluated image/video visual values
- evaluated effects
- evaluated transition roles/windows
- draw order
- blockers
- diagnostics

Rule:

```text
MasterVisualProgram is the canonical renderer-neutral visual program.
VisualLayerProgram and LiveScrubVisualProgram are compatibility projections
until they are replaced or formally aliased.
```

Required surface node fields:

- target id
- layer id
- element id
- source binding
- root timeline range
- local timeline range
- source media range
- transform
- anchor/origin
- opacity
- crop
- mask
- text style/layout
- shape geometry/style
- effects
- transition role
- blend mode
- draw order
- blockers
- diagnostics

Rules:

- rotation origin and transform order must be explicit.
- text/image/shape/video surfaces must share the same transform contract.
- source media identity must travel with the visual surface.
- renderer-specific projections may drop capabilities only by reporting
  blockers; they may not silently ignore evaluated values.

### 5.4.1 MasterRenderGraph Contract

`MasterRenderGraph` is the renderer-facing dependency graph produced from
`MasterVisualProgram`.

Purpose: separate deterministic frame evaluation from render execution.

Required node families:

- source media sample
- nested scene/precomposition
- layer transform
- mask
- crop
- effect
- transition
- blend/composite
- color conversion
- output surface

Required fields:

- graph revision
- root time
- frame index
- render mode
- resolution
- color settings
- source dependencies
- cache keys
- blockers
- diagnostics

Rules:

- render graph construction must be deterministic for the same graph revision
  and time.
- render graph nodes declare needed inputs before render execution.
- nested composition caches are optimizations over editable truth, not separate
  scene state.
- preview, Live Scrub, playback, and export lower from the same graph.

### 5.5 RendererPresentationProof

Purpose: prove the renderer showed the requested master frame.

Required proof fields:

- requested root time
- requested frame index
- requested commit frame number
- requested media item id/source id
- request id
- source revision
- graph revision
- renderer capability state
- blocker list
- presented root time
- presented frame index
- presented commit frame number
- presented media item id/source id
- surface id
- presentation timestamp
- native presentation ack
- pixel/checksum proof when available
- Live Scrub parity state
- playback parity state
- export parity state
- latency budget state
- match/mismatch reason
- renderer mode

Playback, Live Scrub, preview, and export may not claim parity unless they can
prove the presented frame matches the requested master frame.

Rules:

- `currentPosition` is not presentation proof.
- accepting an upload is not presentation proof.
- a proof surface is not a production surface.
- stale commit frame number or stale media item id blocks parity.
- proof logs must make source flashes and delayed frames diagnosable.

### 5.6 Expression And Deterministic Evaluation Contract

Expression support must be deterministic before it becomes production renderer
truth.

Required model:

```text
Expression DAG
-> dependency ordering
-> cycle detection
-> deterministic evaluation
-> property value snapshot
```

Rules:

- expressions are pure functions of scene snapshot, property path, time, and
  seed.
- expressions may sample `valueAtTime` only through the same evaluator.
- randomness must be seeded by graph revision/target/property/time policy.
- expressions must declare dependencies or be sandboxed into explicit blockers.
- wall-clock time must not drive preview, scrub, playback, or export motion.

### 5.7 Cache And Revision Contract

Caching is mandatory for performance, but cache must never become truth.

Required revisions:

- motion graph revision
- channel collection revision
- scope projection revision
- source media revision
- render graph revision
- renderer capability revision

Required cache keys:

- graph revision
- source asset id
- source media time
- seek tolerance
- root time/frame index
- render mode
- resolution
- color settings
- effect settings

Rules:

- hot Live Scrub must not rebuild the full graph per pointer pixel.
- cache invalidation must follow graph/source revision changes.
- active scrub may coalesce requests and chase the latest target.
- release/play/export exactness must evaluate the requested master frame, not
  the nearest cached frame unless policy explicitly allows it and reports it.

## 6. Millisecond Accuracy Contract

Time truth:

- `TimelineTime` remains canonical.
- The project timescale remains microseconds.
- Frame index is derived from root time and frame rate.
- Local time is always projected from root time through a scope mapper.
- Keyframe evaluation always uses projected domain time.
- Renderer output always reports the master frame it presented.

Accuracy rules:

- A keyframe at 1.000 seconds must evaluate at exactly 1.000 seconds in its
  declared domain.
- A keyframe at 4.000 seconds must not affect 3.999 seconds unless
  interpolation mathematically requires it.
- Playback start after scrub must begin from the last committed master time,
  not from an old native sample or stale source item.
- Releasing Live Scrub must not change the presented frame unless a new master
  commit explicitly requests a new frame.
- Switching from Track A to Track B must be a source/sample decision inside the
  same master frame, not a clock handoff.
- Transition windows must be evaluated as real root/local time ranges, not as
  seam-only shortcuts.

Permitted tolerance:

- Domain model tests: exact `TimelineTime` equality.
- Renderer proof tests: zero frame mismatch for deterministic test assets.
- Device/performance traces: no stale source frame after scrub/play handoff;
  any mismatch must be diagnosed by proof metadata and treated as a blocker.

## 7. Implementation Phases

### Phase 0 - Audit And Freeze Existing Paths

Goal: identify every time writer, channel collector, evaluator, visual program,
and renderer consumer before changing behavior.

Tasks:

- inventory all reads/writes of `_manualMotionPropertyChannels`;
- inventory all calls to `MasterFrameEvaluationReadAdapter.evaluate`;
- inventory all direct construction of `MasterFrameEvaluation`;
- inventory all `LiveScrubVisualProgram` builders;
- inventory all timeline scope projection adapters;
- inventory all renderer paths that read slider/UI values directly;
- add guard docs or allowlists for legacy paths that must be removed later.

Verification:

- docs/inventory update;
- `rg` proves each known path is accounted for.

Exit gate:

- every old path is labeled as canonical, adapter, compatibility, or removal
  candidate.
- no implementation of Phase 1 may begin unless this inventory exists and is
  linked from this plan.
- migration cannot proceed until each workflow has a legacy-detach plan.

### Phase 1 - Universal Channel Collection

Goal: stop feeding the master evaluator with manual-only channels.

Add a domain/presentation adapter such as:

```text
UniversalMotionChannelCollector
```

Prerequisite:

```text
UniversalTargetResolver
-> UniversalMotionChannelCollector
```

It must collect channels from:

- manual transition lanes;
- scene layer scope edits;
- text channels;
- image channels;
- shape channels;
- video channels;
- scene program imports;
- mention motion patches;
- normal transition graph bundles;
- scene clip instance channels;
- future root background layer channels.

Rules:

- collection must accept only canonical resolved targets;
- collection must preserve channel identity;
- collection must not duplicate same channel id;
- collection must not mutate channel data;
- collection must report unsupported/missing ownership diagnostics.

Implementation target:

- replace direct `_manualMotionPropertyChannels` reads at master evaluation
  entry points with collected universal channels;
- keep `_manualMotionPropertyChannels` only as a source collection until it can
  be renamed or absorbed.

Verification:

- unit tests prove text/image/shape/video/manual transition channels all reach
  `MasterFrameEvaluationReadAdapter`;
- regression test proves manual transition Scale/Rotation still evaluates.

Exit gate:

- no production master evaluation path is manual-only.

### Phase 2 - Universal Timeline Scope Model

Goal: every timeline surface becomes a `UniversalTimelineScope` projection.

Tasks:

- introduce or formalize a scope model that covers root, scene, layer,
  transition, text, shape, image, video, and export;
- route scope-local time conversion through one mapper;
- keep TimelinePanel as a UI projection, not as timing truth;
- make Shape track/content identity explicit where the UI model supports it;
- keep temporary visual compatibility only with diagnostics.

Verification:

- tests for root-to-local and local-to-root mapping for each scope kind;
- tests for shape/image/video/text target identity preservation;
- tests for transition-local time around A/B windows.

Exit gate:

- no keyframe operation calculates local time without a scope mapper.

### Phase 3 - MasterFrameEvaluation Becomes Universal

Goal: `MasterFrameEvaluation` reads all authored project channels and all active
targets for the requested master time.

Tasks:

- extend `MasterFrameEvaluationReadAdapter` or add a universal facade above it;
- include scene clip instance style channels and source scene/layer channels;
- include transition channels without rebuilding empty evaluations;
- carry active transition ids and active surface ownership from the same
  evaluation;
- preserve diagnostics for channels outside visible scopes;
- remove direct ad-hoc `MasterFrameEvaluation(...)` construction in runtime
  bridges unless it is a pure copy with evaluated values preserved.

Required fix:

```text
Non-manual transition runtime bridge must not pass empty evaluatedChannels or
empty channels when evaluated channel data exists.
```

Verification:

- tests prove evaluated channel parity for text/image/shape/video/manual
  transition/normal transition at the same root time;
- tests prove bridge paths preserve evaluated channels;
- tests prove unsupported channels create blockers instead of disappearing.

Exit gate:

- a single master evaluation can explain the frame for preview, Live Scrub,
  playback, and export.

### Phase 4 - MasterVisualProgram

Goal: replace mode-specific partial visual programs with a renderer-neutral
visual program.

Tasks:

- introduce `MasterVisualProgram` in domain or presentation services;
- reconcile `MasterVisualProgram` with the existing `VisualLayerProgram`
  contract before adding another renderer-facing model;
- map every evaluated target to a visual surface/program node;
- include source media binding, transform, opacity, crop, mask, text, shape,
  image, video, effects, transition roles, and draw order;
- make `LiveScrubVisualProgram` a projection from `MasterVisualProgram`;
- make unsupported property handling explicit and testable;
- prevent renderer adapters from inventing missing values.

Verification:

- adapter tests for all supported property families;
- unsupported property tests with deterministic blockers;
- rotation and scale tests prove center-origin transform semantics survive the
  visual program.

Exit gate:

- Live Scrub, preview, playback, and export consume the same evaluated visual
  program data, even if their renderer capabilities differ.

### Phase 5 - Renderer Adapters With Presentation Proof

Goal: each renderer consumes `MasterVisualProgram` and reports proof.

Renderer adapters:

- Preview adapter
- Live Scrub adapter
- Playback adapter
- Export adapter

Each adapter must:

- accept a `MasterVisualProgram`;
- lower through `MasterRenderGraph` where rendering requires dependency
  planning;
- bind source media by stable asset/source id;
- bind transform/effect values in renderer units;
- render or block explicitly;
- report `RendererPresentationProof`;
- reject stale source frames;
- reject stale commit frame numbers;
- reject mismatched media item presentation.

Live Scrub boundary:

- Stage5 remains the protected hot path;
- the adapter feeds Stage5 with master-evaluated frame/program data;
- protected Stage5 internals are edited only in explicitly approved slices.

Verification:

- deterministic test asset for Track A -> Track B;
- play after scrub on Track A must not flash Track B;
- play after scrub on Track B must not flash Track A;
- release after Live Scrub must retain the same frame;
- playback across A/B seam must not require a clock reset;
- proof logs must identify any mismatch source.

Exit gate:

- renderer mismatch is impossible to hide because proof blocks it.

### Phase 6 - Remove Legacy Bypass Paths

Goal: delete or permanently gate old paths that bypass the master engine.

Removal candidates:

- manual-only master evaluation inputs;
- transition bridge evaluations with empty channel lists;
- renderer-side effect/value calculation;
- seam-only transition progress shortcuts;
- UI-only animate values;
- direct slider-to-renderer bindings;
- private timeline/local time calculations;
- duplicate text/shape/image/video effect evaluators.

Rules:

- delete only after tests prove the universal path covers the behavior;
- do not delete protected Live Scrub internals casually;
- if a compatibility path must remain, it must emit a blocker/diagnostic when
  used in production.
- compatibility keep is temporary and must include a removal trigger in docs.
- no Phase 7 parity claim is valid while duplicated active routing exists for
  the same workflow.

Verification:

- `rg` checks for removed bypass signatures;
- tests prove no known user workflow depends on a bypass.

Exit gate:

- no production visible frame can bypass `MasterFrameEvaluation`.
- no production workflow can execute through both old and universal engines for
  the same frame request.

### Phase 7 - Professional Parity Matrix

Goal: prove After Effects-style timing/value parity across authoring modes.

Required workflows:

- one video layer with Scale keyframes;
- one video layer with Rotation keyframes;
- Track A + Track B without transition;
- Track A + Track B with manual transition;
- Track A + Track B with normal transition;
- image layer transform animation;
- text layer transform/style animation;
- shape layer transform/geometry/style animation;
- scene clip instance transform animation;
- nested scene scope layer animation;
- scrub forward/backward across source boundary;
- scrub, release, then play;
- play, pause, scrub, play again;
- export sample at the same frame.
- expression-driven property at a fixed frame.
- nested scene/precomposition sample at a fixed frame.
- crop/mask/effect sample at a fixed frame.

Each workflow must compare:

- root time;
- scope-local time;
- active source id;
- evaluated keyframe values;
- visual program values;
- render graph node values;
- renderer proof frame;
- output surface identity.

Exit gate:

- preview, Live Scrub, playback, and export explain the same frame through the
  same master chain.

## 8. Performance Contract

The universal engine must be accurate and fast.

Rules:

- hot scrub must not rebuild the full project graph per pointer pixel;
- channel collection must be revision-cached;
- scope projections must be immutable and cacheable;
- keyframe evaluation should be bounded by active/visible channels;
- renderer adapters should receive compact frame programs;
- diagnostics must be rate-limited in hot paths;
- native/media source rebinding must be avoided during active scrub unless the
  source truly changes.
- graph revision, source revision, and render graph revision must be part of
  cache invalidation.
- active scrub may use chase/coalescing behavior, but release/play/export must
  evaluate the exact requested master frame.

Targets:

- no visible stale frame after scrub release;
- no visible source flash at play start;
- no renderer jump before playback starts;
- no A/B seam pause caused by a clock reset;
- no unsupported property silently dropped;
- no frame output without presentation proof in professional modes.

## 9. Writer-Agent Execution Rules

The writer agent must work in small slices:

1. domain model/service;
2. unit tests;
3. adapter layer;
4. UI wiring;
5. renderer bridge;
6. native/protected path only when explicitly approved.

Each slice must answer:

- Which old path is being removed or bypassed less?
- Which master contract is being strengthened?
- Which tests prove time/value correctness?
- Does this touch protected Live Scrub files?
- Does this require APK install?
- What is the rollback command?

Do not combine unrelated fixes in one checkpoint.

## 10. Definition Of Done

This plan is complete only when:

- every authored text/image/shape/video/transition/scene property is represented
  as a universal motion channel or explicit non-animatable property;
- every keyframe operation writes into the same graph model;
- every timeline surface is a scope projection;
- every frame evaluation uses master time and projected domain time;
- every renderer consumes `MasterVisualProgram` or a tested projection from it;
- every renderer reports presentation proof;
- preview, Live Scrub, playback, and export agree on the same source frame and
  same evaluated property values;
- legacy bypass paths are deleted or blocked;
- legacy links are detached workflow-by-workflow with documented evidence;
- all unsupported properties are visible diagnostics, not silent omissions;
- A/B playback, scrub, transition, and export behave as one continuous timeline
  with no stale frame, no source flash, no lag from clock handoff, and no hidden
  fallback.

## 11. First Recommended Implementation Slice

Start with Phase 0 unless a current universal inventory document already exists
and is linked from this plan.

Expected first checkpoint:

```text
checkpoint: inventory universal motion engine paths
```

Minimum Phase 0 output:

- inventory of all time writers and native clock boundaries;
- inventory of all channel sources and graph buckets;
- inventory of all target id forms and raw clip id uses;
- inventory of all keyframe operation entry points;
- inventory of all renderer/effect/value consumers;
- inventory of all Live Scrub, playback, preview, and export presentation proof
  paths;
- classification of every path as canonical, adapter, compatibility, or
  removal candidate.

Only after Phase 0 passes, continue with Phase 1.

Build `UniversalMotionChannelCollector` and route
`_masterFrameEvaluationForMode(...)` through it. This is the smallest slice that
directly addresses the current P1 finding without touching protected Live Scrub
internals.

Expected checkpoint:

```text
checkpoint: collect universal motion channels for master evaluation
```

Minimum tests:

- collector includes manual transition channels;
- collector includes scene layer scope text/image/shape/video channels;
- master evaluation receives collected channels;
- duplicate channel ids are de-duplicated deterministically;
- unsupported ownership is reported as diagnostics.

Do not start renderer work until this slice is complete.
