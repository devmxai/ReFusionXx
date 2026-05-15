# PLFPW-00 Current Truth Audit

Slice: `PLFPW-00`  
Plan: `professional_local_first_project_workspace_migration_closure_plan.md`  
Date: `2026-05-16`  
Package: `com.refusion.app`

## Goal

Establish a strict baseline of active MCP/apply/proof paths before any behavior
migration, and classify every known legacy execution path with explicit cleanup
ownership for the migration slices.

## Mandatory Inputs Reviewed

1. `docs/professional_local_first_project_workspace_migration_closure_plan.md`
2. `docs/professional_checkpoint_policy.md`
3. `docs/professional_refusion_motion_keyframe_engine.md`
4. `docs/prebuild_reports/pivwsct_00_legacy_write_inventory.md`

## Execution Baseline

```text
branch: codex/unified-keyframe-ops-foundation-20260426
commit: a63cdf69
workspace status: dirty by unrelated untracked diagnostics files only
```

Unrelated untracked files were intentionally not staged or modified in this
slice.

## Connected Device Baseline

```text
adb serial: adb-A8NFCP5307400775-sCQhkH._adb-tls-connect._tcp
model: ELN2_W29
package: com.refusion.app
versionName: 1.0.0-beta.11
versionCode: 11
lastUpdateTime: 2026-05-15 23:10:03
```

## MCP Endpoint And Cloud Baseline

From runtime config:

```text
default MCP endpoint:
https://wygydvczsgnocihbihje.supabase.co/functions/v1/mcp
project ref: wygydvczsgnocihbihje
```

Deployment baseline:

```text
SUPABASE_ACCESS_TOKEN present: false
```

Result: server-side edge-function changes cannot be confirmed as live in this
slice until deployment credentials are available.

## Current Truth Boundary

Current behavior still includes mixed truths:

1. Cloud data truth (`refusion_layers`, `refusion_agent_commands`) and revision
   changes can advance before guaranteed local renderer visibility.
2. App local truth applies remote payloads in screen-level handlers.
3. Bridge truth uses polling-style sync loops with command/layer/channel fetch.

The migration target remains:

```text
local-first canonical transaction apply
-> graph/timeline/frame/canvas proof
-> cloud relay/mirror/history
```

## Live Paths Inventory (Code-Verified)

### A) Edge MCP write surface (legacy row-centric still active)

Observed in `supabase/functions/mcp/index.ts`:

1. Command aliases still map many mutations to `refusion.insert_layer`.
2. `insertLayer` and `syncEditorLayers` write directly to `refusion_layers`.
3. Command status includes `appApplied`, but cloud acceptance and app visibility
   remain separate lifecycle stages.

### B) Cloud bridge runtime path (polling/snapshot-centric still active)

Observed in `refusion_mcp_cloud_bridge.dart`:

1. Bridge runs periodic `syncNow()` on `interval=8s`.
2. Sync performs `set_active_context`, `get_pending_commands`, `get_layers`,
   `get_motion_channels`, plus diagnostics fetches.
3. Snapshot emission is driven by cloud responses; local-first direct
   transaction ingestion is not yet the sole execution path.

### C) Screen-level remote apply path (legacy compatibility still active)

Observed in `fusionx_clean_ui_screen.dart`:

1. `_handleMcpCloudSnapshot` drives local apply decisions from remote snapshots.
2. `_applyRemoteSolidLayerIfNeeded`, `_applyRemoteShapeLikeLayerIfNeeded`,
   `_applyRemoteTextLayerIfNeeded`, `_applyRemoteMotionChannel*` still perform
   runtime mutation behavior.
3. Manual helpers like `_insertRootSolidLayer` and `_insertTextPreset` remain
   direct mutation entry points and are not yet fully cut over to one canonical
   transaction-only route.

### D) Local-first primitives exist but are not sole authority

Observed in domain services:

1. `LocalMcpTransactionApi` exists and wraps snapshot/validation/target/apply.
2. `UnifiedCreativeApplyEngine` exists with transaction validation and domain
   preflight.
3. `CreativeTransactionEnvelope` and `LegacyPathCleanupRecord` models exist.

Gap: these primitives are not yet the exclusive execution spine for all
Manual/MCP/Script/Template writes.

