# Remaining Path To Full Export Parity

Status: `ACTIVE`

Type: `corrective technical completion plan`

Canonical follow-up:

- [Professional Export System Plan](/Users/mx/Documents/InGeneBMFPro/docs/process/professional-export-system-plan.md)
- [Professional Effects Render And Export Plan](/Users/mx/Documents/InGeneBMFPro/docs/process/professional-effects-render-and-export-plan.md)
- [Professional Export Audit Gap And Cleanup Plan](/Users/mx/Documents/InGeneBMFPro/docs/process/professional-export-audit-gap-and-cleanup-plan.md)

Purpose:

- unify the remaining export work into one strict plan
- separate `accepted baseline export` from `full export parity`
- prevent the team from mixing device acceptance tasks with renderer/backend expansion tasks

## Audit Verdict

### What is strong now

- first Android export baseline is real, not mocked
- Flutter already builds a canonical `ExportComposition`
- Android already owns export orchestration through `Stage6ExportManager`
- export UI, progress, cancel, validation, and output handoff already exist
- baseline export now includes:
  - single visual track
  - optional single audio track
  - preset sizing
  - scalar `normal speed`
  - first `text-only` motion overlay path

Primary implementation anchors:

- [fusionx_clean_ui_screen.dart](/Users/mx/Documents/InGeneBMFPro/sources/ui/fusionx-clean-ui-2/lib/features/editor/presentation/screens/fusionx_clean_ui_screen.dart)
- [export_composition_models.dart](/Users/mx/Documents/InGeneBMFPro/sources/ui/fusionx-clean-ui-2/lib/features/editor/domain/models/export_composition_models.dart)
- [export_composition_builder.dart](/Users/mx/Documents/InGeneBMFPro/sources/ui/fusionx-clean-ui-2/lib/features/editor/domain/models/export_composition_builder.dart)
- [stage6_export_controller.dart](/Users/mx/Documents/InGeneBMFPro/sources/ui/fusionx-clean-ui-2/lib/core/engine/stage6_export_controller.dart)
- [Stage6ExportManager.kt](/Users/mx/Documents/InGeneBMFPro/sources/ui/fusionx-clean-ui-2/android/app/src/main/kotlin/com/fusionx/fusionx_clean_ui_2/Stage6ExportManager.kt)
- [export_bottom_sheet.dart](/Users/mx/Documents/InGeneBMFPro/sources/ui/fusionx-clean-ui-2/lib/features/editor/presentation/widgets/export_bottom_sheet.dart)

### What is still fragile or baseline-only

- export truth is still effectively `single visual baseline`, not full compositing truth
- motion export is currently a `text-only deterministic overlay lane` with
  historical sampled-overlay fallback material still present in the system, not
  full motion renderer parity
- scalar speed is constant-only; `curve speed` is not exported
- audio export is baseline inclusion, not full audio parity:
  - no mixing graph
  - no gain envelopes
  - no pitch-preservation policy
- effects, transitions, cameras, and non-text motion elements are still blocked
- the builder still assumes sequential clip placement, not a full overlap/gap/compositing model

### What the official stack supports well

Based on official Android Media3 documentation:

- `Transformer` is the correct shortest path for first export baseline
- `Composition` mixes multiple `EditedMediaItemSequence` objects, which is suitable for:
  - visual sequence + audio sequence
  - multi-asset sequential editing
- `OverlayEffect` and `CanvasOverlay` are valid for text/image-like overlays
- progress, cancel, completion, and validation are all normal parts of the intended export flow

But the same official docs also make the main limitation clear:

- default Transformer output supports at most:
  - one video track
  - one audio track
- multi-sequence composition is mixed together, but this is not the same as full editor-grade visual compositing parity
- some operations remain limited or unsupported in composition workflows, especially advanced transitions/crossfades
- aggressive trim/edit-list optimizations are narrow and should not be treated as the main parity path

Official references:

