# Professional Motion

## Status

- document type: architecture reference
- execution status: future reference, not an active implementation slice
- authority: project-owned editor and motion architecture
- dependency: builds on the accepted `Stage 6` exact timeline foundation

## Purpose

This document defines the professional target architecture for a timeline system
that can eventually support:

- script-driven motion
- manual keyframes
- reusable transitions
- reusable effects
- text animation
- shape animation
- camera/viewport motion
- templates and presets
- normalized runtime evaluation
- fast preview
- deterministic export

It is the architecture we should return to when we choose to begin the motion
system for real.

## Executive Verdict

The current timeline foundation is strong enough to serve as the base for a
professional motion system.

It is **not yet** a professional motion system by itself.

The correct path is **not** to redesign the current exact-time timeline from
zero.

The correct path is to add one disciplined architecture layer above it:

1. scene / layer / element identity
2. property channels
3. keyframe model
4. interpolation engine
5. normalization / compile layer
6. deterministic runtime evaluation layer
7. preview and render projections

## Implementation Progress

The internal foundation slices completed so far are:

1. canonical scene / layer / element / property domain models
2. property channels and first keyframe primitives
3. normalized motion composition and compile boundary foundations
4. deterministic runtime evaluation foundations
5. first compile/evaluation helpers without UI binding
6. transition / effect / camera domain foundations without UI binding
7. text animation and text preset domain foundations without UI binding
8. text preset compile / runtime binding without UI
9. text element runtime binding and preview hook foundations without UI
10. text element insertion and binding foundations without bottom-sheet UI yet
11. text preview renderer hook foundations without bottom-sheet UI yet
12. first user-facing text preset hookup
13. custom text preset import foundations

The current editor-facing local layer built on top of those slices now also
includes:

- a dedicated text preset bottom sheet
- project-owned preset JSON validation/import normalization
- canvas text preview rendering through the motion runtime adapter
- direct text edit flow from the timeline via double-tap
- text edit bottom sheet with text/size/basic control editing
- direct move/scale transform overlay on the canvas during text edit

## Reviewed Consensus

This document reflects the combined conclusions of:

- current codebase review
- `Stage 6` timeline precision work
- motion feasibility review
- official `BMF` documentation
- official `Media3` documentation
- architecture monitor review

Consensus summary:

- exact editor time and edit truth must remain application-owned
- preview/runtime backends must consume resolved truth, not own it
- `BMF` is a credible execution/render/export backend, not the authoring model
- `Media3` is preview/transport infrastructure, not the motion authoring model
- future keyframes, scripts, transitions, and effects must all anchor to the
  same canonical time model already introduced in `Stage 6`

## Official Architecture Boundary

Boundaries already locked by the project:

- Flutter/project code owns:
  - editor truth
  - timeline semantics
  - playhead semantics
  - clip/layer identity
  - motion authoring model
  - normalization/compile logic
- `Media3` owns:
  - transport
  - play / pause / seek / scrub
  - preview surface transport behavior
- `BMF/BMFLite` should own:
  - processing
  - compositing execution
  - effect execution
  - export/render backend work

Reference:

- [Stage 4 Architecture Lock](/Users/mx/Documents/InGeneBMFPro/docs/process/stage-4-architecture-lock.md)
- [BMF Motion Architecture Feasibility](/Users/mx/Documents/InGeneBMFPro/docs/research/bmf-motion-architecture-feasibility.md)
- [Stage 6 Foundation Reference - Canonical Timeline Truth For Future Motion, Script, And Export Layers](/Users/mx/Documents/InGeneBMFPro/docs/process/stage-6-foundation-reference-canonical-timeline-truth-for-future-motion-script-export.md)

## What The Current Foundation Already Gives Us

The current timeline foundation is already strong in these areas:

### 1. Exact Time Foundation

The project now owns a canonical exact time primitive:

- `TimelineTime`
- `TimelineTimeRange`
- exact tick-based time with stable rescaling

This is the correct foundation for:

