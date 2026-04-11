# Professional Export Audit Gap And Cleanup Plan

Last updated: April 10, 2026

Status: `ACTIVE`

Type: `implementation audit, gap map, and cleanup execution plan`

Purpose:

- document the exact current export state after direct code audit and agent review
- separate what is **implemented correctly** from what is **modeled only**, **approximate**, or **still blocked**
- define the cleanup and execution order required before the project can claim a
  professional export system for:
  - text effects and animation
  - image effects and animation
  - shape effects and animation
  - transitions
  - camera motion
  - future authored visual effects

Primary references:

- [Professional Export System Plan](/Users/mx/Documents/InGeneBMFPro/docs/process/professional-export-system-plan.md)
- [Professional Effects Render And Export Plan](/Users/mx/Documents/InGeneBMFPro/docs/process/professional-effects-render-and-export-plan.md)
- [Export Current-Stage Closure Plan](/Users/mx/Documents/InGeneBMFPro/docs/process/export-current-stage-closure-plan.md)
- [Remaining Path To Full Export Parity](/Users/mx/Documents/InGeneBMFPro/docs/process/remaining-path-to-full-export-parity.md)
- [Professional Export Subsystem Handoff And Resume Map](/Users/mx/Documents/InGeneBMFPro/docs/process/professional-export-subsystem-handoff-and-resume-map.md)

## Audit Basis

This document is based on:

- direct code audit
- document audit
- agent review of documentation truth
- agent review of runtime/export code
- agent comparison of documented plan vs implemented code

Audit verdict:

- the project now has a **real export system foundation**
- the project does **not** yet have a **professional full-parity export engine**
- the current system is best described as:
  - `real baseline export`
  - `strong canonical planning contracts`
  - `improved deterministic motion-text lane`
  - `partial compositor-aware routing`
  - `not yet a full execution engine for all effects`

## Part A Execution Checkpoint

Current landed progress in `Part A`:

- documentation truth was tightened so the plan set now reflects:
  - the current narrow independent authored overlay-clock repair
  - the current contract-driven motion-text blur first path
  - the fact that neither of those is yet the final professional effects lane
- native export now fails honestly when motion channel edge semantics require
  unsupported `beforeStart` / `afterEnd` behavior instead of silently degrading
  outside the currently supported `clamp` mode
- motion/text parity diagnostics now compare sampled reference data against the
  actual runtime-preferred execution path:
  - `raster_program` first when present
  - otherwise `program`
  - instead of treating older `program-only` comparison as the sole truth
- motion/text parity computation has now been extracted into a focused native
  helper seam instead of remaining fully embedded inside the `CanvasOverlay`
  draw/runtime body
- motion/text runtime inputs are now grouped in a dedicated native runtime
  bundle seam instead of being passed around as scattered raw program /
  contract / track inputs at each overlay/export call site
- the first narrow `Media3 GL blur` slice has landed for the independent
  motion-text overlay sequence:
  - supported only when blur is deterministic, uniform, positive, and uses
    normal blend mode
  - unsupported cases still fall back to the current local/software blur lane
- the export UI diagnostics now expose:
  - `reference path`
  - `runtime path`
  - `missing runtime nodes`
  - `unexpected runtime nodes`
- the first GL blur lane is now more explicit and less brittle:
  - it emits decision diagnostics for enable/fallback reasons
  - it accepts constant blur-channel cases instead of rejecting all blur
    channels categorically
  - it still fails back honestly for time-varying or conflicting blur states
- `canonicalEffectsGraph` is no longer bridge-only in the native path:
  - Android export now reads it during preflight/export assembly
  - export UI now exposes a dedicated `Canonical Effects` diagnostics surface
  - obvious unsupported categories such as authored `image/shape`,
    `motionEffect`, `motionTransition`, `camera`, and authored non-normal
    `blendMode` now fail from canonical graph truth instead of only from broad
    aggregate counters
- the shared motion-text raster surface has now been corrected at the text
  layout layer itself:
  - Flutter preview no longer renders motion text glyph-by-glyph before blur
  - Android export no longer constructs blur/fill text surfaces glyph-by-glyph
  - both now use shaped paragraph/full-text layout semantics
  - the shared contract default now names this honestly as
    `shaped_paragraph_layout`
