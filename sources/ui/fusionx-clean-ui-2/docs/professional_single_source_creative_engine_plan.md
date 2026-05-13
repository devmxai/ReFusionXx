# Professional Single Source Creative Engine Plan

Short name: `PSSCE`

Status: master architecture plan for the unified ReFusionXx creative runtime

Package: `com.refusion.app`

Date: 2026-05-13

Supersedes as umbrella:

- `professional_universal_agent_node_live_apply_spatial_plan.md`
- `professional_canvas_visual_motion_engine_plan.md`
- `professional_mcp_scene_truth_runtime_plan.md`
- `professional_agent_composition_truth_graph_plan.md`
- MCP-only, paste-only, and UI-only apply plans

Must preserve:

- protected Stage5 / Live Scrub boundaries unless an exact implementation slice
  explicitly approves them;
- existing Master Clock, Master Timeline, Master Keyframe, SpeedyGraph, and
  export foundations;
- editable ReFusion-native SceneProgram and DirectorPlan semantics.

## 1. Executive Decision

ReFusionXx must have one app-wide source of truth for every creative operation.

The center of the product must not be:

```text
MCP
Supabase rows
Paste Script parser
manual UI widgets
template buttons
timeline row widgets
preview player state
native video surface state
export-only models
```

The center must be:

```text
Canonical Creative Graph
  + Master Timeline Graph
  + Master Property/Effect/Motion Channels
  + Deterministic Frame Evaluator
  + Master Visual Program
```

Every input path must be only an adapter into that engine:

```text
Manual UI
Paste Script
MCP Agent
Templates
Tap List
Future Tools
        |
        v
Input Adapter
        |
        v
Canonical SceneCommand
        |
        v
ProfessionalEditorCommandDispatcher
        |
        v
Unified Apply Engine
        |
        v
Canonical Creative Graph
        |
        v
Master Timeline Graph
        |
        v
Master Frame Evaluator
        |
        v
Master Visual Program
        |
        v
Preview Renderer / Playback / Live Scrub Adapter / Export Renderer
```

The product rule is:

```text
If it does not enter the Canonical Creative Graph, it is not real.
If it does not evaluate through the Master Frame Evaluator, it is not visual truth.
If preview and export do not consume the same evaluated truth, it is not production-ready.
If MCP succeeds before the open app applies and proves it, it is not applied.
```

## 2. Why This Plan Exists

The current system has working pieces, but they can behave like separate
engines:

```text
Paste Script can apply locally.
Manual UI can mutate local editor state.
MCP can write Supabase rows.
Renderer can draw a subset of payloads.
Export can have a different support surface.
```

This creates the exact failures observed:

- ChatGPT says a layer was inserted, but the open app does not show it.
- `appApplied=false` remains because the app never receives or acknowledges the
  exact command.
- A background exists in Supabase but not as a true timeline node.
- Video effects such as mask, border, glow, and shadow can exist as metadata but
  not as rendered surfaces.
- Motion can be stored in payload fields instead of canonical keyframe channels.
- The agent guesses coordinates because it does not receive evaluated canvas and
  element geometry.
- Manual edits, scripts, and MCP edits can diverge.
- Preview, Live Scrub, and export can silently disagree.

The fix is not another MCP patch. The fix is to make every path use the same
creative engine.

## 3. External Professional Lessons To Encode

### 3.1 Remotion Invariant

Remotion makes composition metadata explicit:

```text
width
height
fps
durationInFrames
current frame
```

The useful invariant for ReFusionXx is not React. The useful invariant is:

```text
composition metadata + frame/time + props/graph -> pixels
```

ReFusionXx must expose the native equivalent:

```text
CompositionTruth + FrameContext + CreativeGraph + Assets -> EvaluatedFrameTruth
```

Official references:

- https://www.remotion.dev/docs/composition
- https://www.remotion.dev/docs/use-current-frame
- https://www.remotion.dev/docs/use-video-config
- https://www.remotion.dev/docs/renderer/render-media

### 3.2 HyperFrames Invariant

