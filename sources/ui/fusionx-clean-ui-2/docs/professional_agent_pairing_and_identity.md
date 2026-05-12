# Professional Agent Pairing And Identity

Status: ready for implementation  
Package: `com.refusion.app`  
Date: 2026-05-12  
Short name: `PAP`  
Primary goal: make ChatGPT, Claude, Codex, Cursor, and other MCP agents connect
to the exact open ReFusionXx project through a production-safe one-tap pairing
flow, without dev tokens, guessed device ids, default sessions, or ambiguous
project context.

## 1. Executive Decision

ReFusionXx will use **One-Tap Agent Pairing**.

The user signs in once, opens a project, taps `Connect Agent`, receives a short
pairing code such as `REF-A1B2`, gives that code to an MCP-capable agent, and
the backend creates an `agentSessionToken` bound to the exact user, device, app
session, project, composition, timeline revision, playhead, and selection that
were active when the code was generated.

The final production flow is:

```text
User opens ReFusionXx
-> Supabase Auth identifies the user
-> App registers this physical device
-> App opens or creates a project/composition
-> App syncs active context to Supabase
-> User taps Connect Agent
-> App generates a short pairing code
-> User gives the code/link/QR to ChatGPT or another MCP client
-> Agent calls refusion.attach_pairing_code(code)
-> Backend returns an agentSessionToken bound to the active context
-> All MCP tools use that token
-> Realtime updates make edits appear in the open app
```

This is the same class of trusted binding used by WhatsApp Web, Apple TV
pairing, GitHub device flows, and authenticator apps: short-lived, user
approved, context-bound access.

## 2. Why This Plan Exists

The current live MCP foundation proves that cloud tool calls can work:

- a Supabase MCP endpoint exists,
- project and composition tables exist,
- layer inserts can be written to Supabase,
- editor sessions can be touched,
- active context can be queried,
- command history and audit tables exist.

But that is not enough.

The missing production layer is:

```text
Identity + Device + App Session + Active Context + Pairing + Agent Session
```

Without this layer, the system can accept a command from ChatGPT but cannot
answer the product-critical questions:

- Which user's project should be edited?
- Which device is currently open?
- Which app session is alive?
- Which project and composition are visible on the user's screen?
- Which timeline revision should the command apply to?
- Should the edit be visible immediately, queued, or rejected?
- Who is allowed to disconnect or revoke the agent?

This plan closes that gap.

## 3. Production Principle

The MCP server is not allowed to guess.

Every production write must resolve its target context from a trusted
`agentSessionToken`, not from user-written text, not from a `default` session,
not from an arbitrary `deviceId`, and not from a request body supplied by the
agent.

Correct:

```text
agentSessionToken -> userId/deviceId/appSessionId/projectId/compositionId
```

Forbidden:

```text
tool args projectId = "active"
tool args deviceId = "default"
server global default project
temporary dev token in release builds
```

## 4. Authentication Model

There are two different authentication layers. They must not be confused.

### 4.1 Connector Transport Authentication

This is how ChatGPT, Claude, Codex, or another MCP client is allowed to connect
to the public MCP endpoint at all.

Supported development modes:

- `No Auth` for local smoke tests only.
- Temporary dev token for local smoke tests only.

Supported production modes:

- OAuth if the host MCP client requires OAuth.
- Public attach-only MCP endpoint if the host allows unauthenticated discovery,
  with all real project access locked behind `agentSessionToken`.

Important rule:

An unauthenticated connector may expose only:

```text
initialize
tools/list
refusion.attach_pairing_code
```

It may not expose or execute project mutations without an `agentSessionToken`.

### 4.2 Agent Session Authentication

This is the real ReFusion authorization layer.

After the user gives a valid pairing code to the agent, the agent calls:

```text
refusion.attach_pairing_code(code)
```

The backend returns:

```text
agentSessionToken
```

Every later MCP tool call must include that token. The backend derives all
target context from the token.

## 5. Non-Negotiable Rules

