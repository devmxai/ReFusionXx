# Professional Unified Timeline Presentation Plan

Status: official execution plan  
Package: `com.refusion.app`  
Date: 2026-05-11  
Short name: `PUTP`  
Depends on:

- `docs/professional_checkpoint_policy.md`
- `docs/professional_refusion_motion_keyframe_engine.md`
- `docs/professional_composition_timeline_migration_plan.md`
- `docs/professional_composition_workspace_and_scene_orchestration_plan.md`
- `docs/professional_canvas_timeline.md`

## 1. Executive Decision

ReFusionXx will simplify the user-facing timeline experience by introducing a
single **Unified Timeline Presentation Layer**.

This is not a new timeline engine.

The unified timeline is a presentation, navigation, and command-routing layer
over the existing project model, keyframe commands, effect bindings, preview,
playback, export, and Stage5 paths.

The rule for this plan is:

```text
one visible timeline experience
same internal truth
same TimelinePanel
same keyframe/effect/render engines
```

The user-facing result should feel closer to After Effects and Remotion:

```text
Create Composition
-> choose aspect / empty / solid background
-> open one composition canvas
-> one timeline with layers
-> plus button inserts layer types
-> double tap any layer
-> focused Keyframe Motion Timeline for that layer
```

## 2. Why This Plan Exists

The current editor has accumulated multiple user-facing concepts:

- root timeline,
- scene contents,
- scene scope,
- layer scope,
- transition scope,
- focused transition panels,
- keyframe views.

Internally, many of these are already projections over shared graph and timeline
foundations. The problem is not only technical. The problem is that the user is
asked to understand too many timeline surfaces.

This plan reduces the visible model to:

```text
Composition Timeline
  Layer rows
  Focused Keyframe Motion Timeline per selected layer
```

Existing internal scopes may remain as implementation details, compatibility
fallbacks, or adapters. They must not remain the primary user journey.

## 3. Multi-Agent Review Summary

This plan was reviewed through three independent planning agents:

1. **Code/architecture review:** confirmed that the existing foundations point
   toward adapter/projection unification. `TimelinePanel` already acts as the
   shared display surface, and `FusionXCleanUiScreen` currently routes between
   root, scene, layer, and transition modes.
2. **UX architecture review:** confirmed that the right product model is a
   single timeline with layer types and double-tap focused keyframe editing,
   while preserving existing UI styling and existing engines.
3. **Risk review:** confirmed that the safe path is feature-flagged
   presentation unification only, with no Stage5, Live Scrub, renderer, effect,
   export, keyframe evaluator, or schema rewrite.

All three reviews reached the same decision:

```text
Build a presentation adapter and routing layer.
Do not rebuild timeline logic.
```

## 4. Non-Negotiable Scope

### 4.1 In Scope

This plan may introduce:

- a unified timeline presentation model,
- a layer taxonomy for timeline rows,
- adapter mapping from existing project/timeline/scope objects to unified rows,
- command routing from the existing plus button to layer insertion actions,
- double-tap routing into a focused Keyframe Motion Timeline view,
- an Adjustment Layer presentation contract,
- compatibility adapters for legacy scene contents and transition scope,
- feature flags and regression gates.

### 4.2 Out Of Scope

This plan must not introduce:

- a new timeline engine,
- a new keyframe evaluator,
- a new effect engine,
- a new renderer,
- a new export path,
- a Stage5 rewrite,
- a Live Scrub rewrite,
- a SceneProgram schema rewrite,
- a UI redesign,
- a visual restyle of existing panels,
- a destructive legacy migration.

## 5. Protected Boundaries

The following paths and concepts are protected. If a step appears to require
touching them, the step must stop and be redesigned through an adapter.

### 5.1 Protected Live Scrub / Stage5 Paths

Do not touch:

- `Stage5TimelineScrubPlatformView`
- `Stage5NativeScrubEngine`
- `Stage5SurfaceScrubDecoder`
- `Stage5ScrubOverlayTextureView`
- `Stage5PreviewPlatformView`
- Flutter Live Scrub handoff paths
- `native_timeline_scrub_surface.dart`

### 5.2 Protected Engines

Do not change behavior in:

- keyframe evaluation,
- interpolation evaluation,
- effect evaluation,
- transition rendering,
- preview rendering,
- playback rendering,
- export composition building,
- Stage5 native preview ownership.

### 5.3 Protected UI Contract

This plan must not redesign the UI.

Allowed:

