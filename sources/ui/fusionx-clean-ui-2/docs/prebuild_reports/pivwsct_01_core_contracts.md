# PIVWSCT-01 Core Contracts

Slice: `PIVWSCT-01`  
Plan: `professional_in_app_virtual_project_workspace_single_creative_truth_plan.md`  
Date: `2026-05-15`

## Goal

Define canonical domain contracts for single creative truth transactions without
changing runtime behavior yet.

## Implemented Contracts

File:
`lib/features/editor/domain/models/creative_transaction_contract_models.dart`

Added:

1. `CreativeTransactionEnvelope`
2. `CreativeTransactionOperation`
3. `CreativeTransactionSource`
4. `CreativeTransactionIntent`
5. `CreativeTargetRef`
6. `CreativeApplyProof`
7. `CreativeProofLevel`
8. `CreativeWorkspaceSnapshot`
9. `CreativeCompositionSpec`
10. `CreativeLayerIdentity`
11. `CreativeLayerAlias`
12. `LegacyPathCleanupRecord`
13. `LegacyPathCleanupDecision`

## Validation Rules Added

1. `compositionId` is required.
2. `projectId` is required.
3. `transactionId` is required.
4. `schemaVersion` must be positive.
5. `operations` must not be empty.
6. update/delete/motion/effect/select intents require explicit target identity.

## Scope Confirmation

This slice is domain-only and does not change:

1. Live Scrub paths.
2. Stage5 renderer internals.
3. MCP network behavior.
4. UI mutation flow.

## Tests Added

File:
`test/creative_transaction_contract_models_test.dart`

Covers:

1. valid transaction accepted.
2. missing composition rejected.
3. update without target rejected.
4. source enum coverage for manual/mcp/script/template/import/migration.
5. deterministic proof level ordering.
6. legacy cleanup record requires explicit valid decision data.

## Acceptance Mapping

```text
transaction_schema_validation_pass = true
update_without_target_rejected = true
legacy_cleanup_record_required = true
```

## Notes

The next slice can now build workspace snapshots (`PIVWSCT-02`) on top of these
contracts without introducing a second write model.
