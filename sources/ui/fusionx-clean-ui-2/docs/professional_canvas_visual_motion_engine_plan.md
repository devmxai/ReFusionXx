# Professional Canvas Visual Motion Engine Plan

Status: ready for implementation planning  
Package: `com.refusion.app`  
Date: 2026-05-12  
Short name: `PCVME`  
Supersedes as umbrella: `PMSTR`, `PRMEA`, `PACTG`, `PMCCVT` as MCP-specific
or visual-specific slices  
Must preserve: protected Stage5 / Live Scrub boundaries unless an exact slice
is explicitly approved

## 1. Executive Decision

ReFusionXx needs one app-wide professional canvas visual motion engine.

The center of the architecture must not be MCP, ChatGPT, Supabase rows, manual
UI widgets, timeline rows, or a preview widget. The center must be:

```text
canonical composition/timeline/asset/layer/effect/motion graph
  -> deterministic frame evaluation
  -> master visual program
  -> renderer adapters
  -> visual proof
```

MCP, manual UI, transform handles, inspector panels, scene scripts, presets,
future UI tools, and imported templates are only input adapters. They must all
write through the same canonical editor command system and all render through
the same evaluated frame truth.

The new product rule is:

```text
manual UI / canvas gesture / timeline edit / SceneProgram / MCP
  -> canonical editor command
  -> transaction + undo/redo
  -> composition timeline graph mutation
  -> motion/keyframe/effect/style truth
  -> deterministic frame evaluation
  -> preview/playback/export renderer adapter
  -> visual app-applied proof
```

If a feature works only through MCP, it is not a professional editor feature. If
it works only manually but not through the command graph, it is not scriptable
or agent-ready. If it exists only as metadata and the renderer does not draw it,
it is not real.

## 2. Why This Plan Exists

The current failures are symptoms of one broader architectural gap.

Recent live issues:

- video transform partially applies, but circular mask, border, and glow do not
  render;
- `appApplied=true` can be returned before visual proof;
- animation can be stored as payload metadata but not become editable keyframes;
- background can be changed accidentally by an unrelated motion/update row;
- ChatGPT can see some layers but not the complete clip/style/effect truth;
- manual UI and MCP paths risk becoming different engines;
- preview, playback, Live Scrub, and export can diverge silently.

This is not only an MCP issue. It is a missing professional visual runtime
contract.

## 3. External Principles To Encode

This plan borrows proven principles from code-based video tools and adapts them
to ReFusionXx's native editor.

### 3.1 Remotion-Style Frame Truth

Remotion's core idea is that the app receives the current frame and renders the
composition for that frame. A composition also has explicit video properties:
width, height, duration, and fps. ReFusionXx needs the same invariant:

```text
composition + frame/time + graph + assets -> pixels
```

No renderer-local clock, stale widget state, wall-clock animation, random value,
or hidden native media timestamp may override the evaluated frame.

Reference: Remotion fundamentals and frame hooks:

- https://www.remotion.dev/docs/the-fundamentals
- https://www.remotion.dev/docs/use-current-frame
- https://www.remotion.dev/docs/interpolate
- https://www.remotion.dev/docs/sequence

### 3.2 HyperFrames-Style Timeline And Render Safety

HyperFrames guidance treats composition dimensions, clip timing, media start,
track index, paused timelines, and deterministic seek as source-of-truth
concepts. ReFusionXx needs the native equivalent:

```text
every asset has timeline time
every media clip has source time
every animation is seekable
every renderer can evaluate any frame deterministically
```

The important rule is layout before animation: define the final visible frame
first, then animate into and out of it.

### 3.3 After Effects-Style Surface Stack

Every visible layer needs a canonical surface stack:

```text
source content
  -> crop / source rect / focal point
  -> mask / matte / clip path
  -> intrinsic style
  -> transform
  -> effects
  -> opacity / blend
  -> composite
```

Video, image, text, and shape must all participate in this stack. Differences
belong in per-kind adapters, not in separate engines.

## 4. Existing Systems To Reuse

Do not rebuild these systems. Integrate them.

### 4.1 Timeline And Time Truth

Existing paths:

- `lib/features/editor/presentation/models/timeline_time.dart`
- `lib/features/editor/domain/models/master_time_models.dart`
- `lib/features/editor/domain/services/timeline_clock_coordinator.dart`

These are the time foundation. `PCVME` must use them for root time, local clip
time, frame index, playback, preview, and future export.

### 4.2 Motion And Keyframe Truth

Existing paths:

- `lib/features/editor/domain/models/professional_motion_models.dart`
- `lib/features/editor/domain/services/unified_keyframe_operations.dart`
- `lib/features/editor/domain/services/canvas_timeline_unified_keyframe_adapter.dart`
- `docs/professional_refusion_motion_keyframe_engine.md`
- `docs/professional_speed_graph_system.md`

