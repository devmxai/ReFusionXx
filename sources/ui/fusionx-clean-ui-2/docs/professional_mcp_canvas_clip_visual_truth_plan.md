# Professional MCP Canvas Clip Visual Truth Plan

Status: ready for implementation  
Package: `com.refusion.app`  
Date: 2026-05-12  
Short name: `PMCCVT`  
Depends on: `PMSTR` (`professional_mcp_scene_truth_runtime_plan.md`) and
`PACTG` (`professional_agent_composition_truth_graph_plan.md`)

## 1. Executive Decision

ReFusionXx must stop treating video mask, border, glow, shadow, crop, and
picture-in-picture placement as metadata. These properties are editor truth and
must become renderer truth.

The new rule is:

```text
MCP visual command
  -> canonical clip visual style contract
  -> app-side timeline clip mutation
  -> preview renderer style application
  -> playback/export parity
  -> visual app-applied acknowledgement
```

An MCP command is not successful if the database row changed but the open
composition still shows a rectangular unstyled clip in the wrong place.

This plan closes the current live failure where:

- the agent reports `appApplied=true`,
- the video scales or moves partially,
- circular mask, border, glow, shadow, and correct top-right placement do not
  render,
- final position is guessed from absolute canvas coordinates but applied as a
  relative transform,
- the timeline clip and the canvas surface disagree about visual truth.

## 2. Current Failure

The current screen proves the following:

```text
Visible result:
  - video exists in the Story composition
  - video is selected in the timeline
  - transform changed partially
  - video remains rectangular
  - no circle crop
  - no white border
  - no glow/shadow
  - final position is not the professional top-right PIP placement
```

This means the command path is alive but incomplete.

### 2.1 Renderer Style Gap

The Flutter canvas preview path renders the selected/imported video surface as a
plain transformed media rectangle. It does not consume clip style fields such
as:

```text
maskShape
clipPath
cornerRadius
border
stroke
glow
shadow
overflowClip
```

Therefore, values like:

```json
{
  "clipPath": "circle",
  "renderMask": true,
  "borderRadius": 9999,
  "stroke": {"color": "#FFFFFF", "width": 7},
  "shadow": {"blur": 24, "opacity": 0.22}
}
```

can be stored but still have no visible effect.

### 2.2 Coordinate Contract Gap

The agent sends end positions like:

```json
{"x": 860, "y": 260, "scale": 0.42}
```

as if `x/y` are canvas-absolute center coordinates. The app's clip transform
path can apply position as a relative transform around the media/canvas center.
That mismatch produces a visually strange placement.

The system needs one canonical coordinate contract:

```text
Canvas absolute center coordinates:
  x = distance from composition left edge to clip center
  y = distance from composition top edge to clip center

Internal relative transform:
  tx = x - compositionWidth / 2
  ty = y - compositionHeight / 2
```

No agent should guess this conversion.

### 2.3 Weak App-Applied Receipt

`appApplied=true` currently means the app accepted or stored the command. It
does not prove that the renderer drew the mask, border, glow, and final bounds.

For visual commands, success must mean:

```text
dataApplied=true
rendererApplied=true
visualBoundsVerified=true
```

If a style has no renderer path, the acknowledgement must fail closed with a
diagnostic such as:

```text
rendererApplied=false
reason=clip_mask_renderer_missing
```

## 3. Non-Negotiable Product Workflow

The target workflow must be exact.

### 3.1 User Request

The user says:

```text
Use the video in the timeline.
Put it inside a circular frame.
Start it in the center.
Animate it to the top-right corner.
Keep the face visible.
Add a white border and soft glow.
```

### 3.2 Required Result

```text
Timeline:
  - existing video clip remains the target
  - no unrelated background/text/solid rows are created
  - clip duration and source range remain unchanged unless requested

Canvas at start:
  - video visible as a circle
  - circle centered on the canvas
  - face-framing crop is preserved
  - white border visible
  - glow visible

Canvas at end:
  - same circular video frame
  - professionally placed in top-right safe area
  - margins are consistent with composition size
  - no clipping outside the canvas

Playback:
  - transform animates smoothly
  - mask/border/glow remain attached to the video during motion
  - preview and export match

MCP acknowledgement:
  - rendererApplied=true
  - finalBounds match the recipe contract
```

## 4. Canonical Model: Canvas Clip Visual Style

Create a single canonical style model for all visible timeline media clips.

Suggested domain name:

```text
CanvasClipRenderStyle
```

