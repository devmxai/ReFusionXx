# Pre-Build Report

Slice ID: `PUCTAS-07A.MOTION-EFFECT-CAPABILITY-GUARD`

Date: `2026-05-14`

## Goal

Add a strict, fail-closed capability guard for MCP effect payloads so unsupported
effect types are blocked before success ACK, with structured blockers returned to
the command receipt path.

## Current ReFusion State Before Slice

1. Motion payloads are already lowered through motion-channel paths.
2. Timeline clip style mutation lowers supported visual style fields
   (`mask`, `border`, `glow`, transform-like fields) into typed runtime style.
3. Unsupported effect payload types can still be ignored silently, which allows
   success ACK without explicit capability rejection.

## Reference Comparison

HyperFrames lesson:

- Deterministic rendering requires explicit capability contracts; unsupported
  adapters must fail with diagnostics, not silently noop.

Remotion lesson:

- Composition/runtime truth is explicit and validated; unknown feature payloads
  should not be treated as successful visual application.

## Gap List Closed By This Slice

1. No strict detector for unsupported MCP effect types.
2. No fail-closed ACK path when unsupported effects are requested.
3. No standalone test coverage for capability detection extraction from varied
   payload layouts.

## Decision Table

- motion lowerer behavior: `keep`
- style mutation lowerer for supported fields: `keep`
- unsupported effect detection: `add`
- ACK success criteria when blockers exist: `upgrade` (force failure ACK)
- renderer / Stage5 / Live Scrub behavior: `keep`

## Selected Execution Scope

1. Add `McpEffectCapabilityGuard` service with deterministic detection and
   structured blocker output.
2. Wire guard into MCP remote layer apply path in
   `fusionx_clean_ui_screen.dart`.
3. Upgrade ACK path to send `appliedSuccessfully=false` when blockers exist.
4. Add focused tests for effect capability guard parser.

No renderer changes. No Stage5 changes. No Live Scrub changes.

## Acceptance For This Slice

1. Unsupported effect payloads produce structured blockers.
2. Blocked effect payloads do not receive success ACK.
3. ACK sends failure diagnostics with blocker codes.
4. Supported effect payloads continue normal apply path.
5. Existing MCP text/motion proof tests remain green.

## Rollback

```bash
git -C /Users/mx/Documents/ReFusionXx/sources/ui/fusionx-clean-ui-2 revert <checkpoint-commit>
```
