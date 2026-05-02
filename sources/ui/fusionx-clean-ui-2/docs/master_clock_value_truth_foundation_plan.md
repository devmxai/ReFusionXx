# Master Clock & Value Truth Foundation Plan

Status: official implementation plan for the writer agent  
Intended writer: `gpt-5.3-codex` with `medium` reasoning for narrow slices, `high`
reasoning for broad time/value mapping slices  
Package: `com.refusion.app`  
Date: 2026-05-02  

This plan is the required foundation before the Master Live Scrub Engine can be
implemented. It does not build a renderer. It defines the single source of truth
for time, frame identity, scope-local projections, effect values, and renderer
values.

## 0. Writer Operating Contract

The writer must follow this contract literally.

Before editing code, read:

1. `/Users/mx/.codex/skills/refusion-development-guardrails/SKILL.md`
2. `docs/professional_checkpoint_policy.md`
3. `docs/professional_refusion_motion_keyframe_engine.md`
4. `docs/master_live_scrub_engine_plan.md`
5. this file, `docs/master_clock_value_truth_foundation_plan.md`

Then run:

```bash
git status -sb
git rev-parse --short HEAD
```

Do not touch protected Stage5 / Live Scrub native files in this foundation:

- `Stage5TimelineScrubPlatformView`
- `Stage5NativeScrubEngine`
- `Stage5SurfaceScrubDecoder`
- `Stage5ScrubOverlayTextureView`
- `Stage5PreviewPlatformView`
- Flutter Live Scrub handoff paths

This foundation may inspect those files for understanding, but must not edit
them. If an implementation step appears to require those files, stop and report
the exact dependency.

After each completed slice:

1. update relevant app docs;
2. update `/Users/mx/Documents/refusion-skills` if the rule affects agents;
3. run the smallest relevant verification;
4. commit and push the app repo checkpoint;
5. commit and push the skills repo checkpoint when changed;
6. install APK only when the slice changes runnable app code and a device is
   connected;
7. report rollback commands for every repo that changed.

Ignore unrelated untracked `../../../.claude/`.

## 1. Diagnosis

ReFusion currently has useful pieces of a professional timing system, but they
are not yet enforced as one master truth.

Existing correct foundations:

- `TimelineTime` already stores project ticks at a microsecond timescale
  (`TimelineTime.projectTimescale = 1000000`).
- `TimelineClockCoordinator` already coordinates timeline display/playback
  behavior in parts of the Flutter editor, with phase, authority, revision, and
  evaluation-time concepts. It is the clock foundation to lift, not a class to
  replace or delete.
- Motion graph channels already store real keyframe data for many layer and
  transition properties.
- Scene Scope and Scene Layer Scope already require root-to-local and
  local-to-root projection adapters.

The problem is that not every feature is forced through one time/value contract.
Some paths still use:

- root timeline time directly;
- scene-local time directly;
- layer-local time directly;
- transition progress computed beside the graph;
- source media time computed beside the graph;
- playback sample notifiers as local preview time;
- MethodChannel timeline time for native transition renderers;
- UI slider values that are not formally tied to engine/render units.

This creates different answers to the same questions:

```text
What frame is the app showing?
Which keyframe value owns this frame?
Is this time root, scene, layer, transition, or source media time?
Does 100% scale mean normal, double size, or UI delta?
Does blur 20 mean pixels, sigma, intensity, or percent?
```

Professional systems such as After Effects avoid this by separating domains and
making every displayed value a projection from one canonical model:

```text
master time snapshot
-> domain projection
-> keyframe evaluation
-> property definition/unit mapping
-> frame evaluation snapshot
-> renderer/export consumer
```

This foundation builds that model.

## 2. One Principle

Every preview, playback, scrub, transition, effect, keyframe, inspector value,
and export sample must be explainable as:

```text
MasterTimeSnapshot
-> TimeDomainMapper
-> KeyframeEvaluator
-> ValueTruthRegistry
-> MasterFrameEvaluation
```

Any renderer, overlay, effect, or editor control that cannot explain its time
and values through this chain is not production-ready.

