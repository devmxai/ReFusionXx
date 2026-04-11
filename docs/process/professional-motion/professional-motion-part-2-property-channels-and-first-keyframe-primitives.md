# Professional Motion Part 2 - Property Channels And First Keyframe Primitives

## Status

- document type: implementation slice reference
- execution status: active foundation slice
- scope type: internal animation architecture only

## Purpose

This slice adds the first motion-animation primitives above the canonical
scene/layer/element/property domain introduced in Part 1.

This slice is still internal-only and must not change:

- current timeline UI
- current editing UX
- current preview/runtime ownership
- current accepted `Stage 6` precision baseline

## Scope

This slice is allowed to add only:

- property channel models
- keyframe models
- interpolation metadata models
- channel extrapolation metadata

This slice must not add yet:

- runtime value evaluation
- keyframe UI
- motion script parsing
- transition/effect execution
- camera runtime behavior
- preview binding

## Output

Primary code output:

- [professional_motion_animation_models.dart](/Users/mx/Documents/InGeneBMFPro/sources/ui/fusionx-clean-ui-2/lib/features/editor/domain/models/professional_motion_animation_models.dart)

## Added Primitives

This slice introduces:

- `MotionInterpolationKind`
- `MotionChannelExtrapolationMode`
- `MotionBezierControlPoints`
- `MotionSpringSpec`
- `MotionInterpolationSpec`
- `MotionKeyframeModel`
- `MotionPropertyChannelModel`

## Rules

- all keyframe times must use canonical `TimelineTime`
- channel value kinds must match property-definition kinds
- channels remain authoring/runtime foundation only for now
- no existing clip/timeline state may be replaced by these models yet

## Acceptance Gate

This slice is accepted only if:

- the project still analyzes/builds successfully
- no current timeline behavior changes
- the animation primitives remain clearly separated from current runtime paths

## Next Slice

If this slice is accepted, the next legal motion slice is:

- normalized motion-composition structure and compile-boundary foundations