- motion-text blur defaults were also corrected for current authored text:
  - shared/native defaults now use `alpha_mask_colorized`
    for text blur color resolution
  - this intentionally steps away from `premultiplied_text_color` as the
    default text blur truth because that was producing dark fringe / pseudo-stroke
    artifacts on transparent text-overlay surfaces
  - current constant/uniform GL blur remains a narrow slice, but the default
    authored text blur path is now the safer single-color alpha-mask path
- blur ordering is now being treated as an engine rule instead of a preset
  detail:
  - the current text lane now treats opacity as a post-effect composite step
    instead of multiplying it into the blur source before the blur pass
  - preview now applies opacity after `ImageFilter.blur`
  - Android export now applies node opacity at layer composite time instead of
    dimming the offscreen blur source
  - the first GL blur slice now fails back honestly when this ordering cannot
    be preserved yet
- this matters beyond text:
  - `source -> blur -> composite opacity` is now the canonical rule that must
    also hold for future image/shape/authored-layer blur surfaces
- direct device validation after this fix still showed the exported blur
  landing in a non-final backend truth in real presets:
  - the first GL blur slice is still too narrow for common authored cases
  - export therefore still falls back to node-local bitmap/alpha blur inside
    `CanvasOverlay`
  - this fallback lane can still produce pseudo-stroke / dark fringe / broken
    edge softness
- this confirms the next real task is not more text blur tuning:
  - it is the construction of a generic isolated authored-surface blur backend
    that can later serve text, image, and shape layers
- first execution progress on that task has now landed:
  - the independent authored overlay surface can now carry a timeline GL effect
    stack, not only one constant `GaussianBlur`
  - the current stack can segment and order:
    - `GaussianBlur`
    - `AlphaScale`
  - this moves the current lane closer to a reusable authored-surface backend
    shape
- but the wider gap remains open:
  - the current producer is still motion text only
  - image/shape authored surfaces are not yet feeding the same backend lane
  - true generic authored-surface blur still requires compositor-backed surface
    ownership beyond the current overlay source
- `2026-04-10`: `visualCompositorGraph` now projects non-text authored visuals
  into real compositor-owned overlay layers/segments instead of leaving them as
  aggregate counters only:
  - resolved motion `image/shape/videoClip/mask` elements now emit authored
    overlay segments owned by `app_authored_visual_surface_renderer`
  - current-backend compositor support was tightened so only the narrow
    motion-text authored lane can be treated as executable today
  - this means image/shape authored visuals are now represented truthfully in
    routing and blocking, but they still do not render through a professional
    parity backend yet
- `2026-04-10`: a first `authoredVisualSurfaceProgram` now exists end-to-end:
  - non-text authored visuals from `motionComposition` now lower into a shared
    export-side surface program carrying:
    - source binding identity
    - element kind / shape kind
    - transform
    - opacity / blur
    - shape sizing scalars
    - element/layer scalar channels
  - this program is now bridged through `ExportComposition`
  - Android export now reads it during preflight and verifies that compositor-
    owned non-text authored segments are backed by program nodes
  - this closes the first contract seam for future image/shape routing into the
    same isolated authored-surface effects backend
- `2026-04-10`: `authored surface runtime diagnostics` now exist end-to-end:
  - Android export now builds a native runtime bundle for
    `authoredVisualSurfaceProgram`
  - preflight/export event payloads now expose authored-surface diagnostics
  - the export UI now renders an `Authored Surfaces` diagnostics card showing:
    - node counts by kind
    - animated/blur-capable node counts
    - compositor-owned vs program-backed segment counts
    - missing program-node coverage when present
  - this means non-text authored visuals now have runtime visibility similar in
    spirit to motion-text diagnostics, even before final surface rendering lands
- `2026-04-10`: non-text authored visuals now also have a first native
  time-resolved runtime evaluator:
  - Android now resolves authored `image/shape/mask/videoClip` surface nodes at
    sampled timeline points instead of reporting only static program counts
  - resolved runtime diagnostics now track:
    - active authored node coverage
    - active animated nodes
    - active blur nodes
    - normal-blend node coverage
    - first-surface-effect-lane eligibility counts
    - max concurrent active node count
    - max resolved blur amount
  - the export UI now exposes these runtime fields in the `Authored Surfaces`
    diagnostics card
  - this means authored surfaces are no longer only modeled/program-backed; the
    Android runtime can now evaluate their transform/opacity/blur/shape scalars
    as a real execution seam for the next backend-routing step

Meaning:

- the project now has a more honest `Part A` foundation for the next backend wave
- but `Part A` is still not fully closed until:
  - remaining diagnostics/backend seams are reviewed once more for any hidden
    raw-path leakage
  - text-surface quality is revalidated on device against strong blur presets
  - then the work can move from this foundation into a wider
    `execution adapter + broader Media3 GL effects slice`

## Architecture Verdict Against Official Runtime Models

Compared against the official runtime building blocks from:

- Media3 `Transformer`
- Media3 `GlEffect`
- Media3 `GaussianBlur`
- Media3 `DefaultVideoCompositor`
- Media3 `AudioMixer`
- Flutter `ImageFilter.blur`
- BMF graph/module execution

the current plan direction is judged as:

- `APPROVE WITH CONDITIONS`

Meaning:

- the direction is strong and professionally credible
- it is the strongest current plan in this project
- but it still needs tightening before it can be treated as a full
  After-Effects-like authored animation/export roadmap

### Why The Direction Is Strong

- it keeps `Media3 Transformer` as the real Android backbone for decode /
  transform / encode / mux instead of inventing a fake export path
- it refuses preset-by-preset tuning as a final strategy
- it introduces a canonical graph layer, which is the correct direction for any
  professional authored animation/effects pipeline
- it separates:
  - modeling truth
  - backend execution
  - acceptance / validation
- it explicitly rejects `CanvasOverlay` as the final effects engine
- it leaves room for a backend decision gate:
  - `Media3 GL lane`
  - or `BMF/BMFLite` advanced lane

### Why It Is Not Yet The Final Strongest Possible Plan

- it does not yet promote `canonicalEffectsGraph` to runtime execution truth
- it does not yet complete shared authored surface semantics for:
  - image
  - shape
  - stroke
  - fill
  - shadow
- it does not yet define the professional compositor contract deeply enough for:
  - effect stack ordering
  - blend/compositing parity
  - shared authored layer surfaces
  - compositing/multi-layer execution rules
- it does not yet define acceptance gates strongly enough around:
  - pixel-diff or visual-review baselines
  - backend semantic drift
  - unsupported semantic fail-fast rules
- it does not yet define professional performance budgets for:
  - export latency
  - memory pressure
  - high-FPS fallback policy
  - backend downgrade rules
- it does not yet define the execution adapter layer strongly enough between:
  - `canonicalEffectsGraph`
  - backend lanes such as `Media3 GL`
  - any future `BMF/BMFLite` lane

### After-Effects-Like Scope Clarification

If the target is:

- professional 2D authored animation/effects export for
  `text + image + shape + transitions + camera`

then this plan direction is the correct strongest path right now.

If the target is a broader future scope closer to a full motion-graphics system,
the roadmap should later reserve explicit space for:

- nesting / precomp-like execution
- parenting / hierarchical transforms
- masks / mattes
- deeper time-remap semantics
- broader compositor/effect-stack authoring rules

These are not blockers for the current export parity mission, but they are worth
keeping visible if the long-term goal is true After-Effects-like depth.

## What Is Implemented Correctly

### 1. Real Native Export Backbone

Verified in code:

- `Media3 Transformer` is the real export backbone
- encoded media file generation is real
- trim, order, preset sizing, open/share/save, and constant speed are real
- export lifecycle, progress, cancel, validation, and output handoff are real

Primary anchors:

- [Stage6ExportManager.kt](/Users/mx/Documents/InGeneBMFPro/sources/ui/fusionx-clean-ui-2/android/app/src/main/kotlin/com/fusionx/fusionx_clean_ui_2/Stage6ExportManager.kt)
- [stage6_export_controller.dart](/Users/mx/Documents/InGeneBMFPro/sources/ui/fusionx-clean-ui-2/lib/core/engine/stage6_export_controller.dart)
- [export_bottom_sheet.dart](/Users/mx/Documents/InGeneBMFPro/sources/ui/fusionx-clean-ui-2/lib/features/editor/presentation/widgets/export_bottom_sheet.dart)

### 2. Canonical Export Modeling Exists

Verified in code:

- `ExportCompositionBuilder` builds a real `ExportComposition`
- `ExportComposition` now includes:
  - truth-source modeling
  - capability matrix
  - property capability matrix
  - renderer ownership descriptors
  - visual compositor graph
  - canonical effects graph
  - motion-text export program
  - motion-text raster contract/program

Primary anchors:

- [export_composition_builder.dart](/Users/mx/Documents/InGeneBMFPro/sources/ui/fusionx-clean-ui-2/lib/features/editor/domain/models/export_composition_builder.dart)
- [export_composition_models.dart](/Users/mx/Documents/InGeneBMFPro/sources/ui/fusionx-clean-ui-2/lib/features/editor/domain/models/export_composition_models.dart)