1. No release build may depend on `REFUSION_MCP_ALLOW_NO_AUTH`.
2. No release build may depend on `REFUSION_MCP_DEV_TOKEN`.
3. No production mutation may use `deviceId=default`.
4. No production mutation may write to a default project.
5. No production mutation may accept the target project solely from the agent.
6. Every production mutation requires a valid `agentSessionToken`.
7. Every `agentSessionToken` is bound to one user and one active project context.
8. Pairing codes are short-lived, single-use, and revocable.
9. Agent writes are capability-scoped.
10. Agent writes are revision-safe.
11. Agent writes are audited.
12. User disconnect takes effect immediately.
13. Realtime apply into the open editor is required for the feature to count as
    working.

## 6. Architecture Layers

### 6.1 Identity Layer

Supabase Auth is the user identity source.

Supported sign-in methods:

- Apple
- Google
- Email magic link or email/password

The app stores the Supabase session securely and refreshes it normally.

The MCP backend never trusts `userId` from a request body. It gets user identity
from:

- Supabase JWT for app-originated requests,
- `agentSessionToken` for agent-originated requests,
- service role only inside trusted Edge Functions.

### 6.2 Device Layer

On first install, the app generates a stable local `deviceId` and stores it in
secure storage.

On sign-in, the app registers:

```text
deviceId
ownerId
deviceName
platform
appVersion
lastSeenAt
status
```

This allows the backend to distinguish:

- user's Android phone,
- user's tablet,
- user's emulator,
- user's future desktop app.

### 6.3 App Session Layer

Every app launch creates or resumes an app session:

```text
appSessionId
ownerId
deviceId
startedAt
lastHeartbeatAt
status: active | idle | backgrounded | closed
```

The app sends heartbeat updates while foregrounded. When the app is backgrounded
or closed, the session status changes.

### 6.4 Active Context Layer

Whenever a project, composition, selection, or playhead changes, the app updates
the active context:

```text
contextId
appSessionId
ownerId
deviceId
projectId
compositionId
timelineId
playheadMs
selectedLayerIds
timelineRevision
updatedAt
```

This is the key object that answers:

```text
Where should ChatGPT write?
```

### 6.5 Pairing Layer

The user explicitly creates a short-lived pairing code from the currently open
project. The code binds an agent to that active context.

Code examples:

```text
REF-A1B2
REF-X7K9
REF-3M4N
```

Rules:

- prefix: `REF-`
- alphabet: Crockford Base32 without ambiguous characters,
- length: 4 to 6 random chars depending on collision/load,
- default expiry: 10 minutes,
- single-use,
- bound to one active context,
- locked after repeated failed attempts,
- claim creates an agent session token.

### 6.6 Agent Session Layer

After a valid attach, the backend creates:

```text
agentSessionId
agentSessionToken
ownerId
deviceId
appSessionId
activeContextId
projectId
compositionId
grantedCapabilities
expiresAt
revokedAt
```

Only a token hash is stored. The raw token is returned once to the MCP client.

## 7. Data Model

### 7.1 New Tables

```sql
refusion_devices
  id uuid primary key
  owner_id uuid not null
  device_id text not null
  device_name text
  platform text not null
  app_version text
  status text not null
  last_seen_at timestamptz
  created_at timestamptz not null
  updated_at timestamptz not null

refusion_app_sessions
  id uuid primary key
  owner_id uuid not null
  device_id uuid not null
  status text not null
  started_at timestamptz not null
  last_heartbeat_at timestamptz
  backgrounded_at timestamptz
  closed_at timestamptz

refusion_active_contexts
  id uuid primary key
  owner_id uuid not null
  device_id uuid not null
  app_session_id uuid not null
  project_id uuid not null
  composition_id uuid not null
  timeline_id text not null default 'main'
  playhead_ms int not null default 0
  selected_layer_ids uuid[] not null default '{}'
  timeline_revision int not null
  status text not null default 'active'
  updated_at timestamptz not null

refusion_pairing_codes
  id uuid primary key
  code text not null unique
  owner_id uuid not null
  device_id uuid not null
  app_session_id uuid not null
  active_context_id uuid not null
  project_id uuid not null
  composition_id uuid not null
  timeline_revision int not null
  status text not null
  failed_attempts int not null default 0
  generated_at timestamptz not null
  expires_at timestamptz not null
  claimed_at timestamptz
  claimed_by_agent text
  revoked_at timestamptz
  revoke_reason text

refusion_agent_sessions
  id uuid primary key
  owner_id uuid not null
  device_id uuid not null
  app_session_id uuid not null
  active_context_id uuid not null
  project_id uuid not null
  composition_id uuid not null
  token_hash text not null
  agent_client_name text
  agent_client_version text
  granted_capabilities text[] not null
  status text not null
  created_at timestamptz not null
  last_used_at timestamptz
  expires_at timestamptz not null
  revoked_at timestamptz
  revoke_reason text
```

