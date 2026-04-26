# Professional ReFusion Motion And Keyframe Engine

Status: official master execution plan  
Package: `com.refusion.app`  
Supersedes: `docs/professional_timeline_clock_contract.md`  
Scope: professional timeline clock, timeline geometry, scoped timelines, keyframes, effects, transitions, script import, scene programs, preview parity, and export parity

## Mandatory Checkpoint Policy

All implementation work under this plan must follow:

`docs/professional_checkpoint_policy.md`

This is a strict project rule. Every completed build step must be committed as a focused checkpoint and pushed to GitHub before starting the next build step, unless the user explicitly says not to push.

The required order is:

```text
finish scoped change
-> verify
-> commit focused files only
-> push checkpoint branch
-> report commit hash and rollback command
```

This rule exists so timeline, Live Scrub, keyframe, transition, and motion-engine regressions can be rolled back precisely.

## Execution Status

- Phase 0: completed. Expanded baseline audit for timeline time writers, geometry writers, keyframe data paths, effect data paths, transition data paths, script import outputs, preview inputs, and export inputs is documented in `docs/professional_timeline_clock_audit.md`.
- Phase 1: completed as isolated infrastructure. `TimelineClockCoordinator` exists in `lib/features/editor/domain/services/timeline_clock_coordinator.dart` with tests in `test/timeline_clock_coordinator_test.dart`.
- Phase 2: device-validated candidate. Main timeline playback start, native playback samples, and scrub handoff pass through `TimelineClockCoordinator`. Real-device validation on April 25, 2026 reported high stability for play/pause and Live Scrub on valid media.
- Phase 3: in progress. `TimelineGeometryMapper` exists in `lib/features/editor/domain/services/timeline_geometry_mapper.dart` with tests in `test/timeline_geometry_mapper_test.dart`; central time/offset mapping, visual follow, clip move, trim drag, and native scrub pointer delta paths are being routed through it. Contract tests now lock scrub/settle/play and zoom/play handoff behavior before deeper motion-engine unification.
- Phase 4+: open. Scope projection, motion graph import, transition unification, scriptable scene programs, and export parity must be built on top of the clock foundation.
- Phase 5: started as isolated domain/presentation infrastructure. `UnifiedKeyframeOperationService` exists in `lib/features/editor/domain/services/unified_keyframe_operations.dart`; it wraps existing graph-backed canvas keyframe operations and adds an atomic group-move entry point for compound properties such as Position. `UnifiedKeyframeTimelineProjectionService` exists in `lib/features/editor/presentation/services/unified_keyframe_timeline_projection.dart`; it projects scalar graph channels into single or batched timeline lanes without making UI lanes the source of truth. Neither service is connected to UI yet.
- Phase 6: started as isolated compatibility infrastructure. `TimelineLaneMotionLoweringService` exists in `lib/features/editor/presentation/services/timeline_lane_motion_lowering.dart`; it lowers single or batched legacy scalar timeline lanes into graph-backed motion channels while rejecting duplicate keyframe times and unsupported value kinds. Round-trip tests now cover lane -> graph channel -> lane identity/timing stability. It is not connected to UI yet.
- Phase 7: started as isolated script infrastructure. `ReFusionSceneProgramImportService` exists in `lib/features/editor/domain/services/refusion_scene_program_import_service.dart`; it validates strict declarative JSON scene programs with required schema version, no executable fields, and editable scalar/integer channels. `ReFusionSceneProgramMotionLoweringService` lowers a validated scene program into a `MotionAuthoringBundle` with generated elements and graph-backed property channels. Neither service is connected to UI yet.
- Live Scrub status: protected. Stage5 Live Scrub is not part of a rewrite. It is a production path that must remain fast, precise, and native-optimized.

## 0. Non-Negotiable Live Scrub Protection

Live Scrub is a protected production path.

This plan must not rebuild, replace, or degrade the current Stage5 Live Scrub path. Any implementation must treat Live Scrub as a high-value existing capability and integrate with it through an adapter layer first.

Strict rules:

- Do not rewrite the Stage5 Live Scrub engine as part of this plan.
- Do not modify Stage5 Live Scrub native files unless a specific, reviewed fix requires it.
- Do not use timeline, keyframe, transition, or script work as a reason to weaken scrub responsiveness.
- Do not accept any phase if fast scrub, slow scrub, zoomed-in scrub, or reverse scrub regresses.
- If a clock or motion engine fix conflicts with scrub quality, stop and redesign the integration layer.
- The target is 100% professional stability, not a visual mask over a timing mismatch.

The goal is to make Live Scrub safer by giving it a proper timeline, geometry, and evaluation contract, not to disturb the working scrub path.

## 1. Master Goal

Build one professional motion system for ReFusion:

```text
Professional Timeline Clock
-> Unified Timeline Geometry
-> Unified Keyframe Operations
-> Unified Motion Property Graph
-> ReFusion Scene Program
-> Preview And Export Parity
```

Every manual edit, preset, transition, imported script, and future AI-generated motion scene must land in the same editable model:

```text
Scene
Layer
Element
Effect Instance
Property Channel
Keyframe
Interpolation
```

No feature may create a private animation engine that cannot be inspected, edited, scrubbed, previewed, exported, or represented in a scope timeline.

## 2. Current Architectural Problem

The app currently has several useful systems, but they are not fully unified:

- Timeline clock and native playback are being centralized, but some UI paths still historically wrote time directly.
- Layer Scope uses real motion channels for some text workflows, but image/shape parity is not complete.
- Transition Scope has manual lanes and script lanes, but they are not yet the same graph as layer motion.
- Script import exists for scoped text and transitions, but both are specialized importers.
- Timeline UI lanes can represent keyframes, but they are not always direct projections of `MotionPropertyChannelModel`.
- Export supports several motion programs, but preview/export parity is not yet guaranteed for every effect.

The professional requirement is:

```text
playhead time
= scroll geometry
= preview frame
= native player position
= scoped local time
= keyframe evaluation time
= export evaluation time
```

## 3. Final Architecture

### 3.1 Timeline Clock

`TimelineClockCoordinator` owns timeline time and interaction phase.

It is the only component allowed to decide the current global timeline time.

Other systems may request time changes, but they must not independently write:

- timeline display time,
- scroll position as time truth,
- preview evaluation time,
- native playback time,
- scoped local time,
- keyframe evaluation time.

### 3.2 Timeline Geometry

`TimelineGeometryMapper` owns deterministic time-to-pixel mapping.

```text
scrollOffset = geometry.offsetForTime(clock.time)
time = geometry.timeForOffset(scrollOffset)
```

Rules:

- The playhead is fixed in viewport space.
- The content scrolls according to clock time.
- Zoom preserves the exact anchor frame.
- Zoom must not change preview frame.
- Native scrub regions, ruler labels, clip bounds, transition windows, and keyframe lanes use the same mapper.

### 3.3 Unified Keyframe Operations

All keyframe operations must use identity-based operations, not index-based operations.

Required operations:

```text
addKeyframe(channelId, localTime, value)
moveKeyframe(keyframeId, localTime)
setKeyframeValue(keyframeId, value)
setKeyframeInterpolation(keyframeId, interpolation)
deleteKeyframe(keyframeId)
selectKeyframe(keyframeId)
moveSelectedKeyframeToPlayhead()
```

Rules:

- A keyframe has a stable ID.
- Moving a keyframe never changes which keyframe is selected.
- Sorting by time must not lose identity.
- Time collisions must not silently drop keyframes.
- Multi-channel properties such as Position must move as a group when they represent one user-visible keyframe.
- UI lanes, Layer Scope, Transition Scope, and script import must call the same keyframe operation layer.

### 3.4 Unified Motion Property Graph

The canonical animation model is a property graph:

```text
MotionProject
MotionScene
MotionLayer
MotionElement
MotionEffectInstance
MotionPropertyChannel
MotionKeyframe
MotionInterpolationSpec
```

Everything compiles to this graph:

- manual canvas edits,
- scoped text animation,
- image animation,
- shape animation,
- transition presets,
- transition scripts,
- imported scene programs,
- future agent-generated motion graphics.

No feature may keep a permanent separate lane model that cannot be lowered into this graph.

### 3.5 ReFusion Scene Program

`ReFusionSceneProgram` is the scriptable authoring format.

It is a declarative data document, not executable code.

Allowed:

- JSON first.
- YAML may be allowed later if validation is identical.
- Strict schema versioning.
- Declarative layers, elements, effects, channels, keyframes, easing, and asset references.

Forbidden:

- JSX.
- JavaScript execution.
- `eval`.
- external imports.
- hidden runtime code.
- shader source embedded directly in user scripts.

The importer pipeline:

```text
External script or agent output
-> ReFusionSceneProgram validation
-> scope and target resolver
-> effect and channel lowerer
-> MotionAuthoringBundle
-> transaction
-> MotionPropertyChannelModel
-> preview/export graph
```

### 3.6 Scope Projection

Scopes are projections, not separate engines.

```text
layerLocalTime = globalClock.time - layerStartTime
transitionLocalTime = globalClock.time - transitionWindowStartTime
```

Layer Scope, Transition Scope, and future Scene Scope must share:

- one clock,
- one geometry mapper,
- one keyframe operation layer,
- one evaluator contract,
- one undo/redo transaction model.

### 3.7 Preview And Export Parity

Preview and export must evaluate the same graph.

The preview pipeline may be optimized, and export may run elsewhere, but both must consume the same normalized motion data:

```text
MotionGraph + clock/evaluation time -> visual state
```

Any effect accepted into the product must define:

- preview behavior,
- scrub behavior,
- playback behavior,
- export behavior,
- fallback or blocker behavior if unsupported.

## 4. Timeline Clock Contract

The coordinator exposes a strict state machine:

- `idle`
- `paused`
- `scrubbing`
- `scrubSettling`
- `playStarting`
- `playing`
- `pausing`
- `seeking`
- `zooming`
- `structuralEditing`

Invalid combinations are forbidden.

Examples:

- The system must not be `playing` and `scrubSettling` at the same time.
- The system must not be `zooming` while accepting timeline time drift from playback samples.
- The system must not be `scrubbing` while playback samples drive visible time.

Every phase defines:

- who may request time changes,
- who may confirm time changes,
- whether native transport is authoritative,
- whether preview frames are requested or streamed,
- whether scroll is user-owned or clock-owned.

All timeline time changes must go through coordinator commands:

```dart
clock.scrubStart(anchorTime);
clock.scrubUpdate(targetTime);
clock.scrubEnd(finalTime);
clock.playFrom(time);
clock.pauseAt(time);
clock.seekTo(time);
clock.zoomStart(anchorTime);
clock.zoomUpdate(anchorTime, scale);
clock.zoomEnd(anchorTime);
clock.applyNativeSample(sampleTime);
clock.applyStructuralEdit(resultingTime);
```

No widget should coordinate playback by mixing:

- `setCurrentTime`,
- `setPlaybackSampleTime`,
- native `seekTo`,
- native `play`,
- scroll `jumpTo`.

Those actions must become coordinator-owned side effects.

## 5. Playback Contract

When the user presses Play:

1. Read start time from `TimelineClockCoordinator`.
2. End or supersede any pending scrub settle for that target time.
3. Send one native command: `playFrom(startTime)`.
4. Enter `playStarting(startTime)`.
5. Reject stale native samples older than the requested start time.
6. Accept the first valid native sample as playback confirmation.
7. Enter `playing`.
8. Drive preview, timeline scroll, ruler, keyframes, effects, transitions, and scopes from accepted clock time.

Acceptance criteria:

- Play after forward scrub starts from the exact final scrub frame.
- Play after reverse scrub starts from the exact final scrub frame.
- Pause then Play starts from the exact paused frame.
- No track jump.
- No refresh flash.
- No preview/timeline divergence.

## 6. Live Scrub Contract

Live Scrub remains native-optimized, but its lifecycle is represented in the coordinator.

Flow:

```text
native scrub down -> clock.scrubStart(anchorTime)
native scrub move -> clock.scrubUpdate(time)
native scrub up   -> clock.scrubEnd(finalTime)
native settle     -> clock.scrubSettling(finalTime)
settle complete   -> clock.pausedAt(finalTime)
```

The coordinator must not slow down scrub input. It adapts scrub events; it does not replace the scrub engine.

Acceptance criteria:

- Fast Live Scrub remains responsive.
- Slow Live Scrub remains stable frame-by-frame.
- Reverse Live Scrub does not jitter between adjacent frames.
- Deep zoom Live Scrub remains precise.
- Scrub-to-play handoff has no jump.

