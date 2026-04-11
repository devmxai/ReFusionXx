# Professional Motion Part 1 - Canonical Scene / Layer / Element / Property Domain Models

## Status

- document type: implementation slice reference
- execution status: active foundation slice
- scope type: internal architecture only

## Purpose

This slice introduces the first real code foundation for `Professional Motion`
without changing:

- the current timeline UI
- the current editing UX
- the current preview/runtime ownership
- the accepted `Stage 6` precision baseline

## Scope

This slice is allowed to add only:

- canonical project/scene/layer/element models
- canonical property target and property definition models
- canonical project format and frame-rate models
- canonical source binding models

This slice must not add yet:

- keyframes
- interpolation
- transition execution
- effect execution
- camera runtime logic
- preview integration
- UI controls for motion authoring

## Output

Primary code output:

- [professional_motion_models.dart](/Users/mx/Documents/InGeneBMFPro/sources/ui/fusionx-clean-ui-2/lib/features/editor/domain/models/professional_motion_models.dart)

## Non-Negotiable Rules

- current timeline truth remains untouched
- current Flutter/native preview contract remains untouched
- no runtime behavior change is allowed
- no second timeline truth may appear
- all new models must anchor to existing canonical `TimelineTime`

## Acceptance Gate

This slice is accepted only if:

- the project still analyzes/builds successfully
- no UI/runtime behavior changes are introduced
- the new domain model is clearly separated from the current clip editor model

## Next Slice

If this slice is accepted, the next legal motion slice is:

- property channels and first keyframe primitives
