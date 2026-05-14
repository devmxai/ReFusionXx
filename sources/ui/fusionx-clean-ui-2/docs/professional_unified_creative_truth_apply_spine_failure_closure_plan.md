# Professional Unified Creative Truth Apply Spine Failure Closure Plan

Short name: `PUCTAS-FC`

Parent plan: `professional_unified_creative_truth_apply_spine_plan.md`

Integrated child plan: `PNCLE-05C.UNIVERSAL-LAYER-UPDATE-IDENTITY-HARDENING.md`

Status: official failure-closure execution plan

Date: 2026-05-14

## 0. Executive Decision

This is the single corrective plan for the current MCP live-apply failure
family.

Do not create a disconnected plan and do not continue broad PUCTAS or PNCLE
feature work until this plan is green on device.

The correct structure is:

```text
PUCTAS
  -> PUCTAS-FC
       -> PUCTAS-FC-01 background/canvas closure
       -> PUCTAS-FC-02 universal identity closure
          -> absorbs PNCLE-05C
       -> PUCTAS-FC-03 fast apply bridge closure
       -> PUCTAS-FC-04 renderer proof closure
       -> PUCTAS-FC-05 legacy path removal closure
```

`PNCLE-05C` is not replaced. It is promoted into this plan as the identity
hardening gate for every editable layer family.

Reason:

```text
The current failures are not isolated bugs.
They are evidence that old partial MCP apply paths still bypass the unified
creative truth spine.
```

Therefore the implementation must not patch one function at a time. It must
remove or adapt every old path that bypasses:

```text
Canonical SceneCommand
-> Composition Spec Gate
-> Intent Classifier
-> Universal Target Resolver
-> Unified Apply Engine
-> Creative Graph
-> Timeline Projection
-> Frame Evaluator
-> Preview/Export Renderer
-> Visual Proof/Ack
```

## 1. Current Live Failures To Close

The latest code and device review confirmed these user-visible failures:

1. MCP can create a background in a Story/Reels composition and the visual can
   appear square instead of filling the active `1080x1920` canvas.
2. MCP can insert text, then a later text update or pop-up animation can create
   another text layer instead of updating the same text.
3. MCP motion can fall back to `selectedClip` or a single visual clip when the
   intended target is unresolved.
4. A simple MCP background/text command can take 10-30 seconds to appear because
   visual apply is still coupled to a heavy polling/sync chain.
5. `appApplied` or proof can indicate data/projection success without proving
   the renderer drew the correct visual node, bounds, and target.

These are one failure family:

```text
MCP intent is accepted
-> legacy/type-specific path interprets it
-> active composition spec is not enforced
-> target identity is not universal
-> unsafe fallbacks can choose the wrong object
-> visual apply waits for polling/diagnostics
-> proof can be metadata/data proof instead of renderer truth
```

## 2. Reference Lessons

### 2.1 HyperFrames Lesson

HyperFrames uses stable DOM selectors and component/block ids:

```text
selector/id -> same DOM node -> style/motion/effect updates same target
```

Professional rule to adopt:

- a style update must target an existing element;
- an animation must target the same selector/identity;
- a missing selector must fail instead of creating a random new element;
- visible layout is real render tree truth, not metadata-only truth.

ReFusion-native translation:

```text
remoteLayerId / targetLayerId / localLayerId / clipId / aliases
-> UniversalLayerTarget
-> same graph node / timeline clip / element
-> update existing target or fail closed
```

### 2.2 Remotion Lesson

Remotion uses composition config and component identity:

```text
Composition(width,height,fps,duration)
same component identity + new props + current frame -> new pixels
```

Professional rule to adopt:

- canvas width/height/fps/duration must be explicit;
- component identity must not be recreated for prop updates;
- frame evaluation must be deterministic;
- preview and export must read the same graph/frame truth.

ReFusion-native translation:

```text
active composition spec + stable layer identity + timeline time
-> evaluated visual program
-> preview/export render the same truth
```

### 2.3 ReFusion Rule

Do not embed HyperFrames or Remotion as normal editable runtimes.

Use them as architecture references only. ReFusion must remain:

```text
native graph
native timeline
native motion/effect channels
native preview/export
```

## 3. Existing Plans And Authority

### 3.1 Parent Plan

`professional_unified_creative_truth_apply_spine_plan.md` remains the parent
architecture. It defines the single source of creative truth.

### 3.2 Identity Plan

