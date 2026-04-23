# Professional Direct Text Effects And Scriptable Motion

Status: architecture plan only. No runtime code is implemented by this file.

This document defines the single professional path for:

- direct, user-facing text effects such as `Bounce In`, `Word Reveal`,
  `Letter Drop`, `Type On`, and `Blur In`
- scriptable or programmatic motion authored by AI agents or external tools
- unifying both paths over the existing ReFusion property graph, scoped
  timeline, preview, playback, and export systems

This document intentionally combines the `direct text effects` product plan and
the `programmatic motion` system plan into one architecture so the project does
not drift into separate or competing systems.

Related architecture:

- `docs/professional_canvas_timeline.md` owns the canonical property graph and
  canvas/timeline convergence
- `docs/professional_scope_timeline.md` owns scoped timeline UX and projection
- `docs/live_scrub_migration_mandate.md` is the binding protected-system
  directive for live scrub and must be read before implementation
- current deterministic export-lowered text program lives in
  `lib/features/editor/domain/models/export_motion_text_program_models.dart`

## 0. Purpose

The goal is to make ReFusion capable of two authoring styles without creating
two engines:

1. Human-first authoring:
   - choose a named effect
   - tune it through sliders/options
   - refine it in scoped timeline if needed
2. Programmatic authoring:
   - accept a structured motion script from AI or external tools
   - normalize it into ReFusion's canonical motion model
   - render, scrub, preview, and export it through the same engine

Professional behavior means:

- a direct text effect is real authored motion, not a preview-only trick
- a script-authored motion sequence becomes real authored motion, not a special
  side path
- both routes end in the same property channels and the same evaluator
- the scoped timeline remains the refinement surface, not a duplicated engine

## 1. Non-Negotiable Directives

### 1.0 Start Rule For Agents

Before implementing any work described by this document, the implementing agent
must first read:

`docs/live_scrub_migration_mandate.md`

This is mandatory because text effects, scriptable motion, scoped timeline, and
preview work all sit near the same editing surfaces that can accidentally
regress `Live Scrub`.

Protected scrub path examples that must not be modified as an incidental side
effect:

- `NativeTimelineScrubSurface`
- `Stage5TimelineScrubPlatformView`
- `Stage5NativeScrubEngine`
- `Stage5SurfaceScrubDecoder`
- `Stage5ScrubOverlayTextureView`

If implementation appears to require a change in that path:

1. stop at that boundary
2. document the exact dependency and affected files
3. propose the smallest possible change
4. do not proceed without explicit approval

This rule is strict and must be treated as a first-read warning, not a buried
footnote.

### 1.1 One Motion Substrate

The canonical evaluated truth remains the shared motion property graph described
in `professional_canvas_timeline.md`.

The durable runtime truth is still:

- `MotionPropertyChannelModel`
- `MotionKeyframeModel`
- `MotionInterpolationSpec`
- evaluated composition snapshots

Direct effects and scripts are authoring abstractions above that substrate.

They do not replace it.

### 1.2 Do Not Create A Second Timeline Or Preview Engine

Forbidden:

- a second `TimelinePanel` implementation
- a separate effect-only timeline engine
- a preview-only text effect runtime
- a script-only playback runtime
- a special export-only effect compiler unrelated to preview/playback

Scoped timeline must continue to be a projection over the existing timeline.

### 1.3 Do Not Embed Remotion Or A JSX Runtime In The App

Remotion is a reference for `compose with code`, `parameterized scenes`, and
`program-backed motion authoring`.

ReFusion must not:

- execute React/JSX/TSX directly inside the mobile runtime
- embed Chromium or a browser rendering stack to evaluate motion
- depend on a foreign runtime for preview, scrub, or export

Instead:

- external or AI-authored scripts must be normalized into a canonical ReFusion
  motion program first
- imported semantics may be inspired by Remotion-like composition, but the app
  executes only ReFusion-native motion data

### 1.4 Direct Effects Compile Down To Property Channels

Every direct effect must lower into ordinary property channels and keyframes.

It may additionally emit semantic metadata for UI, but it may not remain an
opaque rendering trick.

### 1.5 Scripts Normalize Into A Canonical Program

AI or external scripts must not write directly into random UI state.

They must first become a canonical `ReFusion Motion Program` document, then
compile into:

- direct effect bindings
- property channels
- animation blocks
- effect metadata

### 1.6 Live Scrub Remains Protected

Nothing in this document authorizes unscoped changes to protected native scrub
files or ownership boundaries.