- playhead
- split/trim/delete
- future keyframes
- transition windows
- future export timing

### 2. Exact Clip Window Truth

The current editor truth now models clip windows with exact timing:

- duration
- source start
- source end
- source range

This means the project already owns:

- exact clip placement semantics
- exact source-window semantics
- structural edit math foundation

### 3. Exact Timeline Geometry Foundation

The timeline UI is no longer built only on approximate `double seconds`.

The system now has a viable path for:

- exact playhead placement
- exact split marker placement
- exact scrub dispatch
- exact clip geometry

### 4. Preview Projection Boundary

The project already owns the rule that:

- editor truth is one thing
- native preview is a projection of that truth

That rule is essential. It must remain intact as motion architecture grows.

## What The Current Foundation Does Not Yet Provide

The current system is still primarily a:

- clip/track editor
- preview transport integrator

It is **not yet** a full:

- scene graph
- motion graph
- keyframe engine
- effect engine
- transition engine
- camera engine

Missing today:

- scenes
- element-level identity
- property targets
- keyframes
- interpolation data
- procedural motion evaluators
- transition definitions
- effect parameter tracks
- text animation model
- shape/vector layer model
- camera layer model
- preset/template/plugin registry
- normalized runtime composition format
- deterministic frame-by-frame motion evaluator

## Required End State

The target system must eventually support all of the following as first-class
editor behavior:

- text appears with elastic settling
- text types letter by letter
- blur/opacity/scale/rotation animate over time
- shapes resize, morph, and fade
- reusable transitions apply between clips
- camera push/pull/shake/zoom can be authored
- scripts can generate motion
- templates can be parameterized
- export can render the exact same resolved motion truth

The architecture must support:

- manual keyframes
- structured motion scripts
- AI-generated structured animation data
- reusable presets and plugins

## Target Domain Model

The professional architecture should use the following domain model.

### Project

Owns:

- scenes
- global settings
- shared assets
- preset registry bindings
- export settings

### Scene

Owns:

- scene identity
- local duration
- scene in/out on the project timeline
- layer stack
- camera binding

Scenes are required because a professional system must eventually support:

- scene-local composition
- reusable scene templates
- scene-based scripting
- future nested composition

### Layer

A layer is the compositing row inside a scene.

Examples:

- video layer
- image layer
- text layer
- shape layer
- audio layer
- camera layer
- effect/control layer

Each layer must own:

- stable id
- scene id
- z-order
- enabled/visible flags
- local in/out window
- blend/composite mode where relevant
- list of elements/items

### Element

An element is the animatable thing on a layer.

Examples:

- one video clip
- one text block
- one rectangle
- one image
- one mask
- one camera object

Each element must own:

- stable id
- layer id
- element type
- exact local start
- exact duration
- exact visibility window
- transform state
- style/effect bindings
- source binding if media-backed

### Property Target

Each animatable property must be addressable by canonical identity.

Examples:

- `element.transform.position.x`
- `element.transform.scale`
- `text.opacity`
- `shape.cornerRadius`
- `effect.blur.amount`
- `camera.zoom`

This is the minimum needed for:

- keyframes
- scripts
- templates
- AI-generated motion data

## Property System

The timeline must support property channels rather than only clip timing.

### Core Property Groups

At minimum:

- transform
  - x
  - y
  - scaleX
  - scaleY
  - rotation
  - anchor
- visual
  - opacity
  - blur
  - crop
  - brightness
  - contrast
  - color/tint
  - shadow
- shape
  - width
  - height
  - corner radius
  - stroke
  - fill
- text
  - font size
  - letter spacing
  - line spacing
  - tracking
  - reveal progress
  - text-specific transform/style values
- camera
  - pan
  - zoom
  - rotation
  - shake amount

### Property Channel Rules

Each channel must:

- have a stable property id
- support constant values or animated values
- evaluate against canonical time
- be independent from preview backend implementation

## Keyframe Model

The system must add a first-class keyframe model.

Each keyframe should minimally define:

- `targetId`
- `propertyId`
- `time`
- `value`
- `interpolation`
- optional control/easing parameters

### Interpolation Types

The target engine should support:

- step/hold
- linear
- ease in
- ease out
- ease in out
- cubic bezier
- spring-like motion
- bounce / elastic families

### Why This Matters

Without first-class interpolation:

- text animation is limited
- camera motion is weak
- effects cannot animate professionally
- presets are not reusable at high quality

## Script-Driven Motion Layer

The project should eventually support a structured authoring layer above manual
editing.

Inputs may come from:

- manual keyframes
- structured motion script
- AI-generated animation JSON
- preset/template instantiation

This layer must **not** drive preview directly.

It must compile into normalized runtime data first.

## Authoring Format vs Runtime Format

This separation is mandatory.

### Authoring Format

May include:

- user instructions
- preset choices
- template parameters
- motion scripts
- AI-generated descriptions
- editable keyframes

### Normalized Runtime Format

Must contain:

- resolved scene stack
- resolved layer stack
- resolved element windows
- resolved property channels
- resolved keyframes
- resolved transition windows
- resolved effect instructions
- resolved camera instructions

This runtime format is what preview and export consume.

## Normalization / Compile Layer

This is one of the most important missing architecture pieces.

It should own:

- preset expansion
- template parameter binding
- script parsing
- validation
- conflict resolution
- canonical target resolution
- conversion to resolved runtime structures

This layer protects the engine from:

- raw UI state leakage
- malformed script input
- template ambiguity
- duplicated truth

## Runtime Evaluation Layer

The system needs a deterministic evaluator that resolves state at time `t`.

For any current time/frame, it must resolve:

- active scene
- active layers
- active elements
- property values
- effect values
- transition state
- camera state
- text reveal/procedural state

This evaluator is the heart of professional motion behavior.

It should be deterministic and pure with respect to:

- canonical project state
- canonical time
- normalized runtime data

## Transition Architecture

Transitions must not be treated as playback seams only.

They need their own model.

Each transition should define:

- `transitionId`
- left/right binding
- time window
- preset type
- parameter map

Examples:

- fade
- blur dissolve
- zoom transition
- camera push
- shake transition

Each preset must be parameterizable by values such as:

- duration
- direction
- blur amount
- zoom amount
- shake intensity

## Effect Architecture

Effects must be treated as parameterized units, not hardcoded one-offs.

Each effect binding should define:

- target element/layer
- effect type
- parameter set
- optional animation channels for parameters

Examples:

- blur
- brightness
- contrast
- glow
- shadow
- shake

## Text Animation Architecture

Professional text animation requires more than generic transform channels.

The system should support text-specific evaluators such as:

- word reveal
- letter reveal
- typewriter
- elastic pop
- blur in/out
- scale/rotate settle

This likely requires:

- text layout identity
- glyph/word range addressing
- reveal evaluators
- text preset registry

## Shape / Vector Architecture

The system should support shape elements such as:

- rectangle
- rounded rectangle
- circle
- line
- mask

Shapes need:

- geometry properties
- transform properties
- fill/stroke properties
- animation channels

This should remain part of the same canonical time system, not a side system.

## Camera / Viewport Architecture

The system should add a virtual camera model.

The camera must be representable as:

- a dedicated layer or scene-level target
- with its own animatable channels

Minimum camera channels:

- position/pan
- zoom
- rotation
- shake

Camera must evaluate in the same runtime evaluation pass as everything else.

## Preview Architecture Rule

Preview is a consumer of resolved truth, not the owner of truth.

This means:

- `Media3` can remain preview/transport infrastructure
- preview may use approximations for performance during drag
- preview must never redefine canonical edit/motion truth

If future preview sophistication exceeds the current path, it should still
consume normalized runtime data rather than introducing a second authoring
model.

## Render / Export Architecture Rule

`BMF/BMFLite` should receive resolved runtime instructions, not raw editor UI
state.

