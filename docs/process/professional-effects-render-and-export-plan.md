# Professional Effects Render And Export Plan

Last updated: April 10, 2026

Status: `ACTIVE`

Type: `corrective architecture and execution plan`

Audit follow-up:

- [Professional Export Audit Gap And Cleanup Plan](/Users/mx/Documents/InGeneBMFPro/docs/process/professional-export-audit-gap-and-cleanup-plan.md)
- [Professional Export Subsystem Handoff And Resume Map](/Users/mx/Documents/InGeneBMFPro/docs/process/professional-export-subsystem-handoff-and-resume-map.md)

Execution checkpoint:

- `2026-04-10`: `Phase 1 / Step 1` started and landed in code.
- `Canonical Effects Graph` is now built inside
  `ExportCompositionBuilder -> ExportComposition`.
- The graph now captures:
  - canonical track clip nodes
  - motion scene/layer/element nodes
  - property assignments/channels
  - text animation, effects, transitions, and camera operations
  - deterministic motion-text program nodes/channels/blocks
- This checkpoint is **contract work**, not final renderer parity.
- The next execution step no longer starts with text-contract creation.
- The strict next execution order is now governed by:
  - [Professional Export Audit Gap And Cleanup Plan](/Users/mx/Documents/InGeneBMFPro/docs/process/professional-export-audit-gap-and-cleanup-plan.md)
- The corrected next wave is:
  - documentation truth cleanup
  - parity-diagnostic alignment with the actual runtime path
  - promotion of canonical graph execution adapters
  - then the first real `Media3 GL effects` slice

Execution checkpoint update:

- `2026-04-10`: `Phase 2 / Step 1` landed in code.
- A new shared motion-text raster contract now exists in:
  - `professional_motion_text_raster_models.dart`
- The preview path now consumes this raster contract instead of duplicating
  scalar blur/font/padding math inline.
- This means:
  - text raster policy constants are now centralized
  - preview uses shared resolved raster metrics
  - future export/backend adapters have a stricter contract to target
- This still does **not** mean final export parity is complete.
- Export rendering is still not consuming the same contract end-to-end yet.

Execution checkpoint update:

- `2026-04-10`: `Phase 2 / Step 2` landed in code.
- `motionTextRasterContract` is now bridged through `ExportComposition`.
- Android export now reads this contract in `Stage6ExportManager`.
- `MotionTextCanvasOverlay` now consumes shared raster policy values instead of
  local hardcoded blur/font/padding constants.
- This closes the first cross-runtime bridge for shared text raster semantics.
- The remaining gap is still larger:
  - export is using shared raster policy
  - but it is **not yet** using the same final backend effect/compositor lane as
    preview

Execution checkpoint update:

- `2026-04-10`: `Phase 2 / Step 3` landed in code.
- A `motionTextRasterProgram` adapter is now built from the export text program
  and bridged to Android export.
- `Stage6ExportManager` now consumes:
  - shared raster policy
  - shared renderer-friendly text base nodes
- `MotionTextCanvasOverlay` now prefers shared raster-program node semantics
  during program evaluation instead of relying only on raw export-program base
  fields.
- This is the first real `export-side adapter` layer above the canonical text
  program.

Execution checkpoint update:

- `2026-04-10`: `Phase 2 / Step 4` landed in code.
- `motionTextRasterProgram` now carries:
  - animation blocks
  - scalar channels
  - layer scalar channels
- Shared bridge serialization for export motion text channels/interpolation and
  animation blocks now exists in `export_motion_text_program_models.dart`.
- Android export now parses these adapter payloads and `MotionTextCanvasOverlay`
  prefers the raster adapter path first when resolving text nodes.
- This means the export runtime is no longer borrowing only base style/layout
  semantics from the adapter; it can now evaluate time-varying text motion from
  the shared adapter path itself.