## 3. Non-Goals

This plan must not implement:

- GPU composition;
- Media3 `GlEffect`;
- Stage5 decoder changes;
- Stage5 native scrub changes;
- transition pixel rendering;
- removal of `ProfessionalVideoTransitionCompositorManager`;
- UI redesign;
- export renderer parity.

This plan only creates domain models, mappers, registries, adapters, tests, and
documentation that make later renderer work safe.

## 4. Canonical Time Model

Use the existing `TimelineTime` as the canonical time scalar. It already stores
microsecond project ticks and supports exact rescaling.

Use the existing `TimelineClockCoordinator` as the authoritative mutable owner
of editor time. Add master-time models as immutable projections or wrappers
around its snapshot. Do not create a second coordinator, second preview clock,
or second notifier that can advance time independently.

The implementation may extend `TimelineClockSnapshot` directly or introduce a
`MasterTimeSnapshot` wrapper, but it must preserve this ownership rule:

```text
TimelineClockCoordinator
-> immutable clock snapshot
-> time-domain projection
-> value/keyframe evaluation
```

Required model:

```text
MasterTimeSnapshot
  rootTime: TimelineTime
  presentationTime: TimelineTime
  frameIndex: int
  frameRate: double
  commitFrameNumber: int
  monotonicTimeUs: int
  phase: MasterClockPhase
  authority: MasterClockAuthority
  renderMode: MasterRenderMode
  sourceScope: MasterTimeScope
```

Field meaning:

- `rootTime` is the canonical timeline/playhead time.
- `presentationTime` is the displayed/evaluation time. It equals `rootTime` by
  default and may differ only under an explicit settle/seek policy.
- `frameIndex` is derived from `rootTime` and `frameRate`.
- `commitFrameNumber` is a monotonic commit counter for snapshot ordering. It is
  not the same as `frameIndex`.
- `monotonicTimeUs` is wall-clock measurement metadata only. It must not drive
  rendering or keyframe evaluation.

Required enums:

```text
MasterClockPhase
  idle
  paused
  scrubbing
  scrubSettling
  playStarting
  playing
  pausing
  seeking
  zooming
  structuralEditing
  exporting (future phase; do not add in first slice unless already needed)

MasterClockAuthority
  none
  user
  nativeTransport
  geometry
  structuralEdit
  export (future authority)
  test (test-only authority)

MasterRenderMode
  preview
  playback
  liveScrub
  settle
  export
  test

MasterTimeScope
  rootComposition
  sourceComposition
  scene
  layer
  transition
  sourceMedia
```

Rules:

- `rootTime` is the only global playhead truth.
- one clock only; any independent preview/playback/scrub clock is a bug.
- snapshots are immutable; all mutation must pass through one commit path.
- `frameIndex` is derived from `rootTime` and `frameRate`, not stored by UI.
- `commitFrameNumber` increments on accepted commits only.
- `phase` describes what the user/system is doing.
- `authority` describes who is allowed to advance the clock.
- `renderMode` describes why the frame is requested.
- `sourceScope` identifies which projection produced the snapshot.
- `_displayTimeNotifier`, `_playbackSampleTimeNotifier`, and equivalent UI
  listenables may remain only as derived views. They must not become source
  clocks.
- `DateTime.now()` and `Stopwatch` may be used for measurement/diagnostics only,
  never as render/evaluation time.
- native player sample time may enter Flutter only through an explicit native
  transport bridge/adapter. Do not read native player position from arbitrary
  editor code.

Hardening requirements:

- define allowed phase transitions in one table or equivalent tested policy;
- reject invalid phase transitions instead of silently accepting them;
- define authority arbitration in one policy;
- reject writes from the wrong authority for the current phase;
- keep `TimelineClockCoordinator` API compatible during early phases;
- do not touch Stage5 native scrub internals in this foundation.

Acceptance tests:

- frame index is deterministic for 24, 30, 60 fps;
- the same `TimelineTime` with the same fps always maps to the same frame index;
- `presentationTime` equals `rootTime` by default;
- `commitFrameNumber` increments only when a commit changes the snapshot;
- negative/non-finite frame rate is rejected or normalized by policy;
- invalid phase transitions are rejected;
- disallowed authority writes are rejected;
- phase/authority/renderMode can be serialized for diagnostics.