These remain the authoritative path for transforms, opacity, scale, rotation,
position, blur, timing, interpolation, and SpeedyGraph.

### 4.3 Value Truth And Property Registry

Existing path:

- `lib/features/editor/domain/services/master_value_truth_registry.dart`

This already recognizes many professional properties, including transform,
opacity, blur, motion blur, crop, shadow, shape, text, and mask reveal. `PCVME`
must promote the missing visual properties into this registry rather than
storing them as loose payload fields.

### 4.4 Renderer Truth Adapters

Existing paths:

- `lib/features/editor/domain/services/master_visual_program_adapter.dart`
- `lib/features/editor/domain/services/master_render_graph_adapter.dart`
- `lib/features/editor/domain/services/master_renderer_frame_adapters.dart`

These should become the path that preview, playback, Live Scrub adapter, and
export consume.

### 4.5 Export Truth

Existing paths:

- `lib/features/editor/domain/models/export_composition_builder.dart`
- `lib/features/editor/domain/models/export_composition_models.dart`
- `android/app/src/main/kotlin/com/fusionx/fusionx_clean_ui_2/Stage6ExportManager.kt`
- `android/app/src/main/kotlin/com/fusionx/fusionx_clean_ui_2/Stage6AuthoredVisualSurfaceRuntime.kt`

Export parity must be verified through this path, not promised through preview
metadata.

### 4.6 MCP And Agent Control

Existing paths:

- `lib/features/editor/domain/mcp/refusion_mcp_tool_registry.dart`
- `lib/features/editor/domain/mcp/refusion_mcp_agent_control_plane.dart`
- `lib/features/editor/domain/mcp/refusion_mcp_motion_tools.dart`
- `docs/professional_mcp_connectors.md`
- `docs/professional_agent_composition_truth_graph_plan.md`

MCP becomes an adapter over `PCVME`, not a parallel authoring engine.

### 4.7 Composition Workspace

Existing paths:

- `lib/features/editor/domain/models/composition_workspace_models.dart`
- `lib/features/editor/domain/models/composition_scene_clip_models.dart`

These must own project/composition identity, root timeline, scene clips, layer
scope, and future Recent Projects behavior.

## 5. Core Principle

Every visible thing must be an authored surface.

```text
AuthoredSurface =
  identity
  timeline lifetime
  source binding
  visual bounds
  transform channels
  style stack
  effect stack
  mask/crop stack
  render capabilities
  diagnostics
```

Supported authored surface kinds:

- background,
- video,
- image,
- text,
- shape,
- audio-linked visualizer,
- adjustment layer,
- component/group/precomposition.

Video and image must not be treated as transport widgets. Text must not be a
special overlay outside the same visual stack. Shapes must not be static canvas
decorations. All are surfaces.

