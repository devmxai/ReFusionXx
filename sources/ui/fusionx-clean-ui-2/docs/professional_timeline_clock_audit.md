# Professional Timeline Clock Audit

Status: Phase 0 baseline audit for the unified motion/keyframe engine
Parent plan: `docs/professional_refusion_motion_keyframe_engine.md`  
Scope: current timeline time writers, geometry writers, keyframe data paths, effect data paths, transition data paths, script import outputs, preview inputs, and export inputs before unification

## Live Scrub Protection

This audit is read-only documentation. It does not authorize changing or rebuilding Stage5 Live Scrub.

Any future migration must preserve:

- fast Live Scrub,
- slow frame-accurate Live Scrub,
- reverse Live Scrub,
- deep zoom Live Scrub,
- current Stage5 native scrub quality.

### Protected Live Scrub Gate

Any future phase that passes near Live Scrub must obey this gate:

- Treat Stage5 Live Scrub as a protected boundary.
- Do not rewrite Stage5 Live Scrub as part of timeline, keyframe, transition, script, or motion-engine work.
- Do not touch Stage5 native scrub files unless the user explicitly approves that exact change.
- Prefer adapter-level integration around the scrub lifecycle.
- Verify fast scrub, slow scrub, reverse scrub, and deep zoom scrub after every related checkpoint.
- If a proposed engine change risks scrub responsiveness, stop and redesign before editing code.

This rule is repeated here intentionally so that Phase 0 cannot be misread as permission to migrate or rebuild Live Scrub.

## Current Time Writers

The current codebase has multiple writers or derived writers for the same timeline time concept. This is the root architectural reason playback, preview, scroll, scoped timelines, transitions, and keyframes can drift from each other.

### 1. Screen-Level Current Time

File:

- `lib/features/editor/presentation/screens/fusionx_clean_ui_screen.dart`

Current state:

- `_currentTime`
- `_setCurrentTime`

Current responsibility:

- Stores the editor timeline time.
- Updates display time.
- May update playback sample time when not playing native preview.

Risk:

- It can be updated independently from native transport samples and timeline scroll.

### 2. Timeline Display Time Notifier

File:

- `lib/features/editor/presentation/screens/fusionx_clean_ui_screen.dart`

Current state:

- `_timelineDisplayTimeNotifier`
- `_setTimelineDisplayTime`
- `_applyTimelineDisplayTime`

Current responsibility:

- Drives visible timeline time.
- Syncs transition focus and layer scope local notifiers.

Risk:

- It can be blocked by zoom locks or scrub handoff while native transport continues moving.

### 3. Playback Sample Time Notifier

File:

- `lib/features/editor/presentation/screens/fusionx_clean_ui_screen.dart`

Current state:

- `_playbackSampleTimeNotifier`
- `_setPlaybackSampleTime`

Current responsibility:

- Drives playback sample time for preview/scopes during native playback.

Risk:

- Preview can advance from playback samples while timeline display time is gated by scrub handoff, structural edit, trim preview, or scrub settling.

### 4. Native Transport Position

Files:

- `lib/core/engine/stage5_native_transport_controller.dart`
- `android/app/src/main/kotlin/com/fusionx/fusionx_clean_ui_2/Stage5TransportManager.kt`
- `android/app/src/main/kotlin/com/fusionx/fusionx_clean_ui_2/MainActivity.kt`

Current state:

- `Stage5TransportState.positionMs`
- native `buildState()["positionMs"]`
- method channel playback/seek/scrub commands

Current responsibility:

- Reports native playback position and scrub settle position.

Risk:

- Native position may arrive before/after Flutter display time changes.
- Raw samples can be stale relative to the user's latest scrub/play command.

### 5. TimelinePanel Local Display Time

File:

- `lib/features/editor/presentation/widgets/timeline_panel.dart`

Current state:

- `_displayTimeNotifier`
- `_setDisplayTime`
- `_applyReportedPlaybackSample`

Current responsibility:

- Draws the playhead/ruler/timeline at a local widget level.

Risk:

- It can be driven by widget `currentTime`, playback samples, internal ticker, native scrub callbacks, and zoom locks.

### 6. ScrollController Position

File:

- `lib/features/editor/presentation/widgets/timeline_panel.dart`

Current state:

- `_scrollController`
- `_driveScrollToTime`
- `_targetHorizontalOffsetForTime`
- `_effectiveHorizontalScrollOffset`

Current responsibility:

- Maps visible timeline content to the fixed playhead.

Risk:

- Scroll can become a second time source if it is not strictly derived from the clock.
- Visual-only follow can hide a mismatch instead of correcting it.

### 7. Native Scrub Surface

Files:

- `lib/features/editor/presentation/widgets/native_timeline_scrub_surface.dart`
- `lib/features/editor/presentation/widgets/timeline_panel.dart`
- `android/app/src/main/kotlin/com/fusionx/fusionx_clean_ui_2/Stage5TimelineScrubPlatformView.kt`

Current responsibility:

- Provides native optimized scrub input and preview handoff.

Risk:

- Its event lifecycle is not yet represented by one central clock state machine.
- Must be adapted carefully without weakening the existing Stage5 path.

### 8. Scoped Layer Time Projection

File:

- `lib/features/editor/presentation/screens/fusionx_clean_ui_screen.dart`

Current state:

- `_layerScopeDisplayTimeNotifier`
- `_layerScopePlaybackSampleTimeNotifier`
- `_layerScopeLocalTime`

Current responsibility:

- Converts global timeline time to selected layer local time.

Risk:

- Projection is currently synchronized from screen-level notifiers, not from a single clock contract.

### 9. Transition Scope Time Projection

File:

- `lib/features/editor/presentation/screens/fusionx_clean_ui_screen.dart`

Current state:

- `_transitionFocusDisplayTimeNotifier`
- `_transitionFocusPlaybackSampleTimeNotifier`
- `_transitionFocusLocalTime`

Current responsibility:

- Converts global timeline time to transition scope local time.

Risk:

- Transition keyframes/effects can drift if local scope time is not projected from the same global clock as playback.

### 10. Keyframe And Effect Evaluators

Files:

- `lib/features/editor/presentation/screens/fusionx_clean_ui_screen.dart`
- `lib/features/editor/presentation/widgets/timeline_transition_preview_overlay.dart`
- motion and transition authoring/evaluation services

Current responsibility:

- Evaluate animation/effect values for preview, scrub, playback, scoped timelines, and transitions.

Risk:

- If evaluators read different time inputs in preview/scrub/play/export, visible motion will not match timeline truth.

## Current Motion And Keyframe Data Paths

The current codebase already has pieces of a professional motion system, but they are not yet one canonical pipeline.

### 11. Motion Domain Graph

Files:

- `lib/features/editor/domain/models/professional_motion_models.dart`
- `lib/features/editor/domain/models/professional_motion_animation_models.dart`

Current state:

- `MotionProjectModel`
- `MotionSceneModel`
- `MotionLayerModel`
- `MotionElementModel`
- `MotionPropertyChannelModel`
- `MotionKeyframeModel`
- `MotionInterpolationSpec`

Current responsibility:

- Represents scenes, layers, elements, property channels, keyframes, and interpolation.

Risk:

- This is the correct long-term direction, but not all UI lanes, transitions, and script imports are canonical projections of this graph yet.

### 12. Canvas Timeline Authoring Service

File:

- `lib/features/editor/domain/models/professional_canvas_timeline_authoring_models.dart`

Current state:

- `ProfessionalCanvasTimelineAuthoringService`
- keyframe add/move/delete/value/interpolation requests
- property set requests with optional auto-key

Current responsibility:

- Provides a domain-level keyframe operation model for canvas/timeline properties.

Risk:

- This service is closer to the desired unified keyframe layer, but it is not yet the only path used by Layer Scope, Transition Scope, and script imports.

### 13. Timeline UI Animation Lanes

Files:

- `lib/features/editor/presentation/models/timeline_mock_models.dart`
- `lib/features/editor/presentation/widgets/timeline_panel.dart`

Current state:

- `TimelineAnimationLaneData`
- `normalizedKeyframeStops`
- `keyframeIds`
- `keyframeValues`
- timeline keyframe tap/drag callbacks

Current responsibility:

- Draws and edits visible keyframe lanes in the timeline UI.

Risk:

- This model is useful as a projection, but it must not remain a permanent source of truth separate from `MotionPropertyChannelModel`.
- Normalized stops and UI lane values can drift from domain keyframes unless all operations go through a shared keyframe service.

### 14. Layer Scope Keyframe Path

File:

- `lib/features/editor/presentation/screens/fusionx_clean_ui_screen.dart`

Current state examples:

- `_handleLayerScopeAddKeyframe`
- `_handleLayerScopeAnimationKeyframeTap`
- `_handleLayerScopeAnimationKeyframeDrag`
- `_handleLayerScopeMoveSelectedKeyframeToPlayhead`
- `_moveLayerScopeKeyframesToGraph`
- `_setLayerScopeKeyframeInterpolationToGraph`

Current responsibility:

- Bridges Layer Scope UI interaction to motion graph channels for supported layer properties.

Risk:

- It has real graph-backed behavior for some workflows, but the logic still lives heavily in the screen instead of a reusable unified keyframe operation layer.

### 15. Transition Domain And Authoring Path

Files:

- `lib/features/editor/domain/models/professional_normal_transition_models.dart`
- `lib/features/editor/domain/services/normal_transition_authoring_service.dart`
- `lib/features/editor/domain/services/normal_transition_command_history.dart`
- `lib/features/editor/presentation/services/normal_transition_timeline_adapter.dart`

Current state:

- `NormalTransitionNode`
- `NormalTransitionDefinition`
- `NormalTransitionInstance`
- `NormalTransitionChannelSpec`
- `NormalTransitionKeyframeSpec`
- `NormalTransitionCommandHistoryController`

Current responsibility:

- Models normal transitions, presets, instances, overlap windows, command history, and timeline adaptation.

