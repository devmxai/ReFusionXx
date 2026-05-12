# Professional MCP Scene Truth Runtime Plan

Status: ready for implementation
Package: `com.refusion.app`
Date: 2026-05-12
Short name: `PMSTR`
Primary goal: make every ChatGPT / Claude / Codex MCP command become a real,
isolated, rendered editor change inside the exact open ReFusionXx composition:
backgrounds become background layers, text becomes text layers, shapes become
shape layers, durations affect the timeline, animations become keyframe
channels, and nothing leaks between projects or compositions.

## 1. Executive Decision

ReFusionXx must stop treating MCP edits as loose cloud rows.

The new rule is:

```text
MCP command -> canonical editor command -> local MotionProject mutation
            -> timeline layer/keyframe truth -> canvas render truth
            -> app-applied acknowledgement
```

An MCP write is not successful until the open app confirms that it applied the
command to the active local project and rendered the result.

This plan supersedes the partial behavior where:

- a text row may exist in Supabase but not render,
- an animation payload may be stored as a solid layer,
- the latest solid row may silently overwrite the background,
- every new composition may feel like it is continuing one global project,
- a command may claim success without appearing on the user's device.

## 2. Current Failure Analysis

The latest live issue proves three gaps.

Two independent code-path reviews confirmed that the issue is not only one bad
animation row. It is a truth-boundary problem across these areas:

- Create Composition still risks behaving like a singleton editor state instead
  of a real project/composition identity.
- Compatibility defaults such as `default`, `active`, `comp_1`,
  `motion-project`, and `scene-main` can still leak into production write paths.
- Cloud command success can be reported after database write, before the open
  app proves local apply.
- `get_layers` is not enough for a motion editor; the cloud read surface must
  include commands, keyframes, motion channels, and app apply receipts.
- DB layer kinds, Edge Function inference, and local Motion layer kinds must be
  aligned. The backend must not emit a layer kind that the database or app
  cannot truthfully apply.
- Timeline tracks, scene clips, channels, playhead, and selection must become
  composition-scoped state, not global state shared by whatever composition was
  opened last.

### 2.1 Animation Stored As Solid

The agent requested a spring animation and the backend stored a row like:

```json
{
  "layer_kind": "solid",
  "payload": {
    "color": "#FFFFFF",
    "operation": "animate_layer",
    "layerId": "text-layer-id",
    "animation": {
      "name": "spring_pop_up",
      "keyframes": [...]
    }
  }
}
```

That is wrong.

`animate_layer` is not a solid layer. It is a motion command targeting an
existing layer/element. Storing it as `solid` lets the background sync logic
misread it as a white background.

### 2.2 Background Changed Without User Intent

The app currently has a convenience path that extracts `latestSolidColorHex`
from remote layers. If a newer row is classified as `solid`, its color wins,
even when the user never requested a background update.

This violates editor truth.

Background may change only through explicit commands:

```text
background.set_solid
background.set_gradient
layer.insert(kind=background)
layer.update(target=background)
```

Animation, transform, text, and shape commands must never change background.

### 2.3 Cloud Rows Are Not Full Editor Truth

The app can read remote layers, but the local apply bridge is incomplete:

- text insert is partially applied,
- shape insert is not complete,
- background duration is not consistently timeline truth,
- animation/keyframes are not materialized into `MotionPropertyChannelModel`,
- command apply is not acknowledged back as `appApplied=true`,
- active project/composition isolation is not enforced strongly enough.

### 2.4 Motion Tool Surface Gap

The current cloud tool surface is still too narrow for a motion editor. A
professional agent cannot be expected to animate through `insert_layer` or a
generic SceneProgram fallback.

Required cloud tools must exist as first-class MCP tools:

```text
refusion.apply_motion_patch
refusion.apply_animation_recipe
refusion.apply_keyframes
refusion.keyframe_edit
refusion.set_element_transform
refusion.get_keyframes
refusion.get_motion_channels
```

The current issue has two possible manifestations, and the implementation must
handle both:

