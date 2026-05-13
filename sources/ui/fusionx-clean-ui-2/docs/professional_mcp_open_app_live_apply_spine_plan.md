# Professional MCP Open-App Live Apply Spine Plan

Short name: `PMOLAS`

Status: official corrective architecture plan

Package: `com.refusion.app`

Date: 2026-05-13

Supersedes as the immediate execution spine for MCP live-apply failures:

- `professional_mcp_scene_truth_runtime_plan.md`
- `professional_realtime_mcp_editor_apply_plan.md`
- `professional_agent_composition_truth_graph_plan.md`
- `professional_composition_identity_continuity_spatial_truth_plan.md`
- `professional_canvas_visual_motion_engine_plan.md`

This plan does not replace those broader plans. It defines the mandatory
foundation that must be completed before expanding MCP tools, visual effects,
motion recipes, spatial recipes, or agent skills.

Protected boundary: this plan must not touch protected Stage5 / Live Scrub
internals unless a later explicit Live Scrub slice is approved.

## 1. Executive Decision

The remaining MCP problem is not "background failed", "video mask failed", or
"animation failed" as separate bugs.

The root problem is that ReFusionXx does not yet have one identity-bound
live-apply spine:

```text
open app session
  -> exact project/composition identity
  -> canonical agent/manual command
  -> local editor command dispatcher
  -> local graph mutation
  -> deterministic frame evaluation
  -> renderer proof
  -> commandId apply receipt
```

Until this spine exists, every feature can fail in a different form:

- ChatGPT writes to a cloud project while the app is on the home screen.
- ChatGPT writes to a stale project because the backend falls back to latest
  active project.
- A pairing code binds correctly to the wrong context because the context was
  stale at generation time.
- Supabase rows are accepted, but the open editor never receives a command.
- The app polls `get_layers` and guesses intent from rows instead of applying
  command transactions.
- Background, text, video, shape, motion, mask, border, glow, and shadow each
  follow different local paths.
- `appApplied=true` can be inferred from revision instead of proof that the
  command rendered in the exact open composition.

The new rule is:

```text
No MCP command is successful because Supabase accepted a row.
It is successful only when the exact open app applies that exact commandId and
returns a renderer proof receipt.
```

## 2. Independent Review Findings

Three independent reviews were used to define this plan.

### 2.1 Local Code Review

The current code has these structural gaps:

1. The Flutter editor creates local project/composition IDs and only reports
   them through MCP when it believes a composition has started.
2. The backend active-context resolver can fall back to the latest active
   project or create a default `MCP Project`.
3. Pairing is only correct if the active context at generation time is correct.
4. Scene-scope context can diverge from root composition matching.
5. The app consumes `get_layers` snapshots, not `refusion_agent_commands`.
6. Local apply gates can silently reject snapshots.
7. Command success is inferred from applied revision, not command-specific
   proof.
8. Renderer support for effects and motion is not part of the command success
   contract.

### 2.2 Remotion / HyperFrames Review

The professional invariant to borrow is not their implementation language.

The invariant is:

```text
composition dimensions + fps + duration + frame/time + graph -> deterministic
visual output
```

Remotion exposes `width`, `height`, `fps`, and `durationInFrames`, then
components evaluate from frame truth.

HyperFrames uses seek-driven rendering and frame adapters. Every render asks:

```text
What does this exact frame look like?
```

ReFusionXx must expose the same truth through native editor graph APIs:

- `get_composition_truth`
- `evaluate_frame`
- `get_element_geometry`
- `get_renderer_capabilities`
- `wait_for_apply`

### 2.3 Existing Plan Review

The existing plans already contain the right product direction:

- fresh composition identity,
- recent projects,
- composition truth graph,
- spatial solver,
- universal authored surfaces,
- renderer proof,
- `appApplied=true` only after visual proof.

The missing piece is strict execution order. The root live-apply spine must be
built before more creative tools.

## 3. Non-Negotiable Product Contract

### 3.1 Open Composition Contract

The app may expose MCP pairing only when an editor composition is actually open.

Valid open context:

```text
appSessionId
deviceId
projectId
compositionId
timelineId
playheadMs
selection
localRevision
cloudRevision
foreground/background status
```

Invalid context:

```text
home screen
create composition screen before creation
project picker
no active MotionProject
empty projectId
empty compositionId
fallback/latest project
```

If no composition is open:

```text
generate_pairing_code -> ACTIVE_COMPOSITION_REQUIRED
get_project_state -> hasProject=false or noActiveComposition=true
write tools -> OPEN_APP_COMPOSITION_REQUIRED
```

### 3.2 Fresh Composition Contract

`Create Composition` must be atomic:

```text
generate new projectId
generate new compositionId
create empty local graph
persist local snapshot
register/open app session with exact IDs
render empty canvas
```