## 7. Native Transport Adapter

Native transport is authoritative only in these phases:

- `playStarting`, after first valid confirmed sample.
- `playing`, for accepted playback samples.
- `seeking`, when confirming requested seek completion.

It is not authoritative during:

- user scrub updates,
- zoom gestures,
- structural edit transactions,
- scoped timeline edits,
- manual keyframe dragging.

The adapter exposes typed events:

```dart
NativePlaybackStarted(requestedTime, firstSampleTime)
NativePlaybackSample(sampleTime)
NativePlaybackPaused(positionTime)
NativeSeekConfirmed(requestedTime, actualTime)
NativeScrubSettleConfirmed(targetTime)
NativeTransportStalled(lastKnownTime)
```

Raw native position events must not directly mutate UI time.

## 8. Keyframe And Effect Evaluation Contract

All keyframe and effect evaluation reads from:

```dart
clock.evaluationTime
```

No effect may evaluate from:

- widget local state,
- scroll position,
- native raw position,
- stale playback sample,
- independent scoped timer.

This applies to:

- opacity,
- position,
- scale,
- rotation,
- blur,
- color,
- text animation,
- imported script motion,
- transition parameters,
- future shape/image/video effects.

## 9. Transition Contract

Transitions are first-class timeline windows driven by the same clock.

Transition scope uses:

```text
transitionProgress = (globalClock.time - transitionWindowStart) / transitionWindowDuration
```

Rules:

- Transition keyframes change real transition timing.
- Presets and imported scripts compile to the same property channels.
- Preview and export use the same transition evaluator.
- Transition Scope must not invent a separate playback clock.
- Manual transition lanes are temporary UI projections until transition channels are lowered into the canonical graph.

## 10. Script And Agent Authoring Contract

Future agents should not generate app-private hacks.

They should generate a `ReFusionSceneProgram` document that the app validates and lowers into editable motion data.

A generated scene must be inspectable:

- layers visible in timeline,
- elements visible on canvas,
- effects visible in scope,
- keyframes visible on lanes,
- values editable through inspectors,
- timing editable by dragging or move-to-playhead,
- preview and export matching the same authored data.

The import UX must support:

- paste script,
- upload file,
- validation report,
- preview before apply,
- apply as transaction,
- undo/redo as one command,
- edit after import.

## 11. Undo/Redo Transaction Contract

Every user operation must be a transaction.

Required transaction groups:

- add media,
- cut/trim/move clip,
- add layer,
- edit layer style,
- enter/exit scope without mutation,
- add effect,
- add keyframe,
- move keyframe,
- set keyframe value,
- set interpolation,
- import script,
- apply transition preset,
- edit transition keyframe.

Undo/Redo must not be left as a later polish item. It is part of professional timeline safety.

## 12. Implementation Phases

### Phase 0: Audit And Baseline Freeze

Document all current writers of time, scroll, keyframe lanes, effect values, transition lanes, and script import outputs.

Exit criteria:

- A list of all writers exists.
- No code behavior change.

### Phase 1: Timeline Clock Foundation

Complete `TimelineClockCoordinator` ownership for playback, pause, scrub handoff, and native playback samples.

Exit criteria:

- Pause/play has no jump.
- Forward scrub then play has no jump.
- Reverse scrub then play has no jump.
- Existing Live Scrub quality is unchanged.

### Phase 2: Timeline Geometry Foundation

Route all time-to-offset and offset-to-time mapping through `TimelineGeometryMapper`.

Exit criteria:

- Zoom preserves exact frame.
- Playback moves real scroll, not visual-only transforms.
- Native scrub regions update from the same geometry.
- Main timeline, Layer Scope, and Transition Scope share the same mapping rules.

### Phase 3: Live Scrub Adapter Hardening

Wrap Live Scrub events into coordinator commands without rewriting scrub internals.

Exit criteria:

- Slow scrub is stable.
- Reverse scrub is stable.
- Deep zoom scrub is stable.
- Scrub-to-play remains exact.
- No Stage5 regression.

### Phase 4: Scoped Timeline Projection

Connect Layer Scope and Transition Scope as projections of the global clock.

Exit criteria:

- Scoped playback matches main timeline playback.
- Scoped scrub matches main timeline scrub.
- Scope local time is derived, not independently owned.
- Transition scope does not drift from global timeline.

### Phase 5: Unified Keyframe Operations

Create a shared keyframe operation layer used by Layer Scope, Transition Scope, and script imports.

Exit criteria:

- Keyframes use stable IDs.
- Add/move/delete/value/interpolation behavior is identical across scopes.
- Move-to-playhead is available where keyframes exist.
- Time collisions are explicit, not silent.
- Position-like compound channels can move as one visible keyframe group.
- Timeline UI lanes can be generated as projections from graph channels without becoming storage.
- Multiple graph channels can be projected together so Layer Scope and Transition Scope do not duplicate lane-building logic.

### Phase 6: Motion Property Graph Lowering

Lower UI lanes, direct effects, transition lanes, and scoped script imports into canonical motion property channels.

Exit criteria:

- `TimelineAnimationLaneData` is a projection, not permanent source of truth.
- Existing scalar lanes can be lowered into graph-backed channels without silent keyframe merges.
- Lowered scalar lanes can be projected back without changing keyframe IDs, normalized stops, or displayed values.
- Text, image, shape, and transition motion all have graph-backed channels.
- Existing text script import is moved out of screen code into a reusable domain lowerer.

### Phase 7: ReFusion Scene Program V1

Define and implement a strict declarative script format.

Exit criteria:

- JSON schema exists.
- Schema version is required.
- Executable fields are rejected; scripts are declarative editable data only.
- Importer produces a `MotionAuthoringBundle`.
- Imported scene can create layers, elements, effects, channels, and keyframes.
- Imported scene remains editable in the UI.

### Phase 8: Preview Evaluator Parity

All preview surfaces read from the same normalized motion graph.

Exit criteria:

- Manual keyframes work in scrub/play.
- Scripted effects work in scrub/play.
- Transition keyframes are real, not visual-only.
- Preview does not use a private effect path unavailable to export.

### Phase 9: Export Parity

Export consumes the same normalized graph and interpolation semantics as preview.

Exit criteria:

- Preview and export match within accepted visual tolerance.
- Unsupported effects produce explicit blockers.
- No effect is accepted if it cannot be represented in export or clearly marked preview-only.

### Phase 10: Agent Authoring Contract

Create the documentation that external agents use to generate valid `ReFusionSceneProgram` files.

Exit criteria:

- Agent prompt contract exists.
- Example scripts exist for text intro, promo card, transition, lower third, and motion graphic scene.
- Validation errors are human-readable.
- Imported agent output is visible and editable as normal timeline/keyframe data.

## 13. Test Matrix

Required tests before accepting relevant phases:

- Play from paused frame.
- Pause at frame, play again.
- Forward Live Scrub, release, play.
- Reverse Live Scrub, release, play.
- Live Scrub while playing.
- Zoom in then play.
- Zoom out then play.
- Deep zoom slow scrub.
- Main timeline playback.
- Layer Scope playback.
- Transition Scope playback.
- Keyframe add/move/delete/value edit.
- Keyframe drag then play.
- Keyframe move-to-playhead then play.
- Effect value edit then scrub/play.
- Script import then scrub/play.
- Transition preset then scrub/play.
- Preview/export parity probe for every accepted effect family.

## 14. Rejection Criteria

Reject any implementation if:

- Live Scrub becomes slower.
- Play causes a visible jump.
- Preview moves while timeline does not.
- Timeline moves while preview does not.
- Playhead can move outside real timeline content.
- Keyframes evaluate differently in scrub and playback.
- Scope timeline uses a separate clock engine.
- A visual transform hides a real clock mismatch.
- Script import creates hidden motion that cannot be edited.
- Export differs from preview without an explicit documented blocker.

## 15. Final Target

The final target is a 2026-grade ReFusion motion engine:

- one clock,
- one geometry mapper,
- one keyframe operation layer,
- one motion property graph,
- one scene program importer,
- one preview evaluator contract,
- one export parity contract,
- scope timelines as projections,
- scripts as editable data,
- no fake visual correction,
- no Live Scrub regression,
- no playback jump,
- no preview/timeline divergence.

This plan is the foundation for professional transitions, scoped layer animation, direct effects, scriptable motion graphics, future AI-generated scenes, and reliable export.
