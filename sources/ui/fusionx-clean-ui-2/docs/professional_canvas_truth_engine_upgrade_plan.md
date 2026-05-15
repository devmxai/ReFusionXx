# Professional Canvas Truth Engine Upgrade Plan

## 0. Plan Status

Plan id: `PCTE`

This plan is the official corrective plan for ReFusionXx canvas truth, spatial
awareness, coordinate mapping, element geometry, and agent-visible canvas state.

It is not a replacement for:

- `professional_unified_runtime_apply_spine_closure_plan.md`
- `professional_in_app_virtual_project_workspace_single_creative_truth_plan.md`
- `professional_mcp_realtime_single_truth_failure_closure_plan.md`
- `professional_canvas_visual_motion_engine_plan.md`
- `professional_composition_identity_continuity_spatial_truth_plan.md`

It is the canvas-specific closure plan that plugs into those plans.

The required final architecture remains:

```text
Manual UI / MCP / Script / Templates / Imports
-> Canonical SceneCommand / CreativeTransactionEnvelope
-> Unified Apply Engine
-> Canonical Creative Graph
-> Master Timeline Graph
-> Master Frame Evaluator
-> Canvas Truth Engine
-> Preview Renderer / Playback Renderer / Export Renderer
-> Renderer Proof / Ack
```

No canvas, layer, text, shape, motion, transform, effect, handle, or MCP write
may bypass this spine.

## 1. Why This Plan Exists

The current visible failure:

```text
Story composition: 1080x1920
MCP writes text at x=540, y=960
Expected by agent: visual center
Actual in app: bottom-right / clipped near canvas edge
```

Root cause:

ReFusion currently stores visual positions in a center-origin canonical space,
where the Story canvas center is:

```text
x = 0
y = 0
```

But MCP payloads, snapshots, and some app-side compatibility paths sometimes
expose or consume:

```text
x = 540
y = 960
```

as if those fields are absolute top-left canvas pixels.

That value is valid only in an absolute/top-left coordinate space. In the
current canonical center-origin system it means the bottom-right boundary:

```text
canonical x = +540
canonical y = +960
```

The failure is therefore not a text-only bug. It is a canvas truth bug:

- raw `x/y` fields are ambiguous,
- app-side layer kinds parse coordinates differently,
- MCP snapshots leak absolute values under canonical field names,
- `get_element_geometry` can return database/static approximations instead of
  evaluated frame geometry,
- text, shape, image, video, handles, proof, and timeline overlays each perform
  canvas-to-viewport projection independently,
- agents can write spatial edits without a strict coordinate contract.

## 2. Reference Systems Reviewed

### 2.1 Remotion

Useful principles:

- Composition dimensions are explicit:
  `width`, `height`, `fps`, `durationInFrames`.
- Components can read the current composition through `useVideoConfig()`.
- Frame evaluation is deterministic through `useCurrentFrame()`.
- Layout is normally expressed in a known CSS top-left coordinate system.

What ReFusion should adopt:

- Mandatory composition spec for every spatial operation.
- Deterministic frame evaluation for preview, proof, and export.
- Clear authoring coordinate contract.

What ReFusion should not copy:

- React/browser runtime as source of truth.
- CSS layout as native editor truth.

### 2.2 HyperFrames

Useful principles:

- HTML root composition defines visible canvas bounds.
- Inspect/preview/render flows operate against the same composition document.
- Adapter pattern turns GSAP, WAAPI, Lottie, Three.js, CSS, and other systems
  into deterministic seek-driven output.
- Agent skills teach authors to query the canvas and use deterministic timing.

What ReFusion should adopt:

- Agent context tools that expose exact canvas dimensions and element geometry.
- Registry/adapters that lower creative recipes into native ReFusion graph data.
- Seek-driven deterministic proof.

What ReFusion should not copy:

- HTML as native source of truth.
- Browser-only layer model.

### 2.3 OpenCut

Useful principles:

- Stable track/element identity.
- Insert and update are different operations.
- Timeline state is editable data, not only pixels.

What ReFusion should adopt:

- Universal element references:
  `compositionId + sceneId + trackId + layerId + elementId + clipId`.
- Fail-closed updates when target identity is unresolved.

### 2.4 Fluvie

Useful principles:

- Flutter-native composition data.
- Frame rendering follows explicit composition dimensions.

What ReFusion should adopt:

- Native canvas/profile discipline.
- Frame capture/render proof from the same native frame pipeline.

### 2.5 ReFusion Decision

ReFusion must become:

```text
OpenCut-grade identity
+ Fluvie-grade native frame discipline
+ HyperFrames-grade agent inspectability
+ Remotion-grade composition/frame determinism
+ ReFusion-native creative graph and renderer
```

## 3. Non-Negotiable Canvas Principles

### 3.0 Mandatory Wireless Device Closure Gate

Every implementation phase in this plan must be closed through a real device
verification loop on the official connected wireless Android tablet before the
phase can be marked complete.

This is mandatory even when the phase is mostly domain/model/test work.

The closure loop is:

```text
1. Implement the phase.
2. Run the smallest relevant unit/integration tests.
3. Build/install the current app on the official connected wireless device.
4. Launch the app and create or open the target composition.
5. Execute the phase-specific manual/MCP/script scenario.
6. Capture screenshot(s), logs, and any MCP/app proof output.
7. Confirm the phase acceptance criteria.
8. Only then commit/push the checkpoint and mark the phase closed.
```

If a phase truly has no live UI path yet, the phase still requires:

```text
device_smoke_launched = true
app_foreground_verified = true
no_visual_path_reason = documented
next_visual_phase_that_consumes_this_work = documented
```

