# Professional Realtime MCP Editor Apply Plan

Status: ready for implementation
Package: `com.refusion.app`
Date: 2026-05-12
Short name: `PRMEA`
Primary goal: make every ChatGPT / Claude / Codex / MCP edit appear inside the
currently open ReFusionXx composition timeline and canvas in realtime, with
transaction safety, revision safety, visual correctness, and no fragile UI
automation.

## 1. Executive Decision

ReFusionXx will treat MCP edits as **live editor commands**, not as passive
database rows.

An MCP mutation is not successful until all of these are true:

```text
1. The MCP tool call is accepted and validated.
2. The command is written transactionally to cloud truth.
3. The open app receives the command or derived state.
4. The command is applied to the local MotionProject / timeline controller.
5. The canvas visibly updates.
6. The timeline shows the inserted or changed layer/keyframes.
7. The app acknowledges the applied revision back to the cloud.
```

Supabase may store the command and project state, but the open editor must have
a real apply pipeline. A write that exists only in Supabase is a failed live MCP
edit.

The required architecture is:

```text
ChatGPT / MCP Client
  -> Supabase Edge Function MCP endpoint
  -> Command validation + transaction record
  -> Supabase Realtime event
  -> Flutter MCP Live Apply Bridge
  -> Local Command Dispatcher
  -> Domain services / MotionProject mutation
  -> Canvas + timeline refresh
  -> Applied revision acknowledgement
```

## 2. Why This Plan Exists

The current MCP foundation can write rows to Supabase and increment project
revision. That proves the cloud control plane is reachable.

The current gap is that the app reads only a small slice of cloud state
(`latestSolidColorHex`) and does not materialize remote layers, text,
animations, shapes, keyframes, effects, or scene programs into the open editor.

The failure pattern is:

```text
Agent says: "Layer inserted, revision 3 -> 4"
Supabase: row exists
Open app: no visible layer or wrong older background appears
```

This plan closes the missing layer: **Realtime Apply Into Editor**.

## 3. Non-Negotiable Acceptance Rule

The feature is not complete until this exact test passes:

```text
User opens ReFusionXx on Android
User opens a Story composition
User connects ChatGPT through MCP pairing
User asks ChatGPT: "Create a white background, add title text, animate it in"
Within <= 1 second after each tool call:
  - background appears on canvas
  - layer appears on timeline
  - text appears on canvas
  - text layer appears on timeline
  - keyframes/animation lanes appear in the motion timeline
  - revision indicator advances
  - app shows a small applied-action toast
```

If the cloud says success but the open app does not visibly change, the phase
fails.

## 4. Scope

### In Scope

- MCP command envelopes.
- Supabase command/layer/state writes.
- Supabase Realtime subscriptions.
- Polling fallback for missed realtime events.
- Remote-to-local model mapping.
- Background layers.
- Text layers: text content, font size, color, alignment, opacity, typography
  role, fit policy, typewriter options.
- Shape layers: rectangle, rounded rectangle, ellipse, line, icon-like vector
  shapes, fill, stroke, radius, opacity.
- Media layers: image/video/audio metadata and timeline placement.
- Transform changes: position, scale, rotation, anchor, opacity.
- Keyframes and animation channels.
- SceneProgram / DirectorPlan apply results.
- Layer updates and deletes.
- Revision conflict handling.
- Idempotency.
- Applied revision acknowledgement.
- User-visible diagnostics.

### Out Of Scope

- Direct Stage5 or Live Scrub internal changes.
- Native decoder changes.
- Export engine changes.
- UI automation as the main command path.
- New visual design of the editor.
- Unauthenticated production mutations.

## 5. Protected Boundaries

Do not directly modify these paths unless a separate Live Scrub plan explicitly
approves it:

```text
Stage5TimelineScrubPlatformView
Stage5NativeScrubEngine
Stage5SurfaceScrubDecoder
Stage5ScrubOverlayTextureView
Stage5PreviewPlatformView
Flutter Live Scrub handoff paths
native playback clocks
native decoder internals
```

PRMEA operates above those systems through editor state and domain services.

