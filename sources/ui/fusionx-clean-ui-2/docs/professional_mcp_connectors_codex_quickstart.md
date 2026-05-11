# ReFusion MCP - Codex Quickstart

This is the Codex-focused setup for local MCP connection to ReFusion.

Primary reference:  
[professional_mcp_connectors.md](/Users/mx/Documents/ReFusionXx/sources/ui/fusionx-clean-ui-2/docs/professional_mcp_connectors.md)

## 1) Required capability set (minimum)

Use only what you need:

- `project.read`
- `timeline.read`
- `preview.read`

For mutation workflows, add:

- `timeline.write`
- `motion.write`
- `scene.write`

## 2) Session open payload (Codex profile)

`clientName` should be `codex`:

```json
{
  "method": "refusion/session/open",
  "params": {
    "pairingToken": "your-local-token",
    "session": {
      "id": "codex_session",
      "clientName": "codex",
      "clientVersion": "1.0.0",
      "transport": "stdio",
      "activeProjectId": "active",
      "activeCompositionId": "comp_1",
      "timelineRevision": 1,
      "capabilities": [
        "project.read",
        "timeline.read",
        "preview.read",
        "timeline.write",
        "motion.write"
      ]
    }
  }
}
```

## 3) Codex-safe command loop

1. `tools/list`, `resources/list`, `prompts/list`
2. `refusion.get_security_profile`
3. `refusion.get_project_state`
4. `refusion.get_timeline_summary`
5. mutation as `dryRun`
6. inspect `diagnostics` + `patchPreview`
7. `refusion.commit_transaction`
8. `refusion.capture_preview_frame`
9. `refusion.undo_transaction` if needed

## 4) Hardening behaviors to expect

- invalid/missing pairing token => session open rejected.
- oversized payload => `payloadTooLarge`.
- call burst above limit => `rateLimited`.
- blocked capability (filesystem/export/debug by default) => denied.

## 5) Verification

Run MCP tests:

```bash
cd /Users/mx/Documents/ReFusionXx/sources/ui/fusionx-clean-ui-2
flutter test test/mcp
```

Codex profile test:

```bash
cd /Users/mx/Documents/ReFusionXx/sources/ui/fusionx-clean-ui-2
flutter test test/mcp/refusion_mcp_codex_host_profile_test.dart
```

Expected:

```text
All tests passed!
```