- Remaining gap:
  - text still ends in a `CanvasOverlay` backend lane
  - the next step is to move from adapter-first evaluation to a more
    professional backend effect/compositor lane for blur and stronger effects

Execution checkpoint update:

- `2026-04-10`: `Phase 2 / Step 5` landed in code.
- `MotionTextRasterSnapshot` now carries the full `MotionTextRasterContract`,
  not only raster policy scalars.
- Preview now gates blur behavior from the shared raster contract semantics
  instead of implicitly assuming the blur engine.
- Android export blur execution now respects:
  - `blurEngineId`
  - `blurColorResolutionMode`
- The current shared contract default for authored text is now
  `gaussian_layer_blur + alpha_mask_colorized`.
- This keeps the current text path on the safer single-color alpha-mask route
  while the broader professional layer-blur backend is still under construction.
- This is still **not** the final Media3 GL blur lane, but it is the first
  contract-driven cross-runtime blur execution slice rather than a purely local
  Kotlin implementation detail.
- It must therefore be treated as:
  - stronger than the old local blur-only path
  - but still not an accepted final professional effects backend lane

Execution checkpoint update:

- `2026-04-10`: first narrow `Media3 GL blur` slice landed in code.
- The independent motion-text overlay sequence can now route blur through
  `Media3 GaussianBlur` **after** `OverlayEffect` when all of the following are
  true:
  - motion text is already on the independent overlay sequence
  - raster-program blur is present and deterministic
  - all participating nodes use the same positive blur amount
  - blur is not time-varying through scalar channels
  - blend mode remains `normal`
- In that supported narrow lane, local software blur drawing is bypassed and
  the overlay sequence is blurred by Media3 on the GL path instead.
- If any of those conditions are not met, export remains on the current
  software/local blur fallback path.
- This is the first real `Media3 GL effects` slice, but it is still:
  - motion-text-only
  - uniform-blur-only
  - overlay-sequence-only
  - not yet the general professional effects backend lane
- Runtime/export diagnostics now also expose:
  - `blurExecutionMode`
  - `glBlurSigmaPx`
  so device testing can confirm whether the export actually used the GL blur
  slice or fell back to the local/software blur lane.
- `2026-04-10`: the first GL blur lane was hardened further:
  - the lane now produces explicit decision diagnostics:
    - `glBlurDecisionCode`
    - `glBlurDecisionDetail`
  - export UI can now explain why GL blur was enabled or why it fell back
  - the lane no longer rejects every blur channel blindly; it now accepts
    blur channels that resolve to one constant value across base/fallback/keyframes
  - time-varying or conflicting blur channels still fall back honestly to the
    software/local lane
- `2026-04-10`: `canonicalEffectsGraph` now participates in the native export
  path:
  - Android export reads the graph during preflight and export assembly
  - export diagnostics now expose a `Canonical Effects` section
  - clear unsupported authored categories are now blocked from graph truth
    instead of only from broad motion counters
- `2026-04-10`: the shared motion-text surface itself was upgraded:
  - preview no longer paints motion text glyph-by-glyph
  - Android export no longer builds motion text blur/fill surfaces glyph-by-glyph
  - both paths now use shaped full-text paragraph layout before blur is applied
  - the shared raster contract default `layoutEngineId` now reflects this as
    `shaped_paragraph_layout`
- `2026-04-10`: motion-text export blur default color resolution was corrected
  for single-color text surfaces:
  - the shared raster contract now defaults text blur to
    `alpha_mask_colorized`
  - Android export defaults now match this
  - the software/local blur path now disables subpixel/linear text for the
    offscreen blur source and rebuilds the fallback layout with its fallback
    paint instead of silently drawing the non-blurred layout
- Why this matters:
  - blurred text was previously defaulting to `premultiplied_text_color`
    semantics on a transparent overlay surface
  - for single-color authored text, that path was producing dark fringe /
    pseudo-stroke artifacts
  - the new default favors alpha-mask blur colorization until a broader
    professional GL effect lane exists for this case