- [Getting started with Transformer](https://developer.android.com/media/media3/transformer/getting-started)
- [Create a basic video editing app using Media3 Transformer](https://developer.android.com/media/implement/editing-app)
- [Multi-asset editing](https://developer.android.com/media/media3/transformer/multi-asset)
- [Transformer API reference](https://developer.android.com/reference/androidx/media3/transformer/Transformer)
- [OverlayEffect API reference](https://developer.android.com/reference/androidx/media3/effect/OverlayEffect)
- [CanvasOverlay API reference](https://developer.android.com/reference/androidx/media3/effect/CanvasOverlay)
- [Transformations guide](https://developer.android.com/media/media3/transformer/transformations)

## Correction To Existing Plans

The project now has two different goals that must not be mixed:

1. `accepted baseline export`
2. `full export parity`

The baseline is already very close.

The parity plan must now start **after** baseline acceptance, not before it.

That means:

- `to-first-export` should be treated as the plan to reach accepted baseline export
- `to-full-export-parity` should be treated as the expansion plan after baseline acceptance
- this document is the corrective bridge between them

## Priority Order

1. `Lock accepted baseline export`
2. `Tighten export truth and diagnostics`
3. `Harden text-motion export parity`
4. `Expand audio/image parity from baseline to supported layer`
5. `Decide and implement effects/transitions strategy`
6. `Open full multi-track compositing path`
7. `Add curve speed export`
8. `Quality/performance/backend hardening`

## Phase 0: Baseline Acceptance Closure

Goal:

- stop treating the first export as “half-done” once the real baseline passes device acceptance

Includes:

- device acceptance for:
  - `video + audio`
  - `image + audio`
  - `trim + order`
  - `Open / Share / Save To Gallery`
  - `cancel / failure`
  - scalar `normal speed`
- confirm:
  - expected duration
  - expected audio presence
  - output resolution
  - output opens correctly

Exit criteria:

- baseline export is accepted on device
- `to-first-export` can be marked `BASELINE ACCEPTED`
- remaining work is no longer described as “before first export”

## Phase 1: Export Truth Tightening

Goal:

- make export data model strong enough for parity work without rewriting the bridge later

Includes:

- explicit export truth for:
  - clip offsets
  - track roles
  - visual/audio participation
  - expected output characteristics
- preflight validation for:
  - output-format determinism
  - track-type correctness
  - expected audio presence
  - expected preset resolution
  - unsupported composition shapes
- post-export validation for:
  - video track count
  - audio track count
  - expected codec family
  - track mime visibility
- UI diagnostics that separate:
  - `baseline blockers`
  - `current parity limitations`
- contract cleanup:
  - remove old baseline wording that still assumes video-only
  - keep blockers explicit and machine-readable
- expand diagnostics so the export sheet reflects:
  - baseline eligibility
  - parity blockers
  - renderer blockers
- resolution validation now also needs to account for:
  - encoder-reported dimensions
  - rotation metadata
  - small encoder alignment variance
- failure diagnostics should surface the reported output size and track structure
  instead of only showing a generic preset-size mismatch
- cleanup of invalid partial outputs must happen after the active Transformer is
  released, not before

Exit criteria:

- every rejected export has an explicit technical reason
- export truth is no longer tied to preview-only assumptions

## Phase 2: Text Motion Parity Hardening

Goal:

- move current `text-only deterministic overlay lane` from narrow first path to
  supported export layer

### Root-Cause Reset

Current diagnosis after device export failures and code audit:

- the current text-motion export path is **not** a shared renderer with preview parity
- Flutter still carries `motionTextRenderTrack` sampled material for
  fallback/debug/diagnostic use
- Android export now prefers deterministic program + raster contracts inside
  `MotionTextCanvasOverlay`
- this means export text motion is still:
  - deterministic in data model
  - but still renderer-approximated
  - layout-reconstructed
  - not yet on the final compositor/effects backend lane
- because of that, cinematic presets that depend on:
  - letter spacing settle
  - blur settle
  - scale settle
  - rotation settle
  - reveal timing
  can still diverge materially from preview even when baseline export succeeds

This is no longer a “more tuning” problem.

It is an **architecture problem**:

- preview uses the Flutter text/layout/render path
- export uses a native overlay path that reconstructs motion from flattened samples
- therefore export parity cannot be closed by preset multipliers or sample-density
  increases alone

April 10 checkpoint:

- a narrow native fix is now in place to stop coupling motion text directly to a
  slowed media item clock:
  - media speed remains on the media base sequence
  - motion text can run on an independent transparent-image overlay sequence
    with explicit image duration and explicit export-frame-rate intent
- the first build of that path failed immediately with Media3
  `Asset loader error`
  because the transparent PNG overlay input was missing
  `MediaItem.Builder.setImageDurationMs(...)`
- that blocker has now been fixed in
  [Stage6ExportManager.kt](/Users/mx/Documents/InGeneBMFPro/sources/ui/fusionx-clean-ui-2/android/app/src/main/kotlin/com/fusionx/fusionx_clean_ui_2/Stage6ExportManager.kt)
- this is still a narrow current-stage repair slice, not yet the final full
  canonical export render graph promised by
  [Professional Export System Plan](/Users/mx/Documents/InGeneBMFPro/docs/process/professional-export-system-plan.md)

### Corrective Decision

Phase 2 must now be split into two tracks:

1. `legacy sampled overlay containment`
2. `deterministic motion-text export program`

The first track exists only to keep current export usable while the real fix is
built.

The second track is the actual parity path.

### Corrective Architecture Plan

#### Phase 2A: Freeze the legacy sampled path

Goal:

- stop treating legacy sampled-overlay material as if it can reach final parity

Includes:

- keep current sampled overlay as an experimental fallback only
- stop adding more preset-specific visual tuning unless it is required for
  baseline stability
- keep the export sheet wording explicit that the sampled path is non-final

Exit criteria:

- the team no longer treats sampled overlay hardening as the final renderer path

#### Phase 2B: Build a deterministic motion-text export program

Goal:

- replace sampled render snapshots with a canonical export-time motion program

Includes:

- export contract must carry canonical text-motion truth, not flattened samples:
  - text content
  - local/project active ranges
  - base style
  - base transform
  - blend mode
  - z-order
  - reveal specs
  - animation blocks
  - property channels
  - interpolation specs
  - keyframes
- remove dependency on `motionTextRenderTrack.samples` as the primary truth
- keep samples only as optional diagnostics or fallback tooling

Exit criteria:

- export no longer depends on nearest/adjacent sampled render snapshots for
  text-motion truth

#### Phase 2C: Evaluate text motion per exported frame

Goal:

- make export-time text motion deterministic at frame time

Includes:

- native export must evaluate text-node state from canonical motion truth at the
  frame time supplied by Transformer
- time mapping must be explicit:
  - output frame time
  - clip local timeline time
  - project time
  - speed/remap participation
- no frame should be produced by “sample interpolation guesswork” if canonical
  motion truth is available

Exit criteria:

- each output frame is derived from evaluated motion truth, not sample blending

#### Phase 2D: Align text layout/render semantics with preview

Goal:

- reduce renderer drift between preview and export

Includes:

- match preview semantics for:
  - transform order
  - opacity
  - blur model
  - letter spacing
  - line height
  - multiline alignment
  - anchor/centering
- if font-family parity or exact typography is not available in native export,
  document it explicitly as a known scope gap

Exit criteria:

- the remaining differences are known typography limitations, not broken motion

#### Phase 2E: Decide the fallback if Media3 overlay parity remains insufficient

Goal:

- avoid spending unlimited time on the wrong renderer path

Includes:

- after deterministic evaluator lands, test whether Media3 `CanvasOverlay`
  still falls short for cinematic text parity
- if it does, open one explicit fallback path:
  - prerendered motion-text visual layer pipeline
  - or advanced backend/compositor path
- do not continue adding heuristic tuning if the backend path itself is the
  blocker

Exit criteria:

- the team has one explicit renderer/backend decision for advanced text motion
  export

Includes:

- device acceptance for text-motion export
- improve parity between preview and export for:
  - timing
  - transforms
  - opacity
  - blur
  - z-order
- tighten render sampling policy:
  - sample density
  - interpolation expectations
  - export-time determinism
- current first hardening slice is now implemented:
  - native text overlay resolves intermediate frames by interpolating between
    adjacent sampled render snapshots instead of snapping to nearest sample only
- corrective architecture work is now underway:
  - Flutter export builds a canonical `motionTextProgram`
  - Android export reads that program and evaluates text transform/style/reveal
    per frame from scalar channels
  - sampled render snapshots remain available only as fallback while the new
    deterministic path is hardened
- export text render sampling now also forces sample points at motion text
  animation ranges and property-channel keyframe times, so export is less likely
  to skip reveal/transform moments between uniform samples
- animated text-motion export now uses a denser sampling budget and can climb
  toward higher sample rates than static text export, reducing visible motion
  stepping in cinematic-style presets before full renderer parity is reached
- critical text-motion sample times now also add short neighbor samples around
  animation/keyframe boundaries, reducing missed transitions immediately before
  or after a boundary
- native overlay now also fades node appearance/disappearance between adjacent
  samples instead of popping text fully on/off when one side has no node
- native text overlay now scales offsets, font size, blur, and letter spacing
  against the export canvas size, so text-motion export stays closer to preview
  parity when output preset resolution differs from the authored motion canvas
- native text overlay now uses a tighter line-height model closer to the
  Flutter preview path, reducing multiline spacing drift in exported text motion
- export text nodes now carry motion-layer `blendMode`, and the native overlay
  applies a first mapped set of blend modes during export instead of silently
  flattening everything to normal compositing
- export text nodes now also carry `fullText`, `revealUnit`, and
  `revealProgress`, allowing native export to rebuild typewriter/letter/word
  reveal frames from motion truth instead of snapping between sampled
  `visibleText` snapshots only
- native text overlay now isolates each node in its own draw layer and uses a
  cleaner blur/shadow pass, reducing the ghosted letter artifacts seen in some
  cinematic-style text-motion exports
- renderer hardening has now started to become preset-aware: exported text
  nodes carry `presetId`, and cinematic text export can apply tuned blur and
  spacing behavior instead of treating every preset as identical generic text
- preset-aware hardening now also covers `review_gen`, with export-side tuning
  for readability-oriented font sizing, spacing, and blur response rather than
  forcing it through the same cinematic-oriented shaping
- renderer hardening now also looks at exported `animationKinds`, not only
  `presetId`, so imported/custom presets that behave like cinematic or
  typewriter-style text can inherit better export shaping even when their ids
  differ from the built-in preset ids
- resolved motion text animations now carry absolute animation blocks through
  the compile layer, so export render nodes can derive per-behavior progress
  from actual block timing instead of guessing from preset names alone
- export text nodes now carry `animationProgressByKind`, and the native text
  renderer uses those progress values to tune cinematic/typewriter blur,
  spacing, and sizing dynamically across the animation instead of applying one
  static preset multiplier for the entire clip
- the current export blur lane is now stronger than the earlier pure
  mask-filter-only path:
  - contract-driven motion-text blur prefers a premultiplied bitmap Gaussian
    first path
  - `BlurMaskFilter(...)` remains only as fallback
- the native text renderer still mirrors preview **only partially**
- preview uses `ImageFilter.blur(...)` on a rendered text layer, while export
  still does not use the same final GL/compositor blur primitive; this semantic
  mismatch remains a confirmed parity blocker, not a closed item
- text export layouts now reserve extra horizontal padding derived from blur
  and spacing intensity before drawing, reducing clipping and compressed
  overlap artifacts in heavy cinematic-style text presets
- export sampling now also densifies inside resolved text animation blocks,
  not only at their boundaries, so long blur/spacing/rotation blocks receive
  higher temporal coverage during export
- document what still remains outside text parity:
  - advanced typography
  - font family parity
  - richer layout rules
  - real Gaussian/layer-blur parity between preview and export

Urgent blur-note for future continuation:

- when export work resumes, an explicit blur-heavy preset test must be run
  early, not at the end
- acceptance condition is not merely that `blurAmount` is numerically present in
  export nodes
- acceptance condition is that preview-visible blur remains visually present in
  exported output and does not collapse into simple white softening or
  opacity-like fading

Exit criteria:

- text-only motion export is accepted as a supported layer
- text-motion no longer feels experimental in export diagnostics

## Phase 3: Audio/Image Supported-Layer Hardening

Goal:

- move `single audio + visual baseline` into a supported layer with clear behavior

Includes:

- device acceptance for:
  - `video + audio`
  - `image + audio`
- audio policy clarification:
  - when audio is expected
  - when mute is intentional
  - what counts as export failure
  - PCM/channel normalization expectations before advanced audio parity
- image policy clarification:
  - duration truth
  - frame-rate fallback
  - output-size correctness
- confirm scalar speed behavior on audio-bearing clips
- surface expected vs actual output frame rate in validation diagnostics so
  image/video export quality checks are not limited to duration and resolution
- if output frame-rate metadata is available, validation now also rejects
  exports whose actual frame rate drifts materially from the expected preset /
  project output rate instead of treating FPS as diagnostic-only information

Exit criteria:

- audio/image export is predictable and documented
- validation catches missing audio or incorrect duration reliably

## Phase 4: Effects And Transition Strategy Gate

Goal:

- avoid pretending that effects/transitions parity is just “one more slice”

Why this needs a gate:

- official Media3 composition/export is strong for sequencing and overlays
- it is not automatically equivalent to full editor-grade compositing parity
- transitions/crossfades/effect windows are where backend constraints become decisive

Includes:

- classify effects/transitions into:
  - `can stay on Media3`
  - `needs approximation`
  - `requires advanced backend`
- define accepted first parity subset
- decide whether to:
  - keep implementing this phase on `Media3`
  - or open a dedicated `BMF render/export backend` track

Exit criteria:

- there is a written backend decision for effects/transitions
- no team time is spent building parity against the wrong backend assumptions

## Phase 5: Multi-Track Compositing Architecture

Goal:

- move from `single visual track` to actual editor-style visual compositing truth

Includes:

- define compositing model for:
  - multiple visual tracks
  - overlay ordering
  - blend/composite semantics
  - track overlap resolution
- expand export truth so it can represent:
  - stacked visuals
  - overlay images
  - non-destructive layer composition
- choose implementation route:
  - Media3-supported subset
  - or backend-assisted compositor path

Exit criteria:

- export truth can represent layered visual composition without pretending it is sequential-only

## Phase 6: Curve Speed Export

Goal:

- add real time-remapping export instead of rejecting `curve speed`

Includes:

- export truth for curve segments / remap points
- duration truth under remapping
- audio policy under remapping
- validation for:
  - expected duration
  - speed-mode correctness
  - export-time stability

Exit criteria:

- curve speed export is no longer blocked by contract design

## Phase 7: Quality, Performance, And Backend Hardening

Goal:

- move from “feature-capable export” to “professional export”

Includes:

- bitrate/codec policy review
- preset ladder quality tuning
- larger-timeline export stress tests
- export-time profiling
- HDR/SDR scope decision
- backend decision checkpoint:
  - stay on Media3 for supported scope
  - or add `BMF` for advanced parity/rendering

Exit criteria:

- export pipeline is measurable, stable, and ready for broader feature load

## Immediate Recommendation

The next correct execution order is:

1. close baseline export acceptance on device
2. tighten export truth/diagnostics
3. harden text-motion export
4. harden audio/image supported layer
5. open the effects/transitions backend gate before attempting parity there

## What Not To Do

- do not mix baseline acceptance tasks with full parity tasks
- do not describe unsupported parity work as if it blocks first accepted export
- do not assume `CanvasOverlay` text path means full motion parity is solved
- do not start `curve speed` or `multi-track compositing` before the backend decision around effects/transitions is explicit
