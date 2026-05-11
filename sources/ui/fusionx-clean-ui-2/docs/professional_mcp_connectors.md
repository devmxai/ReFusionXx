# Professional MCP Connectors

Status: ready for implementation  
Package: `com.refusion.app`  
Date: 2026-05-11  
Short name: `PMC`  
Primary goal: make ReFusionXx controllable by AI agents through MCP without
manual script copying, without UI automation as the primary path, and without
unsafe access to playback, Live Scrub, export, or native media internals.

## 1. Executive Decision

ReFusionXx will expose a professional **MCP Agent Control Plane**.

The agent should be able to:

- read the active project,
- inspect the timeline,
- inspect the selected layer,
- capture preview frames,
- validate a `SceneProgram`,
- compile a `DirectorPlan`,
- apply scenes transactionally,
- edit keyframes,
- apply motion patches,
- set transforms,
- run visual diagnostics,
- undo and redo every mutation.

The agent must not:

- press UI buttons as the main integration path,
- write directly into Stage5 or Live Scrub internals,
- bypass timeline revisions,
- mutate project state without a transaction,
- inject executable code,
- read or write arbitrary files,
- apply stale commands against an older timeline revision.

The implementation model is:

```text
Claude / ChatGPT / Codex / Cursor / other MCP client
  -> ReFusion MCP Server
  -> ReFusion App Bridge
  -> Flutter Command Bus
  -> Domain Services
  -> Project / Timeline / SceneProgram / Preview / Export
```

The MCP server is a controlled gateway. It is not a second editor engine.

## 2. Why This Plan Exists

The current authoring flow can accept scripts, scene programs, presets, motion
patches, and direct UI edits. That is powerful, but it forces AI agents to work
through fragile paths:

- copy JSON into import UI,
- ask the user to manually paste scripts,
- rely on present presets,
- infer the screen state from screenshots,
- indirectly modify motion through UI actions.

MCP solves the wrong layer only if it is implemented as UI automation.

The correct layer is a structured command and resource surface:

```text
tools    = actions the agent can perform
resources = project/timeline/preview state the agent can read
prompts  = safe workflows the agent can follow
```

This gives ReFusionXx the same strategic advantage that Remotion has for agents:
the project becomes inspectable, deterministic, schema-driven, and editable
through stable primitives.

## 3. Reference Architecture Lessons

### 3.1 Remotion Lessons To Preserve

Remotion's strongest architecture lesson is deterministic video authoring:

```text
frame + props + assets -> pixels
```

ReFusionXx should preserve the same principle for all MCP operations.

Required concepts:

- `CompositionSpec`: `id`, `width`, `height`, `fps`, `durationFrames`,
  `propsSchema`, `defaultProps`.
- `Sequence` or `timeScope`: `from`, `duration`, `localFrame`,
  `absoluteFrame`.
- `FrameContext`: `frame`, `timeMs`, `fps`, `progress`, `localProgress`.
- JSON-only props and schemas.
- deterministic asset resolution.
- same evaluated truth for preview, QA, and export.
- no wall-clock randomness in rendering.

### 3.2 MCP Lessons To Preserve

MCP is a client-server protocol based on JSON-RPC. Servers expose:

- tools for actions,
- resources for context,
- prompts for reusable workflows.

Transport can be local `stdio` or network-capable Streamable HTTP. ReFusion
must start with local development-first MCP, then expand to a production-safe
paired bridge.

### 3.3 ReFusion Codebase Lessons

The strongest existing ReFusion entry points are not widgets. They are domain
services:

- Scene Program validation and import.
- Scene Program authoring and lowering.
- Scene apply transactions.
- DirectorPlan compilation.
- Motion patch import and application.
- Unified keyframe operations.
- frame evaluation adapters.
- unified timeline projection adapters.

MCP must sit on top of those services, not beside them.

## 4. Non-Negotiable Boundaries

### 4.1 Protected Paths

The MCP work must not directly modify or command:

- `Stage5TimelineScrubPlatformView`,
- `Stage5NativeScrubEngine`,
- `Stage5SurfaceScrubDecoder`,
- `Stage5ScrubOverlayTextureView`,
- `Stage5PreviewPlatformView`,
- Flutter Live Scrub handoff paths,
- native playback clocks,
- native decoder internals.