## 5. Time Domains

Time domains must be explicit. Do not pass a raw `TimelineTime` into a renderer
or evaluator without knowing its domain.

Required domain types:

```text
TimeDomain.root
TimeDomain.composition(compositionId)
TimeDomain.scene(sourceSceneId)
TimeDomain.layer(layerId)
TimeDomain.transition(transitionId)
TimeDomain.sourceMedia(assetId or sourceUri)
```

Required projection record:

```text
TimeProjection
  fromDomain
  toDomain
  inputTime
  outputTime
  validRange
  policy
  reason
```

Required projection policies:

```text
strict
clamp
rejectOutsideRange
allowGapAsBlank
sourceRateAdjusted
transitionProgress
```

Required mappers:

```text
root -> scene
scene -> root
scene -> layer
layer -> scene
root/scene -> transition
root/scene -> sourceMedia
time -> frameIndex
frameIndex -> time
```

Rules:

- A Scene Contents timeline may edit a wide authoring range, but a transition
  render domain is only the actual seam window.
- Source media time is never equal to timeline placement time unless a mapper
  proves it.
- Gaps in a composition are valid blank visual time, not permission to replay
  the previous source frame.
- Transition progress is a projection output, not an independent clock.

Acceptance tests:

- root Scene Clip time maps to source scene local time;
- scene video layer time maps to source media time;
- transition window maps to normalized `0.0..1.0`;
- time outside transition window is rejected, not clamped into a frozen boundary
  frame;
- authored gaps return a blank/invalid projection according to policy.

## 6. Value Truth Model

Every editable property must have a formal definition before it can be claimed
as supported.

Required model:

```text
PropertyDefinition
  id
  category
  valueType
  uiUnit
  engineUnit
  rendererUnit
  defaultValue
  minValue
  maxValue
  displayMapping
  engineMapping
  rendererMapping
  supportedTargets
  supportedRenderModes
  unsupportedCases
```

Required value types:

```text
scalar
percent
signedPercent
dimension
point2D
scale2D
degrees
radians
color
boolean
enum
string
```

Required units:

```text
percentUi
signedPercentUi
normalized01
multiplier
canvasPx
sourcePx
devicePx
degrees
radians
shaderSigmaPx
milliseconds
timelineTicks
colorArgb
enumToken
stringToken
```

Rules:

- UI value and renderer value are different layers.
- A slider writes a UI value only through a `PropertyDefinition`.
- Engine values must be deterministic and serializable.
- Renderer mappings must clamp and normalize explicitly.
- Unsupported renderer modes must be explicit, not silently ignored.

Baseline property definitions required in the first implementation slice:

```text
opacity
scale
position
rotation
gaussianBlur
motionBlurAmount
tileOutputScale
```

Required mappings:

```text
opacity
  UI: 0..100 percent
  engine: 0.0..1.0 normalized
  renderer: 0.0..1.0 alpha

scale
  UI: signed percent where 0 means normal, +100 means 2x, -50 means 0.5x
  engine: multiplier clamped above zero
  renderer: transform matrix scale

position
  UI: canvas pixels from composition center/origin policy already used by app
  engine: canvas-space point
  renderer: normalized/device transform decided by renderer adapter

rotation
  UI: degrees
  engine: degrees
  renderer: radians or matrix

gaussianBlur
  UI: pixels/intensity label must resolve to pixels
  engine: blur radius in canvas pixels
  renderer: shader sigma pixels

motionBlurAmount
  UI: percent/intensity
  engine: shutter or sample policy token
  renderer: temporal sampling/shader policy

tileOutputScale
  UI: multiplier
  engine: multiplier
  renderer: mirror-edge overscan multiplier
```

Acceptance tests:

- opacity `100%` maps to `1.0`;
- opacity `0%` maps to `0.0`;
- scale `0%` maps to `1.0`;
- scale `+100%` maps to `2.0`;
- scale `-50%` maps to `0.5`;
- rotation `180deg` maps to pi radians when renderer mapping is requested;
- gaussian blur rejects negative values and maps to stable sigma;
- unsupported enum/string/color keyframe values remain unsupported until their
  definitions exist.

## 7. Keyframe Evaluation Contract

All keyframes must be evaluated through one contract.

Required service shape:

```text
MasterKeyframeEvaluationRequest
  channelId
  propertyDefinitionId
  time: MasterTimeSnapshot
  domainProjection: TimeProjection

MasterKeyframeEvaluationResult
  status
  rawValue
  uiValue
  engineValue
  rendererValue
  interpolation
  reason
```

Rules:

- Channels store authored values.
- Property definitions convert authored values into engine/renderer values.
- Paired properties such as Position and Scale may be edited together, but they
  still evaluate as real channel values.
- Transition-local keyframes evaluate against transition progress/domain, not
  root time directly.
- Missing channels return defaults only when the property definition permits a
  default.

Acceptance tests:

- scalar linear interpolation is stable;
- hold interpolation is stable;
- paired scale X/Y values evaluate independently but can share the same time;
- transition-local scale keyframes evaluate at progress `0.0`, `0.5`, `1.0`;
- keyframes outside the owning layer/transition range are rejected by policy.

## 8. Master Frame Evaluation Snapshot

The final product of this foundation is not a rendered frame. It is a structured
truth snapshot for one requested frame.

Required model:

```text
MasterFrameEvaluation
  time: MasterTimeSnapshot
  projections: List<TimeProjection>
  visibleLayerIds
  activeTransitionIds
  evaluatedChannels
  effectParameters
  diagnostics
```

Required channel/effect record:

```text
EvaluatedPropertyValue
  targetId
  propertyDefinitionId
  domain
  uiValue
  engineValue
  rendererValue
  unit
  sourceChannelId
  status
```

Rules:

- Preview, Live Scrub, playback, and export will eventually consume this same
  snapshot.
- This first foundation does not need to wire every current renderer to the
  snapshot. It must make the snapshot model and tests real.
- No renderer-specific side effect belongs in `MasterFrameEvaluation`.

Acceptance tests:

- a simple layer with opacity and scale produces two evaluated values;
- a transition window produces active transition diagnostics only inside the
  seam window;
- a scene-local layer produces both root and scene projections;
- values include UI, engine, and renderer units.

## 9. Suggested Files For The Writer

The writer should prefer new domain/presentation-adapter files rather than
editing large UI files.

Suggested new app files:

```text
lib/features/editor/domain/models/master_time_models.dart
lib/features/editor/domain/services/master_time_domain_mapper.dart
lib/features/editor/domain/models/master_value_truth_models.dart
lib/features/editor/domain/services/master_value_truth_registry.dart
lib/features/editor/domain/services/master_keyframe_value_evaluator.dart
lib/features/editor/domain/models/master_frame_evaluation_models.dart
```

Suggested tests:

```text
test/master_time_domain_mapper_test.dart
test/master_value_truth_registry_test.dart
test/master_keyframe_value_evaluator_test.dart
test/master_frame_evaluation_models_test.dart
```

Do not edit in the first slice unless unavoidable:

```text
lib/features/editor/presentation/screens/fusionx_clean_ui_screen.dart
android/app/src/main/kotlin/com/fusionx/fusionx_clean_ui_2/*
```

The first implementation slice should be domain-only. UI/native wiring comes
later.

## 10. Phased Implementation Plan

### Phase 0 - Inventory Only

Goal: identify current time and value sources.

Deliverables:

- `docs/master_clock_value_truth_inventory.md`
- list of time readers;
- list of current uses of `_displayTimeNotifier`;
- list of current uses of `_playbackSampleTimeNotifier`;
- list of current uses of `DateTime.now()` and `Stopwatch`;
- list of native player position readers and MethodChannel time arguments;
- list of value mappings;
- list of keyframe evaluators;
- list of transition progress calculators;
- list of source media time mappers;
- list of UI controls that write values.

No code behavior changes.

