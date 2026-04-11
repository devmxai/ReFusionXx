# BMF Motion Architecture Feasibility

## Status

- document type: research / architecture feasibility
- execution status: not active
- roadmap placement: post-`Stage 6` research track
- purpose: evaluate whether `BMF/BMFLite` can serve as the runtime execution layer for a professional motion/video editor driven by keyframes, scripts, templates, or AI-generated structured data

Foundation dependency:

- future motion/script/keyframe work must build on:
  [Stage 6 Foundation Reference - Canonical Timeline Truth For Future Motion, Script, And Export Layers](/Users/mx/Documents/InGeneBMFPro/docs/process/stage-6-foundation-reference-canonical-timeline-truth-for-future-motion-script-export.md)
- future motion implementation planning should also follow:
  [Professional Motion](/Users/mx/Documents/InGeneBMFPro/docs/process/professional-motion-architecture.md)

## Core Question

Can `BMF` be used as the runtime engine underneath a professional editor where:

- a user writes or imports a motion script
- or an AI layer emits structured animation JSON
- or a user manually authors keyframes
- and the engine evaluates and renders the motion accurately frame by frame

## Executive Verdict

Yes, `BMF` is a credible fit as the **execution / processing / render backend** for this kind of system.

No, `BMF` is not, by itself, a complete **authoring / keyframe / timeline / scene engine**.

The strongest architecture is:

1. authoring layer
2. normalization / compile layer
3. runtime evaluation layer
4. `BMF/BMFLite` execution layer

This means:

- `BMF` can run the media operations and render/composite work
- our application must still own the editor model, animation model, scene/layer model, timeline semantics, keyframes, text system, templates, and presets

## Official Evidence

Primary references:

- [BMF Overview](https://babitmf.github.io/docs/bmf/overview/)
- [BMF Homepage](https://babitmf.github.io/)
- [BMF GitHub](https://github.com/BabitMF/bmf)
- [Create a Module](https://babitmf.github.io/docs/bmf/getting_started_yourself/create_a_module/)
- [Built-in Filter Module](https://babitmf.github.io/docs/bmf/api/filter_module/)
- [PushData Mode](https://babitmf.github.io/docs/bmf/multiple_features/graph_mode/pushdatamode/)
- [Remotion Homepage](https://www.remotion.dev/)

From the official BMF documentation, `BMF` is:

- a cross-platform multimedia processing framework
- based on modules, graph / DAG / pipeline execution, and scheduling
- intended for decoding, filtering, encoding, transcoding, and processing workflows
- extensible with custom modules
- capable of dynamic graph behavior and non-trivial runtime orchestration

From the official Remotion documentation, `Remotion` is:

- a system for building video compositions programmatically
- much closer to an authoring/runtime model for video as code

This means the two are not in the same architectural layer.

## What BMF Already Supports Today

What `BMF` already gives us:

- graph-based media execution
- modular processing pipelines
- custom modules for new processing logic
- integration with ffmpeg-compatible filtering behavior
- scheduling and graph orchestration primitives
- cross-platform media-processing orientation

What this is good for:

- clip decode / transform / filter / encode paths
- compositing-style pipelines
- transition execution logic
- effect execution logic
- per-frame processing modules
- deterministic render pipelines when given deterministic normalized inputs

## What Must Be Built On Top

These systems are not provided by BMF as a finished editor framework and must be application-owned:

- scene / layer / clip domain model
- timeline semantics
- playhead semantics
- ripple / split / duplicate / trim / delete semantics
- keyframe authoring system
- interpolation engine
- easing / bezier / spring math
- text layout and professional typography animation system
- virtual camera model
- project serialization
- undo / redo
- presets / templates / plugin product layer
- editor UI and interaction model

## Recommended Layering

### 1. Authoring Layer

Inputs may come from:

- manual keyframes
- timeline JSON
- animation script
- templates / presets
- AI-generated structured motion data

This layer owns:

- user intent
- editable project structure
- keyframe editing UX
- reusable building blocks

### 2. Normalization / Compile Layer

This layer converts authoring data into a stable runtime model:

- resolved clips
- resolved layer stack
- resolved animation curves
- resolved transition windows
- resolved camera transforms
- resolved text animation instructions

This is the ideal place for:

- script interpretation
- preset expansion
- template parameter binding
- AI output validation

### 3. Runtime Evaluation Layer

This layer evaluates motion per frame:

- property values at time `t`
- camera transforms at time `t`
- visibility and overlap at time `t`
- transition blend state at time `t`
- text reveal state at time `t`

This is where:

- easing
- bezier interpolation
- springs
- wiggle / noise
- typewriter timing

should live.

### 4. BMF Execution Layer

This layer executes the already-evaluated frame instructions:

- decode media
- composite layers
- apply transforms
- apply blur / crop / opacity / color operations
- process transitions
- render preview
- render final export

## Feature-by-Feature Feasibility

### Scene / Layer / Clip Model

Feasibility: yes

Assessment:

- `BMF` can sit beneath such a model
- but the model itself must be built by us

### Animatable Properties

Feasibility: mostly yes

Likely straightforward on top of `BMF`:

- position
- scale
- rotation
- opacity
- blur
- crop
- color

Possible but requires more application-owned text/render logic:

- font size
- letter spacing
- shadow
- transform origin for text/layout objects

### Keyframe Engine

Feasibility: yes, but application-owned

`BMF` can execute the result of a keyframe engine, but the keyframe engine itself must be built above it:

- time
- value
- easing
- interpolation
- bezier handles
- spring-style motion

### Procedural Motion

Feasibility: yes

Examples:

- bounce
- elastic pop
- shake
- wiggle
- noise
- typewriter reveal
- camera push / pull / zoom

These should be treated as procedural evaluators in the runtime evaluation layer, then compiled to values that `BMF` executes.

### Transition Engine

Feasibility: yes

Plausible transition families:

- fade
- blur transition
- push / zoom transition
- shake transition

But the overlap model, seam rules, and transition authoring semantics remain our responsibility.

### Text Animation

Feasibility: yes, with the largest amount of app-owned work

This is the biggest gap between “media processing framework” and “motion graphics tool”.

Professional text animation requires:

- text layout
- font metrics awareness
- per-character / per-word timing
- reveal logic
- typography-aware transforms

`BMF` can help execute the resulting frames, but is not itself a professional text-motion authoring engine.

### Camera Model

Feasibility: yes

Recommended interpretation:

- the camera is a virtual scene transform layer
- camera motion affects scene composition globally

Examples:

- zoom
- pan
- rotation
- shake
- motion-blur-like stylization

Again, the camera concept should live above `BMF`; `BMF` executes the resulting transforms and effects.

### Runtime Evaluation

Feasibility: yes

This is one of the strongest reasons to consider `BMF`:

- deterministic processing pipelines
- frame-oriented evaluation feeding a media execution backend
- suitability for preview and final render, if the upstream runtime model is deterministic

### Script / Spec Interpretation

Feasibility: yes, and recommended

This is a very strong architectural fit:

- script or JSON in
- normalized runtime data out
- `BMF` executes

This matches the desired workflow well, but the parser / validator / compiler are ours to build.

### Presets / Templates / Plugins

Feasibility: yes

Recommended model:

- presets expand into normalized animation data
- templates expose parameters
- plugins contribute motion evaluators, transitions, or effect logic

`BMF` can be the execution substrate beneath that, but not the product-layer plugin system itself.

## Comparison To Remotion

`Remotion` is closer to:

- authoring model
- composition model
- video-as-code abstraction

`BMF` is closer to:

- media execution layer
- processing and render substrate

Therefore:

- `BMF` is not “like Remotion”
- but it is reasonable to build a `Remotion-like authoring/runtime model` above `BMF`

## Main Strengths Of Choosing BMF

- strong fit as a processing backend
- graph and module model align well with a compiled runtime
- extensibility via custom modules
- plausible path for transitions, effects, and per-frame execution
- suitable long-term position as the media execution layer

## Main Risks And Limitations

### 1. BMF Is Not A Finished Editor Core

Big portions of the editor must still be built by us.

### 2. Text And Motion Graphics Are Not “Free”

Professional title animation, typography motion, and shape animation will require substantial higher-level systems.

### 3. Preview / Scrub Complexity On Mobile

Even with a strong backend, high-end preview and scrub behavior remain difficult in practice, especially on mobile devices and long-GOP media.

### 4. Keyframe System Must Be Fully Owned By The App

There is no ready-made After Effects-style keyframe subsystem in official BMF docs.

### 5. Camera / Scene Model Must Be Invented Carefully

The cleaner the scene graph and normalized animation model, the more viable `BMF` becomes as an execution backend.

## Recommendation

Recommended decision:

- treat `BMF/BMFLite` as a **backend execution engine**
- do **not** treat `BMF` as the complete editor architecture
- plan a future research track for:
  - scene graph
  - keyframe engine
  - motion spec compiler
  - text animation runtime
  - transition authoring model
  - virtual camera model

## Roadmap Placement

This topic belongs in:

- post-`Stage 6` research

Suggested future track name:

- `Advanced Motion Authoring + Runtime Architecture`

This topic should not replace the current execution priorities.

It should remain a documented research direction until:

- `Stage 6` is stable
- preview/scrub correctness is solid
- current baseline architecture is proven reliable enough to extend

## Final Decision Statement

`BMF` can credibly serve as the runtime media execution layer for a professional motion/video editor driven by scripts, keyframes, templates, or structured motion JSON.

But the professional editor model itself must be built above it.

The cleanest long-term architecture is:

- authoring layer
- normalization / compile layer
- runtime evaluation layer
- `BMF` execution layer