`PNCLE-05C.UNIVERSAL-LAYER-UPDATE-IDENTITY-HARDENING.md` is now mandatory inside
this closure plan. Its core requirements are adopted here:

- build `UniversalLayerTarget`;
- build `UniversalMcpLayerIdentityResolver`;
- build `UniversalLayerRuntimeUpdatePlanner`;
- prevent insert when request is actually update;
- cover text, shape, background, image, video, motion, effects, and style;
- block unsafe selected-clip or single-clip fallback;
- require E2E: insert -> update same layer -> motion with no layer count
  increase.

### 3.3 Native Creative Library Plan

`professional_native_creative_library_engine_plan.md` already links
`PNCLE-05C` as a required hardening phase before lowering and renderer
conformance. This closure plan makes that requirement executable now, before
new creative library expansion.

## 4. Non-Negotiable System Contract

Every authoring source must pass through the same spine:

```text
Manual UI
MCP Agent
Paste Script
Templates
Tap List
Future Tools
        |
        v
Canonical SceneCommand
        |
        v
Composition Spec Gate
        |
        v
Canonical Intent Classifier
        |
        v
Universal Layer Identity Resolver
        |
        v
Universal Runtime Update Planner
        |
        v
Unified Apply Engine
        |
        v
Creative Graph + Timeline Projection
        |
        v
Frame Evaluator
        |
        v
Preview Renderer + Export Renderer
        |
        v
Visual Proof/Ack
```

Forbidden:

```text
MCP direct setState
MCP metadata-only visual success
MCP placeholder timeline clip without graph node
MCP selected-clip fallback for unresolved targeted updates
Manual UI private graph mutation outside the spine
Paste Script private element insertion outside the spine
Template private element insertion outside the spine
Proof inferred from Supabase row/revision only
```

Any old path must be:

```text
deleted
or converted into a canonical-command adapter
or kept only as a private helper under Unified Apply Engine
```

## 5. Root Cause Map

| Failure | Current Cause | Required Closure |
|---|---|---|
| Story/Reels background appears square | `kind=shape` can dispatch before background intent; payload size can survive as final bounds | classify background intent before kind; force active canvas bounds |
| Text animation duplicates text | multi-turn MCP identity is not universal; missing target can become insert | UniversalLayerTarget + fail-closed update/motion |
| Motion on wrong layer | unresolved target can fall back to selected/single clip | block unsafe fallback for MCP mutation intent |
| 10-30s visual delay | command apply waits on polling/sync and diagnostics | separate fast apply path from slow diagnostics |
| False `appApplied` | proof can equal data/projection success | renderer proof with bounds/target checks |
| Old bugs return | old type-specific paths remain | old path removal/adaptation gate |

## 6. Gate 1: Active Composition Spec Gate

Goal: every command uses the active local composition as the canvas truth.

Required command context:

```json
{
  "compositionId": "...",
  "canvas": {
    "width": 1080,
    "height": 1920,
    "aspect": "9:16",
    "preset": "Story",
    "fps": 30,
    "durationMs": 8000,
    "origin": "center"
  }
}
```

Rules:

- local active composition spec is authoritative;
- MCP-provided width/height is a hint, never final background truth;
- conflicting MCP canvas data must be normalized to local canvas;
- proof must include the canvas spec used;
- background/full-canvas commands must use active canvas bounds.

Acceptance:

- Story/Reels selected locally;
- MCP sends background with `1080x1080`;
- app produces full `1080x1920` background;
- proof reports active canvas `1080x1920`;
- no square background is accepted as applied.

## 7. Gate 2: Canonical Intent Classifier

Goal: classify intent before layer kind.

Priority:

1. operation intent:
   - `set_background`
   - `insert_background`
   - `update_background`
   - `update_layer`
   - `animate_layer`
   - `apply_effect`
2. semantic role:
   - `background`
   - `title`
   - `primaryVideo`
3. target/update fields:
   - `targetLayerId`
   - `layerId`
   - `requestedLayerId`
   - `localLayerId`
   - `clipId`
4. mutation payload:
   - `updates`
   - `style`
   - `transform`
   - `motion`
   - `animation`
   - `effects`
5. raw layer kind:
   - `text`
   - `shape`
   - `solid`
   - `media`

Hard rules:

```text
background/fullCanvas intent beats kind=shape
update intent beats insert wording
motion/effect/style intent beats insert wording
insert_layer + targetLayerId + mutation fields is not insert
ambiguous intent fails closed
```

Acceptance:

- `kind=shape + operation=background` routes to background command;
- `kind=shape + name=Scene Background` routes to background command;
- `kind=shape + fullCanvas=true` routes to background command;
- normal rectangle without background intent remains normal shape.

## 8. Gate 3: Universal Layer Identity

This gate absorbs and supersedes the execution priority of `PNCLE-05C`.

### 8.1 Required Model: UniversalLayerTarget

Add a universal target model representing the resolved target of any local or
remote command.

Required fields:

```text
canonicalTargetId
targetKind
targetFamily
remoteLayerId
targetLayerId
localLayerId
clipId
elementId
sourceId
aliases
resolutionSource
confidence
isAmbiguous
isMissing
blockers
metadata
```

Required target kinds:

```text
textElement
shapeElement
backgroundElement
imageClip
videoClip
audioClip
timelineClip
motionChannel
effectInstance
unknownLayer
```

Required resolution sources:

```text
remoteLayerId
targetLayerId
layerId
requestedLayerId
localLayerId
clipId
metadataAlias
existingElementContext
timelineClipMap
lastCreatedBySource
lastTouchedBySource
none
```

`selectedClip` and `singleVisualClip` are not valid automatic resolution
sources for MCP update/motion/effect/style mutation intent.

### 8.2 Required Resolver: UniversalMcpLayerIdentityResolver

The resolver must be pure and testable.

It must extract candidates from:

```text
remoteLayer.id
remoteLayer.remoteLayerId
remoteLayer.layerId
remoteLayer.targetLayerId
remoteLayer.requestedLayerId
remoteLayer.localLayerId
remoteLayer.clipId
payload.*
payload.payload.*
updates.*
updates.payload.*
motion.*
animation.*
effect.*
effects.*
style.*
metadata.mcp.remoteLayerId
metadata.mcp.remoteLayerAliases
```

It must return:

```text
resolvedSingle
resolvedAmbiguous
missingTarget
unsupportedTargetKind
blockedUnsafeFallback
```

### 8.3 Required Planner: UniversalLayerRuntimeUpdatePlanner

Required decisions:

```text
insertNewLayer
updateExistingLayer
applyStyleToExistingLayer
applyTransformToExistingLayer
applyEffectToExistingLayer
applyMotionToExistingLayer
skipDuplicatePayload
blockUnresolvedUpdate
blockAmbiguousTarget
blockUnsupportedTarget
blockUnsafeFallback
```

Hard rule:

```text
Any update/motion/effect/style/transform mutation with unresolved or ambiguous
target must block. It must not insert.
```

### 8.4 Required Diagnostic

Every apply attempt must produce a diagnostic object:

```text
operation
decision
remoteLayerId
targetLayerId
canonicalTargetId
targetKind
targetFamily
resolutionSource
createdNewLayer
updatedExistingLayer
appliedStyle
appliedTransform
appliedEffect
appliedMotion
blockedUnresolvedUpdate
blockedAmbiguousTarget
blockedUnsafeFallback
layerCountBefore
layerCountAfter
textLayerCountBefore
textLayerCountAfter
shapeLayerCountBefore
shapeLayerCountAfter
mediaLayerCountBefore
mediaLayerCountAfter
motionChannelTargetId
payloadSignature
blockers
```

No path may claim success from metadata writes alone.

## 9. Gate 4: Layer Family Behavior

### 9.1 Text

```text
insert text -> creates one text layer
update same text -> same element updates
motion same text -> same element receives motion
duplicate identical payload -> skip
unresolved update -> block
ambiguous update -> block
```

### 9.2 Shape

```text
insert shape -> creates one shape layer/element
update fill/stroke/cornerRadius -> same shape updates
update mask/border/glow/shadow -> same shape/effect stack updates
motion shape -> same shape receives motion
unresolved update -> block
ambiguous update -> block
```

### 9.3 Background

```text
insert background -> creates/binds one background target
update background color/gradient/style -> same target updates
payload size never overrides active canvas for background
duplicate identical payload -> skip
changed payload -> update, not skip
unresolved update -> block
```

### 9.4 Image

```text
insert image -> creates one image clip/layer
update crop/fit/position/scale/rotation/opacity -> same target updates
update mask/border/glow/shadow -> same target/effect stack updates
motion image -> same target receives motion
unresolved update -> block
ambiguous update -> block
```

### 9.5 Video

