# Professional Motion Part 3 - Normalized Motion Composition And Compile Boundary Foundations

## Status

- document type: implementation slice reference
- execution status: active foundation slice
- scope type: internal normalization architecture only

## Purpose

This slice introduces the compile-boundary foundation that separates:

- high-level authoring truth
- from normalized runtime composition truth

This is the layer that will later protect preview and render backends from
reading raw editor or script state directly.

## Scope

This slice is allowed to add only:

- compile request/options models
- compile issue models
- normalized composition models
- resolved scene/layer/element models
- resolved channel models
- compiler interface foundation

This slice must not add yet:

- actual compile implementation logic
- runtime evaluator
- preview binding
- export binding
- keyframe UI
- script parser

## Output

Primary code output:

- [professional_motion_compilation_models.dart](/Users/mx/Documents/InGeneBMFPro/sources/ui/fusionx-clean-ui-2/lib/features/editor/domain/models/professional_motion_compilation_models.dart)

## Added Primitives

This slice introduces:

- `MotionAuthoringOrigin`
- `MotionCompileOptions`
- `MotionCompileRequest`
- `MotionCompileIssue`
- `MotionResolvedPropertyChannel`
- `MotionResolvedElementModel`
- `MotionResolvedLayerModel`
- `MotionResolvedSceneModel`
- `MotionNormalizedComposition`
- `MotionCompileResult`
- `MotionCompositionCompiler`

## Rules

- compile-boundary models must remain independent from current runtime transport
- normalized composition must consume canonical `TimelineTime`
- preview/export must later consume normalized composition, not raw editor UI state
- this slice must not change any current app behavior

## Acceptance Gate

This slice is accepted only if:

- the project still analyzes/builds successfully
- no current timeline behavior changes
- the compile-boundary layer is now explicit in code, not only in documentation

## Next Slice

If this slice is accepted, the next legal motion slice is:

- first deterministic runtime evaluation foundations
