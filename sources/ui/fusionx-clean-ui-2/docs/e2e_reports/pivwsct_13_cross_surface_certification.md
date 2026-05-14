# PIVWSCT-13 End-To-End Cross-Surface Certification

Slice: `PIVWSCT-13`  
Plan: `professional_in_app_virtual_project_workspace_single_creative_truth_plan.md`  
Date: `2026-05-15`

## Scope

Cross-surface deterministic certification for the unified write spine:

```text
Manual UI + MCP + Script + Template
-> Canonical Transaction
-> Unified Apply Engine
-> Creative Graph + Timeline
-> Frame Evaluator + Renderer Proof
```

## Implemented Certification Test

File:
`test/cross_surface_certification_test.dart`

Certified flows:

1. Manual add shape then MCP motion on same layer identity.
2. MCP add text, manual edit same text, MCP style update same identity.
3. MCP background in Story enforces full `1080x1920`.
4. Template-generated layer edited by manual move then MCP effect on same id.
5. Script-generated media layer trimmed by MCP while timeline clip stays aligned.
6. Renderer proof validated with observed target identity.
7. Undo/redo identity preservation.
8. Preview/export parity sample using same frame evaluator.

## Results

```text
cross_surface_context_retention = pass
layer_duplicate_regression_count = 0 in certified scenario
composition_size_mismatch_count = 0 in certified scenario
manual_mcp_graph_match = pass
preview_export_frame_match = pass for sampled frame
```

## Notes

1. This report certifies deterministic domain-level E2E in automated tests.
2. Device-level visual certification remains a separate execution layer and
   depends on active connected adb target.

## Rollback

```bash
git -C /Users/mx/Documents/ReFusionXx/sources/ui/fusionx-clean-ui-2 revert <phase-commit-hash>
```

