# PNCLE-05C.UNIVERSAL-LAYER-UPDATE-IDENTITY-HARDENING

Status: official execution plan  
Package: `com.refusion.app`  
Date: 2026-05-14  
Phase position: immediately after `PNCLE-05B.RUNTIME-TEXT-UPDATE-E2E-HARDENING` and before `PNCLE-06: Lowering And Timeline Projection`

## 1. Executive Decision

`PNCLE-05C.UNIVERSAL-LAYER-UPDATE-IDENTITY-HARDENING` must run now.

This is not a late polish task. It is a required architecture hardening step
before ReFusion can safely expand the professional creative library, registry
packs, MCP authoring, template compilation, lowering, renderer conformance, or
export parity.

Reason:

```text
If layer identity is not universal, every future update can accidentally become
an insert.
```

The text-specific fix in `PNCLE-05B.RUNTIME-TEXT-UPDATE-E2E-HARDENING` reduced
the most visible duplication bug for text, but the same class of bug can still
exist for shape, background, image, video, effects, transforms, and motion
channels unless every layer-like operation uses one shared target-resolution and
update-vs-insert decision model.

This phase upgrades ReFusion from:

```text
type-specific MCP apply paths with local identity heuristics
```

to:

```text
universal layer identity resolution
+ strict operation planning
+ fail-closed update semantics
+ apply proof diagnostics
```

## 2. Why This Phase Belongs Now

The master PNCLE plan already requires first-class command families:

```text
insertText / updateText
insertShape / updateShape
insertMedia / updateMediaBinding
setTransform
applyEffect / updateEffect
applyMotionRecipe / applyKeyframes
```

It also states:

```text
insert commands create new graph nodes
update commands target existing graph nodes
motion commands create or update motion channels
effect commands create or update effect instances
```

Therefore, a universal identity hardening slice must happen before `PNCLE-06`,
because `PNCLE-06` lowers registry items into graph nodes, timeline clips,
effect instances, and motion channels. If lowering starts while MCP/manual/script
updates can still duplicate layer nodes, the graph will inherit duplicated truth.

Correct timing:

```text
PNCLE-05B text runtime identity hardening
-> PNCLE-05C universal layer update identity hardening
-> PNCLE-06 lowering and timeline projection
-> PNCLE-07 renderer conformance
```

Blocked if skipped:

```text
professional registry expansion
shape library expansion
media update workflows
motion recipe packs
effect stack authoring
template compilation
renderer/export parity claims
```

## 3. Problem Statement

The current MCP runtime can receive commands that look like updates but are
represented through legacy or mixed payloads:

```text
insert_layer with target fields
insert_layer with updates
payload.motion
payload.animation
payload.updates.motion
payload.updates.animation
style mutation payloads
media mutation payloads
shape/background mutation payloads
```

Without a universal layer identity model, each layer family can make a different
decision:

```text
text may update existing text
shape may insert a new shape
solid/background may short-circuit
media may create or mutate a clip depending on local maps
motion may fall back to a single visual clip
effect/style may attach to the wrong target
```

The visible user failure is:

```text
User: change this square to rounded corners
Bad result: a new rounded square is inserted on top of the old square

User: move this image
Bad result: motion is applied to a different selected clip

User: update this video mask
Bad result: a new video/image layer or metadata-only success is produced

User: animate the text I just edited
Bad result: animation targets another text or a duplicated text
```

This phase must make those outcomes structurally impossible for supported paths.

## 4. Reference Lessons

### 4.1 HyperFrames Lesson

HyperFrames is HTML-based, but ReFusion must not copy HTML as runtime truth.
The relevant lesson is target identity:

```text
element id / selector / component boundary -> same DOM node -> updated styles,
props, animation bindings, and timeline targets
```

Professional behavior:

- a style change targets an existing element;
- an animation targets an existing element selector;
- a component/block has a stable registry identity;
- a registry item is discovered and applied through a declared contract;
- an update does not silently create a new element when the selector is missing.

ReFusion-native translation:

```text
remoteLayerId / targetLayerId / clipId / localLayerId
-> UniversalLayerTarget
-> same timeline node or editable element
-> update existing layer/property/channel/effect
```