HyperFrames treats source composition files, track timing, media starts,
composition dimensions, paused timelines, lint, inspect, preview, and render as
one deterministic workflow.

The useful invariant for ReFusionXx is:

```text
layout/evaluated frame before animation
deterministic seek before preview
inspect before export
render proof before delivery
```

ReFusionXx should not become HTML. It should adopt the discipline:

```text
validate -> inspect -> preview -> render -> prove
```

### 3.3 ReFusion Native Invariant

ReFusion scenes are not HTML and not black-box video clips. They are editable
native compositions built from:

```text
surfaces
timeline clips
assets
properties
style stacks
effect stacks
motion/keyframe channels
SpeedyGraph timing
render adapters
export adapters
```

DirectorPlan, SceneProgram, templates, and recipes are authoring formats only.
They must compile into ordinary editable graph nodes.

## 4. Non-Negotiable Product Laws

### Law 1: One Mutation Path

No code path may mutate editor state directly except the unified dispatcher.

Forbidden:

```text
widget -> setState(project changed)
MCP bridge -> local graph changed directly
paste parser -> MotionProject changed directly
template button -> timeline changed directly
native preview -> hidden visual state changed
```

Required:

```text
source input -> SceneCommand -> ProfessionalEditorCommandDispatcher
```

### Law 2: One Editable Graph

Every visible or audible item must be represented in the Canonical Creative
Graph.

Supported node families:

```text
background
video
image
text
shape
audio
audio-linked visualizer
adjustment layer
effect control layer
group
precomp / scene clip
component
template instance
```

### Law 3: One Timeline Truth

Every node has a real timeline lifetime:

```text
startMs
durationMs
endMs
trackId
zIndex / draw order
clip-local time mapping
source media time mapping
```

Background is not only metadata. It is a timeline node.

### Law 4: One Property And Channel Truth

Every editable static or animated value lives in one property system.

Examples:

```text
transform.position.x
transform.position.y
transform.scale.x
transform.scale.y
transform.rotation.z
opacity
mask.radius
mask.feather
border.width
shadow.blur
glow.intensity
video.sourceStartMs
video.playbackRate
audio.volume
text.fontSize
shape.cornerRadius
```

Animated values must live in canonical channels/keyframes. Animation must not
live only in:

```text
payload.updates.animation
MCP command payloads
SceneProgram blobs
UI state
renderer-local state
native player clock
```

### Law 5: One Surface Stack

Every visual node participates in the same renderer-neutral surface stack:

```text
source
  -> source range / media decode / generated primitive
  -> crop / fit / focal point
  -> mask / matte / clip path
  -> style / fill / stroke / typography
  -> transform
  -> effects
  -> opacity / blend
  -> composite
```

Different node families can have different adapters, but not separate engines.

### Law 6: One Deterministic Frame Evaluator

The same graph revision and same time must produce the same evaluated result:

```text
CreativeGraph + FrameContext + Assets + CapabilityRegistry
  -> EvaluatedFrameTruth
```

Preview, playback, Live Scrub, screenshot capture, MCP proof, tests, and export
must consume that same evaluated truth.

### Law 7: One Visual Program

Renderers must draw a renderer-neutral `MasterVisualProgram`.

Renderers must not reinterpret raw authoring payloads.

```text
EvaluatedFrameTruth -> MasterVisualProgram -> renderer adapters
```

### Law 8: One Proof Contract

Any operation that claims success must prove:

```text
dataApplied
undoRedoRecorded
timelineVisible
frameEvaluated
visualProgramEmitted
rendererApplied
visualBoundsVerified
previewSupported
exportSupported or exportBlocker
```

For MCP, this proof is also used to write `appApplied=true`.

## 5. Core Architecture

### 5.1 Input Adapters

Each input source converts user intent into canonical commands.

```text
Manual UI Adapter
Paste Script Adapter
MCP Agent Adapter
Template Adapter
Tap List Adapter
Future Tool Adapter
```

Adapters may parse, normalize, and validate intent. They may not mutate the
creative graph.

### 5.2 Canonical SceneCommand

