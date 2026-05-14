# Professional In-App Virtual Project Workspace And Single Creative Truth Plan

Short name: `PIVWSCT`

Status: official replacement architecture plan

Package: `com.refusion.app`

Date: 2026-05-15

Primary goal: make every creative operation from Manual UI, MCP Agent, Script,
Template, Import, and future automation pass through one in-app virtual project
workspace, one stable identity system, one transaction apply engine, one graph,
one timeline projection, one frame evaluator, one preview/export renderer truth,
and one renderer-backed proof/ack path.

This plan exists to solve the current class of failures where the agent or UI can
create, update, animate, or style something without the open composition showing
the same truth immediately and without the next actor understanding the current
scene context.

---

## 0. Mandatory Old Path Elimination Mandate

This plan is not an additive MCP patch.

This plan is the replacement path.

Before any implementation slice is considered complete, the writer agent must
prove that the slice either removes, blocks, or wraps every old path it touches.
No old path may remain capable of mutating canvas, timeline, layer state,
keyframes, effects, media state, selection state, or render metadata outside the
new single creative truth path.

The final accepted architecture must satisfy this rule:

```text
Manual UI / MCP / Script / Template / Import
-> Intent
-> Canonical Creative Transaction
-> Unified Apply Engine
-> In-App Virtual Project Workspace
-> Creative Graph
-> Timeline Projection
-> Frame Evaluator
-> Preview Renderer
-> Export Renderer
-> Renderer Proof/Ack
```

Anything else is legacy.

### 0.1 Absolute Prohibitions

The following patterns are forbidden after the related slice lands:

```text
UI setState directly changes creative truth.
MCP remote payload directly inserts layers.
Script import directly mutates MotionProject without transaction proof.
Template apply bypasses identity resolution.
Canvas state differs from timeline state.
Timeline state differs from graph state.
Preview renderer reads a different truth from export renderer.
Success ack comes from DB write only.
Success ack comes from metadata write only.
Insert is used when the user intent is update.
Selected layer fallback is used when the target identity is ambiguous.
Composition size is guessed by an agent after a composition is already open.
Effects are stored as payload metadata without evaluated renderer conformance.
Animations are stored as loose payloads without seekable property channels.
```

### 0.2 Required Legacy Decision For Every Touched Path

Every legacy path touched by implementation must receive one explicit decision:

```text
canonicalize: move this path to emit canonical transactions only.
adapterOnly: keep only as a thin adapter that cannot mutate state directly.
featureFlag: temporarily gate old behavior while replacing it.
migrate: move persisted data into the new model.
delete: remove old code after equivalent coverage exists.
block: fail closed if the old path is invoked.
```

A slice cannot close unless it updates a `LegacyPathCleanupRecord` or equivalent
coverage record for every old write path it touches.

### 0.3 No Parallel Truth Exception

A temporary adapter is allowed only if it has no independent creative authority.

Allowed:

```text
Legacy MCP payload -> Legacy adapter -> Canonical Creative Transaction
```

Forbidden:

```text
Legacy MCP payload -> old apply code -> canvas/timeline mutation
Canonical transaction -> new apply code -> canvas/timeline mutation
```

The second pattern creates split-brain truth and must be blocked.

---

## 1. Executive Decision

ReFusionXx is a mobile-first native creative editor. It should not rely on a
physical project folder that an agent edits directly, because the primary runtime
is an app, not a desktop web project.

Instead, ReFusionXx must implement a virtual project workspace inside the app.
The workspace exposes structured MCP resources that behave like project files,
but the app remains the only writer of persisted truth.

The agent does not edit files on the phone directly.

The agent reads virtual resources and submits transactions:

```text
refusion://project/current/project.json
refusion://project/current/composition.json
refusion://project/current/layers.json
refusion://project/current/creative_graph.json
refusion://project/current/timeline.json
refusion://project/current/keyframes.json
refusion://project/current/effects.json
refusion://project/current/assets.json
refusion://project/current/selection.json
refusion://project/current/frame_snapshot.json
refusion://project/current/proof_ledger.json
```

Those resources are backed by app-owned state, not uncontrolled files.

The application writes the actual state through a transaction engine only.

---

## 2. Why This Plan Exists

The observed failures are symptoms of missing single creative truth:

```text
Agent creates background, but it appears as square or does not cover Story size.
Agent creates text, then animation update inserts a second text layer.
Agent applies motion, but motion targets the wrong layer or selected fallback.
Agent says success, but canvas/timeline/renderer do not update immediately.
Manual UI moves an element, but the agent does not reliably know the new place.
Supabase command succeeds, but local app preview applies late or partially.
Effect command writes metadata, but renderer does not prove visual application.
```

The root problem is not one bug. The root problem is that creative edits still
can pass through multiple partially overlapping paths:

```text
MCP remote payload path
manual UI direct state path
SceneProgram import path
metadata background path
legacy animation payload path
motion channel path
cloud bridge polling path
local app bridge path
preview-only state path
```

The system must collapse these into one path.

---

## 3. Reference Systems And Lessons To Adopt