### 3. Canonical Effects Graph Exists

Verified in code:

- `canonicalEffectsGraph` is built and serialized
- it already captures:
  - canonical clips
  - motion scenes/layers/elements
  - static property assignments
  - property channels
  - text animation
  - effects
  - transitions
  - camera operations
  - deterministic text-program nodes/blocks/channels

Important limitation:

- this graph is currently **descriptive / diagnostic / planning truth**
- it is **not yet** the runtime execution truth inside Android export

Primary anchors:

- [export_composition_models.dart](/Users/mx/Documents/InGeneBMFPro/sources/ui/fusionx-clean-ui-2/lib/features/editor/domain/models/export_composition_models.dart)

### 4. Deterministic Motion-Text Lane Is Real

Verified in code:

- `motionTextProgram` exists
- `motionTextRasterContract` exists
- `motionTextRasterProgram` exists
- Android now reads and uses:
  - shared raster policy
  - raster program nodes
  - scalar channels
  - layer channels
  - animation blocks
- export now prefers the raster adapter path before older fallback paths

Primary anchors:

- [export_motion_text_program_models.dart](/Users/mx/Documents/InGeneBMFPro/sources/ui/fusionx-clean-ui-2/lib/features/editor/domain/models/export_motion_text_program_models.dart)
- [professional_motion_text_raster_models.dart](/Users/mx/Documents/InGeneBMFPro/sources/ui/fusionx-clean-ui-2/lib/features/editor/domain/models/professional_motion_text_raster_models.dart)
- [Stage6ExportManager.kt](/Users/mx/Documents/InGeneBMFPro/sources/ui/fusionx-clean-ui-2/android/app/src/main/kotlin/com/fusionx/fusionx_clean_ui_2/Stage6ExportManager.kt)

### 5. Preview/Export Text Raster Contract Is Stronger Than Before

Verified in code:

- preview now consumes shared text raster semantics
- preview no longer owns blur/font/padding math as scattered local numbers
- export now consumes the same raster contract family and blur contract metadata
- default blur contract now prefers:
  - `gaussian_layer_blur`
  - `premultiplied_text_color`

Primary anchors:

- [motion_text_preview_overlay.dart](/Users/mx/Documents/InGeneBMFPro/sources/ui/fusionx-clean-ui-2/lib/features/editor/presentation/widgets/motion_text_preview_overlay.dart)
- [professional_motion_text_raster_models.dart](/Users/mx/Documents/InGeneBMFPro/sources/ui/fusionx-clean-ui-2/lib/features/editor/domain/models/professional_motion_text_raster_models.dart)
- [Stage6ExportManager.kt](/Users/mx/Documents/InGeneBMFPro/sources/ui/fusionx-clean-ui-2/android/app/src/main/kotlin/com/fusionx/fusionx_clean_ui_2/Stage6ExportManager.kt)

### 6. Visual Routing And Overlay Windowing Exist

Verified in code:

- `visualCompositorGraph`
- `visualAssemblyWindows`
- `compositorWindowExecutionPlans`
- media/overlay window routing

This means the system already has the beginning of a compositor-aware export
shape, but not yet a full professional compositor renderer.

## What Is Still Partial, Approximate, Or Blocked

### 1. Canonical Effects Graph Is Not Yet Runtime Truth

Current gap:

- Android export reads:
  - `visualCompositorGraph`
  - `motionTextProgram`
  - `motionTextRasterContract`
  - `motionTextRasterProgram`
- Android export does **not** execute from `canonicalEffectsGraph` directly

Implication:

- effects / transitions / camera / non-text authored visuals are modeled
- but they are not yet executed end-to-end from the canonical graph

### 2. The Current Effects Runtime Is Still Text-Centric

Current gap:

- the shared raster/effect contract work is real for `motion text`
- there is no equivalent completed shared raster contract yet for:
  - images
  - shapes
  - stroke/fill/shadow semantics
  - authored layer bounds expansion across all visual types

Implication:

- `Phase 2` is not closed
- it is only materially advanced for text

### 3. The Final Export Lane Still Depends On CanvasOverlay

Current gap:

- the actual final authored-visual draw path still ends in `OverlayEffect + CanvasOverlay`
- blur in export still goes through a software bitmap path per frame/node
- fallback still exists to `BlurMaskFilter`

