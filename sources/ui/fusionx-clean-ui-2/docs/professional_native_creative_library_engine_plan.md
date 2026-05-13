# Professional Native Creative Library Engine Plan

Short name: `PNCLE`

Status: master execution plan for the ReFusionXx professional creative library,
single-engine capability registry, and After Effects-class authoring model.

Date: 2026-05-14

Package: `com.refusion.app`

Supersedes or absorbs future creative-library-only plans. It extends:

- `professional_single_source_creative_engine_plan.md`
- `professional_universal_agent_node_live_apply_spatial_plan.md`
- `professional_canvas_visual_motion_engine_plan.md`
- `professional_mcp_scene_truth_runtime_plan.md`
- `professional_agent_composition_truth_graph_plan.md`
- `research/hyperframe_and_remotion/analysis/refusion_native_extraction_map.md`

This plan is not MCP-only, not motion-only, not manual-UI-only, and not a
template pack. It defines the one ReFusion-native creative engine that every
input surface must use.

## 0. Executive Decision

ReFusionXx must become a single-body creative system:

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
Preview Renderer / Playback / Export Renderer
```

No feature is real unless it passes through this path.

The plan does not embed HyperFrames or Remotion as primary runtime engines.
Instead, it extracts their proven architecture patterns into ReFusion-native
registries, skills, components, effects, motion recipes, validators, and
render-conformance gates.

## 1. Professional References And Lessons

### 1.1 HyperFrames Lessons

Local research snapshot:

- `research/hyperframe_and_remotion/repos/hyperframes`
- commit `57b6858`
- Apache-2.0
- 7 packages, 1,442 files
- 63 registry items: 8 examples, 51 blocks, 4 components

Important lessons:

- HTML is not what ReFusion should copy. The important ideas are registry,
  skills, deterministic seek, CLI discovery, conformance, blocks/components,
  and adapter discipline.
- HyperFrames has a registry schema with name, type, title, description, tags,
  dimensions, duration, files, previews, and related skills.
- HyperFrames skills are capability-specific: core authoring, CLI,
  registry, media, GSAP, CSS animations, WAAPI, Lottie, Three.js, Anime.js,
  Tailwind, and website-to-video.
- HyperFrames separates examples, blocks, and components. ReFusion should
  separate templates, scene blocks, semantic components, and effect snippets.

### 1.2 Remotion Lessons

Local research snapshot:

- `research/hyperframe_and_remotion/repos/remotion`
- commit `6bef89f`
- custom Remotion License
- 121 packages, 10,528 files

Important lessons:

- Remotion's most useful invariant is not React. It is:

```text
composition metadata + current frame + component graph -> pixels
```

- ReFusion equivalent:

```text
composition metadata + current time/frame + creative graph -> visual program
```

- Remotion exposes width, height, fps, and duration at the composition boundary.
- Remotion's `useCurrentFrame()` maps to ReFusion's master frame evaluator.
- Remotion's `interpolate()` and `spring()` map to ReFusion motion channels and
  easing/speed graphs.
- Remotion's `Sequence` maps to ReFusion timeline clips.
- Remotion packages show how to split transitions, effects, shapes, captions,
  fonts, media, renderer, player, studio, and skills into bounded surfaces.

### 1.3 After Effects Lessons

Official Adobe documentation confirms the professional editor model ReFusion
must emulate:

- Effects and animation presets can save/reuse layer properties, animations,
  keyframes, effects, and expressions. Reference:
  https://helpx.adobe.com/after-effects/using/effects-animation-presets-overview.html
- Expressions expose time conversion, vector math, keyframe-related access, and
  property-level procedural behavior. Reference:
  https://helpx.adobe.com/after-effects/using/expression-language-reference.html
- Motion Graphics templates use Essential Graphics to expose controlled,
  editable properties while preserving the designer's motion structure.
  Reference:
  https://helpx.adobe.com/after-effects/using/creating-motion-graphics-templates.html

ReFusion-native translation:

```text
After Effects Presets      -> ReFusion Native Preset Pack
After Effects Effects      -> ReFusion EffectDefinition + EffectInstance
After Effects Expressions  -> ReFusion ExpressionNode / Procedural Channel
After Effects MOGRT        -> ReFusion TemplateDefinition + Exposed Controls
After Effects Timeline     -> Master Timeline Graph
After Effects Graph Editor -> Master Keyframe/SpeedyGraph Editor
After Effects Layer Stack  -> Universal Timeline Node Stack
```

## 2. Non-Negotiable Laws

### Law 1: One Brain

The brain is the `ProfessionalCreativeLibraryRegistry`.

It is the only place that knows:

- which components exist;
- which effects exist;
- which motion recipes exist;
- which templates exist;
- which icons/assets are legal and available;
- which node families support each capability;
- which renderer/export paths support each capability;
- which agent skill examples are valid;
- which manual UI controls should appear.

If a capability exists outside the registry, it is unofficial and must not be
used by MCP, script, or production UI.

### Law 2: One Nervous System

The nervous system is:

```text
SceneCommand -> Dispatcher -> Apply Engine -> Ack/Proof -> Diagnostics
```

Every creative action must emit a command with:

- stable command id;
- target resolution result;
- operation type;
- transaction id;
- undo patch;
- expected graph revision;
- apply proof requirement;
- renderer/export conformance requirement.

### Law 3: One Body

The body is:

```text
Canonical Creative Graph
Master Timeline Graph
Property Channels
Effect Instances
Motion Channels
Asset Bindings
Spatial Geometry
```

No renderer-only, database-only, widget-only, MCP-only, or script-only payload is
allowed to represent final creative truth.

### Law 4: One Eye

The eye is the `Master Frame Evaluator`.

Every visible result must be frame-evaluable:

```text
graph revision + time/frame + viewport + renderer mode -> evaluated visual truth
```

Preview, live scrub, playback, and export may use different adapters, but they
must consume the same evaluated visual truth.

### Law 5: One Memory

The memory is the combined state of:

- project identity;
- composition identity;
- asset catalog;
- timeline graph;
- creative graph;
- command history;
- undo/redo stack;
- recent projects/compositions;
- local persistence snapshot;
- cloud sync snapshot.

A new composition must be clean. A recent composition must restore its own graph
only. No project may inherit hidden nodes from another project.

## 3. Core Architecture

### 3.0 Single Creative Engine Contract

The only legal creative path is:

```text
Entry Surface
  -> Registry Item
  -> Command Envelope
  -> Apply Transaction
  -> Canonical Creative Graph
  -> Master Timeline Graph
  -> Master Frame Evaluator
  -> Preview Renderer
  -> Export Renderer
