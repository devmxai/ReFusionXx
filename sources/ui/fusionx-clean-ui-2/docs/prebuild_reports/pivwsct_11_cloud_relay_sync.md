# PIVWSCT-11 Cloud/Supabase Downgrade To Relay And Sync

Slice: `PIVWSCT-11`  
Plan: `professional_in_app_virtual_project_workspace_single_creative_truth_plan.md`  
Date: `2026-05-15`

## Mandatory Pre-Build Evaluation And User Sync Gate

### Current ReFusion state

1. Cloud state could appear as local truth and block/blur visible success timing.
2. Local-first transaction semantics needed strict relay policy.

### HyperFrames / Remotion comparison

1. Reference systems resolve local scene truth first, then serialize/export/sync.
2. ReFusion parity requirement: cloud mirrors local proof, never declares visual
   success alone.

### Decision

`upgrade`  
Add cloud relay coordinator contracts that enforce local-first apply and forbid
cloud-only appApplied success without app proof ledger.

## Implemented

File:
`lib/features/editor/domain/services/cloud_transaction_relay_sync.dart`

Added:

1. `CloudRelayCommand`
2. `LocalEditRelayDecision`
3. `CloudAppAppliedRecord`
4. `CloudRelaySyncCoordinator`

Rules:

1. local edit does not wait for cloud polling before visible success.
2. cloud command is relay envelope of canonical transaction.
3. cloud appApplied requires matching renderer proof ledger entry.

## Tests

File:
`test/cloud_transaction_relay_sync_test.dart`

Coverage:

1. local command path is local-first and cloud-nonblocking.
2. remote cloud command relays canonical transaction intact.
3. cloud-only appApplied row is rejected.
4. appApplied accepted only with app proof ledger match.

## Acceptance Mapping

```text
local_edit_cloud_wait_count = 0
cloud_command_apply_bypass_count = 0 (relay contract)
cloud_app_applied_without_proof_count = 0
```

## Scope Confirmation

No Live Scrub files touched.  
No Stage5 files touched.  
No direct bridge rewiring in this slice (contract/test foundation only).

