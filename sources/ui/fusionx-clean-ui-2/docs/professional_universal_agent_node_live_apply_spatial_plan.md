# Professional Universal Agent Node Live-Apply And Spatial Intelligence Plan

Short name: `PUANLAS`

Status: Part 1 corrective execution plan

Package: `com.refusion.app`

Date: 2026-05-13

Scope: only the three linked failures below.

This is intentionally not a full app rewrite plan. It is the first focused
execution part for making ChatGPT / Codex / Claude agents professionally useful
inside the exact open ReFusionXx composition.

## 1. The Three Problems This Plan Solves

### Problem A - Universal Agent Capability

The agent must be able to use the application's real capabilities on every
timeline node family where the capability makes sense:

```text
video
image
text
shape
background
audio
adjustment/effect control
scene clip / group / precomp
```

Capabilities must not be trapped in separate one-off paths:

```text
text supports animation but video does not
video supports transform but shape does not
mask exists in payload but renderer ignores it
glow exists as metadata but cannot be previewed
MCP can do something manual UI cannot reuse
```

### Problem B - Live Apply Guarantee

When the agent writes anything, it must appear in the exact open composition's
timeline and canvas.

Database success is not enough:

```text
Supabase row written != app applied
revision increased != command applied
metadata saved != renderer drew it
```

Success requires command-specific proof:

```text
commandId received by open app
local editor graph mutated
timeline shows node/change
frame evaluation sees it
renderer draws it or returns explicit blocker
app writes commandId receipt
```

### Problem C - Pixel-Accurate Spatial Intelligence

The agent must know the canvas, timeline, and element geometry before it moves
or animates anything.

No more guessed values like:

```text
x=860 y=260 scale=0.42
```

unless they came from a deterministic spatial solver.

The agent must know:

```text
canvas width/height/fps/duration
coordinate system
safe zones
visible nodes at a time
intrinsic element sizes
current transforms
current bounds
masked/cropped visible bounds
overlaps
renderer capability status
```

## 2. External Design Principles

### 2.1 Remotion Principle

Remotion makes video metadata explicit at the composition boundary:

```text
id
width
height
fps
durationInFrames
```

Components evaluate from frame truth. ReFusionXx must expose the native editor
equivalent:

```text
composition truth + frame/time -> evaluated scene truth
```

References:

- https://www.remotion.dev/docs/composition
- https://www.remotion.dev/docs/use-current-frame
- https://www.remotion.dev/docs/use-video-config

### 2.2 HyperFrames Principle

HyperFrames uses deterministic seek-driven rendering. It is not screen
recording. Each frame is positioned and captured from a known timeline state.

ReFusionXx must adopt the same invariant:

```text
same graph revision + same time -> same visual output
```

References:

- https://hyperframes.heygen.com/packages/engine
- https://hyperframes.heygen.com/guides/video-editor-cheatsheet
- https://hyperframes.heygen.com/guides/prompting

## 3. Non-Negotiable Contracts

### 3.1 Universal Node Contract

Every editable item becomes a universal node/surface:

```text
UniversalTimelineNode
  id
  family: video | image | text | shape | background | audio | adjustment | group
  sourceBinding
  timelineStartMs
  timelineDurationMs
  zIndex
  intrinsicGeometry
  currentTransform
  styleStack
  maskCropStack
  effectStack
  motionChannels
  rendererCapabilityState
  diagnostics
```

Specialized renderers may exist, but the capability and command model must be
shared.

### 3.2 Universal Capability Registry

There must be one registry that answers:

```text
Can capability X apply to node Y?
Can it be static?
Can it be animated?
Which renderer modes support it?
What fallback/blocker should be returned if unsupported?
```

Capability families:

```text
transform
opacity
fill
stroke
border
corner radius
shadow
glow
blur
mask
crop
fit/fill
blend
color adjustment
motion blur
audio volume/pan
text typography
shape geometry
video speed/source range
adjustment/effect control
```

Example capability applicability:

```text
border:
  video: yes
  image: yes
  text: yes, as text outline/container when requested
  shape: yes
  background: yes, if represented as visible layer
  audio: no

typewriter:
  text: yes
  video/image/shape/audio: no

volume:
  video: yes, if it has audio
  audio: yes
  text/shape/background: no
```

Unsupported does not mean silent failure. It means structured diagnostics.

### 3.3 CommandId Live-Apply Contract

Every mutating agent operation must have a `commandId`.

The command lifecycle:

```text
accepted
cloudCommitted
appReceived
localGraphApplied
timelineVisible
frameEvaluated
visualProgramEmitted
rendererApplied
visualBoundsVerified
appApplied
```

`appApplied=true` is valid only for the exact `commandId`.

Forbidden:

```text
ack all commands up to revision N
mark appApplied true from database write success
mark appApplied true from metadata-only storage
mark appApplied true when app is on home screen
```

### 3.4 Spatial Truth Contract

Agent spatial operations must be solved from evaluated geometry.

Required inputs:

```text
canvas metadata
timeline visible nodes
intrinsic node geometry
current transform
current visible bounds
mask/crop result
safe zones
overlap state
target anchor/zone
motion time range
renderer capability
```

