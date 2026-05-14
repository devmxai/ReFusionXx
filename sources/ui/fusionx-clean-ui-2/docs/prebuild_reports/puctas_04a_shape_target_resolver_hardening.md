# Pre-Build Report

Slice ID: `PUCTAS-04A.SHAPE-TARGET-RESOLVER-HARDENING`

Date: `2026-05-14`

## Goal

Harden MCP shape/solid target resolution and update-intent detection so shape
updates consistently modify the intended existing element (identity-first),
while legitimate inserts remain inserts.

## Current ReFusion State Before Slice

1. Shape target resolution in `fusionx_clean_ui_screen.dart` builds a `Set`
   of candidate ids and iterates it.
2. This loses deterministic priority ordering guarantees.
3. Shape update-intent detection uses shape-specific heuristics that can mark
   some insert-like payloads as update intent.
4. Text resolution already has a stricter, ordered utility
   (`McpTextLayerResolution`) with tested behavior.

## Reference Comparison

HyperFrames lesson adopted:

- Visual patching must resolve through a stable target identity first.
- Target ambiguity or unresolved patch targets should fail conservatively.

Remotion lesson adopted:

- Identity continuity is explicit; updates mutate existing component identity
  (props/state path) instead of accidental duplication.

## Gap List Closed By This Slice

1. Non-deterministic shape candidate iteration order.
2. Shape update-intent heuristics not aligned with hardened text behavior.
3. No dedicated, testable shape resolution contract utility.

## Decision Table

- shape target resolution contract: `upgrade`
- shape update-intent contract: `upgrade`
- text resolver contract: `keep` (reused pattern)
- renderer/Stage5/Live Scrub paths: `keep`

## Selected Execution Scope

1. Add `mcp_shape_layer_resolution.dart` service.
2. Route shape resolution/update-intent usage in
   `fusionx_clean_ui_screen.dart` to this service.
3. Add unit tests for shape resolution behavior.

No renderer changes, no Stage5 changes, no Live Scrub changes.

## Acceptance For This Slice

1. Shape target resolver uses deterministic candidate order.
2. Insert with no target remains insert intent.
3. Insert/update with explicit target resolves as update intent.
4. Update intent + unresolved target still blocks insert (fail closed).
5. Existing MCP text tests and toolkit tests stay green.

## Rollback

```bash
git -C /Users/mx/Documents/ReFusionXx revert <checkpoint-commit>
```