Risk:

- This is a strong transition-specific domain, but it is not yet fully lowered into the same `MotionPropertyChannelModel` graph as layer motion.
- Transition Scope can still behave like a specialized timeline instead of a pure projection over the unified motion graph.

### 16. Transition Scope Manual Lane Path

File:

- `lib/features/editor/presentation/screens/fusionx_clean_ui_screen.dart`

Current state examples:

- `_transitionFocusSession`
- `_resolvedTransitionFocusManualLanes`
- `_updateTransitionFocusManualLane`
- `_handleTransitionFocusAnimationKeyframeTap`
- `_handleTransitionFocusAnimationKeyframeDrag`
- `_handleTransitionFocusAddKeyframe`
- `_transitionLaneLibrary`

Current responsibility:

- Draws and edits transition effect lanes in Transition Scope.

Risk:

- Keyframes may be real for transition preview, but this path must be unified with the same add/move/delete/value/interpolation semantics used by Layer Scope.
- The long-term target is for these lanes to be projections over canonical transition property channels.

### 17. Scoped Text Script Import Path

Files:

- `lib/features/editor/domain/services/scoped_text_motion_script_import_service.dart`
- `lib/features/editor/presentation/widgets/scoped_text_motion_script_bottom_sheet.dart`
- `lib/features/editor/presentation/screens/fusionx_clean_ui_screen.dart`

Current state:

- Text motion scripts can be validated and lowered into scoped text motion channels.

Current responsibility:

- Provides the first practical script-to-keyframes workflow.

Risk:

- The import path is text-specific.
- Lowering still depends on screen-level glue code.
- This must become a reusable `ReFusionSceneProgram` importer/lowerer rather than a text-only importer.

### 18. Normal Transition Script Import Path

Files:

- `lib/features/editor/domain/services/normal_transition_script_import_service.dart`
- `lib/features/editor/presentation/services/normal_transition_timeline_adapter.dart`

Current state:

- Transition scripts can be parsed into `NormalTransitionDefinition` and adapted for timeline use.

Current responsibility:

- Provides a transition-specific declarative import path.

Risk:

- This path is separate from scoped text scripts and separate from the main motion property graph.
- Imported transition channels must eventually lower into the same editable property channel model as other motion.

### 19. Motion Runtime Evaluation Path

Files:

- `lib/features/editor/domain/models/professional_motion_runtime_helpers.dart`
- `lib/features/editor/presentation/screens/fusionx_clean_ui_screen.dart`

Current state:

- `BasicMotionCompositionCompiler`
- `BasicMotionPropertyChannelSampler`
- `BasicMotionRuntimeEvaluator`
- `_motionCompositionForCurrentState`
- `_motionEvaluator`

Current responsibility:

- Compiles and evaluates motion data for preview/runtime snapshots.

Risk:

- The evaluator is the right shape, but every preview/effect/transition path must consume it or a shared normalized derivative.
- If transition preview or script preview bypasses this layer, preview/export parity remains fragile.

### 20. Export Composition Path

Files:

- `lib/features/editor/domain/models/export_composition_builder.dart`
- `lib/features/editor/domain/models/export_composition_models.dart`
- `lib/features/editor/presentation/screens/fusionx_clean_ui_screen.dart`

Current state:

- `ExportCompositionBuilder`
- `ExportComposition`
- `motionTextProgram`
- `authoredVisualSurfaceProgram`
- motion composition inputs

Current responsibility:

- Builds the export graph consumed by the native export pipeline.

Risk:

- Export is already substantial, but the professional target requires that preview and export consume the same normalized motion graph and interpolation semantics.
- Any UI-only effect or transition lane must become either export-backed or explicitly blocked.

## Phase 0 Expanded Findings

The first phase confirms that the app is not missing all professional pieces. It has many of them already:

- a timeline clock coordinator,
- a geometry mapper,
- a motion graph,
- a keyframe model,
- an authoring service,
- script importers,
- transition models,
- preview evaluators,
- export composition builders.

The problem is that these pieces are not yet a single enforced pipeline.

The unification target is:

```text
TimelineClockCoordinator
-> TimelineGeometryMapper
-> UnifiedKeyframeOperations
-> MotionPropertyChannelModel
-> MotionRuntimeEvaluator
-> ExportComposition
```

Script import, transition authoring, Layer Scope, and future AI-generated scenes must all feed this same pipeline.

## Phase 0 Conclusion

The jump and keyframe inconsistencies are not isolated button bugs. The current architecture allows multiple time, geometry, keyframe, transition, and script-output paths to compete or bypass each other.

The next safe implementation step is Phase 1/2 hardening of the clock and geometry foundation, followed by Phase 5 unified keyframe operations:

- keep `TimelineClockCoordinator` as the time owner,
- keep `TimelineGeometryMapper` as the geometry owner,
- adapt Live Scrub through lifecycle commands only,
- create a reusable unified keyframe operation layer,
- lower UI lanes and imported scripts into canonical motion channels,
- do not rewrite or weaken Stage5 Live Scrub.
