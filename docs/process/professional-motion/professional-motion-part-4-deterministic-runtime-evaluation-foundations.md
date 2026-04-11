# Professional Motion Part 4 - Deterministic Runtime Evaluation Foundations

## Status

- document type: implementation slice reference
- execution status: active foundation slice
- scope type: internal runtime-evaluation architecture only

## Purpose

This slice introduces the first explicit runtime-evaluation foundation for the
future motion system.

Its purpose is to define, in code, the shape of the answer to:

- what is active at time `t`
- what property values resolve at time `t`
- what transition/effect state resolves at time `t`

without binding any of that yet to preview, export, or UI.

## Scope

This slice is allowed to add only:

- evaluation request models
- evaluation snapshot/state models
- property sampling interface
- runtime evaluator interface
- diagnostics models

This slice must not add yet:

- full interpolation implementation
- evaluator implementation
- preview integration
- export integration
- transition engine implementation
- effect engine implementation

## Output

Primary code output:

- [professional_motion_evaluation_models.dart](/Users/mx/Documents/InGeneBMFPro/sources/ui/fusionx-clean-ui-2/lib/features/editor/domain/models/professional_motion_evaluation_models.dart)

## Added Primitives

This slice introduces:

- `MotionEvaluationRequest`
- `MotionEvaluationDiagnostic`
- `MotionEvaluatedPropertyValue`
- `MotionEvaluatedElementState`
- `MotionEvaluatedLayerState`
- `MotionEvaluatedSceneState`
- `MotionTransitionEvaluationState`
- `MotionEffectEvaluationState`
- `MotionEvaluationSnapshot`
- `MotionPropertyChannelSampler`
- `MotionRuntimeEvaluator`

## Rules

- evaluation must remain deterministic and time-based
- all evaluation time must use canonical `TimelineTime`
- evaluation models must consume normalized composition, not raw UI state
- this slice must not change the current app runtime behavior

## Acceptance Gate

This slice is accepted only if:

- the project still analyzes/builds successfully
- no current timeline behavior changes
- runtime evaluation is now represented in code as an explicit architecture layer

## Next Slice

If this slice is accepted, the next legal motion slice is:

- first concrete compile/evaluation implementation helpers, still without UI