### 7.2 Existing Tables To Keep

These remain the project source of truth:

- `refusion_projects`
- `refusion_compositions`
- `refusion_project_revisions`
- `refusion_layers`
- `refusion_editor_sessions`
- `refusion_agent_commands`
- `refusion_audit_events`

### 7.3 Required Indexes

```sql
refusion_devices(owner_id, device_id)
refusion_app_sessions(owner_id, device_id, status)
refusion_active_contexts(owner_id, app_session_id, status)
refusion_pairing_codes(code)
refusion_pairing_codes(owner_id, status, expires_at)
refusion_agent_sessions(token_hash)
refusion_agent_sessions(owner_id, project_id, status)
```

### 7.4 RLS Requirements

Every user-facing table must enforce:

```text
owner_id = auth.uid()
```

Edge Functions may use service role internally, but every external request must
resolve to one of:

- verified Supabase user,
- valid pairing code attach flow,
- valid agent session token.

## 8. User Flows

### 8.1 First Launch

```text
Open app
-> Generate local device id
-> Show sign-in screen
-> Supabase Auth succeeds
-> Register device
-> Create app session
-> Enter home/editor
```

### 8.2 Open Or Create Project

```text
User creates Story composition
-> App creates cloud project if needed
-> App creates composition if needed
-> App updates active context
-> App subscribes to realtime project channels
```

### 8.3 Connect Agent

```text
User taps Connect Agent
-> App calls pairing generate endpoint
-> Backend creates REF code bound to active context
-> Modal shows code, QR, and link
-> App subscribes to pairing status channel
```

### 8.4 Agent Attach

The user tells ChatGPT:

```text
Connect to my ReFusion project. Code: REF-A1B2.
```

The agent calls:

```json
{
  "name": "refusion.attach_pairing_code",
  "arguments": {
    "code": "REF-A1B2",
    "agentClientName": "ChatGPT"
  }
}
```

The backend validates the code and returns:

```json
{
  "ok": true,
  "agentSessionToken": "rfx_agent_...",
  "context": {
    "projectId": "...",
    "compositionId": "...",
    "timelineId": "main",
    "playheadMs": 0,
    "timelineRevision": 12
  },
  "capabilities": [
    "project.read",
    "timeline.read",
    "timeline.write",
    "scene.write",
    "motion.write",
    "preview.read"
  ]
}
```

The app receives a realtime `claimed` event and displays:

```text
ChatGPT connected
```

### 8.5 Agent Edit

Every later MCP tool call includes:

```json
{
  "agentSessionToken": "rfx_agent_...",
  "expectedRevision": 12,
  "idempotencyKey": "host-turn-id"
}
```

The backend:

1. validates the token,
2. resolves user/device/project/composition from the token,
3. checks capability,
4. checks revision or runs conflict resolution,
5. performs the transaction,
6. writes audit rows,
7. broadcasts realtime changes,
8. returns `revisionAfter`.

### 8.6 App Closed Or Backgrounded

If the app is backgrounded:

- non-destructive queued writes may be allowed only if the project is cloud
  backed,
- live preview actions are rejected,
- preview capture is rejected,
- app session status becomes `backgrounded`.

If the app is closed:

- live edits should return `APP_SESSION_NOT_ACTIVE` unless the user enabled
  cloud-only queued edits,
- pairing codes tied to that app session should expire or be revoked,
- existing agent sessions should become idle or read-only.

This prevents the user from expecting an immediate on-device change when no app
instance is listening.

## 9. Connection Methods

The app must expose all three methods in the pairing modal.

### 9.1 Manual Code

User copies:

```text
REF-A1B2
```

and writes it to ChatGPT, Claude, Codex, Cursor, or any MCP client.

### 9.2 QR Code

QR payload:

```text
refusion://agent/REF-A1B2
```

or:

```text
https://refusion.app/agent/REF-A1B2
```