This plan borrows principles from HyperFrames, Remotion, OpenCut, Glaxnimate,
OpenTimelineIO, MLT/libopenshot style render separation, and the existing
ReFusionXx plans. It does not embed those runtimes as the editing engine.

### 3.1 HyperFrames Lessons

HyperFrames succeeds for agents because project truth is explicit and readable:

```text
composition id
composition width/height
data-start
data-duration
data-track-index
registered paused timelines
stable selectors
registry manifests
```

ReFusion adoption:

```text
Every composition exposes width, height, fps, duration, current time, safe zones.
Every layer exposes stable id, kind, bounds, track, z-order, and target aliases.
Every animation is seekable from master time.
Every effect is visible in a renderer-supported stack.
Every MCP update targets a stable identity.
```

### 3.2 Remotion Lessons

Remotion succeeds because rendering is frame deterministic:

```text
useVideoConfig() gives composition truth.
useCurrentFrame() gives deterministic time.
Composition props update existing components by identity.
Sequence scopes time without losing identity.
```

ReFusion adoption:

```text
FrameEvaluator(frame/time) must derive visual state from graph + timeline only.
No hidden timer may define final visual truth.
Manual and agent edits must update props of stable layers, not recreate layers.
Preview and export must evaluate the same graph with the same time model.
```

### 3.3 OpenCut Lessons

OpenCut is web-based, but it is useful because editor actions flow through an
editor/timeline command model instead of random direct DOM changes.

ReFusion adoption:

```text
Manual UI operations must become commands/transactions.
Clipboard/import/template flows must become commands/transactions.
Selection, tracks, duration, retime, and element updates must be graph-aware.
```

### 3.4 Glaxnimate Lessons

Glaxnimate-style authoring shows that professional motion graphics need property
channels and object identity, not one-off animation blobs.

ReFusion adoption:

```text
Position, scale, rotation, opacity, fill, stroke, radius, text style, mask,
blur, glow, shadow, grain, and custom effects must be properties/channels on
stable layers.
```

### 3.5 OpenTimelineIO Lessons

OpenTimelineIO is not an editor or renderer, but its timeline thinking is useful:
clear clips, ranges, tracks, media references, and interchange semantics.

ReFusion adoption:

```text
Timeline projection should be serializable, inspectable, and deterministic.
Source ranges and timeline ranges must be explicit.
```

### 3.6 What Not To Copy

Do not replace ReFusion native editing with HTML or React.

Do not make Remotion/HyperFrames a sidecar renderer for normal editable scenes.

Do not make OTIO the app renderer.

Do not make Supabase the realtime authoring engine for local edits.

The target is native ReFusion truth:

```text
native graph -> native timeline -> native evaluator -> native preview/export
```

---

## 4. Target Architecture

### 4.1 The Single Creative Truth Stack

```text
Source Surfaces
  Manual UI
  MCP Agent
  Script
  Template
  Import
  Automation
        |
        v
Intent Normalizer
        |
        v
Target Resolver
        |
        v
Canonical Creative Transaction
        |
        v
Transaction Validator
        |
        v
Unified Apply Engine
        |
        v
In-App Virtual Project Workspace
        |
        v
Creative Graph
        |
        v
Timeline Projection
        |
        v
Frame Evaluator
        |
        v
Preview Renderer / Export Renderer
        |
        v
Renderer Proof/Ack Ledger
```

### 4.2 The In-App Virtual Project Workspace

The workspace is the app-owned project model exposed as structured resources.
It is not necessarily a real folder on mobile.

Required resources:

```text
project manifest
composition spec
layer graph
timeline graph
keyframe channels
effect stacks
asset manifest
selection context
current frame snapshot
renderer capabilities
transaction ledger
proof ledger
legacy cleanup ledger
```

Required properties:

```text
Every resource has schemaVersion.
Every resource has projectId.
Every resource has compositionId.
Every resource has revision.
Every mutation increments revision.
Every resource can be regenerated from canonical project state.
No MCP resource is allowed to become a second persisted truth.
```

### 4.3 Persistence Backing

The implementation may store project state in the current app storage system,
SQLite, Isar, Hive, app documents, or existing MotionProject persistence.
The plan does not mandate one storage technology.

It mandates only this:

```text
Persistence is app-owned.
Persistence is transaction-written.
MCP cannot write persistence directly.
Manual UI cannot bypass transaction writing.
Cloud sync cannot bypass transaction writing.
```

### 4.4 Local MCP Bridge Role

The local MCP bridge is a read/write protocol over the in-app workspace.
It is not the creative engine.

Allowed bridge responsibilities:

```text
Expose resources.
Return snapshots.
Accept transactions.
Validate permissions.
Return dry-run previews.
Return proof and diagnostics.
```

Forbidden bridge responsibilities:

```text
Directly mutate canvas widgets.
Directly insert timeline clips.
Directly rewrite MotionProject without apply engine.
Declare success without renderer proof.
Invent composition dimensions.
Use selected layer as hidden fallback when target is ambiguous.
```

### 4.5 Supabase Role After This Plan

Supabase remains useful, but it must not be the primary local authoring path.

Allowed Supabase roles:

```text
Remote collaboration.
Cloud session pairing.
Command relay when local bridge is unavailable.
Project backup/sync.
Audit history.
Remote agent control.
```

Forbidden Supabase roles:

```text
Primary realtime truth for local open editor.
Success proof without app apply.
DB row as visual success.
Polling-only live editing when local bridge is available.
Parallel layer model that differs from app graph.
```

---

## 5. Core Contracts

### 5.1 Stable Layer Identity Contract

Every editable visual or audio entity must have a stable identity.

Required identity fields:

```text
layerId: canonical app-owned id
kind: background | shape | text | image | video | audio | group | composition | effectContainer
compositionId
timelineTrackId
zOrder
createdBy: manual_ui | mcp_agent | script | template | import | migration
createdAtRevision
updatedAtRevision
aliases: remoteLayerId, targetLayerId, importedId, templateId, clipId, legacyId
```

Rules:

```text
layerId never changes after creation.
Aliases may be added, never used as canonical truth.
Update intent must resolve to one canonical layerId.
If multiple candidates exist, block and request target clarification.
If no candidate exists and intent is update, block.
Insert is allowed only for explicit insert/create intent.
```

### 5.2 Composition Spec Contract

Every operation must use the open composition spec.

Required fields:

```text
compositionId
width
height
fps
durationMs
currentTimeMs
currentFrame
pixelAspect
safeZones
backgroundPolicy
coordinateSystem
origin
scaleMode
```

Rules:

```text
Agent may request composition spec.
Agent may not override composition size during layer insert unless the command is composition.update_settings.
Background insert normalizes to full composition bounds.
Shape/text/media default placement is computed from composition spec and safe zones.
```

### 5.3 Canonical Creative Transaction Contract

Every write becomes a canonical transaction.

Minimum envelope:

```json
{
  "transactionId": "uuid",
  "schemaVersion": 1,
  "source": "manual_ui | mcp_agent | script | template | import | migration",
  "projectId": "project-id",
  "compositionId": "composition-id",
  "baseRevision": 42,
  "intent": "layer.update",
  "target": {
    "layerId": "layer_123"
  },
  "operations": [],
  "idempotencyKey": "source-scoped-key",
  "proofPolicy": "renderer_required"
}
```

Required operation families:

```text
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
effect.apply
effect.update
effect.remove
group.create
group.update
group.ungroup
asset.import
asset.update_metadata
```

### 5.4 Target Resolver Contract

The target resolver is mandatory for every update, effect, animation, and delete.

Inputs:

```text
explicit layerId
remoteLayerId
targetLayerId
clipId
selectedLayerId
user mention
spatial query
kind filter
last transaction id
visual bounds
text content hint
```

Resolution order:

```text
1. canonical layerId exact match
2. current transaction-created layerId
3. registered alias exact match
4. explicit selectedLayerId if the command says use selected layer
5. user mention resolved against current snapshot
6. spatial query with one unambiguous result
7. block
```

Forbidden:

```text
Implicit selected layer fallback.
Single visual clip fallback unless requested explicitly.
Content substring fallback when more than one layer matches.
Creating a new layer because update target is missing.
```

### 5.5 Unified Apply Engine Contract

The apply engine is the only writer of creative state.

Responsibilities:

```text
Validate transaction schema.
Validate source permissions.
Resolve target identity.
Check baseRevision conflict.
Apply operations atomically.
Update graph.
Update timeline projection.
Invalidate current frame.
Request preview repaint.
Request renderer proof.
Write transaction ledger entry.
Return proof/ack.
```

Atomicity rule:

```text
Either graph, timeline, frame evaluation, preview invalidation, and proof ledger
all agree, or the transaction fails and leaves the project unchanged.
```

### 5.6 Creative Graph Contract

The creative graph is the canonical project truth for editable objects.

Required node families:

```text
CompositionNode
LayerNode
TextNode
ShapeNode
MediaNode
AudioNode
GroupNode
EffectStackNode
MotionChannelNode
AssetNode
```

Required graph properties:

```text
stable ids
parent/child relationships
z-order
track mapping
bounds
transform
style
text content
media references
effect stack
motion channels
visibility/lock state
source metadata
revision metadata
```

### 5.7 Timeline Projection Contract

Timeline is a projection of graph truth, not a separate truth.

Required projection fields:

```text
trackId
clipId
layerId
startMs
durationMs
inPointMs
outPointMs
zOrder
visibleRange
linkedMotionChannels
linkedEffectStack
```

Rules:

```text
If a layer exists visually, it must have timeline projection unless explicitly non-timeline.
If timeline clip exists, it must point to a graph layer or asset.
Timeline cannot create orphan clips.
Timeline edits emit transactions and update graph.
```

### 5.8 Frame Evaluator Contract

The frame evaluator computes the current visual state from graph + timeline +
master clock.

Inputs:

```text
CreativeGraph
TimelineProjection
currentTimeMs/currentFrame
compositionSpec
rendererCapabilities
```

Outputs:

```text
EvaluatedFrame
EvaluatedLayer[]
EvaluatedEffects[]
EvaluatedBounds
EvaluatedTransforms
RendererProofTargets
```