- route existing timeline views differently,
- rename user-facing concepts in labels where already surfaced,
- feed existing `TimelinePanel` with a unified projection,
- organize existing plus actions by layer type.

Not allowed:

- new visual design language,
- new bottom bar layout,
- new editor shell,
- new canvas layout,
- replacing `TimelinePanel`,
- forking `TimelinePanel`.

## 6. Product Model

### 6.1 Create Composition

The existing create composition flow stays conceptually intact:

```text
Create Composition
-> choose aspect
-> choose empty, blank, or solid background
-> open the editor workspace
```

This plan does not rebuild create composition.

The professional target is simply that the opened workspace presents one
composition canvas and one timeline surface.

### 6.2 Unified Timeline Layer Types

The unified timeline exposes these layer types:

| Layer Type | Definition | Runtime Truth |
|---|---|---|
| `Solid Layer` | Visible time-bounded color or gradient layer. Used for backgrounds, fills, and design blocks. | Existing background/layer/effect-capable visual model through adapter. |
| `Media Layer` | Video or image layer on the timeline. | Existing media clip/layer truth. |
| `Text Layer` | Text object with transform, opacity, typography, text animation, and effects. | Existing text layer/element/property channels. |
| `Shape Layer` | Basic vector/shape layer with fill, stroke, transform, opacity, and effects. | Existing shape layer/element/property channels. |
| `Audio Layer` | Audio item on the timeline. It does not own canvas bounds. | Existing audio clip/model. |
| `Adjustment Layer` | Time-bounded effect/treatment container. It can apply transition, color, or effect treatment across its span. | Existing effect/transition bindings through adapter only. |

### 6.3 Adjustment Layer Definition

An Adjustment Layer is not a new effect engine.

It is:

```text
time-bounded effect container
```

It may represent:

- a transition region over two adjacent media layers,
- a color/effect treatment across a time span,
- a non-destructive effect container above one or more target layers.

Initial implementation must map Adjustment Layer behavior to existing effect
and transition authoring paths. If an effect cannot be represented through an
existing engine, the adjustment layer must show an unsupported diagnostic rather
than inventing a new runtime path.

### 6.4 Keyframe Motion Timeline

Double tapping any timeline layer opens a focused **Keyframe Motion Timeline**.

This is not a second engine. It is a projection mode over the existing
property/keyframe data for the selected layer.

It may show:

- transform properties,
- opacity,
- text-specific lanes,
- shape-specific lanes,
- media-specific lanes,
- audio-specific lanes,
- effect parameter lanes,
- existing graph/easing controls where already supported.

It must not store a separate copy of keyframes.

## 7. Canonical Architecture

The architecture is:

```text
Existing Project / Composition / Scene / Layer / Effect Data
        |
        v
Unified Timeline Presentation Adapter
        |
        v
Unified Timeline Rows
        |
        +--> Existing TimelinePanel
        |
        +--> Layer Focus Adapter
                 |
                 v
             Keyframe Motion Timeline Projection
                 |
                 v
             Existing Keyframe / Effect / Property Commands
```

The adapter may read and project. It may not become storage truth.

## 8. Implementation Phases

### PUTP-00 - Architecture Freeze And Safety Audit

Purpose: lock the plan boundaries before implementation.

Tasks:

- read the mandatory timeline and checkpoint docs,
- list current root, scene, layer, and transition timeline entry points,
- identify all protected Stage5/Live Scrub paths,
- document the existing callbacks feeding `TimelinePanel`,
- identify existing plus/add commands,
- identify existing double-tap routes.

Deliverables:

- implementation inventory section or test fixture,
- list of files allowed for the first slice,
- list of protected files forbidden for this plan.

Acceptance:

- no code behavior changes,
- no protected Live Scrub or Stage5 file in the proposed write set,
- no renderer/effect/evaluator write set.

### PUTP-01 - Unified Timeline Presentation Model

Purpose: define a read-only presentation model that can describe every visible
timeline item as a layer row.

Create or formalize:

```text
UnifiedTimelinePresentation
  compositionId
  activeScopeKind
  rows[]
  selectedRowId
  playheadTime
  duration
  diagnostics[]

UnifiedTimelineRow
  id
  sourceId
  layerType
  sourceKind
  label
  startMs
  durationMs
  zIndex
  visibility
  locked
  muted
  canFocusKeyframes
  canTrim
  canMove
  canReceiveEffects
```

Rules:

- this model is immutable output,
- this model does not write project data,
- row ids must preserve source identity,
- diagnostics must explain unsupported mappings.

Acceptance:

- unit tests create rows for existing media, text, shape, audio, scene clip, and
  transition-like items without mutating input models.

### PUTP-02 - Layer Taxonomy Mapping Adapter

Purpose: map existing data into the layer taxonomy.

Mapping:

| Existing Source | Unified Row |
|---|---|
| project/root background color or future background layer | `Solid Layer` |
| video/image clips | `Media Layer` |
| text layer or text element | `Text Layer` |
| shape layer or shape element | `Shape Layer` |
| audio clip | `Audio Layer` |
| transition/effect range | `Adjustment Layer` |
| scene clip/container | `Media Layer` or `Composition Layer` diagnostic until surfaced deliberately |

Rules:

- no schema rewrite,
- no data migration,
- unsupported source kinds appear with diagnostics, not crashes,
- legacy scene content remains internally available.

Acceptance:

- legacy fixtures project to deterministic rows,
- no row loses source id or timing,
- draw order/z-index is deterministic.

### PUTP-03 - TimelinePanel Projection Handoff

Purpose: prove that the unified presentation can feed the existing
`TimelinePanel`.

Tasks:

- add adapter from `UnifiedTimelinePresentation` to existing `TimelinePanel`
  view data,
- keep the same `TimelinePanel` widget,
- keep the same visual layout,
- keep existing scrub, zoom, trim, and selection callbacks.

Rules:

- do not fork `TimelinePanel`,
- do not change `TimelinePanel` styling,
- do not change clock or geometry logic,
- if a row cannot map to current visual kinds, emit diagnostics.

Acceptance:

- existing root timeline project renders through the adapter with the same
  visible row count and timing,
- selection and playhead remain stable,
- feature flag off returns exactly to old handoff.

### PUTP-04 - Plus Menu Command Registry

Purpose: make the plus button insert professional layer types while using
existing commands and existing UI affordances.

Layer commands:

```text
Add Solid Layer
Add Adjustment Layer
Add Media Layer
Add Text Layer
Add Shape Layer
Add Audio Layer
```

Rules:

- do not redesign the plus menu,
- do not create new engine-side layer logic in this phase,
- each action must route to an existing creation/import command or a thin
  adapter around it,
- unsupported commands are hidden or disabled with diagnostics, not faked.

Acceptance:

- commands are listed in one registry,
- each command declares whether it is supported by current runtime,
- inserting a layer uses the same command/history path as existing insertion.

### PUTP-05 - Double Tap Layer Focus Routing

Purpose: make double tap open the focused Keyframe Motion Timeline for the
selected layer.

Rules:

- single tap selects,
- double tap focuses,
- focus changes projection mode only,
- focus does not create a second storage model,
- existing Scene Contents / scope internals remain fallback or advanced paths,
  not the default user journey.

Acceptance:

- double tapping media/text/shape/audio/adjustment rows resolves a focus target,
- focus target carries stable source ids,
- unsupported focus reports a clear diagnostic,
- feature flag off returns to existing double-tap behavior.

### PUTP-06 - Keyframe Motion Timeline Adapter

Purpose: project selected-layer property channels into a focused keyframe
timeline.

Tasks:

- use existing property/channel catalogs where available,
- project layer-local time through existing mappers,
- route add/move/delete/value/interpolation actions through existing keyframe
  command adapters,
- preserve graph/easing integrations where already supported.

Rules:

- no new keyframe evaluator,
- no new interpolation runtime,
- no scope-only keyframe semantics,
- no duplicate keyframe storage.

Acceptance:

- add keyframe on a focused layer writes to the same existing channel path,
- moving a keyframe updates the same model the renderer already consumes,
- focused and root projections agree on time mapping.

### PUTP-07 - Adjustment Layer Presentation Contract

Purpose: represent transitions/effects as timeline layers without inventing a
new effect engine.

Tasks:

- define `Adjustment Layer` as a row type,
- support time span, label, target scope diagnostics, and effect binding
  diagnostics,
- map existing normal transition/effect range concepts to adjustment rows where
  possible,
- define unsupported cases clearly.

Rules:

- no effect engine rewrite,
- no fake transition render path,
- no new shader path,
- no export change.

Acceptance:

- a transition/effect span can appear as an `Adjustment Layer` row,
- selecting it can focus existing effect/keyframe controls if supported,
- render output before/after remains identical.

### PUTP-08 - Legacy Compatibility And Scene Contents Containment

Purpose: keep all old projects valid while reducing the primary user journey.

Rules:

- do not delete Scene Contents,
- do not migrate project data,
- do not break nested source compositions,
- keep advanced/fallback access to old scope surfaces until parity is proven.