No phase may be closed with unit tests only when it changes, feeds, validates,
or constrains:

- canvas dimensions,
- coordinates,
- spatial placement,
- layer identity,
- timeline projection,
- renderer proof,
- MCP writes,
- script/template writes,
- manual UI insertion,
- motion/effect geometry,
- preview/export geometry.

#### 3.0.1 Required Device Evidence Per Phase

Each phase report must include:

```text
deviceSerial
packageName
installedVersion
commitHash
compositionPreset
canvasWidth
canvasHeight
scenarioPayloadsOrManualSteps
textLayerCountBeforeAfter
shapeLayerCountBeforeAfter
expectedBounds
renderedBounds
insideCanvas
timelineClipVisible
canvasScreenshotPath
logcatOrAppLogPath
passFail
rollbackCommand
```

#### 3.0.2 Pixel-Exact Canvas Standard

The professional canvas standard is pixel exact:

```text
composition pixels are the truth
viewport pixels are display only
screen pixels never become graph coordinates
every authored element has evaluated bounds in composition pixels
every rendered element has verified bounds in viewport pixels
canvas clipping is mandatory for authored content
```

Allowed visual error:

```text
center position error <= 2 composition pixels
full-canvas background error = 0 composition pixels
manual/MCP equivalent operation geometry delta <= 2 composition pixels
transform handle alignment error <= 2 viewport pixels at 1x
off-canvas authored content = fail unless allowOverflow=true
```

### 3.1 One Canonical Storage Space

The internal creative graph uses one canonical coordinate space:

```text
canonicalCoordinateSpace = centerOrigin
unit = compositionPixels
origin = canvas center
x range = [-canvasWidth / 2, canvasWidth / 2]
y range = [-canvasHeight / 2, canvasHeight / 2]
positive x = right
positive y = down
```

For Story `1080x1920`:

```text
center = { x: 0, y: 0 }
topLeft = { x: -540, y: -960 }
bottomRight = { x: 540, y: 960 }
```

### 3.2 Explicit External Spaces

External authoring APIs may accept additional spaces, but never implicitly:

```text
centerOrigin
topLeftAbsolute
normalizedCanvas
anchorZone
screenViewport
```

Every external coordinate write must provide one of:

- `coordinateSpace`
- semantic `anchor`
- semantic `zone`
- explicit absolute fields such as `centerX/centerY`
- explicit normalized fields such as `normalizedX/normalizedY`

Raw `x/y` without a declared space is forbidden for new MCP/script/template
writes.

### 3.3 No Ambiguous Coordinate Success

If a command says:

```json
{ "x": 540, "y": 960 }
```

inside a `1080x1920` Story composition without coordinate metadata, the runtime
must not guess.

It must return:

```text
AMBIGUOUS_COORDINATE_SPACE
```

with a repair hint:

```text
Use x=0,y=0 with coordinateSpace=centerOrigin,
or centerX=540,centerY=960 with coordinateSpace=topLeftAbsolute,
or anchor=center.
```

### 3.4 Viewport Is Not Composition

Zoom, pan, phone screen pixels, rounded preview rect, and stage viewport are UI
concerns only.

They must never mutate creative graph coordinates.

### 3.5 Author Content Is Clipped By Canvas

Authored visual content must be rendered inside the official composition canvas
and clipped by the official canvas boundary unless:

```text
allowOverflow = true
```

Editor handles may overflow. Authored pixels may not.

### 3.6 Agent Spatial Sight Requirement

The agent must be able to inspect the canvas as a professional editor would:

```text
active composition dimensions
official canvas bounds
current frame/time
selected elements
visible elements
element ids
element intrinsic sizes
element world bounds
element viewport bounds
z-order
safe-area status
timeline clip ids
motion/effect channels
last manual edits
last MCP/script/template edits
```

If the agent cannot read these facts from local evaluated truth, it must not
guess spatial edits.

### 3.7 Universal Node Spatial Contract

The canvas contract applies to every visible node kind:

```text
text
shape
solid/background
image
video
adjustment
effect instance
mask
motion path
template element
future visual node
```

Each node must support:

```text
stable identity
canonical bounds
intrinsic size when applicable
anchor/pivot
transform
timeline clip mapping
renderer support status
export support status
proof status
```

No node kind may maintain its own independent coordinate rules.

### 3.8 Canvas Closure Rule

No object may visually appear outside the official canvas frame unless its graph
node explicitly declares:

```text
allowOverflow = true
```

When `allowOverflow=false`, the runtime must enforce:

```text
content clipped by official canvas clip
hit testing restricted to visible canvas content
proof reports clipped bounds
export output matches preview clipping
```

The rounded editor preview frame is a UI representation of the official canvas
clip. It must not be bypassed by MCP, script, templates, manual add buttons, or
legacy overlays.

### 3.9 Phase Closure Rule

Every phase must end with a written closure note:

```text
what changed
what old path was removed/adapted
what tests passed
what device scenario was run
what screenshot/log proves it
what remains out of scope
whether the phase is closed or blocked
```

If any device scenario fails, the phase is blocked. The implementer must not
move to the next phase until the failure is fixed or explicitly escalated.

## 4. Current ReFusion Gaps To Close

### 4.1 MCP Raw Coordinate Writes

MCP currently permits raw `x/y` values to be stored and later interpreted by
different code paths.

Required fix:

Create one `CanvasCoordinateContract` and route all MCP insert/update/transform
coordinates through it.

### 4.2 Layer-Kind Coordinate Divergence

Text, shape, solid/background, image, video, and transform handles do not all
parse coordinates through the same service.

Required fix:

All layer kinds must call the same `CanvasCoordinateMapper`.

### 4.3 Snapshot Mismatch