```text
1. Future-correct path:
   Agent calls an official motion tool -> backend writes motion command/channel.

2. Legacy compatibility path:
   Agent sends operation=animate_layer through insert_layer -> backend or app
   must treat it as animation, never as solid/background.
```

Important nuance: the latest broken row proves that keyframes can already reach
Supabase inside `payload.animation`. The failure is that the payload is typed as
`solid` and the app does not lower it into local motion channels. The fix must
therefore include both official motion tools and legacy `animate_layer`
compatibility.

## 3. Non-Negotiable Product Workflow

The final workflow must work exactly like this.

### 3.1 New Composition

```text
User taps Create Composition
User chooses Story
App creates a new Project ID
App creates a new Composition ID
App creates an empty timeline for that composition
App writes active context:
  userId/deviceId/appSessionId/projectId/compositionId/revision/playhead
App shows the empty canvas and timeline
```

No new composition may reuse a previous project's timeline state unless the
user intentionally opens that project from Recent Projects.

### 3.2 Background

User asks:

```text
Create a blue background for 30 seconds.
```

Required result:

```text
MCP command: background.set_solid or layer.insert(kind=background)
Timeline: one Background layer, duration = 30000ms
Canvas: blue background visible
Project: revision increments
App: acknowledges appApplied=true
```

### 3.3 Text

User asks:

```text
Add text "Welcome" above the background.
```

Required result:

```text
MCP command: text.insert or layer.insert(kind=text)
Timeline: one Text layer above background
Canvas: text visible at requested/default position
Text properties: content, color, font size, alignment, opacity, frame
Project: revision increments
App: acknowledges appApplied=true
```

### 3.4 Text Animation

User asks:

```text
Animate the text with a spring pop-up.
```

Required result:

```text
MCP command: animation.apply_recipe or keyframe.batch_apply
Target: existing text layer/element
Timeline: keyframe lane appears in Keyframe Motion Timeline
Canvas/preview: text scales/opacity animates during playback
Background: unchanged
Project: revision increments
App: acknowledges appApplied=true
```

### 3.5 Shape

User asks:

```text
Add a rounded rectangle shape behind the text.
```

Required result:

```text
MCP command: shape.insert
Timeline: Shape layer appears between background and text
Canvas: rounded rectangle visible
Properties: fill, stroke, radius, opacity, transform
Project: revision increments
App: acknowledges appApplied=true
```

## 4. Architecture Principle

There must be one command truth and one render truth.

### 4.1 Command Truth

Every MCP mutation must produce a canonical command record:

```json
{
  "commandId": "uuid",
  "commandType": "animation.apply_recipe",
  "projectId": "uuid",
  "compositionId": "uuid",
  "target": {
    "layerId": "uuid",
    "elementId": "uuid"
  },
  "revisionBefore": 8,
  "revisionAfter": 9,
  "idempotencyKey": "agent-provided-or-generated",
  "payload": {
    "recipe": "$motion.scaleInBounce",
    "durationMs": 650
  },
  "status": "accepted"
}
```

### 4.2 Render Truth

The app must convert commands into local runtime objects:

```text
background.set_solid   -> MotionLayerModel(kind=background/shape)
text.insert            -> MotionLayerModel + MotionElementModel(text)
shape.insert           -> MotionLayerModel + MotionElementModel(shape)
transform.patch        -> MotionPropertyAssignment or keyframe channels
animation.apply_recipe -> MotionPropertyChannelModel keyframes
keyframe.batch_apply   -> MotionPropertyChannelModel keyframes
```

The renderer and preview must consume the same local `MotionProjectModel` and
`MotionPropertyChannelModel` truth. No separate visual-only shortcut may exist.

## 5. Canonical Command Taxonomy

The Edge Function and Flutter app must share this command taxonomy.

```text
project.create
project.open
project.close

composition.create
composition.open
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
animation.apply_keyframes
animation.remove

scene_program.apply
director_plan.compile_and_apply

effect.apply
effect.update
effect.remove
```

Any command outside this list must fail closed with a clear error.

## 6. Required Data Contracts

### 6.1 Project

Every project must have:

```text
projectId
ownerId
name
createdAt
updatedAt
lastOpenedAt
revision
```

### 6.2 Composition

Every composition must have:

```text
compositionId
projectId
canvasPreset
width
height
fps
durationMs
createdAt
updatedAt
revision
```

### 6.3 Layer

Every layer must have:

```text
layerId
projectId
compositionId
kind
name
startMs
durationMs
zIndex
payload
createdAt
updatedAt
```

Allowed layer kinds:

```text
background
solid
text
shape
image
video
audio
adjustment
null
```

Motion commands must not be stored as layers unless they create an actual
timeline-visible layer.

### 6.4 Motion Command / Channel

Motion must be stored separately from visual layers:

```text
motionCommandId
projectId
compositionId
targetLayerId
targetElementId
commandType
recipeId
channels[]
keyframes[]
durationMs
createdAt
updatedAt
```

At apply time, these become local `MotionPropertyChannelModel` objects.

### 6.5 Motion Channel Storage

The backend must persist motion separately from visual layer rows.

Required table shape:

```text
refusion_motion_channels
id
ownerId
projectId
compositionId
targetLayerId
targetElementId
targetProperty
motionRecipe
keyframes
status
createdAt
updatedAt
```

Allowed `targetProperty` values:

```text
position
positionX
positionY
scale
scaleX
scaleY
rotation
opacity
blur
compound
```

Realtime must publish this table or the command table that creates equivalent
motion channels. The app must be able to reconstruct the same local
`MotionPropertyChannelModel` objects from the backend truth.

### 6.6 Motion Recipe Contract

Motion recipes are allowed only through an explicit registry.

Initial required recipes:

```text
$motion.scaleIn
$motion.scaleInBounce
$motion.springPopUp
$motion.slideInFromLeft
$motion.slideInFromRight
$motion.slideInFromTop
$motion.slideInFromBottom
$motion.fadeIn
$motion.fadeOut
$motion.rotateIn
```

Unknown recipes fail closed with:

```text
UNKNOWN_MOTION_RECIPE
```

No agent may invent ad hoc easing or recipe names unless the payload is explicit
keyframes accepted by `apply_keyframes`.

## 7. Phase Plan

### PMSTR-00 - Failure Lockdown Fixtures

Purpose: capture current failures before fixing them.

Add fixtures/tests for:

- `animate_layer` must not become `solid`.
- animation command must not change background.
- text insert appears in canvas and timeline.
- background duration 30000ms appears in timeline.
- shape insert appears in canvas and timeline.
- new composition gets a new project/composition context.
- wrong composition command is rejected.
- production grep gate for forbidden write fallbacks:
  `default`, `active`, `comp_1`, `motion-project`, `scene-main`.
- backend layer-kind parity:
  Edge Function cannot emit a layer kind rejected by DB or app mapping.
- official motion surface:
  `apply_motion_patch`, `apply_animation_recipe`, `apply_keyframes`,
  `keyframe_edit`, `set_element_transform`, `get_keyframes`, and
  `get_motion_channels` are present in `tools/list`.
- legacy animation row compatibility:
  a row with `operation=animate_layer` and `payload.animation.keyframes` is
  ignored as background and applied as animation when target mapping exists.

Exit gate:

```text
The tests fail on the current implementation for the known reasons.
```

### PMSTR-01 - Project And Composition Identity Truth

Purpose: make every created composition isolated and addressable.

Implementation requirements:

- `Create Composition` creates a fresh project/composition pair unless user
  explicitly opens an existing Recent Project.
- Active context must include projectId and compositionId.
- MCP pairing code must bind to the exact active project/composition.
- Recent Projects must list real projects by ID, not a global scratch state.
- Opening a recent project restores only that project's timeline and layers.

Exit gate:

```text
Create Project A, add red background.
Create Project B, add blue background.
Open A -> red only.
Open B -> blue only.
No cross-project leakage.
```

### PMSTR-02 - Canonical Command Envelope

Purpose: make command intent explicit and stop guessing from arbitrary payloads.

Implementation requirements:

- Every MCP mutation writes a canonical command record.
- Commands include projectId, compositionId, commandType, target, payload,
  revisionBefore, revisionAfter, idempotencyKey.
- The backend derives target context from `agentSessionToken`, not from freeform
  user text.
- Unknown commands fail closed.
- Command status must be split into explicit states:

```text
cloud_committed
app_pending
app_applied
app_failed
```

`cloud_committed` is not final success. The agent may report final success only
after `app_applied`.

Exit gate:

```text
Every write has a command record that describes the intended editor mutation.
```

### PMSTR-03 - Backend Operation Taxonomy Repair

Purpose: stop classifying motion/update commands as visual layers.

Implementation requirements:

- Align the noun taxonomy across DB, Edge Function, and local app:

```text
solid
background
text
shape
image
video
audio
adjustment
scene_program
```

If the DB keeps `media` as a generic kind, payload must include a required
`mediaType`. The Edge Function must not emit `image` or `video` unless the DB
and app can accept them.
- `inferLayerKind()` must check operation intent before color fallback.
- `operation=animate_layer` maps to `animation.apply_keyframes`.
- `operation=update_layer` maps to `layer.update` or a specific command type.
- `operation=set_background` maps to `background.set_solid`.
- `animation`, `keyframes`, `motionRecipe`, or `recipe` payloads must never
  default to `solid`.
- Insert-layer fallback to `solid` is allowed only when the command truly
  creates a solid/background layer.

Exit gate:

```text
An animation payload is stored as a motion command, not a solid layer.
```

### PMSTR-04 - Official MCP Tool Surface

Purpose: expose real editor capabilities to agents.

Required tools:

```text
refusion.attach_pairing_code
refusion.get_active_context
refusion.get_project_state
refusion.create_composition
refusion.open_project
refusion.list_recent_projects

refusion.insert_layer
refusion.update_layer
refusion.delete_layer
refusion.set_background
refusion.insert_text
refusion.update_text
refusion.insert_shape
refusion.update_shape

refusion.set_transform
refusion.set_element_transform
refusion.apply_motion_patch
refusion.apply_animation_recipe
refusion.apply_keyframes
refusion.keyframe_edit
refusion.get_keyframes
refusion.get_motion_channels

refusion.apply_scene_program
refusion.wait_for_apply
```

Implementation requirements:

- `apply_motion_patch` accepts a target layer/element and either a registered
  recipe or an explicit channel patch.
- `apply_animation_recipe` accepts only known recipes and expands them into
  canonical keyframes.
- `apply_keyframes` writes explicit keyframes for one or more target properties.
- `keyframe_edit` supports insert/update/delete for existing motion channels.
- `set_element_transform` writes static transform values or delegates to
  keyframe tools when animation data is present.
- `get_keyframes` and `get_motion_channels` return enough data for the app and
  the agent to reconstruct animation truth.
- Tool schemas must document target resolution, units, timeline time base,
  accepted properties, and expected revision.

Exit gate:

```text
tools/list advertises all production-safe editing tools with schemas.
No agent needs to misuse insert_layer to animate an element.
```

### PMSTR-05 - Background As Real Timeline Layer

Purpose: make background deterministic and timeline-visible.

Implementation requirements:

- Background insert creates/updates a real background/solid layer.
- Background duration comes from command duration.
- Background zIndex is below content.
- Background update targets an existing background layer when requested.
- The old `latestSolidColorHex` auto-apply path is removed or restricted to
  explicit background commands.
- Non-background rows cannot change background.
- Polling recovery may read background rows, but it must require explicit
  background command authority. It must not use "newest solid wins" as a global
  mutation rule.
- `operation=animate_layer`, `operation=transform`, `operation=keyframe_edit`,
  and any row containing `animation`, `keyframes`, `motionRecipe`, or `recipe`
  are forbidden from background color selection.

Exit gate:

```text
Ask for 30s blue background.
Timeline shows background layer duration = 30000ms.
Ask to animate text.
Background remains blue.
```

### PMSTR-06 - Text Layer Truth

