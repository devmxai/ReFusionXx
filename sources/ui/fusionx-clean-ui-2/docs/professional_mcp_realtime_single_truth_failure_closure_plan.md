# Professional MCP Realtime Single Truth Failure Closure Plan

Short name: `PMRSTFC`

Status: official failure-closure plan

Package: `com.refusion.app`

Date: 2026-05-15

Depends on:

- `professional_in_app_virtual_project_workspace_single_creative_truth_plan.md`
- `professional_unified_creative_truth_apply_spine_plan.md`
- `professional_realtime_mcp_editor_apply_plan.md`
- `professional_checkpoint_policy.md`
- `professional_refusion_motion_keyframe_engine.md`

Primary goal: close the exact failure where an MCP Agent reports that a layer or
background was created because `get_layers` and `revision` changed, while the
open ReFusion mobile app shows nothing on the canvas and nothing in the real
editor timeline.

This is not a new creative feature plan. This is a runtime correctness closure
plan. Its job is to make the already-defined single creative truth architecture
actually become the live path used by the open mobile editor.

---

## 0. Hard Decision

The current success definition is wrong.

This is not success:

```text
MCP row exists in refusion_layers
project revision increased
get_layers returns the row
```

This is only cloud data existence.

Real success is:

```text
command accepted
open app receives command
open app applies canonical transaction
MotionProject / creative graph changes
real timeline projection changes
current frame is evaluated
canvas is invalidated and repainted
renderer proof confirms target visibility
app ACK writes appApplied=true
MCP wait_for_apply returns success with strict proof
```

From this point forward, any Agent answer that claims success from `get_layers`
without `appApplied=true` and renderer proof must be treated as a false positive.

---

## 1. Current Evidence From Code And Device

### 1.1 Live Device State Evidence

ADB inspection on `2026-05-15` showed the device was not focused on ReFusion:

```text
mCurrentFocus = com.sec.android.app.launcher
mFocusedApp = launcher
com.refusion.app MainActivity exists in history but is not resumed
logcat: WindowStopped on com.refusion.app/com.refusion.app.MainActivity set to true
```

Meaning:

```text
The app was not the foreground live editor at the time of inspection.
```

If the app is backgrounded, locked, on launcher, or not inside an active
composition session, realtime local apply cannot be certified.

This does not excuse the architecture, but it proves that the E2E test must first
guarantee:

```text
app foreground = true
open composition = true
active composition id matches MCP scope
canvas visible = true
editor bridge online = true
```

### 1.2 Cloud Tool Evidence

In `supabase/functions/mcp/index.ts`, `insertLayer(...)` does this:

```text
insert refusion_layers row
update project revision
recordCommand(... status=pending ... appApplied=false)
return Layer inserted
```

This means the initial tool success is cloud acceptance, not app application.

The same file already contains stricter tools:

```text
refusion.get_command_status
refusion.wait_for_apply
```

and `wait_for_apply` requires proof fields including:

```text
dataApplied
localGraphApplied
timelineVisible
frameEvaluated
visualProgramEmitted
rendererApplied
visualBoundsVerified
```

If the Agent says `get_command_status` is unavailable, then the active MCP tool
surface is stale, incomplete, or the Agent is connected through a host/profile
that does not expose the current registry. That must be treated as a connector
configuration/runtime deployment failure.

### 1.3 Flutter Cloud Bridge Evidence

In `refusion_mcp_cloud_bridge.dart`, live sync still works by polling/cloud RPC:

```text
touch_editor_session
set_active_context
sync_editor_layers
get_active_context
get_pending_commands
get_layers
get_motion_channels
emit snapshot
run diagnostics later
```

This is not the zero-delay local transaction path. It is a cloud bridge with
network requests, soft timeouts, and silent `_safeCallTool` failures.

Important failure behavior:

```text
_safeCallTool catches all errors and returns null.
```

So the app can fail to fetch pending commands, layers, or diagnostics without
making the failure visible to the user or the Agent as a hard apply failure.

### 1.4 Flutter Screen Runtime Evidence

In `fusionx_clean_ui_screen.dart`, the current live flow is still:

```text
_handleMcpCloudSnapshot
-> pending command materialization
-> _applyRemoteLayersIfNeeded
-> McpSceneCommandDispatcher
-> _applyRemoteSolidLayerIfNeeded / _applyRemoteTextLayerIfNeeded / etc.
-> mutate _motionProject and _tracks via screen-level setState
-> ack revision if represented locally
```

This is a legacy bridge path. It is not yet the `LocalMcpTransactionApi` path.