## 6. Core Principle: Command First, State Mirror Second

The app must not guess what changed by scanning arbitrary rows only.

Every MCP mutation must create a canonical command record:

```json
{
  "commandId": "uuid",
  "commandType": "refusion.insert_layer",
  "projectId": "uuid",
  "compositionId": "uuid",
  "timelineId": "main",
  "revisionBefore": 3,
  "revisionAfter": 4,
  "idempotencyKey": "agent-generated-key",
  "payload": {
    "layerKind": "solid",
    "name": "White Background",
    "startMs": 0,
    "durationMs": 14000,
    "zIndex": -1000,
    "style": {
      "fill": "#FFFFFF"
    }
  }
}
```

The realtime app bridge should apply commands first because commands preserve
intent. Full state snapshots remain a fallback for recovery.

## 7. Canonical Command Taxonomy

Every MCP operation must map to one of these editor command types.

```text
project.create
composition.create
composition.update_settings

layer.insert
layer.update
layer.delete
layer.reorder
layer.select

background.set_solid
background.set_gradient

text.insert
text.update_content
text.update_style
text.update_layout
text.update_fit_policy

shape.insert
shape.update_geometry
shape.update_style

media.insert
media.replace_source
media.trim

transform.set
transform.patch

keyframe.insert
keyframe.update
keyframe.delete
keyframe.batch_apply

animation.apply_recipe
animation.remove

scene_program.apply
director_plan.compile_and_apply

effect.apply
effect.update
effect.remove

transaction.undo
transaction.redo
```

Any tool call that cannot map to this taxonomy must fail with:

```text
UNSUPPORTED_COMMAND_TYPE
```

and include a suggested supported command.

## 8. Canonical Remote Models

### 8.1 Remote Layer

```json
{
  "id": "uuid",
  "kind": "text | solid | shape | image | video | audio | adjustment",
  "name": "Title",
  "startMs": 0,
  "durationMs": 3000,
  "zIndex": 10,
  "visible": true,
  "locked": false,
  "transform": {
    "x": 0,
    "y": 0,
    "scaleX": 1,
    "scaleY": 1,
    "rotation": 0,
    "anchorX": 0.5,
    "anchorY": 0.5,
    "opacity": 1
  },
  "payload": {},
  "updatedAt": "2026-05-12T00:00:00Z"
}
```

### 8.2 Remote Text Payload

```json
{
  "text": "Welcome",
  "fontFamily": "Inter",
  "fontWeight": 500,
  "fontSize": 64,
  "color": "#111111",
  "align": "center",
  "maxLines": 2,
  "fitPolicy": "shrinkToFit",
  "bounds": {
    "x": 90,
    "y": 720,
    "width": 900,
    "height": 180
  }
}
```

### 8.3 Remote Shape Payload

```json
{
  "shape": "roundedRect",
  "bounds": {
    "x": 120,
    "y": 600,
    "width": 840,
    "height": 220
  },
  "radius": 36,
  "fill": "#FFFFFF",
  "stroke": "#111111",
  "strokeWidth": 2
}
```

### 8.4 Remote Animation Channel

```json
{
  "targetLayerId": "uuid",
  "property": "transform.opacity",
  "keyframes": [
    {
      "timeMs": 0,
      "value": 0,
      "easing": "easeOutCubic"
    },
    {
      "timeMs": 450,
      "value": 1,
      "easing": "easeOutCubic"
    }
  ]
}
```

## 9. Required App-Side Architecture

### 9.1 MCP Live Apply Bridge

New service:

```text
RefusionMcpLiveApplyBridge
```

Responsibilities:

- Own Supabase Realtime subscriptions for the active project.
- Listen to command inserts/updates.
- Listen to layer inserts/updates/deletes as fallback.
- Detect missed revisions.
- Request snapshot recovery when needed.
- Pass canonical commands into the local dispatcher.
- Acknowledge applied revisions.
- Surface diagnostics to the UI.

### 9.2 Local Command Dispatcher

New service:

```text
RefusionRemoteEditorCommandDispatcher
```

Responsibilities:

- Validate command payload shape.
- Check active project/composition match.
- Check `revisionBefore`.
- Enforce idempotency.
- Route to domain services.
- Produce local mutation result.
- Return structured success/failure.

### 9.3 Remote Model Mapper

New service:

```text
RefusionRemoteLayerMapper
```

Responsibilities:

- Convert remote `solid` layer to local background/solid layer.
- Convert remote `text` layer to local MotionText layer.
- Convert remote `shape` layer to local shape element.
- Convert remote `image/video/audio` metadata into local timeline clips.
- Convert remote transforms into existing transform channels.
- Convert remote keyframes into existing motion property channels.
- Preserve remote ids in `sourceBinding` metadata.

### 9.4 Applied Revision Store

The app must track:

```text
cloudRevisionSeen
cloudRevisionApplied
lastAppliedCommandIds
lastAppliedLayerUpdatedAt
pendingRemoteCommands
failedRemoteCommands
```

This prevents duplicate application and makes diagnostics clear.

## 10. Required Backend Architecture

### 10.1 Command Record Is Mandatory

Every mutating MCP tool must write `refusion_agent_commands` or equivalent
command history with:

```text
command_id
owner_id
agent_session_id
project_id
composition_id
command_type
payload
revision_before
revision_after
status
created_at
completed_at
idempotency_key
```

### 10.2 Payload Sanitization

Never persist secrets into layer payloads.

Strip these keys recursively from any stored payload:

```text
agentSessionToken
sessionToken
accessToken
refreshToken
authorization
password
secret
apiKey
```

### 10.3 Tool Result Semantics

An MCP tool result must distinguish:

```text
cloudCommitted: true
appApplied: false | true | unknown
revisionAfter: number
commandId: uuid
```

If the app has not acknowledged the revision yet, the tool may say:

```text
cloudCommitted: true
appApplied: "pending"
```

The agent should then call:

```text
refusion.wait_for_apply(commandId)
```

### 10.4 Wait For Apply Tool

New tool:

```text
refusion.wait_for_apply
```

Input:

```json
{
  "agentSessionToken": "...",
  "commandId": "uuid",
  "timeoutMs": 5000
}
```

Output:

```json
{
  "ok": true,
  "cloudCommitted": true,
  "appApplied": true,
  "appliedRevision": 4,
  "deviceId": "...",
  "latencyMs": 482
}
```

This is the difference between "database write succeeded" and "user sees it".

## 11. Realtime Strategy

### 11.1 Primary Path

Subscribe to:

```text
refusion_agent_commands
refusion_layers
refusion_project_revisions
```

filtered by:

```text
owner_id
project_id
composition_id
```

The command subscription is primary. Layer subscription is recovery/fallback.

### 11.2 Polling Fallback

The existing 8-second polling bridge remains only as fallback.

Polling must:

- fetch full command list since last applied revision,
- fetch full layer snapshot if revisions diverge,
- never choose layers by arbitrary order,
- choose latest state by `updated_at` / `revision`,
- repair local state when realtime was missed.

### 11.3 Recovery On Missed Revision

If app sees:

```text
cloudRevision > localAppliedRevision + 1
```

then it must:

```text
1. pause incremental apply
2. fetch authoritative project snapshot
3. reconcile remote layers/keyframes/effects
4. update localAppliedRevision
5. resume realtime apply
```

## 12. Local Apply Semantics

### 12.1 Solid Background

Remote:

```text
layer.kind = solid
payload.color = #FFFFFF
zIndex <= -1000
```

Local result:

```text
1. composition metadata backgroundColor updates
2. solid layer row appears in timeline if created as layer
3. canvas repaint occurs immediately
4. toast: "ChatGPT added White Background"
```

### 12.2 Text

Remote:

```text
layer.kind = text
payload.text/style/bounds
```

Local result:

```text
1. Motion text element is created
2. text appears on canvas
3. text layer appears in timeline
4. text properties become editable locally
5. sourceBinding.remoteLayerId is preserved
```

### 12.3 Shape

Remote:

```text
layer.kind = shape
payload.shape/fill/stroke/bounds
```

Local result:

```text
1. shape element is created
2. fill/stroke/radius are preserved
3. transform handles can select it
4. shape layer appears in timeline
```

### 12.4 Transform

Remote:

```text
commandType = transform.set | transform.patch
```

Local result:

```text
1. existing layer transform updates
2. transform overlay and rendered element stay locked together
3. no playback/live scrub reset
4. keyframe channel updates if command is animated
```

### 12.5 Animation / Keyframes

Remote:

```text
commandType = keyframe.batch_apply | animation.apply_recipe
```

Local result:

```text
1. motion property channels are created or patched
2. keyframes appear in Keyframe Motion Timeline
3. preview evaluates the animation at current playhead
4. next playback uses the same truth
```

### 12.6 SceneProgram / DirectorPlan

Remote:

```text
commandType = scene_program.apply | director_plan.compile_and_apply
```

Local result:

```text
1. scene program validates
2. transaction applies to local project
3. generated layers/elements/keyframes appear in timeline
4. visual QA diagnostics are attached
5. command acknowledges only after local apply succeeds
```

## 13. UI Feedback Requirements

The user must always know what happened.

### 13.1 Connected Indicator

Top bar:

```text
ChatGPT connected
```

### 13.2 Applying Indicator

When command arrives:

```text
Applying ChatGPT edit...
```

### 13.3 Success Toast

Examples:

```text
ChatGPT added White Background
ChatGPT added Title Text
ChatGPT animated Logo scale
```

### 13.4 Failure Toast

Examples:

```text
ChatGPT edit failed: unsupported shape type
ChatGPT edit rejected: stale revision
ChatGPT edit queued: app is offline
```

### 13.5 Diagnostics Panel

Developer mode must show:

```text
cloudRevision
localAppliedRevision
lastCommandId
lastCommandType
lastApplyLatencyMs
lastApplyError
realtimeConnected
pollingFallbackActive
```

## 14. Implementation Phases

### PRMEA-00 — Current Failure Fixture

Purpose: lock the current bug as a failing test.

Tasks:

- Create a fixture where MCP inserts a white solid background after an older
  blue layer.
- Prove current app chooses or keeps the wrong visual state.
- Prove cloud revision advances but local editor does not materialize the new
  layer.

Acceptance:

```text
Test fails before implementation.
Failure message says remote layer is present but not applied locally.
```

### PRMEA-01 — Snapshot Model Carries Remote Layers

Purpose: stop throwing away remote state.

Tasks:

- Extend `RefusionMcpCloudBridgeSnapshot`.
- Add `remoteLayers`.
- Add `remoteCommands` if command API is already available.
- Preserve `remoteRevision`.
- Extract latest solid layer by `updated_at` / revision, not list order.

Acceptance:

```text
Snapshot contains all returned layers.
Newest white solid wins over old blue solid.
```

### PRMEA-02 — Payload Sanitization In Edge Function

Purpose: prevent secrets from being stored in `refusion_layers.payload`.

Tasks:

- Add recursive payload sanitizer.
- Strip agent/session/auth/token/secret keys.
- Apply sanitizer to every mutating tool.
- Add regression for `agentSessionToken` nested inside payload.

Acceptance:

```text
No token-like key can be persisted into layer payload.
```

### PRMEA-03 — Remote Layer Mapper v1

Purpose: convert Supabase layer rows into local editor models.

Tasks:

- Implement mapper for `solid`, `text`, `shape`.
- Preserve remote ids in local metadata/source binding.
- Normalize colors, bounds, duration, zIndex, transforms.
- Reject unsupported payloads with structured errors.

Acceptance:

```text
Remote solid -> local background/layer.
Remote text -> visible local text element.
Remote shape -> visible local shape element.
```

### PRMEA-04 — Local Apply Dispatcher

Purpose: route remote changes through one controlled apply path.

Tasks:

- Add `RefusionRemoteEditorCommandDispatcher`.
- Implement idempotency.
- Check composition match.
- Check revision order.
- Apply mapped layers to MotionProject.
- Update local applied revision.