If any implementation phase requires native scrub changes, that work must be
split into a separately approved task.

### 1.7 Ownership Rules Must Be Explicit

Generated channels from direct effects or scripts must not silently overwrite
hand-authored channels.

The system must always know:

- who owns a generated channel
- which range it owns
- what happens when the user wants to hand-edit it

## 2. Current Code Foundations

The current codebase already contains the right foundations.

### 2.1 Scoped Lane Authoring That Is Real Today

The currently shipped scoped authoring path is real for:

- `Opacity`
- `Position`
- `Scale`
- `Rotation`
- text-only `Gaussian Blur`

These flow through real channels, evaluation, preview, and playback.

### 2.2 Existing Text Preset / Animation Block Model

The repo already contains a useful macro-authoring system in:

- `MotionTextPresetDefinition`
- `MotionTextAnimationBlock`
- `MotionTextAnimationBindingModel`
- `BasicMotionTextPresetCompiler`

The existing kinds already include:

- `wordReveal`
- `letterReveal`
- `typewriter`
- `elasticPop`
- `scaleIn`
- `scaleOut`
- `blurIn`
- `blurOut`
- `rotationSettle`
- `cinematicEntrance`
- `cinematicExit`

This proves that the project does not need a fresh effect engine from zero.

### 2.3 Existing Deterministic Program Path

Export already contains a deterministic text-motion program path in:

- `export_motion_text_program_models.dart`

That is important because it shows the project already accepts the idea that
high-level text motion can be lowered into a canonical program contract.

### 2.4 Current Gaps

The main gap is not the engine.

The main gap is that the product surface is still split between:

- generic property-first animate UI
- hidden text preset capability
- scoped raw property lanes

The user needs one clear product path.

## 3. Product Model

ReFusion should expose two authoring surfaces over one engine:

### 3.1 Surface A - Direct Text Effects

For humans on mobile:

`Add Text Layer -> Double Tap Layer -> Scoped Text Animate/FX -> Effect Sheet`

This path is optimized for:

- speed
- visual clarity
- immediate results
- minimal technical jargon

### 3.2 Surface B - Scriptable Motion

For AI agents, imported motion definitions, and advanced users:

`Script -> Canonical ReFusion Motion Program -> Compiler -> Same Timeline/Preview`

This path is optimized for:

- determinism
- portability
- automation
- future AI collaboration

### 3.3 Shared Rule

Both surfaces must land on the same motion substrate.

That means:

- same property IDs
- same interpolation model
- same keyframe identity
- same evaluator
- same normalized composition
- and for V1 text authoring, the same `ExportMotionTextProgram` lowering path

## 4. Canonical Motion Layers

The professional architecture should be layered as follows:

### Layer 1 - Durable Property Graph

Existing:

- `MotionPropertyChannelModel`
- `MotionKeyframeModel`
- `MotionInterpolationSpec`
- `MotionPropertyCatalog`

This remains the authoritative evaluated truth.

### Layer 2 - Direct Text Effect Definitions

New authored catalog layer:

```text
DirectTextEffectDefinition
  id
  label
  category
  description
  targetKind=text
  parameters[]
  blocks[]
  staticProperties[]
  compilerVersion
```

This is the human-facing effect catalog.

V1 implementation rule:

- this layer should be introduced by generalizing the existing
  `MotionTextPresetDefinition` catalog
- it must not begin as a parallel unrelated system
- in early phases, `Direct Text Effects` is a product-facing name over the
  current preset / animation-block / binding stack

### Layer 3 - Applied Effect Bindings

Per element / per layer authored effect instance:

```text
DirectTextEffectBindingModel
  id
  target
  effectId
  activeRange
  parameterValues
  uiState
  ownershipPolicy
```

This is what the UI edits.

### Layer 4 - Canonical Script Program

Structured motion document for AI/external authoring:

```text
ReFusionMotionProgram
  project
  scenes[]
  layers[]
  elements[]
  directEffects[]
  propertyChannels[]
  metadata
  sourceAdapters[]
```

This is the only canonical import target for scripts.

Important distinction:

- `ReFusion Motion Program` in this document means an authoring/import
  normalization IR
- it is upstream of the current deterministic export-lowered text program
- it is not a rename of `ExportMotionTextProgram`
- export lowering may consume the same authored bindings/channels and produce
  the existing deterministic export program as a later stage
- in V1 it should lower into the existing `MotionCompileRequest ->
  MotionNormalizedComposition` boundary, not create a second compile engine

### Layer 5 - Existing Compile Boundary