```

Entry surfaces:

```text
Manual UI
Paste Script
MCP Agent
Templates
Tap List
Future Tools
```

Each entry surface gets its own adapter, but adapters are translation-only.
They are not allowed to own creative behavior.

```text
ManualUiCommandAdapter
PasteScriptCommandAdapter
McpAgentCommandAdapter
TemplateCommandAdapter
TapListCommandAdapter
FutureToolCommandAdapter
```

All adapters must emit the same `ProfessionalSceneCommandEnvelope`.

Required envelope fields:

```text
commandId
source
transactionId
targetResolution
operationFamily
registryItemId
parameters
expectedGraphRevision
dryRunRequired
undoPolicy
applyProofPolicy
rendererConformancePolicy
exportConformancePolicy
```

If a surface cannot express its action as this envelope, the action is not
production-ready.

### 3.1 ProfessionalCreativeLibraryRegistry

Create one umbrella facade:

```text
ProfessionalCreativeLibraryRegistry
  components
  effects
  motionRecipes
  transitions
  templates
  icons
  typographyPresets
  colorPresets
  assetTreatments
  expressionPresets
  qaRules
  skillExports
  rendererConformance
```

Every sub-registry must use stable ids:

```text
$component.featureCard
$component.progressBar
$effect.glow
$effect.mask.circle
$motion.popUpSpring
$transition.lightLeak
$template.productPromo
$icon.upload
$type.kineticTitle
$color.cinematicWarm
```

### 3.2 Registry Item Contract

Every creative item must declare:

```text
id
version
title
description
category
tags
sourceInspiration
licenseStatus
supportedNodeFamilies
parameterSchema
defaultParams
requiredAssets
supportedAspectRatios
defaultDurationMs
timelineBehavior
spatialBehavior
compileContract
loweringContract
manualUiControls
mcpExamples
pasteScriptExamples
templateExamples
previewPoster
previewMotion
qaRules
rendererConformance
exportConformance
failureMode
```

No item may be listed without a conformance declaration.

### 3.3 Command Taxonomy

Upgrade command families so every creative operation is first-class and not
smuggled through `insertLayer` or legacy payload fields.

Required command families:

```text
insertComponent
updateComponent
insertTemplate
compileTemplate
insertText
updateText
setTypography
insertShape
updateShape
insertMedia
updateMediaBinding
setLayout
setTransform
applyEffect
updateEffect
removeEffect
applyMotionRecipe
applyKeyframes
editKeyframe
applyTransition
updateTransition
insertAdjustmentLayer
updateExposedControl
deleteNode
groupNodes
ungroupNodes
```

Rules:

- insert commands create new graph nodes;
- update commands target existing graph nodes;
- motion commands create or update motion channels;
- effect commands create or update effect instances;
- template commands compile into editable graph nodes;
- delete commands must create undo patches;
- no command family can be implemented for MCP only.

### 3.4 SceneProgram Expansion Gate

`SceneProgram` must be expanded until it can represent every professional
creative concept that the registry exposes.

Required model domains:

```text
scene identity
composition metadata
asset bindings
layers/nodes
components
component slots
groups/precomps
timeline clips
text properties
shape geometry
media trims
media fit/crop
masks
track matte-like relationships
effect instances
effect stacks
adjustment layers
transitions
motion channels
keyframes
expressions/procedural channels
exposed controls
renderer conformance annotations
export conformance annotations
```

No effect, component, template, or animation may survive only as metadata.
It must lower into graph/timeline/channel/effect objects.

### 3.5 Renderer Conformance Contract

Every registry item must state:

```text
previewSupported: true|false
playbackSupported: true|false
liveScrubSupported: true|false
exportSupported: true|false
frameEvaluatorSupported: true|false
timelineEditable: true|false
fallbackMode: none|blocked|approximation|prerender
diagnosticCode
```

If `previewSupported=false`, the manual UI and MCP must show the blocker before
the user believes the item is applied.

### 3.6 Export Support Gate

Export support is part of the registry contract, not an afterthought.

Every item must declare:

```text
previewConformance
playbackConformance
liveScrubConformance
exportConformance
exportBackend
exportParityRisk
```

The export parity gate must read registry conformance before rendering. If a
creative item is preview-only, approximation-only, or prerender-only, the user
and agent must see that before export.

Export acceptance:

```text
same graph revision
same frame evaluator
same property/effect/motion channels
same visual program or declared renderer-specific adapter
no unsupported effect hidden in metadata
no successful export if visual parity is unknown
```

### 3.7 Capability Matrix

Build a central matrix:

| Capability | Video | Image | Text | Shape | Background | Audio | Group | Adjustment |
|---|---|---|---|---|---|---|---|---|
| transform | yes | yes | yes | yes | yes | no | yes | yes |
| opacity | yes | yes | yes | yes | yes | yes | yes | yes |
| mask | yes | yes | yes | yes | yes | no | yes | yes |
| border | yes | yes | yes | yes | yes | no | yes | no |
| shadow | yes | yes | yes | yes | yes | no | yes | no |
| glow | yes | yes | yes | yes | yes | no | yes | no |
| color grade | yes | yes | limited | limited | yes | no | yes | yes |
| typography | no | no | yes | no | no | no | no | no |
| audio volume | no | no | no | no | no | yes | no | no |
| motion recipe | yes | yes | yes | yes | yes | limited | yes | yes |

This matrix is enforced at command validation time.

### 3.8 Existing Capability Upgrade Gate

Existing ReFusion capabilities are not deleted or rebuilt by default.

Current working foundations such as:

```text
position
scale
opacity
rotation
keyframes
SpeedyGraph
MotionPropertyChannelModel
motion blur
gaussian blur
edge fill / motion tile
timeline clips
SceneProgram import/lowering
existing text/shape/media insertion
existing renderer/native implementations
```

must be preserved when they are already correct.

The professional process is:

```text
inventory existing capability
        ↓
