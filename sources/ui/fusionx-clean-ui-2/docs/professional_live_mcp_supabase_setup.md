# Professional Live MCP Supabase Setup

Status: deployed foundation  
Project ref: `wygydvczsgnocihbihje`  
MCP function: `https://wygydvczsgnocihbihje.functions.supabase.co/mcp`  
Date: 2026-05-12

## What Exists Now

The Supabase project now has the first production-shaped foundation for live
MCP editing:

- authenticated project state tables,
- composition and layer tables,
- project revision tracking,
- live editor session presence,
- agent command history,
- audit events,
- RLS enabled on all ReFusion tables,
- realtime publication enabled for project/composition/layer/session/command
  tables,
- a deployed Supabase Edge Function named `mcp`.

## Deployed Edge Function

The Edge Function supports JSON-RPC MCP requests:

- `initialize`
- `tools/list`
- `tools/call`

Current tools:

- `refusion.get_active_context`
- `refusion.get_project_state`
- `refusion.create_project`
- `refusion.insert_layer`
- `refusion.apply_scene_program`
- `refusion.get_command_status`

## Current Dev Authentication

For quick testing, the function accepts a temporary development token through
the query string or `x-refusion-dev-token` header.

The deployed development environment can also enable temporary `No Auth`
connector testing with `REFUSION_MCP_ALLOW_NO_AUTH=true`. This maps requests to
the configured development user and exists only to prove ChatGPT MCP tool calls
end-to-end before the production OAuth/Supabase Auth flow is implemented.

This is not the final production auth model.

Production must replace this with OAuth/Supabase Auth through the MCP
authorization flow.

## Source Of Truth

The authoritative state lives in Supabase:

- `refusion_projects`
- `refusion_compositions`
- `refusion_project_revisions`
- `refusion_layers`
- `refusion_editor_sessions`
- `refusion_agent_commands`
- `refusion_audit_events`

The app should treat these tables as cloud truth for MCP-originated edits.

## Next Required App Work

The Android app still needs the live editor bridge:

1. Sign in with Supabase Auth.
2. Create or open a cloud-backed project.
3. On composition open, call `refusion_touch_editor_session`.
4. Subscribe to realtime changes for:
   - `refusion_layers`
   - `refusion_agent_commands`
   - `refusion_editor_sessions`
5. Apply incoming command/layer changes into the active editor controller.
6. Push local edits back through revision-safe transactions.

## Safety Rule

Do not put service role keys, personal access tokens, or dev tokens into source
control. Use Supabase secrets or local environment variables only.