## 6. Canonical Data Model

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
  "safeAreas": {},
  "revision": 42
}
```

### 6.2 Timeline Truth

```json
{
  "timelineId": "main",
  "tracks": [
    {
      "trackId": "track_video_1",
      "kind": "video",
      "index": 1,
      "clips": [
        {
          "clipId": "clip_01",
          "surfaceId": "surface_video_01",
          "assetId": "asset_video_01",
          "timelineStartMs": 0,
          "timelineDurationMs": 12000,
          "sourceStartMs": 3000,
          "sourceDurationMs": 12000,
          "playbackRate": 1.0,
          "zIndex": 20
        }
      ]
    }
  ]
}
```

### 6.3 Authored Surface Truth

```json
{
  "surfaceId": "surface_video_01",
  "kind": "video",
  "source": {
    "assetId": "asset_video_01",
    "sourceUri": "refusion-asset://asset_video_01"
  },
  "layout": {
    "anchor": "center",
    "intrinsicWidth": 1920,
    "intrinsicHeight": 1080,
    "fit": "cover"
  },
  "style": {},
  "effects": [],
  "motion": {
    "channels": []
  },
  "capabilities": {}
}
```

### 6.4 Authored Surface Style Stack

Suggested domain name:

```text
AuthoredSurfaceEffectStack
```

Required categories:

```json
{
  "crop": {
    "mode": "contain|cover|faceSafeCover|manual",
    "sourceRectNorm": {"x": 0, "y": 0, "w": 1, "h": 1},
    "focalPointNorm": {"x": 0.5, "y": 0.5}
  },
  "mask": {
    "shape": "none|rect|roundedRect|circle|ellipse|path|assetMatte",
    "cornerRadiusPx": 0,
    "radiusPx": 250,
    "featherPx": 0,
    "invert": false,
    "overflow": "clip"
  },
  "border": {
    "enabled": true,
    "color": "#FFFFFF",
    "widthPx": 7,
    "opacity": 1
  },
  "shadow": {
    "enabled": true,
    "color": "#000000",
    "blurPx": 18,
    "offsetX": 0,
    "offsetY": 8,
    "opacity": 0.25
  },
  "glow": {
    "enabled": true,
    "color": "#FFFFFF",
    "blurPx": 24,
    "spreadPx": 0,
    "opacity": 0.22
  },
  "filters": {
    "blurPx": 0,
    "brightness": 1,
    "contrast": 1,
    "saturation": 1,
    "hueDeg": 0
  },
  "blend": {
    "mode": "normal",
    "opacity": 1
  }
}
```

This style stack applies to video, image, text, and shape. Unsupported fields
must report capability blockers instead of being stored silently.

### 6.5 Motion Channel Truth

All animated properties must be channels:

```json
{
  "channelId": "ch_scale_x",
  "targetSurfaceId": "surface_video_01",
  "property": "transform.scaleX",
  "keyframes": [
    {"timeMs": 0, "value": 1.0, "easing": "easeOutCubic"},
    {"timeMs": 900, "value": 0.42, "easing": "easeOutCubic"}
  ]
}
```

No animation may exist only inside an opaque payload blob.

## 7. Coordinate And Placement Contract

### 7.1 Canonical Coordinate System

ReFusionXx should keep center-origin as the internal canonical transform
coordinate system.

```text
canonical x=0,y=0 is composition center
positive x moves right
positive y moves down
```

Top-left canvas coordinates are a derived API/display contract:

```text
centerCanvasAbsolute.x = canonicalX + compositionWidth / 2
centerCanvasAbsolute.y = canonicalY + compositionHeight / 2
```

Agents and UI can request either coordinate space, but every command must state
which one it uses.

### 7.2 Placement Solver

Create a placement solver for professional layout:

```text
center
topLeft
topRight
bottomLeft
bottomRight
safeTitleCenter
safeLowerThird
customAbsoluteCenter
customBounds
```

Example Story PIP:

```text
composition: 1080x1920
diameter: 360
margin: 72
placement: topRight

centerX = 1080 - 72 - 180 = 828
centerY = 72 + 180 = 252
bounds = left 648, top 72, right 1008, bottom 432
canonicalX = 828 - 540 = 288
canonicalY = 252 - 960 = -708
```

No agent or UI feature should hand-guess PIP coordinates when a solver can
derive them.

### 7.3 Spatial Intelligence Layer

The system must give agents and future manual UI the same spatial senses that a
professional motion designer has while looking at the canvas.

The five cognitive layers are:

```text
Sensory:
  What exists and what is visible?

Spatial memory:
  Where is it, how large is it, what does it overlap, and what safe area is it in?

Temporal memory:
  When is it visible, what is its source time, and what keyframes affect it?

Capability memory:
  What can this renderer/tool/app version actually do?

Reasoning helpers:
  How should the engine solve placement, alignment, fit, and layout validation?
