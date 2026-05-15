# Professional Local-First Project Workspace Migration Closure Plan

Status: official execution plan, execution in progress
Short name: `PLFPW-MCP`  
Date: 2026-05-16  
Package: `com.refusion.app`  
Branch context: `codex/unified-keyframe-ops-foundation-20260426`

---

## Current Execution State - 2026-05-16

This section is the canonical continuation point for the current build. It
records what has already been closed and what must happen next. Any agent
continuing this plan must start here before reading later phases.

### Closed Checkpoints

The following checkpoints are already completed and pushed:

```text
022ba96e checkpoint: add plfpw-00 current truth audit
33393de9 checkpoint: fail closed mcp composition identity placeholders
8f422de6 checkpoint: harden json-rpc session identity fail-closed
fe1b5854 checkpoint: harden cloud bridge identity placeholders
b2f97087 checkpoint: finalize workspace identity runtime adoption core
0b952848 checkpoint: enforce workspace identity gate for active mcp context
0e4884e6 checkpoint: add scene context virtual project resources
8446c992 checkpoint: prefer scene context over legacy layers sync
9f73db64 checkpoint: enforce canonical transaction envelope at json-rpc boundary
16a45950 checkpoint: normalize canonical transactions in agent control plane
e8d612ab checkpoint: enforce mutating transaction scope on active workspace
8db64bba checkpoint: require target hints for mutating transactions
d01bc020 checkpoint: enforce target hints at json-rpc boundary
995f2739 checkpoint: update plan hash for json-rpc target gate
52781d75 checkpoint: normalize local mcp target resolution before apply
```

### What Is Closed

These items are now closed for the current migration slice:

```text
PLFPW-00 audit document exists.
MCP composition spec no longer reports placeholder identities as active truth.
JSON-RPC session/open rejects placeholder project/composition identities.
JSON-RPC tools/call does not silently create fake active sessions.
Cloud bridge treats active/comp_1/active-composition as invalid local identity.
Cloud bridge placeholder local context bootstraps from real remote context only.
Focused MCP and cloud bridge tests pass for the identity hardening slice.
ProjectWorkspaceV1 model is now wired into create/open/bootstrap runtime paths.
MCP cloud context now publishes active composition only when runtime workspace identity is valid.
Cloud bridge now requires valid workspace identity to publish active MCP context.
Toolkit active context now fails closed on placeholders and reports workspace identity when valid.
Scene context snapshot tools are now wired (`get_scene_context`, `list_project_resources`, `get_project_resource`).
Virtual project resources now expose read-only context payloads for agent awareness.
Proof resource payload is explicitly read-only and cannot be interpreted as app-apply proof.
Cloud bridge fast-sync now reads layer truth from `get_scene_context` first, with `get_layers` as compatibility fallback only.
JSON-RPC `tools/call` now validates canonical transaction envelopes (`schemaVersion/baseRevision/idempotencyKey/projectId/compositionId/operations`) when provided.
Malformed canonical transactions now fail early at JSON-RPC boundary instead of reaching runtime handlers.
Agent control plane now normalizes canonical transaction fields into runtime command envelopes (expectedRevision/idempotency/project scope/payload) before command execution.
Mutating MCP tools now synthesize canonical transactions when missing and fail closed unless session identity is real (non-placeholder) and transaction scope matches active workspace project/composition.
Canonical mutating transactions now fail validation when update/effect/motion/delete intents are submitted without resolvable target hints.
JSON-RPC `tools/call` now enforces the same target-hint contract for canonical update/effect/motion/delete transactions before dispatching to runtime handlers.
LocalMcpTransactionApi now normalizes update/effect/motion targets via alias resolution before apply and fails closed on missing/ambiguous targets (`TARGET_NOT_FOUND` / `AMBIGUOUS_TARGET` / `UNSAFE_FALLBACK_BLOCKED`).
```

### What Is Not Yet Closed

These are still open and must not be claimed complete:

```text
ProjectWorkspaceV1 is not yet the only create-composition source of truth.
SceneContextSnapshotV1 resources are not yet complete.
SceneContextSnapshotV1 resources exist, but transaction-led revision/diff semantics are not yet finalized.
CanonicalCreativeTransactionV1 is not yet the only write surface.
Manual UI, MCP, Script, Template, and Import are not yet fully cut over.
Supabase is not yet fully converted to relay/mirror/history.
RendererProofV1 is not yet the only appApplied success gate.
Legacy remote layer handlers still exist and must be converted or blocked.
File-backed Live Runtime is not yet implemented; it is a future layer.
```

### Current Verification Baseline

The latest closed slice was verified with:

```text
flutter test test/mcp
flutter test test/presentation_services/refusion_mcp_cloud_bridge_fast_apply_test.dart
flutter test test/local_mcp_transaction_api_test.dart
flutter test test/presentation_services/professional_scene_apply_proof_evaluator_test.dart
flutter test test/presentation_services/mcp_text_layer_resolution_test.dart
dart analyze on the modified files
```

The build was installed on:

```text
Device: ELN2-W29
IP/port at latest install: 192.168.0.199:39407
Package: com.refusion.app
Version: 1.0.0-beta.11
Latest observed install time: 2026-05-16 00:46:37
```

### Immediate Next Slice

The next implementation slice is:

```text
PLFPW-04 - Universal Target Resolver
```

`PLFPW-03B` is now closed: canonical transaction rules moved from JSON-RPC-only
validation into live mutation path normalization in the agent control plane.
Mutating calls now fail closed on placeholder identity and transaction scope
mismatch before command execution.

No new feature work should start before `PLFPW-04` pre-build gate closes.

---

## 0. Executive Decision

ReFusionXx must move from cloud-row-driven MCP editing to a local-first project
workspace where the open app is the only live apply authority.

