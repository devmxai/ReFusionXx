# Professional Agent Composition Truth Graph Plan

Status: ready for implementation planning  
Package: `com.refusion.app`  
Date: 2026-05-12  
Short name: `PACTG`  
Depends on: `PMSTR` (`professional_mcp_scene_truth_runtime_plan.md`)  

## 1. Executive Decision

ReFusionXx must give every connected AI agent a complete, canonical,
composition-scoped view of the open editor before it asks the agent to author,
move, trim, mask, style, or animate anything.

The new rule is:

```text
open app composition truth
  -> canonical Composition Truth Graph
  -> MCP resources and read tools
  -> agent plans against exact project state
  -> canonical editor transaction
  -> app-applied render acknowledgement
```

An agent must never infer what exists in the timeline from a partial layer list.
It must be able to inspect:

- composition size, fps, duration, safe areas, playhead, selection,
- all user-approved media assets and their metadata,
- all timeline tracks, clips, source ranges, timeline ranges, z-order,
- all visual layers, elements, transforms, crops, masks, styles, effects,
- all motion channels and keyframes,
- current evaluated frame bounds and visibility,
- current capabilities and unsupported operations,
- command/apply status for every mutation.

This plan does not replace `PMSTR`. It extends it. `PMSTR` makes writes become
real editor truth. `PACTG` makes the agent know the whole composition truth
before it writes.

## 2. Product Target

The user must be able to say:

```text
Use my uploaded video.
Create a blurred background from it.
Then make the same video appear in a circular frame with a white border.
Move it from the center to the bottom-right corner like a YouTube explainer.
Keep it trimmed from 00:03 to 00:18.
```

Required agent behavior:

```text
1. Read the open composition.
2. Discover the uploaded video asset, its duration, dimensions, source URI,
   current clip usage, timeline start, source in/out, and visual transform.
3. Ask for clarification only if more than one plausible target exists.
4. Create or update background/video layers with exact timeline ranges.
5. Apply crop/mask/border/glow/style as real visual properties.
6. Apply transform keyframes as real motion channels.
7. Preserve all unrelated layers, colors, clips, and timings.
8. Wait for appApplied=true before telling the user it worked.
```

## 3. Current Gap

The current MCP surface is still too narrow for a professional video editor.

Current useful parts:

- `get_active_context` can identify active project/composition context.
- `get_layers` can return remote layer rows from Supabase.
- `get_motion_channels` can return basic motion channels.
- `insert_layer`, `apply_motion_patch`, and `set_element_transform` can write
  some editor intent.

Critical missing truth:

- no complete asset inventory for uploaded videos/images/audio,
- no canonical timeline graph with tracks, clips, source ranges, split groups,
- no read surface for current media clip transforms and canvas placement,
- no read surface for crop, mask, border, glow, shadow, and visual effects,
- no evaluated frame resource for "what is visible at time T",
- no composition-scoped operation capabilities for each selected object,
- no transaction diff preview before commit,
- no guaranteed app-applied receipt for every visual change,
- no first-class media operations such as trim, split, duplicate, move, replace,
  rounded crop, circular mask, border, glow, and picture-in-picture recipes.

The result is that an agent can write a row, but cannot reliably understand the
real editor state. That is why sophisticated requests collapse into guesses.

## 4. Non-Negotiable Principle

The agent may be powerful, but it must not be blind.

```text
No full Composition Truth Graph -> no complex write.
No asset metadata -> no media edit.
No timeline graph -> no trim/split/move.
No evaluated frame -> no layout-sensitive motion.
No appApplied receipt -> no success claim.
```

## 5. Canonical Composition Truth Graph

Create one canonical graph model that represents everything the agent is allowed
to know about the open composition.

### 5.1 Graph Envelope

```json
{
  "schemaVersion": "refusion.compositionTruthGraph/v1",
  "projectId": "uuid",
  "compositionId": "uuid",
  "revision": 42,
  "appSessionId": "uuid",
  "deviceId": "uuid",
  "generatedAt": "2026-05-12T...",
  "composition": {},
  "playhead": {},
  "selection": {},
  "assets": [],
  "timeline": {},
  "scene": {},
  "motion": {},
  "effects": {},
  "capabilities": {},
  "diagnostics": []
}
```

### 5.2 Composition Spec