Acceptance:

```text
Same command applied twice changes local state once.
Wrong composition is rejected.
Stale revision is rejected or recovered.
```

### PRMEA-05 — Background Apply End-To-End

Purpose: make the simplest real MCP edit visible.

Tasks:

- Apply `solid` layers to active canvas.
- Materialize a timeline row when the command is a layer insert.
- Repaint canvas immediately.
- Add success toast.

Acceptance:

```text
ChatGPT insert_layer solid #FFFFFF appears in open app <= 8 seconds with polling.
Timeline shows the background layer.
```

### PRMEA-06 — Text Apply End-To-End

Purpose: make ChatGPT-created text visible and editable.

Tasks:

- Map text content/style/bounds.
- Create local text layer/element.
- Apply font size, color, opacity, alignment.
- Use text fit policy when provided.
- Make text selectable/editable after apply.

Acceptance:

```text
ChatGPT inserts text and user sees it on canvas and timeline.
Changing text color from MCP updates visible text.
```

### PRMEA-07 — Shape Apply End-To-End

Purpose: make ChatGPT-created shapes visible and editable.

Tasks:

- Map rectangle, rounded rectangle, ellipse, line.
- Apply fill/stroke/strokeWidth/radius.
- Apply bounds and transform.
- Make shape selectable with transform tool.

Acceptance:

```text
ChatGPT inserts shape and user sees it on canvas and timeline.
Shape style updates apply live.
```

### PRMEA-08 — Transform Apply End-To-End

Purpose: make MCP transform edits update the same truth as local transform UI.

Tasks:

- Add transform command mapper.
- Apply position/scale/rotation/opacity.
- Reuse existing motion/domain transform truth.
- Keep overlay and rendered element synchronized.

Acceptance:

```text
ChatGPT moves/scales/rotates a selected layer and canvas updates.
Transform overlay remains locked to the rendered layer.
```

### PRMEA-09 — Keyframe And Animation Apply

Purpose: make motion commands appear in the keyframe timeline.

Tasks:

- Map remote keyframe channels.
- Add/update/delete keyframes.
- Apply animation recipe outputs.
- Update Keyframe Motion Timeline.
- Verify preview at playhead.

Acceptance:

```text
ChatGPT adds opacity or position animation.
Keyframes appear locally.
Playback reflects the animation.
```

### PRMEA-10 — SceneProgram Apply Through MCP

Purpose: make larger ChatGPT-authored scenes apply transactionally.

Tasks:

- Route `scene_program.apply`.
- Validate program.
- Apply using existing transaction service.
- Return structured diagnostics.
- Acknowledge only after local apply.

Acceptance:

```text
ChatGPT applies a scene program and all generated layers/elements appear.
Failed scene programs do not partially mutate local state.
```

### PRMEA-11 — Supabase Realtime Subscription

Purpose: reduce live edit latency to < 1 second.

Tasks:

- Subscribe to command rows for active project/composition.
- Subscribe to layer rows as fallback.
- Reconnect automatically.
- Handle app foreground/background.
- Fall back to polling when realtime disconnects.

Acceptance:

```text
ChatGPT insert_layer appears in open app < 1 second.
If realtime drops, polling catches up.
```

### PRMEA-12 — Applied Revision Acknowledgement

Purpose: allow MCP clients to know when the user actually sees the edit.

Tasks:

- Add `refusion_editor_apply_receipts` or reuse command status fields.
- App posts `appliedRevision`, `commandId`, `latencyMs`.
- Backend exposes `refusion.wait_for_apply`.

Acceptance:

```text
ChatGPT can wait until appApplied=true before claiming completion.
```

### PRMEA-13 — Conflict And Offline Queue

Purpose: prevent random writes during stale/offline conditions.

Tasks:

- Reject stale revisions.
- Queue commands if app is offline only when safe.
- Show queued status in app.
- Reconcile on reconnect.

Acceptance:

```text
Commands never silently apply to the wrong revision.
Offline state is explicit to the user and agent.
```

### PRMEA-14 — Full Visual Command Coverage