This is not an additive feature plan. It is a migration and closure plan.

The final system must be:

```text
One project truth
One transaction path
One apply engine
One canvas/timeline renderer
One proof system
Zero active legacy execution paths
```

The old behavior is formally deprecated:

```text
MCP writes Supabase row
-> revision increases
-> get_layers sees row
-> agent claims success
-> app may apply later or not at all
```

The new behavior is mandatory:

```text
Manual UI / MCP Agent / Script / Template / Import
-> Scene Context Snapshot read
-> Canonical Creative Transaction submit
-> Local app applies immediately through Unified Apply Engine
-> Creative Graph + Timeline + Frame Evaluator + Canvas update from one truth
-> RendererProofV1 + appApplied ack
-> Cloud mirror/history updates after local proof
```

Cloud is not the live editor. Cloud is relay, mirror, asset storage, transaction
history, and recovery.

The open app is the live editor.

### 0.1 Future Destination: File-Backed Live Runtime

After the local-first transaction spine is closed, ReFusionXx must evolve into a
file-backed live project runtime comparable to how Remotion/HyperFrames work
with Codex or Claude.

This future layer is not a replacement for the current migration. It depends on
the current migration being correct.

The final destination is:

```text
Agent reads/edits official project files
-> app watches project file changes
-> compiler validates and lowers files into canonical graph/timeline
-> local apply engine updates canvas/player immediately
-> export uses the same files and graph
-> renderer proof confirms the visual result
```

Target project shape:

```text
MyProject.refusion/
  manifest.json
  composition.json
  scene_context.md
  layers/
  motion/
  effects/
  timeline/
  transactions/
  proof/
```

The agent must not write arbitrary runtime state. It may write official
transaction patches and, later, schema-validated project files. The app remains
the authority for validation, locking, compilation, hot reload, renderer proof,
and corruption prevention.

The current plan must finish first because:

```text
fileChanged without local apply is still failure
graphCompiled without timeline/canvas projection is still failure
cloud row success without renderer proof is still failure
```

The file-backed runtime must be implemented later as:

```text
PLFPW-FB-00 - File-Backed Live Runtime Migration
```

It must inherit all hard rules from this plan:

```text
one identity model
one transaction path
one compiler/lowering path
one graph/timeline/frame evaluator
one preview/export renderer path
one renderer proof system
zero active legacy execution paths
```

---

## 1. Plans This Migration Supersedes And Connects

This plan does not replace the product direction of the existing plans. It
closes them into one executable migration:

```text
professional_in_app_virtual_project_workspace_single_creative_truth_plan.md
professional_canvas_truth_engine_upgrade_plan.md
professional_unified_runtime_apply_spine_closure_plan.md
professional_mcp_scene_truth_runtime_plan.md
professional_mcp_realtime_single_truth_failure_closure_plan.md
PNCLE-05C.UNIVERSAL-LAYER-UPDATE-IDENTITY-HARDENING.md
```

The key inherited rules are:

```text
No local same-device edit may wait for Supabase polling before applying.
No MCP write is successful until the open app proves local render application.
No command may mutate canvas/timeline/layers outside canonical transactions.
No unresolved update may silently become insert.
No metadata-only success.
No Cloud-only project truth.
```

---

## 2. Reference-System Decision

### 2.1 Remotion Lesson

Remotion succeeds because the composition is explicit and deterministic:

```text
Composition(width, height, fps, duration)
-> current frame
-> visual values are functions of frame
-> preview and export evaluate the same composition truth
```

ReFusion translation:

```text
CompositionProfile(width, height, fps, durationMs, origin)
-> MasterFrameEvaluator(timeMs/frame)
-> evaluated node properties
-> same visual program for preview/playback/export/proof
```

### 2.2 HyperFrames Lesson

HyperFrames succeeds for AI authoring because the agent reads an inspectable
composition surface and uses deterministic adapters/registries.

ReFusion translation:

```text
Agent reads virtual project resources:
  composition.json
  scene_context.md
  layers.json
  timeline.json
  keyframes.json
  effects.json
  proof_ledger.json

Agent writes only:
  CanonicalCreativeTransaction
```

### 2.3 OpenCut Lesson

OpenCut is the strongest reference for command/update identity. ReFusion must
separate:

```text
insert new element
update existing element
apply keyframes to target
apply effect to target
```

No command may blur insert/update semantics.

### 2.4 Fluvie Lesson

Fluvie is the closest Flutter-native reference. ReFusion must have composition
metadata, frame visibility, layer stack, z-index, and frame evaluation available
inside the rendering tree.

### 2.5 Final Reference Decision

Do not embed Remotion, HyperFrames, OpenCut, or Fluvie as a second runtime.

Adopt the architecture pattern:

```text
inspectable project context
stable identities
transaction writes
deterministic frame evaluation
local renderer proof
```

---

## 3. Mandatory Old Path Elimination Mandate

Every implementation phase must include a `LegacyPathCleanupRecord`.

The record must list every old path touched by the phase and classify it as:

```text
deleteNow
disableBehindFlag
convertToAdapter
blockWithError
leaveTemporarilyWithExitDate
```

No phase may close with:

```text
legacy write path still active
cloud row as success proof
metadata-only success
polling as primary local apply
duplicate target resolver
MCP-only mutation shortcut
manual UI direct mutation bypassing transaction engine
selected-clip fallback for unresolved target
```

### 3.1 Legacy Paths To Inventory And Close

The first implementation slice must produce an inventory for these paths:

