# PIVWSCT-07 Local MCP Resource And Transaction API

Slice: `PIVWSCT-07`  
Plan: `professional_in_app_virtual_project_workspace_single_creative_truth_plan.md`  
Date: `2026-05-15`

## Mandatory Pre-Build Evaluation And User Sync Gate

### Current ReFusion state

1. MCP read/write behavior still relies on mixed legacy adapters and screen-level
   apply paths.
2. PIVWSCT-05 and PIVWSCT-06 established canonical transaction contracts and
   manual transaction generation, but MCP still needed a local API surface
   anchored to the same workspace/apply engine.

### HyperFrames / Remotion comparison

1. HyperFrames workflow succeeds when the authoring surface reads one project
   truth and patches stable targets.
2. Remotion workflow succeeds when updates are deterministic by composition
   identity and props state.
3. ReFusion parity requirement: MCP must read from one workspace snapshot and
   write via one transaction engine, with deterministic target/proof output.

### Decision

`upgrade`  
Add a local MCP transaction API that reuses:
workspace snapshot builder, target resolver, validator/dry-run, unified apply
engine. No direct calls to legacy apply paths.

## Implemented

File:
`lib/features/editor/domain/services/local_mcp_transaction_api.dart`

Added:

1. `LocalMcpTransactionApi.readSnapshot(...)`
2. `LocalMcpTransactionApi.validateTransaction(...)`
3. `LocalMcpTransactionApi.dryRunTransaction(...)`
4. `LocalMcpTransactionApi.resolveTarget(...)`
5. `LocalMcpTransactionApi.applyTransaction(...)`
6. `LocalMcpApplyResponse`
7. Structured proof builder that includes target ids and operation kind.

Rules enforced by this slice:

1. MCP reads come from `InAppVirtualProjectWorkspaceSnapshot`.
2. MCP writes run through `UnifiedCreativeApplyEngine`.
3. Validation/dry-run happen through canonical validator services.
4. Proof payload keeps explicit `targetLayerId` and operation identity.

## Tests

File:
`test/local_mcp_transaction_api_test.dart`

Covers:

1. MCP reads current Story composition dimensions from snapshot.
2. MCP background insert applies Story bounds (1080x1920) even from square
   payload.
3. MCP text insert then update keeps same layer count.
4. MCP effect/motion-style update requires target identity.
5. MCP apply proof includes target layer id and operation identity.

## Acceptance Mapping

```text
mcp_resource_snapshot_freshness = true (snapshot-based reads)
mcp_write_bypass_count = 0 (writes route through unified apply engine)
mcp_update_duplicate_count = 0 (insert+update test keeps layer count stable)
mcp_composition_size_mismatch_count = 0 (background canonical bounds in test)
```

## Scope Confirmation

No Live Scrub files touched.  
No Stage5 files touched.  
No renderer wiring changes in this slice.

