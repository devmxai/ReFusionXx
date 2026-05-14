# PIVWSCT-12 Legacy Code Deletion And Bypass Guards

Slice: `PIVWSCT-12`  
Plan: `professional_in_app_virtual_project_workspace_single_creative_truth_plan.md`  
Date: `2026-05-15`

## Mandatory Pre-Build Evaluation And User Sync Gate

### Current ReFusion state

1. Historic screen-level apply paths still exist in codebase and can regress if
   called accidentally.
2. Needed a strict guard rail to block bypass writes outside canonical
   transaction engine for migrated slices.

### Decision

`upgrade + block`  
Introduce explicit runtime bypass guards and legacy cleanup registry contracts.
Delete-by-flag behavior is postponed until each callsite is fully migrated, but
runtime guard now blocks forbidden paths.

## Implemented

File:
`lib/features/editor/domain/services/legacy_creative_mutation_bypass_guard.dart`

Added:

1. `LegacyMutationBypassViolation`
2. `LegacyPathCleanupRegistry`
3. `LegacyCreativeMutationBypassGuard`
4. `LegacyMutationPatternScanner`
5. `LegacyMutationPatternScanResult`

Guard behavior:

1. blocks write attempts not passing through canonical transaction engine.
2. blocks explicitly registry-marked legacy paths.
3. provides scan counts for risky legacy pattern categories.

## Tests

File:
`test/legacy_creative_mutation_bypass_guard_test.dart`

Coverage:

1. canonical transaction route is allowed.
2. direct legacy bypass path throws.
3. registry-blocked path throws.
4. pattern scanner detects legacy risk signatures.

## Acceptance Mapping

```text
parallel_truth_path_count = guarded for migrated slices
insert_used_as_update_count = scanner-visible + guardable
metadata_only_visual_success_count = scanner-visible + guardable
legacy_mutation_callsite_count = now measurable by scanner patterns
```

## Scope Confirmation

No Live Scrub files touched.  
No Stage5 files touched.  
No destructive deletion of protected paths in this slice; runtime block added.