compare with HyperFrames / Remotion / After Effects reference patterns
        ↓
identify missing contract, weak parameter schema, weak renderer support,
weak export support, weak UI/MCP exposure, or weak skill documentation
        ↓
wrap into ProfessionalCreativeLibraryRegistry
        ↓
upgrade only the weak edge
        ↓
add conformance tests
```

This means:

- do not rewrite `scale` or `position` animation if the keyframe/channel engine
  already evaluates correctly;
- do not rewrite motion blur or gaussian blur if the renderer/export backend is
  already sound;
- do not replace SpeedyGraph with Remotion interpolation; map Remotion-style
  easing knowledge into SpeedyGraph-compatible presets;
- do not replace native renderer effects with HTML/React/GSAP versions;
- do not preserve a feature blindly if it is metadata-only, preview-only,
  export-broken, or invisible to MCP/manual UI.

Every existing capability receives a review record:

```text
id
currentImplementation
currentOwners
currentEntrySurfaces
currentRendererSupport
currentExportSupport
currentTimelineProjection
currentMcpSupport
currentManualUiSupport
hyperframesLessons
remotionLessons
afterEffectsLessons
weaknesses
upgradeActions
conformanceTests
decision: keep | wrap | upgrade | replace
```

Decision meanings:

- `keep`: implementation is sound; only document it in the registry.
- `wrap`: implementation is sound but hidden; expose it through registry,
  manual UI, MCP, skills, and tests.
- `upgrade`: implementation mostly works but needs schema, lowering, renderer,
  export, proof, or UX improvements.
- `replace`: implementation is architecturally wrong, duplicated, metadata-only,
  or impossible to make conformant.

This gate is mandatory before adding new HyperFrames/Remotion-inspired packs.

## 4. Native Library Domains

### 4.1 Component Registry

Required component families:

```text
cards
buttons
badges
lower thirds
captions
progress bars
stats
waveforms
charts
app showcases
social overlays
PIP video frames
hero sections
feature grids
quote blocks
notification cards
dashboard panels
device frames
icon rows
timeline callouts
comparison tables
checklists
pricing blocks
testimonial blocks
before/after frames
```

Every component must lower to editable graph nodes:

```text
component root
slots
shape nodes
text nodes
icon nodes
image/video nodes
effect instances
motion channels
timeline clips
```

No component may be inserted as a flattened image/video unless explicitly
marked as non-editable prerender output.

### 4.2 Effect Registry

Required effect families:

```text
mask
crop
border
rounded corners
shadow
glow
blur
motion blur
edge fill / motion tile
grain
vignette
light leak
chromatic aberration
halftone
wave/ripple
distortion
color grade
LUT
brightness
contrast
saturation
hue
temperature
tint
blend mode
track matte
alpha matte
adjustment layer
```

Every effect must be an `EffectDefinition` plus `EffectInstance`.

```text
EffectDefinition
  id
  family
  parameterSchema
  supportedNodeFamilies
  defaultPresets
  animatableParameters
  rendererBackend
  exportBackend
  orderingRules