The current compile boundary remains authoritative:

```text
MotionCompileRequest
-> MotionNormalizedComposition
-> evaluator
-> preview / playback / export
```

`ReFusion Motion Program` must act as an adapter above this boundary until the
project explicitly promotes a new canonical IR. It must not silently duplicate
the compile pipeline.

## 5. The Direct Text Effect Model

### 5.1 Core Concepts We Must Preserve

Every direct text effect is composed from the same professional primitives:

- `unit`
  - `letters`
  - `words`
  - `lines`
- `progression`
  - how the effect moves through the text over time
- `softness`
  - hard step vs soft overlap
- `order`
  - forward / reverse / center-out / edges-in / random
- `property bundle`
  - opacity / position / scale / rotation / blur / tracking
- `amount`
  - strength of the effect
- `easing token`
  - linear / ease / bounce / elastic / steps
- `preset wrapper`
  - named product effect

This keeps the system small but professional.

### 5.2 Selector And Sequence Spec

The direct effect layer must expose a first-class selector/sequence contract,
because professional text motion is not only “which properties animate,” but
also “which units are affected, in what order, and with what falloff.”

Canonical spec:

```text
DirectTextSelectorSpec
  selectorType
  unit
  includeSpaces
  start
  end
  offset
  shape
  spread
  direction
  mode
  amount
  randomizeOrder
  randomSeed
```

Definitions:

- `selectorType`
  - V1: `range`
  - future: `wiggly`, `expression`
- `unit`
  - `letters`
  - `lettersWithoutSpaces`
  - `words`
  - `lines`
  - `custom`
- `shape`
  - `square`
  - `rampUp`
  - `rampDown`
  - `triangle`
  - `round`
  - `smooth`
- `spread`
  - softness/falloff width across neighboring units
- `mode`
  - how a selector interacts with text or other selectors
- `amount`
  - global influence percentage for the selected bundle

This selector/sequence spec is the correct bridge between:

- Adobe text selectors
- Apple Motion Sequence Text controls
- mobile-friendly direct effect controls

### 5.3 Product Families: Preset, Sequence, And Specialized Behaviors

The product must not flatten all text motion into one undifferentiated concept.

It should explicitly recognize three user-facing families:

#### A. Preset Text Effects

Ready-made named effects with low-friction controls.

Examples:

- `Blur In`
- `Cinematic In`
- `Fade Up`

#### B. Sequence Text Effects

Customizable per-unit sequencing effects driven by selector/sequence controls.

Examples:

- `Word Reveal`
- `Letter Drop`
- `Bounce In`
- `Tracking Settle`

#### C. Specialized Behaviors

Certain behaviors deserve a dedicated contract because they are not just a
generic preset with renamed sliders.

V1 specialized behavior:

- `Type On`

`Type On` should be modeled as its own effect contract with explicit reveal
semantics and optional fade behavior, not only as a generic preset wrapper.

### 5.4 Human-Facing Effect Families

The first product categories should be:

- `Featured`
- `In`
- `Reveal`
- `Out`
- `Loop`
- `Distort`

Recommended first effect families:

- V1 shipping set:
  - `Type On`
  - `Word Reveal`
  - `Blur In`
  - `Fade Up`
  - cinematic blur/scale/rotation-settle variants
- Later-phase expansions:
  - `Letter Drop`
  - `Bounce In`
  - `Pop In`
  - `Tracking Settle`
  - `Loop`
  - `Distort`

V1 should be narrowed to the set already closest to the current compiler and
runtime, while the later families remain planned but not implied as near-term
shipping scope.

### 5.5 Default Controls

Every effect should expose 4-6 controls in the first sheet state.

Shared controls:

- `By`
- `Duration`
- `Order`
- `Softness`

Family-specific controls:

- `Bounce In`
  - `Distance`
  - `Scale From`
  - `Bounce`
- `Blur In`
  - `Blur Amount`
  - `Fade`
  - optional `Distance`
- `Word Reveal` / `Letter Reveal`
  - `Stagger`
  - `Fade`
- `Pop In`
  - `Scale From`
  - `Fade`

### 5.6 Advanced Controls

Advanced controls live behind one expander:

- `Ease`
- `Overlap`
- `Hold`
- `Blur Weight`
- `Scale Weight`
- `Opacity Weight`
- `Rotation Weight`
- `Anchor`
- `Randomize`
- `Seed`

### 5.7 Easing And Curve Contract

The effect system must support two levels of timing control:

#### Level 1 - Named Easing Tokens

