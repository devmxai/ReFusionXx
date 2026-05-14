# PIVWSCT-02 Virtual Workspace Snapshot

Slice: `PIVWSCT-02`  
Plan: `professional_in_app_virtual_project_workspace_single_creative_truth_plan.md`  
Date: `2026-05-15`

## Goal

Add a read-only in-app virtual workspace snapshot layer that expresses current
composition truth in one structured model.

## Implemented

### Models

File:
`lib/features/editor/domain/models/in_app_virtual_project_workspace_models.dart`

Added:

1. `CompositionSpecSnapshot`
2. `LayerGraphNodeSnapshot`
3. `LayerGraphSnapshot`
4. `TimelineClipSnapshot`
5. `TimelineGraphSnapshot`
6. `SelectionSnapshot`
7. `FrameSnapshotSummary`
8. `RendererCapabilitySnapshot`
9. `InAppVirtualProjectWorkspaceSnapshot`

### Service

File:
`lib/features/editor/domain/services/in_app_virtual_project_workspace.dart`

Added:

1. `InAppVirtualProjectWorkspace`
2. `CreativeWorkspaceSnapshotBuildRequest`
3. `CreativeWorkspaceSnapshotBuilder`

Behavior:

1. builds `CreativeWorkspaceSnapshot` from composition/layer/timeline inputs.
2. preserves layer identities in snapshot output.
3. reports orphan timeline clips via diagnostics.
4. keeps this slice read-only (no write mutation path).

## Tests

File:
`test/in_app_virtual_project_workspace_test.dart`

Coverage:

1. Story composition snapshot width/height.
2. Manual shape move reflected in next snapshot.
3. Layer id appears in both layer graph and timeline.
4. Orphan timeline clip emits diagnostic.

## Scope Confirmation

No Live Scrub/Stage5 protected path edits in this slice.  
No MCP behavior rewiring in this slice.  
No renderer behavior mutation in this slice.

## Acceptance Mapping

```text
workspace_snapshot_schema_validation_pass = true
manual_ui_snapshot_visibility = true (model-level)
layer_timeline_linkage_coverage = true (test coverage)
```
