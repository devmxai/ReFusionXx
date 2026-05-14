# PIVWSCT-06 Manual UI Adapter Migration

Slice: `PIVWSCT-06`  
Plan: `professional_in_app_virtual_project_workspace_single_creative_truth_plan.md`  
Date: `2026-05-15`

## Mandatory Pre-Build Evaluation And User Sync Gate

### Current ReFusion state

1. Manual UI writes still happen in scattered per-feature handlers inside
   `fusionx_clean_ui_screen.dart`.
2. PIVWSCT-05 introduced the first unified apply engine, but Manual UI had no
   dedicated transaction adapter yet.
3. This gap keeps identity/update semantics split between direct UI writes and
   canonical transaction paths.

### HyperFrames / Remotion comparison

1. HyperFrames: edits are stable-target patches (selector identity) and updates
   mutate existing nodes instead of ad-hoc re-insert.
2. Remotion: composition/component identity is stable; changes flow through
   props updates on the same identity.
3. ReFusion target: Manual UI must emit canonical transactions carrying explicit
   target identity for update flows.

### Decision

`upgrade`  
Build a Manual UI → Canonical Transaction adapter now, then wire incrementally.
No renderer or Live Scrub changes in this slice.

## Implemented

File:
`lib/features/editor/domain/services/manual_ui_creative_transaction_adapter.dart`

Added:

1. `ManualUiTransactionCommandKind`
2. `ManualUiTransactionDraft`
3. `ManualUiTransactionBuildContext`
4. `ManualUiCreativeTransactionAdapter.toEnvelope(...)`

Migrated command taxonomy (transaction generation):

1. `addBackgroundSolid` → `backgroundSetSolid`
2. `addText` → `textInsert`
3. `addShape` → `shapeInsert`
4. `selectLayer` → `layerSelect`
5. `moveLayer` / `resizeLayer` / `rotateLayer` / `setOpacity` →
   `transformPatch`
6. `setFillColor` → `layerUpdate`
7. `editTextContent` → `textUpdateContent`

Normalization rules:

1. proof level defaults to renderer.
2. idempotency key and transaction id are deterministic per manual sequence.
3. color payload is normalized to canonical `#RRGGBB`.
4. update-style commands carry `target.layerId` identity.

## Tests

File:
`test/manual_ui_creative_transaction_adapter_test.dart`

Coverage:

1. background command maps to `backgroundSetSolid`.
2. text insert maps to `textInsert`.
3. text edit maps to `textUpdateContent` with target identity.
4. fill color maps to `layerUpdate` + normalized color.
5. move/resize/rotate/opacity map to `transformPatch`.
6. select maps to `layerSelect`.

## Acceptance Mapping

```text
manual_ui_transaction_route_coverage = established for migrated adapter intents
manual_update_target_identity = enforced by adapter target mapping
manual_insert_vs_update_semantics = explicit at transaction intent level
```

## Scope Confirmation

No Live Scrub files touched.  
No Stage5 files touched.  
No renderer path changes in this slice.

