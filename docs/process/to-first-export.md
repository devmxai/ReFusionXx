# To First Export

Status: `PLANNING ACTIVE`

Type: `standalone export feature plan`

Scope note:

- this document now tracks the first accepted export baseline only
- the canonical full-system architecture plan is:
  [Professional Export System Plan](/Users/mx/Documents/InGeneBMFPro/docs/process/professional-export-system-plan.md)

Owner model:

- Flutter owns editor truth and export request building
- Android native owns export orchestration and file production
- preview state is not export state
- player state is not export truth

Current checkpoint:

- `Phase 1 - ExportComposition Builder` baseline is implemented
- `Phase 2 - Export Bridge Contract` baseline is implemented
- `Phase 3 - Native ExportManager Baseline` is now implemented as a first
  Android export candidate and is pending real-device acceptance
- `Phase 4 - Export UI And File Handling` baseline is now implemented as a
  first in-app export sheet candidate and is pending real-device acceptance
- `Phase 5 - Validation Matrix` now has its first baseline slice implemented:
  output-file existence/size/duration/dimensions validation from native
- export completion handoff now includes first Android baseline support for:
  - `Open File`
  - `Share File`
  - `Save To Gallery`
- scalar `normal speed` export is now implemented in the baseline expansion
  layer; `curve speed` remains outside baseline
- preset ladder hardening is now implemented as a real output-sizing layer:
  - `720p`
  - `1080p`
  - `Original`
  mapped to real output sizing instead of labels only
- image clips on a single visual track now have a first native export path via
  `EditedMediaItem.setDurationUs(...)`; multi-visual-track compositing is still
  outside the first accepted baseline
- a single audio track can now join that baseline as a separate native export
  sequence, so first export is no longer visual-only
- output validation now checks expected audio presence too, so a file that
  silently loses its baseline audio track no longer passes as a false success
- export preflight diagnostics now separate:
  - baseline blockers
  - current parity limitations
- motion/text export remains outside first export acceptance, but the export
  payload now carries a richer render contract with scenes/layers/channels/
  keyframes instead of summary counts only
- text-only motion export now has a first native `CanvasOverlay` path fed by
  sampled render snapshots from Flutter; device acceptance is still pending
- the app now has export composition models, a pure builder, a screen-side
  composition assembly path, first baseline-eligibility diagnostics, a Flutter
  export controller, a native Android export bridge manager, and a real
  `Media3 Transformer` export start path

## Executive Verdict

The shortest correct path to the first real export is:

`Flutter ExportComposition -> native ExportManager -> Media3 Transformer -> output file`

This is the best first stack for this project now because:

- the app already ships with `androidx.media3:media3-transformer`
- the native app already has timeline segment truth and media preparation seams
- the current codebase does **not** yet have real `BMF` app integration for export orchestration
- `Media3 Transformer` is the fastest path to a real, device-valid, progress-reporting export baseline

Long-term verdict:

- `Media3 Transformer` should be the **first export backend**
- `BMF` should remain the **later advanced export/render backend** for motion/effects/text parity, higher-end processing, and future pro pipelines

This means the project should use a **two-step backend strategy**, not a single forced stack:

1. first export baseline: `Media3 Transformer`
2. later advanced render/export expansion: `BMF`

## What Already Exists

The project is no longer starting from zero.

### Flutter / timeline truth

Already usable:

- canonical media clip truth
- structural edit truth
- trim / split / duplicate / delete truth
- scalar speed truth for normal speed clips
- motion/text normalized composition compile path

Primary current foundations:

- [fusionx_clean_ui_screen.dart](/Users/mx/Documents/InGeneBMFPro/sources/ui/fusionx-clean-ui-2/lib/features/editor/presentation/screens/fusionx_clean_ui_screen.dart)
- [timeline_mock_models.dart](/Users/mx/Documents/InGeneBMFPro/sources/ui/fusionx-clean-ui-2/lib/features/editor/presentation/models/timeline_mock_models.dart)
- [professional_motion_runtime_helpers.dart](/Users/mx/Documents/InGeneBMFPro/sources/ui/fusionx-clean-ui-2/lib/features/editor/domain/models/professional_motion_runtime_helpers.dart)
- [professional_motion_compilation_models.dart](/Users/mx/Documents/InGeneBMFPro/sources/ui/fusionx-clean-ui-2/lib/features/editor/domain/models/professional_motion_compilation_models.dart)

