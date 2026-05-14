# Professional Unified Creative Truth Apply Spine Plan

Short name: `PUCTAS`

Status: official corrective implementation plan

Package: `com.refusion.app`

Date: 2026-05-14

Failure closure addendum:
`professional_unified_creative_truth_apply_spine_failure_closure_plan.md`

The addendum is mandatory for the current MCP failures where background,
text/motion identity, apply latency, and proof still bypass the intended spine.
It integrates `PNCLE-05C.UNIVERSAL-LAYER-UPDATE-IDENTITY-HARDENING.md` as the
universal identity gate. Treat it as the execution gate before continuing broad
PUCTAS or PNCLE phases.

Primary goal: make every creative edit from MCP Agent, Manual UI, Paste Script,
Templates, Tap List, and future tools pass through one professional apply spine
and appear as real editable canvas/timeline/render truth immediately.

This plan is not a background-only fix. It starts with the current failing
background/solid case because that is the smallest visible proof of the larger
architectural problem:

```text
MCP writes a row
-> app stores metadata or placeholder
-> timeline revision changes
-> no real render node exists
-> canvas stays unchanged
```

The permanent fix is:

```text
source intent
-> Canonical SceneCommand
-> Target Resolver
-> Unified Apply Engine
-> CreativeGraph / MotionProject node
-> Timeline Projection
-> Frame Evaluator
-> Preview Renderer
-> Export Renderer
-> Apply Proof
```

No path may bypass this spine.

---

## 0. Why This Plan Exists

The current user-facing failure:

- The user asks ChatGPT/MCP to create a background.
- The MCP server accepts the command.
- Supabase revision increases.
- A `solid` row exists.
- The app may add a timeline placeholder.
- The canvas remains black.

The precise local diagnosis from the current app:

- `_applyRemoteSolidLayerIfNeeded(...)` in `fusionx_clean_ui_screen.dart`
  only writes `project.metadata['backgroundColor']`.
- It adds a placeholder timeline clip.
- It does not create a `MotionLayerModel`.
- It does not create a `MotionElementModel`.
- It does not create evaluated shape properties.
- `MotionShapePreviewOverlay` renders only real evaluated shape elements.
- Therefore there is no shape render node for the preview renderer to draw.

This is a truth mismatch, not a color parsing issue.

The product must never again accept this pattern:

```text
data row exists
timeline revision changed
but canvas/timeline/render truth is missing
```

The system must accept only this pattern:

```text
data exists
graph node exists
timeline clip exists
frame evaluator sees it
renderer draws it
agent receives proof
```

---

## 1. Reference Systems And Lessons

This plan borrows principles, not implementation language.

### 1.0 Reference Inputs Reviewed

This plan must be treated as a synthesis of four evidence sources:

1. Current ReFusionXx code diagnosis:
   - `fusionx_clean_ui_screen.dart`
   - `_applyRemoteSolidLayerIfNeeded(...)`
   - `_ensureMcpSolidLayerTimelineClipInState(...)`
   - `MotionShapePreviewOverlay`
   - `PreviewStage`

2. Prior ReFusionXx architecture documents:
   - `professional_single_source_creative_engine_plan.md`
   - `professional_universal_agent_node_live_apply_spatial_plan.md`
   - `professional_mcp_open_app_live_apply_spine_plan.md`
   - `professional_native_creative_library_engine_plan.md`
   - `PNCLE-05C.UNIVERSAL-LAYER-UPDATE-IDENTITY-HARDENING.md`

3. HyperFrames local skills and references:
   - `hyperframes/SKILL.md`
   - `hyperframes-cli/SKILL.md`
   - `gsap/SKILL.md`
   - related adapter skills for deterministic seek-driven animation

4. Remotion official documentation:
   - `useCurrentFrame()`
   - `useVideoConfig()`
   - `<Composition>`

Any implementation slice derived from this plan must keep these references in
the pre-build report. If a slice disagrees with one of these references, the
report must explicitly explain why ReFusionXx intentionally diverges.

