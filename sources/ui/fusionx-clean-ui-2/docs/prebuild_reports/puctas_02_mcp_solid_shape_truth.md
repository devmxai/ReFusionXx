# Pre-Build Report

Slice ID: `PUCTAS-02.MCP-SOLID-SHAPE-TRUTH`

Date: `2026-05-14`

## Goal

Convert MCP `solid/background` apply from metadata/placeholder behavior into
real shape graph truth so that MCP apply is immediately visible in canvas,
tracked in timeline truth, and eligible for renderer proof.

## Current ReFusion State Before Slice

1. MCP `solid` reached `_applyRemoteSolidLayerIfNeeded(...)`.
2. Handler wrote `project.metadata['backgroundColor']`.
3. Handler inserted placeholder shape clip (`TimelineClipType.placeholder`).
4. No `MotionLayerModel`/`MotionElementModel` shape node was created.
5. `MotionShapePreviewOverlay` only renders real evaluated shape elements.
6. Result: revision increases without guaranteed visible background.

## Reference Comparison

HyperFrames lesson adopted:

- Visual changes must exist as real renderable nodes with stable identity.
- Timeline intent is seek-driven and deterministic, not metadata-only.

Remotion lesson adopted:

- Composition/frame truth must be explicit and deterministic.
- Update must preserve identity of target node rather than creating detached
  state.

## Gap List Closed By This Slice

1. `shape` was not a first-class MCP command type in dispatcher.
2. `solid/background` could succeed without creating a renderable shape node.
3. `solid/background` relied on one-shot ids (`_appliedMcpSolidLayerIds`) rather
   than signature + identity update.
4. unresolved shape/solid update targets could drift into non-deterministic
   behavior.

## Decision Table

- MCP `solid/background` apply path: `upgrade`
- MCP `shape` dispatch path: `upgrade`
- apply engine counting for shape commands: `upgrade`
- text update path: `keep` (existing hardened gate preserved)
- Stage5 / Live Scrub internals: `keep` (no direct modification)

## Selected Execution Scope

1. `professional_scene_command_models.dart`
2. `mcp_scene_command_dispatcher.dart`
3. `professional_scene_apply_engine.dart`
4. `fusionx_clean_ui_screen.dart`
5. `professional_scene_apply_engine_test.dart`

## Acceptance For This Slice

1. `shape` remote layer dispatches into explicit shape apply command.
2. `solid/background` apply path writes real shape node state in project graph.
3. same remote layer id can update existing shape target (no forced duplicate).
4. unresolved update intent is blocked fail-closed.
5. tests for dispatcher/apply engine remain green.
6. no Stage5/Live Scrub protected-path edits.

## Rollback

Use:

```bash
git -C /Users/mx/Documents/ReFusionXx revert <checkpoint-commit>
```
