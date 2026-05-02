# Master Clock Value Truth Inventory

Status: phase-0 inventory baseline
Date: 2026-05-02
Plan: `docs/master_clock_value_truth_foundation_plan.md`

## Scope

This inventory captures current time and value sources before full migration
into one master truth chain:

```text
MasterTimeSnapshot
-> TimeDomainMapper
-> KeyframeEvaluator
-> ValueTruthRegistry
-> MasterFrameEvaluation
```

## 1) Time Readers In Flutter Editor

Primary editor time holders:

- `lib/features/editor/presentation/screens/fusionx_clean_ui_screen.dart`
  - `_currentTime`
  - `_timelineDisplayTimeNotifier`
  - `_playbackSampleTimeNotifier`
  - `_timelineClockCoordinator`
- `lib/features/editor/presentation/widgets/timeline_panel.dart`
  - `_displayTimeNotifier`
  - optional `playbackSampleTimeListenable`

Observed patterns:

- `_displayTimeNotifier` appears as a local timeline display state.
- `_playbackSampleTimeNotifier` appears as a playback sample state.
- root/scope local projection calls are spread between:
  - `SceneScopeSession.rootToLocal(...)`
  - `SceneLayerScopeTimelineViewModel.rootToLocal(...)`
  - `CompositionSceneClipModel.rootToLocalTime(...)`

## 2) DateTime/Stopwatch Sources

Observed `DateTime.now()` in editor/runtime code:

- `lib/features/editor/presentation/widgets/ai_transition_bottom_sheet.dart`
- `lib/features/editor/presentation/widgets/timeline_panel.dart`
- `lib/features/editor/presentation/screens/fusionx_clean_ui_screen.dart`
- several non-preview utility/service files (IDs, agent timing, export metrics)

Observed `Stopwatch` in timeline engine:

- `lib/features/editor/domain/services/timeline_clock_coordinator.dart`
  - used for monotonic commit metadata only.

## 3) Native Time Sources

Native timing/position entry points currently live in Stage5 native transport:

- `Stage5TransportManager` (`currentPosition`, `positionMs` paths)
- `Stage5NativeScrubEngine` (`positionMs` scrub/settle paths)
- `Stage5TimelineScrubPlatformView`
- `MainActivity` platform-channel `positionMs` arguments

This foundation does not edit those files.

## 4) Transition Time/Progress Sources

Manual transition progress and lane-value reads currently appear in:

- `lib/features/editor/presentation/widgets/timeline_transition_preview_overlay.dart`
  - `manualLaneValueAtProgress(...)`
- `lib/features/editor/presentation/screens/fusionx_clean_ui_screen.dart`
  - transition focus and seam-local progress helpers

The new `MasterTimeDomainMapper` must own transition progress mapping policy.

## 5) Keyframe Evaluation Sources

Keyframe value semantics currently come from:

- `MotionPropertyChannelModel` + `MotionKeyframeModel`
- interpolation helpers in
  `lib/features/editor/domain/models/professional_motion_interpolation_evaluator.dart`
- channel access and mutations in:
  - `UnifiedKeyframeOperations`
  - scope adapters (`LayerScopeCompositionAdapter`, transition adapters)

## 6) Value Mapping Sources

Value meanings are currently distributed:

- Motion property catalog defaults (`MotionPropertyCatalog`)
- UI-specific editor controls (percent/sliders/paired edits)
- renderer-side effect parameters (blur/scale/opacity style mappings)

This baseline introduces one explicit registry:

- `MasterValueTruthRegistry`

## 7) Migration Baseline Decisions

Accepted baseline:

- `TimelineClockCoordinator` is the mutable clock owner.
- timeline display/sample notifiers remain temporarily as derived views.
- native transport remains untouched in this foundation.

Migration targets:

- all frame reasoning goes through `MasterTimeSnapshot`.
- all time-domain mapping goes through `MasterTimeDomainMapper`.
- all authored values map through `MasterValueTruthRegistry`.
- all channel evaluation goes through `MasterKeyframeValueEvaluator`.
- all read-only per-frame truth is emitted as `MasterFrameEvaluation`.

## 8) Guardrail Baseline

A scoped lint guard script now protects preview-time clock sources:

- `scripts/master_clock_guard_check.sh`
- `docs/master_clock_guard_allowlist.txt`

This first gate is baseline-only and blocks new unapproved preview-time clock
sources.
