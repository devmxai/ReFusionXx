# Professional Unified Runtime Apply Spine Closure Plan

## Purpose

This document is the execution plan for closing the ReFusionXx MCP/manual/apply gap at the foundation level.

The goal is not to fix one text animation, one background, or one MCP command. The goal is to make every authoring source write through one runtime apply spine:

```text
Manual UI / MCP Agent / Paste Script / Templates / Future Tools
        ↓
CreativeTransactionEnvelope
        ↓
Universal Target Resolver
        ↓
Universal Property Resolver
        ↓
UnifiedCreativeApplyEngine
        ↓
Canonical Creative State / MotionProject / Timeline Projection
        ↓
Master Frame Evaluator
        ↓
Preview Renderer / Playback / Export Renderer
        ↓
Renderer Proof / App ACK
```

After this plan is complete, an MCP agent must not be able to report success because a row exists in Supabase. Success is valid only when the open app has applied the transaction locally, evaluated the current frame, updated the visible timeline/canvas, and produced proof.

## Current Root Cause

The current live MCP path does not fully use the local unified transaction/apply spine.

The current live path is effectively:

```text
MCP Agent
        ↓
Supabase refusion_layers / refusion_motion_channels / refusion_agent_commands
        ↓
RefusionMcpCloudBridge.syncNow()
        ↓
_handleMcpCloudSnapshot()
        ↓
_applyRemoteLayersIfNeeded()
_applyRemoteMotionChannelsIfNeeded()
        ↓
McpSceneCommandDispatcher
        ↓
_applyRemoteTextLayerIfNeeded()
_applyRemoteShapeLayerIfNeeded()
_applyRemoteSolidLayerIfNeeded()
_applyRemoteMotionChannel()
```

This is a legacy remote-apply route. It is type-specific, payload-specific, and depends on late remote-to-local identity mapping. It is not equivalent to the Manual UI path, where keyframes are written directly against local element identity and evaluated by the local motion runtime.

The correct path already exists partially in domain code:

```text
CreativeTransactionEnvelope
        ↓
LocalMcpTransactionApi
        ↓
UnifiedCreativeApplyEngine
```

But this path is not yet the mandatory live MCP path. This plan closes that gap.

## External Architecture Lessons

### HyperFrames Lesson

HyperFrames does not treat animation metadata as success. Animation becomes real only when it is seekable:

```text
canonical target
finite time window
adapter binding
seek(t)
concrete visual state
preview/render verification
```

ReFusionXx must adopt the same invariant:

```text
Remote layer/channel exists
```

is not success.

```text
Resolved runtime node evaluated at time T and rendered
```

is success.

### Remotion Lesson

Remotion has one composition runtime:

```text
Composition(width, height, fps, durationInFrames)
        ↓
useCurrentFrame()
        ↓
frame -> value
        ↓
render
```

ReFusionXx must mirror this natively:

```text
CompositionSpec(width, height, fps, durationMs)
        ↓
MasterFrameEvaluator(timeMs/frameIndex)
        ↓
node property values
        ↓
preview/export renderer
```

No source may bypass the frame evaluator.

## Mandatory Execution Rules For The Writer Agent

### Rule 1: No Blind Code

Before each phase, the writer agent must produce a short pre-build report:

```text
Phase ID
Files to inspect
Current behavior
Expected behavior
Exact files to edit
Test plan
Device verification plan
Rollback plan
```

No code may be written before this report.

### Rule 2: Phase Closure Gate

The writer agent must not move to the next phase until the current phase is closed.

Each closure requires:

```text
1. Unit/service tests for the phase pass.
2. No unrelated files touched.
3. If the phase affects app/MCP/apply/preview, install on the connected wireless Android device.
4. Run a real MCP/manual scenario on the open app.
5. Capture screenshot/log proof when the phase affects visual behavior.
6. Commit and push a focused checkpoint.
7. Provide rollback command.
```

### Rule 3: Connected Device Verification Is Mandatory

There is a real Android device connected wirelessly and the app is open during this work. For every phase that affects the runtime apply path, the writer agent must verify on-device behavior.

The device verification must prove:

```text
The app open on the device is the same package under test.
The active composition is Story/Reels when testing Story/Reels.
MCP writes apply to that exact open composition.
Canvas output respects the official composition canvas.
Timeline shows the same target layer/clip.
Playback/scrub reflects evaluated motion when motion is tested.
```

### Rule 4: No Stage5 / Live Scrub Changes Without Explicit Approval

Do not modify protected Stage5 or Live Scrub files unless the user explicitly authorizes that exact change.

This plan must close MCP/apply/identity/evaluation issues before touching Stage5.

### Rule 5: No Metadata-Only Success

