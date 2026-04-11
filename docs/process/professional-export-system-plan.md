# Professional Export System Plan

Status: `ACTIVE`

Type: `canonical export architecture plan`

Review verdict: `APPROVE WITH CONDITIONS`

Purpose:

- define one strict plan for a real professional export system
- separate what is already real from what is still approximation
- stop preset-by-preset export tuning from being mistaken for a complete renderer
- give the team one monitored execution path to full export parity

Effect-system follow-up:

- [Professional Effects Render And Export Plan](/Users/mx/Documents/InGeneBMFPro/docs/process/professional-effects-render-and-export-plan.md)
- [Professional Export Audit Gap And Cleanup Plan](/Users/mx/Documents/InGeneBMFPro/docs/process/professional-export-audit-gap-and-cleanup-plan.md)

## Review Verdict

This plan is approved as the strongest current direction, with mandatory conditions.

Approved:

- `Media3 Transformer` remains the correct Android export backbone
- a canonical render graph is the right next architectural step
- a dedicated compositor/render layer above the backend is required for full parity
- preset-by-preset visual tuning is not an acceptable final strategy

Approved with conditions:

- no feature may be called supported unless it is represented end-to-end in preview truth, export truth, backend evaluation, and validation
- typography, interpolation, multi-track compositing, and audio graph behavior must be treated as architecture work, not polish
- the project must maintain an explicit support matrix and backend decision gate

Not approved:

- treating `CanvasOverlay` as a complete final export engine
- treating sampled snapshots as long-term truth
- promising literal zero-time export

## Audit Inputs

This plan is based on:

- current project code audit
- current export plans audit
- strict monitor review of prior claims vs actual implementation
- official Android Media3 export/effects documentation

Primary references:

- [Media3 Transformer overview](https://developer.android.com/media/media3/transformer)
- [Create a basic editing app using Media3 Transformer](https://developer.android.com/media/implement/editing-app)
- [Multi-asset editing](https://developer.android.com/media/media3/transformer/multi-asset)
- [Transformer API reference](https://developer.android.com/reference/androidx/media3/transformer/Transformer)
- [OverlayEffect](https://developer.android.com/reference/androidx/media3/effect/OverlayEffect)
- [CanvasOverlay](https://developer.android.com/reference/androidx/media3/effect/CanvasOverlay)
- [TextOverlay](https://developer.android.com/reference/kotlin/androidx/media3/effect/TextOverlay)
- [GlEffect](https://developer.android.com/reference/androidx/media3/effect/GlEffect)
- [GlShaderProgram](https://developer.android.com/reference/androidx/media3/effect/GlShaderProgram)
- [DefaultVideoCompositor](https://developer.android.com/reference/androidx/media3/effect/DefaultVideoCompositor)
- [VideoCompositor](https://developer.android.com/reference/androidx/media3/effect/VideoCompositor)
- [AudioMixer](https://developer.android.com/reference/androidx/media3/transformer/AudioMixer)

## Executive Verdict

The current export stack is **real but partial**.

What is already real:

- decode / transform / encode / mux are real
- trim, order, preset sizing, output file creation, open/share/save, and scalar normal speed are real
- the app already exports through `Media3 Transformer`, not through preview capture or a fake path

What is not yet real parity:

- text motion
- advanced motion
- effects
- transitions
- multi-visual compositing
- full audio graph behavior
- curve speed

The root cause is architectural:

- preview is rendered by the app preview stack
- export is rendered by a different native export stack
- authored visuals are therefore not guaranteed to match preview even when media-native edits do

This is why video and slow motion can be correct while text animation is still wrong.

## What Is Real Today

Current real export path:

`Flutter export truth -> ExportComposition -> Android Stage6ExportManager -> Media3 Transformer -> encoded output file`

Implemented real foundations:

- canonical export composition model
- canonical effects graph generation inside export composition build
- Android export bridge and lifecycle
- preset sizing
- single visual baseline
- optional single audio baseline
- scalar normal speed export
- export validation and file handoff

Primary code anchors:

- [fusionx_clean_ui_screen.dart](/Users/mx/Documents/InGeneBMFPro/sources/ui/fusionx-clean-ui-2/lib/features/editor/presentation/screens/fusionx_clean_ui_screen.dart)
- [export_composition_models.dart](/Users/mx/Documents/InGeneBMFPro/sources/ui/fusionx-clean-ui-2/lib/features/editor/domain/models/export_composition_models.dart)
- [export_motion_text_program_models.dart](/Users/mx/Documents/InGeneBMFPro/sources/ui/fusionx-clean-ui-2/lib/features/editor/domain/models/export_motion_text_program_models.dart)
- [stage6_export_controller.dart](/Users/mx/Documents/InGeneBMFPro/sources/ui/fusionx-clean-ui-2/lib/core/engine/stage6_export_controller.dart)
- [Stage6ExportManager.kt](/Users/mx/Documents/InGeneBMFPro/sources/ui/fusionx-clean-ui-2/android/app/src/main/kotlin/com/fusionx/fusionx_clean_ui_2/Stage6ExportManager.kt)

## What Is Still Approximation

Current export parity gaps:

- authored text motion is still rendered by a native overlay path, not by the preview renderer itself
- typography parity is incomplete
- interpolation parity is incomplete
- multi-track visual compositing is not complete
- effects and transitions are not complete
- cameras and non-text motion are not complete
- audio mixing semantics are not complete
- curve speed export is not complete

Important current truth:

- `motionTextProgram` is now a better source of truth than sampled snapshots
- but `MotionTextCanvasOverlay` is still a separate renderer path
- therefore the system has improved architecture, but it does **not** yet have full export parity

## Official-Docs Stack Decision

### What Media3 Transformer is good at

Media3 Transformer is the correct official Android backbone for:

- decode / encode / mux
- trim
- sequencing
- preset sizing
- H.264/AAC baseline export
- output lifecycle
- progress / cancel / completion
- media-native constant speed operations

### What Media3 Transformer does not solve by itself

Official docs make these limits clear:

- output is still at most one video track plus one audio track
- composition mixing is not the same thing as full editor-grade compositing
- advanced visual parity is not solved automatically by `OverlayEffect`
- `CanvasOverlay` is valid for overlays, but not a guarantee of full motion/type/layout parity
- crossfading and advanced composition cases are limited
- audio/output lane constraints still matter even when composition authoring is richer

Therefore:

- `Transformer` should remain the export backend backbone
- but it must sit under a **real app-owned compositor/render system**
- do not mistake `CanvasOverlay` for a full export engine

## Mandatory Additions From Review

These additions are required for the plan to stay technically honest.

### Capability Matrix

The project must maintain one explicit export capability matrix:

- fully supported
- baseline-only
- experimental
- blocked

This matrix must cover:

- video trim/order
- image clips
- audio layers
- text layout
- text motion
- non-text motion
- effects
- transitions
- camera
- constant speed
- curve speed
- typography features
- interpolation kinds

### Interpolation Contract

The render graph must include a deterministic interpolation registry.

It must define:

- supported interpolation kinds
- exact backend interpretation
- fallback policy
- blocked unsupported kinds

Silent downgrade is forbidden.

### Typography Contract

Text parity must include:

- font family
- font weight/style
- size
- color
- letter spacing
- line height
- alignment
- anchor
- stroke/shadow if authored
- blend semantics

### Audio Graph Requirement

Audio must become a real graph, not audio inclusion only.

Relevant official backbone:

- `AudioMixer` in Media3 should inform the Android-side mix architecture

### Performance Truth

The correct performance target is:

- predictable throughput
- no unnecessary stalls
- explicit quality ladder
- explicit stress-tested limits

The plan must not promise literal zero-time export across all projects and devices.

## Target Architecture

The correct professional architecture is:

1. `Canonical Editor Render Graph`
2. `Preview Runtime`
3. `Export Runtime`
4. `Backend Encode/Mux Layer`

### 1. Canonical Editor Render Graph

One canonical graph must describe everything exportable:

- media clips
- track roles
- visual layers
- audio layers
- overlap/gap rules
- transforms
- text layout and typography
- motion channels
- effect nodes
- transition nodes
- camera nodes
- speed/remap nodes
- output format expectations

This graph is the only truth.

Preview state is not export state.

### 2. Preview Runtime

Preview must consume the canonical graph directly.

It may still use Flutter/native hybrid rendering, but:

- semantics must come from the same graph
- timing and interpolation must come from the same graph
- no preview-only motion behavior is allowed

### 3. Export Runtime

Export must also consume the same canonical graph directly.

It must:

- evaluate frame time deterministically
- resolve clip-local time, project time, and speed/remap time explicitly
- render authored visuals from canonical semantics, not from guessed snapshots
- render audio from a real audio graph policy

### 4. Backend Encode/Mux Layer

Backend execution should be split into lanes:

- `Lane A`: media-native lane for trim/order/constant speed/preset sizing
- `Lane B`: compositor lane for authored visuals/effects/transitions
- `Lane C`: final encode/mux lane

Current recommendation:

- keep `Media3 Transformer` as the first backend backbone
- add a real compositor layer above it
- if Media3 overlay/compositor APIs remain insufficient after deterministic parity work, open an advanced backend lane explicitly

## Non-Negotiable Rules

These are strict red lines:

- do not use sampled snapshots as primary truth again
- do not declare parity for any feature that is not represented end-to-end
- do not degrade unsupported interpolation silently to something else
- do not hide renderer gaps behind preset-specific hacks
- do not mix baseline acceptance with full parity claims
- do not rely on preview capture as export
- do not promise “zero time” export; promise predictable throughput, no silent degradation, and no unnecessary stalls

## Acceptance Criteria For A Professional Export System

The system is only considered professional when all of the following are true:

- one canonical render graph drives both preview and export
- all supported properties are represented end-to-end in the graph and backend
- every supported interpolation kind is evaluated deterministically in export
- multi-track visual layering is composited correctly
- audio layering/mix policy is deterministic
- transitions and effects are rendered from true semantic nodes
- output quality is controlled by a real quality ladder
- validation checks structure, duration, resolution, codec family, and parity invariants
- unsupported features are blocked explicitly, never silently approximated
- parity tests exist for timing and geometry tolerances

## Phase Structure

### Phase 0: Baseline Export Lock

Goal:

- formally accept the real baseline already built

Includes:

- device acceptance for:
  - video
  - image
  - single audio track
  - trim/order
  - scalar normal speed
  - open/share/save
  - cancel/failure

Exit:

- baseline export is accepted as a real media-native foundation

### Phase 1: Canonical Export Render Graph

Goal:

- replace fragmented export truth with one canonical render/export graph

Current checkpoint:

- root graph metadata is now explicit in export truth:
  - `graphSchemaVersion`
  - `backendProfile`
  - `truthSources`
- support is now machine-readable through:
  - `capabilityMatrix`
  - `propertyCapabilityMatrix`
  - `rendererOwnershipMatrix`
  - `interpolationContractRegistry`
- baseline blockers and parity limitations now have explicit codes
- fallback-only sampled text render input is no longer baseline-eligible when
  the canonical `motionTextProgram` is missing
- Android native preflight now enforces the graph contract instead of relying
  only on older implicit assumptions

Includes:

- graph schema for:
  - media clips
  - track roles
  - visual nodes
  - audio nodes
  - motion channels
  - text layout/style nodes
  - effect nodes
  - transition nodes
  - camera nodes
  - speed/remap nodes
- explicit versioning
- machine-readable support flags
- interpolation registry
- typography contract
- machine-readable blocked-feature reasons

Exit:

- preview and export can both target the same graph contract

### Phase 2: Deterministic Motion/Text Renderer

Goal:

- replace transitional text overlay logic with a supported motion/text renderer

Includes:

- deterministic per-frame evaluation from canonical graph
- full text style contract:
  - font family
  - font weight
  - size
  - color
  - line height
  - letter spacing
  - alignment
  - anchor
  - reveal semantics
  - blend semantics
- complete interpolation support
- motion block support
- parity tests against preview

Exit:

- text motion export is no longer an approximation layer

Checkpoint:

- `Phase 2 Part 1` approved by monitor
  - canonical typography/layout contract now flows end-to-end through preview truth, export truth, bridge, and native renderer
  - shared default `color / fontWeight / fontStyle / lineHeight / alignment / anchor` are explicit contract fields instead of hidden hardcodes
  - authored `fontFamily` truth remains honestly blocked until it exists upstream
- `Phase 2 Part 2` approved by monitor
  - `animationBlocks` now flow end-to-end through `motionTextProgram`, bridge, native parsing, and runtime evaluation
  - reveal timing/progress/stagger now comes from blocks as primary runtime truth, with channel reveal only as fallback
  - per-kind animation progress is now derived from blocks at render time instead of being metadata only
- `Phase 2 Part 3` approved by monitor and technical review
  - structured interpolation specs now flow end-to-end through `motionTextProgram`, bridge, native parsing, and runtime evaluation
  - `animationBlocks` and scalar keyframes both contribute to authoritative encountered interpolation scanning
  - unsupported interpolation kinds now fail closed in Dart preflight, native preflight, and native runtime with no silent downgrade path
  - `cubicBezier` evaluation now consumes `x1 / y1 / x2 / y2` as a true bezier solver instead of a y-only approximation
- `Phase 2 Part 4` approved by monitor and technical review
  - preview text motion nodes no longer render through the generic Flutter `Text` widget path
  - preview now uses a deterministic glyph-layout painter with manual glyph measurement, manual letter spacing, shared line height/alignment handling, and a blur/fill pass closer to export semantics
  - preview placement now follows the same `center -> rotate -> scale -> anchorOffset` transform order as export instead of `Align`-based widget placement
- `Phase 2 Part 5` approved by monitor and technical review
  - native export now computes structured motion-text parity probes by comparing `motionTextProgram` evaluation against `renderTrack` sample seams at identical sample times
  - parity diagnostics now survive start, progress, validation-failed, completed, and cancel lifecycle paths without being dropped by later events
  - Flutter export state and the export sheet now surface these probes as diagnostics only, without falsely claiming full renderer parity

### Phase 3: Visual Compositor Layer

Goal:

- support full visual layering beyond the single-visual baseline

Includes:

- z-order compositing
- overlap/gap semantics
- image layers
- text layers
- authored overlay layers
- visual timeline assembly independent of simple sequence concatenation
- official-compositor path evaluation using Media3 effect/compositor seams where sufficient

Exit:

- export is not limited to single visual baseline semantics

Checkpoint:

- `Phase 3 Part 1` approved by monitor and technical review
  - canonical `visualCompositorGraph` now exists as a typed export contract artifact with explicit visual layers and visual segments
  - the graph now flows through `graphMetadata`, `preflightSummary`, diagnostic maps, and bridge payload instead of living as an implicit assumption
  - motion-text overlay ranges are now represented as authored visual layers in the graph, while multi-visual/effects/transitions/camera requirements surface as explicit compositor reasons instead of silent gaps
  - native preflight now validates visual-compositor graph presence and consistency without falsely claiming that a full compositor renderer already exists
- `Phase 3 Part 2` approved by monitor and technical review
  - native visual assembly is now materially graph-driven: media clip timing and ordering come from `visualCompositorGraph` segments instead of raw track selection/timing
  - graph provenance now survives into native clip assembly through `graphLayerId / graphSegmentId / graphZOrder / graphAssemblyOrder`
  - authored motion-text overlay insertion is now gated by overlap with graph-authored overlay segments instead of any global non-null motion-text contract
- `Phase 3 Part 3` approved by monitor and technical review
  - canonical visual assembly windows now partition the export timeline into `gap`, `mediaOnly`, `mediaWithAuthoredOverlay`, and `compositorRequired` windows
  - native rebuilds these windows from graph segments plus duration and validates declared windows field-by-field instead of trusting only counts or coarse flags
  - authored overlay presence is now checked through graph-authored overlay windows rather than looser segment-only assumptions
- `Phase 3 Part 4` approved by monitor and technical review
  - native visual execution is now window-policy-driven: clip routing derives from visual assembly windows, requires continuous coverage, and fails closed on `gap` or `compositorRequired` windows
  - motion-text overlay application is now constrained to exact `mediaWithAuthoredOverlay` windows so overlay rendering cannot leak outside declared graph ownership
  - blocked compositor-required windows now surface as explicit preflight/runtime diagnostics with window id, timeline range, and active layer/segment ids
- `Phase 3 Part 5` approved by monitor and technical review
  - native visual media execution is now split at visual assembly window boundaries so each emitted visual clip inherits one authoritative window policy only
  - `mediaOnly` routes run with no authored overlay attached, while `mediaWithAuthoredOverlay` routes attach overlay rendering only for the exact declared window range
  - visual assembly routing provenance now survives end-to-end through native lifecycle events and export UI, including clip id, graph window/segment/layer ids, z-order, covered windows, and active layer/segment context
- `Phase 3 Part 6 foundation` approved by monitor and technical review
  - every visual assembly window now declares one typed execution owner, separating baseline window routing from compositor-required ownership in canonical export truth
  - compositor-required windows now emit typed `compositorWindowExecutionPlans` with exact timeline range plus ordered layer/segment/media/authored inputs from canonical graph truth
  - native preflight now validates both execution-owner truth and compositor plan truth field-by-field against canonical reconstruction without overclaiming finished compositor runtime execution
- `Phase 3 Part 6A` approved by monitor
  - native runtime now consumes `compositorWindowExecutionPlans` for compositor-owned windows instead of blanket-blocking them
  - the supported slice stays narrow and fail-closed: one base media input plus an image-overlay stack, with authored overlays only after media inputs
  - non-base compositor media clips are skipped so the compositor-owned base clip becomes the authoritative runtime route
  - visual assembly diagnostics now surface per-compositor-window execution owner, result, base clip, overlay clips, ordered graph ids, and authored node ids
- `Phase 3 Part 6B` approved by monitor
  - Dart export truth and native preflight now recognize the same narrow image-overlay-stack compositor slice as current-backend-supported instead of blanket-blocking all compositor-required windows
  - `multipleVisualTracks` and `compositorRequiredVisualWindow` remain blockers only when unsupported compositor windows remain
  - supported and unsupported compositor-window counts are now explicit in export truth and bridge diagnostics
- `Phase 3 Part 6C` approved by monitor
  - native canonical validation and runtime diagnostics now stay aligned with the same supported narrow image-overlay-stack compositor slice instead of reclassifying supported compositor windows as blocked
  - `compositorRequired` routes surface as routed only when their resolved compositor window execution is executable, while unsupported or non-executable windows still fail closed
  - the widened compositor slice is now honest end-to-end across Dart truth, native canonical/preflight/runtime, diagnostics, and docs
- `Phase 3 Part 7` approved by monitor
  - `compositorWindowExecutionPlans` now carry typed ordered `executionInputs` with explicit roles (`baseMedia`, `overlayMedia`, `authoredOverlay`) instead of relying on derived id lists alone
  - native canonical validation now compares typed execution inputs field-by-field against canonical reconstruction, and runtime support predicates consume the typed inputs as primary truth
  - legacy id lists remain secondary consistency metadata only; unsupported execution-input shapes still fail closed without silent fallback

### Current Real-Device Checkpoint

Latest verified real-device export checkpoint on April 10, 2026:

- Confirmed achievements
  - export now produces a real media file with readable `video + audio` metadata on device, so the media/export backend is no longer theoretical or mock-only
  - the current export architecture is materially upgraded and already includes:
    - canonical motion-text truth
    - visual compositor graph
    - typed compositor execution inputs
    - native compositor-window routing and diagnostics

- Confirmed blockers
  - the current hard export blocker is now `duration truth / runtime validation correctness`
  - latest real-device failure pattern showed:
    - a real output file with readable `video+audio`
    - then a late failure such as `Export duration deviates from timeline truth by 4004ms`
  - current root cause is now better understood:
    - authored motion/text can extend beyond the active media base
    - these authored-only tail windows were still being classified as `mediaWithAuthoredOverlay`
    - that let baseline export start even though the current backend cannot render those windows as baseline overlay
    - the result was a real file that ended with media truth, followed by a late duration-validation failure
  - corrective rule already adopted:
    - `mediaWithAuthoredOverlay` is valid only when exactly one media segment is active
    - authored-only windows must be `compositorRequired`
  - agent-backed runtime diagnosis now points to a second, deeper duration-truth gap:
    - Flutter was still rebuilding export clip timing from implicit cursor state instead of carrying explicit clip start truth
    - Android runtime was still validating against timeline-style absolute duration while the actual `EditedMediaItemSequence` execution remains sequential
  - corrective rules now adopted:
    - `ExportClipSeed` must carry explicit `timelineStartTime`
    - `ExportCompositionBuilder` must consume explicit clip starts instead of reconstructing them from `timelineCursor`
    - Android export validation must derive expected duration from the actual execution plan duration, not from a broader absolute timeline shape that the current backend does not materialize

- Confirmed non-blocking limitations
  - text motion, typography, and interpolation parity remain honest non-blocking limitations and should stay documented as limitations rather than blocker codes
  - current motion/text parity diagnostics are not yet acceptance-grade because the parity probe is still structurally contaminated by node-identity mismatch

- Confirmed parity-probe contamination
  - latest device diagnostics showed:
    - `Compared Nodes: 0`
    - `Missing Program Nodes: 130`
    - `Unexpected Program Nodes: 130`
  - this strongly indicates that the current parity probe is matching different node-id namespaces rather than comparing equivalent nodes
  - current known namespaces:
    - preview/render-track nodes use `text-preview:*`
    - canonical program nodes use `text-program:*`
  - therefore current drift/missing/unexpected counts must not be treated as renderer-parity acceptance evidence yet

- Immediate next priorities
  - `Priority 1`: finish stabilizing runtime duration truth / validation correctness on top of the corrected window classification
  - `Priority 2`: verify on device that explicit clip-start truth and execution-plan-derived expected duration remove the late duration failure
  - `Priority 3`: repair motion/text parity probe identity so parity diagnostics become trustworthy
  - only after those repairs should the next feature-building wave continue on top of device-verified truth

- Additional checkpoint on April 10, 2026:
  - export preflight no longer treats the generated timeline text track as a media export track
  - canonical editor text-track clips are now excluded from `ExportTrackSeed` generation
  - motion/text export continues to flow through `motionTextProgram` and `motionTextRenderTrack`
  - this removes the false unresolved-composition blocker:
    - `Clip text-element-* is missing an export asset id.`

- Current practical interpretation
  - export backend status:
    - real and functioning at the media/file level
  - current failure mode:
    - timing/validation correctness
  - current text-motion status:
    - deterministic program path exists
    - but parity probe is not yet trustworthy enough to judge final renderer quality
  - latest renderer-side discovery:
    - Media3 `CanvasOverlay` reuses the same backing bitmap/canvas across frames
    - therefore custom overlays must clear the canvas explicitly on every `onDraw`
    - otherwise authored text leaves stale frame residue and appears as ghosting or accumulated motion trails
    - this explains the device symptom where video motion remains correct while text motion smears after the first second
  - latest FPS/quality checkpoint:
    - export now carries an explicit requested output frame rate instead of always inheriting project fps
    - native export now maps requested fps into `EditedMediaItem.Builder.setFrameRate(...)`
    - native export now uses `DefaultEncoderFactory.Builder.setRequestedVideoEncoderSettings(...)` with a bitrate ladder derived from output size × fps
    - encoder support is now preflight-checked against the current device for the requested H.264 size/rate profile before export starts
- current plan status:
    - continue with strict staged execution
    - keep non-blocking limitations documented honestly
    - do not treat parity diagnostics as final acceptance until identity repair lands
    - current close-out execution for the accepted export lane is now tracked in:
      [Export Current-Stage Closure Plan](/Users/mx/Documents/InGeneBMFPro/docs/process/export-current-stage-closure-plan.md)

### Phase 4: Audio Graph And Mix Engine

Goal:

- move from baseline audio inclusion to true audio export behavior

Includes:

- multiple audio layers
- gain policy
- mute policy
- timing alignment
- audio overlap behavior
- speed/remap audio policy
- future pitch-preservation path
- explicit mixer ownership and format constraints

Exit:

- audio export follows a deterministic graph instead of simple inclusion only

### Phase 5: Effects, Transitions, And Camera Parity

Goal:

- export all authored creative semantics, not just clips and text

Includes:

- effect nodes
- transition nodes
- camera nodes
- transition timing
- effect windows
- compositor integration for advanced motion/effects

Exit:

- creative intent in the timeline survives export

### Phase 6: Full Speed And Time-Remap Parity

Goal:

- complete export support for all speed systems

Includes:

- constant speed hardening
- curve speed export
- time remap segments
- export-time duration correctness
- visual and audio policy under remap

Exit:

- speed systems are no longer baseline-only

### Phase 7: Backend Decision Gate

Goal:

- choose the correct long-term execution backend with evidence, not hope

Decision questions:

- can Media3 + custom compositor + effect stack meet parity and performance needs?
- is `CanvasOverlay`/custom GL sufficient after deterministic renderer work?
- do advanced effects/transitions require a dedicated backend lane?

Possible outcome:

- continue on Media3 backbone
- or open an advanced export backend lane for complex compositing

Decision inputs:

- remaining parity gaps after deterministic renderer/compositor work
- throughput profiling under real project load
- typography/text-motion correctness
- effects/transitions feasibility
- future feature risk when new authored nodes are added

Exit:

- one explicit backend decision for advanced export

### Phase 8: Quality Ladder And Performance Hardening

Goal:

- make the export system production-grade

Includes:

- bitrate ladder
- codec policy
- frame-rate policy
- output validation matrix
- large project stress tests
- deterministic failure handling
- export throughput profiling

Exit:

- export quality and throughput are measured and controlled

## Agent Roles

### Monitor Agent

Responsibilities:

- prevent overclaim
- verify that no phase exits on heuristic tuning alone
- ensure every “supported” feature is represented end-to-end

### Docs Agent

Responsibilities:

- verify conformance with official Media3/export documentation
- flag when the plan depends on undocumented assumptions
- review backend decisions against official constraints

### Technical Audit Agent

Responsibilities:

- compare plan phases against actual code
- flag approximation layers still present in implementation
- verify that old fallback paths do not silently remain primary

### Plan Steward Agent

Responsibilities:

- keep this document canonical
- keep baseline, parity, and backend decisions separated
- update phase status only when exit criteria are truly met

## Immediate Next Step

The next correct execution step is:

- treat this document as the canonical export plan
- keep [to-first-export.md](/Users/mx/Documents/InGeneBMFPro/docs/process/to-first-export.md) as baseline-only history
- keep [remaining-path-to-full-export-parity.md](/Users/mx/Documents/InGeneBMFPro/docs/process/remaining-path-to-full-export-parity.md) as the corrective bridge that led here
- begin implementation from `Phase 1: Canonical Export Render Graph`

## Truth Statement

This plan is intentionally stricter than the previous export plans.

Reason:

- the current project already has a real export baseline
- but professional export for arbitrary motion/effects/timeline content requires
  a compositor architecture, not more local tuning