### 4.2 Remotion Lesson

Remotion is React/frame-based, but ReFusion must not copy React as runtime truth.
The relevant lesson is component identity plus props:

```text
same component identity + changed props + current frame -> new pixels
```

Professional behavior:

- a component is not recreated randomly for a prop update;
- animation is derived from stable component identity and frame;
- `Sequence` boundaries map to timeline identity;
- props update the same component instance path;
- duplicate component creation requires explicit insert intent.

ReFusion-native translation:

```text
same layer target + changed properties + current timeline time
-> evaluated visual program
```

### 4.3 ReFusion Rule

ReFusion must use native Flutter/domain/timeline models as truth:

```text
UniversalLayerTarget
UniversalLayerApplyPlanner
Canonical SceneCommand
Master Timeline Graph
MotionPropertyChannelModel
EffectInstance
Renderer/export conformance
```

HyperFrames and Remotion are architecture references only.

## 5. Current ReFusion Evidence To Audit

The implementation agent must confirm exact line numbers before coding, but the
current known areas are:

```text
lib/features/editor/presentation/screens/fusionx_clean_ui_screen.dart
```

Known areas to inspect:

- remote layer dispatch around `_applyRemoteLayerIfNeeded`;
- text apply path around `_applyRemoteTextLayerIfNeeded`;
- solid/background apply path around `_applyRemoteSolidLayerIfNeeded`;
- timeline clip mutation path around `_applyRemoteTimelineClipMutationFromLayerIfNeeded`;
- timeline style mutation path around `_applyRemoteTimelineClipStyleMutation`;
- motion apply path around `_applyRemoteMotionChannel`;
- layer/clip lookup around `_mcpTimelineClipIdForRemoteLayer`;
- remote identity helpers around `_mcpRemoteElementContextByLayerId`;
- representation helpers around `_isMcpRemoteLayerRepresentedLocally`;
- signature/short-circuit maps such as `_appliedMcpTextLayerSignatures`,
  `_appliedMcpSolidLayerIds`, and `_appliedMcpMotionChannelSignatures`.

Known services to inspect:

```text
lib/features/editor/presentation/services/mcp_text_layer_resolution.dart
lib/features/editor/presentation/services/mcp_text_runtime_update_planner.dart
lib/features/editor/presentation/services/mcp_scene_command_dispatcher.dart
lib/features/editor/presentation/services/professional_scene_apply_engine.dart
lib/features/editor/presentation/services/professional_scene_apply_proof_evaluator.dart
lib/features/editor/presentation/services/refusion_mcp_cloud_bridge.dart
```

Known tests to preserve:

```text
test/presentation_services/mcp_text_layer_resolution_test.dart
test/presentation_services/mcp_text_runtime_update_identity_test.dart
test/mcp/refusion_mcp_mvp_toolkit_test.dart
```

## 6. Scope

This phase covers identity/update behavior for existing supported layer families:

```text
text
shape
solid/background
image
video
timeline clip visual layers
motion channels on layer targets
effect/style mutations on layer targets
```

This phase covers command surfaces:

```text
MCP runtime apply
MCP cloud bridge command normalization
SceneCommand dispatcher planning
professional scene apply proof
read-only discovery contracts if they expose update support
```

This phase does not create new creative capabilities.

## 7. Explicit Non-Scope

Do not implement any of these in this phase:

```text
new visual effects
new animation presets
new templates
new shape packs
new media renderer
new export renderer
new Live Scrub path
new Stage5 path
new external HyperFrames/Remotion runtime
new HTML/React execution bridge
```

Protected paths:

```text
Stage5TimelineScrubPlatformView
Stage5NativeScrubEngine
Stage5SurfaceScrubDecoder
Stage5ScrubOverlayTextureView
Stage5PreviewPlatformView
Flutter Live Scrub handoff paths
```

If any required fix appears to need a protected path, stop and ask for explicit
approval before coding.

## 8. Required Architecture

### 8.1 Universal Layer Target Model

Add a universal model that represents the result of resolving a remote or local
layer target.

Suggested file:

```text
lib/features/editor/presentation/services/mcp_universal_layer_identity.dart
```