The following are not valid proof:

```text
Supabase row exists
revision increased
get_layers returns a layer
motion channel row exists
timeline data changed only in the cloud
```

Valid proof requires local runtime evidence:

```json
{
  "localGraphApplied": true,
  "timelineVisible": true,
  "targetResolved": true,
  "frameEvaluated": true,
  "rendererApplied": true,
  "visualBoundsVerified": true
}
```

For motion, proof must include sampled frame values:

```json
{
  "sampleStart": {"timeMs": 0, "scaleX": 0.15, "opacity": 0.0},
  "sampleMid": {"timeMs": 300, "scaleX": 1.1, "opacity": 1.0},
  "sampleEnd": {"timeMs": 900, "scaleX": 1.0, "opacity": 1.0}
}
```

If values do not change, the motion did not apply.

## Phase 0 — Baseline And Safety Check

### Objective

Establish the current repo/device/app baseline before code changes.

### Required Inspection

Inspect:

```text
lib/features/editor/presentation/screens/fusionx_clean_ui_screen.dart
lib/features/editor/presentation/services/refusion_mcp_cloud_bridge.dart
lib/features/editor/presentation/services/mcp_scene_command_dispatcher.dart
lib/features/editor/domain/services/local_mcp_transaction_api.dart
lib/features/editor/domain/services/unified_creative_apply_engine.dart
lib/features/editor/presentation/services/professional_scene_apply_proof_evaluator.dart
supabase/functions/mcp/index.ts
```

### Required Output

Write a pre-build report explaining:

```text
Current live MCP entry point
Current local/manual keyframe entry point
Current proof/ack behavior
Current device/app version
Dirty worktree files that must not be touched
```

### Verification

Run:

```bash
git status -sb
git rev-parse --short HEAD
adb devices
adb shell pidof com.refusion.app
```

If the app is not running, launch it and verify the current open screen before proceeding.

### Closure Criteria

Phase 0 is closed only when the baseline report exists and no code was changed.

## Phase 1 — MCP Live Transaction Adapter

### Objective

Convert live MCP input into `CreativeTransactionEnvelope` before applying anything to the editor.

### Current Problem

`McpSceneCommandDispatcher` produces `ProfessionalSceneCommand`, then the screen executes type-specific handlers.

This must stop being the primary path.

### Required Build

Create or introduce an adapter that converts live MCP artifacts into transactions:

```text
pending command insert layer      -> CreativeTransactionIntent.layerInsert/textInsert/shapeInsert/backgroundSetSolid
pending command update layer      -> CreativeTransactionIntent.layerUpdate/textUpdateContent/transformPatch
motion channel row                -> CreativeTransactionIntent.keyframeBatchApply
legacy animation payload          -> CreativeTransactionIntent.animationApplyRecipe or keyframeBatchApply
effect/style payload              -> CreativeTransactionIntent.effectApply or layerUpdate
```

### Required Design

The adapter must preserve:

```text
projectId
compositionId
remoteLayerId
targetLayerId
commandId
revisionBefore/revisionAfter
source = mcpAgent
raw payload for diagnostics
```

### Required Integration

The live MCP snapshot path must call the transaction adapter before the legacy dispatcher.

Allowed temporary behavior:

```text
transaction path first
legacy path only as compatibility fallback
debug warning when fallback is used
```

Forbidden behavior:

```text
legacy path primary
type-specific handler primary
ack before transaction apply
```

### Required Tests

Add tests proving:

```text
MCP text insert payload -> CreativeTransactionEnvelope(textInsert)
MCP background payload -> CreativeTransactionEnvelope(backgroundSetSolid)
MCP shape payload -> CreativeTransactionEnvelope(shapeInsert)
MCP motion channel -> CreativeTransactionEnvelope(keyframeBatchApply)
MCP legacy animation payload -> CreativeTransactionEnvelope(animationApplyRecipe or keyframeBatchApply)
```

### Device Verification

After implementation:

```text
1. Install the app on the connected wireless device.
2. Open/create a Story composition.
3. Send MCP command: create full-canvas white background.
4. Confirm it appears inside the official rounded Story canvas, not as an external square overlay.
5. Confirm timeline shows a background/solid clip.
6. Confirm ACK/proof is not based only on get_layers.
```

### Closure Criteria

Phase 1 is closed only if:

```text
Transactions are generated for MCP artifacts.
Legacy dispatcher is not the primary path for tested commands.
Device background insertion works through transaction path.
Focused tests pass.
Commit and push completed.
```

## Phase 2 — Universal Target Identity

### Objective

Guarantee that every update/motion/effect resolves to a real local target before application.

### Required Contract

Every target must resolve through one resolver:

```text
remoteLayerId
targetLayerId
layerId
localLayerId
elementId
timelineClipId
aliases
selectedLayerIds
spatial candidates
text query
```

### Required Rules

```text
Insert intent without target -> allowed.
Update intent without resolved target -> fail closed.
Motion intent without resolved target -> fail closed.
Effect intent without resolved target -> fail closed.
Ambiguous target -> fail closed with candidates.
Fallback to selected layer -> allowed only when explicitly permitted and unambiguous.
```

### Required Build

The resolver must output:

```json
{
  "resolved": true,
  "targetLayerId": "...",
  "targetElementId": "...",
  "timelineClipId": "...",
  "source": "remoteLayerId|targetLayerId|selected|spatial|textQuery",
  "confidence": 1.0
}
```

### Required Tests

Add tests:

```text
insert text -> creates one target
update same remoteLayerId -> same target
motion same remoteLayerId -> same target
update missing target -> fail closed
motion missing target -> fail closed
two text layers ambiguous update -> fail closed
```

### Device Verification

On connected device:

```text
1. Create text from MCP.
2. Update same text from MCP.
3. Verify no duplicate text.
4. Apply motion to same text.
5. Verify same text moves/animates.
6. Confirm timeline layer count does not increase on update/motion.
```

### Closure Criteria

Phase 2 is closed only when the device proves no duplicate text/layer is created for update or motion.

## Phase 3 — Universal Property Resolver

### Objective

Make all authoring sources use one property vocabulary.

### Required Canonical Properties

At minimum:

```text
x / positionX / position.x                  -> transform.position.x
y / positionY / position.y                  -> transform.position.y
scale / scaleX / scale.x                    -> transform.scale.x
scale / scaleY / scale.y                    -> transform.scale.y
rotation / rotationDeg / rotationDegrees    -> transform.rotation.degrees
opacity                                     -> visual.opacity
blur / blurAmount / gaussian_blur           -> visual.blur.amount
motionBlur / motionBlurAmount / motion_blur -> effect.motionBlur.amount
```

### Required Lowering Rules

```text
scale as scalar -> write both scale.x and scale.y unless explicit axis exists.
position as {x,y} -> write position.x and position.y channels.
rotationDeg -> transform.rotation.degrees.
blurAmount -> visual.blur.amount.
unknown property -> fail closed.
unsupported property for node kind -> fail closed.
```

### Required Server/Client Parity

The same aliases must be supported in:

```text
supabase/functions/mcp/index.ts
Flutter runtime property resolver
Manual UI registry/catalog
```

If one side supports a property and another side does not, the property is not officially supported.

### Required Tests

Add tests for property canonicalization:

```text
positionX -> transform.position.x
scale -> transform.scale.x and transform.scale.y
rotationDeg -> transform.rotation.degrees
blurAmount -> visual.blur.amount
motionBlurAmount -> effect.motionBlur.amount
unknown property fails
```

### Device Verification

On connected device:

```text
1. Create text.
2. Apply scale motion through MCP.
3. Apply rotation motion through MCP.
4. Apply opacity motion through MCP.
5. Apply Gaussian blur if renderer support is confirmed.
6. Verify visual changes on canvas and timeline.
```

### Closure Criteria

Phase 3 is closed only when supported properties change evaluated frame values and render visibly.

## Phase 4 — Runtime Evaluation Boundary

### Objective

Ensure every transaction is compiled/evaluated before ACK.

### Required Runtime Sequence

After transaction apply:

```text
normalize transaction
resolve target
validate capability
apply to local graph/state
project to timeline
evaluate frame at current playhead
invalidate preview
collect visual proof
ack command
```

### Required Build

Create or wire a single evaluation/proof function:

```text
evaluateTransactionProof(transaction, state, timeMs)
```

It must check:

```text
target exists locally
timeline clip exists
frame evaluator sees target
render snapshot has non-empty bounds
opacity/scale/position match expected sampled values when applicable
```

### Required Tests

Add tests:

```text
background transaction -> evaluated bounds match canvas
text transaction -> evaluated text node exists
motion transaction -> sampled values differ across start/mid/end
proof fails when target is missing
proof fails when property was not evaluated
```

### Device Verification

On connected device:

```text
1. Create background.
2. Create text.
3. Apply pop-up.
4. Scrub/play.
5. Confirm text appears small/hidden at animation start and ends at final scale.
6. Confirm ACK only after proof passes.
```

### Closure Criteria

Phase 4 is closed only when proof catches failed/non-visible animation.

## Phase 5 — Legacy Path Containment And Cleanup

### Objective

Prevent old handlers from remaining silent alternative truth paths.

### Required Cleanup