- Why this matters:
  - blur quality was being limited by a broken text surface before the blur step
  - rough edges, fragmented glyphs, and pseudo-stroke artifacts were not only a
    blur-kernel problem; they were also a layout/raster-surface problem
  - this checkpoint upgrades the authored text surface itself before continuing
    broader blur/effects backend work
- Important remaining limitation:
  - animated/time-varying blur still needs a wider backend lane than the current
  narrow constant/uniform GL slice
  - so this checkpoint should be treated as foundational quality repair, not
    final professional blur parity

Execution checkpoint update:

- `2026-04-10`: blur effect ordering was corrected in the current text lane.
- The root cause found in both preview and export was not only the blur kernel:
  opacity was being multiplied into the source surface **before** blur.
- The current text lane now follows the stricter ordering:
  - `source content`
  - `blur effect`
  - `composite opacity`
- Flutter preview now applies opacity after `ImageFilter.blur` instead of baking
  it into the text color before blur.
- Android export now renders the source text surface at intrinsic color alpha
  and applies node opacity at layer-composite time via the native canvas layer,
  instead of dimming the blur source before the blur pass.
- The first narrow GL blur slice also now fails back honestly when opacity
  semantics require post-effect compositing that the current slice cannot
  preserve yet.
- Why this matters:
  - dim/gray pseudo-blur is not only a kernel problem
  - professional Gaussian blur for any asset type must preserve effect-stack
    ordering on an isolated authored surface
  - this rule now becomes canonical for future `text/image/shape` blur work,
    not a motion-text-only workaround
- `2026-04-10`: direct device validation after the ordering fix showed that the
  export defect still remains in the fallback backend lane itself:
  - preview now follows the correct effect ordering and still uses Flutter
    layer blur
  - export still falls back in many real presets to node-local bitmap/alpha
    blur inside `CanvasOverlay`
  - this happens when the first narrow GL lane cannot legally own the authored
    effect stack, such as post-effect opacity or time-varying blur cases
  - in that fallback lane, blur is still not a true isolated authored-layer
    blur backend, so pseudo-stroke / dark fringe / broken edge softness can
    remain visible
- Conclusion:
  - the remaining blocker is no longer “tune the text blur more”
  - the remaining blocker is “replace node-local software blur truth with a
    generic isolated authored-surface blur backend for text/image/shape”

Execution checkpoint update:

- `2026-04-10`: the first isolated authored-surface `timeline GL effect stack`
  has now landed for the independent motion-text overlay surface.
- Instead of supporting only one constant sigma on the sequence, export can now
  build a time-segmented GL effect stack on the isolated overlay sequence using:
  - `TimestampWrapper(GaussianBlur(...))`
  - `TimestampWrapper(AlphaScale(...))`
- This means the first GL lane is no longer limited to:
  - constant blur only
  - opacity-free blur only
- The lane now samples a shared authored-surface blur/opacity timeline from the
  deterministic runtime and can route that timeline to ordered GL effects on
  the isolated overlay sequence when:
  - participating nodes remain uniform at the surface level
  - blend mode remains `normal`
  - the authored surface can still be owned by the independent overlay sequence
- Why this matters:
  - this is the first backend component shaped like a generic authored-surface
    effect stack rather than a text-node-local blur path
  - the current producer is still motion text, but the backend pattern is now
    closer to what `text/image/shape` authored blur needs
- Important remaining limitation:
  - this is still not full multi-surface authored blur parity
  - image/shape authored surfaces are not yet feeding this stack
  - compositor-backed isolated surfaces still need to be built for broader
    layer coverage
