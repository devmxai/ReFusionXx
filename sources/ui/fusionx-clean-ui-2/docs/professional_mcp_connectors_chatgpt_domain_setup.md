# ReFusion MCP - ChatGPT Domain Setup

Status: `PMC-14 extension`

This guide is the production path for ChatGPT connectivity when adding your MCP
domain from ChatGPT Apps settings.

## 1) Required Deployment Shape

1. Public HTTPS domain (for example: `https://mcp.yourdomain.com`).
2. MCP endpoint exposed over Streamable HTTP transport.
3. TLS certificate valid (no self-signed certs for production).
4. ReFusion MCP toolset available on that endpoint.

## 2) Host Handshake Order (must follow)

1. `refusion/session/open`
2. `refusion.get_security_profile`
3. `refusion.get_host_compatibility`
4. `refusion.get_project_state`
5. `refusion.get_timeline_summary`
6. mutation only via `dryRun -> commit`

## 3) ChatGPT Settings Flow

In ChatGPT:

1. Open **Settings**
2. Open **Apps**
3. Add your MCP domain
4. Complete domain connection flow
5. Verify the server by running a read-only tool first

## 4) Safety Requirements

- Never bypass transaction flow.
- Always include `expectedRevision` on commit mode.
- Respect limits returned by `refusion.get_security_profile`.
- Respect host requirements returned by `refusion.get_host_compatibility`.

## 5) Known Boundaries

- Local `stdio` integration is for local dev hosts (Codex/Claude local).
- ChatGPT requires remote domain onboarding and network-reachable transport.
- Stage5 and Live Scrub remain protected and are not directly mutated by MCP.