Rules:

```text
No visual result may depend on uncontrolled async timers.
Motion is seek-driven.
Effects are evaluated according to current frame.
Manual drag updates graph and reevaluates frame.
MCP update updates graph and reevaluates frame.
Export uses the same evaluator.
```

### 5.9 Renderer Proof/Ack Contract

A transaction cannot report success until it has proof appropriate to its type.

Minimum proof fields:

```text
transactionId
projectId
compositionId
revisionBefore
revisionAfter
layerCountBefore
layerCountAfter
targetLayerIds
createdLayerIds
updatedLayerIds
deletedLayerIds
timelineProjectionUpdated
frameEvaluated
previewInvalidated
rendererSawTargets
exportConformanceKnown
latencyMs
proofLevel
failureReasons
```

Proof levels:

```text
schemaOnly: dry-run only, never final commit success.
graphApplied: graph changed, but no visible proof yet.
timelineProjected: timeline agrees with graph.
frameEvaluated: evaluator produced visible state.
previewRendered: preview renderer saw target.
exportConformant: export path can reproduce target.
```

Commit success for visible edits requires at least:

```text
frameEvaluated + previewRendered
```

Visible effect success also requires:

```text
rendererSawTargets + effectStackConformant
```

---

## 6. Realtime Performance Contract

The product target is perceived instant application.

Required latency budgets:

```text
text character/style update: <= 100 ms local apply target
transform drag update: <= 16-33 ms per interactive frame where possible
shape/background insert: <= 300 ms local visible target
MCP local transaction roundtrip: <= 1000 ms typical target
effect metadata validation: <= 300 ms target
effect visual preview: progressive if heavy, first feedback <= 1000 ms
```

Hard rule:

```text
No local same-device edit may wait for Supabase polling before applying.
```

Allowed realtime strategy:

```text
Apply locally first through transaction engine.
Render proof locally.
Then mirror to cloud/sync ledger asynchronously.
```

Blocked realtime strategy:

```text
Write to cloud.
Wait for polling.
Scan remote rows.
Guess what changed.
Apply partial local state.
```

---

## 7. Required MCP Resource API

The MCP bridge must expose resources that make the current scene inspectable.

### 7.1 Read Resources

Required read-only resources:

```text
refusion://project/current/manifest
refusion://project/current/composition
refusion://project/current/layers
refusion://project/current/layer/{layerId}
refusion://project/current/timeline
refusion://project/current/keyframes
refusion://project/current/effects
refusion://project/current/assets
refusion://project/current/selection
refusion://project/current/frame/current
refusion://project/current/frame/{timeMs}
refusion://project/current/renderer_capabilities
refusion://project/current/transactions/recent
refusion://project/current/proofs/recent
```

Every snapshot response must include:

```text
projectId
compositionId
revision
currentTimeMs
compositionSpec
schemaVersion
```

### 7.2 Write Tools

Required write tools:

```text
refusion.transaction.validate
refusion.transaction.apply
refusion.transaction.dry_run
refusion.transaction.undo
refusion.transaction.redo
refusion.layer.resolve_target
refusion.project.snapshot
refusion.project.diff_since_revision
refusion.renderer.prove_transaction
```

Existing tools may remain only as adapters that compile into canonical
transactions.

Example:

```text
refusion.apply_scene_program -> SceneProgram adapter -> transaction.apply
refusion.insert_text -> Text adapter -> transaction.apply
refusion.apply_animation -> Animation adapter -> transaction.apply
```

No tool may call legacy apply code directly.

### 7.3 Agent Context Contract

Before complex edits, the agent must read:

```text
project manifest
composition spec
layer graph
timeline graph
selection context
current frame snapshot
renderer capabilities
```

For simple explicit-id updates, the agent may read a compact target snapshot.

The app must make the latest manual changes visible through incremented revision.

---

## 8. Manual UI Contract

Manual UI must stop being a privileged direct mutation path.

Every UI action must emit the same transaction family as MCP.

Examples:

```text
+ Background button -> background.set_solid transaction
+ Text button -> text.insert transaction
Drag shape -> transform.patch transaction
Resize handle -> transform.patch transaction
Change color -> shape.update_style transaction
Text edit -> text.update_content transaction
Apply pop animation -> animation.apply_recipe transaction
Delete keyframe -> keyframe.delete transaction
```

UI may optimistically preview only if the optimistic state is backed by a pending
transaction and is reconciled by the apply engine.

Forbidden:

```text
UI-only layer state.
UI-only selected layer state that MCP cannot read.
Canvas-only transform state.
Timeline-only clip edits.
```

---

## 9. Script, Template, And Import Contract

Scripts and templates must compile into transactions.

Required path:

```text
Script/Template/Import
-> semantic parser/compiler
-> canonical transactions
-> dry-run validation
-> apply engine
-> renderer proof
```

Forbidden:

```text
Raw SceneProgram mutates MotionProject directly.
Template creates layer ids outside identity registry.
Import creates timeline clips without graph layers.
```

---

## 10. Migration And Cleanup Strategy

