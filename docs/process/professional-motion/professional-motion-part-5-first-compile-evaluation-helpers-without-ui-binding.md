# Professional Motion Part 5 - First Compile / Evaluation Helpers Without UI Binding

## Status

- document type: implementation slice reference
- execution status: active foundation slice
- scope type: internal helper implementation only

## Purpose

This slice converts the previous motion foundations from static models into the
first usable helper layer.

It introduces:

- a basic composition compiler
- a basic property-channel sampler
- a basic runtime evaluator

without binding any of that to:

- the current timeline UI
- the current preview/runtime transport
- export
- motion authoring UI

## Scope

This slice is allowed to add only:

- first compile helper implementations
- first property-sampling helper implementations
- first runtime-evaluation helper implementations
- minimal domain-model adjustments required by those helpers

This slice must not add yet:

- preview integration
- export integration
- keyframe UI
- motion script parser
- transition engine implementation
- effect engine implementation

## Output

Primary code output:

- [professional_motion_runtime_helpers.dart](/Users/mx/Documents/InGeneBMFPro/sources/ui/fusionx-clean-ui-2/lib/features/editor/domain/models/professional_motion_runtime_helpers.dart)

## What It Provides

This slice introduces:

- `BasicMotionCompositionCompiler`
- `BasicMotionPropertyChannelSampler`
- `BasicMotionRuntimeEvaluator`

Current intended behavior:

- deterministic helper behavior
- static/property-channel resolution at time `t`
- first compile path from project domain to normalized composition
- no dependency on current editor UI or transport stack

## Guardrails

- current app behavior must remain unchanged
- current timeline precision baseline must remain untouched
- helper implementations are internal only
- unsupported advanced interpolation is allowed to remain simplified for now

## Acceptance Gate

This slice is accepted only if:

- the project still analyzes/builds successfully
- no current timeline behavior changes
- the motion architecture is no longer only declarative, but now has first
  working helper implementations

## Next Slice

If this slice is accepted, the next legal motion slice is:

- transition/effect/camera foundations or script normalization helpers, still
  without UI binding