```

These layers are not MCP-only. They should power:

- agent reads,
- inspector panels,
- transform tool overlays,
- alignment buttons,
- snapping,
- layout diagnostics,
- visual QA,
- future template authoring.

### 7.4 Canvas Metadata Contract

Create a canonical canvas metadata projection.

Suggested command/resource:

```text
get_canvas_metadata
```

Required response:

```json
{
  "compositionId": "uuid",
  "width": 1080,
  "height": 1920,
  "aspect": "9:16",
  "fps": 30,
  "durationMs": 30000,
  "origin": "center",
  "coordinateSystem": {
    "canonical": "centerOrigin",
    "unit": "px",
    "xRange": [-540, 540],
    "yRange": [-960, 960]
  },
  "safeZones": {
    "titleSafe": {"left": 64, "top": 128, "right": 1016, "bottom": 1792},
    "actionSafe": {"left": 32, "top": 96, "right": 1048, "bottom": 1824}
  },
  "anchors": {
    "topLeft": {"x": -540, "y": -960},
    "topCenter": {"x": 0, "y": -960},
    "topRight": {"x": 540, "y": -960},
    "centerLeft": {"x": -540, "y": 0},
    "center": {"x": 0, "y": 0},
    "centerRight": {"x": 540, "y": 0},
    "bottomLeft": {"x": -540, "y": 960},
    "bottomCenter": {"x": 0, "y": 960},
    "bottomRight": {"x": 540, "y": 960},
    "goldenTop": {"x": 0, "y": -367},
    "goldenBottom": {"x": 0, "y": 367}
  }
}
```

### 7.5 Element Geometry Contract

Create a geometry projection for every authored surface.

Suggested command/resource:

```text
get_element_geometry
```

Required response:

```json
{
  "surfaceId": "surface_video_01",
  "clipId": "clip_video_01",
  "kind": "video",
  "intrinsicSize": {"width": 1920, "height": 1080},
  "aspectRatio": 1.7777778,
  "timelineRange": {"startMs": 0, "durationMs": 12000},
  "sourceRange": {"startMs": 3000, "durationMs": 12000},
  "worldBounds": {
    "centerX": 0,
    "centerY": 0,
    "width": 1080,
    "height": 607.5,
    "rotationDeg": 0,
    "scaleX": 0.5625,
    "scaleY": 0.5625
  },
  "visibleBounds": {},
  "style": {},
  "safeAreaCompliance": {
    "titleSafe": true,
    "actionSafe": true
  },
  "overlaps": []
}
```

The geometry response must be evaluated from the same frame context as the
renderer. It cannot be a stale database approximation.

### 7.6 Visual Layout Summary

Create a layout summary projection for agents and UI diagnostics.

Suggested command/resource:

```text
get_visual_layout_summary
```

Required response:

```json
{
  "summary": "Story canvas 1080x1920 with one purple background, one video clip centered, and one text layer in the upper third.",
  "primaryFocus": "surface_video_01",
  "backgroundSurfaceId": "surface_background_01",
  "selectedSurfaceIds": ["surface_video_01"],
  "issues": [
    {
      "code": "TEXT_OVERLAPS_VIDEO",
      "severity": "warning",
      "surfaceIds": ["surface_text_01", "surface_video_01"]
    }
  ],
  "suggestions": [
    {
      "operation": "surface.position.at_anchor",
      "targetSurfaceId": "surface_text_01",
      "anchor": "goldenTop"
    }
  ]
}
```

This gives the agent and the future manual UI a human-readable mental model,
not only raw JSON.

### 7.7 Semantic Positioning Commands

Add semantic spatial commands. These commands compile into ordinary transform
channels or immediate transform properties.

Required operations:

```text
surface.position.at_anchor
surface.align_to
surface.fit_in_zone
surface.scale_to
surface.center_in
surface.distribute
surface.keep_in_canvas
```

Allowed anchors:

```text
topLeft, topCenter, topRight
centerLeft, center, centerRight
bottomLeft, bottomCenter, bottomRight
goldenTop, goldenBottom
ruleOfThirdsTopLeft, ruleOfThirdsTopRight
ruleOfThirdsBottomLeft, ruleOfThirdsBottomRight
```

Allowed zones:

```text
fullCanvas
titleSafe
actionSafe
upperThird
middleThird
lowerThird
leftHalf
rightHalf
customRect
```

Example:

```json
{
  "operation": "surface.position.at_anchor",
  "target": {"surfaceId": "surface_video_01"},
  "anchor": "topRight",
  "paddingPx": 72,
  "safeArea": "actionSafe",
  "keepInCanvas": true,
  "animate": {
    "durationMs": 900,
    "easing": "easeOutCubic"
  }
}
```

The engine, not the agent, calculates the final pixel-perfect transform.

### 7.8 Reasoning Helpers

Add non-mutating reasoning commands that work for MCP and manual UI diagnostics.

Required operations:

```text
layout.suggest_composition
layout.validate_intent
layout.preview_change
layout.describe_timeline
layout.detect_overlaps
layout.score_safe_area
```

These commands must support `dryRun=true` and return proposed diffs without
mutating state.

### 7.9 Vision Loop

Add optional visual capture for pixel-level verification.

Required operation:

```text
capture_frame
```

Required behavior:

```text
evaluate frame -> render/capture preview -> store approved image -> return URI
```

The capture must be tied to:

- projectId,
- compositionId,
- revision,
- frame/time,
- renderer adapter,
- capability diagnostics.

Vision is not the first source of truth. It is a verification loop over the
deterministic visual program.

## 8. Time And Frame Contract

Every visible/evaluated frame must carry:

```json
{
  "rootTimeMs": 10334,
  "rootFrame": 310,
  "compositionTimeMs": 10334,
  "compositionFrame": 310,
  "clipLocalTimeMs": 334,
  "sourceTimeMs": 3334,
  "fps": 30
}
```

Rules:

- first frame is `0`;
- duration in frames is derived from durationMs and fps;
- clip local time is root time minus clip start;
- media source time is source start plus local time times playback rate;
- gaps evaluate to blank, not stale frames;
- playback, scrub, preview, export, MCP proof, and tests must evaluate from
  the same frame context.

## 9. Editor Command Dispatcher

Create one universal dispatcher.

Suggested domain name:

```text
ProfessionalEditorCommandDispatcher
```

Inputs:

- manual UI toolbar,
- canvas transform handles,
- timeline operations,
- inspector controls,
- SceneProgram,
- DirectorPlan,
- MCP tools,
- future templates/importers.

All inputs lower into:

```json
{
  "commandId": "cmd_...",
  "projectId": "uuid",
  "compositionId": "uuid",
  "expectedRevision": 42,
  "source": "manualUi|canvasGesture|timelineUi|sceneProgram|mcp|preset",
  "operation": "surface.style.patch",
  "target": {"surfaceId": "surface_..."},
  "payload": {},
  "dryRun": false
}
```

The dispatcher owns:

- validation,
- target resolution,
- dry-run diff,
- transaction commit,
- undo/redo record,
- revision increment,
- realtime notification,
- renderer proof request,
- diagnostics.

No UI widget or MCP handler may mutate visual state directly.

## 10. Required Command Taxonomy

### 10.1 Project And Composition

```text
project.create
project.open
composition.create
composition.set_duration
composition.set_fps
composition.set_size
composition.set_background
```

### 10.2 Assets And Timeline

```text
asset.register
asset.import
timeline.insert_clip
timeline.trim_clip
timeline.split_clip
timeline.move_clip
timeline.duplicate_clip
timeline.delete_clip
timeline.set_clip_duration
timeline.set_source_range
```

### 10.3 Surfaces

```text
surface.insert_background
surface.insert_video
surface.insert_image
surface.insert_text
surface.insert_shape
surface.group
surface.ungroup
surface.delete
surface.reorder
```

### 10.4 Visual Style

```text
surface.style.patch
surface.crop.set
surface.mask.set
surface.border.set
surface.shadow.set
surface.glow.set
surface.filter.set
surface.blend.set
surface.fill.set
surface.stroke.set
```

### 10.5 Motion

```text
motion.channel.set_keyframes
motion.channel.edit_keyframe
motion.apply_recipe
motion.apply_speed_graph
motion.remove_channel
motion.set_transform
motion.set_opacity
```

### 10.6 Recipes

```text
recipe.video_pip
recipe.circular_pip_to_corner
recipe.blur_background_from_media
recipe.spring_text_pop
recipe.lower_third_enter
recipe.shape_reveal
recipe.image_card_slide
```

Recipes must compile into ordinary surfaces, style patches, and motion
channels. Recipes are not a second runtime.

### 10.7 Spatial Awareness And Layout Commands

```text
canvas.get_metadata
surface.get_geometry
layout.get_visual_summary
surface.position.at_anchor
surface.align_to
surface.fit_in_zone
surface.scale_to
surface.center_in
surface.distribute
surface.keep_in_canvas
layout.suggest_composition
layout.validate_intent
layout.preview_change
layout.detect_overlaps
layout.score_safe_area
capture.frame
```

These commands are shared by MCP and future manual UI. They must not become
agent-only tools.

## 11. Visual Effects Catalog

All effects below must be represented as editable data with preview/export
capability reporting.

### 11.1 Shared Effects For Video, Image, Text, Shape

```text
transform: position, scale, rotation, anchor, skew
opacity
crop: contain, cover, sourceRect, focal point
mask: rect, roundedRect, circle, ellipse, custom path, asset matte
border/stroke
shadow
glow
blur
color: brightness, contrast, saturation, hue, tint
blend mode
motion blur
clip lifetime and z-order
```

### 11.2 Video-Specific

```text
source trim
source speed
freeze frame
loop
audio mute/volume
background blur from video
picture-in-picture
face-safe crop
edge fill / motion tile
```

### 11.3 Image-Specific

```text
pan/zoom
ken burns
background blur
rounded/circle crop
drop shadow/glow
```

### 11.4 Text-Specific

```text
font family
font weight
font size
line height
letter spacing
alignment
text frame
auto-fit
typewriter progress
caret binding
text fill/stroke/shadow/glow
per-word/per-line reveal
```

### 11.5 Shape-Specific

```text
rect
rounded rect
circle
ellipse
line
path
fill
stroke
trim path
dash
corner radius
shape morph
```

## 12. Master Frame Evaluation

Create or formalize one evaluator:

```text
MasterFrameEvaluator
```

Input:

```text
CompositionGraph
FrameContext
Assets
Capabilities
```

Output:

```text
EvaluatedFrameTruth
```

Required evaluated data:

```json
{
  "frame": 310,
  "surfaces": [
    {
      "surfaceId": "surface_video_01",
      "visible": true,
      "sourceTimeMs": 3334,
      "bounds": {},
      "transform": {},
      "style": {},
      "effects": [],
      "drawOrder": 20,
      "diagnostics": []
    }
  ]
}
```

No renderer adapter may calculate its own motion values from raw UI state after
this stage.

## 13. Master Visual Program

Create or formalize one renderer-neutral visual program:

```text
MasterVisualProgram
```

It must describe what to draw, not how a specific renderer draws it.

Example:

```json
{
  "programVersion": "refusion.masterVisualProgram/v1",
  "composition": {"width": 1080, "height": 1920},
  "drawCommands": [
    {
      "type": "surface",
      "surfaceId": "surface_video_01",
      "source": {"kind": "video", "assetId": "asset_video_01"},
      "time": {"sourceTimeMs": 3334},
      "bounds": {"left": 648, "top": 72, "right": 1008, "bottom": 432},
      "transform": {},
      "clip": {"shape": "circle", "radiusPx": 180},
      "border": {"color": "#FFFFFF", "widthPx": 7},
      "glow": {"blurPx": 24, "opacity": 0.22}
    }
  ]
}
```

Renderer adapters consume this. They do not reinterpret authoring payloads.

## 14. Renderer Adapters

### 14.1 Flutter Preview Adapter

Must render:

- video/image/text/shape surfaces,
- transform,
- crop,
- circle and rounded masks,
- border,
- glow,
- shadow,
- opacity,
- z-order,
- selected and unselected states.

Visual style must not appear only when a clip is selected.

### 14.2 Playback Adapter

Must consume the same evaluated frame truth as preview. Playback may optimize
media decoding, but it cannot change bounds, style, crop, mask, effect order,
or motion values.

### 14.3 Live Scrub Adapter

Protected Live Scrub internals must not be touched unless explicitly approved.
The allowed direction is adapter consumption:

```text
Live Scrub receives evaluated visual program / frame state
```

not:

```text
Live Scrub calculates its own clip truth
```

### 14.4 Export Adapter

Export must either:

- render the same visual program with matching semantics, or
- block with explicit unsupported capability diagnostics.

Silent export drops are forbidden.

## 15. Capability And Proof System

Every renderer reports capabilities.

```json
{
  "renderer": "flutterPreview",
  "supports": {
    "video": true,
    "circleMask": true,
    "roundedRectMask": true,
    "border": true,
    "glow": true,
    "shadow": true,
    "textAutoFit": true,
    "motionBlur": false
  }
}
```

Every committed visual command must produce proof:

```json
{
  "commandId": "cmd_...",
  "dataApplied": true,
  "frameEvaluated": true,
  "visualProgramEmitted": true,
  "rendererApplied": true,
  "visualBoundsVerified": true,
  "previewSupported": true,
  "exportSupported": false,
  "exportBlocker": "motionBlur not yet implemented in Stage6"
}
```

For MCP, this is returned through `wait_for_apply`. For manual UI, it powers the
diagnostic panel and undo/redo records.

## 16. Agent And MCP Adapter

MCP tools are adapters over the command dispatcher.

Required rule:

```text
MCP tool -> EditorCommand -> Transaction -> Visual Proof
```

MCP must not:

- write raw `solid` rows for animation;
- store mask/border/glow as metadata-only updates;
- create a new background layer when styling a video;
- bypass undo/redo;
- report success before renderer proof.

MCP resources must expose the graph projection:

```text
get_composition_truth_graph
get_canvas_metadata
get_timeline_graph
get_asset_inventory
get_surface_visual_state
get_element_geometry
get_visual_layout_summary
get_motion_channels
get_renderer_capabilities
get_command_status
wait_for_apply
capture_frame
```

MCP tools may expose friendly aliases, but internally they must call the same
operations listed in the universal command taxonomy:

```text
position_at_anchor -> surface.position.at_anchor
align_to -> surface.align_to
fit_in_zone -> surface.fit_in_zone
scale_to -> surface.scale_to
preview_change -> layout.preview_change
```

## 17. Future Manual UI Adapter

The same engine must serve future manual UI:

- toolbar transform tool,
- clip inspector,
- style inspector,
- effects panel,
- crop/mask editor,
- keyframe motion timeline,
- timeline trim/split/move,
- recipe buttons and presets.

Manual UI must call the same command dispatcher used by MCP. The UI may provide
ergonomic controls, but it cannot own separate mutation logic.

## 18. Implementation Phases

### PCVME-00: Inventory, Ownership, And Stop Gates

Create an inventory of every current writer and renderer reader:

- manual UI mutation paths,
- timeline mutation paths,
- transform handles,
- SceneProgram lowering,
- MCP Edge Function writes,
- Supabase/app bridge paths,
- preview render paths,
- playback render paths,
- Live Scrub adapter paths,
- export paths,
- legacy/default ID paths.

Label each path:

```text
canonical
adapter
compatibility
legacy to remove
blocked
```

Exit only when duplicate active writers are known.

### PCVME-01: Composition Identity And Transaction Backbone

Build app-wide transaction truth:

- project/composition IDs,
- active context,
- expected revision,
- command IDs,
- idempotency keys,
- undo/redo entries,
- wrong-context rejection,
- command diagnostics.

No visual mutation ships without undo/redo coverage.

### PCVME-02: Canonical Composition Timeline Graph

Unify:

- project,
- composition,
- assets,
- tracks,
- clips,
- surfaces,
- styles,
- effects,
- keyframes,
- canvas metadata,
- element geometry,
- visual layout summary,
- playhead,
- selection,
- capabilities.

`PACTG` becomes a serialized read projection of this graph, not a second source
of truth.

This phase must expose the sensory layer:

- `canvas.get_metadata`,
- `surface.get_geometry`,
- `layout.get_visual_summary`.

### PCVME-03: Universal Editor Command Dispatcher

Route all input sources into one dispatcher:

```text
manual UI
canvas gestures
timeline gestures
SceneProgram
MCP
presets
future templates
```

All route to canonical commands and transactions.

This phase must include semantic positioning operations:

- `surface.position.at_anchor`,
- `surface.align_to`,
- `surface.fit_in_zone`,
- `surface.scale_to`,
- `surface.center_in`,
- `surface.distribute`,
- `layout.preview_change`,
- `layout.validate_intent`.

Raw numeric transforms remain supported for precise pro workflows, but agents
and high-level UI tools must prefer anchors, zones, and placement solvers.

### PCVME-04: Authored Surface And Visual Style Stack

Promote video/image/text/shape/background to authored surfaces.

Implement:

- `AuthoredSurface`,
- `AuthoredSurfaceEffectStack`,
- `VisualStylePatch`,
- per-kind adapters for video/image/text/shape/background.

Mask, crop, border, shadow, glow, fill, stroke, filters, blend, and opacity must
be renderer-consumed truth.

### PCVME-05: Motion, Keyframe, And SpeedyGraph Gate

All animated values route through:

- unified keyframe operations,
- MotionInterpolationTruthCompiler,
- SpeedyGraph / Bezier timing,
- motion recipe compiler.

No animation may bypass the motion/keyframe engine.

### PCVME-06: Master Frame Evaluator

Implement/standardize deterministic frame evaluation:

```text
composition graph + frame context -> evaluated frame truth
```

This must include source media time, local clip time, bounds, transform, style,
effect values, draw order, and diagnostics.

### PCVME-07: Master Visual Program

Implement/standardize renderer-neutral draw commands.

Preview, playback, Live Scrub adapter, export, screenshot QA, and MCP proof all
consume this program or report a capability block.

### PCVME-08: Preview Renderer Adapter

First visible target:

- Flutter preview shows video/image/text/shape visual style,
- circle/rounded masks work,
- border/glow/shadow render,
- transforms and motion remain attached,
- style works selected and unselected.

### PCVME-09: Playback And Scrub Adapter Gate

Playback must match preview for implemented properties.

Live Scrub protected files are not touched unless explicitly approved. If an
implemented property is not supported by Live Scrub yet, diagnostics must state
that clearly.

### PCVME-10: Export Adapter Gate

Export must either match implemented visual semantics or block with an explicit
reason.

### PCVME-11: MCP Adapter Refactor

Refactor MCP tools to call the command dispatcher.

Legacy MCP rows such as:

```text
operation=animate_layer typed as solid
operation=update_layer with mask/border/glow metadata
```

must be compatibility-routed or rejected, never treated as real background or
successful visual apply.

### PCVME-12: Manual UI Foundation

Wire initial manual UI controls to the dispatcher:

- transform,
- crop,
- mask,
- border,
- glow,
- shadow,
- basic effects,
- keyframe edit.

This can ship after MCP, but the engine must already be designed for it.

### PCVME-13: Device Acceptance And Regression Suite

Run real-device tests:

- create two projects and verify isolation,
- import video,
- insert background,
- add text,
- add shape,
- apply circular video PIP,
- animate text spring,
- apply image crop/shadow,
- verify preview/playback,
- verify command proof,
- verify undo/redo,
- verify no legacy metadata success.

### PCVME-14: Legacy Decommission

Remove or hard-block:

- metadata-only effect success,
- direct UI mutation paths,
- MCP raw row shortcuts,
- `latestSolidColorHex` style background inference,
- production writes using `default`, `active`, `comp_1`, `motion-project`,
  `scene-main`,
- duplicate keyframe/effect engines.

### PCVME-15: Visual Proof And Diagnostics

Make proof app-wide, not MCP-only.

Every visual command must be able to report:

- command accepted,
- transaction committed,
- graph mutated,
- frame evaluated,
- visual program emitted,
- renderer adapter applied,
- visible bounds verified,
- unsupported preview/playback/export capabilities,
- undo/redo record created.

This proof powers:

- MCP `wait_for_apply`,
- manual UI diagnostic panel,
- QA screenshots,
- regression tests,
- export parity blockers.

## 19. Acceptance Gates

### 19.1 Project Isolation

```text
Project A: red background
Project B: blue background
Reopen A: red remains
Reopen B: blue remains
No cross-project leakage
```

### 19.2 Manual And MCP Same Path

```text
Manual transform and MCP transform produce the same command type,
same motion channels, same undo entry, same evaluated frame truth.
```

### 19.3 Video PIP

```text
Existing video clip
circle mask
white border
soft glow
center start
top-right end
correct Story bounds
smooth motion
preview and playback visible
no unrelated background change
```

### 19.4 Text Animation

```text
Text layer gets scale/opacity spring keyframes
Keyframes are editable
Preview plays animation
Background unchanged
```

### 19.5 Image And Shape Effects

```text
Image rounded mask + shadow renders
Shape fill/stroke/corner radius renders
Both can be animated through motion channels
```

### 19.6 Renderer Proof

```text
wait_for_apply or UI proof succeeds only after:
  dataApplied=true
  frameEvaluated=true
  visualProgramEmitted=true
  rendererApplied=true