### 1.5 New PIVWSCT Runtime Gap Evidence

The new services exist:

```text
LocalMcpTransactionApi
UnifiedCreativeApplyEngine
InAppVirtualProjectWorkspace
CreativeTransactionEnvelope
CreativeTargetResolver
CreativeTransactionValidator
```

But current search shows they are domain/test level only. They are not wired into
`fusionx_clean_ui_screen.dart` or `refusion_mcp_cloud_bridge.dart` as the live
MCP apply path.

Therefore:

```text
PIVWSCT exists as contracts/services/tests.
PIVWSCT is not yet the mobile editor runtime path.
```

This is the core architectural gap.

---

## 2. Root Causes

### RC-01: False Success Contract

The Agent accepts `get_layers` and `revision` as success.

But `get_layers` reads `refusion_layers` from Supabase. It does not prove:

```text
open app received command
open app mutated MotionProject
timeline projected the layer
canvas repainted
renderer saw it
```

Required closure:

```text
Agent must call wait_for_apply(commandId, strictProof=true).
MCP must not present DB row existence as visual success.
```

### RC-02: Live App Not Guaranteed Foreground/Open Composition

Current device inspection showed launcher/lockscreen state, not the open editor.

Required closure:

```text
Before every live apply test, verify foreground app package, resumed activity,
active composition id, canvas visible, and bridge online.
```

If not true, block the test and report:

```text
APP_NOT_FOREGROUND_OR_COMPOSITION_NOT_OPEN
```

### RC-03: New Single Truth Services Are Not The Live Runtime Path

`LocalMcpTransactionApi` exists but is not used by the presentation/live bridge.

Required closure:

```text
MCP command -> canonical transaction -> LocalMcpTransactionApi -> UnifiedCreativeApplyEngine -> MotionProject/Timeline adapter -> preview invalidation -> renderer proof
```

The old path must become adapter-only or be blocked.

### RC-04: Cloud Polling Cannot Be The Primary Local Realtime Path

The existing bridge still depends on cloud requests and polling. It can be 1s in
best case and much longer on network/timeout/diagnostics failure.

Required closure:

```text
local foreground editor applies locally first
cloud mirrors result later
```

Cloud relay is allowed, but cloud DB cannot be the local realtime authority.

### RC-05: Silent Bridge Failures Hide The Real Problem

`_safeCallTool` swallows all errors and returns null. This masks:

```text
pending command fetch failure
layer fetch failure
auth failure
agent session mismatch
timeout
stale tool registry
```

Required closure:

```text
fast apply failures must surface as diagnostics and block proof.
```

### RC-06: Composition Spec Is Not Enforced At Runtime Boundary

The Agent can read a 1080x1920 composition, but the actual live apply still must
normalize all geometry against the app-owned composition spec before rendering.

Required closure:

```text
composition spec must come from the foreground app workspace snapshot
not from Agent memory or stale cloud context
```

### RC-07: Timeline Projection Is Still Partly Derived In Screen State

For shapes/backgrounds, the screen builds timeline projection from MotionProject
only after specific tracks exist and screen state updates occur.

Required closure:

```text
canonical apply must update graph + timeline projection atomically
and the UI must read the projection from one source
```

### RC-08: Renderer Proof Is Not Yet Actual Runtime Proof For The New Path

`LocalMcpTransactionApi` proof currently can report graph-level proof with
`rendererApplied=false`. The old proof path infers renderer proof from projection
and bounds, not from a hard live renderer observation.

Required closure:

```text
final appApplied=true requires renderer/app frame proof, not DB/projection only
```

---

## 3. Final Required Runtime Shape

The correct live flow must become:

```text
MCP Agent
-> refusion.project.snapshot / local workspace resource
-> Agent chooses target from current app snapshot
-> refusion.transaction.apply
-> app validates foreground composition
-> app converts request to CreativeTransactionEnvelope
-> UnifiedCreativeApplyEngine applies to UnifiedCreativeState
-> MotionProjectAdapter commits to MotionProject
-> TimelineProjectionAdapter commits to timeline truth
-> FrameEvaluator evaluates current frame
-> CanvasPreviewInvalidation repaints
-> RendererProofEvaluator confirms visual target
-> app ACKs command with strict proof
-> Agent receives wait_for_apply success
```

No other write path may claim live success.

---

## 4. Non-Negotiable Acceptance Rules

### 4.1 Foreground Gate

Before a live command applies:

```text
package foreground == com.refusion.app
activity resumed == MainActivity
app foreground flag == true
composition session started == true
motionProject != null
active composition id == command composition id
canvas size > 0
```

