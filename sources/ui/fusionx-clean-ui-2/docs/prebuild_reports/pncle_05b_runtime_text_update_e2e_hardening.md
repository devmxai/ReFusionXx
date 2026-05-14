# Pre-Build Report

## 1. Slice ID
`PNCLE-05B.RUNTIME-TEXT-UPDATE-E2E-HARDENING`

## 2. Goal
Prevent MCP text-update duplication at runtime so that:
- insert creates a new text element only for true insert intent.
- update mutates the same existing text element identity.
- follow-up motion applies to the same resolved text target.
- unresolved update fails closed (no silent insert fallback).
- DB/metadata-only success is not treated as visual/apply success.

## 3. Current ReFusion State (Before This Slice)
- MCP text runtime flow enters through `_applyRemoteTextLayerIfNeeded` in
  `/Users/mx/Documents/ReFusionXx/sources/ui/fusionx-clean-ui-2/lib/features/editor/presentation/screens/fusionx_clean_ui_screen.dart`.
- Insert could occur in edge cases where update intent existed but target
  resolution was incomplete.
- Prior duplicate short-circuit behavior could be too coarse if it keyed only
  by remote id without payload-delta awareness.
- Motion fallback could drift to non-text clip fallback paths when text target
  resolution was missing.

## 4. Reference Comparison

### HyperFrames
- Text update targets a stable selector/DOM node (for example `#typed-text`).
- Update mutates existing node content/style; it does not create a second node.
- GSAP/WAAPI timelines keep targeting the same selector identity.

### Remotion
- Text update is props-driven over stable composition/component identity.
- Props mutate the same rendered component tree instead of random re-create.
- Motion/animation continuity follows the same identity path.

### ReFusion Target Model
- `remoteLayerId` + `targetLayerId` + aliases must behave like selector/props
  identity continuity.
- Update commands must resolve to the same local `elementId`.
- Motion commands must bind to the same resolved `elementId` for that text.

## 5. Decision Table
| Area | Decision |
|---|---|
| MCP text identity resolver | `upgrade` |
| MCP text insert path | `keep` with guard |
| MCP text update path | `upgrade` |
| unresolved update target | `block` (fail-closed) |
| text motion fallback | `upgrade/block` when unresolved text target |
| renderer / Live Scrub / Stage5 | `keep` (no change) |

## 6. Gap List

### Closed by This Slice
- Candidate target ids were not consistently read from full payload/nested
  payload variants.
- Update intent detection needed stronger operation/tool/target inference.
- Unresolved update could degrade into silent insert.
- Duplicate apply guard needed payload-signature semantics, not id-only.
- Motion fallback needed text-aware blocking when text target is unresolved.

### Out Of Scope (Intentional)
- No renderer changes.
- No Live Scrub behavior changes.
- No Stage5 path changes.
- Final visual/device E2E remains a required closure gate.

## 7. Selected Execution Slice
Scope is intentionally limited to MCP text identity/update hardening:
- `/Users/mx/Documents/ReFusionXx/sources/ui/fusionx-clean-ui-2/lib/features/editor/presentation/services/mcp_text_layer_resolution.dart`
- `/Users/mx/Documents/ReFusionXx/sources/ui/fusionx-clean-ui-2/lib/features/editor/presentation/services/mcp_text_runtime_update_planner.dart`
- `/Users/mx/Documents/ReFusionXx/sources/ui/fusionx-clean-ui-2/lib/features/editor/presentation/screens/fusionx_clean_ui_screen.dart` (MCP text apply + motion target handling only)
- MCP text identity tests only.

## 8. Acceptance Criteria
- Insert text without explicit target creates one new text element.
- Update for same `remoteLayerId` does not increase text element count.
- Update via `targetLayerId` mutates the same `elementId`.
- Unresolved update fails closed and does not insert text.
- `insert_layer` carrying explicit target/update intent does not create new text.
- Motion after update resolves and applies to same text `elementId`.
- Ambiguous update without resolvable target neither updates randomly nor inserts.
- No Live Scrub or Stage5 files are touched.
- Required tests pass.
- Device/runtime E2E confirms behavior in real app execution.

## 9. Tests
- `flutter test test/presentation_services/mcp_text_layer_resolution_test.dart`
- `flutter test test/presentation_services/mcp_text_runtime_update_identity_test.dart`
- `flutter test test/mcp/refusion_mcp_mvp_toolkit_test.dart`
- `dart analyze` for slice files:
  - `mcp_text_layer_resolution.dart`
  - `mcp_text_runtime_update_planner.dart`
  - `fusionx_clean_ui_screen.dart`
- Device/runtime E2E scenario documented in:
  `/Users/mx/Documents/ReFusionXx/sources/ui/fusionx-clean-ui-2/docs/e2e_reports/pncle_05b_runtime_text_update_e2e.md`

## 10. Rollback
```bash
git -C /Users/mx/Documents/ReFusionXx/sources/ui/fusionx-clean-ui-2 revert 8b75a1cb
```
