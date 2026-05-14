# Pre-Build Report

Slice ID: `PUCTAS-07C.EFFECT-CAPABILITY-PROOF-MATRIX`

Date: `2026-05-14`

## Goal

Expose structured effect capability diagnostics in ACK proof so every MCP apply
attempt reports detected/supported/unsupported effect families deterministically.

## Current ReFusion State Before Slice

1. Unsupported effects are fail-closed (PUCTAS-07A).
2. Structured effect payload lowering exists (PUCTAS-07B).
3. ACK proof still lacks explicit capability-matrix detail for effect payloads.

## Reference Comparison

HyperFrames lesson:

- Adapter conformance is observable; diagnostics should identify what adapter
  handled or rejected.

Remotion lesson:

- Render-relevant input state must be inspectable in deterministic metadata for
  reproducible debugging.

## Gap List Closed By This Slice

1. No proof-level list of detected/supported/unsupported effects.
2. No per-layer effect type visibility in ACK diagnostics.
3. No test coverage for capability-report proof map contract.

## Decision Table

- capability guard enforcement: `keep`
- effect payload lowering: `keep`
- capability proof diagnostics: `upgrade`
- renderer / Stage5 / Live Scrub: `keep`

## Selected Execution Scope

1. Extend `McpEffectCapabilityGuard` with `inspectCapabilities`.
2. Persist latest capability proof map in MCP screen apply pipeline.
3. Merge capability proof map into both success and failure ACK proof payloads.
4. Add tests for report/proof-map behavior.

No renderer changes. No Stage5 changes. No Live Scrub changes.

## Acceptance For This Slice

1. ACK proof includes `effectCapability.detected/supported/unsupported`.
2. ACK proof includes `effectCapability.layerEffectTypes`.
3. Failure ACK still includes blockers and now also capability matrix.
4. Success ACK includes capability matrix when effect payload was present.
5. Existing tests remain green.

## Rollback

```bash
git -C /Users/mx/Documents/ReFusionXx/sources/ui/fusionx-clean-ui-2 revert <checkpoint-commit>
```