### Android native

Already usable:

- real method channel bridge
- real native transport manager
- real timeline segment parsing
- trim/source-window mapping
- per-clip scalar playback-rate mapping for preview
- `CompositionPlayer` seam already exists
- `Media3 Transformer` dependency already exists

Primary current foundations:

- [MainActivity.kt](/Users/mx/Documents/InGeneBMFPro/sources/ui/fusionx-clean-ui-2/android/app/src/main/kotlin/com/fusionx/fusionx_clean_ui_2/MainActivity.kt)
- [Stage5TransportManager.kt](/Users/mx/Documents/InGeneBMFPro/sources/ui/fusionx-clean-ui-2/android/app/src/main/kotlin/com/fusionx/fusionx_clean_ui_2/Stage5TransportManager.kt)
- [stage5_native_transport_controller.dart](/Users/mx/Documents/InGeneBMFPro/sources/ui/fusionx-clean-ui-2/lib/core/engine/stage5_native_transport_controller.dart)
- [android/app/build.gradle](/Users/mx/Documents/InGeneBMFPro/sources/ui/fusionx-clean-ui-2/android/app/build.gradle)

## What Is Still Missing

These pieces are still missing for the **first accepted export**, even though the
baseline implementation now exists:

- real-device acceptance of the `Phase 3` output path
- preset-specific quality ladder handling
- final real-device acceptance for MediaStore/save-location handoff
- final real-device acceptance for open/share/save actions after export completes
- full validation matrix for trim/order/audio/duration sanity
- final real-device acceptance for scalar speed export
- curve speed export
- text/motion export
- image overlay export
- transition export

Current blocker examples:

- export currently starts from the existing share action and reports through the
  top bar/snackbars, but it does not yet have a dedicated export completion UI
- the preset contract exists, but the native path still exports through one safe
  H.264/AAC baseline path; preset-specific sizing is the next quality-hardening slice
- output is currently written to an app-owned export directory only; gallery
  handoff now exists for Android baseline but still needs device acceptance
- baseline validation still correctly blocks unsupported content such as
  `motion/text`, non-video tracks with clips, and clip-speed overrides

## What “First Export” Means

The first accepted export must be a **complete vertical slice**, not a mock.

That means all of the following must be true:

- the user taps export from the app
- Flutter builds one canonical export request
- native receives it through a stable bridge
- native produces a real playable output file
- the output reflects clip order and trim correctly
- progress is visible
- success/failure is visible
- the output can be opened and verified on device

## Strict Scope For First Export

Included in first export baseline:

- Android only
- imported video clips
- imported image clips on a single visual track
- trim/source-window correctness
- adjacent clip ordering/concat correctness
- embedded clip audio when supported by the source
- H.264 video
- AAC audio
- progress / success / failure
- cancel
- output save path
- output validation

Explicitly excluded from the first accepted export:

- text/motion render export
- image overlay export
- transition export
- template export
- curve speed export
- advanced effects export
- 4K promises
- HEVC promises
- screen-capture-based export
- preview capture as export

Important:

- scalar `normal speed` support is now part of the baseline expansion layer
- `curve speed` is not part of first export acceptance

## Stack Decision

### First export backend

Chosen backend:

- `Media3 Transformer`

Reason:

- already present in the Android app
- official Android export/editing backend
- shortest path to a playable file with trim and multi-item sequencing
- best immediate fit for Android-first export baseline

### Later advanced backend

Deferred backend:

- `BMF`

Reason:

- stronger long-term render/export potential
- better candidate for advanced motion/effects/text/export parity
- but not currently integrated as an app-owned export backend in this project
- therefore too large a jump for the first accepted export slice

## Architecture Decision

### Flutter side