```text
insert video -> creates one video clip/layer
update transform/crop/mask/style -> same target updates
effect video -> same video receives effect instance
motion video -> same video receives motion
unresolved update -> block
ambiguous update -> block
```

Do not touch Stage5, Live Scrub, native playback, or export renderer in this
gate unless a later explicitly approved slice says so.

### 9.6 Motion

```text
motion with explicit target -> exact target
motion after update -> same canonicalTargetId
motion unresolved -> block
motion ambiguous -> block
selected/single clip fallback -> forbidden for MCP mutation intent
```

### 9.7 Effects And Style

```text
apply effect with target -> same layer/effect stack
update effect with target -> same effect instance when identity exists
style mutation with target -> same target updates
unresolved effect/style update -> block
metadata-only effect success -> forbidden
```

## 10. Gate 5: Fast Apply Bridge

Goal: visual apply must not wait for slow diagnostics.

Split the bridge:

```text
Fast path:
  realtime or minimal pending-command event
  fetch affected layers/channels only
  apply locally
  renderer proof
  ack

Slow diagnostics path:
  get_canvas_metadata
  get_visual_layout_summary
  get_project_snapshot
  get_timeline_graph
  evaluate_frame
```

Rules:

- command apply does not wait for diagnostics;
- diagnostics cannot hold an `_syncInFlight` lock that blocks apply;
- pending command fetch must be command-scoped;
- realtime is preferred;
- polling is fallback only and must be reported as fallback.

Budgets:

```text
MCP write -> local command received p95 <= 500ms with realtime
local command received -> canvas visible p95 <= 250ms
MCP write -> canvas visible p95 <= 1000ms with realtime
polling fallback visible p95 <= 8000ms
```

## 11. Gate 6: Renderer Proof/Ack

`appApplied=true` means rendered truth.

Required proof:

```json
{
  "dataApplied": true,
  "graphNodeExists": true,
  "timelineClipExists": true,
  "frameEvaluated": true,
  "visualProgramEmitted": true,
  "rendererApplied": true,
  "targetLayerId": "...",
  "targetElementId": "...",
  "operationApplied": "insert|update|motion|effect",
  "canvasBounds": {"x":0,"y":0,"width":1080,"height":1920},
  "visualBounds": {"x":0,"y":0,"width":1080,"height":1920},
  "createdLayerCount": 0,
  "updatedLayerCount": 1,
  "latencyMs": 143
}
```

Rules:

- background proof compares visual bounds to canvas bounds;
- update proof reports stable target and unchanged layer count;
- motion/effect proof reports resolved target identity;
- proof cannot be inferred from Supabase row existence;
- proof cannot be inferred from revision increment.

## 12. Gate 7: Legacy Path Removal

The implementation must create and maintain a cleanup map:

```text
old path name
current behavior
decision: delete|adapter|keep-private-helper
replacement spine path
test proving old behavior cannot return
removal deadline if temporarily kept
```

Mandatory cleanup targets:

1. background classified after generic shape dispatch;
2. solid/background metadata-only truth;
3. shape full-canvas heuristic as the only background detector;
4. update intent falling back to insert;
5. motion/effect falling back to selected/single clip;
6. bridge diagnostics blocking command apply;
7. proof evaluator treating data application as renderer proof;
8. MCP-only direct apply paths;
9. Manual UI direct mutations outside the same spine;
10. Script/template insertions outside the same spine.

## 13. Execution Slices

### PUCTAS-FC-00: Unified Failure Closure Pre-Build Report

Before code, create a report that includes:

- current code inventory;
- current live failures;
- HyperFrames comparison;
- Remotion comparison;
- PNCLE-05C integration decision;
- old path cleanup map;
- selected first slice;
- tests;
- rollback;
- protected files not to touch.

Checkpoint:

```text
checkpoint: document puctas failure closure prebuild
```

### PUCTAS-FC-01: Background Intent And Canvas Spec Closure

Scope:

- active composition spec gate;
- background intent before shape kind;
- full-canvas canonicalization;
- background graph/timeline/proof bounds;
- remove/adapt old shape-first background bypass.

Tests:

- Story/Reels MCP background from `1080x1080` becomes `1080x1920`;
- Square composition still supports square background;
- normal shape rect remains shape;
- proof blocks square visual in Story/Reels;
- no metadata-only background success.

Device E2E:

- create Story/Reels;
- MCP asks white background;
- full-canvas background appears under budget;
- timeline clip links to graph node;
- manual UI can select/edit it.

Checkpoint:

```text
checkpoint: close mcp background canvas intent path
```

### PUCTAS-FC-02: Universal Identity Models And Resolver

This is `PNCLE-05C-01` inside PUCTAS-FC.

Scope:

- `UniversalLayerTarget`;
- `UniversalMcpLayerIdentityResolver`;
- all id/alias extraction;
- ambiguity/missing/unsafe fallback decisions.

Acceptance:

- resolver extracts all supported id aliases;
- resolver resolves text/shape/background/image/video/timeline clip targets;
- resolver reports ambiguous targets;
- resolver reports missing targets;
- resolver blocks unsafe fallback for mutation intent;
- no UI behavior changes.

Checkpoint:

```text
checkpoint: add universal layer identity resolver
```

### PUCTAS-FC-03: Universal Intent Classifier And Runtime Planner

This is `PNCLE-05C-02` inside PUCTAS-FC.

Scope:

- intent classifier;
- runtime update planner;
- diagnostic model;
- duplicate payload decision;
- fail-closed update/motion/effect/style behavior.

Acceptance:

- insert remains insert only when no update/mutation target exists;
- `insert_layer` with target/update fields is not insert;
- unresolved update/motion/effect/style blocks;
- duplicate identical payload skips;
- changed payload updates existing target;
- planner emits complete diagnostics.

Checkpoint:

```text
checkpoint: add universal layer runtime update planner
```

### PUCTAS-FC-04: Text, Shape, Background Adapter Migration

Scope:

- route existing text behavior through the universal planner;
- route shape behavior through the universal planner;
- route background behavior through the universal planner;
- preserve PNCLE-05B text hardening;
- remove old background/shape bypasses.

Acceptance:

- MCP text insert -> update -> motion uses one target;
- MCP shape insert -> update style -> motion uses one target;
- MCP background insert -> update color uses one target;
- unresolved/ambiguous updates block;
- layer counts do not increase for updates.

Checkpoint:

```text
checkpoint: route text shape background through universal identity
```

### PUCTAS-FC-05: Image, Video, Motion, Effect Adapter Migration

Scope:

- image/video timeline clip target identity;
- media transform/style/mask/effect target identity;
- motion channel target binding;
- effect/style stack target binding;
- remove selected/single clip fallback for MCP mutation intent.

Acceptance:

- image update does not duplicate;
- video update does not duplicate;
- video/image motion targets same media target;
- effect/style mutation targets same layer/effect instance;
- unresolved/ambiguous motion/effect blocks.

Checkpoint:

```text
checkpoint: route media motion effects through universal identity
```

### PUCTAS-FC-06: Fast Apply Bridge Closure

Scope:

- separate command apply from diagnostics;
- realtime/minimal pending-command fast path;
- diagnostics path cannot block visual apply;
- latency metrics and fallback reporting.

Acceptance:

- background visible under 1s on realtime path;
- diagnostics may run after apply;
- polling fallback is explicit;
- command-specific fetch only loads affected layers/channels.

Checkpoint:

```text
checkpoint: split mcp fast apply from diagnostics
```

### PUCTAS-FC-07: Renderer Proof Closure

Scope:

- proof from graph + timeline + frame evaluator + renderer;
- bounds verification;
- target identity verification;
- no data-only success.

Acceptance:

- row exists but graph missing => not applied;
- graph exists but timeline missing => not applied;
- timeline exists but renderer bounds wrong => not applied;
- wrong target motion/effect => not applied;
- square background in Story/Reels cannot return success.

Checkpoint:

```text
checkpoint: enforce renderer proof for mcp apply
```

### PUCTAS-FC-08: Legacy Path Removal Gate

Scope:

- code search cleanup;
- old path map finalized;
- bypass tests;
- documentation update.

Acceptance:

- every MCP apply path enters canonical spine;
- every Manual UI/script/template path has adapter or cleanup ticket;
- no old path can produce visual success without graph/timeline/renderer proof.

Checkpoint:

```text
checkpoint: remove legacy apply bypasses
```

### PUCTAS-FC-09: Device E2E Closure

Required real-device scenarios:

1. Story/Reels MCP background from square payload fills full canvas.
2. MCP text insert -> update same text -> apply pop-up motion.
3. MCP shape insert -> update rounded corners/fill -> apply motion.
4. Manual shape -> MCP update same shape.
5. MCP image/video insert -> update transform/style/effect on same target.
6. Ambiguous text/shape update blocks.
7. Unresolved motion/effect blocks.
8. Repeated same update does not duplicate layer or channel.

