# ReFusion Native Extraction Map

This file translates the HyperFrames and Remotion research into a ReFusion-native implementation direction.

## Executive Decision

Do not embed HyperFrames or Remotion as primary runtime engines inside ReFusionXx.

Instead, extract their architecture into a ReFusion-native system:

```text
HyperFrames / Remotion knowledge
        ↓
Professional Creative Library Registry
        ↓
Generated Agent Skills + Manual UI Catalog + MCP Discovery Tools
        ↓
Canonical SceneCommand / SceneProgram
        ↓
Unified Apply Engine
        ↓
Canonical Creative Graph
        ↓
Timeline Clips + Motion Channels + Effect Instances
        ↓
Master Frame Evaluator
        ↓
Preview Renderer + Export Renderer
```

## Why This Is The Correct Direction

Embedding the engines directly creates multiple sources of truth:

- ReFusion timeline vs HTML/React timeline
- ReFusion keyframes vs GSAP/React interpolation
- ReFusion preview vs browser preview
- ReFusion export vs browser/FFmpeg export
- ReFusion editable graph vs flattened web output

That repeats the exact class of bugs currently hurting MCP apply: data exists, but the open editor does not render or own it.

## What We Already Have In ReFusion

| Capability | Existing ReFusion source | Current gap |
|---|---|---|
| Agent authoring skill | `.agents/skills/refusion-native-motion-scene-author/SKILL.md` | Needs to be generated/backed by machine-readable registries |
| SceneProgram/DirectorPlan DSL | `refusion_scene_program_models.dart` and import/lowering services | Must become the only accepted high-level authoring path |
| Motion recipes | `scene_motion_recipe_library.dart` | Needs MCP/manual UI discovery and renderer conformance |
| Easing/speed graphs | `professional_speed_graph_preset_catalog.dart` | Needs unified registry exposure |
| Semantic components | `scene_semantic_component_registry.dart` | Needs visual builders, previews, validators, parameter schemas for every component |
| Icons/brands | `scene_icon_registry.dart` | Needs asset/license matrix and UI/MCP discovery |
| Effects | scattered across docs, Dart models, Android shader/export code | Needs central effect registry |
| Templates | `assets/scene_programs` | Needs typed template catalog with previews and aspect support |
| MCP tools | `refusion_mcp_tool_registry.dart` | Needs creative library discovery tools |

## Required ReFusion Registries

### 1. ProfessionalCreativeLibraryRegistry

Umbrella facade that exposes all creative capabilities to every entry point.

Consumers:

- Manual UI
- MCP Agent
- Paste Script
- Templates
- Tap List
- Future Tools
- QA/validators

### 2. Component Registry

Required categories:

- cards
- buttons
- badges
- lower thirds
- captions
- progress bars
- stats
- waveform
- charts
- app showcases
- social overlays
- PIP video frames
- hero sections
- feature grids
- quote blocks
- notification cards
- dashboard panels

Each component definition must include:

- `id`
- `title`
- `category`
- `tags`
- `parameterSchema`
- `requiredSlots`
- `optionalSlots`
- `supportedAspectRatios`
- `defaultDurationMs`
- `defaultMotionRecipeIds`
- `editableNodeKinds`
- `compileToSceneCommands`
- `previewPoster`
- `manualUiControls`
- `mcpExamples`
- `qaRules`

### 3. Effect Registry

Required effects:

- shadow
- border
- glow
- blur
- mask
- rounded corners
- clip path
- grain
- vignette
- color grade
- LUT
- brightness/contrast/saturation/hue
- chromatic aberration
- light leak
- motion blur
- edge fill/motion tile
- distortion/wave/ripple

Each effect must declare:

- supported node kinds: video/image/text/shape/background/group
- parameter schema
- default presets
- preview renderer support
- export renderer support
- effect ordering rules
- lowering target: shader, vector draw, layer style, material, or frame post-process

### 4. Motion Recipe Registry

Required recipe groups:

- entrances
- exits
- emphasis
- text-specific
- video/PIP
- card/group choreography
- transitions
- progress/data motion
- camera-like motion

Every recipe lowers to:

```text
MotionPropertyChannelModel
property: positionX / positionY / scaleX / scaleY / opacity / rotation / crop / mask / effectParameter
keyframes: [{timeMs, value, easing}]
targetNodeId
compositionId
projectId
```

No recipe may stay as metadata only.

### 5. Template Registry

Template records should include:

- `id`
- `title`
- `intent`
- `durationMs`
- `aspectRatios`
- `requiredAssets`
- `componentIds`
- `motionRecipeIds`
- `effectIds`
- `previewPoster`
- `previewVideo`
- `compileToSceneProgram`
- `qaChecklist`

### 6. Agent Skill Registry

Skills should be generated or validated against the same registry source:

- no stale recipe names
- no unsupported effects
- no fake components
- examples match actual MCP tools
- every write ends with appApplied proof

## Required MCP Discovery Tools

Add tools generated from the registry:

```text
refusion.list_components
refusion.describe_component
refusion.insert_component
refusion.list_effects
refusion.describe_effect
refusion.apply_effect
refusion.list_motion_recipes
refusion.describe_motion_recipe
refusion.apply_motion_recipe
refusion.list_templates
refusion.compile_template
refusion.preview_library_item
refusion.validate_creative_plan
```

These tools must not bypass the canonical command dispatcher.

## Manual UI Integration

Manual UI must read the same registry:

- component browser
- effect browser
- motion recipe browser
- template browser
- icon browser
- style preset picker
- preview thumbnails
- parameter inspector

If an item exists for MCP but not manual UI, the registry is incomplete.

## Renderer Conformance

Every registry item must have a conformance record:

```text
previewSupported: true/false
exportSupported: true/false
timelineEditable: true/false
frameEvaluatorSupported: true/false
failureMode: unsupported|fallback|prerender
```

No item may report success if it only writes data but does not render.

## Optional Sidecar Rule

A local HyperFrames/Remotion-inspired sidecar can be useful for research, preview generation, template conversion, or prerendered special effects.

But if used, it must output one of:

- ReFusion SceneProgram
- ReFusion Creative Graph nodes
- ReFusion motion channels/effect instances
- prerendered media layer explicitly marked non-editable

It must never become the master timeline.

## First Implementation Slice

The smallest professional slice is:

1. Create `ProfessionalCreativeLibraryRegistry`.
2. Register existing ReFusion motion recipes from `scene_motion_recipe_library.dart`.
3. Register existing semantic components from `scene_semantic_component_registry.dart`.
4. Register initial effects from current docs/runtime support.
5. Add MCP discovery tools for list/describe.
6. Add manual UI read-only browser backed by the same registry.
7. Add conformance tests proving the registry item exists, compiles, applies, appears in timeline, evaluates a frame, and exports.

After this slice, we can import HyperFrames/Remotion-inspired packs safely.

## Stop List

- Do not copy Remotion source into ReFusion without legal review.
- Do not make HTML, React, GSAP, or browser output the editor truth.
- Do not add MCP-only creative tools.
- Do not add manual UI-only creative features.
- Do not add registry items without preview/export conformance.
- Do not allow skills to mention non-existent recipes/effects/components.
- Do not flatten editable components into video unless explicitly requested.