No previous cloud layer, command, media clip, motion channel, pairing context,
or local cache may enter the new composition.

Previous work returns only through `Recent Projects`.

### 3.3 Pairing Contract

A pairing code binds to:

```text
userId
deviceId
appSessionId
projectId
compositionId
timelineId
localRevision/cloudRevision
selection/playhead
```

Agent tools must use the token-bound context. Freeform `projectId` and
`compositionId` in tool arguments may be accepted only as assertions. If they
do not match the token-bound open context, the command fails with:

```text
WRONG_ACTIVE_CONTEXT
```

### 3.4 Command Success Contract

Every MCP write has a `commandId`.

The command lifecycle is:

```text
accepted
cloud_committed
app_received
local_snapshot_applied
truth_graph_evaluated
visual_program_lowered
renderer_applied
visual_bounds_verified
app_applied
```

Failure states are explicit:

```text
wrong_context
unsupported_command
target_not_found
revision_conflict
renderer_capability_missing
local_apply_failed
visual_proof_failed
```

`appApplied=true` is allowed only for the exact `commandId`.

Revision-only acknowledgement is not a professional success model.

### 3.5 Universal Node Contract

Every timeline node must be an authored surface:

```text
identity
timeline lifetime
source binding
intrinsic geometry
visible bounds
transform
style stack
mask/crop stack
effect stack
motion channels
renderer capability state
diagnostics
```

This contract applies to:

```text
background
video
image
text
shape
audio
adjustment
scene clip
group/precomp
```

No feature may work only for text or only for video through a private path.

## 4. Root Causes To Eliminate

### 4.1 Backend Context Fallback

The backend must stop using latest active project as live-editor truth.

Allowed:

```text
explicit open app session with projectId + compositionId
agent session token bound to pairing context
explicit Recent Project open action
```

Forbidden in live-write paths:

```text
latest active project fallback
default MCP Project fallback
auto-create project during write
auto-create composition during write
active/default/comp_1/motion-project/scene-main production IDs
```

### 4.2 Snapshot-Driven Apply

`get_layers` is a read mirror. It is not the command bus.

The app must stop relying on:

```text
poll get_layers
infer layer kind
guess background/text/media intent
apply row heuristically
ack by revision
```

The app must use:

```text
subscribe/fetch command by commandId
dispatch command through one local command dispatcher
write command receipt
```

### 4.3 Revision-Only ACK

Revision tells us the cloud graph advanced. It does not prove which command was
applied, which renderer drew it, or whether the visible canvas changed.

Forbidden final behavior:

```text
ack all pending commands <= revision
mark appApplied=true because timelineRevision >= revisionAfter
return success while renderer did not draw the node/effect/motion
```

Required final behavior:

```text
ack commandId
include proof levels
include renderer diagnostics
include target IDs
include evaluated bounds
```

### 4.4 Renderer-Metadata Gap

Metadata is not visual truth.

If mask, glow, border, shadow, animation, crop, or motion blur is stored but
the renderer does not consume it, the command is not visually successful.

The renderer capability matrix must decide success:

```text
flutterPreview
nativePreview
playback
liveScrub
export
```

Unsupported paths must fail closed with diagnostics.

## 5. Canonical Architecture

### 5.1 Open App Session Registry

The app owns active session registration.

Required payload:

```text
deviceId
appSessionId
projectId
compositionId
timelineId
playheadMs
selection
revision
status
foreground
appVersion
platform
lastSeenAt
```

If the app leaves the editor screen, it must publish:

```text
hasActiveComposition=false
projectId=null
compositionId=null
```

Backend must not substitute old project IDs after this.

### 5.2 Canonical Editor Command Dispatcher

Create a single dispatcher for all mutations:

```text
MCP
manual UI
timeline UI
canvas gestures
SceneProgram
templates
future agent skills
```

All route to:

```text
ProfessionalEditorCommandDispatcher.apply(command)
```

Dispatcher responsibilities:

- validate active identity,
- resolve targets,
- apply mutation to local graph,
- produce undo/redo entry,
- evaluate affected frame(s),
- lower to visual program,
- request renderer apply,
- create command receipt.

### 5.3 Command Transport

Primary transport:

```text
Supabase Realtime subscription on refusion_agent_commands
filter: ownerId + projectId + compositionId + status in accepted/cloud_committed
```

Fallback:

```text
poll get_pending_commands after missed revision or reconnect
```

Snapshots remain read mirrors:

```text
get_layers
get_motion_channels
get_composition_truth
```

They must not be the primary apply mechanism.

### 5.4 Command Receipt

New receipt shape:

```text
commandId
projectId
compositionId
deviceId
appSessionId
receivedAt
localAppliedAt
renderVerifiedAt
localRevisionBefore
localRevisionAfter
cloudRevisionAfter
targetIds
proof:
  localSnapshotApplied: bool
  timelineVisible: bool
  canvasVisible: bool
  frameEvaluated: bool
  visualProgramLowered: bool
  rendererApplied: bool
  visualBoundsVerified: bool
diagnostics:
  warnings[]
  blockers[]
  rendererCapabilities
```

The server updates the command from the receipt by `commandId`.

## 6. Phased Execution Plan

### PMOLAS-00: Red Failure Fixtures

Create failing tests or reproducible diagnostics for current failures.

Required scenarios:

- App on home screen, MCP write attempted -> rejected as no open composition.
- Create Composition A red, Create Composition B blue -> no leakage.
- Reopen A/B from Recent -> correct contents.
- Pair to A, switch to B, agent writes -> rejected or requires re-pair.
- Insert background -> appears in timeline and canvas.
- Insert text -> appears in timeline and canvas.
- Insert shape -> appears in timeline and canvas.
- Apply animation -> creates motion channels, not solid/background.
- Apply video mask/border/glow -> renderer either draws or blocks explicitly.
- `wait_for_apply` cannot succeed from DB write alone.

Gate:

```text
Every failure logs commandId, projectId, compositionId, appSessionId,
revision, stoppedStage, and diagnostic reason.
```

### PMOLAS-01: Active Composition Fail-Closed Context

Implement strict context behavior.

Requirements:

- When no composition is open, the app publishes `hasActiveComposition=false`.
- Backend returns no active editable project for live writes.
- `generate_pairing_code` fails with `ACTIVE_COMPOSITION_REQUIRED`.
- `get_project_state` reports no active composition instead of latest project.
- Existing project fallback is allowed only for explicit Recent/open flows.

Gate:

```text
ChatGPT cannot write a background while the app is on the ReFusion Studio
home screen.
```

### PMOLAS-02: Cloud-Backed Composition Identity

When creating a composition, reserve/persist cloud identity immediately.

Requirements:

- `Create Composition` creates or reserves project/composition records.
- Local `MotionProjectModel.id` equals cloud `projectId`.
- Root scene/composition id equals cloud `compositionId`.
- App session uses these exact IDs.
- No local-only UUID may become invisible to Supabase live tools.

Gate:

```text
Immediately after Create Composition, get_project_state returns the exact IDs
shown in local editor diagnostics.
```

### PMOLAS-03: Pairing Bound To App Session

Pairing code generation must bind to the exact open app session.

Requirements:

- Pairing row includes `appSessionId`, `deviceId`, `projectId`,
  `compositionId`, `timelineId`, `selection`, and `revision`.
- Agent session token inherits this context.
- Tool argument project/composition mismatch returns `WRONG_ACTIVE_CONTEXT`.
- Switching projects invalidates or suspends old agent session.

Gate:

```text
An agent paired to Composition A cannot mutate Composition B after the user
switches without a new pairing or explicit approved retarget.
```

### PMOLAS-04: Command Bus And Local Dispatcher

Stop applying remote edits from layer snapshots.

Requirements:

- Add `get_pending_commands` or realtime command subscription.
- App receives commands by `commandId`.
- App routes all remote commands through `ProfessionalEditorCommandDispatcher`.
- Snapshots are used for inspection/recovery only.
- Unsupported command types return `app_failed`, not silent ignore.

Gate:

```text
MCP insert background creates one command, the app receives that commandId,
applies it through dispatcher, and writes a command receipt.
```

### PMOLAS-05: CommandId Apply Receipts

Replace revision-only success with command-specific proof.

Requirements:

- Server accepts `ack_command_applied(commandId, receipt)`.
- Revision-only ACK is removed or limited to diagnostics.
- `wait_for_apply(commandId)` returns the receipt.
- Multiple commands at the same or lower revision are not auto-succeeded.

Gate:

```text
Command A can succeed while Command B at same revision can fail if renderer
proof differs.
```

### PMOLAS-06: Minimal Universal Node Apply

Implement minimum command support through one node model:

- background solid layer,
- text layer,
- shape rectangle/ellipse,
- media transform/style update,
- opacity,
- position,
- scale,
- rotation,
- duration/start time.

Gate:

```text
All four visible layer families can be inserted/updated by MCP and manual UI
through the same dispatcher path.
```

### PMOLAS-07: Motion And Keyframe Lowering

No animation may live only in payload metadata.

Requirements:

- animation recipes lower to `MotionPropertyChannelModel`,
- raw keyframes lower to motion channels,
- edits merge phases rather than replace full animation,
- `animate_layer` legacy payload is migrated or rejected, never solid.

Gate:

```text
Add popup entrance, then add exit-right. Result is one target with two motion
phases, not duplicate layers or overwritten animation.
```

### PMOLAS-08: Renderer Capability And Proof

Renderer proof becomes part of success.

Requirements:

- Capability matrix for background/text/shape/video/image/effects/motion.
- Renderer adapters consume the same evaluated visual program.
- Unsupported effects return blockers.
- Mask/border/glow are not success until visible on the relevant renderer.

Gate:

```text
Video circle mask either visibly renders and receipts rendererApplied=true, or
fails with RENDERER_CAPABILITY_MISSING. No metadata-only success.
```

### PMOLAS-09: Composition Truth Graph

Expose complete context to agents.

Required tools:

```text
get_composition_truth
get_asset_inventory
get_timeline_graph
get_surface_visual_state
get_element_geometry
get_motion_channels
get_renderer_capabilities
evaluate_frame
```

Gate:

```text
Agent can identify uploaded video, duration, source range, timeline range,
rendered bounds, current transform, effects, and active motion channels before
editing.
```

### PMOLAS-10: Spatial Solver

Stop spatial guessing.

Required operations:

```text
surface.position.at_anchor
surface.move.to_anchor
surface.fit_in_zone
surface.scale_to
surface.keep_in_canvas
surface.exit.direction
recipe.circular_pip_to_corner
```

Gate:

```text
For Story 1080x1920, circular PIP diameter 360 and margin 72:
topRight center is x=828 y=252 absolute, x=288 y=-708 center-origin.
```

### PMOLAS-11: Diagnostics Panel

Add visible diagnostics for agent work.

Must show:

```text
active project/composition
app session/device
pairing status
realtime status
last commandId
command stage
local/cloud revision
renderer proof
last blocker
```

Gate:

```text
When a command fails, the user sees where it stopped and why.
```

### PMOLAS-12: Legacy Cleanup

After all gates pass, remove unsafe paths:

- latest-solid-wins background inference,
- scene-program fallback to animate existing layer,
- snapshot-driven apply as primary path,
- default/latest project live-write fallback,
- revision-only command success,
- metadata-only effect success.

Gate:

```text
Production grep proves forbidden paths are removed or test-only.
```

## 7. Minimum Build Slice

The first implementation slice must be intentionally small:

```text
1. Fail closed when no open composition.
2. Make Create Composition register exact cloud identity.
3. Add command polling/subscription for commandId.
4. Apply only background solid through local dispatcher.
5. ACK only that commandId with a real receipt.
6. Prove wait_for_apply returns appApplied=true only after canvas changes.
```

Do not start video mask/glow/motion work until this slice is green.

## 8. Stop List

Do not:

- add more creative MCP tools before the live-apply spine is green,
- report `appApplied=true` from Supabase row success,
- ack by revision as the final model,
- let backend live writes fall back to latest project,
- allow pairing from the home screen,
- apply remote edits from `get_layers` as the primary path,
- store animation/effects as `solid`,
- mutate background from non-background commands,
- treat metadata as renderer success,
- guess spatial pixels when anchor/zone solver is available,
- build MCP-only behavior that manual UI cannot reuse,
- touch protected Stage5 / Live Scrub internals in this plan.

## 9. Acceptance Suite

### 9.1 No Open Composition

```text
Open app home screen
Call generate_pairing_code
Expected: ACTIVE_COMPOSITION_REQUIRED
Call insert_layer through any old token
Expected: WRONG_ACTIVE_CONTEXT or OPEN_APP_COMPOSITION_REQUIRED
```

### 9.2 Simple Live Background

```text
Create new Story composition
Pair agent
Agent inserts purple background
Expected:
  commandId exists
  app receives commandId
  timeline has one background layer
  canvas is purple
  wait_for_apply(commandId).appApplied=true
  proof.canvasVisible=true
```

### 9.3 Command Isolation

```text
Create A red
Create B blue
Send stale command targeting A while B is active
Expected: rejected, B remains blue
```

### 9.4 Sequential Motion Merge

```text
Add video
Command 1: circular PIP top-right
Command 2: popup intro
Command 3: exit right
Expected:
  one video node
  one style stack
  one motion timeline with phases
  no background mutation
```

### 9.5 Renderer Proof

```text
Apply mask/border/glow to video
If supported: visible proof true
If not supported: renderer capability blocker returned
Never: appApplied=true with metadata-only effect
```

## 10. Final Definition Of Done

The MCP live-apply system is done only when this is true:

```text
ChatGPT command
  -> exact open composition
  -> commandId transaction
  -> local dispatcher
  -> graph mutation
  -> timeline visible
  -> canvas visible
  -> frame evaluation proof
  -> renderer proof
  -> commandId appApplied receipt
```

Anything less is a partial prototype, not the professional product path.