Every mutation becomes a command with identity, target, time, operation, and
expected revision.

```json
{
  "schemaVersion": "refusion.scene-command/v1",
  "commandId": "uuid",
  "source": "manual-ui | paste-script | mcp-agent | template | tap-list | future-tool",
  "projectId": "uuid",
  "compositionId": "uuid",
  "expectedRevision": 12,
  "transactionId": "uuid",
  "operation": "setProperty | insertNode | removeNode | applyEffect | applyMotion | trimClip | splitClip | reorder | group | setSourceRange",
  "target": {
    "mode": "nodeId | selection | semantic | query",
    "nodeId": "uuid"
  },
  "time": {
    "rootTimeMs": 1200,
    "frameIndex": 36
  },
  "payload": {},
  "validation": {
    "requireVisibleTarget": true,
    "requireRendererSupport": true,
    "allowRebase": true
  }
}
```

### 5.3 ProfessionalEditorCommandDispatcher

The dispatcher is the only write gate.

Responsibilities:

```text
resolve target
validate permissions
validate capability
validate time
validate renderer support
open transaction
apply graph mutation
record undo/redo
increment revision
invalidate evaluator/renderers
produce apply receipt
```

All input paths must call this dispatcher.

### 5.4 Unified Apply Engine

The apply engine mutates canonical domain models only:

```text
CompositionGraph
TimelineGraph
AssetGraph
SurfaceGraph
PropertyChannelGraph
EffectStackGraph
MotionChannelGraph
AudioGraph
Group/PrecompGraph
```

It never writes renderer-specific side state as the source of truth.

### 5.5 Canonical Creative Graph

The graph is the single product truth.

```text
CreativeGraph
  project
  compositions
  assets
  timelines
  tracks
  nodes
  surfaces
  groups
  precomps
  properties
  channels
  keyframes
  effects
  masks
  media ranges
  typography
  audio
  diagnostics
```

## 6. Canonical Data Contracts

### 6.1 Composition Truth

```json
{
  "schemaVersion": "refusion.composition/v1",
  "projectId": "uuid",
  "compositionId": "uuid",
  "name": "Story",
  "width": 1080,
  "height": 1920,
  "fps": 30,
  "durationMs": 30000,
  "durationFrames": 900,
  "coordinateSystem": "centerOriginCanonical",
  "safeAreas": {
    "title": {},
    "action": {}
  },
  "revision": 42
}
```

### 6.2 Universal Authored Node

```json
{
  "schemaVersion": "refusion.authored-node/v1",
  "nodeId": "uuid",
  "family": "video | image | text | shape | background | audio | adjustment | group | precomp | component",
  "name": "Hero Video",
  "trackId": "uuid",
  "timelineStartMs": 0,
  "timelineDurationMs": 10000,
  "zIndex": 20,
  "sourceBinding": {},
  "propertyRefs": [],
  "effectStackRef": "uuid",
  "motionChannelRefs": [],
  "capabilityState": {},
  "diagnostics": []
}
```

### 6.3 Surface Stack

```json
{
  "schemaVersion": "refusion.surface-stack/v1",
  "nodeId": "uuid",
  "source": {},
  "crop": {},
  "mask": {},
  "style": {},
  "transform": {},
  "effects": [],
  "opacity": {},
  "blend": {},
  "composite": {}
}
```

### 6.4 Property Channel

```json
{
  "schemaVersion": "refusion.property-channel/v1",
  "channelId": "uuid",
  "nodeId": "uuid",
  "propertyPath": "transform.position.x",
  "valueType": "number | color | vector | enum | text | boolean",
  "staticValue": 540,
  "keyframes": [
    {
      "timeMs": 0,
      "value": 540,
      "easing": "$speedyGraph.easeOutCubic"
    }
  ]
}
```

### 6.5 Effect Stack

```json
{
  "schemaVersion": "refusion.effect-stack/v1",
  "nodeId": "uuid",
  "effects": [
    {
      "effectId": "uuid",
      "type": "mask | border | shadow | glow | blur | colorGrade | vignette | grain | motionBlur",
      "enabled": true,
      "params": {},
      "animatableParamRefs": []
    }
  ]
}
```