```

### 19.7 Export Parity Or Block

```text
If export supports the property, output matches preview semantics.
If export does not support it, export blocks with reason.
No silent drops.
```

### 19.8 Spatial Intelligence

```text
get_canvas_metadata returns width, height, fps, duration, origin, anchors, zones.
get_element_geometry returns evaluated bounds for video/image/text/shape.
position_at_anchor(topRight, padding=72) places the surface exactly in safe bounds.
fit_in_zone(upperThird, contain) preserves aspect and avoids overflow.
layout.preview_change predicts bounds and overlap before commit.
```

### 19.9 Reasoning And Vision Loop

```text
layout.get_visual_summary explains the current composition accurately.
capture_frame returns a revision/time-bound visual proof image.
Agent can inspect, propose, validate, apply, and verify without guessing raw coordinates.
```

## 20. Stop List

Do not ship if any of these are true:

```text
A visual edit exists only in Supabase or metadata.
Manual UI edits and MCP edits use different mutation paths.
Undo/redo cannot reverse a shipped authoring mutation.
Composition Truth Graph becomes a second source of truth.
Canvas preview and timeline disagree about layer timing or transform.
Renderer draws from UI slider values instead of evaluated graph state.
Agents must guess canvas size, origin, or element geometry.
High-level positioning requires raw x/y numbers when anchor/zone would be sufficient.
Spatial tools return database approximations instead of evaluated frame bounds.
Animation timing bypasses MotionInterpolationTruthCompiler.
Motion/keyframe rows can mutate background.
Video remains a transport widget instead of a graph-backed surface.
Mask/border/glow render only when selected.
appApplied=true returns before renderer proof.
Export drops supported visual properties silently.
Realtime/polling applies to the wrong project/composition.
Legacy IDs remain in production write paths.
Protected Stage5/Live Scrub internals are touched without explicit slice approval.
```

## 21. Relationship To Existing Plans

This plan is the umbrella.

```text
PCVME
  owns app-wide canvas/timeline/visual/motion truth

PMSTR
  becomes MCP scene-write slice under PCVME-11

PRMEA
  becomes realtime/app-apply slice under PCVME-11 and PCVME-15 proof

PACTG
  becomes graph read projection under PCVME-02

PMCCVT
  becomes first concrete visual-style implementation under PCVME-04/08

professional_refusion_motion_keyframe_engine.md
  remains the motion/keyframe authority under PCVME-05

professional_universal_motion_engine_plan.md
  remains the universal motion graph authority under PCVME-02/05/06
```

## 22. Definition Of Done

The plan is done when the same app-wide engine supports all of this:

```text
User manually inserts video -> timeline and canvas agree.
Agent reads the same video -> sees asset, clip, bounds, style, time.
Agent applies circular PIP -> real mask/border/glow/motion render.
User manually adjusts glow -> same style stack updates.
User edits keyframes -> same motion channels update.
Preview, playback, and export either match or block with reasons.
Undo/redo works for every operation.
No metadata-only success remains.
```

In one sentence:

```text
Every visible edit, from any source, becomes deterministic frame truth and real
pixels on the canvas.
```