Purpose: make MCP text fully real and editable.

Implementation requirements:

- Text insert creates a text layer and text element.
- Text layer has visible range, zIndex, content, fontSize, color, opacity,
  alignment, frame, fit policy.
- Text update changes existing text, not a new duplicate unless requested.
- Remote layer ID maps to local layer/element metadata.
- Text appears in timeline and canvas.

Exit gate:

```text
Ask: add text "Welcome" at center, font 96, black.
Canvas shows text, timeline shows Text layer, project state stores mapping.
```

### PMSTR-07 - Shape Layer Truth

Purpose: make shapes real editor layers.

Implementation requirements:

- Shape insert supports rectangle, rounded rectangle, ellipse, line.
- Shape style supports fill, stroke, strokeWidth, cornerRadius, opacity.
- Shape transform supports position, scale, rotation, anchor.
- Shape appears in timeline and canvas.
- Shape update targets existing layer/element.

Exit gate:

```text
Ask for rounded rectangle behind text.
Timeline shows Shape layer between background and text.
Canvas shows the shape with requested style.
```

### PMSTR-08 - Transform Command Truth

Purpose: make transform edits apply to any layer kind.

Implementation requirements:

- `set_transform` and `transform.patch` support text/shape/image/video.
- Transform values map to MotionPropertyAssignments for static values.
- Animated transforms map to MotionPropertyChannelModel.
- Canvas, handles, preview, and timeline use the same transform state.

Exit gate:

```text
Ask: move text to x=540 y=400, rotate 8 degrees.
Canvas updates; transform tool shows the same position/rotation.
```

### PMSTR-09 - Animation And Keyframe Truth

Purpose: make MCP animation visible and playable.

Implementation requirements:

- `apply_animation_recipe` expands recipes into channels.
- `apply_keyframes` writes explicit channels.
- App converts remote motion commands into `MotionPropertyChannelModel`.
- Backend stores official motion commands in `refusion_motion_channels` or an
  equivalent command table, not as visual layer rows.
- Supported properties: positionX, positionY, scaleX, scaleY, rotation,
  opacity, blur where supported.
- Remote absolute canvas coordinates convert to local centered coordinates.
- Keyframe times are clamped to the layer visible range.
- Existing remote bad rows with `operation=animate_layer` must be safely
  ignored as background and migrated/applied as animation when possible.
- The app must find the local target through remote layer metadata such as
  `mcp.remoteLayerId`, then map keyframes to the correct local element target.
- Recipe expansion must produce deterministic keyframes. For a spring pop-up,
  minimum required channels are scaleX, scaleY, and opacity. Optional y-position
  overshoot is allowed only if target coordinates are explicit.
- Playback, scrub, and keyframe timeline must consume the same channels.

Exit gate:

```text
Ask: animate text with spring pop-up.
Timeline shows scale/opacity keyframe lanes.
Playback shows pop-up animation.
Background unchanged.
```

### PMSTR-10 - Command Apply Dispatcher In Flutter

Purpose: centralize live apply instead of scattered snapshot heuristics.

Implementation requirements:

- Add `McpEditorCommandDispatcher`.
- Dispatcher receives command records and state snapshots.
- Dispatcher routes command types to local services:
  - background service
  - text service
  - shape service
  - transform service
  - keyframe service
  - scene program service
- Dispatcher is idempotent by commandId/idempotencyKey.
- Dispatcher rejects wrong project/composition.
- Dispatcher is the only path allowed to acknowledge `app_applied`.

Exit gate:

```text
All MCP live apply paths go through one dispatcher with diagnostics.
```

### PMSTR-11 - Supabase Realtime First, Polling Fallback Second

Purpose: make edits appear within one second.

Implementation requirements:

- Subscribe to project/composition command channel as the primary path.
- Subscribe to layer/motion changes only as recovery/state mirror.
- Polling fallback detects missed revisions.
- Realtime payload includes commandId and revisionAfter.
- App acknowledges command application.
- App tracks:

```text
cloudRevisionSeen
cloudRevisionApplied
appliedCommandIds
failedCommandIds
lastRealtimeAt
lastPollingRecoveryAt
```