Required fields:

```json
{
  "schemaVersion": "refusion.canvasClipRenderStyle/v1",
  "clipId": "clip_...",
  "layerId": "layer_...",
  "mask": {
    "shape": "none|circle|roundedRect|rect",
    "radiusPx": 250,
    "cornerRadiusPx": 0,
    "featherPx": 8,
    "overflow": "clip"
  },
  "crop": {
    "mode": "contain|cover|faceSafeCover|manual",
    "sourceRectNorm": {"x": 0.0, "y": 0.0, "w": 1.0, "h": 1.0},
    "focalPointNorm": {"x": 0.5, "y": 0.42}
  },
  "border": {
    "enabled": true,
    "color": "#FFFFFF",
    "widthPx": 7,
    "opacity": 1.0
  },
  "glow": {
    "enabled": true,
    "color": "#FFFFFF",
    "blurPx": 24,
    "spreadPx": 0,
    "opacity": 0.22
  },
  "shadow": {
    "enabled": false,
    "color": "#000000",
    "blurPx": 18,
    "offsetX": 0,
    "offsetY": 8,
    "opacity": 0.18
  }
}
```

This model must be carried through:

```text
MCP payload -> Supabase layer/style row -> app bridge snapshot
            -> local clip state -> Flutter preview -> native/Stage5/export
```

## 5. Canonical Model: Canvas Clip Transform Contract

Create one transform contract for MCP and local editor code.

Suggested domain name:

```text
CanvasClipTransformKeyframe
```

Required semantics:

```json
{
  "timeMs": 900,
  "positionMode": "centerCanvasAbsolute",
  "centerX": 860,
  "centerY": 260,
  "scale": 0.42,
  "rotationDeg": 0,
  "opacity": 1,
  "easing": "easeOutCubic"
}
```

Conversion rule:

```text
relativeX = centerX - compositionWidth / 2
relativeY = centerY - compositionHeight / 2
```

The conversion belongs in the app/backend adapter, not in the agent prompt.

### 5.1 PIP Anchor Contract

Agents should prefer recipes over hand-computed coordinates.

Required recipe:

```text
refusion.apply_video_pip_recipe
```

Arguments:

```json
{
  "target": {"clipId": "clip_...", "layerId": "layer_..."},
  "shape": "circle",
  "placement": "topRight",
  "diameterPx": 360,
  "marginPx": 72,
  "durationMs": 900,
  "start": {"placement": "center", "scale": 1.0},
  "end": {"placement": "topRight", "scale": 0.42},
  "border": {"color": "#FFFFFF", "widthPx": 7},
  "glow": {"color": "#FFFFFF", "blurPx": 24, "opacity": 0.22},
  "crop": {"mode": "faceSafeCover"}
}
```

App-side solver:

```text
center placement:
  centerX = compositionWidth / 2
  centerY = compositionHeight / 2

topRight placement:
  centerX = compositionWidth - marginPx - diameterPx / 2
  centerY = marginPx + diameterPx / 2
```

For a Story composition `1080x1920`, `diameter=360`, `margin=72`:

```text
topRight centerX = 1080 - 72 - 180 = 828
topRight centerY = 72 + 180 = 252
```

The final circle bounds must be:

```text
left = 648
top = 72
right = 1008
bottom = 432
```

This is the professional target, not a guessed location.

## 6. MCP Tool Surface

Add or harden these tools.

### 6.1 `refusion.set_clip_visual_style`

Purpose: update mask/crop/border/glow/shadow on an existing media clip or layer.

Must not create new solid/background/update metadata rows.

Arguments:

```json
{
  "clipId": "clip_...",
  "layerId": "layer_...",
  "style": {}
}
```

Response:

```json
{
  "ok": true,
  "revisionBefore": 14,
  "revisionAfter": 15,
  "targetClipId": "clip_...",
  "styleAppliedToData": true
}
```

### 6.2 `refusion.apply_clip_transform_keyframes`

Purpose: apply real motion channels to an existing clip.

Arguments:

```json
{
  "clipId": "clip_...",
  "layerId": "layer_...",
  "coordinateSpace": "centerCanvasAbsolute",
  "keyframes": []
}
```

### 6.3 `refusion.apply_video_pip_recipe`

Purpose: one high-level professional recipe for the common explainer-video
pattern: full/center video becomes circular PIP in a corner.

This tool must:

- resolve the target video clip,
- solve exact canvas bounds,
- write clip style,
- write transform keyframes,
- preserve source range and clip duration,
- return expected start/end bounds,
- wait for visual apply when requested.

### 6.4 `refusion.get_clip_visual_state`

Purpose: let the agent inspect current visual truth before/after mutation.

Response must include:

```json
{
  "clipId": "clip_...",
  "renderStyle": {},
  "transformAtPlayhead": {},
  "evaluatedBounds": {},
  "isRendererCapable": {
    "circleMask": true,
    "border": true,
    "glow": true,
    "shadow": true
  }
}
```

## 7. App Bridge Requirements

The app bridge must map remote visual style to the currently open composition.

Required behavior:

```text
1. Read remote media layer rows and style mutations.
2. Resolve remote layerId -> local timeline clipId.
3. Store CanvasClipRenderStyle in local clip state.
4. Store transform channels in local clip motion channels.
5. Trigger setState/editor refresh.
6. Emit app apply receipt only after local state contains the style/channel.
```

Required local maps:

```text
_mcpRemoteMediaLayerClipIds: remoteLayerId -> localClipId
_canvasClipTransforms: localClipId -> CanvasClipTransform
_canvasClipRenderStyles: localClipId -> CanvasClipRenderStyle
```

The style map must survive:

- realtime apply,
- polling fallback,
- timeline selection,
- play/pause,
- preview rebuild,
- app foreground/background,
- project reopen.

## 8. Renderer Requirements

### 8.1 Flutter Preview Renderer

The Flutter canvas preview must render style for media clips.

Required rendering order:

```text
outer glow/shadow
  -> border stroke
    -> clipped media surface
      -> video/image content with crop/cover/focal point
```

Circle rendering must use a real circular clip, not only rounded metadata.

Implementation shape:

```text
if mask.shape == circle:
  draw square/diameter layout box
  apply ClipOval to media
  draw border as circular stroke
  draw glow outside circle

if mask.shape == roundedRect:
  apply ClipRRect
  draw rounded border/glow
```

### 8.2 Stage5 / Native Preview Parity

If Stage5/native preview is responsible for the visible canvas, it must receive
the same style contract. If native support is not implemented in the first
slice, Flutter overlay fallback may render border/glow, but the video clipping
must still be visible in the active preview path.

The implementation must not touch protected Live Scrub files unless that exact
change is explicitly approved.

### 8.3 Export Parity

The final export path must not silently drop mask/border/glow. If export parity
is not finished in the first implementation slice, export must report a clear
diagnostic rather than pretending parity exists.

## 9. Visual App-Applied Receipt

Extend app receipts from data success to visual success.

Required receipt:

```json
{
  "commandId": "cmd_...",
  "dataApplied": true,
  "rendererApplied": true,
  "visualBoundsVerified": true,
  "clipId": "clip_...",
  "layerId": "layer_...",
  "expectedBounds": {"left": 648, "top": 72, "right": 1008, "bottom": 432},
  "actualBounds": {"left": 648, "top": 72, "right": 1008, "bottom": 432},
  "styleChecks": {
    "circleMask": true,
    "border": true,
    "glow": true
  }
}
```

If the renderer path is missing:

```json
{
  "dataApplied": true,
  "rendererApplied": false,
  "reason": "clip_visual_style_renderer_missing"
}
```

The agent must not tell the user "done" when `rendererApplied=false`.

## 10. Implementation Phases

### PMCCVT-00: Failure Fixture

Create a fixture that reproduces the current bug:

```text
Story composition 1080x1920
one imported video clip
MCP command: circle mask + border + glow + topRight PIP motion
current result: rectangular clip, missing border/glow, wrong final bounds
```

The fixture must fail before the fix.

### PMCCVT-01: Canonical Models

Add canonical data models:

- `CanvasClipRenderStyle`
- `CanvasClipMaskStyle`
- `CanvasClipBorderStyle`
- `CanvasClipGlowStyle`
- `CanvasClipShadowStyle`
- `CanvasClipTransformKeyframe`
- `CanvasClipPipPlacement`

Models must support JSON serialization and strict validation.

### PMCCVT-02: Coordinate Solver

Add a composition-aware solver:

```text
placement -> centerCanvasAbsolute bounds -> internal relative transform
```

Required placements:

- `center`
- `topRight`
- `topLeft`
- `bottomRight`
- `bottomLeft`

Required tests:

- Story `1080x1920`, topRight, diameter `360`, margin `72`
- Landscape `1920x1080`, topRight, diameter `300`, margin `64`
- Square `1080x1080`, center and bottomRight