Editor snapshots can expose absolute canvas center values under canonical
`x/y` names while the advertised coordinate system is center-origin.

Required fix:

Snapshots must expose both:

```json
{
  "position": {
    "x": 0,
    "y": 0,
    "coordinateSpace": "centerOrigin"
  },
  "absoluteCenter": {
    "x": 540,
    "y": 960,
    "coordinateSpace": "topLeftAbsolute"
  }
}
```

### 4.4 Geometry Is Not Evaluated Frame Truth

`get_element_geometry` must not be a static database approximation.

Required fix:

It must evaluate the same frame graph used by preview/export at `timeMs`.

### 4.5 Fragmented Projection

PreviewStage exposes a canvas rect, but text, shape, image, video, and handles
perform independent projection logic.

Required fix:

Introduce one `CanvasViewportProjector` for:

- preview overlays,
- transform handles,
- canvas hit testing,
- renderer proof,
- screenshot diagnostics.

### 4.6 Agent Lacks Reliable Spatial Sight

Agents can read canvas metadata, but not a single evaluated spatial scene
snapshot with all visible elements and bounds.

Required fix:

Add `get_spatial_scene_snapshot`.

## 5. Target Architecture

### 5.1 CompositionProfile And ViewportProjectionState

Canvas truth is split into two objects.

`CompositionProfile` is creative/export truth:

```text
CompositionProfile
  projectId
  compositionId
  sceneId
  width
  height
  fpsNumerator
  fpsDenominator
  durationMs
  durationInFrames
  pixelAspectRatio
  aspectPreset
  canonicalCoordinateSpace
  axisDirection
  origin
  boundsCenterOrigin
  boundsTopLeftAbsolute
  safeAreas
  guides
  compositionRevision
  graphRevision
```

`ViewportProjectionState` is editor/display truth:

```text
ViewportProjectionState
  compositionId
  devicePixelRatio
  stageRect
  canvasRect
  viewportScale
  viewportOffset
  editorPreviewClipRadius
  chromeInsets
  screenshotScale
```

Rules:

- `CompositionProfile` is used by graph, timeline, frame evaluator, export, and
  MCP spatial validation.
- `ViewportProjectionState` is used by pointer input, editor handles,
  screenshots, visual proof, and preview projection.
- `ViewportProjectionState` must never become creative graph truth.
- Rounded preview corners are editor chrome by default. Export/composition
  clipping is rectangular unless the user explicitly authors a rounded mask.
- Both objects must be derived from the active local composition and current
  preview state, not from MCP guesses.

### 5.2 CanvasCoordinateMapper

One service must provide all conversions:

```text
toCanonical(input, CanvasProfile) -> CanonicalPoint
fromCanonical(point, CanvasProfile, targetSpace) -> ExternalPoint
rectToCanonical(inputRect, CanvasProfile) -> CanonicalRect
rectToViewport(canonicalRect, CanvasProfile, canvasRect) -> ScreenRect
```

Supported input spaces:

```text
centerOrigin
topLeftAbsolute
normalizedCanvas
anchorZone
screenViewport
legacyInferred
```

`legacyInferred` is temporary and may only be used inside compatibility
adapters. New writes cannot use it.

### 5.3 CanvasSpatialIntent

Agents and UI should prefer semantic placement:

```text
anchor = center | topLeft | topCenter | topRight |
         centerLeft | centerRight |
         bottomLeft | bottomCenter | bottomRight |
         goldenTop | goldenBottom |
         upperThird | middleThird | lowerThird

zone = fullCanvas | titleSafe | actionSafe | upperHalf |
       lowerHalf | leftHalf | rightHalf | customRect

fit = preserveSize | contain | cover | fill | scaleToFit
```

The solver converts these to canonical geometry.

### 5.4 CanvasGeometrySnapshot

For every evaluated frame:

```text
CanvasGeometrySnapshot
  canvasProfile
  elements[]
    layerId
    elementId
    timelineClipId
    kind
    name
    source
    canonicalPosition
    absoluteCenter
    intrinsicSize
    localBounds
    worldBounds
    viewportBounds
    transformedCorners
    axisAlignedBounds
    anchor
    pivot
    rotation
    scale
    opacity
    zIndex
    visibleAtFrame
    clippedByCanvas
    safeAreaStatus
    occlusion
    rendererSupport
    exportSupport
```

### 5.5 Spatial Scene Snapshot MCP Tool

Add an MCP-visible tool backed by local/evaluated truth:

```text
refusion.get_spatial_scene_snapshot
```

Returns:

- active CanvasProfile,
- selected layer/element ids,
- visible element geometry,
- timeline clip mapping,
- z-order,
- collision/overflow diagnostics,
- recommended semantic targets.

The agent must be trained to call this before spatial edits.

### 5.6 Spatial Plan Validator

Add:

```text
refusion.validate_spatial_plan
```

It takes proposed create/update/move/effect/motion commands and returns:

```text
valid | invalid | ambiguous
canonicalized commands
target resolution
expected geometry
layout warnings
repair hints
```

No write is accepted when validation fails.

### 5.7 Formal Versioned Contracts

The writer agent must not invent payload shapes. These contracts are mandatory
versioned DTOs.

#### 5.7.1 CoordinateInputV1

```json
{
  "schema": "refusion.canvas.coordinateInput.v1",
  "space": "centerOrigin|topLeftAbsolute|normalizedCanvas|anchorZone|screenViewport",
  "unit": "compositionPx|normalized|viewportPx",
  "x": 0,
  "y": 0,
  "centerX": 540,
  "centerY": 960,
  "normalizedX": 0.5,
  "normalizedY": 0.5,
  "anchor": "center",
  "zone": "titleSafe",
  "basis": {
    "compositionId": "uuid",
    "compositionRevision": 12,
    "snapshotId": "uuid",
    "frame": 0
  }
}
```