Flutter must build an `ExportComposition` from canonical editor truth.

It must not use:

- preview player state
- current playback position as export truth
- projected display-only text clips as the only motion source

Flutter export truth should come from:

- `_tracks`
- asset metadata
- project format
- canonical clip windows
- scalar speed fields
- compiled `MotionNormalizedComposition` when motion/text export is opened later

### Native side

Android must own:

- export execution
- output file production
- lifecycle reporting
- cancellation
- quality preset interpretation

This must be implemented as a dedicated export layer, not as an extension of the live preview state machine.

Required new native class:

- `Stage6ExportManager` or equivalent dedicated name

It must remain separate from:

- `Stage5TransportManager`

`Stage5TransportManager` may share helper models/utilities, but it must not become the export owner.

## ExportComposition Contract

First export composition must contain:

### Header

- contract version
- project id
- requested output preset
- requested output file name or export session id
- canvas width
- canvas height
- frame rate
- total timeline duration

### Media truth

- ordered video track clips
- clip id
- asset id
- source uri
- source start
- source duration
- timeline start
- timeline duration
- playback rate
- whether clip has audio

### Asset metadata

- source uri
- source mime/type if available
- duration
- width
- height
- rotation if available

### Future-gated sections

- motion composition
- text render instructions
- transition instructions
- image overlays
- effect stacks

These future sections must be optional and versioned, not improvised later.

## Export Bridge Contract

Flutter -> native methods to add:

- `exportTimeline`
- `cancelExport`
- `openExportedFile` or later app-owned equivalent

Native -> Flutter events to add:

- `queued`
- `started`
- `progress`
- `completed`
- `failed`
- `cancelled`

Progress event minimum payload:

- export job id
- progress ratio
- current phase
- output path if available
- error message if failed

## Quality Strategy

The first export must support a safe preset ladder, not “everything at once”.

### First accepted preset ladder

- `Draft 720p`
- `Full HD 1080p`
- `Original Size` when device/backend support is sane

### First accepted codec ladder

- video: `H.264`
- audio: `AAC`

### Deferred quality expansion

Open only after baseline export is accepted:

- 1440p
- 4K
- HEVC
- bitrate tuning
- device capability adaptation
- high-end performance benchmarking

## Strict Phase Plan

### Phase 0 - Scope Freeze

Freeze the first export scope and exclusions.

Deliverables:

- accepted scope matrix
- accepted stack decision
- no hidden feature creep

### Phase 1 - ExportComposition Builder

Build one canonical Flutter-side export payload.

Deliverables:

- `ExportComposition` model
- builder from editor truth
- validation helpers

Acceptance:

- can serialize one clip and two adjacent clips correctly
- no preview-only state leaks into payload

Current implementation status:

- completed baseline

Current implementation artifacts:

- [export_composition_models.dart](/Users/mx/Documents/InGeneBMFPro/sources/ui/fusionx-clean-ui-2/lib/features/editor/domain/models/export_composition_models.dart)
- [export_composition_builder.dart](/Users/mx/Documents/InGeneBMFPro/sources/ui/fusionx-clean-ui-2/lib/features/editor/domain/models/export_composition_builder.dart)
- [fusionx_clean_ui_screen.dart](/Users/mx/Documents/InGeneBMFPro/sources/ui/fusionx-clean-ui-2/lib/features/editor/presentation/screens/fusionx_clean_ui_screen.dart)
- [export_composition_builder_test.dart](/Users/mx/Documents/InGeneBMFPro/sources/ui/fusionx-clean-ui-2/test/export_composition_builder_test.dart)

### Phase 2 - Export Bridge Contract

Open Flutter/native export APIs.

Deliverables:

- method channel methods
- export event channel contract
- export job id lifecycle

Acceptance:

- Flutter can start and cancel an export request
- progress can travel back into Flutter

Current implementation status:

- completed baseline

Current implementation artifacts:

- [stage6_export_controller.dart](/Users/mx/Documents/InGeneBMFPro/sources/ui/fusionx-clean-ui-2/lib/core/engine/stage6_export_controller.dart)
- [Stage6ExportManager.kt](/Users/mx/Documents/InGeneBMFPro/sources/ui/fusionx-clean-ui-2/android/app/src/main/kotlin/com/fusionx/fusionx_clean_ui_2/Stage6ExportManager.kt)
- [MainActivity.kt](/Users/mx/Documents/InGeneBMFPro/sources/ui/fusionx-clean-ui-2/android/app/src/main/kotlin/com/fusionx/fusionx_clean_ui_2/MainActivity.kt)
- [fusionx_clean_ui_screen.dart](/Users/mx/Documents/InGeneBMFPro/sources/ui/fusionx-clean-ui-2/lib/features/editor/presentation/screens/fusionx_clean_ui_screen.dart)

What this baseline now proves:

- Flutter can build a real export payload
- Flutter can send an export request into Android native through a dedicated export channel
- Android can accept the request, allocate an export job id, and emit lifecycle events
- cancel is now part of the explicit contract

What it does **not** prove yet:

- no output file is produced yet
- no real Transformer job is executed yet
- no MediaStore save flow is executed yet

### Phase 3 - Native ExportManager Baseline

Build dedicated Android export manager using `Media3 Transformer`.

Deliverables:

- export manager class
- transformer job creation
- output file writing
- success/failure handling

Acceptance:

- one trimmed clip exports
- two adjacent clips export in correct order
- output file is playable

Current implementation status:

- baseline implementation candidate completed
- pending device acceptance

Current implementation artifacts:

- [Stage6ExportManager.kt](/Users/mx/Documents/InGeneBMFPro/sources/ui/fusionx-clean-ui-2/android/app/src/main/kotlin/com/fusionx/fusionx_clean_ui_2/Stage6ExportManager.kt)
- [stage6_export_controller.dart](/Users/mx/Documents/InGeneBMFPro/sources/ui/fusionx-clean-ui-2/lib/core/engine/stage6_export_controller.dart)
- [fusionx_clean_ui_screen.dart](/Users/mx/Documents/InGeneBMFPro/sources/ui/fusionx-clean-ui-2/lib/features/editor/presentation/screens/fusionx_clean_ui_screen.dart)

What this candidate now does:

- validates first-export baseline eligibility before export starts
- builds a real `Composition` from the video track clips
- starts a real `Media3 Transformer` export job
- writes to an app-owned movies export directory
- emits `started / progress / completed / failed / cancelled`

Current honest limitation:

- the preset contract exists, but this first candidate still exports through a
  safe baseline H.264/AAC path without full preset-specific scaling logic yet
- post-export open/share and MediaStore handoff are not implemented yet
- scalar speed export is still outside the accepted first baseline
- motion/text export is still outside the accepted first baseline

### Phase 4 - Export UI And File Handling

Add user-visible export flow.

Deliverables:

- export bottom sheet or dialog
- quality preset selection
- export progress UI
- success/failure UI
- output open/share action

Acceptance:

- export can be started and observed in the app
- output file path is visible and usable

Current implementation status:

- baseline implementation candidate completed
- pending real-device acceptance

Current implementation artifacts:

- [export_bottom_sheet.dart](/Users/mx/Documents/InGeneBMFPro/sources/ui/fusionx-clean-ui-2/lib/features/editor/presentation/widgets/export_bottom_sheet.dart)
- [editor_top_bar.dart](/Users/mx/Documents/InGeneBMFPro/sources/ui/fusionx-clean-ui-2/lib/features/editor/presentation/widgets/editor_top_bar.dart)
- [fusionx_clean_ui_screen.dart](/Users/mx/Documents/InGeneBMFPro/sources/ui/fusionx-clean-ui-2/lib/features/editor/presentation/screens/fusionx_clean_ui_screen.dart)

What this candidate now does:

- opens a dedicated export bottom sheet from the top bar
- shows preset selection for `720p / 1080p / Original`
- shows baseline blockers and diagnostics before export starts
- shows live export progress and supports cancel
- shows output path after completion and supports path copy

### Phase 5 - Validation Matrix