That makes `BMF` suitable for:

- compositing
- transforms
- effect execution
- transition execution
- export rendering

But it keeps authoring semantics inside the application where they belong.

## Performance Rules

The architecture should explicitly avoid laggy or fragile designs.

Rules:

- one canonical truth only
- no separate hidden motion timeline
- no preview-owned timing
- no script path that bypasses normalization
- no effect/transitions authored directly against player state
- no backend-specific property ids at authoring level

Performance-oriented requirements:

- normalized runtime data should be cacheable
- evaluation should be deterministic and incremental where possible
- preview projection should minimize full rebuilds
- keyframe lookup should be indexable by target and time
- scene/layer/element identity must remain stable across edits

## Extensibility And Registry Model

The system should eventually add registries for:

- transition presets
- text animation presets
- effect presets
- templates
- motion plugins

Each registry item should expand into normalized runtime instructions rather
than patching editor state ad hoc.

## Recommended Staged Rollout

When we choose to implement this for real, the safest staged order is:

1. canonical scene/layer/element identity
2. property channel model
3. keyframe model
4. interpolation engine
5. normalization / compile layer
6. runtime evaluator
7. transition/effect bindings
8. text-specific animation system
9. camera layer
10. preset/template/plugin registries
11. BMF-backed render/export alignment

## Governance Rule

This document is a reference architecture only.

It does **not** authorize immediate implementation of:

- keyframes
- transitions
- effect engine
- camera engine
- motion scripting
- export redesign

Those must be opened as explicit execution slices later.

Current implementation slice reference:

- [Professional Motion Part 1 - Canonical Scene / Layer / Element / Property Domain Models](/Users/mx/Documents/InGeneBMFPro/docs/process/professional-motion/professional-motion-part-1-canonical-scene-layer-element-property-domain-models.md)
- [Professional Motion Part 2 - Property Channels And First Keyframe Primitives](/Users/mx/Documents/InGeneBMFPro/docs/process/professional-motion/professional-motion-part-2-property-channels-and-first-keyframe-primitives.md)
- [Professional Motion Part 3 - Normalized Motion Composition And Compile Boundary Foundations](/Users/mx/Documents/InGeneBMFPro/docs/process/professional-motion/professional-motion-part-3-normalized-motion-composition-and-compile-boundary-foundations.md)
- [Professional Motion Part 4 - Deterministic Runtime Evaluation Foundations](/Users/mx/Documents/InGeneBMFPro/docs/process/professional-motion/professional-motion-part-4-deterministic-runtime-evaluation-foundations.md)
- [Professional Motion Part 5 - First Compile / Evaluation Helpers Without UI Binding](/Users/mx/Documents/InGeneBMFPro/docs/process/professional-motion/professional-motion-part-5-first-compile-evaluation-helpers-without-ui-binding.md)
- [Professional Motion Part 6 - Transition / Effect / Camera Domain Foundations Without UI Binding](/Users/mx/Documents/InGeneBMFPro/docs/process/professional-motion/professional-motion-part-6-transition-effect-camera-domain-foundations-without-ui-binding.md)
- [Professional Motion Part 7 - Text Animation And Text Preset Domain Foundations Without UI Binding](/Users/mx/Documents/InGeneBMFPro/docs/process/professional-motion/professional-motion-part-7-text-animation-and-text-preset-domain-foundations-without-ui-binding.md)
- [Professional Motion Part 8 - Text Preset Compile / Runtime Binding Without UI](/Users/mx/Documents/InGeneBMFPro/docs/process/professional-motion/professional-motion-part-8-text-preset-compile-runtime-binding-without-ui.md)
- [Professional Motion Part 9 - Text Element Runtime Binding And Preview Hook Foundations Without UI](/Users/mx/Documents/InGeneBMFPro/docs/process/professional-motion/professional-motion-part-9-text-element-runtime-binding-and-preview-hook-foundations-without-ui.md)
- [Professional Motion Part 10 - Text Element Insertion And Binding Foundations Without Bottom-Sheet UI Yet](/Users/mx/Documents/InGeneBMFPro/docs/process/professional-motion/professional-motion-part-10-text-element-insertion-and-binding-foundations-without-bottom-sheet-ui-yet.md)
- [Professional Motion Part 11 - Text Preview Renderer Hook Foundations Without Bottom-Sheet UI Yet](/Users/mx/Documents/InGeneBMFPro/docs/process/professional-motion/professional-motion-part-11-text-preview-renderer-hook-foundations-without-bottom-sheet-ui-yet.md)
- [Professional Motion Part 12 - First User-Facing Text Preset Hookup](/Users/mx/Documents/InGeneBMFPro/docs/process/professional-motion/professional-motion-part-12-first-user-facing-text-preset-hookup.md)
- [Professional Motion Part 13 - Custom Text Preset Import Foundations](/Users/mx/Documents/InGeneBMFPro/docs/process/professional-motion/professional-motion-part-13-custom-text-preset-import-foundations.md)
- [Professional Motion Text Preset JSON Format](/Users/mx/Documents/InGeneBMFPro/docs/process/professional-motion/professional-motion-text-preset-json-format.md)
- [Professional Motion Text Preset Agent Guide](/Users/mx/Documents/InGeneBMFPro/docs/process/professional-motion/professional-motion-text-preset-agent-guide.md)
- [Professional Motion Text Preset Agent Contract](/Users/mx/Documents/InGeneBMFPro/docs/process/professional-motion/professional-motion-text-preset-agent-contract.md)
- [Professional Motion Text Modify V1](/Users/mx/Documents/InGeneBMFPro/docs/process/professional-motion/professional-motion-text-modify-v1.md)