Required model:

```text
UniversalLayerTarget
```

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
solidLayer
imageClip
videoClip
timelineClip
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
singleVisualClipFallback
none
```

Strict rule:

```text
singleVisualClipFallback is allowed only for explicit insert/bootstrap behavior,
never for explicit update/motion/effect/style mutation intent.
```

### 8.2 Universal Identity Resolver

Add a pure resolver service:

```text
UniversalMcpLayerIdentityResolver
```

It must accept:

```text
remote layer payload
operation hint
available text contexts
available element contexts
available timeline clips
remote media layer clip map
remote layer kind hints
selected clip context
strict mode flag
```

It must extract candidate ids from all known locations:

```text
remoteLayer.id
remoteLayer.remoteLayerId
remoteLayer.layerId
remoteLayer.targetLayerId
remoteLayer.requestedLayerId
remoteLayer.localLayerId
remoteLayer.clipId
payload.remoteLayerId
payload.layerId
payload.targetLayerId
payload.requestedLayerId
payload.localLayerId
payload.clipId
payload.payload.*
updates.*
updates.payload.*
animation.*
motion.*
effect.*
style.*
metadata.mcp.remoteLayerId
metadata.mcp.remoteLayerAliases
```

It must return one of:

```text
resolvedSingle
resolvedAmbiguous
missingTarget
unsupportedTargetKind
blockedUnsafeFallback
```

It must not mutate UI state.

### 8.3 Universal Apply Intent Classifier

Add a pure classifier:

```text
UniversalLayerApplyIntentClassifier
```

It must classify each incoming payload as:

```text
insert
update
styleMutation
transformMutation
effectMutation
motionMutation
delete
unknown
```

Hard rules:

```text
operation contains update_layer -> update
operation contains update_* -> update
payload has targetLayerId and updates -> update
payload has style/mask/border/glow/cornerRadius -> styleMutation
payload has transform/position/scale/rotation/opacity -> transformMutation
payload has effect/effects -> effectMutation
payload has motion/animation/keyframes -> motionMutation
insert_layer with targetLayerId and mutation fields -> not insert
```

### 8.4 Universal Update Planner

Add a pure planner:

```text
UniversalLayerRuntimeUpdatePlanner
```

Required decision values:

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

Required planner inputs:

```text
remoteLayerId
operation
classifiedIntent
resolvedTarget
payloadSignature
previousPayloadSignature
existingLayerCount
strictMode
```

Required planner output:

```text
UniversalLayerApplyPlan
```

Required fields:

```text
decision
remoteLayerId
canonicalTargetId
targetKind
targetFamily
shouldCreateLayer
shouldUpdateLayer
shouldApplyStyle
shouldApplyTransform
shouldApplyEffect
shouldApplyMotion
shouldRecordSignature
shouldFailClosed
reason
blockers
diagnostic
```

Hard rule:

```text
Any update/motion/effect/style/transform mutation with unresolved or ambiguous
target must block. It must not insert.
```

### 8.5 Universal Apply Diagnostic

Every runtime apply attempt must emit a diagnostic object in tests and debug
logs.

Required model:

```text
UniversalLayerApplyDiagnostic
```

Required fields:

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

No apply path may claim success from metadata writes alone.

## 9. Required Behavior By Layer Family

### 9.1 Text

Text already has a hardened slice. This phase must wrap or adapt it into the
universal model without regressing it.

Required behavior:

```text
insert text -> creates one text layer
update same text -> updates same text element
motion same text -> targets same text element
duplicate identical payload -> skip, not insert
update unresolved text -> block, not insert
```

Decision:

```text
wrap existing PNCLE-05B text planner into universal identity contract
```

### 9.2 Shape

Shape update must not create a new shape when the user asked to change the
existing shape.

Required behavior:

```text
insert shape -> creates one shape layer/element
update rounded corners -> updates same shape target
update fill/stroke/border -> updates same shape target
update mask/glow/shadow -> updates same shape target or effect instance
motion shape -> targets same shape target
update unresolved shape -> block, not insert
ambiguous two shapes with no target -> block, not insert
```

Example:

```text
User: make the square rounded
Expected: same shape gets cornerRadius/border radius update
Forbidden: new rounded rectangle appears on top
```

### 9.3 Solid / Background

Solid/background must stop relying on duplicate short-circuit only.

Required behavior:

```text
insert background -> creates or binds the intended background target
update background color -> updates same target
update gradient/style -> updates same target if supported
duplicate identical payload -> skip
changed payload -> update, not skip
unresolved update -> block
```

### 9.4 Image

Image updates must target the same media clip or editable image layer.

Required behavior:

```text
insert image -> creates one image clip/layer
update crop/fit/position/scale/rotation/opacity -> updates same target
update mask/border/glow/shadow -> updates same target or effect instance
motion image -> targets same image clip/layer
unresolved update -> block
ambiguous image target -> block
```

### 9.5 Video

Video updates must target the same video clip or editable video layer.

Required behavior:

```text
insert video -> creates one video clip/layer
update transform/crop/mask/style -> updates same video target
motion video -> targets same video target
effect video -> creates/updates effect instance on same target
unresolved update -> block
ambiguous video target -> block
```

Do not touch native playback, Stage5, Live Scrub, or export renderer paths in
this phase.

### 9.6 Motion Channels

Motion must use the same resolved target as the layer update.

Required behavior:

```text
motion with explicit target -> resolve exact target
motion after update -> same canonicalTargetId
motion unresolved -> block
motion ambiguous -> block
motion cannot fall back to selected clip when explicit target is missing
```

Forbidden:

```text
fallbackToSingleVisualClip for explicit update/motion/effect mutation
```

Allowed:

```text
fallbackToSingleVisualClip only for safe legacy bootstrap when no mutation
intent exists and strict mode permits compatibility
```

### 9.7 Effects And Style Mutations

Effects and styles must attach to existing targets.

Required behavior:

```text
apply effect with target -> create/update EffectInstance on same target
update effect with target -> update same EffectInstance when identity exists
style mutation with target -> update target style/effect stack
unresolved effect update -> block
metadata-only effect success -> forbidden
```

## 10. Strict Execution Slices

### PNCLE-05C-00: Pre-Build Evaluation Report

Before coding, create a report:

```text
docs/prebuild/PNCLE-05C.UNIVERSAL-LAYER-UPDATE-IDENTITY-HARDENING.prebuild.md
```

Required report sections:

```text
current ReFusion code inventory
HyperFrames comparison
Remotion comparison
gap list
decision table
files to touch
files explicitly not to touch
test plan
rollback plan
acceptance criteria
```

Decision table must include:

```text
text -> wrap
shape -> upgrade
solid/background -> upgrade
image -> upgrade
video -> upgrade
motion -> upgrade
effects/style -> upgrade
Live Scrub/Stage5 -> block
HyperFrames runtime embed -> block
Remotion runtime embed -> block
```

Checkpoint:

```text
checkpoint: document pncle-05c prebuild evaluation
```

### PNCLE-05C-01: Universal Identity Models And Resolver

Implement only pure models and resolver.

Allowed files:

```text
lib/features/editor/presentation/services/mcp_universal_layer_identity.dart
test/presentation_services/mcp_universal_layer_identity_test.dart
```

Acceptance:

```text
resolver extracts all supported id aliases
resolver resolves text/shape/solid/image/video/timeline clip targets
resolver reports ambiguous targets
resolver reports missing targets
resolver blocks unsafe fallback for mutation intent
no UI behavior changes
no Live Scrub/Stage5 changes
```

Verification:

```bash
flutter test test/presentation_services/mcp_universal_layer_identity_test.dart
```

Checkpoint:

```text
checkpoint: add universal mcp layer identity resolver
```

### PNCLE-05C-02: Universal Intent Classifier And Planner

Implement pure classifier and planner.

Allowed files:

```text
lib/features/editor/presentation/services/mcp_universal_layer_apply_planner.dart
test/presentation_services/mcp_universal_layer_apply_planner_test.dart
```

Acceptance:

```text
insert remains insert only when no update/mutation target exists
insert_layer with update fields is not treated as insert
update/motion/effect/style unresolved target blocks
duplicate identical payload skips
changed payload updates existing target
planner emits complete diagnostics
```

Verification:

```bash
flutter test test/presentation_services/mcp_universal_layer_apply_planner_test.dart
```

Checkpoint:

```text
checkpoint: add universal mcp layer apply planner
```

### PNCLE-05C-03: Text Adapter Migration

Adapt the existing text-specific resolver/planner to the universal contract.

Allowed files:

```text
lib/features/editor/presentation/services/mcp_text_layer_resolution.dart
lib/features/editor/presentation/services/mcp_text_runtime_update_planner.dart
lib/features/editor/presentation/screens/fusionx_clean_ui_screen.dart
test/presentation_services/mcp_text_layer_resolution_test.dart
test/presentation_services/mcp_text_runtime_update_identity_test.dart
```

Rules:

```text
preserve PNCLE-05B behavior
do not loosen text fail-closed behavior
do not reintroduce insert-as-update
do not change visual renderer
```

Verification:

```bash
flutter test \
  test/presentation_services/mcp_text_layer_resolution_test.dart \
  test/presentation_services/mcp_text_runtime_update_identity_test.dart