If a later phase appears to require these, implementation must stop and open a
new explicitly approved Live Scrub plan.

### 4.2 No UI Automation As Core

The MCP connector must not be built as "click this button, drag this handle".

Allowed:

```text
refusion.set_element_transform(...)
refusion.keyframe_edit(...)
refusion.apply_motion_patch(...)
```

Forbidden as primary architecture:

```text
tap toolbar button
drag the canvas handle
paste script into bottom sheet
simulate double tap in timeline
```

UI automation may be used only for QA tests, never as the command system.

### 4.3 Transactional Mutations Only

Every state-changing MCP tool must use:

- `mode: dryRun | commit`,
- `expectedRevision`,
- `idempotencyKey`,
- transaction diff,
- rollback data,
- undo/redo integration.

No mutating command may apply directly to `_motionProject`,
`_universalMotionPropertyChannels`, native runtime state, or widget-local state.

## 5. Core Architecture

### 5.1 Components

```text
ReFusionMcpServer
  - exposes MCP tools/resources/prompts
  - validates tool schemas
  - manages client sessions
  - talks to ReFusionAppBridge

ReFusionAppBridge
  - receives MCP command envelopes
  - sends them into Flutter
  - returns structured results/resources
  - supports local development transport first

RefusionCommandBus
  - routes commands to domain services
  - enforces capabilities
  - enforces expectedRevision
  - creates transactions

RefusionTransactionManager
  - dryRun
  - commit
  - undo
  - redo
  - rollback
  - batch mutation safety

RefusionResourceProvider
  - project state
  - timeline summary
  - selection
  - playhead
  - preview frames
  - scene diagnostics

RefusionCapabilityGate
  - user/session permissions
  - dangerous action confirmations
  - filesystem and export restrictions
```

### 5.2 Data Flow

```text
MCP tool call
  -> schema validation
  -> session lookup
  -> capability check
  -> expectedRevision check
  -> dry-run or commit command
  -> domain service execution
  -> transaction record
  -> preview/evaluation diagnostics
  -> structured MCP result
```

### 5.3 Command Envelope

All MCP writes must normalize into this shape:

```json
{
  "commandId": "cmd_01HV...",
  "sessionId": "session_abc",
  "projectId": "active",
  "capability": "motion.write",
  "mode": "dryRun",
  "expectedRevision": 1204,
  "idempotencyKey": "agent-turn-17-op-2",
  "payload": {
    "type": "motion.setElementTransform",
    "elementId": "clip_hero_video",
    "position": { "x": 120, "y": -40 },
    "scale": { "x": 0.82, "y": 0.82 },
    "rotationDegrees": 0,
    "writeMode": "static"
  }
}
```

### 5.4 Command Result

```json
{
  "ok": true,
  "transactionId": "txn_774",
  "requiresConfirmation": false,
  "summary": "Set transform for clip_hero_video",
  "revisionBefore": 1204,
  "revisionAfter": 1205,
  "affectedObjects": ["clip_hero_video"],
  "patchPreview": {
    "changedProperties": ["position", "scale"],
    "diagnostics": []
  }
}
```

## 6. Capability Model

Capabilities are mandatory.

```text
project.read          read project metadata and active composition
timeline.read         read clips, layers, selection, playhead
timeline.write        insert, move, split, trim, duplicate, delete layers
motion.write          transforms, keyframes, motion patches
scene.write           apply SceneProgram or DirectorPlan
preview.read          capture preview frames and diagnostics
transport.control     seek, play, pause
media.import          import user-approved media
export.start          start export
filesystem.read       disabled by default
filesystem.write      disabled by default
debug.diagnostics     local development only
```

Dangerous operations must return `requiresConfirmation: true` unless the session
was explicitly granted the capability.

Dangerous examples:

- delete layer,
- overwrite whole scene,
- import external media,
- export,
- filesystem read/write,
- batch operation affecting many clips,
- any operation where `expectedRevision` mismatches.

## 7. Session State

Each MCP client session stores:

```text
sessionId
clientName
clientVersion
connectionTransport
activeProjectId
activeCompositionId
timelineRevision
selectedObjectIds
playheadMs
previewMode
grantedCapabilities
pendingTransactions
lastPreviewFrameResourceUri
lastDiagnosticsResourceUri
createdAt
lastSeenAt
```