### 6.6 Frame Context

```json
{
  "schemaVersion": "refusion.frame-context/v1",
  "projectId": "uuid",
  "compositionId": "uuid",
  "graphRevision": 42,
  "rootTimeMs": 1200,
  "frameIndex": 36,
  "fps": 30,
  "quality": "preview | export | scrub | proof"
}
```

### 6.7 Evaluated Frame Truth

```json
{
  "schemaVersion": "refusion.evaluated-frame/v1",
  "frameContext": {},
  "canvas": {},
  "drawList": [],
  "nodeGeometry": {},
  "visibleBounds": {},
  "overlaps": [],
  "capabilityDiagnostics": [],
  "exportDiagnostics": []
}
```

## 7. Time And Coordinate Contracts

### 7.1 Time Truth

All time must resolve through these mappings:

```text
root composition time
  -> scene/precomp local time
  -> clip local time
  -> source media time
  -> property channel sample time
  -> frame index
```

No animation may depend on wall-clock time as truth.

Required values:

```text
rootTimeMs
frameIndex
fps
durationMs
durationFrames
clipStartMs
clipDurationMs
sourceStartMs
sourceDurationMs
playbackRate
localTimeMs
```

### 7.2 Coordinate Truth

All geometry must be evaluable in canonical pixel coordinates.

Required geometry output:

```text
canvasWidth
canvasHeight
coordinateSystem
anchor
position
scale
rotation
intrinsicSize
renderedSize
worldBounds
visibleBounds
maskedBounds
safeAreaCompliance
```

### 7.3 Spatial Solver

Agents and high-level UI tools should prefer semantic operations:

```text
positionAtAnchor
fitInZone
alignTo
scaleToFit
moveToEdge
centerIn
distribute
avoidOverlap
```

Raw pixel edits remain allowed for professional precision, but they must be
validated against the same frame evaluator.

## 8. Capability Registry

There must be one capability registry that answers:

```text
Can capability X apply to node family Y?
Can it be static?
Can it be animated?
Is it supported in preview?
Is it supported in export?
Which renderer adapter implements it?
What fallback or blocker is required?
```

Capability families:

```text
transform
opacity
source range
crop
fit/fill
mask
matte
clip path
fill
stroke
border
corner radius
shadow
glow
blur
motion blur
blend
color adjustment
LUT
vignette
grain
typography
shape geometry
video speed
audio volume
audio pan
audio fades
adjustment layer controls
precomp transforms
```

Unsupported capabilities must return structured blockers. They must never be
silently dropped.

## 9. Ingress Adapters

### 9.1 Manual UI Adapter

Manual UI gestures and inspector changes must emit commands:

```text
drag element -> setProperty(transform.position)
resize handles -> setProperty(transform.scale or bounds)
timeline trim -> trimClip
add effect button -> applyEffect
keyframe edit -> setKeyframe
```

The UI reads from the graph and writes through the dispatcher.

### 9.2 Paste Script Adapter

Pasted script is an authoring format.

Required pipeline:

```text
paste text
  -> parse DirectorPlan / SceneProgram / command list
  -> normalize into SceneCommands
  -> validate
  -> dispatch transaction
```

If Paste Script can do something, MCP and templates can do it too because all
compile to the same commands.

### 9.3 MCP Agent Adapter

MCP is remote authoring and synchronization. It is not a separate engine.

Required pipeline:

```text
MCP tool call
  -> server validates identity and composition
  -> creates command bus row
  -> app receives command
  -> app converts to SceneCommand
  -> dispatcher applies
  -> app writes ACK with proof
```

MCP success means:

```text
server accepted + open app applied + proof stored
```

It does not mean only "Supabase row inserted."

### 9.4 Template Adapter

Templates compile into regular nodes, effects, and channels. A template instance
is editable after insertion.

### 9.5 Tap List Adapter

Tap-list actions are shortcuts over the same command dispatcher.