### 1.1 HyperFrames Lessons

HyperFrames treats HTML composition structure as the source of truth:

- clips have explicit ids;
- timing lives in `data-start`, `data-duration`, and track attributes;
- visual state is real DOM/CSS, not metadata-only;
- GSAP timelines are created paused and registered;
- the runtime seeks timelines deterministically;
- layout is built first, then animation describes motion into/out of that
  layout;
- selectors are stable identities.

Professional lessons to adopt in ReFusionXx:

1. Every visible thing must have a stable id.
2. Every visible thing must exist in the real render tree.
3. Timing must be explicit and seekable.
4. Animation must be deterministic from time/frame.
5. Layout must be inspectable before motion is added.
6. MCP/agent updates must target stable identities, not vague labels.

### 1.2 GSAP / HyperFrames Timing Lessons

The GSAP-HyperFrames contract creates paused timelines and lets the framework
seek them. It does not allow render-critical motion to depend on uncontrolled
`play()` calls, timers, async event handlers, or hidden state.

Professional lessons to adopt:

1. ReFusion motion channels must be seek-driven.
2. No MCP motion may remain as raw `payload.animation` metadata.
3. Motion must lower into `MotionPropertyChannelModel`.
4. Frame evaluation must compute visual state from graph + time.
5. Repeated commands should update existing channels by stable target/property,
   not add duplicate channels.

### 1.3 Remotion Lessons

Remotion exposes composition truth explicitly:

- `useVideoConfig()` gives width, height, fps, duration, id, and props.
- `useCurrentFrame()` gives deterministic frame time.
- `<Sequence>` time-shifts components while preserving local frame logic.
- `interpolate()` turns frame/time into visual values.
- updates are props/identity driven, not random component creation.

Professional lessons to adopt:

1. ReFusion must expose composition metadata to agents and UI tools:
   width, height, fps, duration, current time, origin, and safe zones.
2. ReFusion must evaluate every frame deterministically.
3. ReFusion must preserve identity when props/style/text/motion change.
4. ReFusion must support local time within scene/layer scopes.
5. Preview and export must read the same graph/evaluator truth.

### 1.4 What We Must Not Copy

Do not embed Remotion or HyperFrames as a second runtime for normal editing.

ReFusionXx is a native creative editor. The goal is not:

```text
MCP -> HTML/React sidecar -> prerendered video -> imported clip
```

The goal is:

```text
MCP/manual/script/template -> ReFusion native graph -> editable native preview/export
```

External engines may inspire adapters, templates, effect recipes, and benchmark
tests, but they must not become a parallel truth source for normal editable
authoring.

---

## 2. Non-Negotiable Product Contract

### 2.1 Single Source Of Creative Truth

All authoring sources must emit the same command type:

```text
Manual UI
Paste Script
MCP Agent
Templates
Tap List
Future Tools
        |
        v
Canonical SceneCommand
        |
        v
Unified Apply Engine
        |
        v
CreativeGraph / MotionProject
        |
        v
Timeline Projection
        |
        v
Frame Evaluator
        |
        v
Preview Renderer + Export Renderer
```

If MCP can create a shape, Manual UI must create the same command family.

If Manual UI can move a shape, MCP must be able to inspect the moved geometry
through the same graph.

If Paste Script creates a shape, it must appear in the same timeline projection
and be editable by Manual UI and MCP.

### 2.2 No Metadata-Only Visual Success

This is forbidden:

```text
solid/background -> project.metadata.backgroundColor only
```

This is required:

```text
solid/background
-> real shape layer
-> real rectangle element
-> full canvas width/height
-> visual.color property
-> timeline clip
-> evaluated frame state
-> preview renderer output
```

Metadata may describe or optimize. Metadata must not replace visible graph
truth.

### 2.3 No Placeholder-Only Timeline Truth

A timeline clip is valid only if it references a real graph target:

```text
timelineClipId
layerId
elementId
trackKind
startMs
durationMs
zIndex
sourceCommandId
```

The old placeholder pattern is not enough:

```text
TimelineClipType.placeholder
visualKind: shape
but no MotionElementModel
```

Placeholder may exist only for planned/unimplemented commands and must not
produce `appApplied=true`.

### 2.4 Apply Means Rendered

`appApplied=true` is valid only after all checks pass:

```json
{
  "commandAccepted": true,
  "targetResolved": true,
  "graphApplied": true,
  "timelineVisible": true,
  "frameEvaluated": true,
  "rendererNodeVisible": true,
  "exportPathCompatible": true,
  "targetLayerId": "...",
  "targetElementId": "...",
  "timelineClipId": "...",
  "operationApplied": "insert|update|motion|effect"
}
```

Any missing proof must return a blocker, not success.

---

## 3. Current Failure Anatomy

### 3.1 Failing Background Path

Current observed path:

```text
MCP get_layers returns solid row
-> McpSceneCommandDispatcher emits applySolidLayer
-> _applyRemoteSolidLayerIfNeeded runs
-> project.metadata['backgroundColor'] updated
-> _ensureMcpSolidLayerTimelineClipInState adds placeholder clip
-> no MotionLayerModel added
-> no MotionElementModel added
-> _motionCompositionForCurrentState may not create shape content
-> MotionShapePreviewOverlay sees no shape
-> canvas stays black
```

This explains why the database and revision look successful while the app does
not visually change.

### 3.2 Why Text Sometimes Works

MCP text uses `BasicMotionTextElementAuthoringService.insertTextPreset(...)`.
That path creates real motion text element state and text timeline entries.

Text works when it becomes graph/render truth.

Solid fails because it is treated as metadata/timeline placeholder.

### 3.3 Why Video/Shape/Effects Have Similar Risk

Any layer family can fail if it follows one of these patterns:

- writes only metadata;
- writes only Supabase rows;
- writes only timeline placeholder;
- writes only `payload.updates`;
- writes motion/effects without lowering to channels;
- applies renderer-only style not represented in the graph;
- returns success before proof.

Therefore the fix must be universal.

---

## 4. Canonical Command Model

### 4.1 Command Envelope

Every source must emit:

```json
{
  "schema": "refusion.scene-command/v1",
  "source": "manual_ui|mcp_agent|paste_script|template|tap_list",
  "commandId": "cmd_...",
  "projectId": "...",
  "compositionId": "...",
  "operation": "insertNode|updateNode|deleteNode|setProperty|applyEffect|applyMotion|trimClip|splitClip",
  "target": {
    "mode": "new|layerId|elementId|timelineClipId|selection|query",
    "id": "...",
    "kind": "background|shape|text|image|video|audio|effect"
  },
  "payload": {},
  "expectedRevision": 0,
  "dryRun": false
}
```

### 4.2 Operation Families

Allowed operation families:

| Operation | Purpose | Produces |
|---|---|---|
| `insertNode` | create a new editable node | graph node + clip |
| `updateNode` | mutate existing node | same node id |
| `deleteNode` | remove node | graph + timeline deletion |
| `setProperty` | set typed property | property assignment/channel |
| `applyEffect` | apply effect | effect node or property set |
| `applyMotion` | apply animation | motion channels |
| `trimClip` | adjust timeline range | timeline + layer range |
| `splitClip` | split timeline span | two linked graph/timeline spans |

No source may invent a one-off operation outside this table without extending
the command schema, tests, registry, and proof contract.

### 4.3 Source Adapters

Each source becomes a thin adapter:

```text
Manual Add Shape button
-> insertNode(kind=shape)

MCP insert_layer(kind=shape)
-> insertNode(kind=shape)

Paste Script shape block
-> insertNode(kind=shape)

Template background block
-> insertNode(kind=background)
```

Source adapters do not mutate the editor directly.

---

## 5. Universal Node Model

### 5.1 Node Families