Required in V1:

- `linear`
- `easeIn`
- `easeOut`
- `easeInOut`
- `bounce`
- `elastic`
- `steps`

#### Level 2 - Curve-Level Semantics

Required in the architecture, even if surfaced later:

- cubic-bezier control points
- overshoot enablement
- curve reuse or preset curve tokens
- random/cyclic style timing where supported

This prevents the system from getting stuck at a toy-level easing model.

### 5.8 Timeline Representation

The direct effect should appear in scoped timeline first as effect-phase rows,
not as raw scalar clutter.

Default effect rows:

- `In`
- `Main`
- `Out`

Expanded rows may reveal generated lanes:

- `Opacity`
- `Position`
- `Scale`
- `Rotation`
- `Blur`
- `Tracking`
- `Reveal`

This preserves a clean mobile UX while keeping raw control accessible.

## 6. The Scriptable Motion Model

### 6.1 Canonical Name

The canonical script/import target should be named:

`ReFusion Motion Program`

This name fits the existing deterministic export program direction already
present in the codebase.

In this plan, however, the name refers to the authoring-side normalization
format, not the already-lowered export-only representation.

### 6.2 Canonical Serialization Contract

The program must be serialization-stable and versioned.

Minimum required fields:

```text
schemaVersion
programId
sourceKind
sourceFormatVersion
compositionId
fps
durationInFrames
width
height
defaultProps
metadata
```

Optional but recommended:

```text
sourceAdapter
sourcePrompt
sourceModel
compatibilityFlags
validationMode
```

No script import path should be accepted without a schema version.

### 6.3 What A Script Is Allowed To Express

A script may author motion at two levels:

1. High-level:
   - add a named direct effect with parameters
2. Low-level:
   - author explicit property channels and keyframes

Both are valid.

This means an AI agent can produce either:

- `apply Bounce In to text layer A`
- or
- explicit `opacity/position/scale` keyframes

### 6.4 Script Input Rule

ReFusion should accept structured motion input, not arbitrary executable code.

Recommended accepted forms:

- canonical JSON
- canonical YAML
- typed in-app data models
- safe adapter output from external code systems

### 6.5 Remotion-Like Bridge Rule

ReFusion may add an importer for a safe Remotion-like subset later, but it must
work as:

```text
external code or JSX-like structure
-> adapter / translator
-> ReFusion Motion Program
-> compiler
-> property channels and bindings
```

Not:

```text
JSX runtime inside app
-> preview engine
```

The adapter contract should explicitly normalize at least:

- `compositionId`
- `fps`
- `durationInFrames`
- `width`
- `height`
- serializable props/schema
- relative offsets equivalent to sequence timing

### 6.6 Canonical Program Shape

The canonical program should be able to describe:

```text
project
  format
  frameRate

scene[]
  range

layer[]
  range
  blendMode
  zIndex

element[]
  kind
  source
  base properties

directEffect[]
  effectId
  activeRange
  parameterValues
  ownership

propertyChannel[]
  propertyId
  keyframes[]
  interpolation
```

### 6.7 Validation And Error Model

The program importer must produce typed validation output.

Minimum issue shape:

```text
ProgramValidationIssue
  code
  severity
  message
  path
  sourceSpan
  recoveryHint
```

Severity levels:

- `error`
- `warning`
- `info`

Validation must cover:

- schema compatibility
- unsupported effect families
- property/value kind mismatches
- selector incompatibilities
- ownership overlaps
- missing reveal semantics
- unsupported export parity cases

### 6.8 Two Valid Output Styles From AI

The AI/program path should explicitly support:

#### Style A - Effect-Level Script

Example shape:

```json
{
  "directEffects": [
    {
      "effectId": "text.bounce_in",
      "targetElementId": "title-1",
      "activeRange": {"startMs": 0, "durationMs": 900},
      "parameterValues": {
        "unit": "letters",
        "distance": 180,
        "scaleFrom": 0.0,
        "bounce": 0.55,
        "softness": 0.35,
        "order": "forward"
      }
    }
  ]
}
```

#### Style B - Channel-Level Script

Example shape:

```json
{
  "propertyChannels": [
    {
      "propertyId": "visual.opacity",
      "targetElementId": "title-1",
      "keyframes": [
        {"timeMs": 0, "value": 0, "interpolation": "easeOut"},
        {"timeMs": 300, "value": 1, "interpolation": "easeOut"}
      ]
    }
  ]
}
```

Both forms are valid.

### 6.9 Reveal Semantics Contract