```text
MCP insert_layer -> refusion_layers row -> get_layers success
MCP get_layers verification without appApplied proof
Cloud revision as success proof
refusion_mcp_cloud_bridge polling as primary apply path
_handleMcpCloudSnapshot remote payload apply as main execution
_applyRemoteSolidLayerIfNeeded as primary execution
_applyRemoteTextLayerIfNeeded as primary execution
_applyRemoteShapeLikeLayerIfNeeded as primary execution
_applyRemoteMotionChannel with selected/single-clip fallback
metadata background/latestSolidColor visual shortcut
legacy animation payload stored on layer without lowering
manual UI direct insert/update helpers that bypass transactions
script/template/import direct MotionProject mutation
preview-only state that does not update canonical graph/timeline
proof evaluator fields derived from dataApplied only
Supabase command status appApplied without renderer proof
```

### 3.2 Legacy Closure Metrics

These metrics must be tracked and reach the final values before closure:

```text
legacy_mutation_callsite_count = 0
cloud_bypass_count = 0
cloud_appApplied_without_proof = 0
metadata_only_success_count = 0
unresolved_update_insert_count = 0
selected_clip_fallback_for_targeted_command_count = 0
polling_primary_apply_count = 0
```

If any metric is non-zero, the migration is not complete.

---

## 4. Target Architecture

### 4.1 Live Local Truth

The app owns:

```text
ProjectWorkspace
CompositionProfile
CanonicalCreativeGraph
MasterTimelineGraph
MotionChannelGraph
EffectStackGraph
SelectionState
UndoRedoLedger
FrameEvaluator
PreviewRenderer
ExportRenderer
RendererProofLedger
```

### 4.2 Virtual Project Resources

The agent reads structured resources generated from app-owned state:

```text
refusion://project/current/manifest.json
refusion://project/current/composition.json
refusion://project/current/scene_context.md
refusion://project/current/scene_context.json
refusion://project/current/layers.json
refusion://project/current/timeline.json
refusion://project/current/keyframes.json
refusion://project/current/effects.json
refusion://project/current/assets.json
refusion://project/current/selection.json
refusion://project/current/frame_snapshot.json
refusion://project/current/proof_ledger.json
refusion://project/current/capabilities.json
```

These resources behave like project files for the agent, but they are generated
read-only snapshots. They are not the write surface.

### 4.3 Write Surface

The only write surface is:

```text
refusion.apply_transaction(CanonicalCreativeTransaction)
```

Legacy tool names may exist only as adapters:

```text
refusion.insert_layer
refusion.update_layer
refusion.apply_motion_patch
refusion.apply_effect
```

They must lower to `CanonicalCreativeTransaction` before any local mutation.

### 4.4 Local-First Apply

Local app apply is first:

```text
receive transaction
-> validate schema/baseRevision/idempotency
-> resolve target
-> validate capability
-> canonicalize coordinate input
-> lower motion/effects/properties
-> apply to graph
-> project timeline
-> evaluate frame
-> render preview
-> produce RendererProofV1
-> ack appApplied
-> mirror transaction/snapshot/proof to cloud
```

### 4.5 Cloud Role

Supabase remains valuable, but only as:

```text
transaction relay
realtime notification
asset storage
project snapshot mirror
history ledger
multi-device recovery
agent context distribution
```

Supabase must not be the primary same-device apply engine.

---

## 5. Required Contracts

### 5.1 ProjectWorkspaceV1

```json
{
  "schemaVersion": "ProjectWorkspaceV1",
  "projectId": "uuid",
  "compositionId": "uuid",
  "workspaceId": "uuid",
  "createdAt": "iso8601",
  "updatedAt": "iso8601",
  "activeRevision": 12,
  "compositionProfile": {
    "width": 1080,
    "height": 1920,
    "fps": 30,
    "durationMs": 10000,
    "coordinateSystem": "centerOrigin",
    "canvasBounds": {
      "left": -540,
      "top": -960,
      "right": 540,
      "bottom": 960
    }
  }
}
```

### 5.2 SceneContextSnapshotV1

Generated by the app after every successful local apply:

```json
{
  "schemaVersion": "SceneContextSnapshotV1",
  "snapshotId": "uuid",
  "projectId": "uuid",
  "compositionId": "uuid",
  "revision": 12,
  "generatedAt": "iso8601",
  "playheadMs": 0,
  "compositionProfile": {},
  "layers": [],
  "timelineClips": [],
  "motionChannels": [],
  "effectInstances": [],
  "selection": {},
  "recentTransactions": [],
  "capabilities": {},
  "agentSafeSummary": "Story 1080x1920 composition with 2 layers..."
}
```

### 5.3 CanonicalCreativeTransactionV1

Every write, from any source, must become this envelope:

```json
{
  "schemaVersion": "CanonicalCreativeTransactionV1",
  "transactionId": "uuid",
  "idempotencyKey": "string",
  "baseRevision": 12,
  "projectId": "uuid",
  "compositionId": "uuid",
  "authorSurface": "manualUI|mcp|script|template|import",
  "sourceTool": "refusion.insert_layer",
  "intent": "insert|update|delete|animate|effect|batch",
  "target": {
    "targetMode": "explicit|selected|semantic|createdByTransaction",
    "layerId": "optional",
    "elementId": "optional",
    "timelineClipId": "optional",
    "remoteAliases": []
  },
  "coordinateBasis": {
    "space": "canvasCanonical|normalizedCanvas|anchorZone",
    "origin": "centerOrigin",
    "snapshotId": "uuid",
    "revision": 12
  },
  "operations": [],
  "expectedProof": {
    "requiresCanvasVisible": true,
    "requiresTimelineVisible": true,
    "requiresRendererBounds": true
  }
}
```

Hard requirements:

```text
schemaVersion required
transactionId required
idempotencyKey required
baseRevision required
projectId required
compositionId required
authorSurface required
intent required
coordinateBasis required for spatial operations
```