### 9.6 Future Tools Adapter

Any new AI, UI, automation, plugin, import, or generation feature must declare
its input adapter and prove it only writes through the command dispatcher.

## 10. MCP Live Apply And ACK Contract

### 10.1 Command Bus

Every mutating MCP operation creates a command row:

```text
commandId
projectId
compositionId
agentSessionId
target
operation
expectedRevision
revisionBefore
revisionAfter
status=pending_apply
payload
createdAt
```

Commands should not be hidden from the open app by `editor_session_id` before
the open app claims them.

Correct ownership flow:

```text
command created without editor_session_id
open app sees command by project/composition
open app marks received and sets editor_session_id
open app applies locally
open app ACKs exact commandId
```

### 10.2 ACK Proof

The app may ACK only after the dispatcher produces proof:

```text
localGraphApplied=true
timelineVisible=true
frameEvaluated=true
visualProgramEmitted=true
rendererApplied=true
visualBoundsVerified=true
```

`appApplied=true` must not be written by the server alone.

### 10.3 App Background Handling

If the app is not foreground or cannot reach the network:

```text
status=waiting_for_open_app
appApplied=false
reason=APP_BACKGROUND_OR_NETWORK_BLOCKED
```

This must be visible in diagnostics.

## 11. Graph Projections And Agent Knowledge

### 11.1 Composition Truth Graph

The agent reads a projection:

```text
CompositionTruthGraph
```

This projection is read-only. It is not a second source of truth.

It includes:

```text
composition metadata
assets
timeline tracks
nodes
source ranges
property channels
effect stacks
motion channels
current playhead
selected nodes
evaluated geometry
renderer capabilities
diagnostics
```

### 11.2 Agent Write Rules

Before spatial or timeline edits, the agent must read:

```text
get_composition_truth
get_timeline_state
get_element_geometry
get_capabilities
```

Then write through semantic commands or validated pixel commands.

## 12. Validation, Inspect, Preview, Render Gates

Borrowing the useful discipline from HyperFrames, ReFusionXx needs native gates.

### 12.1 Validate

Checks graph correctness:

```text
missing IDs
invalid references
unsupported properties
invalid time ranges
overlapping clips on impossible tracks
unknown effects
missing assets
invalid keyframe values
```

### 12.2 Inspect

Evaluates frames and catches visual issues:

```text
off-canvas elements
unintended overlap
text overflow
masked content invisible
zero-size nodes
unsupported renderer capability
safe-area violations
```

### 12.3 Preview

Uses the same frame evaluator and visual program as export.

### 12.4 Render / Export

Export must not use a different graph interpretation.

If export cannot support a capability:

```text
exportSupported=false
exportBlocker={ code, nodeId, capability, message }
```

Silent export drops are forbidden.

## 13. Transactions, Undo, Redo, And Rebase

Every command belongs to a transaction.

Required transaction record:

```text
transactionId
source
commands
revisionBefore
revisionAfter
undoPatch
redoPatch
diagnostics
proof
```

Revision conflicts must rebase when safe:

```text
same node, non-overlapping property -> merge
same node, same property -> conflict
target removed -> fail with TARGET_REMOVED
target ambiguous -> fail with AMBIGUOUS_TARGET
```

Undo and redo must affect graph truth, not renderer-local state.

## 14. Renderer And Export Conformance

Each renderer adapter must declare:

```text
supports node family
supports effect type
supports animated property
supports mask/crop/source range
supports blend mode
supports export parity
```

Preview and export may differ in quality, but not in:

```text
time mapping
property values
interpolation
effect order
source identity
draw order
geometry
visibility
```

## 15. Persistence And Recent Projects

Create Composition must create clean identity:

```text
new projectId or compositionId as requested
empty timeline graph
empty surface graph
fresh revision
no carryover from prior composition
```

Recent Projects / Recent Compositions is the only way to reopen old work.

The local app should persist graph state so returning from background does not
replay a partial cloud reload as if it were the truth.

## 16. Implementation Phases

### PSSCE-00: Inventory And Guardrails