Rules:

- `space` is required for numeric writes.
- `screenViewport` is accepted only from live pointer/handle readback with a
  contemporaneous `ViewportProjectionState`.
- MCP, scripts, templates, and imports cannot write `screenViewport`.
- Conflicting fields fail with `CONFLICTING_COORDINATE_FIELDS`.
- Missing space for raw `x/y` fails with `AMBIGUOUS_COORDINATE_SPACE`.

#### 5.7.2 CanvasDiagnosticV1

```json
{
  "schema": "refusion.canvas.diagnostic.v1",
  "code": "AMBIGUOUS_COORDINATE_SPACE",
  "severity": "error|warning|info",
  "message": "Raw x/y require coordinateSpace.",
  "repairHint": "Use anchor=center or centerX/centerY.",
  "fieldPath": "payload.props.x",
  "blocking": true
}
```

#### 5.7.3 SpatialSceneSnapshotV1

```json
{
  "schema": "refusion.canvas.spatialSceneSnapshot.v1",
  "snapshotId": "uuid",
  "composition": "CompositionProfile",
  "viewport": "ViewportProjectionState",
  "frame": "FrameEvaluationRequest",
  "selection": {
    "layerIds": [],
    "elementIds": [],
    "timelineClipIds": []
  },
  "elements": [],
  "diagnostics": []
}
```

#### 5.7.4 RendererProofV1

```json
{
  "schema": "refusion.canvas.rendererProof.v1",
  "commandId": "uuid",
  "compositionId": "uuid",
  "frameEvaluationId": "uuid",
  "visualProgramHash": "sha256",
  "previewRendererVersion": "string",
  "exportRendererVersion": "string",
  "expectedBounds": {},
  "evaluatedBounds": {},
  "renderedBounds": {},
  "insideCanvas": true,
  "timelineClipVisible": true,
  "visualBoundsVerified": true,
  "rendererApplied": true,
  "pixelDiff": null,
  "diffImagePath": null,
  "diagnostics": []
}
```

Self-asserted booleans are invalid. `rendererApplied` and
`visualBoundsVerified` must be produced from evaluated/measured bounds, not from
`didApply` or database success.

### 5.8 Transform Math Contract

All visible nodes use the same transform order:

```text
1. local content bounds
2. apply anchor/pivot offset
3. apply scale
4. apply rotation around pivot
5. apply translation in canonical center-origin composition pixels
6. resolve parent/world transform if nested
7. compute transformed corners
8. compute axis-aligned bounds
9. apply mask/crop
10. inflate visual bounds for effects such as shadow/glow/blur when applicable
11. intersect authored pixels with rectangular composition clip unless allowOverflow=true
12. project to viewport for preview/handles/proof
```

Node position semantics:

- Text position is the node anchor point, not baseline or top-left.
- Shape position is the shape anchor point.
- Image/video position is the media anchor point after fit/crop.
- Background/solid with `backgroundRole=canvas` ignores authored position and
  resolves to full-canvas bounds.
- Baseline, glyph bounds, and line boxes are text layout data, not primary node
  position.

### 5.9 Frame And Time Domain Contract

Geometry/proof must use frame identity, not bare milliseconds.

```text
FrameEvaluationRequest
  compositionId
  fpsNumerator
  fpsDenominator
  durationInFrames
  rootFrame
  rootTimeMs
  sceneFrame
  sceneTimeMs
  clipLocalFrame
  clipLocalTimeMs
  elementLocalFrame
  effectLocalFrame
  transitionProgress
  roundingMode = floor|round|ceil|exactFrame
```

Rules:

- Preview, scrub, proof, and export use the same `FrameEvaluationRequest`.
- Bare `timeMs` is allowed only for UI display and compatibility adapters.
- Proof/export requests must include frame identity and rounding mode.
- Any MCP command that references time must declare the time domain.

### 5.10 Stale Snapshot Guard

Every spatial update/move/effect/motion command must carry a basis:

```json
{
  "basisSnapshotId": "uuid",
  "basisCompositionRevision": 12,
  "basisGraphRevision": 41,
  "basisFrame": 30,
  "targetIdentity": {
    "layerId": "...",
    "elementId": "...",
    "timelineClipId": "..."
  },
  "boundsBefore": {}
}
```

If the current composition revision, graph revision, target identity, or
`boundsBefore` no longer matches, reject with:

```text
STALE_SPATIAL_SNAPSHOT
```

Repair hint:

```text
Call refusion.get_spatial_scene_snapshot again, then retry.
```

### 5.11 TextLayoutSnapshot Contract

Text geometry must include layout truth:

```text
TextLayoutSnapshot
  text
  fontFamily
  fontFingerprint
  fontLoaded
  fontSize
  fontWeight
  lineHeight
  letterSpacing
  textAlign
  maxWidth
  baseline
  ascent
  descent
  lineBoxes
  glyphBounds
  measuredBounds
  paintedBounds
  overflow
```

Rules:

- Text proof cannot pass while `fontLoaded=false`.
- Measurement properties and render properties must match.
- Multiline, wrapping, baseline, and alignment must be represented in geometry.
- Text visual bounds use painted bounds; editing frame bounds may be larger but
  must be named separately.

### 5.12 Registry And Capability Conformance Dependency

Canvas truth must consume `ProfessionalCreativeLibraryRegistry` conformance for
every component, effect, template, motion recipe, shape preset, and future node.

No registry item may be considered canvas-safe unless it declares:

```text
previewRendererSupport
exportRendererSupport
frameEvaluatorSupport
geometrySupport
proofSupport
editableBoundsSupport
supportedCoordinateSpaces
```

If any support field is missing, commands using that item fail or become
explicit `prerenderOnly`, never silent metadata-only success.

### 5.13 Local/Cloud MCP Contract Parity

Both MCP stacks must obey the same canvas contract:

- local Dart toolkit,
- Supabase Edge Function / cloud MCP.

Required conformance:

```text
same accepted coordinate inputs
same rejected ambiguous inputs
same diagnostic codes
same normalized canonical payload
same snapshot schema
same proof schema
same target resolution behavior
```

Every change to canvas coordinate semantics requires tests in both stacks.

### 5.14 Code Ownership And Legacy Cleanup Targets

Canvas truth ownership:

```text
CompositionProfile: domain canvas service
ViewportProjectionState: preview-stage/editor presentation service
CanvasCoordinateMapper: domain service, used by all writers/readers
CanvasViewportProjector: presentation service, used by overlays/handles/proof
CanvasGeometrySnapshot: frame evaluator output
SpatialSceneSnapshot: MCP/local evaluated projection
RendererProof: proof evaluator from measured/evaluated bounds
```

Legacy cleanup must explicitly cover these current paths:

```text
lib/features/editor/presentation/screens/fusionx_clean_ui_screen.dart
lib/features/editor/presentation/services/mcp_editor_layer_snapshot_builder.dart
lib/features/editor/presentation/widgets/preview_stage.dart
lib/features/editor/presentation/widgets/motion_text_preview_overlay.dart
lib/features/editor/presentation/widgets/motion_shape_preview_overlay.dart
lib/features/editor/presentation/widgets/motion_image_preview_overlay.dart
lib/features/editor/presentation/widgets/unified_canvas_transform_overlay.dart
lib/features/editor/domain/mcp/refusion_mcp_mvp_toolkit.dart
lib/features/editor/domain/mcp/refusion_mcp_tool_registry.dart
supabase/functions/mcp/index.ts
```

Approved compatibility adapters:

```text
LegacyMcpCoordinateAdapter
LegacySnapshotCoordinateAdapter
LegacyLayerPayloadAdapter
```

Forbidden outside approved adapters:

```text
manual half-canvas subtraction
manual viewport center addition
ad hoc coordinateSpace inference
publishing absolute center as x/y
reading DB payload geometry as proof
returning full-canvas placeholder geometry for arbitrary elements
```

Required cleanup checks:

```bash
rg "_mcpCanonicalCoordinateFromRemoteValue|_mcpRemoteCoordinateSpace|canvasSize\\.width / 2|canvasSize\\.height / 2" lib supabase/functions/mcp/index.ts
rg "computeLayerGeometry|full-canvas placeholder|appliedSuccessfully.*rendererApplied" lib supabase/functions/mcp/index.ts
rg "constraints.maxWidth|constraints.maxHeight" lib/features/editor/presentation/widgets/*preview_overlay.dart
```

Any match must either be removed, routed through the official mapper/projector,
or documented as an approved compatibility adapter.

## 6. Implementation Phases

### PCTE-00: Pre-Build Canvas Audit Gate

Before code:

1. Capture current device screenshot.
2. Dump current MCP layers.
3. Dump active canvas metadata.
4. Dump current app visual/timeline state.
5. Record the failing command:
   `Story 1080x1920 + text x=540,y=960`.
6. Confirm current actual behavior.

Exit criteria:

- Failure reproduced and archived.
- Current branch/commit recorded.
- Dirty worktree assessed.

### PCTE-01: CompositionProfile, ViewportProjectionState, And Coordinate Contract

Build:

- `CompositionProfile`
- `ViewportProjectionState`
- `CanvasCoordinateSpace`
- `CanvasCoordinateMapper`
- `CanvasSpatialIntent`
- `FrameEvaluationRequest`
- typed diagnostics:
  - `AMBIGUOUS_COORDINATE_SPACE`
  - `UNSUPPORTED_COORDINATE_SPACE`
  - `OUT_OF_CANVAS_BOUNDS`
  - `INVALID_CANVAS_PROFILE`
  - `STALE_SPATIAL_SNAPSHOT`

Rules:

- Internal canonical storage is center-origin.
- Composition truth and viewport/editor projection are separate objects.
- `screenViewport` is accepted only for pointer/readback flows.
- New writes must be explicit.
- Legacy inference is isolated and measurable.

Tests:

- Story center:
  `centerOrigin x=0,y=0 -> absoluteCenter 540,960`.
- Story absolute center:
  `topLeftAbsolute centerX=540,centerY=960 -> canonical 0,0`.
- Boundary:
  raw `x=540,y=960` without space -> fail.
- Normalized:
  `normalizedX=0.5,normalizedY=0.5 -> canonical 0,0`.

Device check:

- Mandatory wireless device smoke:
  - install the app,
  - launch editor,
  - create Story composition,
  - verify app foreground and canvas preset,
  - record that this phase is not yet wired into live placement if applicable.
- If any mapper result is exposed through MCP/app state in this phase, run the
  center placement scenario on device before closure.

### PCTE-02: MCP Coordinate Write Gate

Build:

- one MCP coordinate normalization boundary for:
  - `insert_layer`
  - `update_layer`
  - `set_element_transform`
  - `apply_motion_patch`
  - future script/template imports
- local/cloud MCP conformance tests for the same coordinate payloads.

Rules:

- New MCP writes cannot use ambiguous raw `x/y`.
- `x/y` are canonical center-origin only when declared or from trusted internal
  adapters.
- Absolute values use `centerX/centerY` or `coordinateSpace=topLeftAbsolute`.
- Semantic placement uses `anchor/zone`.
- Every spatial write includes `basisSnapshotId` or runs through
  `validate_spatial_plan` immediately before apply.
