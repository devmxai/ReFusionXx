# PIVWSCT-08 Scene, Script, Template, Import Adapter Migration

Slice: `PIVWSCT-08`  
Plan: `professional_in_app_virtual_project_workspace_single_creative_truth_plan.md`  
Date: `2026-05-15`

## Mandatory Pre-Build Evaluation And User Sync Gate

### Current ReFusion state

1. Script/template/import authoring can still emit payloads that differ from
   MCP/manual transaction semantics.
2. This causes cross-surface identity drift and duplicate behavior risk.

### HyperFrames / Remotion comparison

1. HyperFrames keeps patch targets stable across generation and editing.
2. Remotion keeps compositional identity deterministic across prop changes.
3. ReFusion parity requirement: generated content from script/template/import
   must produce app-owned stable layer identities and canonical transaction
   intents before runtime apply.

### Decision

`upgrade`  
Add a shared compiler that lowers non-UI/non-MCP authoring surfaces into
canonical transaction envelopes with stable layer ids.

## Implemented

File:
`lib/features/editor/domain/services/authoring_surface_transaction_compiler.dart`

Added:

1. `AuthoringSurfaceSource`
2. `AuthoringSurfaceBuildContext`
3. `AuthoringLayerSpec`
4. `AuthoringSurfaceTransactionCompiler.compile(...)`

Key behavior:

1. Generates app-owned stable layer ids:
   `app.<source>.<sourceNodeId>`
2. Lowers inserts to canonical intents:
   `backgroundSetSolid`, `textInsert`, `shapeInsert`, `layerInsert`.
3. Lowers optional recipe/effect to:
   `animationApplyRecipe`, `effectApply`.
4. Keeps target identity chain stable for insert + later animation/effect
   transactions.

## Tests

File:
`test/authoring_surface_transaction_compiler_test.dart`

Coverage:

1. stable app-owned layer ids for scene/template sources.
2. text insert + animation + effect preserve the same target layer id.
3. media import lowers to `layerInsert` while preserving source alias.

## Acceptance Mapping

```text
script_template_import_bypass_count = reduced (canonical transaction compiler exists)
cross_surface_identity_stability = true for compiler-generated transactions
animation_effect_target_chain = true for generated layers
```

## Scope Confirmation

No Live Scrub files touched.  
No Stage5 files touched.  
No renderer wiring changes in this slice.