The session must be explicit and observable. A command from an unknown or stale
session must fail closed.

## 8. MCP Resources

Resources expose context without mutating the project.

Required resources:

```text
refusion://project/active/state
refusion://project/active/composition
refusion://project/active/timeline-summary
refusion://project/active/selection
refusion://project/active/playhead
refusion://project/active/scene-program
refusion://project/active/director-plan
refusion://preview/frame/latest
refusion://preview/frame/{timeMs}
refusion://diagnostics/evaluated-frame-truth
refusion://diagnostics/visual-harmony
refusion://diagnostics/scene-program-validation
```

Resource payloads must be compact by default. Large payloads must be paginated or
served by URI.

## 9. MCP Tools

### 9.1 Read Tools

#### `refusion.get_project_state`

Returns active project metadata, composition settings, fps, duration, revision,
and capabilities.

Required capability: `project.read`

#### `refusion.get_timeline_summary`

Returns a compact layer/clip list, start/end times, track order, selected state,
and revision.

Required capability: `timeline.read`

#### `refusion.get_selection`

Returns selected layer/clip/element IDs and their editable capabilities.

Required capability: `timeline.read`

#### `refusion.get_playhead`

Returns current playhead time and frame.

Required capability: `timeline.read`

### 9.2 Preview Tools

#### `refusion.seek_preview`

Seeks preview to a given `timeMs` through the existing Flutter transport command
path. Must not call native transport directly from MCP.

Required capability: `transport.control`

#### `refusion.capture_preview_frame`

Captures a preview frame at `timeMs` or current playhead and returns a resource
URI plus frame metadata.

Required capability: `preview.read`

#### `refusion.evaluate_frame`

Returns evaluated frame truth: element bounds, transforms, opacity, visible
state, and diagnostics for a specified time.

Required capability: `preview.read`

### 9.3 Scene Authoring Tools

#### `refusion.validate_scene_program`

Validates a SceneProgram without applying it.

Must reuse the same rules as the existing import service:

- schema validation,
- unsafe key denial,
- layout and timing validation,
- visual diagnostics where available.

Required capability: `scene.write` for commit mode, `project.read` for validate
only.

#### `refusion.author_scene_program`

Runs the authoring pipeline and returns an authoring result without committing
unless `mode=commit`.

Required capability: `scene.write`

#### `refusion.apply_scene_program`

Applies a valid SceneProgram transactionally.

Required fields:

```text
sessionId
expectedRevision
mode
sceneProgram
replaceExisting
startTimeMs
```

Required capability: `scene.write`

#### `refusion.compile_director_plan`

Compiles a `DirectorPlan` to a SceneProgram, validates it, and returns compile
diagnostics.

Required capability: `scene.write` for commit mode.

### 9.4 Timeline Tools

#### `refusion.insert_layer`

Inserts a layer of one of these types:

```text
solid
adjustment
media
text
shape
audio
scene
```

Required capability: `timeline.write`

#### `refusion.split_at_playhead`

Splits selected clip or given clip at current playhead.

Required capability: `timeline.write`

#### `refusion.trim_layer`

Adjusts layer start/end time.

Required capability: `timeline.write`

#### `refusion.move_layer`

Moves a layer in time or track order.

Required capability: `timeline.write`

#### `refusion.delete_layer`

Deletes layer with confirmation unless session has elevated write capability.

Required capability: `timeline.write`

### 9.5 Motion Tools

#### `refusion.set_element_transform`

Sets or keyframes transform for any editable element:

```text
position
scale
rotation
anchor
opacity
```

This must call the same domain logic used by user transform operations, not the
canvas overlay widget.

Required capability: `motion.write`

#### `refusion.keyframe_edit`

Unified keyframe operation:

```text
add
set
move
delete
ease
```

Must route through unified keyframe operations.

Required capability: `motion.write`

#### `refusion.apply_motion_patch`

Applies declarative motion JSON to selected or targeted elements.

Required capability: `motion.write`

### 9.6 Transaction Tools

#### `refusion.dry_run_command`

Runs any command envelope in dry-run mode and returns patch preview.

#### `refusion.commit_transaction`

Commits a pending transaction.

#### `refusion.undo_transaction`

Undoes a transaction created through MCP or normal UI command history.

#### `refusion.redo_transaction`

Redoes transaction.

#### `refusion.list_recent_transactions`