### 5.4 UniversalTargetResolverV1

Target resolution must be shared by MCP, Manual UI, Script, Template, and Import.

Resolution order:

```text
1. elementId
2. layerId
3. timelineClipId with verified element binding
4. remoteAliases
5. selectedLayerIds only when command explicitly allows selected target
6. semantic query with single unambiguous candidate
7. fail closed
```

Blocked:

```text
update command -> unresolved target -> insert new layer
motion command -> unresolved target -> selected clip fallback
effect command -> unresolved target -> single visible clip fallback
```

Required errors:

```text
TARGET_NOT_FOUND
AMBIGUOUS_TARGET
TARGET_KIND_MISMATCH
STALE_SPATIAL_SNAPSHOT
INSERT_USED_FOR_UPDATE
CAPABILITY_NOT_SUPPORTED
```

### 5.5 UniversalPropertyResolverV1

Aliases from any source must map to canonical property ids:

```text
x -> transform.position.x
y -> transform.position.y
positionX -> transform.position.x
positionY -> transform.position.y
scale -> transform.scale.uniform
scaleX -> transform.scale.x
scaleY -> transform.scale.y
rotation -> transform.rotation.degrees
opacity -> visual.opacity
blur -> visual.blur.amount
gaussianBlur -> visual.blur.amount
motionBlur -> effect.motionBlur.amount
color -> style.fill.color
fontSize -> text.font.size
```

No property may be accepted unless:

```text
resolver maps it
capability registry permits it for target kind
lowering can express it
preview renderer can evaluate it or marks it as prerender-only
proof can report its status
```

### 5.6 CanvasCoordinateContractV1

Raw `x/y` without coordinate space is forbidden for MCP/Script/Template writes.

Allowed coordinate inputs:

```text
canvasCanonical center-origin pixels
normalizedCanvas 0..1
anchorZone enum
safeArea enum
relative delta with explicit target basis
```

Examples:

```json
{
  "space": "anchorZone",
  "anchor": "center",
  "padding": 0,
  "fit": "preserve-size"
}
```

```json
{
  "space": "canvasCanonical",
  "origin": "centerOrigin",
  "x": 0,
  "y": 0
}
```

Blocked:

```json
{ "x": 0, "y": 0 }
```

unless the envelope declares exact coordinate basis and snapshot revision.

### 5.7 CapabilityRegistryV1

Every layer kind must declare:

```text
supports insert
supports update
supports transform
supports motion channel
supports effect stack
supports preview render
supports export render
supports proof
fallback mode
```

For each capability:

```text
targetKinds
propertyIds
rendererSupport
exportSupport
proofSupport
performanceBudget
featureFlag
testCoverage
```

If capability is not registry-approved, command fails before mutation.

### 5.8 RendererProofV1

No success without local renderer proof.

Required fields:

```json
{
  "schemaVersion": "RendererProofV1",
  "transactionId": "uuid",
  "projectId": "uuid",
  "compositionId": "uuid",
  "revisionApplied": 13,
  "frameId": "compositionId:frameNumber",
  "graphApplied": true,
  "timelineProjected": true,
  "frameEvaluated": true,
  "visualProgramEmitted": true,
  "canvasRendered": true,
  "targetProofs": [
    {
      "layerId": "id",
      "elementId": "id",
      "timelineClipId": "id",
      "evaluatedBounds": {},
      "renderedBounds": {},
      "visibleAreaRatio": 1.0,
      "visualHash": "optional",
      "capabilityProof": {}
    }
  ],
  "appApplied": true
}
```

Blocked:

```text
appApplied=true from DB write
appApplied=true from revision update
appApplied=true from get_layers
appApplied=true from self-asserted booleans without measured target proof
```

### 5.9 UndoRedoTransactionLedgerV1

Manual UI and MCP must share undo/redo semantics.

Required:

```text
transaction group id
inverse patch
affected target ids
author surface
timestamp
baseRevision
resultRevision
proof id
```

Acceptance:

```text
Manual insert -> MCP update -> undo -> redo
MCP insert -> Manual move -> MCP animate -> undo sequence remains coherent
```

---

## 6. Implementation Phases

Each phase must follow this closure template:

```text
Pre-Build Report
Implementation
LegacyPathCleanupRecord
Smallest relevant tests
Device validation if phase affects app/MCP/apply/canvas
Focused checkpoint commit
Push
Rollback command
```

No phase may close with unverified claims.

---

## PLFPW-00 - Pre-Build Gate And Current Truth Audit

### Goal

Freeze the current failure surface before changing behavior.

### Build

Create an audit report:

```text
docs/prebuild_reports/plfpw_00_current_truth_audit.md
```

The report must include:

```text
current branch and commit
connected device id/model/package/version
active MCP endpoint
current Supabase function deploy status
current write paths
current app apply paths
current proof paths
current cloud-only success cases
current manual UI direct mutation paths
current MCP insert/update/motion paths
```

### Legacy cleanup requirement

No code deletion yet, but every legacy path must be assigned an owner and future
closure phase.

### Tests

```text
rg inventory for legacy paths
flutter test existing MCP transaction/proof tests
adb screenshot of current app baseline
```

### Exit gate

```text
Complete legacy inventory exists.
No unknown live write path remains unclassified.
```

### Execution status

```text
Closed by checkpoint 022ba96e.
```

---

## PLFPW-01 - Real Project Workspace Identity On Create Composition

### Goal

`Create Composition` must create a real project/composition/workspace identity,
not a loose in-memory or default state.

### Build

Add or wire:

```text
ProjectWorkspaceV1 model
CompositionProfileV1 model
WorkspaceRevisionState
WorkspaceSessionState
```

On every new composition:

```text
new projectId
new compositionId
new workspaceId
new revision = 0
compositionProfile from selected preset
empty canonical graph
empty timeline graph
empty proof ledger
fresh selection state
```

### Legacy cleanup requirement

Disable production use of:

```text
default project ids
active project fallback ids
motion-project
scene-main
comp_1
global singleton project identity for new compositions
```

They may remain only in tests with explicit fixture names.

### Tests

```text
Create Story -> project/composition ids unique
Create Square -> ids unique and profile square
Create Story then Square -> no layer leakage
Open recent project -> restores matching ids
```

### Device validation

On connected Android device:

```text
Create Story composition.
Capture app diagnostic context.
Verify projectId/compositionId/profile are real and Story 1080x1920.
Create second composition.
Verify it starts clean.
```

### Exit gate

No MCP or cloud call may report active composition unless a real workspace exists.

### Execution status

Partially closed by:

```text
33393de9 MCP composition tools fail closed on placeholder identities.
8f422de6 JSON-RPC sessions/tools fail closed on placeholder identities.
fe1b5854 Cloud bridge fails closed on placeholder identities.
```

The create-composition runtime still needs full `ProjectWorkspaceV1` adoption.
That remaining work is split into `PLFPW-01B`.

---

## PLFPW-01B - ProjectWorkspace Identity Finalization And Runtime Adoption

### Goal

Finish the identity foundation started in `PLFPW-01` by making the open
composition a real runtime workspace, not only a validated MCP context.

After this slice, the app must not be able to enter editor mode with:

```text
projectId = active
compositionId = comp_1
workspaceId missing
compositionProfile missing
graph/timeline state detached from workspace identity
```

### Build

Wire `Create Composition` and project restore into one runtime identity object:

```text
ProjectWorkspaceV1
CompositionProfileV1
WorkspaceRevisionState
WorkspaceSessionState
CanonicalCreativeGraph root
MasterTimelineGraph root
RendererProofLedger root
```

The active editor state must expose one authoritative object:

```text
ActiveProjectWorkspace
```

Required fields:

```text
projectId
compositionId
workspaceId
revision
compositionProfile.width
compositionProfile.height
compositionProfile.fps
compositionProfile.durationMs
compositionProfile.coordinateSystem
compositionProfile.canvasBounds
createdAt
updatedAt
```

### Runtime Rules

```text
Create Story -> workspace profile must be 1080x1920.
Create Square -> workspace profile must be 1080x1080.
Create Landscape -> workspace profile must be 1920x1080.
MCP context must mirror active workspace identity only.
Manual UI must read active workspace identity only.
Canvas must size from active workspace compositionProfile only.
Timeline must project from active workspace graph only.
```

### LegacyPathCleanupRecord

This slice must classify and close these legacy patterns:

```text
active project fallback -> blockWithError
comp_1 composition fallback -> blockWithError
active-composition fallback -> blockWithError
motion-project identity fallback -> blockWithError
scene-main default as runtime root -> convertToAdapter only for tests/import
format/preset state detached from workspace -> convertToAdapter
canvas size inferred from payload -> blockWithError for MCP/Script/Template
```

### Tests

Add or harden tests for:

```text
Create Story creates real workspace ids and 1080x1920 profile.
Create Square creates different workspace ids and 1080x1080 profile.
Switching composition clears prior graph/timeline/proof state.
MCP get_composition_spec returns inactive when workspace missing.
MCP get_composition_spec returns real workspace ids when workspace exists.
Cloud bridge never reports placeholders as active composition.
Manual Add Solid reads workspace profile, not payload dimensions.
```

### Device Validation

On the connected Android device:

```text
Install build.
Create Story.
Open pairing/context diagnostics.
Verify active workspace ids are real.
Verify canvas profile is Story 1080x1920.
Add manual solid.
Verify solid is inside selected canvas frame.
Ask MCP to read context.
Verify MCP reports the same projectId/compositionId/profile.
```

### Exit Gate

This slice is not closed until:

```text
No live editor context can exist without ActiveProjectWorkspace.
No active MCP context can be published from placeholder ids.
No canvas size can be inferred from MCP layer payload.
Device validation confirms Story profile survives Manual and MCP context reads.
Focused checkpoint is committed and pushed.
```

---

## PLFPW-02 - Scene Context Snapshot Resources

### Goal

Give the agent a project-like read surface equivalent to Remotion/HyperFrames
project context, without letting it edit uncontrolled files.

### Build

Implement:

```text
SceneContextSnapshotV1Builder
VirtualProjectResourceRegistry
SceneContextMarkdownRenderer
SceneContextJsonRenderer
```

Expose:

```text
refusion.get_scene_context
refusion.get_project_resource
refusion.list_project_resources
```

Required resources:

```text
manifest.json
composition.json
scene_context.md
scene_context.json
layers.json
timeline.json
keyframes.json
effects.json
assets.json
selection.json
frame_snapshot.json
proof_ledger.json
capabilities.json
```

### Legacy cleanup requirement

`get_layers` must be downgraded to compatibility/read-only legacy view. It must
not be accepted as proof of app application.

### Tests

```text
snapshot includes composition dimensions
snapshot includes selected layer
snapshot includes layer bounds
snapshot includes timeline clip ids
snapshot includes motion channels
snapshot increments after transaction
```

### Device validation

```text
Create Story.
Add manual solid.
Read scene context through MCP/app diagnostic path.
Verify context reports same layer visible on canvas/timeline.
```

### Exit gate

Agent has enough information to know:

```text
canvas size
layer ids
bounds
timeline position
selection
recent transactions
capabilities
```

---

## PLFPW-03 - Canonical Creative Transaction Schema And Validator

### Goal

All writes must use one schema with revision, idempotency, target semantics, and
coordinate basis.

