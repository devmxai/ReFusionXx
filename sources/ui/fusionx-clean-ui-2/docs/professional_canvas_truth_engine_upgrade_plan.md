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

### 5.1 CanvasProfile

Create a canonical profile object:

```text
CanvasProfile
  projectId
  compositionId
  sceneId
  width
  height
  fps
  durationMs
  currentTimeMs
  currentFrame
  pixelAspectRatio
  aspectPreset
  canonicalCoordinateSpace
  axisDirection
  origin
  boundsCenterOrigin
  boundsTopLeftAbsolute
  safeAreas
  guides
  roundedPreviewClipRadius
  viewportScale
  viewportOffset
```

This object must be derived from the active local composition truth, not from
MCP guesses.

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

### PCTE-01: CanvasProfile And Coordinate Contract

Build:

- `CanvasProfile`
- `CanvasCoordinateSpace`
- `CanvasCoordinateMapper`
- `CanvasSpatialIntent`
- typed diagnostics:
  - `AMBIGUOUS_COORDINATE_SPACE`
  - `UNSUPPORTED_COORDINATE_SPACE`
  - `OUT_OF_CANVAS_BOUNDS`
  - `INVALID_CANVAS_PROFILE`

Rules:

- Internal canonical storage is center-origin.
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

- None required unless wired into live paths.

### PCTE-02: MCP Coordinate Write Gate

Build:

- one MCP coordinate normalization boundary for:
  - `insert_layer`
  - `update_layer`
  - `set_element_transform`
  - `apply_motion_patch`
  - future script/template imports

Rules:

- New MCP writes cannot use ambiguous raw `x/y`.
- `x/y` are canonical center-origin only when declared or from trusted internal
  adapters.
- Absolute values use `centerX/centerY` or `coordinateSpace=topLeftAbsolute`.
- Semantic placement uses `anchor/zone`.

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

### PCTE-03: Snapshot Contract Cleanup

Build:

- snapshot payloads must expose canonical and absolute fields separately.

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

### PCTE-05: Evaluated Element Geometry

Build:

- `CanvasGeometrySnapshot` from frame evaluator truth.
- `get_element_geometry(timeMs)` reads evaluated frame state, not only static DB
  payload.

Rules:

- Geometry includes motion channels at `timeMs`.
- Geometry includes transforms, scale, rotation, masks, effects that inflate
  bounds, and canvas clipping.
- Geometry includes visible/timeline status.

Tests:

- Text with position keyframes returns different geometry at `t=0` and `t=500`.
- Rotation returns transformed corners and axis-aligned bounds.
- Scale pop-up returns changing bounds through frames.

Device check:

- MCP applies pop-up to text.
- Scrub/play.
- Query geometry at start/mid/end.
- Verify geometry and visual result match.

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

Tests:

- Correct centered text returns proof pass.
- Ambiguous coordinate returns proof failure before apply.
- Off-canvas command fails unless `allowOverflow=true`.

Device check:

- MCP creates background + text + motion.
- Verify proof includes rendered bounds.

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

## 8. KPIs And Budgets

Required metrics:

```text
coordinate_ambiguity_rejection_rate = 100%
center_insert_visual_error <= 2px at 1x viewport
manual_mcp_geometry_parity_score >= 0.99
preview_export_geometry_parity_score >= 0.98
renderer_proof_false_positive_rate = 0%
spatial_snapshot_latency_p95 < 120ms for light scenes
canvas_coordinate_mapping_unit_tests_pass = 100%
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
- Rollback command is prepared.

## 10. Definition Of Done

For each phase:

- Unit tests pass.
- Relevant integration tests pass.
- Device check passes when the phase touches MCP/apply/preview/canvas.
- Screenshots/logs are saved for visual phases.
- Legacy paths are removed or downgraded to compatibility adapters.
- No metadata-only success remains for the phase.
- Commit checkpoint is created and pushed.

## 11. Stop List

Do not:

- patch text position only;
- add another MCP-only coordinate workaround;
- let `x/y` mean different things by layer kind;
- let snapshots publish absolute pixels as canonical coordinates;
- let `get_element_geometry` read only database payloads;
- let renderer proof pass without evaluated visual bounds;
- let UI and MCP use different canvas placement logic;
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
