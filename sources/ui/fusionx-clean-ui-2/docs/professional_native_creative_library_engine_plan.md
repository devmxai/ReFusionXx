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

### 0.1 Mandatory Pre-Build Evaluation And User Sync Gate

Before implementing any PNCLE phase or slice, the team must complete a strict
pre-build evaluation and share it with the user/reviewer.

No coding is allowed before this gate is complete.

Required pre-build sequence for each slice:

```text
1) analyze current ReFusion implementation for this slice
2) evaluate strengths, weaknesses, and known risks in current code
3) compare against relevant HyperFrames and Remotion references
4) classify each capability path with one decision:
   keep | wrap | upgrade | add | replace | block
5) choose the smallest safe execution slice
6) define acceptance gate and rollback for that slice
7) publish the pre-build report before writing code
```

The pre-build report is mandatory and must include:

```text
slice id
current state summary
reference comparison summary (HyperFrames / Remotion)
gap list
decision table (keep/wrap/upgrade/add/replace/block)
selected execution slice
tests to run
acceptance criteria
rollback command
```

If any decision is ambiguous, risky, or missing evidence, the slice is blocked
until the report is corrected.

Fail conditions:

```text
code changes started without pre-build report
reference comparison missing for relevant capability
decision table missing
acceptance gate missing
rollback path missing
```

Fail action:

```text
stop implementation
revert unapproved edits for that slice
re-enter at pre-build evaluation
```

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
capabilityBenchmark
benchmarkDecision
legacyPathCleanup
failureMode
```

No item may be listed without a conformance declaration.
No item may be listed as production-ready without a completed Capability
Benchmark Matrix record.

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

### 3.9 Capability Benchmark Matrix

Every effect, motion recipe, transition, component, template primitive, media
treatment, and future creative capability must pass a formal Capability
Benchmark Matrix before it can be promoted to production.

This matrix is not optional research. It is the official engineering gate that
decides whether an existing ReFusion capability is kept, wrapped, upgraded,
replaced, or blocked.

Each capability must be scored from 1 to 5 against ReFusion, Remotion, and
HyperFrames where a comparable implementation or pattern exists.

Required benchmark dimensions:

```text
Visual Quality
Temporal Accuracy
Parameter Depth
Performance
Preview/Export Parity
Editability
Determinism
Cross-device Stability
Pipeline Coverage
Agent Usability
```

Score meanings:

```text
1 = unusable or missing
2 = partial / prototype / fragile
3 = usable with important limitations
4 = production-grade with known minor gaps
5 = best-in-class or reference-quality
```

Every score must include three forms of evidence:

```text
codeReference
benchmarkScene
measurementResult
```

Evidence examples:

```text
codeReference:
  - local ReFusion implementation path
  - Remotion or HyperFrames reference path
  - renderer/export adapter path

benchmarkScene:
  - fast linear motion
  - strong rotation
  - scale + rotation
  - kinetic text
  - video with internal motion
  - layer overlap / occlusion

measurementResult:
  - frame evaluation time
  - render/export parity delta
  - visual diff score
  - dropped-frame or latency metric
  - device stability result
```

Decision rules:

```text
if Visual Quality + Temporal Accuracy < 4:
  decision = upgrade
  action = adopt reference algorithm or recipe idea

if Performance < 3:
  decision = upgrade
  action = add tiered quality, fallback, or budget guard

if Preview/Export Parity < 4:
  decision = blocked
  action = no production launch

if Editability < 4:
  decision = prerender-only or upgrade
  action = cannot ship as native editable feature

if Pipeline Coverage < 4:
  decision = upgrade
  action = route Manual UI, Paste Script, MCP, Templates, Tap List, and Future
  Tools through the same command/apply path

if Agent Usability < 4:
  decision = upgrade
  action = add schema, examples, target rules, failure codes, and skill docs
```

Final benchmark decisions:

```text
keep
wrap
upgrade
adoptIdea
replace
prerenderOnly
blocked
reject
```

Registry benchmark record:

```text
CapabilityBenchmarkRecord
  capabilityId
  capabilityFamily
  benchmarkVersion
  comparedAgainst
  dimensions
    visualQuality
    temporalAccuracy
    parameterDepth
    performance
    previewExportParity
    editability
    determinism
    crossDeviceStability
    pipelineCoverage
    agentUsability
  evidence
    codeReferences
    benchmarkScenes
    measurementResults
  strengths
  weaknesses
  adoptedReferenceIdeas
  requiredUpgrades
  cleanupRequired
  decision
  nextActions
  owner
  reviewer
  qaOwner
  releaseOwner