### E) Proof pipeline partially hardened, still migration-incomplete

Observed in:

1. `professional_scene_apply_proof_evaluator.dart`
2. `professional_scene_timeline_projection_validator.dart`
3. `supabase/functions/mcp/index.ts` (`wait_for_apply` strict proof path)

Gap: full `RendererProofV1` closure (measured rendered bounds + unified local
apply authority) is not fully complete across all legacy apply paths.

## Legacy Path Cleanup Record (PLFPW Baseline)

| Legacy path id | Current behavior | Decision | Target phase |
|---|---|---|---|
| `legacy.edge.insert_layer.row_write` | Writes layer rows directly to cloud table | `convertToAdapter` | `PLFPW-07` |
| `legacy.edge.sync_editor_layers.row_sync` | Syncs editor timeline as cloud row writes | `convertToAdapter` | `PLFPW-07` |
| `legacy.cloud_bridge.polling_primary` | Polling/snapshot loop is active apply driver | `disableBehindFlag` then `deleteNow` | `PLFPW-06` then `PLFPW-12` |
| `legacy.screen.snapshot_apply_router` | Screen snapshot handler decides local mutation set | `convertToAdapter` | `PLFPW-06` / `PLFPW-11` |
| `legacy.screen.remote_solid_apply` | Remote solid/background payload mutates screen state | `convertToAdapter` | `PLFPW-11` |
| `legacy.screen.remote_text_apply` | Remote text payload mutates screen state | `convertToAdapter` | `PLFPW-11` |
| `legacy.screen.remote_shape_apply` | Remote shape payload mutates screen state | `convertToAdapter` | `PLFPW-11` |
| `legacy.screen.remote_motion_apply` | Remote channels mutate timeline/elements with fallback logic | `blockWithError` for unresolved target + `convertToAdapter` | `PLFPW-04` / `PLFPW-11` |
| `legacy.manual.insert_root_solid` | Manual UI inserts solid via direct helper | `convertToAdapter` | `PLFPW-11` |
| `legacy.manual.insert_text_preset` | Manual UI inserts text via direct helper | `convertToAdapter` | `PLFPW-11` |
| `legacy.manual.insert_shape_direct` | Manual UI shape insertion helper path | `convertToAdapter` | `PLFPW-11` |
| `legacy.success.get_layers_as_visibility` | `get_layers` used as practical success signal | `blockWithError` as success proof | `PLFPW-07` |
| `legacy.success.revision_as_proof` | Revision increase interpreted as apply success | `blockWithError` as success proof | `PLFPW-07` |
| `legacy.proof.data_only_inference` | Proof fields can derive from non-render visibility in some paths | `deleteNow` (replace with RendererProofV1) | `PLFPW-10` |

## Metrics Baseline (Before Migration Closure)

Current baseline values are non-zero by architecture and expected at this
pre-build phase:

```text
legacy_mutation_callsite_count > 0
cloud_bypass_count > 0
cloud_appApplied_without_proof risk > 0 (depends on path)
metadata_only_success_count > 0 risk
unresolved_update_insert_count > 0 risk
selected_clip_fallback_for_targeted_command_count > 0 risk
polling_primary_apply_count > 0
```

The exact numeric counters will be introduced as explicit runtime metrics in
`PLFPW-12` guard phase.

## Verification Run In This Slice

Executed:

```text
flutter test \
  test/local_mcp_transaction_api_test.dart \
  test/presentation_services/refusion_mcp_cloud_bridge_fast_apply_test.dart \
  test/presentation_services/professional_scene_apply_proof_evaluator_test.dart \
  test/presentation_services/mcp_text_layer_resolution_test.dart
```

Result:

```text
All tests passed.
```

## Live Scrub Boundary

Protected Stage5/Live Scrub files were not modified in this slice.

```text
protected_live_scrub_touch_count = 0
```

## PLFPW-00 Exit Gate Decision

`PLFPW-00` is complete.

Conditions satisfied:

1. Current branch/commit/device/MCP endpoint baselines recorded.
2. Legacy execution paths are inventoried and mapped to cleanup phases.
3. Baseline tests executed and green.
4. No behavior code changed in this slice.

Next implementation slice allowed:

```text
PLFPW-01 Real Project Workspace Identity On Create Composition
```