Implication:

- this is not yet the final professional backend lane for effects
- `Media3 GL effects slice` has not been implemented yet

### 4. Capability Matrix Still Correctly Marks Major Areas As Open

Current code explicitly marks these as not fully supported:

- `node.text_motion`: `approximation`
- `node.non_text_motion`: `blocked`
- `node.effect`: `blocked`
- `node.transition`: `blocked`
- `node.camera`: `blocked`
- `system.multi_visual_compositing`: `blocked`
- `system.audio_graph`: `blocked`
- `property.curve_speed`: `blocked`
- typography/interpolation/blur/blend/reveal: mostly `approximation`

This honesty is good, but it also means professional parity is not reached.

### 5. Some Semantics Are Declared But Not Fully Enforced

Current gap:

- `beforeStart` / `afterEnd` channel behavior exists in contracts
- current evaluator falls back to `fallbackValue` outside `activeRange`
- these semantics are not yet fully enforced as supported runtime behavior

Implication:

- any advanced authored behavior depending on non-default edge semantics can
  export incorrectly instead of being rejected clearly
- these semantics should be treated as a blocker for professional parity until
  they are either:
  - executed correctly
  - or rejected clearly at preflight/runtime validation time

### 6. Parity Diagnostics Are Not Yet Acceptance-Grade

Current gap:

- much of the current parity logic is:
  - program/property-level
  - sample/program comparison
  - not pixel-diff acceptance
- text parity diagnostics still do not fully measure the final live execution
  path in the strongest possible way

Implication:

- current diagnostics help
- they do not yet prove professional visual parity

## Code Hygiene And Structural Debt

Current verified file sizes:

- [Stage6ExportManager.kt](/Users/mx/Documents/InGeneBMFPro/sources/ui/fusionx-clean-ui-2/android/app/src/main/kotlin/com/fusionx/fusionx_clean_ui_2/Stage6ExportManager.kt): `5959` lines
- [export_composition_models.dart](/Users/mx/Documents/InGeneBMFPro/sources/ui/fusionx-clean-ui-2/lib/features/editor/domain/models/export_composition_models.dart): `4193` lines
- [fusionx_clean_ui_screen.dart](/Users/mx/Documents/InGeneBMFPro/sources/ui/fusionx-clean-ui-2/lib/features/editor/presentation/screens/fusionx_clean_ui_screen.dart): `4545` lines
- [stage6_export_controller.dart](/Users/mx/Documents/InGeneBMFPro/sources/ui/fusionx-clean-ui-2/lib/core/engine/stage6_export_controller.dart): `1024` lines
- [export_bottom_sheet.dart](/Users/mx/Documents/InGeneBMFPro/sources/ui/fusionx-clean-ui-2/lib/features/editor/presentation/widgets/export_bottom_sheet.dart): `1048` lines

Primary cleanliness problems:

- `Stage6ExportManager.kt` currently owns too many responsibilities:
  - bridge parsing
  - preflight
  - runtime validation
  - visual routing
  - sequence assembly
  - text evaluation
  - blur kernels
  - draw logic
  - diagnostics
- deterministic text layout logic exists in both:
  - Dart preview
  - Kotlin export
- `export_composition_models.dart` mixes:
  - domain model
  - graph builder
  - capability policy
  - diagnostics
  - bridge serialization
- documentation still contains some stale wording that no longer matches the
  latest code exactly

## Current Phase Classification

### According To Professional Export System Plan

- `Phase 0`: effectively real
- `Phase 1`: largely real
- `Phase 2`: partial for text only
- `Phase 3`: only partial graph/routing groundwork exists, not the real backend lane
- `Phase 4`: not implemented as a professional audio graph
- `Phase 5`: modeled/blocked, not executed
- `Phase 6`: constant speed only; curve/time-remap not done
- `Phase 7`: backend decision not closed
- `Phase 8`: partial hardening only

### According To Professional Effects Render And Export Plan

- `Phase 1`: implemented
- `Phase 2`: partially implemented for motion text
- `Phase 3`: not implemented as a real `Media3 GL effects` lane
- `Phase 4`: not implemented as a full authored visual compositor
- `Phase 5`: not implemented
- `Phase 6`: not accepted

## Documentation Corrections Required

The following corrections should be made before the next major execution wave:

1. update stale “next step” wording in
   [professional-effects-render-and-export-plan.md](/Users/mx/Documents/InGeneBMFPro/docs/process/professional-effects-render-and-export-plan.md)
   so it no longer says to build work that already landed
