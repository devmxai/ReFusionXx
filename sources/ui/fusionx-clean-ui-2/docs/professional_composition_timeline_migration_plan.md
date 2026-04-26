# Professional Composition Timeline Migration Plan

Status: official execution plan  
Package: `com.refusion.app`  
Date: 2026-04-26  
Depends on: `docs/professional_refusion_motion_keyframe_engine.md`, `docs/professional_checkpoint_policy.md`

## 1. Final Decision

ReFusion will migrate toward a canonical internal Composition Timeline.

The final architecture is:

```text
Composition Timeline Graph = canonical internal truth
Unified Layer Scope Timeline = one editing surface for all scoped animation
Legacy Transition Scope Timeline = deprecated compatibility path
```

This means:

- The existing Layer Scope Timeline behavior is the reference UX and interaction model.
- Transition Scope must not keep a separate keyframe/timeline engine.
- Transitions must become composition/layer/effect property animation, not a separate private timeline.
- Script and future agent-generated motion must compile into the same editable graph.

## 2. Mandatory Safety Rules

### 2.1 Live Scrub Protection

Live Scrub is protected and must not regress.

Do not modify these paths unless the user explicitly approves that exact Live Scrub change:

- `Stage5TimelineScrubPlatformView`
- `Stage5NativeScrubEngine`
- `Stage5SurfaceScrubDecoder`
- `Stage5ScrubOverlayTextureView`
- `Stage5PreviewPlatformView`
- Flutter Live Scrub handoff paths

If a Composition Timeline step appears to require changing Live Scrub, stop and redesign the adapter layer first.

### 2.2 Checkpoint And Device Install Rule

Every completed build step must be reversible.

Required sequence:

```text
implement the smallest safe slice
-> run targeted verification
-> commit focused files only
-> push checkpoint to GitHub
-> install on the connected device if available
-> report branch, commit hash, verification, install result, rollback command
```

Commit format:

```text
checkpoint: <short behavior name>
```

Rollback note:

```bash
git revert <commit-hash>
```

If no Android device is connected, the agent must say that explicitly and skip only the install step.

## 3. North Star: Agent-Ready Motion Graphics

This migration exists so ReFusion can eventually support agent-authored motion graphics.

Future goal:

```text
User prompt
-> Agent/API creates a ReFusion Scene Program
-> App validates it
-> App creates background assets, text, shapes, effects, channels, keyframes
-> User opens the same Scope Timeline and edits everything manually
-> Preview and export match the same graph
```

An agent-generated scene must never become hidden motion.

Everything it creates must be visible and editable:

- composition layers,
- text elements,
- image elements,
- shape elements,
- generated backgrounds or asset references,
- effects,
- property channels,
- keyframes,
- interpolation/easing,
- transition groups,
- timing.

The app must be able to explain and edit what the agent generated.

## 4. Canonical Model

The canonical graph is:

```text
Composition
  Layer
    Element
      EffectInstance
        PropertyChannel
          Keyframe
          Interpolation
```

Rules:

- Composition time is the canonical time.
- Scope local time is derived from composition time.
- Keyframes are stored with stable identities.
- UI lanes are projections, not storage truth.
- FX and Animate both write to property channels.
- Presets and scripts lower into the same graph as manual edits.
- Preview and export consume the same graph.

## 5. Scope Strategy

### 5.1 Unified Layer Scope Timeline

The Layer Scope Timeline becomes the single scope editing surface for:

- text,
- image,
- shape,
- transition,
- future scene/program scopes.

It owns the shared UX behavior:

- keyframe lanes,
- add key,
- move key,
- move selected key to playhead,
- value editor,
- graph/easing editor,
- Animate picker,
- FX picker,
- lane selection,
- keyframe selection,
- keyframe drag behavior.

### 5.2 Legacy Transition Scope Deprecation

The current Transition Scope Timeline is not the future source of truth.

It should be treated as:

```text
legacy transition editing implementation
-> compatibility only
-> no new permanent behavior
-> gradually replaced by Unified Layer Scope Timeline in transition mode
```

Transition concepts remain, but their implementation changes:

- Clip A and Clip B are transition context.
- Transition window is a composition-time range.
- Transition FX are effect/property channels.
- Transition presets are recipes that create grouped channels/keyframes.
- Transition scripts lower into the Composition Timeline graph.

## 6. Migration Phases

### Phase C0: Documentation And Baseline Lock

Purpose: make the architecture and safety rules explicit.

Deliverables:

- This plan exists.
- Master motion plan links to this plan.
- Checkpoint policy includes post-build device install.
- Live Scrub protection remains explicit.

Exit criteria:

- Documentation checkpoint pushed.
- No code behavior change.

Status: completed in checkpoint `ddebdd1`.

### Phase C1: Composition Projection Domain

Purpose: add domain-only projection infrastructure without UI changes.

Deliverables:

- `CompositionTimelineProjection` model.
- `ScopeProjection` model with modes:
  - `layer`
  - `transition`
  - `scene`
- Projection resolver from existing `MotionProjectModel` / `MotionSceneModel`.
- Tests for global-to-local time mapping.
- Tests for stable layer/effect/channel/keyframe identity.

Exit criteria:

- No UI wiring.
- No Stage5/Live Scrub changes.
- Tests prove projection does not own a second clock.

Current foundation:

- `CompositionTimelineProjectionResolver` exists in `lib/features/editor/domain/services/composition_timeline_projection.dart`.
- It produces composition, scene, layer, and transition scope projections from existing `MotionProjectModel` / `MotionSceneModel` data.
- It derives scope-local time from composition-global time and does not create or own a second clock.
- It filters property channels into the current scene/layer/transition projection while preserving existing channel and keyframe identities.
- Tests exist in `test/composition_timeline_projection_test.dart`.

### Phase C2: Unified Scope Adapter For Layer Scope

Purpose: route current Layer Scope operations through the unified domain path while keeping the same UI.

Deliverables:

- Adapter that converts current Layer Scope context into `ScopeProjection`.
- Layer Scope add/move/value/interpolation/delete keyframes call `UnifiedKeyframeOperations`.
- Existing text scope behavior preserved.
- Image scope and shape scope gaps documented before UI claims full parity.

Exit criteria:

- Existing Layer Scope interactions still work.
- Text keyframes keep preview/play/export behavior.
- No Live Scrub regression.
- Device install after checkpoint.

Current foundation:

- `LayerScopeCompositionAdapter` exists in `lib/features/editor/domain/services/layer_scope_composition_adapter.dart`.
- It converts a layer id, scene id, global time, and graph channels into a `ScopeProjection`.
- It routes layer-scope add/move/value/interpolation/delete keyframe operations through `CanvasTimelineUnifiedKeyframeAdapter`, which uses `UnifiedKeyframeOperations`.
- It validates that authored keyframes target the active layer scope before mutation.
- `UnifiedScopeTimelineProjectionAdapter` exists in `lib/features/editor/presentation/services/unified_scope_timeline_projection_adapter.dart`.
- It converts graph-backed `ScopeProjection.channels` into `TimelineAnimationLaneData` as presentation-only lanes, preserving channel IDs, keyframe IDs, normalized local-time stops, and numeric keyframe values.
- This is domain/adapter infrastructure only. It is not wired to the production Layer Scope UI yet.
- Tests exist in `test/layer_scope_composition_adapter_test.dart` and `test/unified_scope_timeline_projection_adapter_test.dart`.

### Phase C3: Image And Shape Scope Parity

Purpose: make image and shape scopes real graph-backed scopes, not partial UI surfaces.

Deliverables:

- Image transform/effect channels lowered into composition graph.
- Shape transform/style/effect channels lowered into composition graph.
- Scope entry paths for supported image and shape layers.
- Value/graph/keyframe operations match text scope behavior.

Exit criteria:

- Text, image, and shape use the same scope operation layer.
- Unsupported properties are explicit blockers.
- Preview/export parity status is documented per property.

Current foundation:

- `ScopeMotionPropertyCatalog` exists in `lib/features/editor/domain/services/scope_motion_property_catalog.dart`.
- It declares the shared graph-backed motion surface for text, image, and shape elements:
  - position X/Y,
  - scale X/Y,
  - rotation,
  - opacity,
  - blur amount.
- It keeps type-specific properties explicit:
  - text: font size, letter spacing, reveal progress,
  - image: crop rect,
  - shape: width, height, corner radius.
- It builds canonical element targets for layer-scope authoring.
- Tests prove that text, image, and shape keyframes can be authored through the same `LayerScopeCompositionAdapter`.
- This is domain/adapter infrastructure only. It is not wired to production UI yet and does not touch Stage5 or Live Scrub.

### Phase C4: Transition Recipe Lowering

Purpose: stop creating new transition behavior in legacy transition lanes.

Deliverables:

- Transition preset recipes lower into composition graph channels.
- Black Mix, Blur, Zoom, Flash, Push/Slide families map to property/effect channels.
- Transition groups get metadata:
  - `animationGroupId`
  - `presetId`
  - `role`
  - `transitionWindowId`
- Legacy transition lane data can be read for compatibility but is no longer the preferred write target.

Exit criteria:

- Applying a transition creates editable channels/keyframes.
- Keyframes appear through the unified scope lane projection.
- Transition timing changes are real graph changes.

Current foundation:

- `NormalTransitionMotionGraphLowerer` exists in `lib/features/editor/domain/services/normal_transition_motion_graph_lowerer.dart`.
- It treats existing `NormalTransitionInstance` data as a recipe input, not as a permanent timeline engine.
- It lowers transition channel specs into canonical `MotionPropertyChannelModel` channels with stable IDs and local transition-window keyframe times.
- It maps `from` / `to` recipe targets to explicit outgoing/incoming `MotionPropertyTarget`s supplied by the caller.
- It currently supports graph-backed scalar transition properties:
  - opacity,
  - blur amount / horizontal / vertical / mix,
  - position X/Y,
  - scale X/Y,
  - rotation,
  - shake amount.
- It supports scalar parameter references such as `$peakBlur` for imported transition recipes.
- Unsupported targets, properties, values, or duplicate keyframe times produce explicit issues instead of hidden preview-only motion.
- Tests prove Cross Dissolve lowers into editable opacity channels and that the lowered channels project through transition scope.
- `NormalTransitionGraphAuthoringService` exists in `lib/features/editor/domain/services/normal_transition_graph_authoring_service.dart`.
- It combines transition node/instance creation with graph lowering in one domain-level apply operation.
- Applying a graph-backed transition now returns:
  - `NormalTransitionNode`,
  - `NormalTransitionInstance`,
  - `NormalTransitionOverlapWindow`,
  - canonical `MotionPropertyChannelModel` graph channels.
- It also returns `NormalTransitionGraphAuthoringBundle` metadata:
  - `animationGroupId`,
  - `presetId`,
  - `transitionWindowId`,
  - `nodeId`,
  - `instanceId`,
  - per-channel `role` and `propertyId`.
- Tests prove the graph apply path creates channels that can be projected into unified transition scope lanes.
- `TransitionScopeGraphLaneAdapter` exists in `lib/features/editor/presentation/services/transition_scope_graph_lane_adapter.dart`.
- It turns `NormalTransitionGraphAuthoringBundle` channels into transition-aware timeline lanes with role labels such as `Outgoing Opacity` and `Incoming Opacity`.
- It preserves lane-to-channel metadata so the UI can map selection, value editing, and future move-to-playhead operations back to the graph channel.
- It refuses non-transition scopes or mismatched transition windows instead of silently showing incorrect lanes.
- `TransitionScopeGraphAuthoringAdapter` exists in `lib/features/editor/presentation/services/transition_scope_graph_authoring_adapter.dart`.
- It is the UI-facing facade for the next wiring slice:
  - apply transition preset,
  - create graph channels,
  - resolve transition scope,
  - project role-aware unified scope lanes.
- It blocks scope opening when graph apply fails or when the transition context cannot resolve to real outgoing/incoming layers.
- `TransitionUnifiedScopeEntryGate` exists in `lib/features/editor/presentation/services/transition_unified_scope_entry_gate.dart`.
- It is the guarded entry decision layer for future UI wiring:
  - disabled by default,
  - returns legacy Transition Scope while disabled,
  - opens graph-backed Unified Scope only when graph apply, transition projection, and lane projection all succeed,
  - returns explicit fallback reasons for graph, projection, or lane failures.
- This keeps the next UI step small and reversible instead of directly replacing the legacy Transition Scope path.
- `TransitionUnifiedScopeRequestFactory` exists in `lib/features/editor/presentation/services/transition_unified_scope_request_factory.dart`.
- It converts an adjacent video clip boundary into:
  - a temporary transition-scope `MotionProjectModel`,
  - outgoing/incoming video layers,
  - outgoing/incoming element targets,
  - a `TransitionScopeGraphAuthoringRequest` for the gate.
- Tests prove this request can pass through the gate into graph-backed role-aware unified transition lanes.
- `TransitionUnifiedScopeBridgeEntryAdapter` exists in `lib/features/editor/presentation/services/transition_unified_scope_bridge_entry_adapter.dart`.
- It is the bridge-level adapter for future production UI wiring:
  - reads a timeline transition preset,
  - resolves the matching normal transition definition,
  - builds the unified transition request,
  - sends it through the entry gate,
  - falls back to legacy Transition Scope when the feature is disabled, the preset is unsupported, the boundary is invalid, or the graph/projection/lane gate blocks opening.
- `FusionXCleanUiScreen` now contains a disabled-by-default bridge preflight:
  - `_unifiedTransitionScopeBridgeEnabled = false`,
  - `_tryOpenUnifiedTransitionScopeBridge(...)`,
  - existing/new transition bridge taps call this preflight before legacy handling,
  - because the flag is false, current production behavior is unchanged until the real Unified Layer Scope handoff is built and explicitly enabled.
