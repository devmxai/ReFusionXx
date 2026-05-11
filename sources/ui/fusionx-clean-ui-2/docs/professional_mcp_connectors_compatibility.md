# ReFusion MCP Compatibility Packaging

Status: `PMC-14`

This document packages the ReFusion MCP server for real hosts with explicit,
honest boundaries.

## 1) Transport + Command

- Transport: `stdio` JSON-RPC.
- Server entrypoint: local app bridge + JSON-RPC server in ReFusion.
- Pairing: pass `pairingToken` in `refusion/session/open` when enabled by
  `RefusionMcpHardeningPolicy.requiredPairingToken`.

## 2) Claude Desktop / Claude Code

Use a local stdio launcher that starts ReFusion MCP runtime.

Example host config shape:

```json
{
  "mcpServers": {
    "refusion": {
      "command": "/absolute/path/to/refusion_mcp_launcher",
      "args": [],
      "env": {
        "REFUSION_MCP_PAIRING_TOKEN": "pair-123"
      }
    }
  }
}
```

Session open payload must include:

```json
{
  "method": "refusion/session/open",
  "params": {
    "pairingToken": "pair-123",
    "session": {
      "id": "session_local",
      "clientName": "claude",
      "clientVersion": "1.0.0",
      "transport": "stdio",
      "activeProjectId": "active",
      "activeCompositionId": "comp_1",
      "timelineRevision": 1,
      "capabilities": [
        "project.read",
        "timeline.read",
        "timeline.write",
        "motion.write",
        "preview.read"
      ]
    }
  }
}
```

## 3) Codex local MCP

Codex can connect via the same stdio server config surface used for local MCP
servers.

Minimum required capabilities for full authoring loop:

- `project.read`
- `timeline.read`
- `timeline.write`
- `motion.write`
- `preview.read`

Optional (blocked by default policy):

- `filesystem.read`
- `filesystem.write`
- `export.start`
- `debug.diagnostics`

## 4) ChatGPT integration path (important limitation)

Direct raw local MCP server connection is not guaranteed as a generic
end-user feature path.

For production ChatGPT integration, package this as an official app/connector
surface (Apps SDK / connector-supported path) and expose approved tools through
that integration boundary.

In short:

- Local dev: use stdio MCP host (Claude/Codex local flows).
- ChatGPT production: use supported app/connector packaging path.

## 5) Troubleshooting Checklist

1. `refusion/session/open` fails:
   - Check pairing token mismatch.
   - Check session capability strings are valid.

2. `tools/call` fails with `sessionNotFound`:
   - Session expired (TTL) or not opened.

3. `tools/call` fails with `payloadTooLarge`:
   - Reduce payload size; send compact patch.

4. `tools/call` fails with `rateLimited`:
   - Retry after window, lower call burst.

5. `resources/read` fails with `resourceTooLarge`:
   - Request compact resource or split into smaller resource endpoints.

6. Audit verification:
   - Read `refusion://mcp/audit/recent` to inspect session open/close, tool
     calls, result status, revisions, and tool timing.

## 6) Host Acceptance

A host compatibility pass is complete when all are true:

1. Host opens session with granted capabilities.
2. Host runs `dryRun -> commit -> undo` workflow.
3. Host reads preview resource.
4. Host reads audit resource.
5. Security gates enforce pairing, payload limit, and rate limits.

Local automated proof command:

```bash
cd /Users/mx/Documents/ReFusionXx/sources/ui/fusionx-clean-ui-2
flutter test test/mcp/refusion_mcp_e2e_workflow_test.dart
```

Expected output:

```text
All tests passed!
```