```json
{
  "id": "comp_...",
  "name": "Story",
  "width": 1080,
  "height": 1920,
  "fps": 30,
  "durationMs": 30000,
  "background": {
    "mode": "transparent|solid|gradient|mediaBlur",
    "layerId": "layer_bg"
  },
  "safeAreas": {
    "title": { "x": 64, "y": 128, "width": 952, "height": 1664 }
  }
}
```

### 5.3 Asset Registry

All media imported by the user must be registered before the agent can use it.
This registry must never expose private local filesystem paths to external
agents unless the user explicitly allows it. Use stable asset IDs and approved
read URIs.

```json
{
  "assetId": "asset_video_01",
  "kind": "video",
  "label": "talking-head.mp4",
  "sourceUri": "refusion-asset://asset_video_01",
  "durationMs": 48231,
  "width": 1920,
  "height": 1080,
  "fps": 30,
  "hasAudio": true,
  "audioChannels": 2,
  "thumbnailUri": "refusion-thumb://asset_video_01",
  "isUserImported": true,
  "isAvailableOnDevice": true,
  "canUseInMcp": true
}
```

### 5.4 Timeline Graph

Timeline must be explicit. The agent must see clip timing, source timing, track
order, split lineage, and overlap rules.

```json
{
  "timelineId": "main",
  "durationMs": 30000,
  "tracks": [
    {
      "trackId": "track_video_1",
      "kind": "video",
      "index": 1,
      "locked": false,
      "muted": false,
      "clips": [
        {
          "clipId": "clip_talk_01",
          "assetId": "asset_video_01",
          "layerId": "layer_talk_01",
          "timelineStartMs": 0,
          "timelineDurationMs": 15000,
          "sourceStartMs": 3000,
          "sourceDurationMs": 15000,
          "playbackRate": 1.0,
          "splitGroupId": null,
          "zIndex": 20,
          "label": "talking-head"
        }
      ]
    }
  ]
}
```

### 5.5 Scene Layer Graph

Scene graph must expose render hierarchy and visual state, not just database
layer rows.

```json
{
  "layers": [
    {
      "layerId": "layer_talk_01",
      "kind": "media",
      "mediaKind": "video",
      "name": "Talking Head PIP",
      "trackId": "track_video_1",
      "clipId": "clip_talk_01",
      "zIndex": 20,
      "visibleRangeMs": { "start": 0, "duration": 15000 },
      "elements": [
        {
          "elementId": "element_talk_01",
          "kind": "videoClip",
          "sourceBinding": {
            "assetId": "asset_video_01",
            "sourceStartMs": 3000,
            "sourceDurationMs": 15000
          },
          "transform": {
            "x": 540,
            "y": 960,
            "scaleX": 1.0,
            "scaleY": 1.0,
            "rotationDeg": 0,
            "opacity": 1
          },
          "crop": {
            "rect": { "x": 0, "y": 0, "width": 1, "height": 1 },
            "fit": "cover"
          },
          "mask": {
            "type": "none|circle|roundedRect|rect|path",
            "radius": null,
            "feather": 0
          },
          "style": {
            "borderWidth": 0,
            "borderColor": "#FFFFFF",
            "glow": null,
            "shadow": null
          }
        }
      ]
    }
  ]
}
```

### 5.6 Motion Graph

Motion must expose every animatable property with target address, keyframes,
time basis, and easing.

```json
{
  "channels": [
    {
      "channelId": "motion_01",
      "target": {
        "layerId": "layer_talk_01",
        "elementId": "element_talk_01"
      },
      "propertyId": "transform.position.x",
      "timeBasis": "timeline",
      "keyframes": [
        { "timeMs": 0, "value": 540, "easing": "easeOutCubic" },
        { "timeMs": 900, "value": 842, "easing": "easeOutCubic" }
      ]
    }
  ]
}
```

### 5.7 Effects Catalog And Capability Graph

The agent must know what is supported before it writes.

```json
{
  "capabilities": {
    "media.video.trim": "supported",
    "media.video.split": "supported",
    "media.video.mask.circle": "supported",
    "media.video.mask.roundedRect": "supported",
    "media.video.border": "supported",
    "media.video.glow": "supported",
    "media.video.motion.transform": "supported",
    "media.video.exportParity": "supported|previewOnly|blocked"
  },
  "unsupportedReasons": []
}
```

## 6. MCP Resources

Expose the graph through read-only MCP resources. These resources are the
agent's eyes.

Required resources:

```text
refusion://project/active/context
refusion://composition/active/spec
refusion://composition/active/truth-graph
refusion://timeline/active/graph
refusion://media/assets
refusion://scene/layers
refusion://motion/channels
refusion://effects/catalog
refusion://selection/current
refusion://playhead/current
refusion://frame/evaluated/{timeMs}
refusion://preview/frame/{timeMs}
refusion://commands/{commandId}
refusion://transactions/recent
```

Every mutating tool must be able to cite the resource revision it used:

```json
{
  "expectedRevision": 42,
  "basedOnGraphRevision": 42
}
```

## 7. MCP Read Tools

Add read tools for agents that cannot consume resources directly.

```text
refusion.get_project_snapshot
refusion.get_composition_spec
refusion.get_timeline_graph
refusion.get_media_assets
refusion.get_scene_layers
refusion.get_motion_channels
refusion.get_effects_catalog
refusion.get_selection
refusion.evaluate_frame
refusion.capture_preview_frame
refusion.inspect_layout
refusion.explain_capabilities
```

`get_project_snapshot` must be the default first call for any complex request.
It returns the compact graph. Other tools return focused slices.

## 8. MCP Write Tools

Separate intent by domain. Do not overload `insert_layer` for every operation.

### 8.1 Timeline And Media

```text
refusion.insert_media_clip
refusion.trim_clip
refusion.split_clip
refusion.move_clip
refusion.duplicate_clip
refusion.delete_clip
refusion.replace_media_source
refusion.set_clip_speed
refusion.set_clip_volume
refusion.set_clip_duration
```

### 8.2 Visual Layer Authoring

```text
refusion.insert_background
refusion.update_background
refusion.insert_text
refusion.update_text
refusion.insert_shape
refusion.update_shape
refusion.insert_image_layer
refusion.update_layer_style
```

### 8.3 Crop, Mask, Border, Glow

```text
refusion.set_crop
refusion.set_fit_mode
refusion.set_layer_mask
refusion.set_rounded_crop
refusion.set_border
refusion.set_glow
refusion.set_shadow
refusion.apply_effect
refusion.remove_effect
```

### 8.4 Motion

```text
refusion.set_layer_transform
refusion.apply_animation_recipe
refusion.apply_keyframes
refusion.keyframe_edit
refusion.remove_animation
```

### 8.5 Transaction

```text
refusion.dry_run_transaction
refusion.commit_transaction
refusion.undo_transaction
refusion.redo_transaction
refusion.wait_for_app_apply
```

## 9. Universal Command Envelope

All write tools must lower into one command envelope.

```json
{
  "schemaVersion": "refusion.command/v1",
  "commandId": "cmd_...",
  "transactionId": "txn_...",
  "agentSessionToken": "redacted",
  "projectId": "uuid",
  "compositionId": "uuid",
  "expectedRevision": 42,
  "basedOnGraphRevision": 42,
  "idempotencyKey": "agent-turn-7-op-2",
  "mode": "dryRun|commit",
  "commandType": "media.clip.trim",
  "target": {
    "clipId": "clip_talk_01",
    "layerId": "layer_talk_01"
  },
  "payload": {},
  "appApplyPolicy": {
    "waitForAppApply": true,
    "timeoutMs": 5000,
    "requireCanvasVisible": true,
    "requireTimelineVisible": true
  }
}
```

Success response:

```json
{
  "ok": true,
  "commandId": "cmd_...",
  "transactionId": "txn_...",
  "revisionBefore": 42,
  "revisionAfter": 43,
  "status": "app_applied",
  "appApplied": true,
  "affectedObjects": ["clip_talk_01", "layer_talk_01"],
  "timelineDiff": [],
  "visualDiff": [],
  "diagnostics": []
}
```

## 10. Picture-In-Picture Recipe Contract

The reference images imply a reusable recipe. Build it as a first-class editor
recipe, not as ad hoc keyframes.

Tool:

```text
refusion.apply_video_pip_recipe
```

Payload:

```json
{
  "sourceClipId": "clip_talk_01",
  "mode": "circlePip",
  "timelineRangeMs": { "start": 0, "duration": 15000 },
  "sourceRangeMs": { "start": 3000, "duration": 15000 },
  "background": {
    "type": "blurredDuplicate",
    "blurRadius": 36,
    "dim": 0.35
  },
  "pip": {
    "shape": "circle",
    "diameter": 248,
    "borderWidth": 4,
    "borderColor": "#FFFFFF",
    "glow": {
      "color": "#FFFFFF",
      "blur": 18,
      "opacity": 0.28
    }
  },
  "motion": {
    "from": { "x": 540, "y": 960, "scale": 1.0 },
    "to": { "x": 870, "y": 1450, "scale": 0.34 },
    "durationMs": 900,
    "easing": "easeOutCubic"
  }
}
```