- Stale basis data fails with `STALE_SPATIAL_SNAPSHOT`.

Tests:

- MCP insert text `anchor=center` creates canonical `0,0`.
- MCP insert text `centerX=540,centerY=960` creates canonical `0,0`.
- MCP insert text raw `x=540,y=960` fails.
- MCP background `backgroundRole=canvas` canonicalizes to full canvas.

Device check:

- Install app.
- Create Story composition.
- MCP insert text centered.
- Verify text appears visually centered, not bottom-right.
- Capture screenshot and app/MCP proof.
- Verify authored text is clipped inside the official rounded Story canvas.
- Verify timeline shows exactly one text clip for the inserted text.

### PCTE-03: Snapshot Contract Cleanup

Build:

- snapshot payloads must expose canonical and absolute fields separately.
- existing `sync_editor_layers` and `get_layers` consumers must either migrate
  to the new shape or be wrapped by `LegacySnapshotCoordinateAdapter`.

Required snapshot shape:

```json
{
  "position": {
    "x": 0,
    "y": 0,
    "coordinateSpace": "centerOrigin"
  },
  "absoluteCenter": {
    "x": 540,
    "y": 960,
    "coordinateSpace": "topLeftAbsolute"
  },
  "bounds": {
    "coordinateSpace": "centerOrigin",
    "left": -100,
    "top": -40,
    "right": 100,
    "bottom": 40
  }
}
```

Rules:

- Never publish absolute center as canonical `x/y`.
- Never publish screen pixels as composition pixels.
- Every geometry field declares its coordinate space.
- Every snapshot includes `snapshotId`, `compositionRevision`, `graphRevision`,
  and `frame`.

Tests:

- Manual text at visual center snapshots as canonical `0,0`.
- MCP text at visual center snapshots as canonical `0,0`.
- Manual move by 100 px right snapshots as canonical `100,0`.
- Agent can compute delta from snapshot without guessing.

Device check:

- Add text manually.
- Move it.
- Ask MCP snapshot.
- Confirm reported canonical delta matches actual move.
- Capture before/after screenshots.
- Confirm the agent-visible geometry matches the actual visual movement in
  composition pixels.

### PCTE-04: Unified Canvas Projection

Build:

- `CanvasViewportProjector`
- one projection path for:
  - text overlay,
  - shape overlay,
  - image overlay,
  - video overlay,
  - transform handles,
  - proof bounds.
- Explicit migration of:
  - `motion_text_preview_overlay.dart`
  - `motion_shape_preview_overlay.dart`
  - `motion_image_preview_overlay.dart`
  - `unified_canvas_transform_overlay.dart`
  - `_CleanPreviewCanvas` call sites.

Rules:

- `PreviewStage.canvasRect` remains the viewport location of the official
  composition canvas.
- All authored content maps through projector.
- All authored content clips inside canvas.
- Handles may use a separate editor overlay space.

Tests:

- Text and shape at canonical `0,0` share the same visual center.
- Text and shape at canonical edge values clip identically.
- Handles align with element bounds at zoom 1x, 2x, and pan offsets.

Device check:

- Story canvas.
- Add background, text, shape.
- Zoom/pan preview.
- Verify content and handles stay aligned.
- Confirm no authored content escapes the official rounded canvas at any zoom.
- Confirm handle overlays can appear outside only as editor chrome, not authored
  content.

### PCTE-05: Evaluated Element Geometry

Build:

- `CanvasGeometrySnapshot` from frame evaluator truth.
- `get_element_geometry(FrameEvaluationRequest)` reads evaluated frame state,
  not only static DB payload.
- `TextLayoutSnapshot` for text nodes.

Rules:

- Geometry includes motion channels at the requested `FrameEvaluationRequest`.
- Geometry includes transforms, scale, rotation, masks, effects that inflate
  bounds, and canvas clipping.
- Geometry includes visible/timeline status.
- Geometry merges image fit, video transform, text layout, masks, blur/glow
  inflation, rotation corners, and timeline visibility.
- Cloud/local geometry APIs cannot return full-canvas placeholders for arbitrary
  elements.

Tests:

- Text with position keyframes returns different geometry at `t=0` and `t=500`.
- Rotation returns transformed corners and axis-aligned bounds.
- Scale pop-up returns changing bounds through frames.

Device check:

- MCP applies pop-up to text.
- Scrub/play.
- Query geometry at start/mid/end.
- Verify geometry and visual result match.
- Confirm evaluated bounds change with the motion and remain tied to the same
  element identity.

### PCTE-06: Spatial Scene Snapshot Tool

Build:

```text
refusion.get_spatial_scene_snapshot
```

It returns:

- `CanvasProfile`
- visible elements,
- selected elements,
- timeline mapping,
- element geometry,
- z-order,
- collision/overflow diagnostics,
- safe area status,
- natural language summary.

Rules:

- Snapshot is local/evaluated truth.
- Snapshot cannot be cloud-only truth.
- Snapshot cannot claim element visibility if it is not in canvas/timeline.

Tests:

- Empty Story composition returns no elements.
- Background + text returns two elements with correct bounds.
- Manual UI inserted element appears in snapshot.
- MCP inserted element appears in snapshot.
- Moving manually then querying snapshot reports new coordinates.

Device check:

- Manual add shape.
- Query snapshot.
- MCP updates same shape.
- Query snapshot again.
- Verify same identity and new geometry.
- Confirm the agent sees the exact manually changed position before applying
  its edit.
- Confirm no duplicate layer is created.

### PCTE-07: Spatial Solver And Semantic Tools