Every visible/editable thing belongs to a node family:

| Family | Graph representation | Timeline track | Renderer |
|---|---|---|---|
| `background` | shape rectangle element | shape/background track | shape preview/export |
| `shape` | shape element | shape track | shape preview/export |
| `text` | text element | text track | text preview/export |
| `image` | image element | image track | image preview/export |
| `video` | video element | video track | native/Flutter preview/export |
| `audio` | audio element | audio track | audio mixer/export |
| `effect` | effect node/channel | effect/adjustment track | renderer effect adapter |

Background is not special metadata. It is a shape-family node with background
role metadata.

### 5.2 Required Graph Identity

Each node must have stable ids:

```text
nodeId
layerId
elementId
timelineClipId
sourceCommandId
remoteLayerId (optional)
aliases (optional)
```

Manual edits, MCP updates, scripts, and future tools must resolve the same ids.

### 5.3 Required Property Surface

Baseline properties supported by all visual nodes:

```text
transform.position.x
transform.position.y
transform.scale.x
transform.scale.y
transform.rotation.degrees
visual.opacity
visual.color (where applicable)
visual.blur.amount
```

Shape/background required properties:

```text
visual.color
shape.width
shape.height
shape.cornerRadius
visual.borderColor
visual.borderWidth
effect.shadow.*
```

Text required properties:

```text
text.content
text.fontSize
text.fontWeight
text.lineHeight
visual.color
```

Media required properties:

```text
media.assetId
media.sourceRange
crop/mask/border/glow/shadow
```

---

## 6. Immediate Fix: Background/Solid Truth

### 6.1 New Rule

Every MCP `solid`, `background`, or full-canvas rectangle must become a real
shape node.

### 6.2 Lowering Contract

Input examples:

```json
{"layer_kind": "solid", "payload": {"fillColor": "#FFFFFF"}}
```

```json
{"type": "shape", "shape": "rect", "payload": {"backgroundColor": "#FFFFFF"}}
```

```json
{"operation": "set_background_color", "payload": {"color": "#FFFFFF"}}
```

All lower to:

```text
insertNode(kind=background)
```

or, if target exists:

```text
updateNode(kind=background)
```

### 6.3 Graph Output

Create/update:

```text
MotionLayerModel(
  id: stable background layer id,
  kind: MotionLayerKind.shape,
  visibleRange: command time range,
  zIndex: background zIndex,
)

MotionElementModel(
  id: stable background element id,
  kind: MotionElementKind.shape,
  shapeKind: MotionShapeKind.rectangle,
  localRange: layer-local visible range,
  properties:
    positionX = 0
    positionY = 0
    scaleX = 1
    scaleY = 1
    opacity = 1
    width = canvasWidth
    height = canvasHeight
    cornerRadius = 0
    visual.color = requested color
)
```

### 6.4 Timeline Output

Create/update:

```text
TimelineClipData(
  id: timelineClipId,
  type: generated/shape (not metadata-only placeholder),
  visualKind: shape,
  contentKind: generatedShape/background,
  label: "Background",
  durationTime: layer duration,
)
```

If current enum values do not yet have generated shape/background clip type,
use the closest existing type only as a compatibility wrapper, but the clip must
carry a real graph target id in metadata/binding.

### 6.5 Renderer Output

The evaluator must see the shape element and `MotionShapePreviewOverlay` must
draw it. The fallback canvas color may remain as a base color, but the command
is not considered applied unless the background shape node is visible.

### 6.6 Update Behavior

If a background already exists:

- changing color updates the same element;
- changing duration updates the same timeline clip/layer range;
- applying blur/effect applies to the same element;
- MCP must not insert stacked full-canvas backgrounds unless the user explicitly
  asks for multiple layers.

---

## 7. Target Resolver

### 7.1 Purpose

Every update/motion/effect command must resolve a target before mutation.

### 7.2 Target Search Order

Use this order:

1. `elementId`
2. `layerId`
3. `timelineClipId`
4. `remoteLayerId`
5. `targetLayerId`
6. aliases
7. selected node
8. visible matching node at playhead
9. semantic role (`background`, `title`, `primaryVideo`)

### 7.3 Fail-Closed Rules

If target is missing:

```text
TARGET_NOT_FOUND
```

If multiple targets match:

```text
AMBIGUOUS_TARGET
```

If target is wrong kind:

```text
TARGET_KIND_MISMATCH
```

No update may silently become insert.

### 7.4 Geometry Awareness

Resolver must expose geometry for every visible node:

```json
{
  "elementId": "...",
  "kind": "shape",
  "bounds": {"x": 0, "y": 0, "width": 1080, "height": 1920},
  "zIndex": 0,
  "visibleAtPlayhead": true,
  "timelineClipId": "..."
}
```

When the user manually moves a shape, the graph properties change. MCP must
read that changed geometry from the graph, not from stale cloud payloads.

---

## 8. Spatial Truth API

### 8.1 Required Read Tools

Expose the same truth to MCP and internal diagnostics:

```text
get_canvas_metadata
get_composition_truth
get_timeline_state
get_element_geometry
evaluate_frame
get_renderer_capabilities
```

### 8.2 Canvas Metadata

Must include:

```json
{
  "width": 1080,
  "height": 1920,
  "fps": 30,
  "durationMs": 14000,
  "coordinateSystem": "center-origin",
  "anchors": {
    "center": {"x": 0, "y": 0},
    "topRight": {"x": 540, "y": -960}
  },
  "safeZones": {}
}
```

### 8.3 Element Geometry

Must be evaluated from current graph/frame:

```json
{
  "elementId": "...",
  "kind": "background",
  "position": {"x": 0, "y": 0},
  "size": {"width": 1080, "height": 1920},
  "worldBounds": {},
  "timelineClipId": "...",
  "zIndex": 0
}
```

### 8.4 Frame Evaluation

`evaluate_frame(timeMs)` must report what is visible at that exact time:

```json
{
  "timeMs": 0,
  "visibleNodes": [
    {
      "elementId": "background",
      "kind": "shape",
      "visible": true,
      "rendererFamily": "shape"
    }
  ]
}
```

---

## 9. Unified Apply Engine

### 9.1 Required Pipeline

Every command must pass:

```text
validate schema
-> resolve target
-> dry-run plan
-> apply transaction
-> update graph
-> update timeline projection
-> evaluate frame
-> emit preview/export visual program
-> produce proof
```

### 9.2 Transaction Output

Each transaction returns:

```json
{
  "operationApplied": "insert",
  "createdNodeCount": 1,
  "updatedNodeCount": 0,
  "createdTimelineClipCount": 1,
  "updatedTimelineClipCount": 0,
  "targetElementId": "...",
  "targetLayerId": "...",
  "timelineClipId": "..."
}
```

### 9.3 Rebase / Revision Conflict

If app revision moved:

1. reload current graph;
2. re-resolve target;
3. rebase property update;
4. retry if deterministic;
5. fail with `REVISION_CONFLICT_UNRESOLVED` if unsafe.

Do not drop command silently.

---

## 10. Timeline Projection Truth

### 10.1 Projection Rule

Timeline is a projection of graph, not a separate truth.

Every visible graph node must project to a clip.

Every visible clip must resolve back to a graph node.

### 10.2 Background Timeline Requirements

MCP background must show:

- one clip in shape/background track;
- label from command or `Background`;
- duration equal command duration or composition duration;
- linked `layerId` and `elementId`;
- zIndex behind normal shapes/text/media.

### 10.3 Manual / MCP / Script Parity

These three operations must produce equivalent graph/timeline output:

```text
Manual UI -> Add background
MCP -> insert background
Paste Script -> background rectangle
```

Tests must compare graph node kind, properties, timeline clip count, and frame
evaluation output.

---

## 11. Motion And Effects Lowering

### 11.1 Motion

Any motion input:

```text
payload.motion
payload.animation
updates.motion
updates.animation
apply_motion_patch
apply_keyframes
set_element_transform
```

must lower to:

```text
MotionPropertyChannelModel
```

No command is successful if motion stays only in raw payload metadata.

### 11.2 Effects

Any effect input:

```text
blur
shadow
glow
border
mask
color grade
grain
vignette
```

must lower to either:

- typed property assignments;
- typed property channels;
- effect node with renderer capability declaration.

If renderer cannot draw it:

```text
RENDERER_CAPABILITY_MISSING
```

Do not claim `appApplied=true`.

### 11.3 Background Effects

Background shape must support at least:

- color;
- opacity;
- blur where supported;
- shadow/glow where supported;
- motion channels for position/scale/opacity if user requests.

---

## 12. Renderer Proof

### 12.1 Proof Levels

Proof levels:

| Level | Meaning |
|---|---|
| `dataApplied` | command saved locally |
| `graphApplied` | node/channel exists in graph |
| `timelineVisible` | clip exists and maps to node |
| `frameEvaluated` | evaluator sees node at time |
| `rendererPrepared` | renderer capability exists |
| `rendererVisible` | renderer emitted visible output |

### 12.2 Required MCP Ack

MCP write result:

```json
{
  "ok": true,
  "commandId": "...",
  "appApplied": false,
  "status": "pending_renderer_proof"
}
```

Only app can later mark:

```json
{
  "appApplied": true,
  "proof": {
    "graphApplied": true,
    "timelineVisible": true,
    "frameEvaluated": true,
    "rendererVisible": true
  }
}
```

### 12.3 Device Proof

At least one E2E test must capture:

- before screenshot;
- after screenshot;
- target color/shape/text visible;
- text/shape count;
- command proof payload.

---

## 13. Implementation Phases

### PUCTAS-00: Pre-Build Gate

Before each slice, publish:

- current ReFusion state;
- HyperFrames lesson;
- Remotion lesson;
- gap list;
- decision table (`keep`, `upgrade`, `replace`, `block`);
- selected execution scope;
- tests;
- rollback plan.

No code starts before this report.

### PUCTAS-01: Canonical Command Foundation

Goal: define the common command envelope and command families.

Tasks:

- add domain command models if missing;
- map current `ProfessionalSceneCommand` to the canonical schema;
- define source adapters for MCP/manual/script/template;
- add command validation;
- add dry-run planning type.

Acceptance:

- one test proves MCP and manual shape insert compile to same operation family;
- unsupported command fails with structured error;
- no renderer changes.

### PUCTAS-02: MCP Solid/Background To Real Shape Node

Goal: fix current visible failure.

Tasks:

- replace metadata-only solid apply with graph-backed background node apply;
- create/update `MotionLayerModel(kind: shape)`;
- create/update `MotionElementModel(kind: shape, rectangle)`;
- assign full canvas size and `visual.color`;
- preserve `metadata.backgroundColor` only as compatibility, not truth;
- create linked timeline clip;
- update represented-local check to use graph target;
- add tests for insert/update/no duplicate.

Acceptance:

- MCP white background appears on canvas.
- Timeline has one background/shape clip.
- `MotionShapePreviewOverlay` sees a visible shape.
- Re-sending color update changes same element.
- No duplicate full-canvas backgrounds unless explicitly requested.

### PUCTAS-03: Manual Shape / MCP Shape / Script Shape Parity

Goal: same path for all shape insertions.

Tasks:

- route Manual Add Shape through same command family;
- route Paste Script shape through same command family;
- route MCP shape through same command family;
- normalize default shape ids/properties;
- compare outputs in parity tests.

Acceptance:

- three sources create equivalent shape graph nodes;
- manual move changes graph geometry;
- MCP reads moved geometry.

### PUCTAS-04: Unified Target Resolver

Goal: one resolver for text/shape/background/image/video.

Tasks:

- generalize current MCP text resolver;
- support aliases and timeline clip bindings;
- expose ambiguous target diagnostics;
- block unresolved updates;
- add geometry-aware resolution at playhead.

Acceptance:

- "same shape" updates selected/targeted shape;
- ambiguous shape update returns `AMBIGUOUS_TARGET`;
- missing target returns `TARGET_NOT_FOUND`;
- no update becomes insert silently.

### PUCTAS-05: Timeline Projection Contract

Goal: every graph node has a timeline clip and every clip maps back.

Tasks:

- add projection validator;
- validate graph-to-clip links;
- validate clip-to-graph links;
- add proof fields for timeline visibility;
- migrate background placeholder clip to graph-linked clip.

Acceptance:

- background clip resolves to background element;
- text clip resolves to text element;
- shape clip resolves to shape element;
- visual node without timeline clip fails proof.

### PUCTAS-06: Spatial Truth API

Goal: agents and UI tools can inspect exact canvas truth.

Tasks:

- implement `get_canvas_metadata`;
- implement `get_element_geometry`;
- implement `get_timeline_state`;
- implement `get_composition_truth`;
- implement `evaluate_frame`;
- expose same data internally and through MCP.

Acceptance:

- after manual shape move, MCP sees new x/y;
- after MCP insert background, manual inspector sees geometry;
- frame evaluation matches preview.

### PUCTAS-07: Motion/Effect Lowering

Goal: no raw animation/effect payload remains as truth.

Tasks:

- lower motion recipes to channels;
- lower effect payloads to typed properties/effect nodes;
- add capability check before apply;
- block unsupported renderer capability.

Acceptance:

- `apply_motion` on shape creates channels;
- `apply_effect` on background creates typed effect data;
- unsupported effect fails before success.

### PUCTAS-08: Renderer Proof Contract

Goal: appApplied means rendered.

Tasks:

- add proof object from apply engine;
- prove graph/timeline/evaluator/renderer states;
- wire proof to MCP ack;
- add `wait_for_apply` strict behavior.

Acceptance:

- DB-only write cannot return appApplied;
- metadata-only change cannot return appApplied;
- background insert returns appApplied only after visible shape proof.

### PUCTAS-09: Preview/Export Parity

Goal: preview and export share graph/evaluator truth.

Tasks:

- verify background shape export path;
- verify shape/text/media preview/export parity;
- add snapshot or structured parity tests.

Acceptance:

- background visible in preview and export model;
- shape position matches preview/export;
- parity score recorded in report.

### PUCTAS-10: Device E2E

Goal: prove actual app behavior.

Scenario:

1. open fresh composition;
2. MCP insert white background;
3. verify canvas turns white;
4. verify timeline clip exists;
5. MCP insert shape;
6. manual move shape;
7. MCP reads geometry;
8. MCP updates same shape color;
9. paste script animates same shape;
10. verify no duplicate nodes and all visible.

Acceptance:

- screenshots captured;
- timeline count recorded;
- geometry before/after recorded;
- command proof recorded;
- branch checkpoint pushed.

---

## 14. Test Matrix

### 14.1 Unit Tests

- command schema validation;
- background lowerer;
- target resolver;
- graph mutation transaction;
- timeline projection;
- frame evaluator visibility;
- motion/effect lowering.

### 14.2 Integration Tests

- MCP background -> shape node;
- manual background -> same shape node;
- script background -> same shape node;
- MCP update background -> same element;
- MCP shape + manual move + MCP geometry read.

### 14.3 Device Tests

- physical Android device;
- fresh composition;
- composition with existing video;
- composition with existing text;
- app foreground;
- app background/return;
- MCP connection active.

### 14.4 Negative Tests

- update missing target;
- ambiguous target;
- unsupported effect;
- renderer missing capability;
- stale revision;
- app not in editor.

---

## 15. Capability Benchmark Matrix Requirement

Every capability touched by this plan must have a benchmark record:

```json
{
  "capabilityId": "shape.background.fullCanvas",
  "refusionScore": {
    "visualQuality": 0,
    "temporalAccuracy": 0,
    "parameterDepth": 0,
    "performance": 0,
    "previewExportParity": 0,
    "editability": 0,
    "determinism": 0,
    "crossDeviceStability": 0
  },
  "referenceSystems": {
    "hyperframes": "layout/CSS node truth + seek-driven timeline",
    "remotion": "composition config + frame deterministic component truth"
  },
  "decision": "keep|upgrade|adoptIdea|prerenderOnly|block",
  "nextActions": []
}
```

Release rule:

- if visual quality < 4, upgrade before release;
- if preview/export parity < 4, block release;
- if editability < 4, do not ship as native editable capability;
- if determinism < 4, block MCP automation.

---

## 16. Performance Budgets

Initial budgets:

```text
command_normalization_p95 <= 20ms
target_resolution_p95 <= 25ms
graph_apply_p95 <= 40ms
timeline_projection_p95 <= 25ms
frame_eval_p95 <= 8ms on reference device
renderer_proof_p95 <= 120ms after local apply
MCP_to_visible_p95 <= 1000ms with realtime
MCP_to_visible_p95 <= 8000ms with polling fallback
```

If budgets are exceeded, the slice must record:

- measured latency;
- root cause;
- fallback behavior;
- owner;
- next action.

---

## 17. Rollback And Feature Flags

Every new capability must be behind a controlled gate until E2E passes:

```text
unifiedApply.backgroundShape.enabled
unifiedApply.shapeParity.enabled
unifiedApply.rendererProof.strict
```

Rollback strategy:

- feature flag off for runtime behavior;
- git revert for committed slice;
- do not leave half-enabled MCP path.

---

## 18. Stop List

Do not:

- create MCP-only visual behavior;
- write visual state only to metadata;
- add placeholder timeline clips without graph nodes;
- return appApplied from Supabase row success;
- allow update to become insert silently;
- infer renderer success from revision;
- build a second HTML/React runtime for normal editable authoring;
- touch Stage5/Live Scrub internals unless a specific approved slice requires it;
- add more creative tools before the apply spine is green.

---

## 19. First Slice Instruction For The Writer Agent

Start with:

```text
PUCTAS-02: MCP Solid/Background To Real Shape Node
```

Mandatory pre-build report:

- current `solid` code path;
- current `MotionShapePreviewOverlay` requirements;
- HyperFrames lesson: visible node must exist in source truth;
- Remotion lesson: composition dimensions and frame evaluation are explicit;
- selected scope;
- tests;
- rollback plan.

Implementation:

1. Add a testable helper if needed:
   `McpSolidBackgroundApplyPlanner` or equivalent.
2. Convert remote solid/background payload into a background shape command.
3. Create/update a real shape layer and rectangle element in MotionProject.
4. Add full-canvas width/height and `visual.color`.
5. Link timeline clip to graph target.
6. Keep metadata background color only as compatibility.
7. Add tests proving:
   - one insert creates one shape element;
   - update changes same element;
   - timeline clip maps to element;
   - frame evaluator sees shape;
   - no Live Scrub/Stage5 files touched.
8. Install on device and verify MCP white background becomes visible.

Do not proceed to PUCTAS-03 until PUCTAS-02 is device-green.

---

## 20. Final Definition Of Done

The apply spine is done only when this is true:

```text
Manual UI inserts shape
Paste Script inserts shape
MCP inserts shape
Template inserts shape
        |
        v
same command family
same graph model
same timeline projection
same frame evaluator
same preview renderer
same export renderer
same target resolver
same proof contract
```

The current background bug is closed only when:

- MCP creates a background and the canvas visibly changes;
- timeline shows a real linked background/shape clip;
- Manual UI can select/edit that background;
- MCP can read its geometry;
- MCP can update it without duplicates;
- script/template can produce the same result;
- appApplied is returned only after proof.

That is the professional baseline. Everything else builds on top of it.