Required result:

```text
background duplicate layer -> timeline visible
foreground video layer -> circular mask
border/glow -> style graph
transform keyframes -> motion graph
appApplied=true -> after visible render
```

## 11. Implementation Phases

### PACTG-00: Inventory And Boundary Audit

- List existing editor truth sources:
  - `MotionProject`,
  - timeline tracks/clips,
  - imported `EditorAssetItem`,
  - export graph models,
  - motion channels,
  - effects/style/mask models.
- Document which are local-only and which are cloud-visible.
- Confirm no protected Live Scrub file must be touched.

Acceptance:

```text
One inventory table maps each truth source to MCP visibility and gap status.
```

### PACTG-01: Composition Truth Graph Domain Model

- Add canonical Dart models for `CompositionTruthGraph`.
- Include composition, assets, timeline, scene, motion, effects, selection,
  playhead, capabilities, diagnostics.
- Add JSON serialization with stable schema version.

Acceptance:

```text
Unit test serializes a composition with video, text, shape, mask, and motion.
```

### PACTG-02: Local Graph Builder

- Build graph from the currently open Flutter editor state.
- Capture imported asset metadata from `EditorAssetItem`.
- Capture timeline clips with timeline/source ranges.
- Capture visual layer tree and resolved transform/style/mask properties.
- Capture motion channels and keyframes.

Acceptance:

```text
Opening a composition with one imported video returns asset duration, width,
height, clip source range, timeline range, and layer transform.
```

### PACTG-03: Active Context Sync Upgrade

- Update active context heartbeat to publish:
  - project/composition IDs,
  - revision,
  - graph revision,
  - playhead,
  - selection,
  - active tool,
  - app apply state.
- Remove any reliance on `default`, `active`, `comp_1`, `scene-main`, or
  singleton timelines in production paths.

Acceptance:

```text
Two compositions opened sequentially produce two distinct graph contexts.
```

### PACTG-04: Asset Registry Sync

- Add Supabase table or app-session resource for user-approved assets.
- Store sanitized asset metadata:
  - asset ID,
  - kind,
  - duration,
  - dimensions,
  - fps,
  - hasAudio,
  - thumbnail reference.
- Do not leak raw local file paths to external agents.

Acceptance:

```text
MCP get_media_assets returns the uploaded video with correct duration and size.
```

### PACTG-05: Timeline Graph Resource

- Expose tracks, clips, timeline ranges, source ranges, playback rate, split
  groups, z-order, locked/muted flags.
- Add `get_timeline_graph`.

Acceptance:

```text
Agent can identify the currently selected video clip and its exact trim range.
```

### PACTG-06: Scene Layer Graph Resource

- Expose render layer hierarchy and element-level properties.
- Include transform, crop, mask, border, glow, shadow, opacity, blend mode,
  text/style, shape geometry, media binding.
- Add `get_scene_layers`.

Acceptance:

```text
Agent can tell whether a video is full-frame, circular, rounded, or uncropped.
```

### PACTG-07: Evaluated Frame Resource

- Add `evaluate_frame(timeMs)` returning:
  - visible layers,
  - resolved bounds,
  - masks,
  - opacity,
  - z-order,
  - offscreen/overlap diagnostics.
- Add optional `capture_preview_frame(timeMs)`.

Acceptance:

```text
Agent can verify that a PIP circle is bottom-right and fully inside canvas.
```

### PACTG-08: Capability Catalog

- Expose supported operations by element kind:
  - video trim/split/mask/border/glow/transform,
  - image crop/mask/style,
  - text style/animation,
  - shape geometry/stroke/fill,
  - audio trim/volume.
- Include export parity status:
  - `supported`,
  - `previewOnly`,
  - `blocked`,
  - `requiresNativeParity`.

Acceptance:

```text
Agent refuses unsupported operations with a precise reason and repair option.
```

### PACTG-09: Domain-Specific Write Tools

- Implement timeline/media tools:
  - `insert_media_clip`,
  - `trim_clip`,
  - `split_clip`,
  - `move_clip`,
  - `duplicate_clip`.
