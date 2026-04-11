# ReFusionXx

`ReFusionXx` is the official baseline repository for the current project state.

This repository starts from the latest validated legacy workspace snapshot and
preserves the full codebase, plans, and documentation as the new official
`main` baseline.

Official shipped app identity in this baseline:

- app name: `ReFusion`
- package id: `com.refusion.app`
- canonical shipped version source:
  [pubspec.yaml](/Users/mx/Documents/InGeneBMFPro/sources/ui/fusionx-clean-ui-2/pubspec.yaml)

Legacy documentation still contains the original local filesystem paths from the
source workspace where this snapshot was authored. Those references are kept
intentionally for continuity with the existing execution notes.

## Source Of Truth

This file is the canonical progress log and execution reference.

Core rules:

- no plan is imported from any other project
- no stage may be skipped
- no stage may be marked complete without its documented exit gate
- no undocumented workaround may be treated as an official step
- all engine acquisition and build steps must follow official documentation first
- any later Flutter bridge work is project-owned unless official BMF documentation explicitly covers it
- every important milestone must update this file before moving on
- Android release APK handoff must go only to `/Users/mx/Desktop/Ingame APK release`
- APK naming rule:
  - `Ingame pro V1.apk`
  - `Ingame pro V2.apk`
  - `Ingame pro V3.apk`

## Official Source Hierarchy

Primary sources only:

1. Official BMF repository: [https://github.com/BabitMF/bmf](https://github.com/BabitMF/bmf)
2. Official BMF docs: [https://babitmf.github.io/docs/bmf/](https://babitmf.github.io/docs/bmf/)
3. Official BMFLite README: [https://github.com/BabitMF/bmf/blob/master/bmf_lite/README.md](https://github.com/BabitMF/bmf/blob/master/bmf_lite/README.md)
4. Official Android Media3 docs: [https://developer.android.com/media/media3](https://developer.android.com/media/media3)
5. UI reference repository: [https://github.com/devmxai/fusionx-clean-ui-2](https://github.com/devmxai/fusionx-clean-ui-2)

## Current Stage

Current stage: `Stage 9 - Performance Hardening`

Stage status: `IMPLEMENTATION ACTIVE`

Active timeline development reference:

- [Stage 6 Timeline Professionalization Master Plan](/Users/mx/Documents/InGeneBMFPro/docs/process/stage-6-timeline-professionalization-master-plan.md)
- [Stage 6 Timeline Professionalization - Stage 0 Baseline Freeze](/Users/mx/Documents/InGeneBMFPro/docs/process/stage-6-timeline-professionalization-stage-0-baseline-freeze.md)
- [Stage 6 Timeline Professionalization - Stage 1 Single Playback Clock Ownership](/Users/mx/Documents/InGeneBMFPro/docs/process/stage-6-timeline-professionalization-stage-1-single-playback-clock-ownership.md)
- [Stage 6 Timeline Professionalization - Stage 2 Professional Live Scrub Engine](/Users/mx/Documents/InGeneBMFPro/docs/process/stage-6-timeline-professionalization-stage-2-professional-live-scrub-engine.md)
- [Stage 6 Timeline Professionalization - Stage 3 Zoom And Ruler Canonicalization](/Users/mx/Documents/InGeneBMFPro/docs/process/stage-6-timeline-professionalization-stage-3-zoom-and-ruler-canonicalization.md)
- [Stage 6 Timeline Professionalization - Stage 4 Trim Interaction Hardening](/Users/mx/Documents/InGeneBMFPro/docs/process/stage-6-timeline-professionalization-stage-4-trim-interaction-hardening.md)
- [Stage 6 Timeline Professionalization - Stage 5 Gesture State Machine Lock](/Users/mx/Documents/InGeneBMFPro/docs/process/stage-6-timeline-professionalization-stage-5-gesture-state-machine-lock.md)
- [Stage 6 Timeline Professionalization - Stage 6 Editing Semantics Hardening](/Users/mx/Documents/InGeneBMFPro/docs/process/stage-6-timeline-professionalization-stage-6-editing-semantics-hardening.md)
- [Stage 6 Timeline Professionalization - Stage 7 Multi-Track And Mobile Navigation Quality](/Users/mx/Documents/InGeneBMFPro/docs/process/stage-6-timeline-professionalization-stage-7-multi-track-and-mobile-navigation-quality.md)
- [Stage 6 Timeline Professionalization - Stage 8 Motion And Text Timeline Integration](/Users/mx/Documents/InGeneBMFPro/docs/process/stage-6-timeline-professionalization-stage-8-motion-and-text-timeline-integration.md)
- [Stage 6 Timeline Professionalization - Stage 9 Performance Hardening](/Users/mx/Documents/InGeneBMFPro/docs/process/stage-6-timeline-professionalization-stage-9-performance-hardening.md)
- [Stage 6 Timeline Professionalization - Track Manipulation And Interaction Plan](/Users/mx/Documents/InGeneBMFPro/docs/process/stage-6-timeline-professionalization-track-manipulation-and-interaction-plan.md)
- [Current Thread Handoff And Resume Packet](/Users/mx/Documents/InGeneBMFPro/docs/process/current-thread-handoff-and-resume-packet.md)

Active independent feature plans:

- [Feature Plan - Speed (Normal And Curve)](/Users/mx/Documents/InGeneBMFPro/docs/process/feature-speed-normal-and-curve-plan.md)
- [To First Export](/Users/mx/Documents/InGeneBMFPro/docs/process/to-first-export.md)
- [Remaining Path To Full Export Parity](/Users/mx/Documents/InGeneBMFPro/docs/process/remaining-path-to-full-export-parity.md)
- [Professional Export System Plan](/Users/mx/Documents/InGeneBMFPro/docs/process/professional-export-system-plan.md)
- [Professional Effects Render And Export Plan](/Users/mx/Documents/InGeneBMFPro/docs/process/professional-effects-render-and-export-plan.md)
- [Professional Export Audit Gap And Cleanup Plan](/Users/mx/Documents/InGeneBMFPro/docs/process/professional-export-audit-gap-and-cleanup-plan.md)
- [Professional Export Subsystem Handoff And Resume Map](/Users/mx/Documents/InGeneBMFPro/docs/process/professional-export-subsystem-handoff-and-resume-map.md)
- [Export Current-Stage Closure Plan](/Users/mx/Documents/InGeneBMFPro/docs/process/export-current-stage-closure-plan.md)

Current timeline professionalization state:

- `Stage 0`: closed
- `Stage 1`: closed
- `Stage 2`: parked at accepted interim baseline
- `Stage 3`: closed
- `Stage 4`: closed
- `Stage 5`: closed
- `Stage 6`: closed
- `Stage 7`: parked at accepted interim baseline
- `Stage 8`: closed
- `Stage 9`: active
- current estimated timeline maturity: `76%`

Current Stage 9 checkpoint:

- current motion/text timeline projection is memoized for the active editor state
- current display tracks reuse cached text-track projection when motion state
  has not changed
- current motion/text lookup paths reuse cached current entries in the common
  case
- this improves hot-path projection cost without changing accepted timeline
  semantics

Current next timeline workstream reference:

- focused next timeline plan is now:
  [Stage 6 Timeline Professionalization - Track Manipulation And Interaction Plan](/Users/mx/Documents/InGeneBMFPro/docs/process/stage-6-timeline-professionalization-track-manipulation-and-interaction-plan.md)
- this scoped plan does not replace the master plan
- it exists so the next timeline work can start from explicit manipulation
  ownership, lane targeting, and mobile drag quality rules
- latest thread handoff / resume packet for opening a new thread is now:
  [Current Thread Handoff And Resume Packet](/Users/mx/Documents/InGeneBMFPro/docs/process/current-thread-handoff-and-resume-packet.md)

Latest pushed timeline checkpoint in `BETA1`:

- timeline lane visuals below the ruler were returned to a more neutral
  monochrome style in
  [timeline_panel.dart](/Users/mx/Documents/InGeneBMFPro/sources/ui/fusionx-clean-ui-2/lib/features/editor/presentation/widgets/timeline_panel.dart)
- the colorful lane tint extension on the left side of the timeline rows was
  removed in
  [timeline_panel.dart](/Users/mx/Documents/InGeneBMFPro/sources/ui/fusionx-clean-ui-2/lib/features/editor/presentation/widgets/timeline_panel.dart)
- the timeline now starts with no pre-seeded empty media/text tracks and creates
  a track only when the first asset or text preset of that type is inserted, in
  [fusionx_clean_ui_screen.dart](/Users/mx/Documents/InGeneBMFPro/sources/ui/fusionx-clean-ui-2/lib/features/editor/presentation/screens/fusionx_clean_ui_screen.dart)
- text preset insertion now ensures a text track exists before adding the first
  generated text clip, in
  [fusionx_clean_ui_screen.dart](/Users/mx/Documents/InGeneBMFPro/sources/ui/fusionx-clean-ui-2/lib/features/editor/presentation/screens/fusionx_clean_ui_screen.dart)
- scrub now has dedicated gesture surfaces in the empty spacer below the ruler
  and in the empty timeline area below the last visible track, so background
  scrub can start from general timeline space and not only from track surfaces,
  in
  [timeline_panel.dart](/Users/mx/Documents/InGeneBMFPro/sources/ui/fusionx-clean-ui-2/lib/features/editor/presentation/widgets/timeline_panel.dart)
- long-press clip reorder now enters through an animated morph from the normal
  timeline clip geometry into compact reorder cards in
  [timeline_panel.dart](/Users/mx/Documents/InGeneBMFPro/sources/ui/fusionx-clean-ui-2/lib/features/editor/presentation/widgets/timeline_panel.dart)
- the same-track reorder preview now feels more magnetic during insertion, with
  a clearer temporary insertion gap and softer rightward push for the clips that
  come after the insertion point in
  [timeline_panel.dart](/Users/mx/Documents/InGeneBMFPro/sources/ui/fusionx-clean-ui-2/lib/features/editor/presentation/widgets/timeline_panel.dart)
- the reorder-entry crash shown after the animation work is now fixed at the
  root by switching `_TimelinePanelState` from
  `SingleTickerProviderStateMixin` to `TickerProviderStateMixin`, so the panel
  can legally own both the playback ticker and the reorder animation controller
  in
  [timeline_panel.dart](/Users/mx/Documents/InGeneBMFPro/sources/ui/fusionx-clean-ui-2/lib/features/editor/presentation/widgets/timeline_panel.dart)
- the reorder presentation has now been corrected so the base timeline row fades
  out during reorder entry, the long strip no longer remains visible under the
  overlay, and compact reorder clips are rendered by a dedicated card UI rather
  than by shrinking the normal timeline clip widget in
  [timeline_panel.dart](/Users/mx/Documents/InGeneBMFPro/sources/ui/fusionx-clean-ui-2/lib/features/editor/presentation/widgets/timeline_panel.dart)
- the reorder interaction no longer swaps the ruler/header area into a separate
  mode label; the timeline chrome stays in its normal shape and only the clips
  on the active reordered row transition into square cards while the selected
  pressed clip remains the active moving card in
  [timeline_panel.dart](/Users/mx/Documents/InGeneBMFPro/sources/ui/fusionx-clean-ui-2/lib/features/editor/presentation/widgets/timeline_panel.dart)
- the reorder drag path is now backed by global pointer tracking while the base
  row clips animate out, so the long-press contact does not get lost when the
  active row morphs into compact cards in
  [timeline_panel.dart](/Users/mx/Documents/InGeneBMFPro/sources/ui/fusionx-clean-ui-2/lib/features/editor/presentation/widgets/timeline_panel.dart)
- the moving insertion handle has been removed from the reorder UI, the active
  row rail now hides during the card state, and the temporary insertion spacing
  plus dragged-card scale were reduced for a smoother visual transition in
  [timeline_panel.dart](/Users/mx/Documents/InGeneBMFPro/sources/ui/fusionx-clean-ui-2/lib/features/editor/presentation/widgets/timeline_panel.dart)
- non-video timeline clips now preserve true temporal placement when moved, so
  overlay/text/audio-style tracks shift in time instead of falling back to
  video-style reorder semantics in
  [fusionx_clean_ui_screen.dart](/Users/mx/Documents/InGeneBMFPro/sources/ui/fusionx-clean-ui-2/lib/features/editor/presentation/screens/fusionx_clean_ui_screen.dart)
- temporal gaps before moved non-video clips now render as real empty space
  instead of `+` add placeholders, and gap width now follows actual time width
  so drop precision stays stable in
  [timeline_mock_models.dart](/Users/mx/Documents/InGeneBMFPro/sources/ui/fusionx-clean-ui-2/lib/features/editor/presentation/models/timeline_mock_models.dart)
  and
  [timeline_panel.dart](/Users/mx/Documents/InGeneBMFPro/sources/ui/fusionx-clean-ui-2/lib/features/editor/presentation/widgets/timeline_panel.dart)
- moved motion-text clips now respect their shifted activation range during
  preview/runtime evaluation, so the text appears only from its real timeline
  start in
  [professional_motion_runtime_helpers.dart](/Users/mx/Documents/InGeneBMFPro/sources/ui/fusionx-clean-ui-2/lib/features/editor/domain/models/professional_motion_runtime_helpers.dart)
  and
  [fusionx_clean_ui_screen.dart](/Users/mx/Documents/InGeneBMFPro/sources/ui/fusionx-clean-ui-2/lib/features/editor/presentation/screens/fusionx_clean_ui_screen.dart)
- moving non-video clips no longer auto-jumps the playhead or recenters the
  timeline; playback position stays under explicit user control in
  [fusionx_clean_ui_screen.dart](/Users/mx/Documents/InGeneBMFPro/sources/ui/fusionx-clean-ui-2/lib/features/editor/presentation/screens/fusionx_clean_ui_screen.dart)
- this pushed checkpoint has passed:
  - `dart format`
  - `flutter analyze`
  - `flutter build apk --debug`
- this pushed checkpoint has also been installed on the connected device:
  - package: `com.refusion.app`
  - device: `SM-S908N`
  - `versionName = 1.0.0-beta.1`
  - `lastUpdateTime = 2026-04-11 04:34:01`
- this pushed checkpoint is still **not yet accepted** until the manipulation
  interaction is checked on device for:
  - animated entry feel
  - same-track magnetic insertion behavior
  - no accidental gaps after drop
  - non-video temporal dragging precision
  - text/runtime timing after shifted placement

Current independent feature checkpoint:

- `Speed` feature planning is now opened as a separate track
- current implemented baseline includes:
  - dock entry
  - compact speed bottom sheet
  - clip-level speed metadata foundation
  - visible timeline speed badge
  - constant speed duration truth for the selected clip

Current export planning checkpoint:

- first export planning is now documented as a standalone feature plan
- chosen first export backend: `Media3 Transformer`
- chosen long-term advanced backend: `BMF`
- canonical export architecture reference is now:
  [Professional Export System Plan](/Users/mx/Documents/InGeneBMFPro/docs/process/professional-export-system-plan.md)
- current export close-out reference is now:
  [Export Current-Stage Closure Plan](/Users/mx/Documents/InGeneBMFPro/docs/process/export-current-stage-closure-plan.md)
- current export audit and cleanup reference is now:
  [Professional Export Audit Gap And Cleanup Plan](/Users/mx/Documents/InGeneBMFPro/docs/process/professional-export-audit-gap-and-cleanup-plan.md)
- current subsystem resume reference is now:
  [Professional Export Subsystem Handoff And Resume Map](/Users/mx/Documents/InGeneBMFPro/docs/process/professional-export-subsystem-handoff-and-resume-map.md)
- current export graph checkpoint now includes:
  - explicit graph schema metadata
  - machine-readable capability and blocker contracts
  - property-level capability registry
  - renderer ownership registry
  - interpolation contract registry
  - native contract enforcement of preflight blockers
  - `Phase 2 Part 1` monitor-approved typography/layout contract
  - `Phase 2 Part 2` monitor-approved animation-block runtime contract
  - `Phase 2 Part 3` monitor-and-technical-approved interpolation contract
  - `Phase 2 Part 4` monitor-and-technical-approved preview/export layout contract
  - `Phase 2 Part 5` monitor-and-technical-approved preview/export parity-probe seam
  - export now accepts an explicit requested output FPS and routes it through the native Media3 export path
  - native export now applies a bitrate ladder derived from output size × fps through `DefaultEncoderFactory`
  - device capability checks now gate unsupported H.264 size/rate export profiles before export starts
  - `Phase 3 Part 1` monitor-and-technical-approved visual compositor contract
  - `Phase 3 Part 2` monitor-and-technical-approved graph-driven visual assembly contract
  - `Phase 3 Part 3` monitor-and-technical-approved canonical visual assembly window contract
  - `Phase 3 Part 4` monitor-and-technical-approved window-policy-driven visual execution contract
  - `Phase 3 Part 5` monitor-and-technical-approved window-segmented visual execution and per-route provenance diagnostics
  - `Phase 3 Part 6 foundation` monitor-and-technical-approved compositor execution-owner and compositor-plan contract
  - `Phase 3 Part 6A` monitor-approved narrow native compositor execution for compositor-owned base-media-plus-image-overlay-stack windows with per-window execution diagnostics
  - `Phase 3 Part 6B` monitor-approved truth/preflight honesty for the supported narrow image-overlay-stack compositor slice
  - `Phase 3 Part 6C` monitor-approved canonical/runtime/diagnostic honesty for the supported narrow image-overlay-stack compositor slice
  - `Phase 3 Part 7` monitor-approved typed ordered compositor execution-input truth across Dart plans and native canonical/runtime validation
  - latest real-device export checkpoint recorded in the plan:
    - export backend now produces a real media file with readable video/audio metadata
    - authored-only visual-window classification is now corrected
    - generated timeline text-track clips are now excluded from media export tracks
      so motion text no longer triggers false `missing export asset id` blockers
    - `video + slow motion + text motion` now exports on the current `30fps`
      path, but the actual output stream can still be about `8-10fps`; this means
      the text motion can still be visibly stepped because the current narrow
      authored overlay-clock repair is not yet the final accepted compositor/effects lane
    - follow-up device evidence:
      - `video + text motion` requested at `30fps` and `90fps` exported as actual
        `24fps` streams
      - `video + slow motion + text motion` requested at `30fps` exported at
        roughly `9.7fps`, matching the visible text-motion stutter
    - the hard blocker was traced to the lack of an accepted authored visual
      lane for `slow motion + text/image/shape animation`
    - current active repair path is:
      - keep media speed isolated on the media base pass
      - run authored visuals on their own export timeline clock
      - generalize that lane later into a supported compositor/effects path
    - April 10 implementation checkpoint:
      - a Media3 `TimestampAdjustment` fixed-cadence attempt was tested before
        authored `OverlayEffect`
      - that attempt failed on device with `ERROR_CODE_MUXING_TIMEOUT` and was
        removed from the production export path
      - a narrower native repair path is now implemented in
        `Stage6ExportManager`:
        - motion text can be routed onto an independent transparent-image
          overlay sequence instead of being attached directly to the slowed media
          item
        - this keeps clip `setSpeed(...)` on the media base path while the text
          overlay is evaluated on its own export timeline clock
      - the first version of that path immediately failed with Media3
        `Asset loader error`
        because the transparent PNG overlay asset was created as an image input
        without `MediaItem.Builder.setImageDurationMs(...)`
      - that asset-loader blocker has now been fixed by setting image duration
        and image mime type on the transparent overlay `MediaItem`
      - the old authored-motion high-FPS blocker above `30fps` was removed, so
        `60fps`/`90fps` now reach the real encoder capability gate
      - latest installed real-device build after that fix:
        - package `com.refusion.app`
        - device `lastUpdateTime = 2026-04-11 04:34:01`
      - urgent newly confirmed parity blocker:
        - motion-text blur still does **not** match preview semantics
        - preview uses a real text-layer/image-space blur via
          `ImageFilter.blur(...)`
        - export now prefers a contract-driven premultiplied bitmap Gaussian
          first path, but it still is not the final GL/compositor blur lane
        - `BlurMaskFilter(...)` remains only as a fallback path
        - in practice this can make blur-heavy presets export as softened white
          / opacity-like text, or show fringe/dark-edge artifacts instead of a
          true accepted Gaussian-style blur
        - this blocker must be treated as important and must be re-tested later
          with a blur-heavy preset before the export file can be considered
          visually accepted
      - fixed-cadence authored motion still needs broader real-device acceptance
        and may still require a safer compositor/custom-effect generalization
        before it can be marked accepted
    - current motion/text parity is not yet acceptance-grade for slow-motion
      authored animation even when the export file is successfully produced
- `Phase 1 - ExportComposition Builder` baseline is now implemented
- `Phase 2 - Export Bridge Contract` baseline is now implemented
- `Phase 3 - Native ExportManager Baseline` is now implemented as a first
  export candidate pending device acceptance
- current export composition baseline includes:
  - canonical export models
  - pure builder from editor truth
  - motion-aware composition attachment point
  - first-baseline eligibility diagnostics
  - test coverage for builder sequencing and blocker detection
- current export bridge baseline includes:
  - dedicated Flutter export controller
  - dedicated Android export manager
  - dedicated export method channel
  - dedicated export event channel
  - export job id lifecycle foundation
  - cancel contract foundation
- current export execution candidate includes:
  - real `Media3 Transformer` start path
  - real output file path generation
  - real export progress events
  - real completion/failure/cancel lifecycle
  - first baseline validation for unsupported content
- current export UI baseline includes:
  - dedicated export bottom sheet
  - preset selection UI
  - live progress/cancel state
  - output path copy state after completion
- current export validation baseline includes:
  - output-file existence validation
  - file-size validation
  - duration metadata validation
  - exported-duration vs expected-duration tolerance check
  - readable video-track validation
  - output width/height/mime reporting back to Flutter
  - partial-output cleanup on cancel/failure when possible
  - session diagnostics in the export sheet
  - native `Open File`
  - native `Share File`
  - native `Save To Gallery`
  - in-sheet progress block with estimated remaining time
  - native admission path for `normal speed` clips
  - motion/text render-contract diagnostics in the export sheet
  - richer motion/text export contract payload carrying:
    - scenes/layers/elements
    - property channels
    - keyframes/interpolation
    - source bindings
  - first canonical `motionTextProgram` export contract for deterministic
    text-motion evaluation
  - first native narrow `CanvasOverlay`-backed deterministic text-motion lane
    fed by app-owned export renderer logic and shared raster contracts
  - first native image export path for a single visual track via
    `EditedMediaItem.setDurationUs(...)`
  - first native single-audio-track export path alongside the visual baseline
    via a second `EditedMediaItemSequence`
  - export validation now checks expected audio presence, not only file existence
    and duration
- next allowed export implementation step: `Device acceptance for Phase 3 and Phase 4`
- remaining export work before the first accepted baseline is now:
  - real-device export verification
  - real-device acceptance for preset ladder
  - real-device acceptance for scalar speed export
  - real-device acceptance for `Open/Share/Save` output handoff
  - full validation matrix for trim/order/audio/duration sanity
  - motion/text renderer parity
  - later full image/audio/effects/transition parity
- professional export parity beyond the accepted baseline now requires:
  - canonical export render graph
  - deterministic motion/text renderer
  - visual compositor layer
  - audio graph
  - effects/transitions/camera parity
  - full speed/time-remap parity
  - backend decision gate and quality hardening

What remains in the broader timeline roadmap:

- `Stage 7` remains parked for later multi-track/mobile-density polish
- `Stage 8` remains closed as an accepted motion/text foundation
- `Stage 10` remains for final closure

Active execution note:

- the timeline professionalization documents linked above are the current
  execution truth
- the most recent resume/onboarding packet for a fresh thread is:
  [Current Thread Handoff And Resume Packet](/Users/mx/Documents/InGeneBMFPro/docs/process/current-thread-handoff-and-resume-packet.md)
- older `Stage 5` / older `Stage 6` sections later in this README are archival
  progress history only and must not override the active stage documents

Timeline documentation discipline:

- every accepted timeline slice must update:
  - the stage document
  - the timeline master plan
  - this README snapshot when the visible stage state changes
- no timeline phase may be treated as current truth if it exists only in chat
  and not in the project documentation

## Snapshot Preservation

- independent GitHub repository:
  [https://github.com/devmxai/ReFusionXx](https://github.com/devmxai/ReFusionXx)
- accepted snapshot baseline:
  - date: `2026-04-06`
  - commit: `4bc0e18`
  - scope: `Stage 5B` accepted scrub snapshot
- latest beta snapshot note:
  - [BETA10 snapshot note](/Users/mx/Documents/InGeneBMFPro/docs/releases/BETA10.md)
  - [BETA11 snapshot note](/Users/mx/Documents/InGeneBMFPro/docs/releases/BETA11.md)
  - [BETA12 snapshot note](/Users/mx/Documents/InGeneBMFPro/docs/releases/BETA12.md)
  - [BETA13 snapshot note](/Users/mx/Documents/InGeneBMFPro/docs/releases/BETA13.md)
  - [BETA14 snapshot note](/Users/mx/Documents/InGeneBMFPro/docs/releases/BETA14.md)
  - [BETA1 snapshot note](/Users/mx/Documents/InGeneBMFPro/docs/releases/BETA1.md)
- current pushed thread/bootstrap packet:
  - [Current Thread Handoff And Resume Packet](/Users/mx/Documents/InGeneBMFPro/docs/process/current-thread-handoff-and-resume-packet.md)

Completed so far:

- created the isolated workspace at `/Users/mx/Documents/InGeneBMFPro`
- created documentation folders
- created source folders for UI and engine
- created official asset folder
- created Desktop release handoff folder at `/Users/mx/Desktop/Ingame APK release`
- started multi-agent research on:
  - official BMF/BMFLite documentation
  - UI baseline audit
  - community pitfalls and integration lessons
  - compliance/reviewer policy
- closed `Stage 0 - Governance, research, and official source acquisition`
- downloaded the full UI reference repository into:
  `/Users/mx/Documents/InGeneBMFPro/sources/ui/fusionx-clean-ui-2`
- recorded UI provenance:
  - origin: `https://github.com/devmxai/fusionx-clean-ui-2`
  - commit: `7990d4acf2d60cb37ecdb872d7733da2cf0ad975`
- downloaded the full official BMF repository into:
  `/Users/mx/Documents/InGeneBMFPro/sources/engine/bmf-official`
- recorded BMF provenance:
  - origin: `https://github.com/BabitMF/bmf`
  - commit: `7d5c79bde80cbaffb7c9aa99f0593c4c490ceebe`
  - `.gitmodules` absent at this commit
- downloaded official public release assets into:
  `/Users/mx/Documents/InGeneBMFPro/assets/official`
  - `files.tar.gz`
  - `bmf_lite_files.tar.gz`
- extracted the official public release assets inside the project
- recorded public asset checksums in the acquisition report
- classified `QNN / ControlNet` as `out of current baseline scope`
- approved the non-QNN official baseline as the current project target
- applied UI-shell truthfulness cleanup inside the isolated reference UI source:
  `/Users/mx/Documents/InGeneBMFPro/sources/ui/fusionx-clean-ui-2`
  - removed seeded default timeline clips from the initial state
  - removed branded/fake preview copy from the canvas shell
  - changed the `Add` flow to open a bottom sheet with `Video` and `Image` tabs
  - changed the sheet to require explicit item selection before `Add to timeline`
  - disabled shell playback so the UI no longer implies real transport
  - disabled `Add` while non-visual dock tabs are active
  - reclassified the seeded library entries as sample assets, not imported media
  - kept this as UI-shell work only, without claiming real import or real playback
- closed `Stage 1 - Official native baseline build` using an official-source-backed non-QNN Android root-CMake path
- recorded official-source evidence that:
  - the BMFLite root CMake defaults `BMF_LITE_ENABLE_TEX_GEN_PIC` to `OFF`
  - Android convenience paths force or default it to `ON`
  - project collaborator evidence says QNN is only needed for the Vincent chart demo:
    [Issue #159 comment](https://github.com/BabitMF/bmf/issues/159#issuecomment-2553439114)
- successfully configured and built the native non-QNN Android baseline without patching the source tree
- produced Stage 1 native artifacts:
  - `/Users/mx/Documents/InGeneBMFPro/sources/engine/bmf-official/bmf_lite/build_android_non_qnn_manual/lib/libbmf_lite.a`
  - `/Users/mx/Documents/InGeneBMFPro/sources/engine/bmf-official/bmf_lite/build_android_non_qnn_manual/bin/test_bmf_lite_android_interface`
- closed `Stage 2 - Official native real-device validation` on physical Android hardware:
  - device serial: `R3CT10LKLSX`
  - model: `SM-S908N`
  - ABI: `arm64-v8a`
  - exit code: `0`
  - successful native outputs created on device:
    - `backup.jpg`
    - `super_resolution.jpg`
    - `denoise.jpg`
- closed `Stage 3 - UI Import And Boundary Lock`
- closed `Stage 4 - Architecture Lock`
- opened `Stage 5 - Native Transport And Preview Integration`
- documented the architecture ownership table for:
  - transport
  - preview
  - preview aspect ratio
  - timeline/playhead
  - import
  - processing
  - export

Current stage focus:

- begin the real transport/preview integration under the locked ownership model
- keep Flutter out of transport ownership
- use hot reload only for Dart-side shell work
- rebuild when native Android or BMFLite integration code changes
- Stage 5 first slice implementation is now in progress inside:
  `/Users/mx/Documents/InGeneBMFPro/sources/ui/fusionx-clean-ui-2`
- the current Stage 5 slice uses:
  - Android `Media3` native transport
  - one fixed local Android sample source
  - `MethodChannel` + `EventChannel` state flow
  - Android `PlatformView` preview hosting
  - Flutter as host/presenter only
- Stage 5 first-slice implementation details now completed:
  - copied the official BMFLite sample video to:
    `/Users/mx/Documents/InGeneBMFPro/sources/ui/fusionx-clean-ui-2/android/app/src/main/res/raw/stage5_sample.mp4`
  - added Android native transport bridge classes under:
    `/Users/mx/Documents/InGeneBMFPro/sources/ui/fusionx-clean-ui-2/android/app/src/main/kotlin/com/fusionx/fusionx_clean_ui_2`
  - added Flutter-side transport controller and native preview host under:
    `/Users/mx/Documents/InGeneBMFPro/sources/ui/fusionx-clean-ui-2/lib/core/engine`
    `/Users/mx/Documents/InGeneBMFPro/sources/ui/fusionx-clean-ui-2/lib/features/editor/presentation/widgets`
  - wired the editor screen so play/seek/scrub now target native transport ownership in the Stage 5 slice
  - disabled mock add/edit controls while the fixed sample transport slice is active, so the UI does not imply real import or real timeline truth yet
  - kept real import explicitly deferred
- Media3 compatibility note:
  - the Stage 5 slice originally started on AGP `7.3.0`, Gradle `7.5`, `compileSdk 33`, and `Media3 1.1.1`
  - the approved `Stage 5B` uplift has now been applied locally to the minimum official stack needed for scrubbing mode:
    - AGP `8.6.0`
    - Gradle `8.7`
    - Kotlin plugin `1.9.24`
    - Java target `17`
    - `compileSdk 35`
    - `targetSdk 35`
    - `minSdk 21`
    - `androidx.media3:1.8.0`
  - `minSdk 21` became mandatory when moving to `Media3 1.8.0`, because the library manifest declares `minSdkVersion 21`
- current device-side status:
  - `flutter analyze` passes
  - Stage 5B uplift build succeeded locally via:
    `./gradlew :app:assembleDebug`
  - latest debug APK was rebuilt at:
    `/Users/mx/Documents/InGeneBMFPro/sources/ui/fusionx-clean-ui-2/build/app/outputs/apk/debug/app-debug.apk`
  - latest debug APK was reinstalled onto device `R3CT10LKLSX` using `adb install -r`
  - the app process was relaunched successfully on-device
  - user-device feedback confirmed:
    - play was initially smooth
    - scrub did not update preview continuously
    - the timeline clip was initially absent
  - follow-up Stage 5 fixes now applied:
    - added a read-only sample clip to the timeline while fixed-sample transport is active
    - prevented external/programmatic timeline sync from toggling native scrubbing state
    - throttled native seek dispatch while the user is actively scrubbing
    - kept the final exact seek after scrub release
  - latest debug APK containing those fixes was rebuilt and reinstalled on device `R3CT10LKLSX`
  - scrub investigation then confirmed the remaining limitation was architectural in the earlier Stage 5 slice:
    - current stack was on `Media3 1.1.1`
    - current sample had sparse keyframes
    - sync-seeking during drag could legitimately resolve to frame `0`
    - professional live scrub was therefore not closable in that earlier slice
  - opened `Stage 5B - Professional Scrub Upgrade` as the approved sub-slice plan to close the scrub gap before any move toward `Stage 6`
  - `Stage 5B` is explicitly a scrub-quality sub-slice only and does not close full `Stage 5` by itself
  - `Stage 5B` implementation is now in progress:
    - `Phase 0` baseline remained frozen as documented
    - `Phase 1` toolchain uplift completed locally
    - `Phase 2` scrub logic replacement completed locally
    - native scrub now uses `ExoPlayer.setScrubbingModeEnabled(true/false)`
    - native scrub parameters now start with `ScrubbingModeParameters.DEFAULT`
    - the final settle seek now happens in native on scrub release
    - the extra Flutter-side scrub timer layer was removed so Flutter no longer double-throttles native transport
    - one bounded `~16ms` timeline dispatch layer still remains in `TimelinePanel`, intentionally, as the single active Flutter-side coalescing layer
  - physical-device acceptance was completed on `2026-04-06`:
    - scrub now works well and is accepted for the current fixed-sample scope
    - the result is not claimed as perfect `100%`, but it is accepted as stable and professional enough to close this slice
  - `Stage 5B` is now closed for the accepted fixed-sample scrub scope
- closed `Stage 5 - Native Transport And Preview Integration`
- opened `Stage 6 - Real Import And Timeline Truth`
- implemented the first Stage 6 slice inside:
  - `/Users/mx/Documents/InGeneBMFPro/sources/ui/fusionx-clean-ui-2/android/app/src/main/kotlin/com/fusionx/fusionx_clean_ui_2/MainActivity.kt`
  - `/Users/mx/Documents/InGeneBMFPro/sources/ui/fusionx-clean-ui-2/android/app/src/main/kotlin/com/fusionx/fusionx_clean_ui_2/DeviceMediaLibraryManager.kt`
  - `/Users/mx/Documents/InGeneBMFPro/sources/ui/fusionx-clean-ui-2/android/app/src/main/kotlin/com/fusionx/fusionx_clean_ui_2/Stage5TransportManager.kt`
  - `/Users/mx/Documents/InGeneBMFPro/sources/ui/fusionx-clean-ui-2/lib/core/engine/stage5_native_transport_controller.dart`
  - `/Users/mx/Documents/InGeneBMFPro/sources/ui/fusionx-clean-ui-2/lib/features/editor/presentation/screens/fusionx_clean_ui_screen.dart`
  - `/Users/mx/Documents/InGeneBMFPro/sources/ui/fusionx-clean-ui-2/lib/features/editor/presentation/widgets/media_bottom_sheet.dart`
  - `/Users/mx/Documents/InGeneBMFPro/sources/ui/fusionx-clean-ui-2/lib/features/editor/presentation/models/editor_asset_item.dart`
- first Stage 6 slice now does all of the following:
  - requests standard Android media-library access at runtime
  - loads real device videos and images into the approved bottom-sheet grid
  - imports a real selected video into the timeline and rebinds native `Media3` preview to that imported source
  - imports a real selected image into the timeline and updates the preview shell metadata path without claiming native image playback
  - marks imported entries inside the sheet so repeated imports remain truthful
- Stage 6 startup/picker refinement now also does all of the following:
  - first app open starts with no default sample video bound to preview or transport
  - the approved media picker now uses compact portrait thumbnail cards without per-item labels
  - picker cards keep a visible selection circle and still import through the approved button
  - the workspace canvas ratio is now locked by the first imported video only
  - later imported videos fit inside that locked canvas instead of redefining it
- Stage 6 timeline truth now also includes:
  - video playback is rebuilt from clip windows, not the full original source only
  - Stage 6 seam stabilization remains open as a focused transport slice
  - the current seam-recovery build implements the first two recovery phases:
    - Flutter-side `latest-wins` scrub dispatch for active scrubbing, so repeated drag updates do not queue unbounded `MethodChannel` seeks
    - native Android `one-seek-at-a-time` coalescing for multi-item timeline scrub, so repeated slow seam scrubs do not keep piling additional `player.seekTo(...)` requests while a previous scrub seek is still being processed
  - local verification for this seam-recovery build succeeded:
    - `flutter analyze --no-pub`
    - `./gradlew :app:assembleDebug`
  - the current device validation target for this build is now:
    - repeated slow scrub from `clip1 -> clip2`
    - repeated reverse scrub from `clip2 -> clip1`
    - confirming that live preview no longer degrades after several seam passes
  - latest user validation now accepts the current seam-recovery build as the active baseline:
    - multi-clip live scrub is now working well enough to preserve and continue from this version
    - the new coalescing path improved repeated seam scrubbing enough for the current acceptance threshold
    - this does not close `Stage 6`, but it closes the urgent seam-scrub blocker for the current saved snapshot
  - latest seam continuity recovery now also improves playback-through-cut on the same source:
    - adjacent segments from the same imported video are no longer limited to the earlier single-segment-only fast path
    - full-source clips are no longer forced through clipping configuration when clipping is not needed
    - latest user validation confirms a clearly improved same-source seam playback baseline for this saved version
  - split, trim, duplicate, reorder, and delete now resync native playback to the current video-track sequence
  - deleting a split segment closes the gap on the main video track instead of leaving playback bound to the removed source region
  - picker thumbnail requests now use higher-resolution device thumbnails for clearer image cards
- Stage 6 performance stabilization now also includes:
  - device-media queries and picker thumbnail extraction now run off the Android main thread
  - picker thumbnails now use native byte caching and smaller transfer sizes to reduce bottom-sheet scroll lag
  - the picker now warms thumbnails in background batches instead of firing one thumbnail RPC per visible card during scroll
  - Flutter bottom-sheet cards now render from a local thumbnail-bytes map instead of individual `FutureBuilder` thumbnail fetches
  - Android media queries and Android thumbnail generation now use separate executors so sheet opening and thumbnail warmup do not contend on the same worker pool
  - picker media loading is now paged instead of capped to the first `~60` device results
  - picker media lists now keep a stable `newest-first` order from the Android query itself, while Flutter appends later pages without reshuffling already-rendered cards
  - thumbnail arrivals now update per tile instead of triggering whole-sheet redraws after each batch
  - picker thumbnail requests now dedupe in-flight items and retry naturally when previously blank cards become visible again
  - picker warmup now targets page-entry and idle visible-window loading instead of repeatedly fighting active drag frames
  - the bottom sheet now opens at a fixed `~68%` height instead of starting short and stretching during browse
  - picker cards are now slightly smaller and visually lighter to reduce scroll jitter during browsing
  - when all timeline clip windows come from the same imported video, native playback now stays on one source and uses mapped clip windows instead of rebuilding a full `Media3` playlist on every edit
  - the single-source timeline fast path is intended to remove the black preview flashes and codec churn seen after repeated split/delete/trim operations
  - the timeline interaction contract now also has a safer contextual-edit baseline:
    - clip selection remains UI-only and does not rebind preview or transport by itself
    - edit icons remain visible in a fixed toolbar layout with no helper text
  - the current local editor-facing baseline now also includes:
    - Professional Motion text preset import through a dedicated `Text` bottom sheet
    - custom text preset JSON ingestion with project-owned validation and import normalization
    - text preview rendering on the canvas through the local motion runtime adapter
    - text clip modify flow through a dedicated edit bottom sheet
    - text transform overlay for direct move/scale editing on the canvas during active text edit
    - timeline text edit affordance through double-tap on the text layer
    - timeline trim mode gated behind one `Trim` tool instead of always-on trim chrome
    - timeline trim chrome with internal left/right handles and protected trim-only interaction mode
    - timeline ruler/header cleanup so the left time readout and ruler labels now come from one shared header rendering path
    - latest scrub refinement now moved closer to native ownership:
      - native live scrub now uses a latest-only seek queue during active scrubbing
      - scrub settle no longer waits on the earlier delayed handoff path
      - Flutter no longer predicts the final scrub frame optimistically before native settle confirms it
  - latest local validation snapshot:
    - `flutter analyze`
    - `./gradlew app:compileDebugKotlin`
    - `flutter build apk --debug`
    - latest debug APK reinstalled successfully on device `R3CT10LKLSX`
    - latest app launch confirmed on `com.refusion.app/.MainActivity`
    - edit icons stay disabled by default and activate only when a selected imported clip exists
    - split/trim validity is now enforced on action press instead of changing toolbar activation with playhead movement
- scrub regression fix now also includes:
  - timeline scrub dispatch has been restored to a `~16ms` Flutter cadence after the earlier `~32ms` slowdown regressed live preview feel
  - native scrubbing now keeps `EXACT` seek during drag for `sample`, `imported`, and `single-source timeline` paths so preview updates stay closer to the user’s hand movement
- preview cleanup now also includes:
  - the native preview surface no longer shows source/status chips over the video area
  - preview rounded corners are now subtle instead of large card-like radii
  - the empty preview state no longer draws placeholder art or a fake portrait canvas before the first import
- rebuilt and installed the new debug app on the physical Android device:
  - APK: `/Users/mx/Documents/InGeneBMFPro/sources/ui/fusionx-clean-ui-2/build/app/outputs/flutter-apk/app-debug.apk`
  - latest seam continuity validation build installed at `2026-04-06 17:05:32`
  - install target: `R3CT10LKLSX`
- user validation accepted the first Stage 6 import slice:
  - real video import works
  - playback works well
  - scrub works well
  - the remaining weakness is timeline interaction polish, not the import path itself
- opened the next Stage 6 slice:
  - `Timeline Interaction Contract`
  - reference: `/Users/mx/Documents/InGeneBMFPro/docs/process/stage-6-timeline-interaction-contract.md`
  - first implementation target:
    - selection becomes UI state only
    - selection no longer rebinds preview or transport
    - playback does not auto-select clips
  - current implementation in progress now also includes:
    - stronger visible selected-clip chrome in the timeline
    - contextual edit-tool activation for a selected imported clip
    - first core clip operations: `delete`, `duplicate`, `split`, `trim left`, `trim right`
  - latest physical-device follow-up now confirms:
    - scrub is working correctly again and is currently accepted
    - split/delete behavior looks generally natural enough for this slice
    - picker ordering and thumbnail fill are now much closer to the intended behavior
    - bottom-sheet scrolling improved through the latest picker-only passes, but smoothness still remains an open polish item
    - preview empty-state cleanup is now implemented so the canvas stays visually clean before the first import
  - the seam-scrub blocker has now been reduced from crash-risk to follow-up polish only for the accepted current baseline
  - the strongest official seam baseline now active in the app is:
    - Android `Media3 1.9.3`
    - app `minSdk 23`
    - native coalesced multi-item scrub handling on top of the official `1.9.x` scrub fixes

Stage 2 closure summary:

- detected only one connected Android target:
  - `emulator-5554`
- emulator-only evidence does not close `Stage 2`
- completed a preliminary adb-based native run using the Stage 1 binary and official test assets
- staged and ran:
  - `/Users/mx/Documents/InGeneBMFPro/sources/engine/bmf-official/bmf_lite/build_android_non_qnn_manual/bin/test_bmf_lite_android_interface`
  - `/Users/mx/Documents/InGeneBMFPro/assets/official/bmf_lite_release_files/bmf_lite_files/test.jpg`
  - `/Users/mx/Documents/InGeneBMFPro/assets/official/bmf_lite_release_files/bmf_lite_files/test-canny.png`
- preliminary emulator result:
  - `init result:-600`
  - `Segmentation fault`
  - exit code `139`
- captured emulator log evidence shows GL/program build failures before the crash:
  - `GL error 0x500`
  - `GL error 0x501`
  - `build_program error`
  - `sr.cpp, init, 304]compile program 0 error`
- physical-device validation then succeeded on:
  - serial: `R3CT10LKLSX`
  - model: `SM-S908N`
  - fingerprint: `samsung/b0qksx/b0q:16/BP2A.250605.031.A3/S908NKSS8GZB2:user/release-keys`
- successful physical-device execution output:
  - `test super_resolution start`
  - `init result:0`
  - `processVideoFrame result = 0`
  - `test super_resolution end`
  - `test denoise start`
  - `init result:0`
  - `processVideoFrame result = 0`
  - `test denoise end`
  - `EXIT_CODE=0`
- successful physical-device output files on device:
  - `backup.jpg`
  - `super_resolution.jpg`
  - `denoise.jpg`

Stage 3 closure summary:

- imported UI scope is documented
- mock-only areas are documented
- seeded default timeline clips are removed
- preview branding and fake playback copy are removed
- non-visual `Add` paths are disabled
- shell playback remains disabled until real transport integration exists
- the approved shell bottom sheet UX is in place for `Video` and `Image`

Stage 4 closure summary:

- ownership table is documented
- official-source-backed vs project-owned responsibilities are documented
- preview aspect-ratio ownership is explicitly defined
- timeline/playhead ownership is explicitly defined
- import ownership is explicitly defined
- hot reload policy is documented

Stage 1 closure summary:

- verified local prerequisites:
  - Android SDK CMake `3.22.1`
  - Android NDK `23.1.7779620`
  - Java `17`
- confirmed the official convenience Android paths were the source of the QNN blocker:
  - [build_android.sh](/Users/mx/Documents/InGeneBMFPro/sources/engine/bmf-official/bmf_lite/build_android.sh)
  - [android/lite/src/CMakeLists.txt](/Users/mx/Documents/InGeneBMFPro/sources/engine/bmf-official/bmf_lite/android/lite/src/CMakeLists.txt)
- adopted the source-default non-QNN path from the official BMFLite root CMake:
  - [CMakeLists.txt](/Users/mx/Documents/InGeneBMFPro/sources/engine/bmf-official/bmf_lite/CMakeLists.txt)
- successful Stage 1 configure command:
  - `cmake -S /Users/mx/Documents/InGeneBMFPro/sources/engine/bmf-official/bmf_lite -B /Users/mx/Documents/InGeneBMFPro/sources/engine/bmf-official/bmf_lite/build_android_non_qnn_manual -DCMAKE_BUILD_TYPE=Release -DANDROID_STL=c++_shared -DANDROID_ABI=arm64-v8a -DANDROID_PLATFORM=android-21 -DCMAKE_TOOLCHAIN_FILE=$HOME/Library/Android/sdk/ndk/23.1.7779620/build/cmake/android.toolchain.cmake -DBMF_LITE_ENABLE_OPENGLTEXTUREBUFFER=ON -DBMF_LITE_ENABLE_CPUMEMORYBUFFER=ON -DBMF_LITE_ENABLE_SUPER_RESOLUTION=ON -DBMF_LITE_ENABLE_DENOISE=ON`
- successful Stage 1 build command:
  - `cmake --build /Users/mx/Documents/InGeneBMFPro/sources/engine/bmf-official/bmf_lite/build_android_non_qnn_manual --parallel 16`
- confirmed cache values:
  - `BMF_LITE_ENABLE_TEX_GEN_PIC=OFF`
  - `BMF_LITE_ENABLE_OPENGLTEXTUREBUFFER=ON`
  - `BMF_LITE_ENABLE_CPUMEMORYBUFFER=ON`
  - `BMF_LITE_ENABLE_SUPER_RESOLUTION=ON`
  - `BMF_LITE_ENABLE_DENOISE=ON`

## Required Documents

- execution policy: [docs/process/execution-plan.md](/Users/mx/Documents/InGeneBMFPro/docs/process/execution-plan.md)
- Stage 1 native baseline build: [docs/process/stage-1-native-baseline-build.md](/Users/mx/Documents/InGeneBMFPro/docs/process/stage-1-native-baseline-build.md)
- Stage 2 native real-device validation: [docs/process/stage-2-native-real-device-validation.md](/Users/mx/Documents/InGeneBMFPro/docs/process/stage-2-native-real-device-validation.md)
- Stage 3 UI import and boundary lock: [docs/process/stage-3-ui-import-and-boundary-lock.md](/Users/mx/Documents/InGeneBMFPro/docs/process/stage-3-ui-import-and-boundary-lock.md)
- Stage 4 architecture lock: [docs/process/stage-4-architecture-lock.md](/Users/mx/Documents/InGeneBMFPro/docs/process/stage-4-architecture-lock.md)
- Stage 6 real import and timeline truth: [docs/process/stage-6-real-import-and-timeline-truth.md](/Users/mx/Documents/InGeneBMFPro/docs/process/stage-6-real-import-and-timeline-truth.md)
- Stage 6 timeline interaction contract: [docs/process/stage-6-timeline-interaction-contract.md](/Users/mx/Documents/InGeneBMFPro/docs/process/stage-6-timeline-interaction-contract.md)
- Stage 6 seam boundary stabilization: [docs/process/stage-6-seam-boundary-stabilization.md](/Users/mx/Documents/InGeneBMFPro/docs/process/stage-6-seam-boundary-stabilization.md)
- Stage 6 closure checklist: [docs/process/stage-6-closure-checklist.md](/Users/mx/Documents/InGeneBMFPro/docs/process/stage-6-closure-checklist.md)
- Future preview architecture - composition-based multi-clip evaluation (`future-gated reference only`): [docs/process/future-preview-architecture-composition-based-multi-clip-evaluation.md](/Users/mx/Documents/InGeneBMFPro/docs/process/future-preview-architecture-composition-based-multi-clip-evaluation.md)
- UI V1 requirements: [docs/process/ui-v1-requirements.md](/Users/mx/Documents/InGeneBMFPro/docs/process/ui-v1-requirements.md)
- official BMF baseline: [docs/research/bmf-official-baseline.md](/Users/mx/Documents/InGeneBMFPro/docs/research/bmf-official-baseline.md)
- UI baseline audit: [docs/research/ui-baseline-audit.md](/Users/mx/Documents/InGeneBMFPro/docs/research/ui-baseline-audit.md)
- community findings: [docs/research/community-findings.md](/Users/mx/Documents/InGeneBMFPro/docs/research/community-findings.md)
- source acquisition report: [docs/research/source-acquisition-report.md](/Users/mx/Documents/InGeneBMFPro/docs/research/source-acquisition-report.md)
- Stage 5 scrub investigation: [docs/research/stage-5-scrub-investigation.md](/Users/mx/Documents/InGeneBMFPro/docs/research/stage-5-scrub-investigation.md)
- BMF motion architecture feasibility: [docs/research/bmf-motion-architecture-feasibility.md](/Users/mx/Documents/InGeneBMFPro/docs/research/bmf-motion-architecture-feasibility.md)
- Professional Motion architecture reference: [docs/process/professional-motion-architecture.md](/Users/mx/Documents/InGeneBMFPro/docs/process/professional-motion-architecture.md)
- Professional Motion Part 1 - Canonical Scene / Layer / Element / Property Domain Models: [docs/process/professional-motion/professional-motion-part-1-canonical-scene-layer-element-property-domain-models.md](/Users/mx/Documents/InGeneBMFPro/docs/process/professional-motion/professional-motion-part-1-canonical-scene-layer-element-property-domain-models.md)
- Professional Motion Part 2 - Property Channels And First Keyframe Primitives: [docs/process/professional-motion/professional-motion-part-2-property-channels-and-first-keyframe-primitives.md](/Users/mx/Documents/InGeneBMFPro/docs/process/professional-motion/professional-motion-part-2-property-channels-and-first-keyframe-primitives.md)
- Professional Motion Part 3 - Normalized Motion Composition And Compile Boundary Foundations: [docs/process/professional-motion/professional-motion-part-3-normalized-motion-composition-and-compile-boundary-foundations.md](/Users/mx/Documents/InGeneBMFPro/docs/process/professional-motion/professional-motion-part-3-normalized-motion-composition-and-compile-boundary-foundations.md)
- Professional Motion Part 4 - Deterministic Runtime Evaluation Foundations: [docs/process/professional-motion/professional-motion-part-4-deterministic-runtime-evaluation-foundations.md](/Users/mx/Documents/InGeneBMFPro/docs/process/professional-motion/professional-motion-part-4-deterministic-runtime-evaluation-foundations.md)
- Professional Motion Part 5 - First Compile / Evaluation Helpers Without UI Binding: [docs/process/professional-motion/professional-motion-part-5-first-compile-evaluation-helpers-without-ui-binding.md](/Users/mx/Documents/InGeneBMFPro/docs/process/professional-motion/professional-motion-part-5-first-compile-evaluation-helpers-without-ui-binding.md)
- Professional Motion Part 6 - Transition / Effect / Camera Domain Foundations Without UI Binding: [docs/process/professional-motion/professional-motion-part-6-transition-effect-camera-domain-foundations-without-ui-binding.md](/Users/mx/Documents/InGeneBMFPro/docs/process/professional-motion/professional-motion-part-6-transition-effect-camera-domain-foundations-without-ui-binding.md)
- Professional Motion Part 7 - Text Animation And Text Preset Domain Foundations Without UI Binding: [docs/process/professional-motion/professional-motion-part-7-text-animation-and-text-preset-domain-foundations-without-ui-binding.md](/Users/mx/Documents/InGeneBMFPro/docs/process/professional-motion/professional-motion-part-7-text-animation-and-text-preset-domain-foundations-without-ui-binding.md)
- Professional Motion Part 8 - Text Preset Compile / Runtime Binding Without UI: [docs/process/professional-motion/professional-motion-part-8-text-preset-compile-runtime-binding-without-ui.md](/Users/mx/Documents/InGeneBMFPro/docs/process/professional-motion/professional-motion-part-8-text-preset-compile-runtime-binding-without-ui.md)
- Professional Motion Part 9 - Text Element Runtime Binding And Preview Hook Foundations Without UI: [docs/process/professional-motion/professional-motion-part-9-text-element-runtime-binding-and-preview-hook-foundations-without-ui.md](/Users/mx/Documents/InGeneBMFPro/docs/process/professional-motion/professional-motion-part-9-text-element-runtime-binding-and-preview-hook-foundations-without-ui.md)
- Professional Motion Part 10 - Text Element Insertion And Binding Foundations Without Bottom-Sheet UI Yet: [docs/process/professional-motion/professional-motion-part-10-text-element-insertion-and-binding-foundations-without-bottom-sheet-ui-yet.md](/Users/mx/Documents/InGeneBMFPro/docs/process/professional-motion/professional-motion-part-10-text-element-insertion-and-binding-foundations-without-bottom-sheet-ui-yet.md)
- Professional Motion Part 11 - Text Preview Renderer Hook Foundations Without Bottom-Sheet UI Yet: [docs/process/professional-motion/professional-motion-part-11-text-preview-renderer-hook-foundations-without-bottom-sheet-ui-yet.md](/Users/mx/Documents/InGeneBMFPro/docs/process/professional-motion/professional-motion-part-11-text-preview-renderer-hook-foundations-without-bottom-sheet-ui-yet.md)
- Professional Motion Part 12 - First User-Facing Text Preset Hookup: [docs/process/professional-motion/professional-motion-part-12-first-user-facing-text-preset-hookup.md](/Users/mx/Documents/InGeneBMFPro/docs/process/professional-motion/professional-motion-part-12-first-user-facing-text-preset-hookup.md)
- Professional Motion Part 13 - Custom Text Preset Import Foundations: [docs/process/professional-motion/professional-motion-part-13-custom-text-preset-import-foundations.md](/Users/mx/Documents/InGeneBMFPro/docs/process/professional-motion/professional-motion-part-13-custom-text-preset-import-foundations.md)
- Professional Motion Text Preset JSON Format: [docs/process/professional-motion/professional-motion-text-preset-json-format.md](/Users/mx/Documents/InGeneBMFPro/docs/process/professional-motion/professional-motion-text-preset-json-format.md)
- Professional Motion Text Preset Agent Guide: [docs/process/professional-motion/professional-motion-text-preset-agent-guide.md](/Users/mx/Documents/InGeneBMFPro/docs/process/professional-motion/professional-motion-text-preset-agent-guide.md)
- Professional Motion Text Preset Agent Contract: [docs/process/professional-motion/professional-motion-text-preset-agent-contract.md](/Users/mx/Documents/InGeneBMFPro/docs/process/professional-motion/professional-motion-text-preset-agent-contract.md)
- Professional Motion Text Modify V1: [docs/process/professional-motion/professional-motion-text-modify-v1.md](/Users/mx/Documents/InGeneBMFPro/docs/process/professional-motion/professional-motion-text-modify-v1.md)
- Stage 5B professional scrub upgrade: [docs/process/stage-5b-professional-scrub-upgrade.md](/Users/mx/Documents/InGeneBMFPro/docs/process/stage-5b-professional-scrub-upgrade.md)
- Stage 6 timeline precision and canonical time model: [docs/process/stage-6-timeline-precision-and-canonical-time-model.md](/Users/mx/Documents/InGeneBMFPro/docs/process/stage-6-timeline-precision-and-canonical-time-model.md)
- Stage 6 timeline precision gated execution plan: [docs/process/stage-6-timeline-precision-gated-execution-plan.md](/Users/mx/Documents/InGeneBMFPro/docs/process/stage-6-timeline-precision-gated-execution-plan.md)
- Stage 6 timeline precision baseline freeze: [docs/process/stage-6-timeline-precision-baseline-freeze.md](/Users/mx/Documents/InGeneBMFPro/docs/process/stage-6-timeline-precision-baseline-freeze.md)
- Stage 6 Step 7 precision validation matrix: [docs/process/stage-6-step-7-precision-validation-matrix.md](/Users/mx/Documents/InGeneBMFPro/docs/process/stage-6-step-7-precision-validation-matrix.md)
- Stage 6 foundation reference for future motion/script/export: [docs/process/stage-6-foundation-reference-canonical-timeline-truth-for-future-motion-script-export.md](/Users/mx/Documents/InGeneBMFPro/docs/process/stage-6-foundation-reference-canonical-timeline-truth-for-future-motion-script-export.md)

## Next Allowed Step

`Stage 6 - Real Import And Timeline Truth`

Single current goal:

- continue Stage 6 through the closure checklist without regressing the accepted timeline-precision baseline

Single next allowed step:

- keep the accepted precision baseline intact:
  - structural edit truth remains exact
  - visible cut placement remains exact
  - scrub baseline remains intact
  - accepted playback baseline remains intact
- return to:
  [docs/process/stage-6-closure-checklist.md](/Users/mx/Documents/InGeneBMFPro/docs/process/stage-6-closure-checklist.md)
- do not open export
- do not open motion/keyframe implementation
- do not reopen seam polish by breaking exact truth

Latest accepted precision milestone:

- `Step 7 - Precision Validation Matrix` is accepted on the physical device
- the timeline precision foundation is now treated as a protected baseline for all later Stage 6 work

## Approved Roadmap Queue

1. `Stage 6` next allowed step:
   preserve the accepted seam-recovery baseline and work through the Stage 6 closure checklist in order:
   `Preserve Track A -> Finish Track B -> Finish Track C`
2. only if step `1` succeeds:
   validate that the combined Stage 6 device pass succeeds without scrub/playback regression
3. only if step `2` succeeds:
   close `Stage 6` formally with updated documentation
4. only after `Stage 6` becomes stable:
   if a current-path seam ceiling was formally recorded, evaluate the future preview-architecture draft:
   [docs/process/future-preview-architecture-composition-based-multi-clip-evaluation.md](/Users/mx/Documents/InGeneBMFPro/docs/process/future-preview-architecture-composition-based-multi-clip-evaluation.md)
5. only after `Stage 6` becomes stable:
   open the future-gated export preparation stage draft:
   [docs/process/future-stage-7-export-contract-and-native-orchestration-baseline.md](/Users/mx/Documents/InGeneBMFPro/docs/process/future-stage-7-export-contract-and-native-orchestration-baseline.md)
6. only after the export baseline later becomes stable:
   resume the deferred research track:
   `Advanced Motion Authoring + Runtime Architecture`
   reference:
   [docs/research/bmf-motion-architecture-feasibility.md](/Users/mx/Documents/InGeneBMFPro/docs/research/bmf-motion-architecture-feasibility.md)

Guardrail:

- hot reload is allowed for Flutter-shell work once Stage 5 begins
- native Android, platform-channel, C++ bridge, and BMFLite changes still require rebuild/redeploy when touched
- real import, real playback, and integration must follow the Stage 4 ownership lock

## README Update Contract

After each important milestone this file must be updated with:

- current stage name
- `OPEN` or `CLOSED`
- what was completed in the stage
- the single remaining blocker if still open
- the single next allowed step
- artifact paths if any exist
- real-device result if a stage requires device validation