Returns recent transaction summaries.

## 10. MCP Prompts

Prompts guide agents into safe workflows.

Required prompts:

### `refusion.prompt.create_professional_scene`

Guides an agent to create a `DirectorPlan`, compile it, validate it, capture a
preview frame, and only then apply.

### `refusion.prompt.repair_scene_visual_issue`

Uses preview diagnostics and evaluated frame truth to produce a targeted patch.

### `refusion.prompt.animate_selected_layer`

Reads selected layer capabilities, proposes motion, dry-runs keyframes, and
commits after validation.

### `refusion.prompt.audit_before_export`

Checks timeline, missing assets, visual harmony, preview frame, and export
readiness.

## 11. Proposed Files

The exact paths may be refined during implementation, but the agent should use
this shape unless the codebase clearly indicates a better local pattern.

### 11.1 Dart Domain Layer

```text
lib/features/editor/domain/mcp/
  refusion_mcp_command.dart
  refusion_mcp_command_result.dart
  refusion_mcp_capability.dart
  refusion_mcp_session.dart
  refusion_mcp_transaction.dart
  refusion_mcp_command_bus.dart
  refusion_mcp_transaction_manager.dart
  refusion_mcp_resource_provider.dart
  refusion_mcp_tool_registry.dart
```

### 11.2 Flutter Bridge Layer

```text
lib/features/editor/presentation/mcp/
  refusion_mcp_app_bridge.dart
  refusion_mcp_bridge_controller.dart
  refusion_mcp_preview_resource_provider.dart
```

### 11.3 Local MCP Server

The server may be implemented in Dart or Node. The preferred MVP is Node or Dart
based on the project team's existing local tooling. It must talk to the Flutter
app bridge through a local bridge, not by reading app memory or controlling UI.

```text
tools/refusion_mcp_server/
  README.md
  package.json or pubspec.yaml
  src/server.*
  src/tools/*
  src/resources/*
  src/prompts/*
  src/refusion_bridge_client.*
  schemas/*.schema.json
```

### 11.4 Tests

```text
test/mcp/
  refusion_mcp_command_bus_test.dart
  refusion_mcp_transaction_manager_test.dart
  refusion_mcp_resource_provider_test.dart
  refusion_mcp_scene_program_tool_test.dart
  refusion_mcp_keyframe_tool_test.dart
  refusion_mcp_expected_revision_test.dart
```

Server tests:

```text
tools/refusion_mcp_server/test/
  tools_list_test.*
  dry_run_command_test.*
  scene_program_validation_test.*
  resources_test.*
```

## 12. Phase Plan

### PMC-00 - Inventory And Boundary Audit

Purpose: map existing domain services and confirm protected boundaries.

Tasks:

- inventory scene import, authoring, apply transaction, motion patch, keyframe,
  frame evaluation, timeline projection, preview capture, export paths.
- record which services are safe for MCP wrapping.
- record which files are protected.
- produce implementation notes in `docs/professional_mcp_connectors_inventory.md`.

Acceptance:

- no code behavior changed.
- protected Live Scrub and Stage5 paths explicitly listed.
- first tool candidates mapped to real services.

Verification:

- `rg` inventory references.
- documentation review.

### PMC-01 - Command Envelope And Capability Model

Purpose: define the shared command contract for every MCP mutation.

Tasks:

- add command envelope model.
- add command result model.
- add capability enum.
- add session model.
- add validation helpers.

Acceptance:

- command cannot be constructed without session id, capability, mode, and
  idempotency key.
- mutating commands require `expectedRevision`.
- unsupported capability fails closed.

Verification:

- targeted Dart tests.

### PMC-02 - Transaction Manager Foundation

Purpose: make every future MCP write reversible.

Tasks:

- implement dry-run result type.
- implement pending transaction record.
- implement commit/undo/redo contract.
- integrate with existing command history where available.
- do not wire any tool yet.

Acceptance:

- dry-run creates no project mutation.
- commit produces revision change.
- undo restores previous revision for test fixtures.

Verification:

- transaction manager tests.

### PMC-03 - Read-Only Resource Provider

Purpose: expose project context safely.

Tasks:

- implement project state resource.
- implement timeline summary resource.
- implement selection resource.
- implement playhead resource.
- implement compact serialization.

Acceptance:

- resources are read-only.
- payloads include revision.
- missing active project returns structured error.

Verification:

- resource provider tests.

### PMC-04 - Preview And Evaluation Resources

Purpose: give agents visual context without UI automation.

Tasks:

- add `evaluate_frame` domain wrapper.
- add preview frame resource contract.
- return bounds/transforms/opacity/visibility diagnostics.
- keep native preview ownership intact.

Acceptance:

- frame evaluation can run without mutating state.
- returned diagnostics include coordinate system and canvas size.
- no direct Stage5 protected file changes.

Verification:

- frame evaluation tests.

### PMC-05 - SceneProgram MCP Tools

Purpose: let agents author and apply complete scenes safely.

Tasks:

- implement `validate_scene_program`.
- implement `author_scene_program`.
- implement `apply_scene_program`.
- reuse existing unsafe-key denylist.
- use transaction manager for apply.

Acceptance:

- invalid SceneProgram returns structured errors.
- unsafe keys are rejected.
- valid dry-run returns patch preview.
- commit applies through transaction.
- undo removes the applied scene.

Verification:

- scene program MCP tool tests.

### PMC-06 - DirectorPlan MCP Tool

Purpose: allow agents to create scenes from higher-level intent.

Tasks:

- implement `compile_director_plan`.
- return compile diagnostics.
- optionally chain to SceneProgram validation.
- do not auto-commit without explicit mode.

Acceptance:

- DirectorPlan can compile to SceneProgram in dry-run.
- compile errors include exact path and repair hint.
- commit path is transaction protected.

Verification:

- director plan tool tests.

### PMC-07 - Motion Patch And Keyframe Tools

Purpose: let agents repair and animate existing elements.

Tasks:

- implement `apply_motion_patch`.
- implement `keyframe_edit`.
- implement `set_element_transform`.
- route through existing keyframe and motion services.
- support static and keyframe write modes.

Acceptance:

- tool can add a position keyframe.
- tool can set static transform.
- tool can update easing.
- stale revision fails.
- undo restores previous motion state.

Verification:

- keyframe and motion MCP tests.

### PMC-08 - Timeline Tools

Purpose: support direct editing of timeline layers.

Tasks:

- implement `insert_layer`.
- implement `split_at_playhead`.
- implement `trim_layer`.
- implement `move_layer`.
- implement `delete_layer` with confirmation requirement.

Acceptance:

- tools return patch preview in dry-run.
- commit changes timeline revision.
- delete requires elevated capability or confirmation.
- operations work on unified timeline projection without replacing timeline
  engine.

Verification:

- timeline command tests.

### PMC-09 - Local MCP Server MVP

Purpose: expose the first real MCP server for local clients.

Tasks:

- create local MCP server package.
- expose tools/list.
- expose resources/list and resources/read.
- expose prompts/list and prompts/get.
- connect to app bridge.
- support local development transport.

Acceptance:

- MCP Inspector can list tools.
- MCP Inspector can call read-only tools.
- server starts with clear logs.
- server fails if app bridge unavailable.

Verification:

- server unit tests.
- MCP Inspector manual verification.

### PMC-10 - Flutter App Bridge

Purpose: connect local MCP server to the running ReFusion app.

Tasks:

- implement app bridge controller.
- support pairing/session token for local development.
- route bridge messages into command bus.
- stream tool results back to MCP server.
- expose bridge status diagnostics.

Acceptance:

- app shows bridge available in debug diagnostics.
- invalid session rejected.
- command bus receives a read-only command from MCP server.

Verification:

- app bridge tests.
- local manual test with running app.

### PMC-11 - Security And Confirmation Gates

Purpose: prevent unsafe external control.

Tasks:

- implement capability grants.
- implement confirmation result flow.
- block filesystem read/write by default.
- block export by default.
- block destructive commands without confirmation.
- ensure all tool errors are structured.

Acceptance:

- destructive tool returns `requiresConfirmation`.
- filesystem tool unavailable unless explicitly enabled.
- missing capability fails closed.

Verification:

- capability gate tests.

### PMC-12 - Agent Skill And Authoring Guide

Purpose: teach AI agents how to use ReFusion MCP correctly.

Tasks:

- add `refusion-mcp-agent-control/SKILL.md` or equivalent local skill guide.
- document safe workflows.
- document example prompts.
- document common repair loop.
- document SceneProgram and DirectorPlan usage through MCP.