If any fails:

```text
block command or keep pending with reason APP_NOT_READY
no appApplied=true
no success answer
```

### 4.2 Composition Gate

The app-owned composition spec is mandatory:

```text
width
height
fps
durationMs
currentTimeMs
compositionId
coordinateSystem
safe zones
```

The Agent may not invent size. A background command in Story must produce:

```text
bounds = 0,0,1080,1920 in composition coordinates
```

or equivalent center-origin full-canvas representation.

### 4.3 Identity Gate

Any update, animation, effect, delete, trim, style change, or transform requires
one resolved canonical target layer id.

If target is missing or ambiguous:

```text
block
return TARGET_NOT_FOUND or AMBIGUOUS_TARGET
never insert
```

### 4.4 Apply Gate

Every source writes through the same apply path:

```text
Manual UI
MCP
Script
Template
Import
```

All must produce canonical transactions.

### 4.5 Proof Gate

A visible command is successful only if:

```text
localGraphApplied = true
timelineVisible = true
frameEvaluated = true
previewInvalidated = true
rendererApplied = true
visualBoundsVerified = true
appApplied = true
```

### 4.6 Agent Protocol Gate

The Agent response must be forbidden from saying success unless it has:

```text
commandId
wait_for_apply strict proof success
appApplied=true
rendererApplied=true
visualBoundsVerified=true
```

If `wait_for_apply` is not visible in the connected tool surface, the session is
misconfigured and must fail before creative execution.

---

## 5. Implementation Plan

### PMRSTFC-00: Live Failure Reproduction Gate

Goal: build a trustworthy reproduction protocol before code changes.

Tasks:

```text
1. Verify device is connected.
2. Verify current focus is com.refusion.app.
3. Verify MainActivity is resumed.
4. Verify editor composition is open.
5. Verify canvas dimensions from app snapshot.
6. Verify MCP tool list exposes wait_for_apply and get_command_status.
7. Clear logcat.
8. Run one controlled background insert.
9. Require commandId from insert response.
10. Call wait_for_apply(commandId, strictProof=true).
11. Capture screenshot, UI tree, logcat, MCP command status.
```

Acceptance:

```text
foreground_gate_verified = true
composition_gate_verified = true
wait_for_apply_available = true
false_success_reproduced_or_blocked = true
```

Blockers:

```text
If app is launcher/lockscreen/background, stop and report APP_NOT_FOREGROUND.
If wait_for_apply missing, stop and report MCP_TOOL_SURFACE_STALE.
```

Checkpoint:

```text
checkpoint: document mcp realtime failure reproduction gate
```

### PMRSTFC-01: Runtime Diagnostic Surfacing

Goal: stop silent failures.

Changes:

```text
1. Replace silent _safeCallTool swallowing for fast apply calls with structured diagnostics.
2. Track pending command fetch success/failure.
3. Track get_layers success/failure.
4. Track materialized pending command count.
5. Track remote layers selected for apply.
6. Track each apply decision: applied, represented, blocked, skipped.
7. Expose these diagnostics in the UI/dev log and proof map.
```

Required diagnostics:

```text
mcpFastApply.pendingCommandsFetched
mcpFastApply.pendingCommandCount
mcpFastApply.remoteLayerCount
mcpFastApply.materializedLayerCount
mcpFastApply.appliedCommandCount
mcpFastApply.blockedReasons
mcpFastApply.foregroundReady
mcpFastApply.compositionMatch
mcpFastApply.lastError
```

Acceptance:

```text
silent_fast_apply_failure_count = 0
mcp_apply_diagnostic_present = 100%
```

Checkpoint:

```text
checkpoint: surface mcp live apply diagnostics
```

### PMRSTFC-02: MCP Tool Surface Strictness

Goal: make the Agent unable to claim success from DB rows.

Changes:

```text
1. Ensure get_command_status and wait_for_apply are exposed in all MCP tool registries.
2. Update agent prompt/tool descriptions to require wait_for_apply after every mutation.
3. Return warning in insert/update tool response: not visually applied until wait_for_apply succeeds.
4. Add strict response fields to mutation results:
   cloudCommitted=true
   appApplied=false
   proofRequired=true
   nextRequiredTool=refusion.wait_for_apply
```

Acceptance:

```text
mutation_response_false_success_wording_count = 0
wait_for_apply_tool_surface_coverage = 100%
agent_db_only_success_blocked = true
```

Checkpoint:

```text
checkpoint: require wait for apply in mcp tool surface
```

### PMRSTFC-03: Foreground And Composition Runtime Gate