Validate the first export baseline.

Must verify:

- trim correctness
- clip ordering correctness
- duration sanity
- aspect ratio sanity
- audio presence sanity
- cancel path
- failure path

Current implementation status:

- first baseline slice implemented
- broader matrix is still pending real-device acceptance

Current implementation artifacts:

- [Stage6ExportManager.kt](/Users/mx/Documents/InGeneBMFPro/sources/ui/fusionx-clean-ui-2/android/app/src/main/kotlin/com/fusionx/fusionx_clean_ui_2/Stage6ExportManager.kt)
- [stage6_export_controller.dart](/Users/mx/Documents/InGeneBMFPro/sources/ui/fusionx-clean-ui-2/lib/core/engine/stage6_export_controller.dart)
- [export_bottom_sheet.dart](/Users/mx/Documents/InGeneBMFPro/sources/ui/fusionx-clean-ui-2/lib/features/editor/presentation/widgets/export_bottom_sheet.dart)

What this first slice now does:

- validates that the output file exists
- validates that the output file size is non-zero
- validates that readable duration metadata exists
- validates that a readable video track exists
- compares exported duration against canonical timeline duration with tolerance
- captures output width/height and mime type when available
- captures `hasAudio/hasVideo` metadata when available
- reports validation metadata back into Flutter after completion
- cleans partial output files on cancel/failure/validation failure when possible
- keeps export-session diagnostics visible in the sheet: preset, clip count,
  target duration, and current phase
- can open the completed output file from the export sheet through native
  `FileProvider` handoff
- shows a centered in-sheet loading/progress block with estimated remaining time
  based on real export progress

### Phase 6 - Post-Baseline Extensions

Open only after Phase 5 is accepted.

Priority order:

1. scalar speed export
2. audio correctness hardening
3. text/motion export using normalized motion composition
4. image overlays
5. transitions
6. higher-quality presets
7. advanced render/export backend evaluation with `BMF`

## Best Stack Recommendation

### Best first stack

- Flutter canonical export composition
- Android native export manager
- `Media3 Transformer`
- hardware-backed Android encoding path where available
- H.264/AAC preset ladder first

### Best long-term stack

- same Flutter export composition contract
- same native export orchestration contract
- optional later backend expansion to `BMF`

This preserves one truth while allowing backend growth later.

## What Must Not Happen

Do not:

- reuse the live player as export engine
- treat preview output as export output
- use screen capture as export
- let Flutter UI state become export truth
- mix first export baseline with motion/text/transition parity immediately
- start with `BMF` integration before a first accepted native export slice exists

## Distance To First Export

Current readiness judgment:

- architectural readiness for first export baseline: `medium-high`
- implementation readiness for first export baseline: `medium`

Distance estimate:

- to first accepted export baseline: `2 to 3 focused implementation/acceptance slices`
- to broad professional export parity: `significantly more after baseline`

## Current Next Allowed Step

Current next allowed step:

`Device acceptance for Phase 3 and Phase 4`

Then:

`Broader Phase 5 device matrix acceptance`

Only after device acceptance succeeds should the baseline be treated as
accepted.

## References

- [Future Stage 7 Draft - Export Contract And Native Orchestration Baseline](/Users/mx/Documents/InGeneBMFPro/docs/process/future-stage-7-export-contract-and-native-orchestration-baseline.md)
- [Stage 6 Foundation Reference - Canonical Timeline Truth For Future Motion, Script, And Export Layers](/Users/mx/Documents/InGeneBMFPro/docs/process/stage-6-foundation-reference-canonical-timeline-truth-for-future-motion-script-export.md)
- [Professional Motion Architecture](/Users/mx/Documents/InGeneBMFPro/docs/process/professional-motion-architecture.md)
- [Media3 Transformer](https://developer.android.com/media/media3/transformer)
- [Media3 editing app guide](https://developer.android.com/media/implement/editing-app)
- [BMF Overview](https://babitmf.github.io/docs/bmf/overview/)
- [BMF GitHub](https://github.com/BabitMF/bmf)
