# PIVWSCT-05 Unified Apply Engine Skeleton

Slice: `PIVWSCT-05`  
Plan: `professional_in_app_virtual_project_workspace_single_creative_truth_plan.md`  
Date: `2026-05-15`

## Goal

Create the first unified write engine skeleton so transaction-based writes can
mutate one creative state atomically instead of scattered per-source paths.

## Implemented

File:
`lib/features/editor/domain/services/unified_creative_apply_engine.dart`

Added:

1. `CreativeApplyContext`
2. `CreativeAtomicMutationScope`
3. `CreativeRevisionManager`
4. `CreativeApplyLedger` + `CreativeApplyLedgerEntry`
5. `CreativeApplyResult`
6. Runtime graph/timeline models:
   - `UnifiedCreativeLayerNode`
   - `UnifiedCreativeTimelineClip`
   - `UnifiedCreativeState`
7. `UnifiedCreativeApplyEngine.apply(...)` with:
   - validator + dry-run gate
   - fail-closed on invalid transactions
   - atomic draft mutation
   - deterministic revision increment
   - ledger entry append

Initial operation coverage:

1. `background.set_solid`
2. `shape.insert`
3. `text.insert`
4. `text.update_content`
5. `transform.patch`
6. `layer.select`

## Design Notes

1. Background apply canonicalizes to active composition dimensions through the
   context spec (`width`/`height`) even if payload carries square values.
2. Update intents mutate existing target nodes only; invalid update targets fail
   through validator and do not mutate revision.
3. Engine currently lives at domain-service level only; no UI/renderer wiring
   in this slice.

## Tests

File:
`test/unified_creative_apply_engine_test.dart`

Covers:

1. background insert creates layer + timeline clip + full-canvas bounds.
2. text insert creates a single deterministic layer id.
3. text update mutates same layer id and does not increase layer count.
4. transform patch mutates current node bounds.
5. failed update leaves revision unchanged.

## Acceptance Mapping

```text
atomic_apply_pass = true (tests green)
text_update_duplicate_count = 0 (same layer id update)
background_full_canvas_bounds = true (1080x1920 preserved)
failed_apply_mutation_count = 0 (revision unchanged on failure)
```

## Scope Confirmation

No Live Scrub files touched.  
No Stage5 files touched.  
No renderer behavior changes in this slice.