### 9.3 Deep Link

User copies:

```text
https://refusion.app/agent/REF-A1B2
```

The agent extracts the code and calls `refusion.attach_pairing_code`.

## 10. MCP Tool Surface

### 10.1 Public Tools

These are public only because they cannot mutate project state:

```text
refusion.attach_pairing_code
```

Optional:

```text
refusion.describe_pairing_flow
```

### 10.2 Token-Gated Tools

All project tools require `agentSessionToken`:

```text
refusion.get_active_context
refusion.get_project_state
refusion.get_layers
refusion.insert_layer
refusion.apply_scene_program
refusion.apply_motion_patch
refusion.keyframe_edit
refusion.set_element_transform
refusion.capture_preview_frame
refusion.get_command_status
refusion.disconnect_agent
```

### 10.3 Required Error Codes

Every MCP error must be structured:

```text
PAIRING_CODE_NOT_FOUND
PAIRING_CODE_EXPIRED
PAIRING_CODE_ALREADY_CLAIMED
PAIRING_CODE_LOCKED
AGENT_SESSION_REQUIRED
AGENT_SESSION_EXPIRED
AGENT_SESSION_REVOKED
CAPABILITY_DENIED
APP_SESSION_NOT_ACTIVE
PROJECT_NOT_OPEN
REVISION_CONFLICT
IDEMPOTENCY_REPLAY
```

## 11. Backend Endpoints

### 11.1 Pairing Generate

```text
POST /functions/v1/mcp/pairing/generate
Authorization: Bearer <supabase-jwt>
```

Body:

```json
{
  "projectId": "...",
  "compositionId": "...",
  "timelineId": "main",
  "playheadMs": 1200,
  "selectedLayerIds": []
}
```

Response:

```json
{
  "code": "REF-A1B2",
  "qrData": "refusion://agent/REF-A1B2",
  "link": "https://refusion.app/agent/REF-A1B2",
  "expiresAt": "2026-05-12T10:10:00Z"
}
```

Latency budget: less than 200 ms after warm start.

### 11.2 MCP Tool Call

```text
POST /functions/v1/mcp
```

Supports:

- `initialize`
- `tools/list`
- `tools/call`

`tools/list` may advertise public and token-gated tools, but token-gated tools
must fail without `agentSessionToken`.

### 11.3 Agent Revoke

```text
POST /functions/v1/mcp/agent-sessions/revoke
Authorization: Bearer <supabase-jwt>
```

Revocation must be immediate.

## 12. Flutter App Requirements

### 12.1 Domain Services

Add:

```text
RefusionAuthService
RefusionDeviceRegistrationService
RefusionAppSessionService
RefusionActiveContextSyncService
RefusionAgentPairingService
RefusionAgentSessionRealtimeService
```

### 12.2 UI Components

Add:

```text
ConnectAgentButton
AgentPairingModal
PairingQrView
ActiveAgentBanner
AgentActionToast
AgentManagementScreen
```

### 12.3 Editor Integration

The editor must:

- update active context when project opens,
- update active context when composition changes,
- update playhead and selection into active context,
- subscribe to project realtime channels,
- apply incoming layer updates to the open editor,
- show action toasts,
- handle revision conflicts visibly.

## 13. Realtime Requirements

Required channels:

```text
pairing:{code}
project:{projectId}
agent-session:{agentSessionId}
user:{userId}
```

Required events:

```text
pairing.claimed
pairing.expired
agent.connected
agent.disconnected
layer.inserted
layer.updated
layer.deleted
command.accepted
command.succeeded
command.failed
revision.conflict
```

Realtime is not optional. If a ChatGPT edit lands only in Supabase but does not
appear in the open app, this feature is not done.

## 14. Security Requirements

### 14.1 Pairing Code Controls

Each pairing code:

- expires in 10 minutes,
- is single-use,
- is tied to one active context,
- is tied to one owner,
- locks after 5 failed attempts,
- can be manually revoked,
- cannot be generated without an open cloud-backed project.

### 14.2 Agent Session Controls

Each agent session:

- stores only a token hash,
- expires after idle timeout,
- can be revoked instantly,
- carries explicit capabilities,
- records last use,
- rejects stale or unauthorized writes,
- supports `expectedRevision`,
- supports `idempotencyKey`.