### PMCCVT-03: MCP Tools

Expose:

- `set_clip_visual_style`
- `apply_clip_transform_keyframes`
- `apply_video_pip_recipe`
- `get_clip_visual_state`

The backend must reject unsupported style fields rather than storing ambiguous
metadata.

### PMCCVT-04: Legacy Compatibility

If old rows arrive as:

```text
operation=update_layer
updates.mask/border/glow/clipPath/renderMask
```

they must be routed into `CanvasClipRenderStyle`, not treated as a background
or inert metadata row.

If old rows arrive as:

```text
operation=animate_layer
updates.animation/keyframes
```

they must be routed into transform/motion channels for the target clip.

### PMCCVT-05: App Bridge Style Apply

Parse remote style into `_canvasClipRenderStyles[clipId]`.

The local apply path must handle:

- media clip by `clipId`,
- media clip by `layerId`,
- selected clip fallback only when the target is unambiguous,
- wrong target rejection when multiple candidate videos exist.

### PMCCVT-06: Flutter Renderer Style Apply

Render actual:

- circle clip,
- rounded rect clip,
- white border,
- soft glow,
- shadow,
- crop/focal point.

This must work on the open canvas before considering export parity.

### PMCCVT-07: Motion + Style Binding

Ensure style remains attached while transform animates.

Acceptance:

```text
At 0ms: circular video centered with border/glow
At 450ms: circular video halfway along path with border/glow
At 900ms: circular video top-right with border/glow
```

No frame may temporarily show the raw rectangular video.

### PMCCVT-08: Visual Apply Receipt

Upgrade `wait_for_apply` / command status:

- data apply,
- renderer apply,
- expected bounds,
- actual bounds,
- style checks.

### PMCCVT-09: Agent Prompt/Skill Contract

Update the agent-facing guidance:

- read `Composition Truth Graph` first,
- target existing video clip,
- prefer `apply_video_pip_recipe`,
- do not use `apply_scene_program` for clip style/motion,
- do not create solid/update rows for mask or animation,
- wait for visual apply receipt.

### PMCCVT-10: Device Acceptance

Install on the connected device and verify the exact scenario:

```text
1. Open Story composition.
2. Insert/import a video clip.
3. Connect MCP.
4. Ask agent for circular PIP animation.
5. Confirm on device:
   - circular mask visible
   - border visible
   - glow visible
   - starts center
   - ends top-right within safe bounds
   - playback preserves style
```

## 11. Acceptance Tests

### 11.1 Renderer Unit Test

```text
Given CanvasClipRenderStyle(mask=circle,border=white,glow=soft)
When renderer builds the preview surface
Then it uses a circular clip and paints border/glow outside the video.
```

### 11.2 Coordinate Solver Test

```text
Story 1080x1920, topRight, diameter=360, margin=72
Expected final bounds:
  left=648, top=72, right=1008, bottom=432
Expected center:
  x=828, y=252
```

### 11.3 MCP End-To-End Test

```text
Agent calls apply_video_pip_recipe on video clip
Backend writes style + transform channels
App applies to local clip
Renderer draws circular video
wait_for_apply returns rendererApplied=true
```

### 11.4 Regression Test: No Metadata-Only Success

```text
If renderer does not support circle mask
Then command status must not return appApplied=true
It must return rendererApplied=false with reason.
```

### 11.5 Regression Test: No Background Pollution

```text
Applying clip visual style must not create or update background layers.
```

## 12. Stop List

Do not:

- store mask/border/glow as metadata without renderer apply,
- report `appApplied=true` for visual commands without renderer verification,
- let agents hand-compute PIP coordinates when a recipe can solve them,
- use `apply_scene_program` as fallback for styling an existing video clip,
- create a new solid/background row for clip mask or animation,
- change Live Scrub protected files without explicit approval,
- break existing manual transform controls,
- make style visible only when the clip is selected,
- allow preview and export to diverge silently.

## 13. Definition Of Done

This plan is complete only when the user can run this prompt through ChatGPT:

```text
Inspect the open timeline. Use the existing video clip. Put it in a circular
frame with a white border and soft glow. Start it centered, then animate it to
the top-right corner as a professional picture-in-picture explainer frame.
```

And the open Android app shows:

```text
real circular video
real border
real glow
correct center start
correct top-right final placement
smooth motion
no unrelated layer changes
visual app-applied confirmation
```

Anything less is not done.
