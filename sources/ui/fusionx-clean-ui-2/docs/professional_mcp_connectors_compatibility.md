# ReFusion MCP Compatibility Packaging

Status: `PMC-14`

This document packages the ReFusion MCP server for real hosts with explicit,
honest boundaries.

ChatGPT domain onboarding checklist:
- [professional_mcp_connectors_chatgpt_domain_setup.md](/Users/mx/Documents/ReFusionXx/sources/ui/fusionx-clean-ui-2/docs/professional_mcp_connectors_chatgpt_domain_setup.md)

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

Recommended first tool call after `refusion/session/open`:

- `refusion.get_security_profile`

This returns active hardening facts (pairing requirement, payload limits, rate
limits, restricted capabilities) so the host can adapt its command strategy
before sending mutations.

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

ChatGPT connection is supported through remote MCP domain onboarding (Apps
settings flow), not through local `stdio`.

Required shape for ChatGPT onboarding:

- Public HTTPS domain (no localhost).
- MCP endpoint exposed with Streamable HTTP transport.
- Domain reachable from ChatGPT and TLS-valid.
- Host should call `refusion.get_security_profile` then
  `refusion.get_host_compatibility` before any mutation path.

For production ChatGPT integration, package this as an official app/connector
surface (Apps SDK / connector-supported path) and expose approved tools through
that integration boundary.

In short:

- Local dev: use stdio MCP host (Claude/Codex local flows).
- ChatGPT: add MCP domain from ChatGPT Apps settings and use remote transport.

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