- This is preflight infrastructure only. It does not yet open Unified Layer Scope for users and does not touch Stage5 or Live Scrub.

### Phase C5: Transition Mode In Unified Layer Scope Timeline

Purpose: replace the old Transition Scope editing UI with Unified Layer Scope Timeline in transition mode.

Deliverables:

- Pressing transition bridge opens `UnifiedLayerScopeTimeline(mode: transition)`.
- Context supplies:
  - Clip A,
  - Clip B,
  - transition window,
  - available transition FX,
  - relevant animation groups/channels.
- Old Transition Focus UI is hidden behind a compatibility flag or removed from the normal path.

Exit criteria:

- Transition keyframe add/move/value/edit uses the same controls as text/image/shape.
- Move-to-playhead exists for transition keyframes.
- Value editor works on real property channels.
- No duplicate transition source of truth.

### Phase C6: Scene Program Import V1

Purpose: prepare the app for agent-authored scenes.

Deliverables:

- `ReFusionSceneProgram` JSON schema.
- Validator with readable errors.
- Lowerer from program to Composition Timeline graph.
- Import as one undoable transaction.
- Examples:
  - text intro,
  - lower third,
  - promo card,
  - shape motion scene,
  - transition scene.

Exit criteria:

- Imported scene creates editable layers/channels/keyframes.
- Scope Timeline can inspect and edit imported motion.
- No hidden runtime code.

### Phase C7: Preview And Export Parity Gate

Purpose: ensure the new graph is not preview-only.

Deliverables:

- Preview evaluator consumes graph projections.
- Export builder consumes the same normalized graph.
- Unsupported effects generate explicit blockers.
- Parity probes for accepted effect families.

Exit criteria:

- Preview/export match for accepted effects.
- Blur/black mix/zoom-like transition effects are not accepted until both preview and export paths exist or a blocker is shown.

### Phase C8: Legacy Transition Scope Removal

Purpose: remove deprecated transition timeline ownership after migration is proven.

Deliverables:

- No new writes to legacy transition manual lanes.
- Old transition lane data migrated or treated as read-only compatibility.
- Dead UI paths removed after real-device validation.

Exit criteria:

- Transition editing uses Composition Timeline graph only.
- Scope UI remains unified.
- Undo/redo path is graph-backed.

## 7. Implementation Order

Recommended execution order:

```text
C0 Documentation And Baseline Lock
-> C1 Composition Projection Domain
-> C2 Layer Scope Adapter Wiring
-> C3 Image/Shape Scope Parity
-> C4 Transition Recipe Lowering
-> C5 Transition Mode In Unified Layer Scope Timeline
-> C6 Scene Program Import V1
-> C7 Preview/Export Parity
-> C8 Legacy Transition Scope Removal
```

Do not start C5 before C4.  
Do not remove legacy transition paths before C5 is device-validated.  
Do not claim agent-ready support before C6 and C7 are complete.

## 8. Acceptance Matrix

Every phase that affects behavior must verify the smallest relevant subset:

- main timeline play/pause remains stable,
- Live Scrub remains stable,
- Layer Scope keyframes still add/move/value/edit,
- Text scope remains functional,
- Transition bridge still opens a usable editor,
- no keyframes disappear after sorting,
- no timeline engine owns a second clock,
- preview and timeline time remain aligned,
- export blockers are explicit.

## 9. Rejection Criteria

Reject or revert a slice if:

- Live Scrub regresses,
- play/pause jump returns,
- a scope owns independent time,
- transition keyframes are only visual and not graph-backed,
- keyframes are index-based instead of ID-based,
- preview works but export silently ignores the effect,
- imported scripts create hidden uneditable animation,
- old Transition Scope remains a permanent second engine.

## 10. Commit Naming Examples

Use focused checkpoints:

```text
checkpoint: 2026-04-26 document composition timeline migration
checkpoint: add composition scope projection domain
checkpoint: route layer scope through composition projection
checkpoint: add image shape graph scope parity
checkpoint: lower transition recipes to motion graph
checkpoint: open transitions in unified scope timeline
checkpoint: add scene program schema v1
checkpoint: add preview export parity gates
checkpoint: remove legacy transition scope writes
```

## 11. Practical Rule

When uncertain, prefer this direction:

```text
Do not create a new timeline.
Project the Composition Timeline into the existing Unified Layer Scope Timeline.
Mutate graph channels through unified keyframe operations.
Protect Live Scrub.
Checkpoint, push, install, then continue.
```