### 14.3 Rate Limits

Required limits:

- pairing generation per user,
- attach attempts per IP,
- attach attempts per code,
- write calls per agent session,
- preview capture calls per agent session,
- failed token validations per IP.

### 14.4 Audit Log

Every MCP mutation records:

```text
ownerId
deviceId
appSessionId
agentSessionId
agentClientName
projectId
compositionId
commandType
payloadSummary
revisionBefore
revisionAfter
status
timestamp
```

## 15. Implementation Phases

### PAP-00: Schema Foundation

Goal: create the identity, device, session, context, pairing, and agent session
tables.

Implementation:

- add migrations for all new tables,
- add indexes,
- add updated-at triggers,
- add realtime publication,
- add RLS policies,
- keep existing MCP tables intact.

Acceptance gate:

- migration applies cleanly,
- anonymous users cannot read private state,
- user A cannot read user B tables,
- service role can run internal workflows,
- realtime publication includes required tables.

### PAP-01: Supabase Auth Integration

Goal: make the app know the signed-in user.

Implementation:

- add Supabase Auth sign-in,
- support Apple, Google, and email,
- store session securely,
- refresh JWT,
- add sign-out,
- expose current user to app services.

Acceptance gate:

- sign-in creates a valid Supabase user,
- sign-out clears local auth state,
- expired JWT refreshes without losing project state,
- unauthenticated app cannot generate pairing codes.

### PAP-02: Device Registration

Goal: bind a physical app installation to the signed-in user.

Implementation:

- generate stable local `deviceId`,
- store it securely,
- register device after sign-in,
- update `last_seen_at`,
- show device in account settings later.

Acceptance gate:

- app restart preserves device id,
- reinstall creates a new device id,
- signed-in device appears in `refusion_devices`,
- heartbeat updates `last_seen_at`.

### PAP-03: App Session And Active Context Sync

Goal: make the backend know what is open in the app.

Implementation:

- create app session on foreground,
- update session heartbeat,
- mark backgrounded/closed status,
- update active context on project open,
- update active context on composition switch,
- update playhead and selection.

Acceptance gate:

- backend can identify the exact open project,
- active context updates within 1 second of project change,
- stale app sessions become idle/backgrounded/closed,
- no active context is created without a project.

### PAP-04: Pairing Code Edge Function

Goal: generate a short-lived pairing code from the app.

Implementation:

- create `/mcp/pairing/generate`,
- validate Supabase JWT,
- validate project ownership,
- validate active app session,
- generate collision-checked `REF-` code,
- store code bound to active context,
- return code, QR payload, link, expiry.

Acceptance gate:

- code appears in app in less than 500 ms,
- code expires after 10 minutes,
- code is unique,
- code cannot be generated without an open project,
- cancel revokes the code.

### PAP-05: Connect Agent UI

Goal: expose one-tap pairing to the user.

Implementation:

- add `Connect Agent` button in project/editor top bar,
- add pairing modal,
- add code copy,
- add QR display,
- add deep link copy,
- add expiry countdown,
- subscribe to `pairing:{code}`.

Acceptance gate:

- code copy works,
- link copy works,
- QR contains the same code,
- countdown is accurate,
- modal status changes on claim/expiry/cancel.

### PAP-06: Agent Attach Tool And Session Token

Goal: let an MCP client claim a pairing code.

Implementation:

- add `refusion.attach_pairing_code`,
- validate code existence,
- validate expiry,
- validate unused status,
- lock after failed attempts,
- create `refusion_agent_sessions`,
- return raw token once,
- store token hash only,
- broadcast `pairing.claimed`.

Acceptance gate:

- valid code returns an agent session token,
- expired code fails,
- used code fails,
- locked code fails,
- app receives claimed event in less than 1 second,
- connected banner appears.

### PAP-07: Token-Gated MCP Tools

Goal: ensure all real MCP tools resolve context from token.

Implementation:

- require `agentSessionToken` for all project reads/writes,
- validate token hash,
- check expiry and revoked status,
- derive project/composition from session,
- enforce capability list,
- remove implicit default project in production mode.

Acceptance gate:

- every mutating tool rejects missing token,
- every project read rejects missing token unless explicitly public,
- capability mismatch returns `CAPABILITY_DENIED`,
- project id from request body cannot override token context.