Verification:

```bash
rg "_displayTimeNotifier|_playbackSampleTimeNotifier|_currentTime|TimelineTime|playbackSample|timelineDisplay|progress|parameterValue|manualLaneValueAtProgress|DateTime\\.now\\(|Stopwatch\\(" lib test
rg "currentPosition|positionMs" android/app/src/main/kotlin/com/fusionx/fusionx_clean_ui_2
```

### Phase 1 - Time Models And Mapper

Goal: lift the existing `TimelineClockCoordinator` into the master-clock
foundation, add `MasterTimeSnapshot` or an equivalent immutable projection, add
time domain types, and add deterministic mappers.

Allowed changes:

- targeted extensions to `TimelineClockSnapshot` / `TimelineClockCoordinator`
  when they are strictly domain-level and keep the existing API compatible;
- new model/service files;
- new tests;
- docs update;
- skills update.

Forbidden changes:

- no Stage5 files;
- no renderer files;
- no UI preview logic;
- no transition compositor changes;
- no native bridge implementation yet;
- no migration of `_displayTimeNotifier` / `_playbackSampleTimeNotifier` yet.

Verification:

```bash
flutter test test/timeline_clock_coordinator_test.dart
flutter test test/master_time_domain_mapper_test.dart
flutter analyze
```

### Phase 2 - Value Truth Registry

Goal: add formal property definitions and baseline mappings.

Allowed baseline properties:

- opacity;
- scale;
- position;
- rotation;
- gaussianBlur;
- motionBlurAmount;
- tileOutputScale.

Verification:

```bash
flutter test test/master_value_truth_registry_test.dart
flutter analyze
```

### Phase 3 - Keyframe Evaluation Contract

Goal: route scalar/paired/transition-local authored values through the value
truth registry.

Allowed behavior:

- domain service tests only;
- adapters may consume existing `MotionPropertyChannelModel` only if needed and
  without changing UI behavior.

Verification:

```bash
flutter test test/master_keyframe_value_evaluator_test.dart
flutter analyze
```

### Phase 4 - Frame Evaluation Snapshot

Goal: build structured `MasterFrameEvaluation` from a time snapshot, projections,
and evaluated values.

No renderer consumption yet.

Verification:

```bash
flutter test test/master_frame_evaluation_models_test.dart
flutter analyze
```

### Phase 5 - Read-Only Integration Adapter

Goal: add an adapter that can read current project/editor state and produce a
`MasterFrameEvaluation` without changing what the UI renders.

Allowed changes:

- presentation/domain adapter;
- tests using existing composition/layer/transition fixtures.

Forbidden:

- no Stage5/native changes;
- no preview surface ownership changes;
- no native player bridge unless separately approved.

Verification:

```bash
flutter test <targeted adapter tests>
flutter analyze
```

### Phase 6 - Enforcement And Migration Gates

Goal: add tests and docs that prevent new features from bypassing the master
time/value system.

Allowed:

- tests;
- docs;
- optional lightweight debug assertions in domain adapters;
- scoped lint/check scripts that ban new rendering-time clocks in editor
  preview paths.

Forbidden:

- no global runtime kill switches;
- no broad lint hacks unless scoped and tested.

Implementation note (checkpoint `checkpoint: implement master clock value truth foundation` and later slices):

- guard scripts now block new preview-time `DateTime.now()` / `Stopwatch`
  sources unless allowlisted;
- native transport handoff to `TimelineClockCoordinator` now has a dedicated
  adapter path (`MasterClockNativeBridge`) so screen-level playback sample
  application no longer hardcodes coordinator phase bootstrapping in UI code.
- pause-time writes from editor playback toggles and transport callbacks are now
  routed through the same bridge adapter instead of direct coordinator writes in
  screen code.

## 11. First Writer Task

The first writer task must be exactly:

```text
Implement Phase 0 and Phase 1 only:
- create the inventory doc;
- document every current time reader and classify whether it is source,
  derived, native sample, diagnostic, or temporary;
- lift `TimelineClockCoordinator` as the master-clock foundation without
  replacing it;
- add `MasterTimeSnapshot` or an equivalent immutable projection and time domain
  models;
- add deterministic domain mapper;
- add focused tests for frame index, presentation time, commit ordering,
  phase-transition rejection, and authority rejection;
- update docs and refusion-skills;
- do not edit Stage5/native/renderer/UI preview files.
```

Do not implement value registry, native bridge, notifier migration, preview
surface changes, renderer changes, or transition bug fixes in the first task
unless explicitly approved after Phase 1 review.

## 12. Writer Prompt

Use this prompt for the writer agent:

```text
You are the Writer agent for ReFusionXx.

Project:
/Users/mx/Documents/ReFusionXx/sources/ui/fusionx-clean-ui-2

Branch:
codex/unified-keyframe-ops-foundation-20260426

Model expectation:
Use gpt-5.3-codex. Use medium reasoning for this first slice. Raise to high
only if time-domain mapping becomes ambiguous.

Mandatory reading:
1. /Users/mx/.codex/skills/refusion-development-guardrails/SKILL.md
2. docs/professional_checkpoint_policy.md
3. docs/professional_refusion_motion_keyframe_engine.md
4. docs/master_live_scrub_engine_plan.md
5. docs/master_clock_value_truth_foundation_plan.md

Start with:
git status -sb
git rev-parse --short HEAD

Task:
Implement Phase 0 and Phase 1 of Master Clock & Value Truth Foundation only.

Deliver:
- docs/master_clock_value_truth_inventory.md
- master time/domain model files or compatible TimelineClockCoordinator
  extensions
- deterministic time-domain mapper
- phase/authority policy tests
- targeted tests
- docs update if needed
- refusion-skills update if agent-facing rules changed

Hard boundaries:
- Do not edit Stage5 native files.
- Do not edit Live Scrub handoff paths.
- Do not implement renderer/GPU/Media3 effects.
- Do not edit ProfessionalVideoTransitionCompositorManager.
- Do not modify preview surface ownership.
- Do not implement Native Bridge in this slice.
- Do not migrate _displayTimeNotifier or _playbackSampleTimeNotifier in this
  slice; inventory them only.
- Do not mix transition bug fixes into this slice.
- Ignore unrelated untracked ../../../.claude/.

Verification:
Run the smallest relevant flutter tests and flutter analyze.

Checkpoint:
Commit app repo with:
checkpoint: add master clock value truth foundation

If refusion-skills changed, commit that repo separately with:
checkpoint: document master clock value truth foundation

Push both repos.
Install APK only if runnable app code changed and a device is connected.

Final response must include:
- branch
- commit hash(es)
- files changed
- verification
- push result
- install result or reason skipped
- rollback command(s)
```

## 13. Reviewer Checklist

After the writer finishes, review with these questions:

- Did the writer avoid Stage5/native/renderer files?
- Does `MasterTimeSnapshot` use existing `TimelineTime` instead of inventing a
  parallel scalar?
- Are root/scene/layer/transition/source media domains explicit?
- Does transition time reject outside-window requests?
- Are frame indices deterministic from time and fps?
- Are tests focused and stable?
- Did the writer avoid UI behavior changes?
- Did docs and skills update match the new rule?
- Can the entire checkpoint be reverted with one app commit and one skills
  commit?

## 14. Stop Conditions

Stop immediately if:

- the writer needs to edit protected Stage5 files;
- the writer tries to implement a renderer;
- the writer introduces another preview time notifier as truth;
- the writer stores frame index as UI state;
- the writer creates a new source media time mapper outside the official mapper;
- the writer maps UI values directly to renderer values without a property
  definition;
- tests require device/video playback to pass Phase 1.

## 15. Definition Of Done For This Foundation

The foundation is complete when:

- one canonical time snapshot model exists;
- every domain projection has a documented mapper;
- baseline value definitions exist;
- keyframe evaluation can produce UI/engine/renderer values;
- frame evaluation snapshots can be produced without rendering;
- preview/playback/liveScrub/export can later consume the same snapshot;
- agent documentation says not to claim effect/transition parity outside this
  truth system.