Build:

```text
position_at_anchor
fit_in_zone
align_to
keep_in_canvas
move_relative
scale_to_fit
validate_spatial_plan
```

Rules:

- Agents should prefer semantic placement over raw coordinates.
- Raw coordinate commands remain available only with explicit space.
- Solver uses real element intrinsic size and current bounds.

Tests:

- `position_at_anchor(center)` centers text.
- `position_at_anchor(topRight,padding=24)` computes correct canonical value.
- `fit_in_zone(fullCanvas)` for background covers exact canvas.
- `keep_in_canvas` prevents accidental overflow.

Device check:

- MCP creates title at center.
- MCP moves it top third.
- MCP moves it bottom center.
- Verify visually and through snapshot.
- Confirm pixel deltas match the solver output.
- Confirm `keep_in_canvas` blocks or corrects overflowing authored content.

### PCTE-08: Renderer Proof Upgrade

Build proof fields:

```json
{
  "canvasProfileResolved": true,
  "coordinateSpaceResolved": true,
  "targetResolved": true,
  "timelineClipExists": true,
  "frameEvaluated": true,
  "expectedBounds": {},
  "renderedBounds": {},
  "visualBoundsVerified": true,
  "insideCanvas": true,
  "rendererApplied": true,
  "previewExportParityEligible": true
}
```

Rules:

- `get_layers` is not proof.
- revision increment is not proof.
- metadata write is not proof.
- `appApplied=true` requires local frame/renderer proof.
- Self-asserted `rendererApplied=true` is invalid without measured/evaluated
  bounds.
- Proof must name sampled frame(s), renderer versions, visual program hash, and
  diff artifact paths when parity is evaluated.

Tests:

- Correct centered text returns proof pass.
- Ambiguous coordinate returns proof failure before apply.
- Off-canvas command fails unless `allowOverflow=true`.

Device check:

- MCP creates background + text + motion.
- Verify proof includes rendered bounds.
- Verify proof includes `insideCanvas=true`.
- Verify proof fails when a command would render outside the canvas without
  `allowOverflow=true`.

### PCTE-09: Legacy Coordinate Path Cleanup

Cleanup mandate:

- No new code may call ad hoc coordinate math inside screen widgets.
- Existing legacy helpers must become compatibility adapters or be removed.
- Layer-kind-specific coordinate parsing must be replaced by
  `CanvasCoordinateMapper`.

Targets to audit:

- MCP server payload canonicalization.
- MCP app-side remote layer apply.
- text overlay projection.
- shape overlay projection.
- image/video overlay projection.
- transform handle projection.
- editor snapshot builder.
- `get_canvas_metadata`.
- `get_element_geometry`.

Exit criteria:

- `rg` confirms no unsupported raw coordinate conversions remain outside
  approved mapper/adapters.
- Compatibility adapters emit diagnostics when used.
- Official wireless device E2E passes after cleanup.
- No legacy path can render authored content outside the official canvas.

## 7. Acceptance Suite

The plan is not complete until all pass:

### 7.1 Coordinate Acceptance

1. Story `1080x1920`, MCP `anchor=center` text appears centered.
2. Story `1080x1920`, MCP `centerX=540, centerY=960` text appears centered.
3. Story `1080x1920`, MCP raw `x=540,y=960` without coordinate space is
   rejected.
4. Center-origin `x=0,y=0` appears centered.
5. Snapshot reports centered text as canonical `0,0`.

### 7.2 Manual/MCP Parity

1. Manual Add Text and MCP Add Text produce the same graph shape.
2. Manual Add Solid and MCP Add Background produce the same full-canvas bounds.
3. Manual move and MCP move both update the same element identity.
4. MCP can read exact position after manual movement.

### 7.3 Motion Geometry

1. Pop-up scale motion changes evaluated geometry over time.
2. Position keyframes change geometry over time.
3. Rotation keyframes return transformed corners.
4. Motion cannot target a random selected layer when target is unresolved.

### 7.4 Renderer Proof

1. Proof cannot pass from database rows alone.
2. Proof requires local timeline visibility.
3. Proof requires evaluated frame geometry.
4. Proof requires renderer-applied visual bounds.

### 7.5 Device E2E

Run on the official connected tablet:

```text
1. Create Story composition.
2. MCP create full-canvas white background.
3. MCP create centered text "TEXT MOTION TEST".
4. MCP apply pop-up motion to same text.
5. Query spatial scene snapshot.
6. Scrub/play.
7. Capture screenshot.
8. Confirm text is centered and motion applies.
9. Confirm timeline has background and text clips.
10. Confirm no duplicate text layer.
```

Required evidence:

```text
device screenshot of centered text
device screenshot of motion mid-frame or scrubbed frame
timeline screenshot showing background + one text clip
spatial snapshot JSON
renderer proof JSON
logcat/app log excerpt with no coordinate/proof failure
```

### 7.5.1 Preset And Transform Coverage

The E2E suite must run across:

```text
Story 1080x1920
Landscape 1920x1080
Square 1080x1080
at least one non-1080 preset
```

For each preset, verify:

```text
center placement
top-left/top-right/bottom-center semantic placement
manual move then agent readback
agent move then manual readback
scaled text
rotated text
scaled/rotated shape
image fit/contain/cover
video fit/contain/cover
zoom/pan projection alignment
fractional coordinate round trip
high-DPI screenshot proof when available
```

### 7.5.2 Device Artifact Mechanics

All device artifacts go under:

```text
.tmp_diagnostics/pcte/<phase>/<commit>/
```

Required commands or equivalent:

```text
adb devices
adb shell monkey -p com.refusion.app 1
adb exec-out screencap -p > .tmp_diagnostics/pcte/<phase>/<commit>/screen.png
adb logcat -d > .tmp_diagnostics/pcte/<phase>/<commit>/logcat.txt
```

Pixel measurements must be derived from one of:

- renderer proof bounds,
- spatial snapshot bounds,
- app diagnostic bounds,
- screenshot measurement script documented in the closure note.

Manual visual inspection alone is not sufficient for phase closure.

### 7.6 Per-Phase Device Closure Matrix

Each phase must complete the matching wireless-device closure scenario:

| Phase | Required Device Closure |
| --- | --- |
| PCTE-00 | Reproduce and screenshot the current wrong placement/failure. |
| PCTE-01 | Install/launch smoke plus mapper proof in logs or diagnostics. |
| PCTE-02 | MCP centered text appears in exact center of Story canvas. |
| PCTE-03 | Manual move is visible to MCP snapshot with exact pixel delta. |
| PCTE-04 | Text/shape/background stay clipped and aligned at zoom/pan. |
| PCTE-05 | Motion geometry changes match visual scrub/playback. |
| PCTE-06 | Agent snapshot sees all visible elements and exact bounds. |
| PCTE-07 | Semantic placement moves elements to center/top/bottom precisely. |
| PCTE-08 | Renderer proof passes/fails based on actual rendered bounds. |
| PCTE-09 | Final cleanup E2E proves no legacy path bypasses canvas truth. |

Skipping a device closure scenario requires an explicit `BLOCKED` note and the
phase cannot be marked done.

## 8. KPIs And Budgets

Required metrics:

```text
coordinate_ambiguity_rejection_rate = 100%
center_insert_visual_error <= 2px at 1x viewport
full_canvas_background_error = 0px
manual_mcp_geometry_parity_score >= 0.99
preview_export_geometry_parity_score >= 0.98
renderer_proof_false_positive_rate = 0%
spatial_snapshot_latency_p95 < 120ms for light scenes
canvas_coordinate_mapping_unit_tests_pass = 100%
per_phase_wireless_device_closure_rate = 100%
```

Performance budgets:

```text
CanvasCoordinateMapper single conversion <= 0.05ms
CanvasGeometrySnapshot light scene <= 4ms
CanvasGeometrySnapshot medium scene <= 8ms
SpatialSceneSnapshot light scene <= 120ms p95
Frame evaluator spatial proof <= 8ms on reference device for light scenes
```

## 9. Definition Of Ready

Before each implementation phase:

- Current failure reproduced or linked.
- Existing code path inspected.
- Reference principle identified.
- Scope is limited.
- Live Scrub and Stage5 protected paths are listed and untouched unless the
  phase explicitly owns them.
- Tests to add are named.
- Device verification method is named.
- Wireless device availability is confirmed or the phase is blocked.
- Screenshot/log artifact path is prepared.
- Rollback command is prepared.

## 10. Definition Of Done

For each phase:

- Unit tests pass.
- Relevant integration tests pass.
- Wireless device check passes for the phase.
- Screenshots/logs are saved for visual phases.
- Screenshots/logs are saved for every phase that touches app state, MCP,
  canvas, timeline, preview, motion, effects, or proof.
- Legacy paths are removed or downgraded to compatibility adapters.
- No metadata-only success remains for the phase.
- Pixel-exact acceptance thresholds are met.
- Canvas clipping acceptance passes.
- Agent spatial snapshot/proof is updated when the phase changes agent-visible
  geometry.
- Commit checkpoint is created and pushed.

## 11. Stop List

Do not:

- patch text position only;
- add another MCP-only coordinate workaround;
- let `x/y` mean different things by layer kind;
- let snapshots publish absolute pixels as canonical coordinates;
- let `get_element_geometry` read only database payloads;
- let renderer proof pass without evaluated visual bounds;
- let self-asserted proof booleans pass without measured/evaluated bounds;
- let UI and MCP use different canvas placement logic;
- let local Dart MCP and cloud MCP diverge in coordinate semantics;
- accept spatial writes based on stale snapshots;
- treat rounded editor chrome as exported composition shape unless explicitly
  authored;
- use screen viewport coordinates in MCP/script/template writes;
- accept raw spatial commands that the system cannot prove;
- create a new canvas engine that bypasses the runtime apply spine.

## 12. Immediate Recommended Execution Order

The next engineering slice should be:

```text
PCTE-01 + PCTE-02 + PCTE-03
```

Reason:

These three phases close the exact observed failure:

```text
MCP x=540,y=960 intended center -> app renders bottom-right
```

They also create the foundation for:

- correct MCP spatial writes,
- correct snapshots,
- correct agent context,
- correct manual/MCP parity.

After that, execute:

```text
PCTE-04 + PCTE-05 + PCTE-06
```

Reason:

These phases turn geometry into evaluated frame truth and make the agent see the
same canvas the renderer sees.

Finally:

```text
PCTE-07 + PCTE-08 + PCTE-09
```

Reason:

These phases add semantic motion-designer tools, proof, and legacy cleanup.

## 13. Final Expected State

After this plan, the following must be true:

```text
User creates Story composition.
Agent asks for canvas.
Agent receives exact 1080x1920 canvas profile.
Agent inserts text at center using anchor=center.
Runtime resolves canonical position x=0,y=0.
Text appears centered inside the official rounded canvas.
Timeline shows one text clip.
Agent asks geometry.
Runtime returns exact evaluated bounds.
User manually moves text.
Agent asks geometry again.
Runtime reports exact new position and movement delta.
Agent applies pop-up motion.
Motion targets the same element.
Preview and export evaluate the same geometry.
Proof reports renderer-applied bounds.
```

That is the professional canvas standard required for ReFusionXx.