```

Checkpoint:

```text
checkpoint: route mcp text identity through universal planner
```

### PNCLE-05C-04: Shape And Solid/Background Update Wiring

Wire shape and solid/background mutation paths to the universal planner.

Allowed areas:

```text
_applyRemoteSolidLayerIfNeeded
_applyRemoteTimelineClipMutationFromLayerIfNeeded
_applyRemoteTimelineClipStyleMutation
shape/background related helper functions
```

Required tests:

```text
insert shape creates one target
update shape cornerRadius keeps layer count stable
update shape fill/stroke keeps layer count stable
update solid/background color changes same target
changed solid payload updates instead of short-circuiting
ambiguous shape update blocks
unresolved shape update blocks
```

Forbidden:

```text
new shape capability
new renderer path
metadata-only success
fallback insert for update intent
```

Checkpoint:

```text
checkpoint: harden mcp shape and background update identity
```

### PNCLE-05C-05: Image And Video Update Wiring

Wire image/video timeline clip mutation paths to the universal planner.

Allowed areas:

```text
remote media layer clip map
timeline clip mutation path
timeline clip style mutation path
media/image/video transform and crop mutation helpers
```

Required tests:

```text
insert image creates one target
update image crop/fit keeps layer count stable
update image transform keeps layer count stable
insert video creates one target
update video mask/style keeps layer count stable
update video transform keeps layer count stable
ambiguous media update blocks
unresolved media update blocks
```

Forbidden:

```text
native playback changes
Stage5 changes
Live Scrub changes
export changes
metadata-only success
```

Checkpoint:

```text
checkpoint: harden mcp media update identity
```

### PNCLE-05C-06: Motion/Effect Target Binding

Route motion/effect/style target binding through the universal resolved target.

Allowed areas:

```text
_applyRemoteMotionChannel
_applyRemoteMotionChannelToTimelineClip
effect/style mutation helpers
```

Required behavior:

```text
motion after text update targets same text
motion after shape update targets same shape
motion after image update targets same image
motion after video update targets same video
effect update targets existing layer/effect instance
unresolved explicit motion blocks
ambiguous explicit motion blocks
unsafe fallback is blocked for mutation intent
```

Checkpoint:

```text
checkpoint: bind mcp motion and effects to universal layer identity
```

### PNCLE-05C-07: Command Taxonomy Guard

Add guard coverage so legacy command shapes cannot bypass the planner.

Allowed files:

```text
lib/features/editor/presentation/services/mcp_scene_command_dispatcher.dart
lib/features/editor/presentation/services/professional_scene_apply_engine.dart
lib/features/editor/presentation/services/professional_scene_apply_proof_evaluator.dart
test/mcp/refusion_mcp_mvp_toolkit_test.dart
additional focused dispatcher/apply proof tests
```

Required behavior:

```text
insert_layer + targetLayerId + updates -> update/mutation plan
insert_layer + motion/animation -> motion plan
update_layer with missing target -> fail closed
update_layer can never create a duplicate node
appApplied cannot be true from database/metadata write only
```

Checkpoint:

```text
checkpoint: enforce universal layer command taxonomy guard
```

### PNCLE-05C-08: E2E Visual Proof

Run a real-device or equivalent app-level E2E pass.

Required scenarios:

```text
1) insert text -> update same text -> apply motion
2) insert shape -> update rounded corners -> apply motion
3) insert shape -> update fill/border/glow
4) insert image -> update crop/scale/position
5) insert video -> update mask/position/scale
6) ambiguous two similar shapes -> update request blocks
7) ambiguous two similar text layers -> update request blocks
8) repeated same update payload -> no duplicate, no extra motion channel
```

Required proof for each scenario:

```text
before layer count
after layer count
target id before
target id after
motion/effect target id
diagnostic decision
screenshot or UI dump if available
```

Checkpoint:

```text
checkpoint: verify universal layer update identity e2e
```

## 11. Acceptance Gate

The phase is complete only when all of these are true:

```text
text update duplicate count = 0
shape update duplicate count = 0
solid/background update duplicate count = 0
image update duplicate count = 0
video update duplicate count = 0
unresolved update fallback insert count = 0
ambiguous update fallback insert count = 0
explicit motion unsafe fallback count = 0
metadata-only success count = 0
insert used as update count = 0
update command duplicate creation count = 0
```

Required tests:

```text
flutter test test/presentation_services/mcp_universal_layer_identity_test.dart
flutter test test/presentation_services/mcp_universal_layer_apply_planner_test.dart
flutter test test/presentation_services/mcp_text_layer_resolution_test.dart
flutter test test/presentation_services/mcp_text_runtime_update_identity_test.dart
flutter test test/mcp/refusion_mcp_mvp_toolkit_test.dart
```

If a broad test suite is too slow, each checkpoint must at minimum run the
smallest focused test for that slice plus the previously affected text tests.

## 12. Definition Of Ready

Do not start implementation unless all are complete:

```text
pre-build report exists
current ReFusion identity paths audited
HyperFrames target identity comparison completed
Remotion component identity comparison completed
decision table completed
files to touch listed
protected files listed as blocked
test matrix listed
rollback command listed
owner/reviewer/QA owner listed
```

## 13. Definition Of Done

Do not close the phase unless all are complete:

```text
pre-build report attached to checkpoint
universal resolver implemented and tested
universal planner implemented and tested
text adapter still passes PNCLE-05B tests
shape/background update identity passes
image/video update identity passes
motion/effect target binding passes
command taxonomy guard passes
E2E visual proof completed or explicitly marked blocked with reason
no Live Scrub/Stage5 protected files touched
all checkpoints pushed
rollback command reported for every checkpoint
```

## 14. Stop List

Do not:

```text
use insert as update
create a duplicate node for update intent
apply motion to selected clip when explicit target cannot resolve
claim effect success from metadata only
claim appApplied from database write only
add MCP-only behavior
add UI-only behavior
embed HyperFrames runtime
embed Remotion runtime
change Stage5
change Live Scrub
add new capabilities during this phase
```

## 15. Rollback Strategy

Each slice must be checkpointed separately.

Rollback pattern:

```bash
git -C /Users/mx/Documents/ReFusionXx/sources/ui/fusionx-clean-ui-2 revert <checkpoint_commit>
```

If a later slice depends on earlier model files, revert in reverse checkpoint
order.

## 16. Final Expected Workflow

After this phase, MCP/manual/script behavior must follow one identity pipeline:

```text
incoming command or remote layer payload
-> classify intent
-> extract candidate ids
-> resolve UniversalLayerTarget
-> build UniversalLayerApplyPlan
-> apply to existing target or create new target only for true insert
-> emit UniversalLayerApplyDiagnostic
-> verify layer counts and target ids
```

Professional user result:

```text
"Change this square to rounded corners"
-> same square updates

"Move this image to the left"
-> same image moves

"Add glow to this video"
-> same video receives glow/effect instance if supported

"Animate the text I just edited"
-> same text receives motion channels

"Update this layer" with no resolvable target
-> blocked with diagnostic, not duplicated
```