Goal: avoid applying into non-open or wrong editor state.

Changes:

```text
1. Add foreground/composition readiness check before _handleMcpCloudSnapshot apply.
2. If not ready, do not claim success.
3. ACK failure or keep pending with structured APP_NOT_READY depending policy.
4. Include active projectId/compositionId/canvas size in failure proof.
5. Expose ready state to MCP snapshot.
```

Acceptance:

```text
background_app_success_ack_count = 0
wrong_composition_apply_count = 0
app_not_ready_proof_present = 100%
```

Checkpoint:

```text
checkpoint: gate mcp apply on foreground composition readiness
```

### PMRSTFC-04: Runtime Adapter From MCP Command To Canonical Transaction

Goal: convert incoming MCP commands into `CreativeTransactionEnvelope` before
any state mutation.

Build:

```text
McpCommandToCreativeTransactionAdapter
McpLayerPayloadToCreativeOperationMapper
McpCompositionSpecRuntimeResolver
McpCanonicalTargetResolverAdapter
```

Input:

```text
pending command row
remote layer row
current app workspace snapshot
```

Output:

```text
CreativeTransactionEnvelope
```

Rules:

```text
insert_layer -> layer.insert/background.set_solid/text.insert/shape.insert/media.insert
update_layer -> layer.update/text.update_content/shape.update_style/transform.patch/effect.update
motion patch -> animation.apply_recipe/keyframe.batch_apply
style/effect -> effect.apply/effect.update
```

Acceptance:

```text
mcp_command_to_transaction_coverage >= 90% for current MCP tools
insert_used_as_update_count = 0
composition_spec_from_app_workspace = true
```

Checkpoint:

```text
checkpoint: adapt mcp commands into creative transactions
```

### PMRSTFC-05: Bridge UnifiedCreativeState To MotionProject Runtime

Goal: make the canonical apply engine mutate what the canvas and timeline
actually render.

Build:

```text
MotionProjectUnifiedCreativeStateAdapter
UnifiedCreativeStateFromMotionProjectBuilder
MotionProjectCommitFromUnifiedCreativeState
TimelineProjectionCommitAdapter
```

Rules:

```text
MotionProject remains the current renderable runtime until fully replaced.
UnifiedCreativeState cannot remain test-only.
Every successful canonical transaction must commit back to MotionProject.
Every MotionProject commit must update timeline projection and selection.
```

Acceptance:

```text
canonical_background_insert_visible_on_canvas = true
canonical_background_insert_visible_on_timeline = true
canonical_text_update_same_layer = true
manual_mcp_state_equivalence = true
```

Checkpoint:

```text
checkpoint: bridge unified creative apply into motion project runtime
```

### PMRSTFC-06: Replace Legacy Remote Apply With Adapter-Only Path

Goal: remove direct screen-level mutation from MCP apply.

Old direct methods become adapter-only or blocked:

```text
_applyRemoteSolidLayerIfNeeded
_applyRemoteShapeLayerIfNeeded
_applyRemoteTextLayerIfNeeded
_applyLegacyRemoteAnimationFromLayerIfNeeded
_applyRemoteTimelineClipMutationFromLayerIfNeeded
```

Allowed after this slice:

```text
legacy payload -> canonical transaction -> unified apply -> runtime commit
```

Forbidden after this slice:

```text
legacy payload -> direct setState mutation -> ack success
```

Acceptance:

```text
mcp_direct_screen_mutation_count = 0 for migrated layer types
parallel_truth_path_count = 0 for background/text/shape/transform/effect basics
```

Checkpoint:

```text
checkpoint: replace legacy mcp remote apply with canonical transaction path
```

### PMRSTFC-07: Immediate Canvas And Timeline Invalidation

Goal: make changes visible without delay.

Changes:

```text
1. After canonical apply, update MotionProject state synchronously on UI isolate.
2. Rebuild timeline projection immediately.
3. Invalidate current frame immediately.
4. Repaint preview overlay immediately.
5. Emit applied toast/diagnostic only after local commit.
6. Mirror cloud ACK asynchronously after local proof.
```

Latency targets:

```text
background/text/shape local commit <= 300ms
text single property update <= 100ms target
local MCP roundtrip <= 1000ms target
no local operation waits for cloud polling when local bridge is available
```

Acceptance:

```text
visible_apply_latency_p95 <= 1000ms
canvas_timeline_update_same_frame_or_next_frame = true
cloud_wait_for_local_edit_count = 0
```

Checkpoint:

```text
checkpoint: make mcp creative apply immediately invalidate canvas timeline
```

