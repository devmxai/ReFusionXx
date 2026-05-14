# PIVWSCT-04 Transaction Validator And Dry Run

Slice: `PIVWSCT-04`  
Plan: `professional_in_app_virtual_project_workspace_single_creative_truth_plan.md`  
Date: `2026-05-15`

## Goal

Enable deterministic transaction validation and dry-run normalization before
real state mutation.

## Implemented

File:
`lib/features/editor/domain/services/creative_transaction_validator.dart`

Added:

1. `CreativeTransactionConflictPolicy`
2. `CreativeTransactionValidationContext`
3. `CreativeTransactionValidationResult`
4. `CreativeTransactionDiff`
5. `CreativeTransactionDryRunResult`
6. `CreativeTransactionValidator`
7. `CreativeTransactionDryRunEngine`

Validation coverage:

1. composition id must match open composition.
2. base revision conflicts are explicit and policy-driven.
3. update/delete/motion/effect intent respects target requirements from envelope.
4. insert with target requires explicit duplicate mode.
5. motion/effect/keyframe intents require renderer capability declaration.

Dry-run coverage:

1. background payload bounds normalize to open composition bounds.
2. normalization is reflected in `CreativeTransactionDiff`.
3. dry-run returns normalized envelope without mutating runtime state.

## Tests

File:
`test/creative_transaction_validator_test.dart`

Covers:

1. wrong composition id reject.
2. stale revision reject.
3. stale revision allowed under explicit rebase policy.
4. background square payload normalized to full composition bounds.
5. update without target reject.
6. insert with target reject unless duplicate mode enabled.

## Acceptance Mapping

```text
invalid_transaction_block_rate = true (test coverage)
dry_run_no_mutation = true (contract-level dry-run)
composition_spec_enforced = true
```

## Scope Confirmation

No Live Scrub/Stage5 path changes.  
No renderer behavior mutation.  
No MCP transport rewiring in this slice.