The migration must be deliberate and reversible, but the end state must delete or
block old mutation paths.

### 10.1 Inventory First

Before writing core code, create a legacy write path inventory covering:

```text
Manual UI add/update/delete paths.
MCP cloud bridge apply paths.
Local MCP app bridge paths.
SceneProgram import paths.
Remote solid/text/shape/media paths.
Animation payload paths.
Effect payload paths.
Timeline direct mutation paths.
Canvas direct setState paths.
Preview-only mutation paths.
Supabase polling apply paths.
```

For each path record:

```text
file
function/class
what it mutates
entry surface
current failure risk
new decision
migration slice
owner test
cleanup status
```

### 10.2 Adapter Phase

Convert legacy paths into adapters.

Adapter rules:

```text
Adapter may parse old payloads.
Adapter may normalize old field names.
Adapter may resolve aliases.
Adapter must emit canonical transaction.
Adapter must not mutate project state.
Adapter must not declare final success.
```

### 10.3 Blocking Phase

Once a path has a canonical replacement and tests, block direct old invocation.

Required block behavior:

```text
Return structured failure.
Include replacement tool/transaction name.
Do not silently fall back.
Do not insert new layers.
Do not mutate metadata.
```

### 10.4 Deletion Phase

After coverage is proven, delete old mutation code.

Deletion readiness requires:

```text
all touched entry surfaces routed to transaction engine
all tests passing
legacy cleanup record says delete
no direct callers remain
rg confirms no forbidden call sites
```

---

## 11. Implementation Phases

The writer agent must execute in small checkpointed slices. Do not jump ahead.
Do not touch protected Live Scrub paths unless a separate explicit approval is
provided.

### PIVWSCT-00: Pre-Build Evaluation And Legacy Write Inventory

Goal: prove exactly what will be replaced before building.

Tasks:

```text
Read this plan.
Read professional_checkpoint_policy.md.
Read professional_refusion_motion_keyframe_engine.md.
Read professional_unified_creative_truth_apply_spine_plan.md.
Read professional_realtime_mcp_editor_apply_plan.md.
Inventory all creative write paths.
Classify each old path using canonicalize/adapterOnly/featureFlag/migrate/delete/block.
Identify protected Live Scrub boundaries and confirm no touch.
Produce docs/prebuild_reports/pivwsct_00_legacy_write_inventory.md.
```

Acceptance:

```text
legacy_write_path_inventory_coverage = 100% for known entry surfaces
old_path_decision_coverage = 100%
protected_live_scrub_touch_count = 0
```

Checkpoint:

```text
checkpoint: inventory single creative truth write paths
```

### PIVWSCT-01: Core Contracts And Models

Goal: define the canonical model without changing behavior.

Build:

```text
CreativeTransactionEnvelope
CreativeTransactionOperation
CreativeTransactionSource
CreativeTransactionIntent
CreativeTargetRef
CreativeApplyProof
CreativeProofLevel
CreativeWorkspaceSnapshot
CreativeCompositionSpec
CreativeLayerIdentity
CreativeLayerAlias
LegacyPathCleanupRecord
```

Rules:

```text
Models are domain-level.
No UI wiring yet.
No MCP behavior change yet.
No renderer changes yet.
```

Tests:

```text
schema validation accepts valid transaction
schema validation rejects missing compositionId
schema validation rejects update without target
action source enum covers manual_ui/mcp_agent/script/template/import/migration
proof level ordering is deterministic
legacy cleanup record requires decision
```

Acceptance:

```text
transaction_schema_validation_pass = 100%
update_without_target_rejected = true
legacy_cleanup_record_required = true
```

Checkpoint:

```text
checkpoint: add single creative truth core contracts
```

### PIVWSCT-02: In-App Virtual Project Workspace Snapshot

Goal: expose current app truth as read-only structured snapshots.

Build:

```text
InAppVirtualProjectWorkspace
CreativeWorkspaceSnapshotBuilder
CompositionSpecSnapshot
LayerGraphSnapshot
TimelineGraphSnapshot
SelectionSnapshot
FrameSnapshotSummary
RendererCapabilitySnapshot
```

Must include:

```text
current composition width/height/fps/duration/currentTime
current selected layer id and selection origin
all layer ids/kinds/names/bounds/transforms/styles
all timeline clips linked to layer ids
all keyframe channels linked to layer ids/properties
all effect stacks linked to layer ids
asset manifest references
revision number
```

Rules:

```text
Read-only only.
No write API yet.
No behavior change.
Snapshot must reflect manual UI edits if they already exist in app state.
```

Tests:

```text
story composition snapshot reports 1080x1920 or actual current spec
manual shape move appears in next snapshot
layer id appears in both layer graph and timeline projection
orphan timeline clip is reported as diagnostic
```

Acceptance:

```text
workspace_snapshot_schema_validation_pass = 100%
manual_ui_snapshot_visibility = true
layer_timeline_linkage_coverage = 100% for sampled layers
```

Checkpoint:

```text
checkpoint: expose in-app virtual workspace snapshot
```

### PIVWSCT-03: Target Resolver Foundation

Goal: make update identity deterministic before allowing broad writes.

