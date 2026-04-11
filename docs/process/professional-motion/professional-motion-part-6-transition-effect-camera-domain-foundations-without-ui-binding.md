# Professional Motion Part 6 - Transition / Effect / Camera Domain Foundations Without UI Binding

## Status

- document type: implementation slice reference
- execution status: active foundation slice
- scope type: internal domain/runtime foundation only

## Purpose

This slice adds the missing motion domains required before a professional text
preset can become real later:

- transitions
- effects
- camera bindings

It also connects those domains to normalized composition and runtime-evaluation
foundation layers.

## Scope

This slice is allowed to add only:

- transition domain models
- effect domain models
- camera binding domain models
- resolved composition support for those domains
- evaluation-state support for those domains
- helper projection support for those domains

This slice must not add yet:

- current UI controls
- text preset UI
- preview binding
- export binding
- final transition/effect execution engines

## Output

Primary code output:

- [professional_motion_fx_models.dart](/Users/mx/Documents/InGeneBMFPro/sources/ui/fusionx-clean-ui-2/lib/features/editor/domain/models/professional_motion_fx_models.dart)

## What This Unlocks

After this slice, the motion architecture is no longer missing the major domain
families needed by text presets.

That means the remaining work before the first real text preset stage is now
smaller and more focused.

## Acceptance Gate

This slice is accepted only if:

- the project still analyzes/builds successfully
- no current timeline behavior changes
- transitions/effects/camera are now represented as first-class motion domains

## Remaining Distance To First Text Preset Stage

After Part 6, the remaining major internal slices before the first real
text-preset runtime-ready stage are:

1. text-animation and text-preset domain foundations
2. text-preset compile/runtime binding without UI

UI hookup would still come after that.