Exit gate:

```text
MCP insert text -> visible on device <= 1s.
If realtime is disconnected, polling recovers <= 8s and logs recovery.
```

### PMSTR-12 - App-Applied Acknowledgement

Purpose: make backend success mean visible success.

Implementation requirements:

- App writes `appApplied=true` with commandId, revision, deviceId,
  appliedAt, diagnostics.
- `wait_for_apply(commandId)` blocks until app acknowledgement or timeout.
- Tool response distinguishes:
  - cloudAccepted
  - appReceived
  - appApplied
  - renderVerified when available
- Duplicate command IDs or idempotency keys return the original command/result
  and never create duplicate layers/keyframes.

Exit gate:

```text
Agent cannot claim final success until appApplied=true.
```

### PMSTR-13 - Duration And Timeline Authority

Purpose: make time precise and editable.

Implementation requirements:

- All layer durations use ms/ticks consistently.
- Background 30s means 30000ms visible range.
- Text/shape/media durations respect command duration or composition default.
- Composition duration expands when a new layer exceeds current duration,
  unless explicitly disabled.
- Timeline lanes display the same ranges used by renderer.

Exit gate:

```text
Ask for 30s background and 5s text.
Timeline lengths match exactly.
Playback/render respects those lengths.
```

### PMSTR-14 - SceneProgram And DirectorPlan Apply Truth

Purpose: make full scene scripts safe and deterministic.

Implementation requirements:

- SceneProgram apply runs through the same command dispatcher.
- SceneProgram cannot silently replace project/composition unless requested.
- Every generated element maps to real layers/elements/channels.
- Unsupported element/property fails with structured diagnostics.
- DirectorPlan compiles into canonical commands, not ad hoc rows.
- SceneProgram must not be used as an animation fallback when the user asked to
  animate an existing layer. That path must go through motion tools.

Exit gate:

```text
Apply a scene program with background, text, shape, and animation.
All pieces appear in timeline and canvas with no old-scene contamination.
```

### PMSTR-15 - Render And Preview Parity

Purpose: ensure what the agent builds is what the user sees.

Implementation requirements:

- Canvas preview, playback preview, timeline state, and export compile from
  the same MotionProject/channels.
- No separate MCP-only visual shortcuts.
- Animation appears during play, scrub, and render.
- Text, shape, and background are evaluated from the same runtime truth.

Exit gate:

```text
Screenshot at t=0, t=325ms, t=650ms matches expected spring animation state.
```

### PMSTR-16 - Diagnostics And User Feedback

Purpose: make failures visible and actionable.

Implementation requirements:

- Toast/log for every agent action:
  - accepted
  - applied
  - failed
  - ignored due wrong context
- Add an MCP diagnostics panel or equivalent developer-visible surface showing:
  last command type, cloud state, app apply state, target project/composition,
  target layer, realtime status, polling recovery status, and last failure.
- Diagnostic panel shows recent MCP commands.
- Each failure includes commandId, commandType, reason, and repair hint.
- Unsupported command never returns vague success.

Exit gate:

```text
If animation cannot apply, user sees why in-app within 1 second.
```

### PMSTR-17 - Migration And Cleanup Of Old Paths

Purpose: remove the paths that caused the current confusion.

Implementation requirements:

- Remove or restrict `latestSolidColorHex` as a broad state mutation path.
- Remove dev/default project targeting in production builds.
- Remove any "default session" fallback for write commands.
- Stop storing motion commands as layer rows.
- Add a compatibility reader for old broken rows:
  `layer_kind=solid` with `operation=animate_layer` must not mutate background.
  It may be migrated into motion command truth once, then marked applied.
- Keep backward-compatible read only where needed for old test data, but do
  not let it mutate the current editor incorrectly.

Exit gate:

```text
No MCP write path can mutate the open editor without a canonical command type.
```

### PMSTR-18 - End-To-End Acceptance Suite

Purpose: prove the product workflow.

Required tests:

```text
1. Create composition isolation
   A red project and B blue project never mix.

2. Background duration
   "Create 30s blue background" creates one 30000ms timeline layer.

3. Text insert
   Text layer appears above background, visible on canvas.

4. Shape insert
   Shape layer appears at requested z-order and renders.

5. Text animation
   Spring pop-up creates scale/opacity keyframes and plays.

6. Background stability
   Applying text animation never changes background color.

7. Wrong context rejection
   Command for another project/composition is rejected.

8. Realtime latency
   Visible apply <= 1 second with realtime, <= 8 seconds with polling fallback.

9. App acknowledgement
   `wait_for_apply` returns appApplied=true after visible mutation.

10. Render parity
   Canvas preview and playback/render evaluate the same state.

11. Forbidden fallback grep
    Production write paths do not depend on `default`, `active`, `comp_1`,
    `motion-project`, or `scene-main`.

12. Layer-kind parity
    Edge Function emitted layer kinds match DB constraints and Flutter mapping.

13. Official motion tool surface
    `tools/list` includes motion patch, animation recipe, keyframe edit,
    transform, and motion readback tools with schemas.

14. Legacy animation compatibility
    Existing bad rows with `operation=animate_layer` never select background
    color and are applied or ignored with diagnostics.
```

## 8. Implementation Order

The order is mandatory.

```text
1. PMSTR-00 failure fixtures
2. PMSTR-01 project/composition identity
3. PMSTR-02 canonical command envelope
4. PMSTR-03 backend taxonomy repair
5. PMSTR-04 official MCP tools
6. PMSTR-05 background truth
7. PMSTR-06 text truth
8. PMSTR-07 shape truth
9. PMSTR-08 transform truth
10. PMSTR-09 animation/keyframe truth
11. PMSTR-10 Flutter dispatcher
12. PMSTR-11 realtime + polling fallback
13. PMSTR-12 app acknowledgement
14. PMSTR-13 duration/timeline authority
15. PMSTR-14 scene/director apply
16. PMSTR-15 render parity
17. PMSTR-16 diagnostics
18. PMSTR-17 cleanup
19. PMSTR-18 acceptance suite
```

Do not start new visual scene experiments until PMSTR-05, PMSTR-06, and
PMSTR-09 pass. Otherwise the agent will keep writing data the renderer cannot
truthfully apply.

## 9. Stop List

Forbidden:

- Do not store `animate_layer` as `solid`.
- Do not let animation commands change background.
- Do not use `latest solid wins` as a general editor mutation rule.
- Do not leave motion tools implemented only in Dart; MCP must expose them in
  the Edge Function.
- Do not use SceneProgram as a fallback for animation of an existing layer.
- Do not let ChatGPT claim success without app acknowledgement.
- Do not accept write commands against `default` project/session.
- Do not let a command choose arbitrary projectId when an agentSessionToken is
  bound to another context.
- Do not add new UI experiments before command truth works.
- Do not touch Stage5 or Live Scrub internals for this plan.
- Do not apply SceneProgram as a destructive replace unless explicitly
  requested.
- Do not create duplicate layers on update commands.

## 10. Definition Of Done

This plan is complete only when this live test passes on a connected Android
device:

```text
1. Open app.
2. Create new Story composition.
3. Connect ChatGPT through pairing.
4. Ask: create a 30-second blue background.
   -> Background layer appears in timeline for 30 seconds.
   -> Canvas turns blue.
5. Ask: add text "Welcome" in white above it.
   -> Text layer appears above background.
   -> Canvas shows text.
6. Ask: add rounded rectangle behind the text.
   -> Shape layer appears between background and text.
   -> Canvas shows shape.
7. Ask: animate the text with spring pop-up.
   -> Keyframe lanes appear.
   -> Playback shows scale/opacity spring.
   -> Background remains blue.
8. Close app, reopen, open Recent Project.
   -> Same project state returns.
9. Create another composition.
   -> It starts clean.
10. `wait_for_apply` reports appApplied=true for every command.
```

If any command exists only in Supabase but does not appear in the open editor,
the implementation is not complete.