- Inventory all current write paths.
- Mark every direct graph mutation outside the dispatcher.
- Mark all renderer-local or MCP-local state that acts like truth.
- Protect Live Scrub boundaries.

Exit criteria:

```text
complete write-path map
complete render-path map
complete export-path map
no implementation starts without boundaries
```

### PSSCE-01: Canonical Command Model

- Add `SceneCommand`.
- Add target resolution contract.
- Add command validation result.
- Add command source enum.
- Add command transaction wrapper.

Exit criteria:

```text
manual, paste, MCP, template commands can share one schema
```

### PSSCE-02: ProfessionalEditorCommandDispatcher

- Create the only mutation gate.
- Add transaction begin/apply/commit/fail.
- Add undo/redo patch output.
- Add revision increment.

Exit criteria:

```text
no new feature may mutate graph without dispatcher
```

### PSSCE-03: Canonical Creative Graph Foundation

- Promote all visible/audible items to authored nodes.
- Represent background as a timeline node.
- Represent media clips as authored surfaces, not only player widgets.
- Represent text/shape/image/video with one shared surface contract.

Exit criteria:

```text
background/text/shape/image/video/audio all exist as graph nodes
```

### PSSCE-04: Property And Channel Unification

- Move static properties and animated properties into one property registry.
- Convert all animation payloads to channels/keyframes.
- Map SceneProgram and MotionProgram values into channels.

Exit criteria:

```text
no animation is stored only in payload metadata
```

### PSSCE-05: Effect Stack Unification

- Implement one effect stack contract.
- Register mask, crop, border, shadow, glow, blur, color, motion blur, and
  blend capabilities.
- Add preview/export support flags.

Exit criteria:

```text
effects are editable, inspectable, renderable, and export-aware
```

### PSSCE-06: Spatial Truth And Geometry Evaluator

- Implement canvas metadata.
- Implement element geometry from evaluated frame truth.
- Implement safe zones, anchors, and visible bounds.
- Implement overlap and off-canvas diagnostics.

Exit criteria:

```text
agent can ask where any node is and receive exact pixel truth
```

### PSSCE-07: Master Frame Evaluator

- Evaluate graph revision at any time/frame.
- Resolve source time, clip time, local time, and property samples.
- Emit draw list and node geometry.

Exit criteria:

```text
same graph revision + same frame -> same evaluated truth
```

### PSSCE-08: Master Visual Program

- Convert evaluated frame truth into renderer-neutral draw commands.
- Prevent renderers from reading raw authoring payloads directly.

Exit criteria:

```text
preview/export/screenshot consume the visual program
```

### PSSCE-09: Renderer Adapter Conformance

- Wire preview renderer through visual program.
- Wire playback invalidation through evaluator.
- Wire export through the same evaluated truth.
- Declare unsupported capabilities explicitly.

Exit criteria:

```text
preview and export either match or block with structured reason
```

### PSSCE-10: Paste Script Adapter Migration

- Make pasted scripts compile into SceneCommands.
- Remove paste-only local mutation.
- Preserve current successful script behavior through the dispatcher.

Exit criteria:

```text
paste script and manual UI produce same graph mutation type
```

### PSSCE-11: MCP Adapter Migration

- Make MCP a remote command transport, not a separate apply engine.
- Fix pending command ownership and ACK flow.
- Apply MCP commands through dispatcher.
- ACK only after proof.

Exit criteria:

```text
anything paste can do, MCP can do through same engine
```

### PSSCE-12: Manual UI Adapter Migration

- Move canvas gestures, inspector edits, timeline trims, and effect buttons to
  SceneCommands.
- Ensure every UI edit is undoable and scriptable.

Exit criteria:

```text
manual UI and MCP produce same command/proof structure
```

### PSSCE-13: Template, Tap List, And Future Tool Adapters

- Compile templates into commands.
- Compile tap-list actions into commands.
- Add adapter policy for future tools.

Exit criteria:

```text
new input sources cannot bypass the dispatcher
```

### PSSCE-14: Validation And Inspect Gates