### Build

Implement or harden:

```text
CanonicalCreativeTransactionV1
CreativeTransactionValidator
CreativeTransactionNormalizer
CreativeTransactionDryRun
IdempotencyLedger
BaseRevisionConflictDetector
```

Validation must reject:

```text
missing schemaVersion
missing baseRevision
missing idempotencyKey
missing projectId/compositionId
spatial op without coordinateBasis
update intent without target
unsupported property/capability
stale snapshot revision
```

### Legacy cleanup requirement

All legacy MCP tools must lower to transaction before app mutation. If lowering
fails, they return structured error and do not write graph/timeline/canvas.

### Tests

```text
valid insert background transaction passes
valid update text transaction passes
raw x/y without coordinate space fails
stale baseRevision fails or rebases explicitly
duplicate idempotencyKey is idempotent
insert_layer with target update intent is blocked or normalized to update
```

### Exit gate

No write can reach local app mutation without `CanonicalCreativeTransactionV1`.

---

## PLFPW-04 - Universal Target Resolver

### Goal

Every operation targets the correct layer/element/clip or fails closed.

### Build

Implement:

```text
UniversalLayerTarget
UniversalTargetResolver
UniversalTargetResolutionResult
UniversalTargetAmbiguityReport
```

Resolver must cover:

```text
text
shape
solid/background
image
video
audio
adjustment/effect layer
motion channel target
effect target
```

### Legacy cleanup requirement

Delete or disable type-specific resolver branches that allow different semantics
for MCP text, shape, background, and motion.

Selected/single-clip fallback is forbidden for targeted MCP transactions.

### Tests

```text
update same text by remote alias
update shape by layerId
update background by semantic role
motion after update targets same elementId
ambiguous two text layers returns AMBIGUOUS_TARGET
missing target returns TARGET_NOT_FOUND
selected clip fallback is not used for unresolved MCP motion
```

### Device validation

```text
MCP insert text.
MCP update same text.
MCP apply motion to same text.
Verify text count unchanged and target id stable.
```

### Exit gate

No update/animate/effect command can create a new layer unless its intent is
explicitly `insert`.

---

## PLFPW-05 - Universal Property Resolver And Capability Registry

### Goal

Any property/effect/motion from any source must resolve to one canonical
capability before it mutates state.

### Build

Implement:

```text
UniversalPropertyResolver
CapabilityRegistryV1
CapabilityValidationResult
PropertyLoweringPlan
```

Required property families:

```text
transform.position.x/y
transform.scale.x/y/uniform
transform.rotation.degrees
visual.opacity
visual.blur.amount
effect.motionBlur.amount
style.fill.color
style.stroke.color/width
style.shadow.*
text.font.size/weight/family
video.color.*
audio.volume/fade/eq
```

### Legacy cleanup requirement

Remove scattered alias maps as authoritative sources. They may call the
UniversalPropertyResolver only.

No capability may be advertised in MCP skills unless registry says:

```text
canValidate
canLower
canPreview
canProof
```

### Tests

```text
scale aliases map to canonical ids
gaussian blur aliases map to visual.blur.amount
motion blur aliases map to effect.motionBlur.amount
unsupported effect fails before mutation
capability matrix blocks unsupported target kind
```

### Exit gate

Manual UI, MCP, Script, and Template all resolve properties through the same
resolver.

---

## PLFPW-06 - Local-First Transaction Apply API

### Goal

Make app-local apply the primary path for MCP and same-device edits.

### Build

Implement/wire:

```text
LocalFirstTransactionReceiver
LocalMcpTransactionApi
UnifiedCreativeApplyEngine live app adapter
TransactionApplyReceipt
TransactionApplyDiagnostics
```

Flow:

```text
MCP transaction received
-> app validates
-> app applies locally immediately
-> app updates graph/timeline/canvas
-> app sends proof
-> cloud mirror updates asynchronously
```

### Legacy cleanup requirement

`refusion_mcp_cloud_bridge` may remain only as relay/recovery. It cannot be the
primary same-device apply mechanism.

Polling can recover missed transactions. Polling cannot be required for normal
visible application.

### Tests

```text
local transaction insert background mutates workspace before cloud mirror
local transaction text update keeps layer count
cloud mirror failure does not prevent local visible apply
duplicate idempotencyKey does not double apply
```

### Device validation

```text
Create Story.
MCP add white background.
Expected visible <= 1s, target <= 300ms after app receives transaction.
Timeline clip appears immediately.
No waiting for get_layers polling.
```

### Exit gate

MCP live edit can succeed without waiting for a cloud row scan.

---

## PLFPW-07 - Supabase Relay/Mirror Conversion

### Goal

Downgrade Supabase from primary editor truth to relay/mirror/history.

### Build

Cloud tables/channels must represent:

```text
creative_transactions
transaction_receipts
workspace_snapshots
project_assets
active_editor_sessions
agent_sessions
realtime transaction broadcasts
```

Edge Function behavior:

```text
legacy insert_layer -> normalize transaction -> enqueue/broadcast transaction
apply_transaction -> enqueue/broadcast transaction
get_scene_context -> latest app-generated snapshot
get_layers -> compatibility view only
get_command_status -> app proof only
```

### Legacy cleanup requirement

Block success from:

```text
revision changed
row inserted
get_layers sees layer
```

These can only mean:

```text
cloudAccepted = true
```

not:

```text
appApplied = true
```

### Tests

```text
Edge insert_layer returns transaction id, not final app success
get_command_status pending until app proof
app proof updates status
Cloud layer mirror cannot claim renderer proof
```

### Device validation

```text
MCP add background.
Agent must not claim final success until app proof.
If app offline, command remains pending/relayAccepted.
When app foreground receives transaction, background appears and proof completes.
```