Acceptance:

- agent guide explains read, dry-run, commit, screenshot, repair, undo.
- guide warns against UI automation.
- examples use exact tool names.

Verification:

- documentation inspection.

### PMC-13 - End-To-End Agent Workflow Test

Purpose: prove the full control plane works.

Test workflow:

```text
agent connects
-> reads active project
-> reads timeline
-> inserts text layer in dry-run
-> commits
-> sets transform
-> adds keyframes
-> captures preview frame
-> validates diagnostics
-> undoes changes
```

Acceptance:

- no manual paste.
- no UI automation.
- all mutations transaction-backed.
- preview resource visible to agent.
- undo restores original state.

Verification:

- local E2E script or MCP Inspector workflow.

### PMC-14 - ChatGPT / Claude / Codex Compatibility Packaging

Purpose: make the connector usable by real agent clients.

Tasks:

- document Claude Desktop/Claude Code setup for local MCP.
- document Codex local MCP usage.
- document ChatGPT integration path through supported connector/App SDK surface
  where available.
- provide server config examples.
- provide troubleshooting checklist.

Acceptance:

- at least one local MCP host can connect.
- setup docs include command, transport, capabilities, and limitations.
- ChatGPT section is honest: if an official connector path requires Apps SDK
  packaging, it must state that clearly.

Verification:

- manual connection verification.

### PMC-15 - Production Hardening

Purpose: make the bridge safe beyond local debugging.

Tasks:

- encrypted pairing token.
- session expiration.
- audit log.
- rate limits.
- command size limits.
- resource size limits.
- telemetry events for tool calls.
- crash-safe transaction rollback.

Acceptance:

- no unauthenticated bridge access.
- audit log records tool, client, capability, revision, result.
- oversized tool call rejected.
- long-running operation returns progress.

Verification:

- security and failure-mode tests.

## 13. First MVP Tool Set

The implementation must not start with every tool. Start with this exact MVP:

```text
refusion.get_project_state
refusion.get_timeline_summary
refusion.get_selection
refusion.capture_preview_frame
refusion.validate_scene_program
refusion.author_scene_program
refusion.apply_scene_program
refusion.undo_transaction
```

Only after those are stable:

```text
refusion.apply_motion_patch
refusion.keyframe_edit
refusion.set_element_transform
refusion.insert_layer
refusion.split_at_playhead
```

## 14. Tool Schema Standards

Every tool must include:

- name,
- title,
- description,
- required capability,
- input schema,
- output schema,
- failure modes,
- dry-run behavior,
- commit behavior,
- revision requirements,
- undo behavior.

Every output must include:

```text
ok
summary
sessionId
revisionBefore
revisionAfter? 
transactionId?
diagnostics[]
resourceUris[]
requiresConfirmation
```

## 15. Error Model

All errors are structured:

```json
{
  "ok": false,
  "error": {
    "code": "REVISION_CONFLICT",
    "message": "Timeline revision changed before commit.",
    "expectedRevision": 1204,
    "actualRevision": 1207,
    "repair": "Read refusion://project/active/timeline-summary and retry."
  }
}
```

Required error codes:

```text
SESSION_NOT_FOUND
CAPABILITY_DENIED
REVISION_CONFLICT
VALIDATION_FAILED
UNSAFE_SCENE_PROGRAM
TRANSACTION_NOT_FOUND
CONFIRMATION_REQUIRED
PROJECT_NOT_OPEN
SELECTION_EMPTY
PREVIEW_UNAVAILABLE
BRIDGE_UNAVAILABLE
TIMEOUT
INTERNAL_ERROR
```

## 16. Security Rules

### 16.1 Scene Program Safety

SceneProgram and DirectorPlan inputs must reject:

```text
script
eval
imports
shaderSource
function
externalProcess
filesystem
networkFetch
nativeCommand
```

### 16.2 File Access

No arbitrary file access in MVP.

Media import must require explicit user approval or a controlled picker bridge.

### 16.3 Network Access

The MCP server must not fetch network URLs for media or scripts unless a later
explicitly approved media import plan defines validation rules.

### 16.4 Export

Export must be disabled until the connector has:

- capability gates,
- confirmation,
- audit log,
- cancellation,
- progress reporting.

## 17. Determinism Requirements