- Add graph lint.
- Add visual inspect.
- Add renderer/export conformance inspect.
- Add command proof diagnostics.

Exit criteria:

```text
bad graph, bad layout, bad renderer support, and bad export support fail early
```

### PSSCE-15: Acceptance And Regression Suite

- Add tests that compare manual, paste, MCP, and template paths.
- Add deterministic frame tests.
- Add preview/export parity tests.
- Add appApplied proof tests.

Exit criteria:

```text
single-source contract is proven, not assumed
```

## 17. Acceptance Tests

### Test 1: Same Edit From Three Inputs

Input:

```text
Move video to top-right with padding 24 and scale-to-fit.
```

Paths:

```text
manual UI
paste script
MCP agent
```

Expected:

```text
same SceneCommand operation
same target node
same property channels
same evaluated frame geometry
same undo entry
same preview result
same export result or same export blocker
```

### Test 2: Background Is A Timeline Node

Input:

```text
Create white background for 30 seconds.
```

Expected:

```text
Background node exists in timeline
durationMs=30000
zIndex behind foreground nodes
preview draws it
export draws it
MCP appApplied=true only after renderer proof
```

### Test 3: Video PIP With Effects

Input:

```text
Make imported video circular, add border/glow/shadow, animate from center to top-right.
```

Expected:

```text
video node remains same node
mask effect exists in effect stack
border/glow/shadow exist in effect stack
motion is canonical keyframe channels
geometry solves to top-right using canvas metadata
preview and export agree
```

### Test 4: Manual Edit After Agent Edit

Input:

```text
Agent creates motion.
User drags final position manually.
Agent asks where node is.
```

Expected:

```text
manual edit writes command
graph revision increments
agent reads exact evaluated bounds
distance moved is computed in pixels
no stale MCP state is used
```

### Test 5: Paste Script Parity

Input:

```text
Paste script that creates text with pop-up animation.
Ask MCP to create the same thing.
```

Expected:

```text
same node family
same channels
same keyframes
same SpeedyGraph timing
same renderer output
```

### Test 6: Export Parity

Input:

```text
Scene with video mask, glow, text animation, and adjustment layer.
```

Expected:

```text
preview frame and export frame evaluate from same graph
unsupported export capability blocks explicitly
no effect is silently dropped
```

### Test 7: App Background Handling

Input:

```text
MCP command while app is backgrounded.
```

Expected:

```text
command remains waiting_for_open_app
appApplied=false
diagnostic states app not foreground/network blocked
when app returns foreground, command applies or reports blocker
```

## 18. Stop List

Do not:

- create another MCP-only apply path;
- create another paste-only apply path;
- let any widget mutate the graph directly;
- store animation only inside payload metadata;
- store effects only as renderer-local state;
- treat background as only project metadata;
- let renderer adapters reinterpret raw payloads;
- return `appApplied=true` before local graph + renderer proof;
- let export silently drop unsupported effects;
- let the agent guess canvas geometry when a solver can compute it;
- use Supabase as the final source of truth for open-app rendering;
- use Live Scrub or Stage5 protected internals as the first implementation step
  unless that exact slice is explicitly approved.

## 19. Definition Of Done

`PSSCE` is done when:

```text
Manual UI, Paste Script, MCP Agent, Templates, Tap List, and Future Tools
all emit Canonical SceneCommands.

Every command goes through ProfessionalEditorCommandDispatcher.

Every visible/audible object exists in the Canonical Creative Graph.

Every static or animated property is represented in the property/channel system.

Every effect is represented in the effect stack with capability diagnostics.

Preview, playback, Live Scrub adapter, screenshot proof, and export consume the
same Master Frame Evaluator and Master Visual Program.

The agent can read exact composition/timeline/canvas/node truth and write back
through the same system as the UI.

appApplied=true means the open app applied, evaluated, rendered, and proved the
change.
```

When this is true, ReFusionXx behaves like a professional native creative
engine:

```text
one brain
one timeline
one scene graph
one keyframe truth
one effects truth
one frame evaluator
one preview/export truth
many input methods
```