Raw pixels remain allowed for manual professional precision, but agent-authored
layout must default to anchors, zones, and solvers.

## 4. Phase Plan

### PUANLAS-00 - Failure Fixtures First

Create red tests/diagnostics for the current three failures.

Scenarios:

```text
1. Agent inserts background but app stays unchanged.
2. Agent applies video mask/border/glow but renderer ignores metadata.
3. Agent moves video to top-right but coordinates are wrong.
4. Agent applies text animation, then second animation overwrites or conflicts.
5. Agent writes while app has no open composition.
6. Agent writes to stale composition after user switches context.
```

Acceptance:

```text
Each failure reports commandId, projectId, compositionId, targetId, node family,
capability, stoppedStage, and renderer diagnostics.
```

No new creative feature may be added before these failures are reproducible.

### PUANLAS-01 - Universal Capability Registry

Build one registry above MCP, UI, renderer, and export.

Required model:

```text
UniversalCapabilityDefinition
  capabilityId
  family
  supportedNodeFamilies
  staticSupport
  animatedSupport
  propertyType
  stackOrder
  affectsBounds
  rendererSupport
  fallbackPolicy
  diagnostics
```

Required first capabilities:

```text
transform.position
transform.scale
transform.rotation
opacity
border
shadow
glow
mask.circle
mask.roundedRect
crop
blur.gaussian
text.fontSize
text.color
shape.fill
shape.stroke
video.sourceRange
audio.volume
```

Acceptance:

```text
One API answers whether border/glow/mask/animation applies to video, image,
text, shape, background, and audio.
```

### PUANLAS-02 - Universal Target Identity

Create one address model for all agent-addressable things:

```text
project
composition
timeline node
layer
element
media clip
text element
shape element
audio clip
adjustment node
scene clip
group/precomp
transition role
```

Required:

```text
resolveTarget(ref, activeCompositionTruth) -> UniversalTarget
```

Acceptance:

```text
MCP, SceneProgram, keyframe UI, canvas transform, and renderer adapters resolve
the same target ID for the same visible node.
```

### PUANLAS-03 - One Capability Patch Path

Agent tools may keep friendly aliases:

```text
set_border
set_glow
set_mask
set_transform
apply_animation_recipe
```

But internally they must all lower to one canonical path:

```text
apply_capability_patch(command)
```

Patch shape:

```text
commandId
targetRef
capabilityId
value
timeRange
mode: set | add | remove | animate | merge
expectedGraphRevision
idempotencyKey
```

Acceptance:

```text
set_glow(video), set_glow(image), set_glow(shape), and set_glow(text) all
produce the same capability patch family with different target adapters.
```

### PUANLAS-04 - Open-App Command Dispatcher

Stop using `get_layers` as the primary apply mechanism.

Required:

```text
get_pending_commands(projectId, compositionId, appSessionId)
dispatchCommand(commandId)
applyCapabilityPatch()
writeCommandReceipt(commandId)
```

The app may continue polling snapshots for recovery and inspection, but
snapshots are not the command bus.

Acceptance:

```text
Agent inserts background:
  server returns commandId
  app receives commandId
  app applies command locally
  app writes receipt for that commandId
  wait_for_apply(commandId) returns appApplied=true
```

### PUANLAS-05 - Command-Specific Receipts

Replace revision-only ACK with command proof.

Receipt:

```text
commandId
projectId
compositionId
appSessionId
deviceId
targetIds
localRevisionBefore
localRevisionAfter
cloudRevisionAfter
proof:
  localGraphApplied
  timelineVisible
  frameEvaluated
  visualProgramEmitted
  rendererApplied
  visualBoundsVerified
diagnostics:
  warnings
  blockers
```

Acceptance:

```text
Two commands at same revision range can have separate success/failure states.
No command succeeds because another command advanced the revision.
```

### PUANLAS-06 - Canvas Metadata Tool

Implement authoritative canvas metadata.

Required tool:

```text
get_canvas_metadata()
```

Story example:

```text
width: 1080
height: 1920
fps: 30
durationMs: from active composition
origin: center
xRange: [-540, 540]
yRange: [-960, 960]
titleSafe: { left: 64, top: 128, right: 1016, bottom: 1792 }
actionSafe: { left: 32, top: 96, right: 1048, bottom: 1824 }
anchors:
  center: { x: 540, y: 960, cx: 0, cy: 0 }
  topRight: { x: 1080, y: 0, cx: 540, cy: -960 }
```

Acceptance:

```text
Agent never needs to guess story canvas dimensions or origin.
```

### PUANLAS-07 - Element Geometry Tool

Implement geometry from evaluated frame truth.

Required tool:

```text
get_element_geometry(targetRef, timeMs)
```

Response includes:

```text
intrinsicSize
timelineRange
sourceRange
centerAbs
centerCanonical
boundsAbs
boundsCanonical
visibleBoundsAfterMask
rotation
scale
opacity
zIndex
safeZoneCompliance
overlaps
rendererCapabilityState
```

Acceptance:

```text
Geometry comes from evaluated frame state, not raw DB payload only.
Tolerance <= 0.5px.
```

### PUANLAS-08 - Deterministic Frame Evaluation

Add a formal frame evaluation tool:

```text
evaluate_frame(timeMs)
```

It must return:

```text
visible nodes
active timeline ranges
evaluated transforms
evaluated styles
evaluated effects
evaluated motion values
visible bounds
overlaps
renderer blockers
```

Acceptance:

```text
Same graph revision + same timeMs returns identical results across 3 calls.
Visibility rule is exact:
timelineStartMs <= timeMs < timelineEndMs
```

### PUANLAS-09 - Spatial Solver

Implement solver-backed layout tools:

```text
position_at_anchor
fit_in_zone
align_to
scale_to
keep_in_canvas
exit_direction
plan_motion_path
```

Example for Story 1080x1920:

```text
circle PIP diameter: 360
margin: 72
anchor: topRight

absolute center: x=828, y=252
canonical center: x=288, y=-708
bounds: left=648, top=72, right=1008, bottom=432
```

Acceptance:

```text
Agent says "move video to top-right as circular PIP" and solver returns exact
coordinates and keyframes. No hand-guessed x/y/scale.
```

### PUANLAS-10 - Overlap And Layout Validation

Add dry-run validation:

```text
layout.preview_change(command)
layout.detect_overlaps(timeRange)
layout.validate_intent(plan)
```

Acceptance:

```text
Before commit, agent sees if text overlaps video, PIP leaves canvas, title safe
is violated, or motion path collides during hold frames.
```

### PUANLAS-11 - Renderer Capability Proof

Renderer support must be honest.

For each capability and node family, report:

```text
previewSupport
playbackSupport
liveScrubSupport
exportSupport
proofMethod
blockerReason
```

Acceptance:

```text
If video glow/mask/border cannot render, command fails with
RENDERER_CAPABILITY_MISSING instead of returning appApplied=true.
```

### PUANLAS-12 - Minimum Green Slice

This is the first implementation slice. Do not start broad effects expansion
before it passes.

Implement:

```text
1. commandId dispatch for background insert
2. commandId receipt
3. get_canvas_metadata
4. get_element_geometry for background/text/shape/media
5. evaluate_frame for visible node list and bounds
6. position_at_anchor solver
7. universal capability registry with transform + opacity + border + mask
```

Acceptance:

```text
Open a Story composition.
Pair ChatGPT.
Ask: "add purple background".
It appears in timeline and canvas.
wait_for_apply(commandId) returns rendererApplied=true.

Ask: "add text and move it to top center title safe".
It appears correctly with evaluated bounds.

Ask: "move video to top-right PIP".
Solver outputs exact top-right bounds.
If mask/border/glow not supported yet, app returns explicit blocker.
```

## 5. Stop List

Do not:

- add more one-off MCP tools for each effect,
- let text/video/image/shape use separate unrelated capability models,
- apply remote changes from `get_layers` as the primary path,
- ack by revision as final success,
- mark metadata-only effects as applied,
- claim unsupported renderer capabilities,
- allow ChatGPT to guess canvas coordinates,
- mutate background from non-background commands,
- replace a whole scene to animate one existing node,
- build MCP-only behavior that manual UI cannot reuse,
- touch protected Stage5 / Live Scrub internals in this part.

## 6. Acceptance Suite

### 6.1 Universal Capability

```text
Query capability registry for:
  border on video/image/text/shape/background/audio
  glow on video/image/text/shape
  typewriter on text/video
  volume on audio/video/text
Expected: correct yes/no/diagnostics.
```

### 6.2 Live Apply

```text
Agent inserts background.
Expected:
  commandId exists
  app receives commandId
  timeline node appears
  canvas changes
  receipt is command-specific
  wait_for_apply(commandId).appApplied=true
```

### 6.3 No False Apply

```text
Agent writes while app is closed/home/no composition.
Expected:
  no appApplied
  no mutation to stale project
  clear OPEN_COMPOSITION_REQUIRED / WRONG_ACTIVE_CONTEXT
```

### 6.4 Spatial Precision

```text
Story 1080x1920.
Target PIP top-right diameter 360 margin 72.
Expected:
  centerAbs=(828,252)
  centerCanonical=(288,-708)
  boundsAbs=(648,72,1008,432)
  tolerance <= 0.5px
```

### 6.5 Sequential Edits

```text
Command 1: make video circular PIP top-right.
Command 2: add popup intro.
Command 3: add exit-right.
Expected:
  one video node
  one style/effect stack
  merged motion phases
  no duplicate layer
  no background mutation
```

## 7. Final Definition Of Done For Part 1

This part is complete when:

```text
Agent can inspect exact canvas/timeline/node truth,
apply a supported capability to any applicable node family through one command
path,
see it appear in the open app,
receive commandId renderer proof,
and use spatial solvers instead of coordinate guessing.
```

Only after this is green should we expand into the next parts:

```text
full effects catalog
full animation recipe catalog
advanced video mask/glow renderer parity
export parity
multi-agent collaboration
advanced Recent Projects persistence
```