- Implement style/mask tools:
  - `set_layer_mask`,
  - `set_rounded_crop`,
  - `set_border`,
  - `set_glow`,
  - `set_shadow`.
- Implement media transform tools:
  - `set_layer_transform`,
  - `apply_animation_recipe`,
  - `apply_keyframes`.

Acceptance:

```text
No complex media command is routed through generic insert_layer.
```

### PACTG-10: Transaction And Dry Run

- Every multi-step edit must run as a transaction.
- Dry run returns timeline diff, visual diff, conflicts, and expected revision.
- Commit requires unchanged `expectedRevision`.
- All commands support `idempotencyKey`.

Acceptance:

```text
PIP recipe dry run shows background duplicate + foreground masked video +
motion channels before commit.
```

### PACTG-11: App Apply Receipts

- App must acknowledge each committed command after local apply.
- Receipt must include:
  - command ID,
  - graph revision after apply,
  - affected objects,
  - timeline visible status,
  - canvas visible status,
  - render diagnostic status.

Acceptance:

```text
Agent cannot report success until appApplied=true.
```

### PACTG-12: PIP Recipe

- Implement `apply_video_pip_recipe`.
- Support:
  - blurred duplicate background,
  - circular mask,
  - rounded rectangle mask,
  - border,
  - glow/shadow,
  - center-to-corner motion,
  - timeline/source range preservation.

Acceptance:

```text
Given one uploaded talking-head video, the agent creates the reference-style
PIP layout with visible timeline layers and correct playback.
```

### PACTG-13: Agent Prompt And Skill Contract

- Update agent-facing MCP descriptions to require:
  - read snapshot first,
  - avoid guessing target clips,
  - use domain-specific tools,
  - dry-run complex edits,
  - wait for app apply.
- Add examples for:
  - trim video,
  - split clip,
  - circular PIP,
  - rounded video card,
  - border/glow,
  - center-to-corner motion.

Acceptance:

```text
ChatGPT uses get_project_snapshot before editing an uploaded video.
```

### PACTG-14: Regression And Device Acceptance

Run device-level tests:

```text
1. Create new Story composition.
2. Upload a video.
3. Pair ChatGPT/Codex.
4. Ask: "Show me what assets are in this composition."
5. Agent returns exact video duration and dimensions.
6. Ask: "Trim it to 3-18s."
7. Timeline clip source range updates.
8. Ask: "Make it a circular PIP with border/glow and move to corner."
9. Timeline shows required layers.
10. Canvas shows circular video.
11. Playback and scrub remain functional.
12. appApplied=true is returned.
```

Acceptance:

```text
All 12 steps pass on a connected Android device.
```

## 12. Security And Privacy

- Expose only assets belonging to the authenticated user and paired project.
- Do not expose raw filesystem paths by default.
- Asset URIs must be scoped to the app/session.
- Pairing token must bind to user, device, project, composition, and capability
  set.
- Every agent read and write must be audit logged.
- User must be able to disconnect the agent immediately.

## 13. Performance Requirements

- `get_project_snapshot` compact mode: less than 500ms on a normal project.
- Full graph mode: less than 1500ms for 100 layers/clips.
- App apply receipt after command commit: less than 1000ms for simple edits.
- Evaluated frame response: less than 750ms for current frame.
- Graph payload must support pagination or section filters for large projects.

## 14. Stop List

Do not implement this as:

- a bigger `get_layers`,
- a generic JSON dump with unstable field names,
- direct UI automation,
- direct Stage5/Live Scrub mutation,
- raw local file path exposure,
- a new parallel editor engine,
- an agent guessing clip IDs from names only,
- a success response before app apply,
- media/mask/effects hidden inside `payload` of `solid`.

## 15. Final Acceptance Definition

This feature is complete only when the following sentence is true:

```text
When the user opens a composition and pairs an agent, the agent can inspect
every permitted asset, clip, layer, element, style, mask, effect, keyframe,
playhead, selection, and capability in that exact composition, then perform a
transactional edit that appears on the open device and returns appApplied=true.
```

If the agent cannot answer "what videos are in this timeline and how long are
they?" the plan is not complete.

If the agent cannot trim/split a video clip without guessing, the plan is not
complete.

If the agent cannot make a video circular with border/glow and animate it from
center to corner as real timeline/render truth, the plan is not complete.

If the change only exists in Supabase and not in the open app, the plan is not
complete.

