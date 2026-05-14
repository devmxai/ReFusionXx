# Pre-Build Report

Slice ID: `PUCTAS-06A.SPATIAL-TRUTH-SNAPSHOT-BRIDGE`

Date: `2026-05-14`

## Goal

Extend MCP cloud snapshot intake so the open app consumes richer spatial truth
payloads (`project snapshot`, `timeline graph`, `frame evaluation`) and feeds
them into ACK proof diagnostics.

## Current ReFusion State Before Slice

1. Bridge already syncs `get_canvas_metadata`, `get_element_geometry`,
   `get_visual_layout_summary`.
2. Snapshot model does not carry full composition truth payload.
3. ACK proof path has no explicit linkage to latest frame-evaluation diagnostics
   in app memory.

## Reference Comparison

HyperFrames lesson adopted:

- Truth should be inspectable as structured scene/timeline state, not inferred
  from partial flags.

Remotion lesson adopted:

- Frame-time deterministic state should be queryable and attached to decision
  flow when validating visual outcomes.

## Gap List Closed By This Slice

1. Missing `get_project_snapshot` data in bridge snapshot.
2. Missing `get_timeline_graph` data in bridge snapshot.
3. Missing `evaluate_frame` data in bridge snapshot.
4. ACK proof lacked spatial diagnostic context from latest snapshot frame.

## Decision Table

- bridge snapshot schema: `upgrade`
- sync tool calls (read-only): `upgrade`
- ACK proof enrichment: `upgrade`
- apply engine / renderer / Stage5 / Live Scrub: `keep`

## Selected Execution Scope

1. `refusion_mcp_cloud_bridge.dart` snapshot schema + sync calls + parsing.
2. `fusionx_clean_ui_screen.dart` in-memory spatial diagnostics capture and ACK
   proof enrichment only.

No renderer changes. No Stage5 changes. No Live Scrub changes.

## Acceptance For This Slice

1. Snapshot includes `projectSnapshot`, `timelineGraph`, `frameEvaluation`.
2. Snapshot parser populates these maps from tool payloads when available.
3. Screen captures latest spatial maps from snapshots.
4. ACK proof includes spatial diagnostics fields when available.
5. Existing MCP/service tests stay green.

## Rollback

```bash
git -C /Users/mx/Documents/ReFusionXx revert <checkpoint-commit>
```
