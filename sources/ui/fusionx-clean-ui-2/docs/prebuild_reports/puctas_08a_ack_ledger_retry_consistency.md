# Pre-Build Report

Slice ID: `PUCTAS-08A.ACK-LEDGER-RETRY-CONSISTENCY`

Date: `2026-05-14`

## Goal

Harden MCP open-app acknowledgment so command rows are marked acknowledged only
after a real successful ACK RPC response, preventing silent local ledger drift
that leaves server commands in `running` / `appApplied=false`.

## Current ReFusion State Before Slice

1. `_acknowledgeMcpRemoteRevision(...)` computes pending command ids.
2. Local set `_mcpAcknowledgedCommandIds` is updated before ACK RPC completion.
3. If ACK RPC fails transiently (network/token/timeout), local ledger still
   treats those ids as acknowledged.
4. Later sync cycles skip retry because ids are already marked acknowledged
   locally.
5. Server-side command rows can remain `running` even when local apply happened.

## Reference Comparison

HyperFrames lesson adopted:

- Deterministic pipeline stages cannot mark completion before the stage actually
  commits.
- Retry safety requires idempotent commit semantics and explicit success checks.

Remotion lesson adopted:

- Frame/runtime state transitions are explicit and deterministic; completion is
  not assumed from intent, but from completed state transitions.

## Gap List Closed By This Slice

1. ACK completion was optimistic (pre-commit) instead of confirmed.
2. Local acknowledged ledger could diverge from remote command bus status.
3. Transient ACK failures had no reliable retry path because ids were already
   consumed locally.
4. Stale timeout ACK path had the same optimistic behavior.

## Decision Table

- ACK RPC contract (`RefusionMcpCloudBridge`): `upgrade`
- local acknowledged ledger mutation timing: `upgrade`
- stale-timeout ACK path: `upgrade`
- command apply logic (text/shape/solid): `keep`
- Live Scrub / Stage5 protected paths: `keep`

## Selected Execution Scope

1. `lib/features/editor/presentation/services/refusion_mcp_cloud_bridge.dart`
2. `lib/features/editor/presentation/screens/fusionx_clean_ui_screen.dart`

No renderer, Stage5, or Live Scrub modifications.

## Acceptance For This Slice

1. ACK API returns success/failure signal to caller.
2. `_mcpAcknowledgedCommandIds` updates only after ACK success.
3. Failed ACK does not consume ids; next sync can retry.
4. Same behavior enforced for stale-timeout ACK path.
5. Existing MCP text identity tests and toolkit tests remain green.

## Rollback

Use:

```bash
git -C /Users/mx/Documents/ReFusionXx revert <checkpoint-commit>
```
