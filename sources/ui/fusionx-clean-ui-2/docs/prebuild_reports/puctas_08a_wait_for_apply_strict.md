# Pre-Build Report

Slice ID: `PUCTAS-08A.WAIT-FOR-APPLY-STRICT`

Date: `2026-05-14`

## Goal

Harden MCP `wait_for_apply` so success is only returned when renderer-proof
contract is complete, not merely when command status is terminal.

## Current ReFusion State Before Slice

1. `ack_command_applied` already computes proof gates and marks `appApplied`.
2. `wait_for_apply` currently treats `status=succeeded` as resolved even if
   proof consistency is incomplete.
3. This can permit edge cases where clients accept a success without strict
   proof validation.

## Reference Comparison

HyperFrames lesson:

- Render completion checks should be deterministic and explicit, especially in
  automation APIs.

Remotion lesson:

- Frame/render truth and completion conditions must be explicit and verifiable.

## Gap List Closed By This Slice

1. Missing strict proof gate in `wait_for_apply`.
2. No explicit error for `succeeded` rows missing proof contract.
3. No deterministic strict/relaxed toggle contract.

## Decision Table

- ACK writer contract: `keep`
- wait_for_apply strict evaluation: `upgrade`
- renderer / Stage5 / Live Scrub: `keep`

## Selected Execution Scope

1. Add proof-completeness checker in MCP function runtime.
2. Enforce strict proof by default in `wait_for_apply`.
3. Allow optional `strictProof=false` for compatibility.

No renderer changes. No Stage5 changes. No Live Scrub changes.

## Acceptance For This Slice

1. `wait_for_apply` default strict mode rejects succeeded rows with incomplete
   proof.
2. `wait_for_apply` returns success only when `appApplied=true` and proof
   contract booleans are all true.
3. `strictProof=false` allows compatibility behavior for legacy clients.

## Rollback

```bash
git -C /Users/mx/Documents/ReFusionXx/sources/ui/fusionx-clean-ui-2 revert <checkpoint-commit>
```