## Final Judgment

The timeline foundation built so far is the correct base for a professional
motion system.

The project does **not** need to throw away its exact-time work.

The project **does** need one disciplined architecture extension above the
current foundation:

- scene
- layer
- element
- property
- keyframe
- normalization
- runtime evaluation

That is the professional path to a global, extensible, script-ready, keyframe-
ready timeline.

## Related References

- [Stage 4 Architecture Lock](/Users/mx/Documents/InGeneBMFPro/docs/process/stage-4-architecture-lock.md)
- [Stage 6 Timeline Precision And Canonical Time Model](/Users/mx/Documents/InGeneBMFPro/docs/process/stage-6-timeline-precision-and-canonical-time-model.md)
- [Stage 6 Timeline Precision Gated Execution Plan](/Users/mx/Documents/InGeneBMFPro/docs/process/stage-6-timeline-precision-gated-execution-plan.md)
- [Stage 6 Foundation Reference - Canonical Timeline Truth For Future Motion, Script, And Export Layers](/Users/mx/Documents/InGeneBMFPro/docs/process/stage-6-foundation-reference-canonical-timeline-truth-for-future-motion-script-export.md)
- [BMF Motion Architecture Feasibility](/Users/mx/Documents/InGeneBMFPro/docs/research/bmf-motion-architecture-feasibility.md)

## Official Evidence

- BMF Overview: [https://babitmf.github.io/docs/bmf/overview/](https://babitmf.github.io/docs/bmf/overview/)
- BMF Built-in Filter Module: [https://babitmf.github.io/docs/bmf/api/api_in_cpp/filter_module/](https://babitmf.github.io/docs/bmf/api/api_in_cpp/filter_module/)
- BMF Create a Module: [https://babitmf.github.io/docs/bmf/getting_started_yourself/create_a_module/](https://babitmf.github.io/docs/bmf/getting_started_yourself/create_a_module/)
- Media3 overview: [https://developer.android.com/media/media3](https://developer.android.com/media/media3)
- Media3 Transformer: [https://developer.android.com/media/media3/transformer](https://developer.android.com/media/media3/transformer)
- Media3 Multi-asset editing: [https://developer.android.com/media/media3/transformer/multi-asset](https://developer.android.com/media/media3/transformer/multi-asset)