EffectInstance
  id
  definitionId
  targetNodeId
  params
  enabled
  startMs
  durationMs
  parameterChannels
```

Effect parameters must be animatable if the registry says they are animatable.

### 4.3 Motion Recipe Registry

Required groups:

```text
entrance
exit
emphasis
text animation
video/PIP
card choreography
group cascade
transition
camera-like motion
data/progress motion
icon micro-interaction
```

Every recipe lowers into canonical channels:

```text
MotionPropertyChannelModel
  targetNodeId
  propertyPath
  keyframes
  easing
  speedGraph
  authoringRecipeId
```

Supported properties:

```text
transform.position.x
transform.position.y
transform.scale.x
transform.scale.y
transform.rotation.z
opacity
mask.radius
mask.feather
crop.left/right/top/bottom
effect.<id>.<param>
text.characterOffset
text.wordProgress
audio.volume
```

No motion may remain in `payload.motion`, `payload.animation`, or arbitrary
metadata after apply.

### 4.4 Template Registry

Templates are ReFusion-native, editable scene programs.

Each template must include:

```text
id
intent
durationMs
aspectRatios
requiredAssets
optionalAssets
componentIds
effectIds
motionRecipeIds
exposedControls
editableSlots
compileToSceneProgram
qaChecklist
previewPoster
previewVideo
```

After Effects MOGRT inspiration maps to:

```text
TemplateDefinition + ExposedControlDefinition + EditableSlotDefinition
```

The designer controls what is exposed; the user/agent can safely customize only
those exposed controls unless using advanced edit mode.

### 4.5 Icon And Asset Registry

Required:

- semantic icon ids;
- brand icon licensing status;
- fallback icon;
- vector path source;
- render size constraints;
- style variants;
- animation presets;
- usage tags.

No brand icon can be used unless license status is known.

### 4.6 Expression And Procedural Registry

After Effects expressions inspire this domain.

ReFusion must support procedural channels, but they must still evaluate through
the master frame evaluator:

```text
ExpressionDefinition
  id
  language: refusion-expression-v1
  inputs
  outputType
  deterministic
  bakeableToKeyframes
  safetyRules