2. update stale blur wording in
   [export-current-stage-closure-plan.md](/Users/mx/Documents/InGeneBMFPro/docs/process/export-current-stage-closure-plan.md)
   to distinguish:
   - prior `BlurMaskFilter` diagnosis
   - current premultiplied Gaussian first-path
   - current remaining acceptance gap
3. update stale line counts in
   [export-current-stage-closure-plan.md](/Users/mx/Documents/InGeneBMFPro/docs/process/export-current-stage-closure-plan.md)
4. tighten wording in
   [remaining-path-to-full-export-parity.md](/Users/mx/Documents/InGeneBMFPro/docs/process/remaining-path-to-full-export-parity.md)
   so `sampled overlay` is clearly historical/fallback language, not current
   primary truth language

## Strict Next Execution Order

### Part A: Truth And Cleanup First

1. update documentation so all current checkpoints reflect the real code state
2. align parity diagnostics with the actual final execution path, not older
   program-only comparison paths
3. make unsupported runtime semantics fail honestly instead of degrading silently
4. extract only the minimum seams required before the first real backend wave:
   - isolate backend-lane interfaces from `Stage6ExportManager.kt`
   - isolate canonical graph adapter logic from `export_composition_models.dart`
   - isolate diagnostics from execution code
   - avoid broad refactor churn before the first real `Media3 GL` lane lands

### Part B: Promote Execution Truth And Complete The Shared Effect Surface Contract

5. promote `canonicalEffectsGraph` from descriptive graph to
   execution-driving adapter truth for all supported authored operations
6. finish `Phase 2` properly by extending the shared raster/effect contract to:
   - image
   - shape
   - stroke
   - fill
   - shadow
   - authored bounds expansion
7. ensure preview and export consume equivalent authored pre-effect surfaces,
   not just similar scalar values
8. add explicit shared semantics for:
   - blend/compositing modes
   - effect ordering
   - layer ordering
   - authored bounds expansion before and after effects

### Part C: Build The Real Professional Effects Lane

9. implement the first real `Media3 GL Effects Slice`
   with texture/GL-backed blur and explicit effect ordering
10. route supported blur through that backend lane instead of `CanvasOverlay`
   being the final truth path
11. define explicit performance budgets and fallback policy for:
   - high-FPS export
   - memory-heavy effects
   - latency ceilings
   - supported downgrade behavior
12. ensure preview/export/backend parity includes blend/compositing behavior,
   not only scalar property parity

### Part D: Build The Real Authored Visual Compositor

13. build a true authored visual compositor for:
    - text + media
    - image + media
    - shape + media
    - multi-authored layers
14. move effect / transition / camera from `modeled but blocked` to
    `executed with explicit backend support`

### Part E: Close Remaining System Gaps

15. build a deterministic audio graph beyond baseline single-audio inclusion
16. add curve speed / time-remap export parity
17. evaluate whether `BMF/BMFLite` is required after the `Media3 GL` slice is real
18. add acceptance tests based on device output:
    - blur-heavy preset
    - image effect preset
    - shape effect preset
    - transition-heavy composition
    - camera-motion composition
    - slow-motion + authored effects
    - high-FPS export where supported
19. add pixel-diff or equivalent visual acceptance checks for critical presets

## Definition Of Done For The Professional Export Claim

The project may only claim professional export for all effects and animate
behavior when all of the following are true:

- canonical graph is execution truth for supported authored visuals
- preview/export/backend semantics are aligned for text/image/shape
- blend/compositing semantics and effect ordering are aligned across preview,
  export, and backend execution
- blur is no longer a canvas/software approximation lane
- supported effects do not silently downgrade meaning across backends
- transitions and camera are executed, not merely modeled
- non-text authored visuals export through a supported parity lane
- diagnostics are honest and acceptance-grade
- the system passes real device validation on representative heavy presets
- the system has explicit performance budgets and honest fallback rules for
  heavy effects and high-FPS exports
- the code is split enough to be safely maintainable

## Final Audit Verdict

The project is on the correct professional direction.

What exists now is **not fake** and should not be minimized:

- real export
- real graph contracts
- real deterministic motion-text work
- real progress in shared semantics

But what exists now is still **not the final professional export engine**.

The next milestone must therefore be:

- `cleanup + contract completion + first real GL effects lane`

not:

- more preset-by-preset tuning inside the current `CanvasOverlay` path.