Acceptance:

- legacy projects open unchanged,
- existing generated scenes remain editable,
- old scene/scope entry points still work behind fallback paths,
- new unified surface can represent old content as rows or diagnostics.

### PUTP-09 - Feature Flag And Rollout Control

Purpose: ship this change safely.

Feature flag:

```text
unifiedTimelinePresentationLayer
```

Behavior:

| Flag State | Behavior |
|---|---|
| off | existing production timeline routing |
| internal | unified projection visible only to internal/dev builds |
| beta | unified projection enabled for selected builds with fallback |
| stable | unified projection becomes default after gates pass |

Rules:

- flag off must require no data rollback,
- no schema migration in this plan,
- no irreversible write path behind the flag.

Acceptance:

- turning the flag off restores the previous user-facing route,
- tests cover both flag off and flag on routing.

### PUTP-10 - Strict Regression Gate

Purpose: prove the unified timeline did not change engines.

Required tests:

- projection tests for every layer type,
- legacy project open tests,
- double-tap focus routing tests,
- keyframe roundtrip tests,
- plus command routing tests,
- adjustment layer diagnostics tests,
- feature flag on/off tests,
- render/preview parity tests for representative scenes where practical,
- no protected file write-set assertion in review.

Acceptance:

- existing targeted timeline/keyframe tests still pass,
- existing scene apply/import tests still pass,
- no Stage5/Live Scrub protected path changed,
- no effect output changed,
- no keyframe output changed,
- no export output changed.

### PUTP-11 - Documentation And Skills Update

Purpose: make future agents use the unified model correctly.

Tasks:

- update relevant authoring docs to prefer:

```text
Timeline Layer
-> Focus Keyframe Motion Timeline
-> Existing commands/effects/keyframes
```

- document Adjustment Layer as presentation contract,
- document that Scene Contents remains internal/advanced fallback,
- document prohibited changes.

Acceptance:

- future scene/timeline agents do not ask the user to navigate multiple
  timeline types for normal work,
- docs explicitly forbid engine rewrites under this plan.

## 9. Risk Matrix

| Risk | Severity | Likelihood | Prevention |
|---|---:|---:|---|
| Live Scrub regression | Critical | Medium | protected file stop list, feature flag, device smoke |
| Stage5/render behavior drift | Critical | Low | no renderer writes, parity tests |
| Effect behavior drift | High | Medium | Adjustment Layer maps existing effect paths only |
| Keyframe semantics drift | High | Medium | command routing through existing adapters |
| Legacy project breakage | High | Medium | no schema migration, compatibility tests |
| New duplicate timeline engine | High | Medium | reuse `TimelinePanel`; adapter-only architecture |
| UI redesign creep | Medium | Medium | no visual restyle; labels/routing only |
| Data rollback needed | High | Low | no irreversible project writes in phase one |
| Confused selection identity | Medium | Medium | stable source ids on every row |
| Scope fallback loss | Medium | Low | keep legacy/advanced scope access until parity |

## 10. Acceptance Definition

This plan is complete only when:

- the user sees one primary timeline after opening a composition,
- plus inserts or routes to clear layer types,
- every visible row has stable source identity,
- double tap opens a focused Keyframe Motion Timeline projection,
- Adjustment Layer is represented as a time-bounded effect container,
- existing scenes and projects open unchanged,
- existing effects work unchanged,
- existing keyframes evaluate unchanged,
- existing preview/playback/export output is unchanged,
- Live Scrub remains untouched and stable,
- feature flag off restores old routing,
- no duplicate timeline engine exists.

## 11. Stop List

Do not:

- touch protected Live Scrub files,
- touch Stage5 engine internals,
- change effect evaluators,
- change keyframe evaluators,
- change export builder semantics,
- change SceneProgram schema as part of this plan,
- fork `TimelinePanel`,
- redesign the UI,
- remove Scene Contents,
- migrate legacy projects,
- create a second keyframe model,
- create a second timeline storage model,
- hide unsupported adjustment/effect behavior behind fake visuals,
- mix this work with Design System, Motion Runtime, scene generation, or visual
  harmony work.

## 12. First Implementation Slice

The first code slice after this plan must be:

```text
PUTP-00 + PUTP-01 only
```

That means:

- inventory,
- feature flag placeholder,
- read-only presentation model,
- read-only projection tests.

It must not wire production UI yet.

The first user-visible routing change is not allowed until the read-only model
and compatibility tests prove that existing timelines can be projected without
data loss.

