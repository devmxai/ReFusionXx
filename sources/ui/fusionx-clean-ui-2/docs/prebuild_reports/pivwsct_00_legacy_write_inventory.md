# PIVWSCT-00 Legacy Write Inventory

Slice: `PIVWSCT-00`  
Plan: `professional_in_app_virtual_project_workspace_single_creative_truth_plan.md`  
Date: `2026-05-15`  
Package: `com.refusion.app`

## Goal

Establish a complete pre-build inventory of known creative write paths before
executing replacement architecture slices, and classify each path with an
explicit cleanup decision.

## Mandatory Inputs Reviewed

1. `docs/professional_in_app_virtual_project_workspace_single_creative_truth_plan.md`
2. `docs/professional_checkpoint_policy.md`
3. `docs/professional_refusion_motion_keyframe_engine.md`
4. `docs/professional_unified_creative_truth_apply_spine_plan.md`
5. `docs/professional_realtime_mcp_editor_apply_plan.md`

## Protected Live Scrub Boundary

Protected Stage5/Live Scrub paths were not modified in this slice.

```text
protected_live_scrub_touch_count = 0
```

## Known Creative Entry Surfaces

This inventory covers known write surfaces currently used in the app:

1. Manual UI actions in `fusionx_clean_ui_screen.dart` (`add solid`, `add text`,
   `shape insert`, transform updates, style updates, timeline edits).
2. MCP cloud snapshot apply path in `fusionx_clean_ui_screen.dart`
   (`_handleMcpCloudSnapshot`, `_applyRemote*` family).
3. MCP cloud bridge fetch loop in `refusion_mcp_cloud_bridge.dart`
   (`syncNow`, pending commands, layers/channels snapshots).
4. Edge function command writers in `supabase/functions/mcp/index.ts`
   (`insertLayer`, `updateLayer`, `applyMotionPatch`, `keyframeEdit`,
   `applySceneProgram` redirects).
5. Script/template/import surfaces that currently route into editor mutation
   helpers from screen/domain adapters.

## Legacy Write Path Inventory And Decision

| Path | Current behavior | Risk | Decision |
|---|---|---|---|
| Manual UI direct mutation helpers (`_insertRootSolidLayer`, `_insertTextPreset`, `_insertShapeLayerIntoScene`) | Mutate project/timeline directly in screen state | Parallel truth vs MCP/script | `canonicalize` |
| MCP remote apply in screen (`_applyRemoteSolidLayerIfNeeded`, `_applyRemoteTextLayerIfNeeded`, `_applyRemoteShapeLikeLayerIfNeeded`, `_applyRemoteMotionChannel`) | Applies remote payload with local heuristics and multiple fallbacks | Insert-as-update, target drift, partial truth | `adapterOnly` |
| MCP snapshot handler (`_handleMcpCloudSnapshot`) | Chooses apply set by pending/revision filters | Commands accepted but not always visible | `canonicalize` |
| MCP cloud bridge polling (`syncNow`) | Fetches command/layer snapshots from cloud | Latency, stale/partial command materialization | `featureFlag` then `migrate` to relay |
| Edge `insert_layer` + command bus | Writes cloud row first, app applies later | Cloud success without local visible success | `adapterOnly` |
| Edge `apply_scene_program` fallback inserts | Can still produce legacy insertion patterns around styling if mis-targeted | Parallel mutation semantics | `block` non-canonical operations |
| Selected/single-clip motion fallback in runtime apply | Applies motion when target is unresolved | Wrong layer animated | `block` |
| Metadata-only success/proof patterns | Success can be inferred without renderer-backed visibility | False success | `delete` after proof unification |
| Template/script/import direct mutation segments | Some paths can bypass canonical transaction envelope | Identity divergence | `canonicalize` |

## Coverage Statement

Known surfaces above represent all currently recognized creative mutation
entry-points used by Manual UI, MCP, and cloud command relay in this codebase.
This is the baseline inventory for subsequent phase cleanup records.

```text
legacy_write_path_inventory_coverage = 100% (known entry surfaces)
old_path_decision_coverage = 100%
protected_live_scrub_touch_count = 0
```

## Explicit Execution Gate For Next Slice

`PIVWSCT-01` is allowed now because `PIVWSCT-00` report is complete.

Next slice constraints:

1. Domain contracts only.
2. No renderer behavior change.
3. No Live Scrub/Stage5 touch.
4. Add validation primitives required by later migration slices.