Required proof per scenario:

```text
before layer count
after layer count
target id before
target id after
motion/effect target id
diagnostic decision
canvas bounds
visual bounds
latency
screenshot or UI dump if available
```

Checkpoint:

```text
checkpoint: verify puctas failure closure e2e
```

## 14. Required Tests

Focused tests must be added or preserved for:

```text
composition spec gate
background intent classifier
universal layer identity resolver
universal runtime update planner
text update identity
shape/background update identity
image/video update identity
motion/effect target binding
command taxonomy guard
renderer proof evaluator
fast apply bridge
```

Minimum command set by slice:

```bash
flutter test test/presentation_services/mcp_text_layer_resolution_test.dart
flutter test test/presentation_services/mcp_text_runtime_update_identity_test.dart
flutter test test/mcp/refusion_mcp_mvp_toolkit_test.dart
```

New focused tests must be added for universal resolver/planner and for
background canvas closure.

## 15. KPIs

```text
MCP_background_story_correct_bounds = 100%
MCP_text_update_duplicate_rate = 0%
MCP_shape_update_duplicate_rate = 0%
MCP_media_update_duplicate_rate = 0%
MCP_motion_wrong_target_rate = 0%
MCP_effect_wrong_target_rate = 0%
unresolved_update_insert_rate = 0%
ambiguous_update_random_apply_rate = 0%
appApplied_data_only_success_rate = 0%
MCP_to_visible_p95_realtime <= 1000ms
MCP_to_visible_p95_polling_fallback <= 8000ms
preview_export_parity_background >= 0.99
```

## 16. Definition Of Ready

Do not start implementation unless:

- pre-build report exists;
- current code paths are audited;
- PNCLE-05C integration decision is stated;
- HyperFrames/Remotion comparison is included;
- old path cleanup map exists;
- protected files are listed;
- tests are listed;
- rollback plan exists.

## 17. Definition Of Done

Do not close this plan unless:

- `PUCTAS-FC-01` through `PUCTAS-FC-09` are green or explicitly blocked with
  reason;
- old path cleanup map is complete;
- universal identity resolver and planner are implemented and tested;
- background canvas closure passes on device;
- text/shape/background/image/video update identity passes;
- motion/effect unsafe fallback is removed for MCP mutation intent;
- fast apply is separated from diagnostics;
- renderer proof blocks data-only success;
- no Live Scrub or Stage5 protected paths are touched without approval;
- all checkpoints are pushed;
- rollback command is reported for every checkpoint.

## 18. Stop List

Do not:

- continue registry/effect expansion before `PUCTAS-FC-01` and `PUCTAS-FC-04`
  are green;
- patch background only in one local function while leaving shape dispatch first;
- let payload width/height override active composition for background;
- use insert as update;
- create duplicate nodes for update intent;
- apply MCP motion/effect/style to selected clip when target is unresolved;
- claim success from metadata, row existence, or revision increment;
- add MCP-only behavior;
- add UI-only behavior;
- embed HyperFrames runtime;
- embed Remotion runtime;
- change Stage5 or Live Scrub in this closure plan.

## 19. Recommended Immediate Start

Start now with:

```text
PUCTAS-FC-00: Unified Failure Closure Pre-Build Report
PUCTAS-FC-01: Background Intent And Canvas Spec Closure
```

Then immediately execute:

```text
PUCTAS-FC-02
PUCTAS-FC-03
PUCTAS-FC-04
```

Reason:

- the square background bug proves active canvas/background intent is broken;
- the text animation duplication proves universal identity is not complete;
- both failures share the same root: old paths bypass the spine;
- fixing only one without the other lets the same bug family return.

## 20. Final Closure Statement

This problem is closed only when the following is true on the connected device:

```text
MCP background in Story/Reels
-> full canvas visible immediately
-> timeline clip linked to graph node
-> manual UI can select/edit it
-> MCP can update it without duplicate
-> proof includes correct canvas and visual bounds

MCP text then animation
-> same text element receives update/motion
-> no duplicate text
-> no selected/single clip fallback
-> proof includes same targetElementId

MCP shape/image/video update
-> same target receives style/transform/effect/motion
-> no duplicate layer
-> unresolved/ambiguous target fails closed

MCP command latency
-> fast apply path is under budget
-> diagnostics no longer block visible apply
```

Until all of this is true, `PUCTAS` is not complete and the product may not
claim professional MCP live apply.