Channel-only scripts are valid for scalar transform, opacity, blur, and
letter-spacing motion.

However:

- any script that uses `text.revealProgress` must also carry reveal semantics
- that semantics must specify at minimum:
  - `revealUnit`
  - `animationKind` or equivalent reveal behavior intent

This is required because preview/export cannot reconstruct correct word-vs-
letter behavior from `text.revealProgress` alone.

### 6.10 Text Segmentation Fidelity

The program spec must declare how text is segmented for sequencing.

Required metadata:

```text
segmentationPolicy
lineResolutionMode
```

Rules:

- `letters` must distinguish whether spaces are included
- `words` must define tokenization rules
- `lines` are valid only after layout-aware resolution
- `custom` selection must carry explicit ranges or indices

V1 may normalize to the engine's current text segmentation behavior, but that
behavior must be declared and versioned so script authors know what is
deterministic.

### 6.11 Normalization Invariants

Normalization must enforce the following:

- `directEffects[]` and explicit `propertyChannels[]` may coexist only when they
  do not claim the same target/property/range without an explicit override rule
- if a script imports both a direct effect and explicit channels for the same
  target/property/range, normalization must:
  - emit a warning or error, and
  - either force conversion to explicit channels or reject the overlap
- imported scripts must preserve stable ownership metadata so future manual
  editing can detach or convert safely

### 6.12 Compatibility Policy

The script path must be forward-safe and backward-readable.

Required rules:

- newer schema versions may be rejected explicitly, not guessed
- adapters must declare which schema versions they support
- normalization must be deterministic for the same input + schema version
- unsupported features must fail with typed issues, not silent fallbacks

## 7. Compile Pipeline

### 7.1 Human Effect Apply Flow

```text
Text Effects Browser
-> DirectTextEffectBindingModel
-> parameter edit in Effect Sheet
-> effect compiler
-> generated MotionPropertyChannelModel[]
-> evaluator
-> preview / playback / scrub / export
```

### 7.2 Script Apply Flow

```text
AI or external script
-> parser or adapter
-> ReFusion Motion Program
-> normalization and validation
-> direct effects and/or property channels
-> evaluator
-> preview / playback / scrub / export
```

### 7.3 Current Best Reuse Point

The first implementation should generalize the current text preset compiler
rather than replacing it.

That means:

- current `MotionTextPresetDefinition` becomes the V1 basis for
  `DirectTextEffectDefinition`
- current `MotionTextAnimationBindingModel` becomes the V1 basis for
  effect bindings
- current preset compilation logic becomes the V1 effect compiler

## 8. Ownership And Editing Rules

This is mandatory to avoid future corruption.

### 8.1 Ownership

A direct effect owns the channels it generates inside its active range.

Manual channels may coexist only when they do not conflict on the same property
and time span.

### 8.2 Detach And Convert

If the user wants to hand-edit a generated property:

- `Detach Property`
  - convert only that generated property into manual channels
- `Convert Effect To Custom`
  - materialize all generated channels as normal authored channels
  - remove the macro effect binding

This conversion is intentionally one-way in V1.

### 8.3 Never Silent Merge

Forbidden:

- recompiling over manually edited generated keyframes without warning
- merging generated and manual ownership invisibly
- allowing UI parameter edits to overwrite custom edits silently

### 8.4 Resolution Rules

When multiple authored forms touch the same target/property/range, the
precedence must be explicit.

Default resolution order:

1. manual detached or custom channels
2. explicit script-authored `propertyChannels[]`
3. compiled `directEffects[]`

This means:

- a detached or converted manual edit always wins
- explicit imported channels outrank macro effect bindings
- direct effects are the lowest-level authored abstraction once lowered

Every generated or imported channel should carry ownership metadata equivalent
to:

```text
ownerType
ownerId
ownedPropertyId
ownedRange
detached
sourceAdapter
```

Effect-phase rows remain UI projections only.

Their durable serialized truth remains:

- effect bindings
- property channels
- ownership metadata

### 8.5 Round-Trip Guarantees

The system must define what is and is not guaranteed to round-trip.

Guaranteed targets:

- direct effect binding -> generated channels -> preview/playback/export
- direct effect binding -> convert to custom channels
- script import -> normalized composition -> preview/playback/export

Not guaranteed in V1:

- arbitrary manual channel graphs converting back into a named effect
- arbitrary imported external semantics preserving all source-specific concepts
  after normalization

This protects the system from promising impossible reversibility.

## 9. UX Contract