The following must no longer be primary MCP apply paths:

```text
_applyRemoteTextLayerIfNeeded
_applyRemoteShapeLayerIfNeeded
_applyRemoteSolidLayerIfNeeded
_applyRemoteMotionChannel
McpSceneCommandDispatcher as primary live path
```

Allowed:

```text
compatibility adapter
diagnostic fallback
migration helper
```

But every fallback must:

```text
log clearly
not ack success before proof
have a removal TODO with phase id
have tests or explicit unsupported status
```

### Required Tests

Add tests proving:

```text
primary MCP text/background/motion commands route through transaction adapter
legacy fallback is not used for normal commands
fallback warning appears when forced
```

### Device Verification

Run full end-to-end scenario:

```text
1. Open Story composition.
2. MCP: create background.
3. MCP: create text "TEXT MOTION TEST".
4. MCP: apply pop-up motion.
5. MCP: update same text color/size.
6. MCP: apply rotation or position motion.
7. Verify no duplicate layers.
8. Verify timeline and canvas match.
9. Verify playback/scrub shows motion.
```

### Closure Criteria

Phase 5 is closed only when the normal MCP path does not depend on legacy handlers.

## Phase 6 — Capability Registry Enforcement

### Objective

Make the system honest about what is supported.

### Required Rule

A capability is supported only if it has:

```text
registry entry
target applicability
parameter schema
property/effect resolver
evaluator support
preview renderer support
export renderer support or explicit export fallback
proof test
manual UI exposure or explicit reason
MCP exposure or explicit reason
```

### Required Examples

For each of these, declare status:

```text
transform.position.x
transform.position.y
transform.scale.x
transform.scale.y
transform.rotation.degrees
visual.opacity
visual.blur.amount
effect.motionBlur.amount
```

If `effect.motionBlur.amount` does not have complete renderer/proof for text, it must not be claimed as fully supported for text.

### Required Tests

Add capability conformance tests:

```text
supported property passes registry/evaluator/renderer proof
unsupported property fails before apply
MCP discovery does not list unsupported properties as supported
```

### Device Verification

Test one supported property and one unsupported property:

```text
supported -> applies and renders
unsupported -> fails clearly and does not mutate graph
```

### Closure Criteria

Phase 6 is closed only when MCP cannot claim unsupported effects as applied.

## Final Acceptance Suite

The full closure must run after all phases.

### Automated Tests

Run the smallest targeted suite plus analysis:

```bash
flutter test test/presentation_services
flutter test test/creative_library
flutter analyze
```

If there are known unrelated analysis warnings, document them explicitly.

### Required Device E2E

On the connected wireless Android device:

```text
Scenario A: Background
- Open/create Story composition.
- MCP creates full-canvas background.
- Background appears inside official Story canvas.
- Timeline shows one matching layer/clip.
- Proof verifies bounds == canvas bounds.

Scenario B: Text Insert/Update
- MCP creates text.
- MCP updates same text.
- No duplicate text.
- Same targetElementId.
- Timeline layer count stable on update.

Scenario C: Pop-Up Motion
- MCP applies pop-up to same text.
- Scrub/play shows visible motion.
- Sampled frame values prove scale/opacity changes.
- No new text layer is created.

Scenario D: Property Motion
- MCP applies position/rotation/opacity.
- Visual result changes on canvas.
- Timeline/channel state points to same local target.

Scenario E: Fail Closed
- MCP sends unknown property.
- Command fails.
- No graph mutation.
- No metadata-only success.
```

### Final Done Criteria

The plan is complete only if:

```text
MCP live path uses transaction adapter as primary path.
Manual UI and MCP share target/property/evaluation contracts.
Legacy remote handlers are contained or removed.
ACK requires local runtime proof.
Device E2E passes.
Focused tests pass.
Checkpoint commit and push are complete.
Rollback command is documented.
```

## Commit And Rollback Rules

Each phase must end with a focused checkpoint:

```bash
git add <related files only>
git commit -m "checkpoint: <phase-specific message>"
git push
```

Each report must include:

```bash
git revert <commit-hash>
```

Do not stage unrelated diagnostics, screenshots, or old workspace files unless they are required test artifacts for the specific phase.

## Final Instruction To The Writer Agent

Do not build randomly.

Do not patch one symptom.

Do not declare success from database state.

Do not move to the next phase until the previous phase is tested on the connected device when visual/apply behavior is affected.

The professional target is:

```text
one source of creative truth
one transaction engine
one target resolver
one property resolver
one frame evaluator
one preview/export truth
one proof contract
```

Anything outside this spine is either a temporary compatibility adapter or technical debt that must be named, logged, tested, and scheduled for removal.