ExpressionInstance
  targetNodeId
  propertyPath
  expressionId
  params
```

Examples:

- loop
- wiggle
- bounce
- delay/follow
- audio-reactive pulse
- nearest-keyframe flash
- clamp-to-safe-zone
- auto-fit text

Expression outputs must be bakeable into keyframes for export fallback.

## 5. Input Surface Integration

### 5.1 Manual UI

Manual UI must read directly from the registry:

- component browser;
- effect browser;
- motion browser;
- template browser;
- icon browser;
- typography/style browser;
- parameter inspector;
- timeline effect stack editor;
- graph/keyframe editor;
- exposed controls panel.

Manual UI must never call a private implementation path. It creates
`SceneCommand`s.

Manual UI is considered incomplete for a registry item unless it can:

- discover the item;
- show its description and preview;
- expose its supported parameters;
- apply it to valid selected targets;
- show unsupported target diagnostics;
- undo and redo it;
- reveal the resulting graph/timeline nodes.

### 5.2 MCP Agent

MCP tools must be generated from the registry:

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

Agent must follow:

```text
inspect -> plan -> validate -> apply -> wait_for_apply -> verify
```

MCP is considered incomplete for a registry item unless it can:

- list it;
- describe it;
- validate parameters;
- dry-run target resolution;
- apply through command envelope;
- wait for app proof;
- report renderer/export blockers.

### 5.3 Paste Script

Paste Script must compile to the same commands:

```text
Script JSON
        ↓
SceneCommand list
        ↓