- `2026-04-10`: execution-truth groundwork for broader authored surfaces landed
  in the export graph/compositor model:
  - `visualCompositorGraph` now emits compositor-owned overlay layers/segments
    for resolved non-text authored visuals such as `image` and `shape`
  - these surfaces are owned by
    `app_authored_visual_surface_renderer` and no longer remain invisible to
    compositor routing
  - current-backend support detection now only treats the narrow motion-text
    authored lane as executable, so non-text authored surfaces are modeled
    truthfully as compositor-required but still unsupported
  - this is the correct prerequisite before routing image/shape surfaces into
    the same isolated authored-surface effects backend
- `2026-04-10`: the next backend seam also landed:
  - a new `authoredVisualSurfaceProgram` now lowers non-text authored visuals
    from `motionComposition` into a shared export-side surface program
  - this program currently carries first-path data for:
    - source binding identity
    - image/shape kind
    - transform
    - opacity / blur
    - shape width / height / corner radius
    - element/layer scalar channels
  - the bridge now reaches Android preflight, where compositor-owned non-text
    authored segments are checked against the presence of surface-program nodes
  - this is not final rendering yet, but it means the next implementation step
    can target one explicit backend input instead of scraping raw motion data
    again inside the export runtime
- `2026-04-10`: runtime diagnostics now also exist for that lane:
  - Android now builds a native authored-surface runtime bundle from
    `authoredVisualSurfaceProgram`
  - export/preflight events now expose an `Authored Surfaces` diagnostics
    payload
  - the current UI shows runtime counts for:
    - image / shape / mask / video authored surface nodes
    - animated nodes
    - blur-capable nodes
    - compositor-owned vs program-backed segment coverage
  - this keeps the new image/shape lane observable while the actual isolated
    effects backend hookup is still being built
- `2026-04-10`: authored non-text visuals now also have a first native
  time-resolved runtime evaluator:
  - Android can now resolve authored `image/shape/mask/videoClip` surface nodes
    at sampled timeline points from `authoredVisualSurfaceProgram`
  - the runtime evaluator resolves:
    - transform position / scale / rotation
    - opacity
    - blur amount
    - shape width / height / corner radius
  - `Authored Surfaces` diagnostics now also expose:
    - runtime sample count
    - active node coverage
    - active animated-node coverage
    - active blur-node coverage
    - normal-blend coverage
    - first-surface-effect-lane eligibility counts
    - max concurrent active nodes
    - max resolved blur amount
  - this is still not final rendering parity for image/shape, but it is the
    first real runtime execution seam above pure graph/program truth and is the
    correct bridge into the next isolated authored-surface backend lane

## Why This Document Exists

This document exists because the current export stack is now real enough to
show the real architectural gap:

- media export is real
- authored motion export is partially real
- effect parity is not real yet

The current blur failures are not an isolated blur bug.

They are the first clear proof that the project still lacks a shared
professional effects render pipeline across:

- preview
- export
- final encoded output

This document defines the strict plan required to make:

- text animation
- image animation
- shape animation
- blur
- color effects
- transitions
- camera motion
- future authored effects

render and export professionally without relying on preset-by-preset tuning or
Canvas approximations.

## Audit Inputs

This plan is based on:

- official Flutter rendering documentation
- official Android graphics documentation
- official Android Media3 effect/export documentation
- official BMF/BMFLite documentation and repository sources
- current project code audit
- real device export evidence

Primary references:

- [Flutter ImageFilter.blur](https://api.flutter.dev/flutter/dart-ui/ImageFilter/ImageFilter.blur.html)
- [Flutter ImageFiltered](https://api.flutter.dev/flutter/widgets/ImageFiltered-class.html)
- [Flutter SceneBuilder.pushImageFilter](https://api.flutter.dev/flutter/dart-ui/SceneBuilder/pushImageFilter.html)
- [Flutter BackdropFilter](https://api.flutter.dev/flutter/widgets/BackdropFilter-class.html)
- [Android RenderEffect](https://developer.android.com/reference/android/graphics/RenderEffect)
- [Android BlurMaskFilter](https://developer.android.com/reference/android/graphics/BlurMaskFilter)
- [Android MaskFilter](https://developer.android.com/reference/android/graphics/MaskFilter)
- [Android Canvas](https://developer.android.com/reference/android/graphics/Canvas)
- [Android Bitmap](https://developer.android.com/reference/android/graphics/Bitmap)
- [Android Hardware Acceleration](https://developer.android.com/topic/performance/hardware-accel)
- [Media3 Transformations](https://developer.android.com/media/media3/transformer/transformations)
- [Media3 Effect](https://developer.android.com/reference/androidx/media3/common/Effect)
- [Media3 GaussianBlur](https://developer.android.com/reference/androidx/media3/effect/GaussianBlur)
- [Media3 CanvasOverlay](https://developer.android.com/reference/androidx/media3/effect/CanvasOverlay)
- [Media3 OverlayEffect](https://developer.android.com/reference/androidx/media3/effect/OverlayEffect)
- [Media3 DefaultVideoFrameProcessor](https://developer.android.com/reference/androidx/media3/effect/DefaultVideoFrameProcessor)
- [Media3 DefaultVideoCompositor](https://developer.android.com/reference/androidx/media3/effect/DefaultVideoCompositor)
- [BMF Create a Graph](https://babitmf.github.io/docs/bmf/getting_started_yourself/create_a_graph/)
- [BMF Getting Started](https://babitmf.github.io/docs/bmf/getting_started_yourself/)
- [BMF Use Module Directly](https://babitmf.github.io/docs/bmf/getting_started_yourself/use_module_directly/)
- [BMF FFmpeg Fully Compatible](https://babitmf.github.io/docs/bmf/multiple_features/ffmpeg_fully_compatible/)
- [BMF GPU Hardware Transcoding](https://babitmf.github.io/docs/bmf/multiple_features/gpu_hardware_acc/gpu_transcoding/)
- [BMF Data Convert Backend](https://babitmf.github.io/docs/bmf/multiple_features/data_backend/)
- [BMF Subgraph Mode](https://babitmf.github.io/docs/bmf/multiple_features/graph_mode/subgraphmode/)

## Executive Verdict

The current system is **architecturally split**.

Today:

- preview uses a Flutter-owned renderer
- export uses an Android-owned renderer
- media transform/export uses `Media3 Transformer`
- authored visuals are reconstructed again inside `CanvasOverlay`

This means the project currently has:

- shared motion data in some places
- but **not** a shared authored render/effect pipeline

Therefore:

- blur breaks first
- typography breaks next
- advanced effects and transitions remain fragile or blocked
- any future strong effect can fail even if blur is fixed locally

## Hard Technical Findings

### 1. Blur Is A Canary, Not The Whole Problem

Real reviewed findings:

- preview blur currently uses a true layer/image blur primitive in Flutter
- export blur currently travels through a separate Android bitmap/software path
- `CanvasOverlay` is valid for overlays, but it is not a professional final
  effects engine by itself
- `BlurMaskFilter` is not a true layer blur primitive
- bitmap/mask-based late overlays can produce:
  - black fringing
  - halo borders
  - edge replication
  - opacity-like softening instead of real blur

Conclusion:

- fixing blur numerically inside the current Canvas path is not enough
- the root issue is the lack of one shared effect graph and one shared render
  contract

### 2. The Current Preview And Export Are Not The Same Renderer

Current reality:

- preview:
  - Flutter `CustomPaint`
  - Flutter `ImageFiltered`
  - Flutter text layout/measurement
- export:
  - Kotlin `CanvasOverlay`
  - Kotlin text layout/measurement
  - bitmap/mask reconstruction
  - optional fallback paths

This is the main reason visual parity is unstable even when scalar values match.

### 3. Media3 Is Still The Correct Backbone, But Not The Whole Solution

`Media3 Transformer` remains the correct Android backbone for:

- decode
- sequencing
- encode
- mux
- output lifecycle
- progress/cancel/completion
- baseline media operations

But `Media3 CanvasOverlay` must not be treated as the final professional
effects engine.

The correct long-term Media3-aligned path for effects is:

- texture/layer oriented effect processing
- `GlEffect`
- `GaussianBlur`
- compositor-driven visual assembly

not:

- late bitmap Canvas approximations as the main truth path

### 4. BMF Is A Strong Advanced Backend Candidate

Official BMF review shows:

- BMF operates on frame/texture/tensor pipelines
- BMF supports graph/module execution
- BMF supports FFmpeg-compatible filter paths
- BMF exposes real blur/image-processing primitives
- BMFLite exposes texture/EGL-oriented execution paths

Important decision:

- BMF is **not** the authoring engine
- BMF is a credible advanced render/export execution backend

This means:

- editor model stays application-owned
- animation semantics stay application-owned
- normalized effect graph stays application-owned
- execution backend may later be:
  - Media3 GL lane for supported scope
  - BMF/BMFLite lane for advanced parity

## Final Architecture Decision

The project must move to this architecture:

`Authoring -> Normalization -> Runtime Evaluation -> Canonical Effects Graph -> Backend Adapter -> Encode`

Where:

- authoring remains app-owned
- normalization remains app-owned
- runtime evaluation remains app-owned
- the canonical effects graph becomes the single truth for authored visuals
- preview and export both consume backend adapters generated from the same graph

## Required New Contracts

### 1. Canonical Authored Visual Graph

The project needs one graph that represents:

- media layers
- text layers
- image layers
- shape layers
- transforms
- opacity
- blur
- color effects
- blend modes
- masks
- transitions
- camera windows
- temporal windows
- z-order

This graph must be explicit, ordered, and backend-agnostic.

### 2. Canonical Effect Registry

Every effect must be defined as a first-class operation, not an ad-hoc
renderer trick.

At minimum:

- transform
- opacity
- blur
- crop
- color matrix
- shadow/glow
- blend
- mask
- transition blend
- camera transform

Each effect descriptor must define:

- semantic meaning
- bounds expansion policy
- premultiplied alpha policy
- effect ordering rules
- backend support level
- fallback policy

### 3. Shared Typography And Raster Contract

The project must stop rebuilding text rendering semantics independently in
Flutter and Kotlin.

It needs one shared contract for:

- font family
- weight/style
- size
- line height
- letter spacing
- baseline
- glyph order
- alignment
- anchor
- fill/stroke/shadow semantics
- text bounds expansion

If this remains duplicated, blur/effects on text will keep drifting.

### 4. Pixel-Level Parity Validation

Current diagnostics compare properties more than final pixels.

That is not enough.

The project must add:

- frame capture at canonical timestamps
- preview reference images
- export reference images
- tolerance-based pixel diff
- effect-specific validation fixtures

Without this, “matched” can still mean “visually wrong”.

## Backend Strategy

### Media3 Lane

Keep `Media3 Transformer` for:

- decode
- sequence assembly
- baseline encode/mux
- supported GL/video effect path

Required restriction:

- `CanvasOverlay` may remain for simple overlays or temporary fallback lanes
- it must not remain the canonical engine for professional authored effects

Target Media3-aligned path:

- authored layer raster/texture source
- `GlEffect` chain
- `GaussianBlur` and future texture effects
- `DefaultVideoCompositor` or app-owned compositor logic above it

### BMF Lane

Open BMF as the advanced backend lane for:

- effect-heavy authored rendering
- advanced filter stacks
- texture/frame graph execution
- future GPU-heavy visual parity
- cases where Media3 overlay/compositor seams are insufficient

Decision rule:

- do not switch blindly
- first build the canonical effects graph
- then implement backend adapters
- then compare:
  - parity
  - performance
  - maintainability
  - device feasibility

## Mandatory Phases

### Phase 0: Truth Reset

Goal:

- stop false claims of professional effect parity

Actions:

- mark current blur/effect export as non-final
- mark `CanvasOverlay` effect path as baseline/experimental only
- add explicit support matrix for:
  - blur
  - text effects
  - image effects
  - shape effects
  - transitions
  - camera
  - multi-visual compositing

Exit criteria:

- docs and diagnostics no longer imply full effect parity

### Phase 1: Canonical Effects Graph

Goal:

- define one backend-neutral graph for authored visuals

Actions:

- add canonical effect node models
- add effect ordering rules
- add bounds/padding expansion rules
- add alpha/compositing rules
- add backend support descriptors

Exit criteria:

- preview and export can both consume the same effect graph input

### Phase 2: Shared Text/Image Raster Contract

Goal:

- stop typography/layout drift before effects are applied

Actions:

- define shared text raster semantics
- define shared image/shape bounds semantics
- define shared stroke/fill/shadow policy
- unify blur input surface semantics:
  - blur applies to the rendered layer
  - not to a reconstructed mask approximation

Exit criteria:

- the same authored layer produces equivalent pre-effect surfaces in preview and
  export

### Phase 3: Media3 GL Effects Slice

Goal:

- build the first professional export path for supported effects without using
  Canvas as primary truth

Actions:

- move blur to GL/texture effect path where supported
- prototype `GaussianBlur`-based export path
- test effect ordering and alpha handling
- verify no black fringe or artificial stroke artifacts

Exit criteria:

- one blur-heavy preset exports with visual parity that is acceptable by pixel
  review

### Phase 4: Authored Visual Compositor

Goal:

- support multiple authored visual layers and effect stacks coherently

Actions:

- add shared compositor assembly rules
- support:
  - text + media
  - image + media
  - shape + media
  - multiple authored layers
- define transition and camera hooks in the same graph

Exit criteria:

- the project no longer depends on a single special text-only overlay slice

### Phase 5: BMF Advanced Backend Pilot

Goal:

- validate whether BMF/BMFLite is required for the advanced parity lane

Actions:

- build one pilot backend adapter from the canonical graph into BMF execution
- test:
  - blur
  - color effect
  - transition window
  - layered authored content
- compare against Media3 GL lane

Exit criteria:

- make explicit backend decision:
  - `Media3 only`
  - `Media3 baseline + BMF advanced`
  - or `BMF primary advanced render lane`

### Phase 6: Validation And Acceptance

Goal:

- only close the effects export file when quality is proven, not assumed

Required acceptance tests:

- blur-heavy text preset
- image effect preset
- shape effect preset
- transition-heavy composition
- camera-motion composition
- slow-motion media + authored effects
- high-FPS export where supported

Hard acceptance conditions:

- no black borders
- no false stroke halos
- no opacity-like blur collapse
- no effect order inversion
- no preview/export semantic drift that remains visible
- no backend fallback silently changing effect meaning

## Immediate Next Execution Order

The next correct order is:

1. document the current blur/effect lane as non-final
2. create the canonical effects graph contract
3. create the shared raster/effect semantics contract
4. prototype one Media3 GL blur path
5. decide whether advanced parity needs BMF backend expansion

## What Must Not Happen Again

The project must not:

- fix each preset separately and call that parity
- keep treating `CanvasOverlay` as the final effects engine
- tune blur coefficients without fixing the effect pipeline
- treat sampled/scalar parity as visual parity
- promise professional export while effect semantics still differ per backend

## Final Decision

The correct professional direction is:

- keep `Media3` as the current export backbone
- stop using `CanvasOverlay` as the final truth for advanced effects
- build a canonical authored effects graph
- move supported effects to a texture/GL export lane
- evaluate BMF/BMFLite as the advanced parity backend when Media3 seams end

This is the first plan that correctly addresses:

- blur
- future effects
- professional animation export
- backend honesty
- long-term maintainability

without relying on local tuning or visual guesswork.