### Exit gate

Cloud-only success is impossible.

---

## PLFPW-08 - Canvas Coordinate And Spatial Truth Upgrade

### Goal

Make every spatial operation deterministic and visible inside the selected
composition canvas.

### Build

Wire:

```text
CompositionProfileV1
CanvasCoordinateMapper
AnchorZonePositioner
BoundsEvaluator
TextLayoutSnapshot
SpatialSceneSnapshotV1
```

Rules:

```text
MCP cannot send unqualified x/y.
Agent sees canvas bounds and element bounds.
Center means canvas center.
Top-left means composition top-left, not screen viewport.
Background canvas fill always equals composition bounds.
Content render is clipped to composition unless allowOverflow=true.
Editor handles may extend outside canvas; content may not.
```

### Legacy cleanup requirement

Delete or convert:

```text
screen viewport coordinate assumptions
payload x/y interpreted without basis
square fallback for Story background
background based on payload width/height instead of CompositionProfile
```

### Tests

```text
Story center maps to (0,0) center-origin
Story background fills 1080x1920
Square background fills square
Landscape background fills landscape
text center appears inside canvas center
shape topLeft with padding appears inside top-left safe bounds
stale spatial snapshot rejected
```

### Device validation

```text
Create Story.
MCP add background full canvas.
MCP add centered text.
MCP move text top-left via anchor.
Take screenshot and bounds diagnostic.
Verify content stays inside rounded canvas and timeline shows clips.
```

### Exit gate

No agent-created element appears outside composition due to coordinate ambiguity.

---

## PLFPW-09 - Motion And Effects Lowering Into Real Runtime Channels

### Goal

Motion/effects must not remain metadata. They must lower into runtime-evaluable
channels/effect instances.

### Build

Implement/wire:

```text
MotionRecipeLowerer
EffectInstanceLowerer
KeyframeChannelWriter
MotionChannelTargetBinder
EffectCapabilityProof
```

Required first recipes:

```text
popUp
scaleIn
fadeIn
slideIn
rotateIn
positionMove
```

Each recipe must produce real canonical channels:

```text
transform.scale.x/y
visual.opacity
transform.position.x/y
transform.rotation.degrees
```

### Legacy cleanup requirement

Block:

```text
payload.motion saved only in layer metadata
payload.animation saved only in layer metadata
animation row stored as solid layer
effect payload accepted without renderer/evaluator support
```

### Tests

```text
popUp creates scale and opacity channels
motion after text update targets same element
unknown recipe fails UNKNOWN_MOTION_RECIPE
blur effect lowers to effect instance/channel
motion reapply updates existing channel instead of duplicate
```

### Device validation

```text
MCP insert text center.
MCP apply popUp.
Play/scrub start range.
Verify text visibly scales/appears.
Verify timeline/keyframe state includes channels.
```

### Exit gate

No motion/effect command can claim success unless runtime channels/effect
instances exist and renderer proof acknowledges them.

---

## PLFPW-10 - RendererProofV1 And App ACK

### Goal

Make `appApplied=true` a visual renderer truth, not a data truth.

### Build

Implement:

```text
RendererProofV1
RendererProofCollector
TimelineProjectionProof
CanvasRenderedBoundsProof
VisualHashProof optional
AppApplyAckWriter
wait_for_apply command/status contract
```

Proof must include:

```text
graphApplied
timelineProjected
frameEvaluated
visualProgramEmitted
canvasRendered
targetProofs
renderedBounds
operationApplied
createdLayerCount
updatedLayerCount
```

### Legacy cleanup requirement

Remove proof logic that sets renderer fields from `dataApplied` alone.

### Tests

```text
proof fails if timeline clip missing
proof fails if rendered bounds missing
proof fails if target id mismatch
proof passes for real background fill
proof passes for text visible within canvas
```

### Device validation

```text
MCP add background.
MCP wait_for_apply returns appApplied=true only after visible.
MCP add text.
wait_for_apply proof includes rendered bounds inside canvas.
```

### Exit gate

Every successful MCP write has app renderer proof.

---

## PLFPW-11 - Manual UI / MCP / Script / Template Cutover

### Goal

All authoring surfaces must write through the same transaction engine.

### Build

Convert:

```text
Manual Add Solid
Manual Add Text
Manual Add Shape
Manual transform edit
Manual keyframe edit
MCP insert/update/animate/effect
Script import
Template apply
```

into:

```text
CanonicalCreativeTransaction
```

### Legacy cleanup requirement

Direct mutation helpers must either:

```text
be deleted
be private implementation inside UnifiedCreativeApplyEngine
be compatibility adapters that only emit transactions
```

They cannot be public execution paths.

### Tests

```text
manual Add Solid and MCP Add Solid produce same graph/timeline shape
manual text update and MCP text update use same resolver/proof
script template insert uses same transaction/proof
undo/redo spans mixed manual and MCP operations
```

### Device validation

```text
Manual add shape.
MCP reads scene context and updates same shape color/position.
Manual moves text.
MCP reads new bounds and applies animation to same text.
No duplicate layers.
```

### Exit gate

No authoring surface can mutate live graph/timeline/canvas outside transaction
apply.

---

## PLFPW-12 - Legacy Code Deletion And Compile-Time Guards

### Goal

Physically remove or block old execution paths after parity is proven.

### Build

Add compile/runtime guards:

```text
assertNoLegacyMutationPath
assertNoCloudOnlyAppApplied
assertNoUnresolvedTargetFallback
assertNoPollingPrimaryApply
```

Delete or hard-disable old code according to `LegacyPathCleanupRecord`.

### Required cleanup report

Create:

```text
docs/cleanup_reports/plfpw_12_legacy_path_elimination_report.md
```