Dispatcher
```

No direct local graph mutation.

### 5.4 Templates And Tap List

Templates and Tap List entries must be registry item instances.

When user taps a preset:

```text
Registry item -> parameter defaults -> SceneCommand -> Unified Apply Engine
```

### 5.5 Future Tools

Every future tool integrates by adding:

- registry definition;
- parameter schema;
- compiler/lowering adapter;
- renderer/export conformance;
- manual UI controls;
- MCP exposure;
- tests.

No future tool gets a private engine.

## 6. Spatial Intelligence Layer

Every operation that changes layout must be spatially aware.

Required services:

```text
CanvasMetadataService
ElementGeometryService
VisualLayoutSummaryService
SafeZoneSolver
AnchorSolver
FitFillSolver
CollisionAndOverlapDetector
MotionPathBoundsValidator
```

Agent/manual/script commands use semantic layout first:

```text
positionAtAnchor(topRight, padding: 32)
fitInZone(upperThird, mode: contain)
centerIn(canvas)
exitTo(right, beyondBoundsBy: elementWidth)
alignTo(layer, horizontalCenter)
```

Raw x/y values remain allowed for advanced pixel editing, but they must declare:

```text
coordinateSystem
origin
unit
targetBoundsBefore
targetBoundsAfter
```

## 7. Apply, Ack, And Proof

Every write command must produce proof:

```json
{
  "commandId": "...",
  "dataApplied": true,
  "localGraphApplied": true,
  "timelineVisible": true,
  "frameEvaluated": true,
  "visualProgramEmitted": true,
  "rendererApplied": true,
  "exportPathSupported": true,
  "targetNodeIds": ["..."],
  "createdGraphNodeIds": ["..."],
  "affectedTimelineClipIds": ["..."],
  "affectedMotionChannelIds": ["..."],
  "affectedEffectInstanceIds": ["..."],
  "operationApplied": "insert|update|effect|motion|template",
  "createdNodeCount": 0,
  "updatedNodeCount": 1,
  "rendererConformance": "supported",
  "exportConformance": "supported",
  "editable": true,
  "prerendered": false
}
```

If any field fails, `appApplied=true` is forbidden.

## 8. QA And Verification

### 8.1 Registry QA

Every item needs tests:

- schema validation;
- parameter defaults valid;
- supported node kinds valid;
- manual UI exposure exists;
- MCP description exists;
- skill example references real ids;
- renderer conformance declared;
- export conformance declared.

### 8.2 Apply QA

For each component/effect/motion/template:

```text
compile
apply
timeline projection
frame evaluation
preview render
export render
ack proof
undo
redo
serialization
restore
```

Required command behavior checks:

```text
dry run
target resolution
apply transaction
undo patch
redo patch
revision rebase
timeline projection
frame evaluate
preview proof
export parity
diagnostic output
```

### 8.3 Visual QA

Use frame capture tests:

- item is visible;
- bounds match expected geometry;
- text does not overflow;
- element stays inside safe zones unless exit is intended;
- preview and export frame hashes/metrics are within tolerance;
- no silent metadata-only success.

### 8.4 Skill QA

Every skill or agent example must be validated against the registry:

- every mentioned component id exists;
- every motion recipe id exists;
- every effect id exists;
- every MCP tool name exists;
- every parameter example passes schema;
- every unsupported combination is described as unsupported;
- no stale HyperFrames/Remotion concept is advertised unless ReFusion has a
  native equivalent.

## 9. Execution Phases

### PNCLE-00: Freeze The Rule

Add an architecture note that says all creative additions must enter through
`ProfessionalCreativeLibraryRegistry` and canonical commands.

Acceptance:

- no new MCP/manual/template creative feature can bypass the registry.

### PNCLE-01: Registry Core Models

Create:

```text
ProfessionalCreativeLibraryRegistry
CreativeLibraryItemDefinition
ComponentDefinition
EffectDefinition
MotionRecipeDefinition
TemplateDefinition
IconDefinition
ExpressionDefinition
RendererConformanceDefinition
ManualUiControlDefinition
McpToolExposureDefinition
QaRuleDefinition
ProfessionalSceneCommandEnvelope
EntrySurfaceAdapterDefinition
CommandFamilyDefinition
```

Acceptance:

- models compile;
- schema tests pass;
- no renderer code touched.

### PNCLE-02: Existing ReFusion Capability Audit And Adapter

Audit and wrap current ReFusion assets:

- `scene_motion_recipe_library.dart`
- `scene_semantic_component_registry.dart`
- `scene_icon_registry.dart`
- existing SceneProgram templates;
- current effect docs/runtime-supported effects.
- existing position/scale/opacity/rotation channels;
- existing SpeedyGraph presets;
- existing motion blur implementation;
- existing gaussian blur implementation;
- existing edge fill / motion tile implementation;
- existing timeline clip projection;
- existing preview/export paths.

For each existing capability, create a review record:

```text
keep | wrap | upgrade | replace
```

The default decision is not `replace`. The default is:

```text
keep working implementation
wrap it in the registry
upgrade missing contracts and conformance
```

Acceptance:

- registry lists existing motion recipes, components, icons, templates, effects;
- every existing animation/effect capability has a review record;
- motion blur, gaussian blur, position, scale, opacity, rotation, and SpeedyGraph
  have explicit registry/conformance entries;
- no working renderer implementation is rewritten without a documented
  `replace` decision and reason.

### PNCLE-03: Discovery APIs

Expose read-only discovery:

```text
list_components
list_effects
list_motion_recipes
list_templates
describe_*
```

Acceptance:

- MCP and internal Dart callers return the same registry data.

### PNCLE-03B: Entry Surface Adapter Layer

Add adapters:

```text
ManualUiCommandAdapter
PasteScriptCommandAdapter
McpAgentCommandAdapter
TemplateCommandAdapter
TapListCommandAdapter
FutureToolCommandAdapter
```

Acceptance:

- every adapter emits `ProfessionalSceneCommandEnvelope`;
- no adapter mutates graph state directly;
- all adapter output can be dry-run before apply.

### PNCLE-04: Manual UI Library Browser

Build read-only browsers:

- components;
- effects;
- motion;
- templates;
- icons.

Acceptance:

- manual UI sees the same ids as MCP.

### PNCLE-05: Command Compilation

Add compilers:

```text
insert_component -> SceneCommand list
apply_effect -> SceneCommand
apply_motion_recipe -> MotionChannel commands
compile_template -> SceneProgram + SceneCommand list
```

Acceptance:

- no command mutates local state directly;
- every compiler emits canonical commands.

### PNCLE-05B: Command Taxonomy Enforcement

Implement first-class command families listed in section 3.3.

Acceptance:

- `insertLayer` can no longer silently mean update, effect, or motion;
- update commands cannot create duplicate nodes;
- motion commands cannot store metadata-only animation;
- effect commands cannot bypass effect instances.

### PNCLE-06: Lowering And Timeline Projection

Every registry item must lower into:

```text
CreativeGraph nodes
Timeline clips
Effect instances
Motion channels
Exposed controls
```

Acceptance:

- inserted item is visible in timeline and graph.

### PNCLE-07: Renderer Conformance Gate

Every item must pass or explicitly fail:

```text
frame evaluator
preview renderer
playback renderer
export renderer
```

Acceptance:

- no registry item reports supported unless visual output is proven.

### PNCLE-07B: Export Parity Gate

Wire registry conformance into export validation.

Acceptance:

- unsupported effect/template/component blocks export with a clear diagnostic;
- preview-only items cannot be silently exported;
- export uses the same graph/frame truth as preview.

### PNCLE-08: HyperFrames-Inspired Packs

Translate, do not copy blindly:

- social overlays;
- lower thirds;
- grain/texture components;
- shimmer sweeps;
- data/chart blocks;
- kinetic type examples;
- product promo blocks;
- VFX transition concepts.

Acceptance:

- every pack item is ReFusion-native and editable.

### PNCLE-09: Remotion-Inspired Packs

Translate:

- interpolate/easing vocabulary;
- spring vocabulary;
- sequence/transition timing;
- shape primitives;
- captions;
- audio visualization;
- light leaks;
- text animation rules.

Acceptance:

- every item lowers to ReFusion primitives and channels.

### PNCLE-10: After-Effects-Class Presets

Build native preset system:

```text
AnimationPreset
EffectPreset
BehaviorPreset
ExpressionPreset
TemplatePreset
```

Acceptance:

- presets can be applied to selected nodes;
- presets can be saved from selected nodes;
- presets preserve keyframes, effect stacks, expressions, and exposed controls.

### PNCLE-11: Essential Controls / Template Controls

Build exposed controls:

```text
ExposedControlDefinition
EditableSlotDefinition
ControlBinding
ValidationRule
```

Acceptance:

- templates expose controlled text/color/layout/media/motion controls;
- advanced internals remain protected unless user enters advanced edit mode.

### PNCLE-12: Agent Skill Generation

Generate or validate skill docs from registry:

- all ids real;
- examples compile;
- tools exist;
- unsupported capabilities are not advertised.

Acceptance:

- no stale skill references;
- agent has exact library knowledge.

### PNCLE-13: Visual Closure Loop

Add:

- preview frame capture;
- layout validator;
- overlap detector;
- safe-zone report;
- before/after proof;
- agent-readable diagnostics.

Acceptance:

- agent can inspect what it built and fix it.

### PNCLE-14: Full Acceptance Suite

End-to-end test:

```text
1. Create clean composition.
2. Insert product promo template.
3. Add card component.
4. Apply glow to card.
5. Apply popUpSpring motion.
6. Add progress bar and waveform.
7. Add video PIP with circular mask and shadow.
8. Modify same text manually.
9. Modify same text through MCP.
10. Paste script adding exit motion.
11. Undo/redo.
12. Scrub frame.
13. Play preview.
14. Export sample.
15. Verify preview/export use same graph.
```

All must pass with one source of truth.

## 10. File/Module Targets

Likely new domain files:

```text
lib/features/editor/domain/creative_library/professional_creative_library_registry.dart
lib/features/editor/domain/creative_library/creative_library_models.dart
lib/features/editor/domain/creative_library/component_registry_adapter.dart
lib/features/editor/domain/creative_library/effect_registry_adapter.dart
lib/features/editor/domain/creative_library/motion_recipe_registry_adapter.dart
lib/features/editor/domain/creative_library/template_registry_adapter.dart
lib/features/editor/domain/creative_library/icon_registry_adapter.dart
lib/features/editor/domain/creative_library/renderer_conformance_registry.dart
lib/features/editor/domain/creative_library/creative_library_command_compiler.dart
lib/features/editor/domain/creative_library/creative_library_command_envelope.dart
lib/features/editor/domain/creative_library/creative_library_entry_adapters.dart
```

Likely MCP additions:

```text
lib/features/editor/domain/mcp/refusion_mcp_tool_registry.dart
supabase/functions/mcp/index.ts
```

Likely UI additions:

```text
lib/features/editor/presentation/widgets/creative_library_browser.dart
lib/features/editor/presentation/widgets/effect_browser.dart
lib/features/editor/presentation/widgets/motion_recipe_browser.dart
lib/features/editor/presentation/widgets/template_browser.dart
lib/features/editor/presentation/widgets/exposed_controls_panel.dart
```

Protected Live Scrub/native renderer files remain untouched unless a later
slice explicitly approves renderer implementation work.

## 11. Stop List

Do not:

- embed Remotion as primary runtime;
- embed HyperFrames as primary runtime;
- rebuild existing working ReFusion capabilities just because HyperFrames or
  Remotion has a similar concept;
- make HTML/React/GSAP timelines editor truth;
- add MCP-only tools;
- add manual-UI-only features;
- add effects that preview cannot render;
- add effects that export cannot render without blocker;
- store motion as metadata only;
- let skills mention non-existent ids;
- insert template output as flattened media unless explicitly non-editable;
- claim appApplied from database success;
- allow duplicate components/effects with different ids for the same concept;
- allow UI, script, and MCP to use different capability lists.

## 12. First Practical Build Slice

Start with a small, hard slice:

```text
PNCLE-01 + PNCLE-02 + PNCLE-03
```

That gives us:

- one creative registry facade;
- existing ReFusion recipes/components/icons/templates wrapped;
- read-only MCP/manual discovery;
- tests proving UI and MCP see the same capabilities.

Only after that should we add new HyperFrames/Remotion-inspired packs.

## 13. Definition Of Done

This plan is done when:

```text
Manual UI can browse and apply the same library as MCP.
MCP can list/describe/apply every supported creative capability.
Paste Script compiles into the same commands.
Templates are editable graph nodes, not flattened media.
Effects are EffectInstances with renderer/export conformance.
Motion is MotionPropertyChannelModel data, not metadata.
Preview and export consume the same evaluated graph.
Agent skills are generated/validated from the registry.
No app path owns a private creative capability.
```

The final product should feel like:

```text
After Effects-class layer/effect/preset thinking
+ Remotion-style deterministic frame logic
+ HyperFrames-style agent/catalog discipline
+ ReFusion-native mobile timeline, preview, and export
```

One brain. One nervous system. One body. One renderer truth.