Purpose: cover all core creative edits.

Tasks:

- Text content/style/layout.
- Solid and gradient backgrounds.
- Shape geometry/style.
- Image/video/audio placement metadata.
- Transform and opacity.
- Keyframes.
- Animation recipes.
- SceneProgram apply.

Acceptance:

```text
Every supported MCP tool either appears live in the open app or fails with a
clear actionable error.
```

### PRMEA-15 — End-To-End Agent Acceptance Suite

Purpose: prove production readiness.

Tests:

```text
1. ChatGPT creates white background -> visible <= 1s
2. ChatGPT adds title text -> visible <= 1s
3. ChatGPT changes text color -> visible <= 1s
4. ChatGPT adds rounded rectangle shape -> visible <= 1s
5. ChatGPT animates text opacity -> keyframes visible and playback works
6. ChatGPT moves shape -> transform overlay remains aligned
7. ChatGPT applies scene program -> all layers appear
8. duplicate command -> no duplicate layer
9. stale revision -> rejected
10. app offline -> agent gets appApplied=false/queued
```

Acceptance:

```text
All tests pass on connected Android device.
```

## 15. Data Integrity Rules

1. Remote ids must be preserved locally.
2. Local ids must not collide with remote ids.
3. Duplicate command ids must not duplicate layers.
4. Duplicate layer ids must update existing local layer, not insert a second
   copy.
5. Newer `updated_at` wins over older rows.
6. Revision order wins over zIndex order for state freshness.
7. zIndex only controls visual stacking, not freshness.
8. Secret-like keys must never enter project payloads.
9. Every failed apply must be recorded.
10. Every successful apply must be acknowledged.

## 16. Performance Budgets

```text
Realtime event received -> local apply start: <= 100ms
Simple solid/text/shape apply: <= 150ms
SceneProgram apply: <= 500ms for normal scenes
Canvas repaint after simple edit: <= 1 frame after setState
MCP tool -> app visible via realtime: <= 1000ms
MCP tool -> app visible via polling fallback: <= 8000ms
Snapshot recovery for <= 100 layers: <= 1200ms
```

## 17. Diagnostics Requirements

The app must expose a developer diagnostic panel or log entries:

```text
MCP endpoint
agent connected
active project id
active composition id
cloud revision
local applied revision
last command id
last command type
last apply result
last apply latency
realtime status
polling fallback status
last error
```

This prevents future "it says success but nothing changed" confusion.

## 18. Stop List

Do not ship if any of these are true:

```text
Cloud row exists but open app does not change.
MCP tool says success before local apply acknowledgement when wait is requested.
Layers are selected by reversed list order instead of revision/updated_at.
agentSessionToken or secrets are persisted in layer payload.
Text/style/shape/keyframe commands are stored but not rendered.
Realtime is absent and polling is the only production path.
Duplicate tool call creates duplicate layers.
Wrong composition receives a command.
Stage5/Live Scrub internals are touched without a separate approved plan.
```

## 19. Definition Of Done

PRMEA is complete only when:

```text
1. ChatGPT can connect through MCP pairing.
2. ChatGPT can insert background/text/shape.
3. ChatGPT can update text color/content/style.
4. ChatGPT can set transform.
5. ChatGPT can add keyframes/animations.
6. ChatGPT can apply a SceneProgram.
7. Every edit appears in the open app timeline/canvas in <= 1s.
8. wait_for_apply returns appApplied=true only after the app acknowledges.
9. Duplicate/stale/wrong-context commands are blocked.
10. Device acceptance suite passes.
```

## 20. First Implementation Order

The next agent must implement in this exact order:

```text
PRMEA-00
PRMEA-01
PRMEA-02
PRMEA-03
PRMEA-04
PRMEA-05
```

This gets the white-background bug fixed first and proves the full path from
ChatGPT to the open app. Do not start advanced animation work before the
background/text/shape apply path is reliable.

After `PRMEA-05`, continue:

```text
PRMEA-06 -> PRMEA-15
```

Each phase must be a focused checkpoint with verification, commit, push, and
device install when an Android device is connected.