### 9.1 Browser Contract

The browser must be effect-first, not property-first.

Good:

- `Bounce In`
- `Word Reveal`
- `Blur In`
- `Type On`

Bad as the main entry path:

- `Position`
- `Scale`
- `Opacity`

Raw property authoring belongs in advanced refinement, not in the first entry
point.

### 9.2 Effect Sheet Contract

The effect bottom sheet should always show:

- effect name
- editable text content
- phase selector
- preview trigger
- replace effect action
- default sliders

It should not open as a generic form disconnected from the effect concept.

### 9.3 Scoped Timeline Contract

Scoped timeline remains the precision/refinement surface.

It should support:

- dragging effect range
- adjusting phase timing
- entering raw generated rows if expanded
- detaching a property or converting the effect

## 10. Implementation Phases

### Phase 0 - Naming And Documentation Alignment

- add this document
- make it the official unification plan
- reference it from the canvas/timeline and scope plans

### Phase 1 - Expose Existing Text Preset Capability As Product UI

- stop treating the current preset system as hidden
- rename the product concept to `Text Effects`
- keep the bottom-dock `Text` action as layer insertion only
- expose the effect-first browser inside scoped text layer `Animate` / `FX`
- route text-only effects by layer type so image and shape scopes do not show
  text-only controls

### Phase 2 - Formalize `DirectTextEffectDefinition`

- generalize the current preset data model
- preserve current animation blocks
- add richer UI metadata for controls
- keep V1 storage compatible with `MotionTextPresetDefinition`,
  `MotionTextAnimationBlock`, and `MotionTextAnimationBindingModel`

### Phase 3 - Build The Effect Sheet

- effect-first bottom sheet
- default + advanced parameter groups
- live preview updates through the same current evaluator

### Phase 4 - Scoped Effect Phase Rows

- show `In / Main / Out` rows
- allow expand/collapse into generated property rows
- keep using the same `TimelinePanel`

### Phase 5 - Formalize `ReFusion Motion Program`

- canonical structured script format
- parser/validator
- normalization rules
- explicit source adapter metadata

### Phase 6 - Script Import Path

First:

- support canonical JSON/YAML program input

Then:

- add safe adapters for AI-produced motion definitions
- add optional Remotion-like semantic importer later

### Phase 7 - Ownership Tooling

- `Detach Property`
- `Convert Effect To Custom`
- ownership badges
- generated/manual conflict detection

### Phase 8 - Expand Effect Families

- tracking effects
- loop and distort families
- text style families
- effect-node parity once runtime/export ownership is ready

## 11. What Must Not Be Done

Do not:

- build a separate text effect engine
- build a separate script playback engine
- execute JSX/TSX inside the app
- fork `TimelinePanel`
- add preview-only effect logic without channels
- advertise effect families that are not actually wired
- route generated motion through a special export path unrelated to preview
- silently overwrite manual edits during recompilation
- rely on directional blur as a near-term flagship path while the current
  raster path intentionally stays isotropic

## 12. Reference Anchors

Professional references that support this direction:

- Adobe After Effects text animation and range selector model:
  https://helpx.adobe.com/after-effects/using/animating-text.html
- Adobe text animation examples:
  https://helpx.adobe.com/after-effects/using/examples-resources-text-animation.html
- Apple Motion text behaviors and sequence controls:
  https://support.apple.com/guide/motion/apply-a-text-behavior-motn1607d4f1/mac
- Apple Motion Type On behavior:
  https://support.apple.com/en-mide/guide/motion/motn1607df7f/mac
- Apple Motion sequence fine-tuning:
  https://support.apple.com/lt-lt/guide/motion/motn8c008c3d/mac
- Alight Motion easing curves:
  https://support.alightmotion.com/hc/en-us/articles/10536934703889-Animation-Easing-Curves
- Alight Motion Text Progress:
  https://guide.alightmotion.com/effects/text-progress
- Alight Motion Text Transform:
  https://guide.alightmotion.com/effects/text-transform
- Remotion, as a reference for programmatic composition and parameterized video
  authoring:
  https://www.remotion.dev/
- Remotion official repository:
  https://github.com/remotion-dev/remotion

## 13. Final Architecture Decision

The official professional path is:

```text
Direct Text Effects
and
Scriptable Motion
share one ReFusion-native motion substrate.
```

The user-facing system is effect-first.

The AI-facing or import-facing system is script/program-first.

Both compile into the same ReFusion channels, the same evaluator, the same
scoped timeline, and the same export-oriented motion program.