```

Example for motion blur:

```text
capabilityId: $effect.motionBlur
ReFusion:
  strength: native AGSL shader, velocity compiler, shutter controls,
  adaptive samples
Remotion:
  reference: CameraMotionBlur and Trail temporal sampling APIs
HyperFrames:
  reference: blur-through, directional blur, whip-pan, velocity-matched
  transition language
decision: upgrade
nextActions:
  - keep native shader
  - add creative presets
  - add Remotion-style temporal sampling benchmark scenes
  - add HyperFrames-style recipe language
  - prove preview/export parity
  - expose through UI/MCP/script from the registry only
```

### 3.10 Legacy Path Cleanup Gate

Any capability review must include a cleanup pass. The goal is not only to add
new professional behavior, but to remove or quarantine old paths that create
parallel truth.

For each capability, list every current path that can create, mutate, render,
or export it:

```text
manual UI path
paste script path
MCP path
template path
tap list path
legacy local mutation path
renderer-only path
database-only path
metadata-only path
export-only path
```

Each path receives one cleanup decision:

```text
canonicalize: convert it to SceneCommand -> Unified Apply Engine
adapterOnly: keep only as translation layer into canonical commands
featureFlag: keep temporarily behind an explicit compatibility flag
migrate: auto-convert old payloads to canonical graph objects
delete: remove because it is duplicated, wrong, or unsafe
block: fail closed until a conformant implementation exists
```

Cleanup is mandatory when any of these are found:

```text
metadata-only effect storage
renderer-only visual state
MCP-only capability
manual-UI-only capability
paste-script-only mutation
insert command used as update
duplicate target mutation path
preview/export divergence path
legacy fallback that hides renderer failure
```

No capability may be marked `keep`, `wrap`, or `upgrade` unless old/conflicting
paths are explicitly handled. A missing cleanup decision is a release blocker.

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

## 11. Delivery Governance

This plan is not accepted as a professional execution plan unless every phase
has measurable gates, owners, rollback controls, migration rules, and release
governance.

### 11.1 KPIs For Every Phase

Every PNCLE phase must report these KPIs:

```text
apply_success_rate >= 99.5%
appApplied_proof_latency_p95 < 120ms
command_dryrun_validation_pass >= 99%
registry_schema_validation_pass = 100%
manual_ui_mcp_capability_match = 100%
skill_registry_reference_validity = 100%
preview_export_parity_score >= 0.98
unsupported_capability_silent_success = 0
metadata_only_success = 0
capability_benchmark_record_coverage = 100%
legacy_path_cleanup_decision_coverage = 100%
parallel_truth_path_count = 0
```

Phase-specific additions:

| Phase | Extra KPI |
|---|---|
| PNCLE-01 | `registry_core_model_test_pass = 100%` |
| PNCLE-02 | `existing_capability_review_coverage = 100%` |
| PNCLE-03 | `list_describe_tool_parity = 100%` |
| PNCLE-03B | `adapter_direct_mutation_count = 0` |
| PNCLE-05B | `insert_used_for_update_count = 0` |
| PNCLE-07 | `renderer_conformance_unknown_count = 0` |
| PNCLE-07B | `export_unsupported_silent_pass = 0` |
| PNCLE-12 | `stale_skill_reference_count = 0` |
| PNCLE-14 | `full_acceptance_suite_pass = 100%` |

### 11.2 Performance Budgets

Reference device class must be named in each run. Until a device matrix is
formalized, use:

```text
reference_device: Android mid/high device connected through adb
composition_reference: 1080x1920, 30fps
```

Budgets:

```text
frame_eval_budget_p95 <= 8ms for small/medium compositions
frame_eval_budget_p95 <= 16ms for heavy compositions
creative_command_dryrun_p95 <= 20ms
registry_list_query_p95 <= 30ms
registry_describe_query_p95 <= 20ms
apply_engine_local_apply_p95 <= 50ms
appApplied_proof_latency_p95 < 120ms
preview_frame_capture_p95 <= 250ms
export_timeout_budget <= 90s per rendered minute for reference composition
```

Initial structural limits before fallback/diagnostic:

```text
max_effect_instances_per_frame = 64
max_motion_channels_per_node = 32
max_keyframes_per_channel = 240
max_visible_nodes_small = 50
max_visible_nodes_medium = 150
max_visible_nodes_heavy = 400
max_nested_group_depth = 8
max_registry_items_without_preview = 0
```

If a composition exceeds a budget, the system must return a diagnostic:

```text
PERFORMANCE_BUDGET_EXCEEDED
```

not a silent visual failure.

### 11.3 RACI / Ownership

Each phase must define:

```text
Owner
Reviewer
QA Owner
Release Owner
Approver
```

Default ownership map:

| Phase | Owner | Reviewer | QA Owner | Release Owner |
|---|---|---|---|---|
| PNCLE-01 | Domain | Architecture | Unit QA | Release |
| PNCLE-02 | Domain | Renderer + Export | Integration QA | Release |
| PNCLE-03 | MCP/Domain | Architecture | Tooling QA | Release |
| PNCLE-03B | Domain | Architecture | Integration QA | Release |
| PNCLE-04 | UI | Domain | UI QA | Release |
| PNCLE-05 | Domain | UI + MCP | Integration QA | Release |
| PNCLE-05B | Domain | Renderer | Integration QA | Release |
| PNCLE-06 | Domain | Timeline | Timeline QA | Release |
| PNCLE-07 | Renderer | Domain + Export | Visual QA | Release |
| PNCLE-07B | Export | Renderer | Export QA | Release |
| PNCLE-08 | Creative Library | Domain | Visual QA | Release |
| PNCLE-09 | Creative Library | Domain | Motion QA | Release |
| PNCLE-10 | Creative Library | Timeline | Preset QA | Release |
| PNCLE-11 | Templates | UI + Domain | Template QA | Release |
| PNCLE-12 | Agent Skills | MCP + Domain | Skill QA | Release |
| PNCLE-13 | QA Tooling | Renderer | Visual QA | Release |
| PNCLE-14 | Integration | Architecture | Full QA | Release |

No phase can be marked done without named owners in the implementation ticket.

### 11.4 Fixed Milestones

Target dates use Asia/Baghdad calendar dates.

| Milestone | Target date | Required scope |
|---|---:|---|
| M1 | 2026-05-18 | PNCLE-01, PNCLE-02, PNCLE-03: registry core + existing inventory + read-only discovery |
| M2 | 2026-05-23 | PNCLE-03B, PNCLE-05, PNCLE-05B: adapters + command taxonomy + command compilation |
| M3 | 2026-05-29 | PNCLE-06, PNCLE-07, PNCLE-07B: lowering + renderer conformance + export parity |
| M4 | 2026-06-04 | PNCLE-08, PNCLE-09, PNCLE-10: HyperFrames/Remotion-inspired native packs + presets |
| M5 | 2026-06-08 | PNCLE-11, PNCLE-12, PNCLE-13: exposed controls + skill generation + visual closure loop |
| M6 | 2026-06-12 | PNCLE-14: full acceptance suite + launch readiness |

If a milestone slips, the release owner must record:

```text
slip reason
affected phases
new target date
risk impact
scope reduction or staffing plan
```

### 11.5 Risk Register

| Risk | Probability | Impact | Mitigation | Owner |
|---|---|---|---|---|
| Preview/export divergence | High | Critical | Renderer/export conformance gate, parity snapshots, block unsupported items | Renderer + Export |
| MCP generates commands outside schema | High | Critical | Registry-generated schemas, dry-run validation, fail-closed errors | MCP/Domain |
| Registry grows without QA | High | High | No item without schema, preview, conformance, tests, skill validation | Creative Library |
| Existing working effects get broken during wrapping | Medium | High | Existing Capability Upgrade Gate, keep/wrap/upgrade/replace decisions | Domain |
| Manual UI and MCP expose different capabilities | Medium | High | Single registry facade, parity test | UI + MCP |
| Motion remains metadata-only | Medium | Critical | Motion lowering tests, channel proof in ack | Domain + Timeline |
| Renderer supports preview but export lacks feature | Medium | Critical | Export parity gate before release | Export |
| Skill docs mention stale ids | Medium | Medium | Skill registry validation | Agent Skills |
| Performance regressions from heavy effect stacks | Medium | High | Performance budgets, fallback diagnostics | Renderer |
| Legacy commands create duplicate layers | High | High | Migration adapter, insert/update enforcement | Domain |

Every risk must have an owner before implementation begins.

### 11.6 Rollback And Feature Flags

Every new capability family ships behind a feature flag:

```text
creative.registry.core
creative.discovery.mcp
creative.discovery.manual_ui
creative.command_taxonomy.v2
creative.effects.registry
creative.motion.registry
creative.templates.registry
creative.export.conformance_gate
effects.experimental.*
motion.experimental.*
components.experimental.*
templates.experimental.*
```

Rollback rules:

- disable one capability family without disabling the entire editor;
- keep projects readable even if a capability is disabled;
- disabled items show `CAPABILITY_DISABLED` diagnostics;
- no flag removal until two stable releases after launch;
- rollback must not delete graph data.

Emergency rollback examples:

```text
effects.experimental.* -> off
creative.discovery.mcp -> off
creative.command_taxonomy.v2 -> compatibility-only
creative.export.conformance_gate -> warn-only only with release approval
```

### 11.7 Legacy Migration Plan

Legacy behavior must be migrated, not abruptly broken.

Migration targets:

```text
insertLayer as general update path
payload.motion
payload.animation
payload.updates.motion
payload.updates.animation
metadata-only effect storage
latest-solid-wins background inference
MCP-only tool aliases
paste-script-only local mutations
```

Compatibility window:

```text
beta.12: compatibility adapter on, warnings emitted
beta.13: compatibility adapter on, telemetry required, new commands preferred
beta.14: legacy commands fail in strict mode, compatibility mode available
beta.15: legacy aliases removed from production skill docs
```

Migration output must include:

```text
legacyCommandId
newCommandFamily
targetResolution
transformedPayload
warnings
compatibilityMode
```

No old command may silently create duplicate nodes when the user meant update.

### 11.8 Definition Of Ready / Done

Definition of Ready for any slice:

```text
pre-build evaluation report completed and reviewed
current ReFusion analysis completed for the slice
HyperFrames/Remotion comparison completed for the slice
decision table completed (keep/wrap/upgrade/add/replace/block)
schema written
registry item contract written
manual UI contract written
MCP contract written
dry-run behavior defined
undo/redo behavior defined
renderer conformance expectation defined
export conformance expectation defined
tests listed
feature flag named
rollback path named
owner/reviewer/QA/release owner assigned
Capability Benchmark Matrix record drafted
legacy path inventory drafted
cleanup decision drafted for every old or overlapping path
```

Definition of Done for any slice:

```text
pre-build report attached to the implementation checkpoint
unit tests pass
integration tests pass
registry schema validation pass
manual UI/MCP parity pass
dry-run validation pass
apply proof pass
timeline projection pass
frame evaluation pass
preview renderer pass
export parity pass or explicit blocker
performance budget pass
Capability Benchmark Matrix pass
legacy path cleanup pass
no duplicate/parallel creative path remains unowned
skill docs synchronized
release checklist updated
rollback verified
```

### 11.9 Operational Test Matrix

Device classes:

```text
Android low memory
Android mid range
Android high range
Android tablet/foldable where applicable
```

Composition sizes:

```text
small: <= 20 visible nodes, <= 20 motion channels, <= 10 effects
medium: <= 80 visible nodes, <= 120 motion channels, <= 40 effects
heavy: <= 250 visible nodes, <= 500 motion channels, <= 120 effects
stress: above heavy, diagnostic/fallback expected
```

Aspect ratios:

```text
9:16
16:9
1:1
4:5
custom
```

Rendering modes:

```text
editor still preview
live scrub
playback
frame capture
export mp4
export still
```

Input paths:

```text
Manual UI
Paste Script
MCP Agent
Template
Tap List
Future Tool adapter test stub
```

Each release candidate must cover every rendering mode and at least small,
medium, and heavy compositions.

### 11.10 Release Governance

Release checklist:

```text
registry diff reviewed
capability benchmark diffs reviewed
legacy path cleanup decisions reviewed
pre-build evaluation reports reviewed for all shipped slices
feature flags reviewed
skills sync pass
MCP discovery parity pass
manual UI discovery parity pass
conformance snapshots approved
preview/export parity pass
performance budget pass
legacy migration telemetry reviewed
risk register updated
rollback commands tested
release notes updated
```

Release cannot proceed if:

```text
metadata_only_success > 0
unsupported_capability_silent_success > 0
unbenchmarked_production_capability_count > 0
legacy_path_without_cleanup_decision > 0
parallel_truth_path_count > 0
missing_prebuild_evaluation_report_count > 0
preview_export_parity_score < 0.98
skill_registry_reference_validity < 100%
registry_schema_validation_pass < 100%
manual_ui_mcp_capability_match < 100%
```

## 12. Stop List

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
- promote a capability without a Capability Benchmark Matrix record;
- keep an old or overlapping path without a cleanup decision;
- treat subjective visual approval as a substitute for benchmark scenes,
  measurements, and code references.
- start coding any slice before completing and publishing the mandatory
  pre-build evaluation report.

## 13. First Practical Build Slice

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

## 14. Definition Of Done

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