Must list:

```text
deleted files/functions
converted adapters
blocked paths
remaining compatibility code
owner and exit date for any temporary compatibility code
metrics after cleanup
```

### Tests

```text
rg confirms forbidden legacy symbols are gone or adapter-only
unit/integration test suite green
cloud-only success test fails closed
polling disconnected still works only as recovery
```

### Device validation

Full smoke:

```text
Create Story.
MCP background visible.
MCP text center visible.
MCP update same text.
MCP popUp visible.
Manual move text.
MCP reads new position and moves it relative.
Create second composition.
Verify clean state and no leakage.
```

### Exit gate

Final metrics:

```text
legacy_mutation_callsite_count = 0
cloud_bypass_count = 0
cloud_appApplied_without_proof = 0
metadata_only_success_count = 0
unresolved_update_insert_count = 0
selected_clip_fallback_for_targeted_command_count = 0
polling_primary_apply_count = 0
```

---

## PLFPW-13 - Final Acceptance And Release Readiness

### Goal

Prove that ReFusion now behaves like a professional local-first creative editor.

### Acceptance Suite

Run on connected device:

```text
1. Create Story composition.
2. MCP reads scene_context and reports 1080x1920.
3. MCP adds white background.
   Expected: visible on canvas and timeline <= 1s.
4. MCP adds centered text "TEXT MOTION TEST".
   Expected: centered inside canvas, text clip visible.
5. MCP updates same text to larger bold title.
   Expected: no duplicate text layer.
6. MCP applies popUp.
   Expected: motion visible during playback/scrub.
7. Manual UI moves text.
   Expected: scene_context shows updated bounds.
8. MCP moves same text to top-left anchor.
   Expected: same layer moves, no duplicate.
9. MCP inserts shape.
   Expected: shape appears in canvas/timeline.
10. MCP updates same shape.
    Expected: same element id, no duplicate.
11. MCP applies effect supported by registry.
    Expected: visible or explicit progressive proof.
12. Create second composition.
    Expected: clean project, no previous layers.
13. Return to first project from recent.
    Expected: previous state restored by project identity.
```

### Performance budgets

```text
scene_context read p95 <= 250 ms from app-local snapshot
local transaction validation p95 <= 50 ms
background/text/shape local apply p95 <= 300 ms
MCP transaction visible p95 <= 1000 ms
renderer proof p95 <= 500 ms for simple layers
polling recovery <= 8 s only when realtime disconnected
```

### Required artifacts

```text
.tmp_diagnostics/plfpw/final/<commit>/screenshots
.tmp_diagnostics/plfpw/final/<commit>/logcat.txt
.tmp_diagnostics/plfpw/final/<commit>/scene_context.json
.tmp_diagnostics/plfpw/final/<commit>/proof_ledger.json
.tmp_diagnostics/plfpw/final/<commit>/acceptance_report.md
```

### Exit gate

The migration is closed only when:

```text
all acceptance steps pass
all cleanup metrics are final zero values
all tests pass
Edge Function deployed
app installed on official connected device
rollback commands documented
old path cleanup report exists
```

---

## 7. Device Validation Protocol

For every phase that touches MCP/apply/canvas/timeline/proof:

```text
1. Build/install on connected Android device.
2. Launch package com.refusion.app.
3. Create or open target composition.
4. Run phase-specific MCP/manual scenario.
5. Capture screenshot.
6. Capture logcat around transaction.
7. Capture scene_context/proof if available.
8. Record pass/fail in phase report.
```

Device failures must not be waved away as "probably old install".

If a failure appears:

```text
stop
write failure report
identify whether issue is schema/transport/apply/render/proof
fix smallest root cause
add regression test
rerun device scenario
```

---

## 8. Edge Function Deployment Rule

Any phase that changes:

```text
supabase/functions/mcp/index.ts
```

is not complete until:

```text
supabase functions deploy mcp --project-ref wygydvczsgnocihbihje
```

has succeeded against the intended Supabase project.

If `SUPABASE_ACCESS_TOKEN` is unavailable, the phase must be marked:

```text
code checkpointed
not live in ChatGPT MCP
blocked on Edge Function deployment
```

App install alone cannot validate server-side MCP behavior.

---

## 9. Stop List

Do not:

```text
add a second MCP-only engine
let the agent edit cloud graph snapshots directly
let Supabase row insertion mean app success
let get_layers mean timeline/canvas proof
let revision increase mean render proof
let update fallback to insert
let motion fallback to selected clip when target unresolved
let raw x/y pass without coordinate basis
let background payload dimensions override CompositionProfile
let effects/motion remain metadata
let Manual UI bypass transaction engine
leave old path active after new path works
touch protected Live Scrub paths without explicit approval
```

---

## 10. Required Agent Writer Workflow

The agent implementing this plan must do this before each phase:

```text
1. Read this plan section.
2. Read relevant existing plan/docs.
3. Run git status -sb.
4. State current commit.
5. Write Pre-Build Report.
6. Identify old code to delete/disable/convert.
7. State exact tests and device scenario.
8. Implement the smallest slice.
9. Run tests.
10. Run device validation if required.
11. Write cleanup/proof notes.
12. Commit focused files only.
13. Push.
14. Report rollback command.
```

No blind coding. No phase closes without evidence.

---

## 11. Final Definition Of Done

This plan is done only when the following statement is true:

```text
For the open composition on the connected device, any write from Manual UI,
MCP, Script, Template, or Import is represented as one canonical transaction,
applied locally by one engine, visible on one canvas/timeline truth, evaluated by
one frame evaluator, proven by one renderer proof system, mirrored to cloud only
after local apply, and no old execution path can claim success independently.
```

If that statement is false, the migration is not done.