### PAP-08: Realtime Apply Into Editor

Goal: make ChatGPT edits appear in the open app immediately.

Implementation:

- subscribe app to `project:{projectId}`,
- map `layer.inserted` into editor controller,
- map `layer.updated` into editor controller,
- map command status into toasts,
- update local revision,
- handle project switch safely.

Acceptance gate:

- ChatGPT `insert_layer` appears on the open canvas,
- revision changes update local state,
- command success/failure toasts appear,
- switching projects changes subscriptions safely,
- no app restart is required.

### PAP-09: Disconnect, Expiry, And Revocation

Goal: keep the user in control.

Implementation:

- disconnect current agent,
- revoke all agents,
- expire idle sessions,
- revoke on suspicious activity,
- show disconnected state in app,
- return structured revoked errors to agents.

Acceptance gate:

- revoked token fails immediately,
- banner disappears on disconnect,
- pairing code expiry updates the modal,
- idle agent expires automatically,
- audit log records revocation.

### PAP-10: Multi-Agent Conflict Protection And Acceptance

Goal: support real multi-agent editing without corrupting the timeline.

Implementation:

- allow multiple active agent sessions,
- enforce `expectedRevision`,
- enforce `idempotencyKey`,
- return `REVISION_CONFLICT`,
- show conflict in app,
- distinguish agents in audit and toasts.

Acceptance gate:

- ChatGPT and Claude can both attach,
- stale revision write returns conflict,
- duplicate idempotency key does not duplicate a layer,
- audit log distinguishes agents,
- user can disconnect one agent without disconnecting others.

## 16. Acceptance Test Suite

### 16.1 Speed

- tap Connect Agent,
- code visible in less than 500 ms,
- attach completes in less than 5 seconds after tool call,
- first edit visible in app in less than 10 seconds.

### 16.2 Security

- expired code rejected,
- used code rejected,
- too many failed attempts locks code,
- missing token rejected,
- revoked token rejected,
- wrong capability rejected,
- cross-user data access rejected.

### 16.3 Context Correctness

- agent edits the exact open project,
- agent edits the exact open composition,
- project switch invalidates or updates context correctly,
- backgrounded app returns expected status,
- closed app does not pretend live apply is possible.

### 16.4 Realtime

- layer insertion visible without restart,
- layer update visible without refresh,
- command failure toast visible,
- disconnect event visible,
- revision conflict visible.

### 16.5 Cross-Agent Compatibility

- ChatGPT Apps connector attaches with code,
- Claude MCP client attaches with code,
- Codex MCP client attaches with code,
- manual code works,
- deep link works,
- QR payload works.

## 17. Migration From Current Dev Mode

Current development paths remain only for smoke tests:

- `REFUSION_MCP_ALLOW_NO_AUTH`
- `REFUSION_MCP_DEV_TOKEN`
- default cloud project,
- manual `set_active_context`.

Migration order:

1. Add PAP schema beside existing tables.
2. Add Auth, device registration, and app session.
3. Add active context sync.
4. Add pairing code generation.
5. Add attach tool and agent session token.
6. Gate production tools behind agent session token.
7. Keep dev mode behind debug-only flags.
8. Remove no-auth and dev-token paths from release configuration.

## 18. Stop List

Do not:

- ship public ChatGPT connector with project mutations available through no-auth,
- let agents guess device ids,
- let agents mutate default projects,
- allow long-lived pairing codes,
- store raw agent tokens,
- skip RLS,
- skip audit rows,
- skip realtime apply,
- skip disconnect,
- allow UI automation as the primary command path,
- tell the user the MCP is working if cloud state updates but the app does not.

## 19. Definition Of Done

PAP is complete only when this flow works end-to-end:

```text
User signs in
-> opens a project
-> taps Connect Agent
-> copies REF code into ChatGPT
-> ChatGPT attaches
-> app shows connected banner
-> ChatGPT adds a solid white background
-> the open app canvas updates immediately
-> user disconnects ChatGPT
-> future calls with the old token fail
```

No manual project ids, no guessed device ids, no dev tokens, no app restart, no
copy-paste of scene JSON, no ambiguous target context, and no cloud-only edit
that does not appear on the open device.