Build:

```text
CreativeTargetResolver
CreativeTargetResolutionRequest
CreativeTargetResolutionResult
CreativeTargetAmbiguityDiagnostic
CreativeLayerAliasIndex
```

Resolution order:

```text
canonical layerId
transaction-created id
alias exact match
explicit selected layer request
explicit user mention
spatial single match
block
```

Tests:

```text
remoteLayerId resolves to canonical layerId
text targetLayerId resolves after previous insert
ambiguous same text blocks
missing update target blocks
selected fallback blocks unless explicitly requested
spatial query with one result resolves
spatial query with multiple results blocks
```

Acceptance:

```text
update_target_resolution_pass = 100%
ambiguous_target_insert_count = 0
implicit_selected_fallback_count = 0
```

Checkpoint:

```text
checkpoint: add deterministic creative target resolver
```

### PIVWSCT-04: Transaction Validator And Dry Run

Goal: allow every source to preview validity before mutation.

Build:

```text
CreativeTransactionValidator
CreativeTransactionDryRunEngine
CreativeTransactionDiff
CreativeTransactionConflictPolicy
```

Validation rules:

```text
baseRevision must match or conflict policy must be explicit
compositionId must match open composition for live apply
target required for update/delete/effect/animation
insert requires explicit insert intent
background uses composition bounds
motion/effect requires renderer capability declaration
```

Tests:

```text
wrong compositionId rejects
stale revision rejects or returns conflict
background square payload normalizes to composition bounds in dry-run
update intent without target rejects
insert intent with target creates no duplicate unless explicit duplicate mode
```

Acceptance:

```text
invalid_transaction_block_rate = 100%
dry_run_no_mutation = true
composition_spec_enforced = true
```

Checkpoint:

```text
checkpoint: add creative transaction validation dry run
```

### PIVWSCT-05: Unified Apply Engine Skeleton

Goal: create the only write engine and wire it behind tests first.

Build:

```text
UnifiedCreativeApplyEngine
CreativeApplyContext
CreativeApplyResult
CreativeApplyLedger
CreativeRevisionManager
CreativeAtomicMutationScope
```

Initial operation coverage:

```text
background.set_solid
shape.insert
text.insert
text.update_content
transform.patch
layer.select
```

Rules:

```text
Apply engine mutates graph/timeline/project state atomically.
Apply engine emits proof request.
Apply engine returns structured failure without mutation when invalid.
No UI wiring yet unless required for tests.
```

Tests:

```text
insert background creates graph layer + timeline projection + evaluated frame target
text insert creates one layer id
text update changes same layer id and does not increase layer count
transform patch updates current bounds seen by snapshot
failed update leaves revision unchanged
```

Acceptance:

```text
atomic_apply_pass = 100%
text_update_duplicate_count = 0
background_full_canvas_bounds = true
failed_apply_mutation_count = 0
```

Checkpoint:

```text
checkpoint: add unified creative apply engine skeleton
```

### PIVWSCT-06: Manual UI Adapter Migration

Goal: route manual UI writes through the apply engine.

Migrate first:

```text
add background
add text
add shape
select layer
move layer
resize layer
rotate layer
change opacity
change fill/color
edit text content
```

Rules:

```text
Manual UI emits transactions.
Manual UI may not directly mutate creative truth.
Manual interaction must remain realtime.
Manual drag may use high-frequency transient preview only if committed through transaction frames and reconciled.
```

Tests:

```text
manual add text appears in workspace snapshot
manual drag updates graph position
agent snapshot after manual drag sees new position
timeline projection updates after manual insert
manual update increments revision once per committed edit or controlled batch
```

Acceptance:

```text
manual_ui_transaction_route_coverage >= 90% for migrated actions
manual_ui_mcp_snapshot_match = 100% for migrated actions
canvas_timeline_sync_after_manual_edit = 100%
```

Checkpoint:

```text
checkpoint: route manual ui writes through creative transactions
```

### PIVWSCT-07: Local MCP Resource And Transaction API

Goal: make the agent read the same truth and write through the same engine.

Build/route:

```text
refusion.project.snapshot
refusion.resource.read current composition/layers/timeline/effects/assets/selection/frame
refusion.transaction.validate
refusion.transaction.dry_run
refusion.transaction.apply
refusion.layer.resolve_target
refusion.renderer.prove_transaction
```

Rules:

```text
MCP read resources come from InAppVirtualProjectWorkspace.
MCP writes become canonical transactions.
MCP legacy tools become adapters.
No MCP tool directly calls old apply paths.
```

Tests:

```text
MCP reads current Story composition spec
MCP background insert uses Story bounds
MCP text insert then text update keeps same layer count
MCP animation/effect update requires target layerId
MCP transaction proof includes renderer target ids
```

Acceptance:

```text
mcp_resource_snapshot_freshness = true
mcp_write_bypass_count = 0
mcp_update_duplicate_count = 0
mcp_composition_size_mismatch_count = 0
```

Checkpoint:

```text
checkpoint: route local mcp through virtual workspace transactions
```

### PIVWSCT-08: SceneProgram, Script, Template, Import Adapter Migration

