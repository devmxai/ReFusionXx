# PIVWSCT-03 Target Resolver Foundation

Slice: `PIVWSCT-03`  
Plan: `professional_in_app_virtual_project_workspace_single_creative_truth_plan.md`  
Date: `2026-05-15`

## Goal

Provide deterministic target resolution before broad write migration, so updates
cannot silently become insertions or selected-layer guesses.

## Implemented

File:
`lib/features/editor/domain/services/creative_target_resolver.dart`

Added:

1. `CreativeTargetResolver`
2. `CreativeTargetResolutionRequest`
3. `CreativeTargetResolution`
4. `CreativeTargetResolutionResult`
5. `CreativeTargetAmbiguityDiagnostic`
6. `CreativeLayerAliasIndex`

Resolution order implemented:

1. canonical `layerId`
2. `transactionCreatedLayerId`
3. alias exact match
4. selected layer request
5. explicit user mention layer id
6. text query single match
7. spatial single match
8. block or missing target

Safety behavior:

1. selected fallback is blocked unless explicitly allowed.
2. multi-candidate text/spatial matches return ambiguity.
3. unresolved target returns missing target.

## Tests

File:
`test/creative_target_resolver_test.dart`

Covers:

1. remote alias resolves to canonical layer id.
2. target layer id resolves after previous insert.
3. ambiguous same text blocks.
4. missing update target blocks.
5. selected fallback blocked unless requested.
6. spatial single match resolves.
7. spatial multiple matches block as ambiguous.

## Acceptance Mapping

```text
update_target_resolution_pass = true
ambiguous_target_insert_count = 0 (resolver-level contract)
implicit_selected_fallback_count = 0 (resolver-level contract)
```

## Scope Confirmation

No Live Scrub/Stage5 modifications.  
No renderer behavior changes.  
No MCP transport behavior changes in this slice.