MCP-authored scenes must be deterministic.

Forbidden in render paths:

- wall-clock time,
- unseeded randomness,
- hidden playback state,
- network fetches,
- nondeterministic asset resolution.

Required:

- `FrameContext`,
- stable composition specs,
- stable asset ids,
- explicit durations,
- deterministic preview/evaluation reports.

## 18. Acceptance Suite

The plan is complete only when all are true:

### 18.1 MCP Discovery

- client can list tools.
- client can list resources.
- client can list prompts.

### 18.2 Read-Only Control

- client can read active project.
- client can read timeline summary.
- client can read selection.
- client can capture preview frame.

### 18.3 Scene Authoring

- client can validate valid SceneProgram.
- invalid SceneProgram returns structured error.
- unsafe SceneProgram is rejected.
- dry-run apply returns patch preview.
- commit apply mutates project revision.
- undo restores previous revision.

### 18.4 Motion Editing

- client can set transform.
- client can add keyframe.
- client can apply motion patch.
- stale revision fails safely.

### 18.5 Preview

- preview frame is returned as resource URI.
- evaluated frame truth includes bounds and transforms.
- visual diagnostics are readable by agent.

### 18.6 Safety

- missing capability denies mutation.
- delete requires confirmation.
- filesystem write unavailable.
- direct Stage5 path untouched.
- no Live Scrub protected files touched.

### 18.7 Real-Agent Proof

At least one MCP host can complete:

```text
connect
read project
create scene or layer
preview
repair
commit
undo
```

without manual script copy and without UI automation.

## 19. Stop List

Do not:

- build a separate timeline engine,
- build a separate render engine,
- bypass existing SceneProgram validation,
- call native transport directly from MCP,
- mutate widget state directly,
- expose arbitrary filesystem access,
- expose raw code execution,
- make MCP depend on screenshot-only state,
- skip dry-run for mutating commands,
- skip `expectedRevision`,
- implement all tools before the MVP is proven,
- hide errors as generic "could not apply" messages.

## 20. Implementation Order For The Writer Agent

The writer agent must execute in this order:

```text
PMC-00
PMC-01
PMC-02
PMC-03
PMC-04
PMC-05
PMC-09
PMC-10
PMC-11
PMC-13 MVP proof
PMC-06
PMC-07
PMC-08
PMC-12
PMC-14
PMC-15
```

Reason:

- command and transaction safety must exist before writes,
- read-only resources must exist before agents can reason,
- SceneProgram tools are the highest-value first write path,
- local server and app bridge must be proven before more tools,
- hardening comes after the MVP can run end to end.

## 21. Checkpoint Rules

Each phase must be a focused checkpoint:

```text
implement phase
-> run smallest relevant verification
-> commit only related files
-> push branch
-> report rollback command
```

Documentation-only phases do not require build. Dart/domain phases require
targeted tests. App bridge phases require local bridge verification. Android
install is required only when runtime app behavior changes and a device is
available.

## 22. Final Definition Of Done

The MCP connector is complete when:

- agents connect through MCP,
- agents read project and timeline state,
- agents create or modify a scene without copy/paste,
- all writes are transactional,
- all writes are undoable,
- preview frames are accessible as resources,
- SceneProgram and DirectorPlan flows are supported,
- keyframes and transforms are supported,
- unsafe code is rejected,
- Live Scrub and Stage5 ownership remain intact,
- a real MCP host completes the full workflow.

At that point ReFusionXx becomes agent-native: the AI can act as a motion
director inside the app through safe tools, while ReFusion remains the source of
truth for rendering, playback, timeline, and export.

## 23. Official References

- Remotion Composition: https://www.remotion.dev/docs/composition
- Remotion Sequence: https://www.remotion.dev/docs/sequence
- Remotion Player: https://www.remotion.dev/docs/player/player
- Remotion renderMedia: https://www.remotion.dev/docs/renderer/render-media
- Remotion Agent Skills: https://www.remotion.dev/docs/ai/skills
- MCP introduction: https://modelcontextprotocol.io/docs/getting-started/intro
- MCP architecture: https://modelcontextprotocol.io/docs/concepts/architecture
- MCP tools: https://modelcontextprotocol.io/docs/concepts/tools
- OpenAI Apps SDK: https://developers.openai.com/apps-sdk/