Goal: ensure non-UI and non-MCP authoring surfaces use the same path.

Migrate:

```text
SceneProgram import
DirectorPlan compile/apply
Paste script
Template apply
Asset import that creates layers
Media insert
```

Rules:

```text
Parser/compiler may remain specialized.
Final write must be canonical transaction.
Every generated layer gets app-owned stable layerId.
Every generated animation becomes property channels.
Every generated effect becomes effect stack entries with renderer capability.
```

Tests:

```text
SceneProgram creates same graph/timeline pattern as MCP equivalent
Template-created layer can be edited by manual UI
Template-created layer can be edited by MCP
Imported media layer has timeline projection and asset manifest entry
```

Acceptance:

```text
script_template_import_bypass_count = 0
cross_surface_editability = 100% for migrated surfaces
```

Checkpoint:

```text
checkpoint: migrate scene scripts templates into creative transactions
```

### PIVWSCT-09: Motion, Keyframe, And Effect Stack Unification

Goal: make movement and effects part of the same editable graph.

Build/migrate:

```text
motion property channel records
keyframe channel ownership by layerId/property
animation recipe lowering
basic easing/spring/velocity contracts
ordered effect stack records
renderer/export conformance declaration per effect
```

Initial properties:

```text
position
scale
rotation
opacity
anchor
fill
stroke
radius
text style
blur
glow
shadow
grain/noise
motion blur
mask/crop
```

Rules:

```text
Animation update never creates layer.
Effect update never creates layer.
Animation/effect must target existing layerId.
Motion is seek-driven by frame evaluator.
Effect preview and export declarations must match.
```

Tests:

```text
manual shape move then MCP motion starts from moved position
MCP text pop animation updates same text target
effect apply updates effect stack on existing layer
effect update changes existing effect entry not duplicate unless explicitly stacked
frame evaluator changes values over time deterministically
```

Acceptance:

```text
motion_target_identity_pass = 100%
effect_target_identity_pass = 100%
frame_determinism_pass = 100%
metadata_only_effect_success_count = 0
```

Checkpoint:

```text
checkpoint: unify motion keyframes effects on creative graph
```

### PIVWSCT-10: Renderer Proof And Realtime Invalidation

Goal: stop reporting success before the user can see the result.

Build:

```text
CreativeRendererProofEvaluator
PreviewInvalidationController
FrameEvaluationProofTarget
RendererProofLedger
ApplyLatencyMetrics
```

Rules:

```text
Every visible transaction invalidates the affected frame/layers.
Proof must include frame evaluator result.
Proof must include preview renderer target observation when available.
Heavy effects may return progressive proof, but not final success until visual proof.
```

Tests:

```text
text character update repaints current frame
shape transform update repaints current frame
background insert proof includes full-canvas evaluated bounds
effect apply proof reports renderer capability and observed target
DB/cloud-only proof is rejected as final success
```

Acceptance:

```text
renderer_proof_required_for_visible_success = true
metadata_only_success_count = 0
preview_invalidated_for_visible_transactions = 100%
```

Checkpoint:

```text
checkpoint: require renderer proof for creative apply success
```

### PIVWSCT-11: Cloud/Supabase Downgrade To Relay And Sync

Goal: keep cloud useful without letting it be local truth.

Migrate:

```text
Cloud pending commands -> transaction relay
Cloud layer rows -> sync mirror or backup only
Cloud ack -> app proof mirror, not proof source
Polling -> fallback only when local bridge unavailable
```

Rules:

```text
Local open editor applies locally first.
Cloud mirrors transaction and proof.
Remote commands still enter transaction engine when received.
Cloud row cannot claim appApplied without app proof ledger entry.
```

Tests:

```text
local MCP command does not wait for polling
remote cloud command applies through same engine
app proof mirrors to cloud ack
cloud-only row cannot mark renderer success
```

Acceptance:

```text
local_edit_cloud_wait_count = 0
cloud_command_apply_bypass_count = 0
cloud_app_applied_without_proof_count = 0
```

Checkpoint:

```text
checkpoint: downgrade cloud bridge to transaction relay
```

### PIVWSCT-12: Legacy Code Deletion And Bypass Guards

Goal: remove the old paths so the new plan is the only path.

Tasks:

```text
Run rg for direct legacy apply functions.
Run rg for metadata-only visual mutation.
Run rg for insert-used-as-update patterns.
Run rg for direct UI mutation call sites.
Delete replaced legacy mutation functions.
Keep only adapters that emit canonical transactions.
Add runtime assertions in debug mode for forbidden bypasses.
Add tests for bypass guard failures.
```

Acceptance:

```text
parallel_truth_path_count = 0
legacy_mutation_callsite_count = 0 for migrated features
insert_used_as_update_count = 0
metadata_only_visual_success_count = 0
```

Checkpoint:

```text
checkpoint: delete legacy creative mutation bypasses
```

### PIVWSCT-13: End-To-End Cross-Surface Certification

Goal: prove the system works like one mind.

Required E2E flows:

```text
Manual add shape -> MCP reads position -> MCP animates same shape -> no duplicate.
Manual drag shape -> MCP reads new position -> MCP animates from current position.
MCP add text -> Manual edit text -> MCP updates style -> same layer id.
MCP add background in Story composition -> full 1080x1920 bounds.
Template creates scene -> Manual moves layer -> MCP applies effect to same layer.
Script creates media layer -> MCP trims media -> timeline and canvas agree.
MCP applies effect -> proof reports renderer visual target.
Undo/redo after mixed Manual + MCP transactions preserves identity.
Preview frame and export frame evaluate same visible state.
```

Acceptance:

```text
cross_surface_context_retention = 100%
layer_duplicate_regression_count = 0
composition_size_mismatch_count = 0
manual_mcp_graph_match = 100%
preview_export_frame_match = 100% for sampled frames
visible_apply_latency_p95 <= defined budget
```

Checkpoint:

```text
checkpoint: certify single creative truth cross surface e2e
```

---

## 12. Required Reports

Every implementation phase must produce or update a report.

Required report locations:

```text
docs/prebuild_reports/pivwsct_00_legacy_write_inventory.md
docs/prebuild_reports/pivwsct_01_core_contracts.md
docs/prebuild_reports/pivwsct_02_virtual_workspace_snapshot.md
docs/prebuild_reports/pivwsct_03_target_resolver.md
docs/prebuild_reports/pivwsct_04_transaction_validation.md
docs/prebuild_reports/pivwsct_05_apply_engine.md
docs/prebuild_reports/pivwsct_06_manual_ui_migration.md
docs/prebuild_reports/pivwsct_07_mcp_transaction_api.md
docs/prebuild_reports/pivwsct_08_scripts_templates_imports.md
docs/prebuild_reports/pivwsct_09_motion_effects_keyframes.md
docs/prebuild_reports/pivwsct_10_renderer_proof.md
docs/prebuild_reports/pivwsct_11_cloud_relay_sync.md
docs/prebuild_reports/pivwsct_12_legacy_deletion.md
docs/e2e_reports/pivwsct_13_cross_surface_certification.md
```

Each report must include:

```text
scope
files inspected
existing behavior
reference lessons applied
implementation decision table
legacy cleanup table
tests run
risks
rollback command
```

---

## 13. Required Metrics

The implementation must add metrics or testable counters for:

```text
transaction_apply_latency_ms
snapshot_build_latency_ms
renderer_proof_latency_ms
manual_ui_transaction_route_coverage
mcp_write_bypass_count
legacy_mutation_callsite_count
parallel_truth_path_count
update_without_target_block_count
insert_used_as_update_count
layer_duplicate_regression_count
composition_size_mismatch_count
metadata_only_success_count
preview_export_mismatch_count
cloud_wait_for_local_edit_count
```

Release blockers:

```text
parallel_truth_path_count > 0 for migrated features
mcp_write_bypass_count > 0
metadata_only_success_count > 0
insert_used_as_update_count > 0
composition_size_mismatch_count > 0 in certified flows
missing_prebuild_report_count > 0
missing_legacy_cleanup_decision_count > 0
```

---

## 14. Writer Agent Operating Rules

The writer agent must follow these rules exactly:

```text
1. Start with PIVWSCT-00 only.
2. Do not implement PIVWSCT-01 until PIVWSCT-00 report is complete.
3. Do not jump phases.
4. Do not touch protected Live Scrub files.
5. Do not add new creative capabilities before routing existing ones.
6. Do not leave old write paths active after a migrated path is complete.
7. Do not accept metadata-only proof.
8. Do not use insert when the intent is update.
9. Do not use selected fallback unless the command explicitly says selected.
10. Do not let Supabase remain the primary local realtime path.
11. Stage only related files per checkpoint.
12. Commit every completed slice with checkpoint message.
13. Push every checkpoint to the current branch.
14. Include rollback command after every checkpoint.
```

---

## 15. Definition Of Ready

A phase is ready only when:

```text
prebuild report exists
legacy paths for the phase are inventoried
old path decisions are recorded
target tests are identified
protected Live Scrub touch count is confirmed zero
rollback strategy is known
```

---

## 16. Definition Of Done

A phase is done only when:

```text
implementation matches this plan
focused tests pass
legacy cleanup records are updated
bypass guards are present where relevant
proof/metrics are available where relevant
no unrelated files are staged
checkpoint commit exists
checkpoint push succeeds
rollback command is documented
```

Final project done means:

```text
Manual UI, MCP, Script, Template, and Import all write through one transaction engine.
The app exposes one virtual project workspace snapshot.
Every layer has stable identity.
Every update targets existing identity or blocks.
Canvas and timeline read the same graph truth.
Preview and export use the same frame evaluator truth.
Visible success requires renderer proof.
Supabase is relay/sync, not local realtime truth.
All migrated legacy mutation paths are deleted or blocked.
```

---

## 17. Final Architecture In One Sentence

ReFusionXx must behave like a mobile-native HyperFrames/Remotion-quality editor
not by embedding their runtimes, but by giving every actor one explicit project
truth, one stable identity map, one deterministic frame/time model, one
transaction writer, and one renderer-backed proof system.