### PMRSTFC-08: Strict Renderer Proof

Goal: final success only after renderer-visible proof.

Build:

```text
RuntimeRendererProofProbe
CanvasTargetVisibilityProbe
TimelineTargetProjectionProbe
FrameEvaluationTargetProbe
```

Proof must include:

```text
targetLayerId
localLayerId
elementId
visualBounds
canvasBounds
trackId
clipId
currentFrame
rendererObserved=true
visualBoundsVerified=true
```

Acceptance:

```text
metadata_only_success_count = 0
rendererApplied_false_success_count = 0
visual_bounds_verified_for_background = 100%
```

Checkpoint:

```text
checkpoint: require runtime renderer proof for mcp success
```

### PMRSTFC-09: Cloud Relay Downgrade And Local-First Mode

Goal: stop using cloud DB as realtime authority.

Changes:

```text
1. When app is foreground and local bridge/session exists, apply locally first.
2. Cloud receives transaction/proof mirror after local apply.
3. Cloud pending command remains fallback for remote/offline relay.
4. get_layers remains inspection only, never visual success proof.
```

Acceptance:

```text
local_first_mcp_apply_enabled = true
cloud_db_primary_realtime_path_count = 0
supabase_row_success_without_app_proof_count = 0
```

Checkpoint:

```text
checkpoint: downgrade cloud mcp path to relay after local apply
```

### PMRSTFC-10: End-To-End Certification

Required E2E tests on real device:

```text
1. Open Story composition 1080x1920.
2. Verify app foreground and composition session.
3. MCP insert white background.
4. wait_for_apply strict proof succeeds.
5. Screenshot shows white background covering entire canvas.
6. Timeline shows one background/shape clip linked to same layer.
7. MCP insert text.
8. MCP update text content/style on same layer.
9. Layer count does not increase on update.
10. MCP apply pop animation to same text.
11. Animation targets same layer/element.
12. Manual move shape.
13. MCP snapshot sees moved position.
14. MCP animates from moved position to new position.
15. MCP apply effect to selected/explicit target.
16. Renderer proof confirms effect target.
```

Acceptance:

```text
mcp_background_canvas_match = 100%
mcp_text_update_duplicate_count = 0
mcp_animation_wrong_target_count = 0
manual_mcp_context_retention = 100%
visible_apply_latency_p95 <= 1000ms
appApplied_true_requires_rendererProof = 100%
```

Checkpoint:

```text
checkpoint: certify mcp realtime single truth on device
```

---

## 6. Immediate Writer Agent Instruction

The writer agent must not start by adding more creative features.

Start only with:

```text
PMRSTFC-00 + PMRSTFC-01 + PMRSTFC-02
```

Purpose:

```text
prove current failure honestly
surface hidden bridge failures
force Agent/tooling to stop claiming DB-only success
```

Do not proceed to canonical runtime replacement until these are complete.

Required first files to inspect:

```text
docs/professional_mcp_realtime_single_truth_failure_closure_plan.md
docs/professional_in_app_virtual_project_workspace_single_creative_truth_plan.md
docs/professional_checkpoint_policy.md
docs/professional_refusion_motion_keyframe_engine.md
supabase/functions/mcp/index.ts
lib/features/editor/presentation/services/refusion_mcp_cloud_bridge.dart
lib/features/editor/presentation/services/mcp_pending_command_layer_materializer.dart
lib/features/editor/presentation/screens/fusionx_clean_ui_screen.dart
lib/features/editor/domain/services/local_mcp_transaction_api.dart
lib/features/editor/domain/services/unified_creative_apply_engine.dart
```

Forbidden:

```text
Do not treat get_layers as success.
Do not add UI-only fixes.
Do not add MCP-only fixes.
Do not bypass MotionProject/timeline/canvas proof.
Do not touch protected Live Scrub files.
Do not hide _safeCallTool errors in the fast apply path.
Do not report appApplied without strict proof.
```

---

## 7. Final Definition Of Done

This failure is closed only when:

```text
Agent cannot claim success from DB row alone.
wait_for_apply is mandatory and available.
App foreground/composition readiness is enforced.
MCP command converts to canonical transaction.
Canonical transaction commits into MotionProject runtime.
Timeline projection updates immediately.
Canvas repaints immediately.
Renderer proof is required for appApplied=true.
Cloud is relay/sync, not realtime authority.
Legacy direct MCP mutation paths are adapter-only or blocked.
Real-device E2E passes on Story 1080x1920.
```

Until then, the issue is not solved; it is only partially documented and tested
at domain level.
