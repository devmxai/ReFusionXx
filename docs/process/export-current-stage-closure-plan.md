# Export Current-Stage Closure Plan

Last updated: April 10, 2026

## Why This Document Exists

This document is the operational close-out plan for the **current export stage**.

It is intentionally narrower than:

- [Professional Export System Plan](/Users/mx/Documents/InGeneBMFPro/docs/process/professional-export-system-plan.md)
- [Professional Effects Render And Export Plan](/Users/mx/Documents/InGeneBMFPro/docs/process/professional-effects-render-and-export-plan.md)

The professional plan remains the long-term architecture reference.
This document defines the smaller, stricter subset of work that must be finished
to say:

- the current export file can be closed for now
- the current export lane is accepted for day-to-day product use
- the remaining long-term export architecture can move to a later generation

## Current Reviewed State

After reviewing the current code and latest device checkpoints, the export stack
is in this state:

- export now produces a real media file through `Media3 Transformer`
- real output metadata is readable on device
- trim, order, preset sizing, constant-speed export, and file handoff are live
- text ghosting caused by `CanvasOverlay` frame reuse has been fixed
- export now carries explicit output FPS through the native path
- native export now uses a bitrate ladder and encoder capability gate
- baseline false blockers around generated text-track clips have been removed
- April 10 device evidence shows `video + slow motion + text motion` can export
  on `30fps`, but the actual output video stream may still be about `8fps`
  because the current Media3 `setSpeed(...)` lane does not synthesize
  intermediate video frames; authored text motion attached through
  `CanvasOverlay` is therefore evaluated only at the sparse output frame
  cadence

At the same time, the export stack is **not yet closed** as a current-stage file
because the following are still open:

- text motion smoothness is improved but not yet accepted as professional-grade
- `slow motion + authored animation` is not accepted yet as professional-grade
  because the narrow independent overlay-clock repair is not yet a generalized
  accepted compositor/effects lane
- typography and interpolation parity are still not accepted
- runtime validation and diagnostics still need one stable accepted pass on device
- the export code is still too monolithic for safe maintenance

## Current Code Reality

The export system is now materially functional, but the codebase still carries
heavy consolidation debt:

- [Stage6ExportManager.kt](/Users/mx/Documents/InGeneBMFPro/sources/ui/fusionx-clean-ui-2/android/app/src/main/kotlin/com/fusionx/fusionx_clean_ui_2/Stage6ExportManager.kt): about `5959` lines
- [fusionx_clean_ui_screen.dart](/Users/mx/Documents/InGeneBMFPro/sources/ui/fusionx-clean-ui-2/lib/features/editor/presentation/screens/fusionx_clean_ui_screen.dart): about `4545` lines
- [export_composition_models.dart](/Users/mx/Documents/InGeneBMFPro/sources/ui/fusionx-clean-ui-2/lib/features/editor/domain/models/export_composition_models.dart): about `4193` lines
- [export_bottom_sheet.dart](/Users/mx/Documents/InGeneBMFPro/sources/ui/fusionx-clean-ui-2/lib/features/editor/presentation/widgets/export_bottom_sheet.dart): about `1048` lines
- [stage6_export_controller.dart](/Users/mx/Documents/InGeneBMFPro/sources/ui/fusionx-clean-ui-2/lib/core/engine/stage6_export_controller.dart): about `1024` lines

That is acceptable for an active build-out phase, but not acceptable as a clean
closed export file.

## Closure Rule

The export file can be closed for the current stage only when **all** of the
following are true:

1. Export succeeds on device for the accepted current scope without false
   blockers or false validation failures.
2. Text motion no longer shows major visible corruption such as ghosting,
   frozen trails, first-second-only motion, or obvious typography collapse.
3. Export diagnostics are honest and actionable when a job fails.
4. FPS and encoder choices are real, capability-aware, and visible in runtime
   diagnostics.
5. The current export code is cleaned enough that further feature work will not
   depend on one giant unsafe file per layer.

## Accepted Scope For Current Closure

The current-stage export file should be closed against this accepted scope:

- single visual media lane
- optional single audio lane
- real file output through `Media3 Transformer`
- preset ladder currently used by the export sheet
- constant speed clips that are already admitted by the current route
- authored motion text through the current deterministic export program path
- export FPS selection through the current native encoder path
- working output handoff:
  - open
  - share
  - save to gallery

## Explicitly Deferred From Current Closure

The following items are **not required** to close the current export file now.
They remain future work under the larger professional export architecture:

- full audio graph and multi-layer audio mix engine
- full effects parity
- full transitions parity
- full camera parity
- full multi-visual compositor parity beyond the currently supported slice
- full curve speed and time-remap parity
- final backend decision gate for advanced export beyond the current Media3 lane
- production stress profiling across very large projects

These remain important, but they must not block closure of the current export
file unless the accepted current scope is broken.

## April 10 Smoothness Finding

Real-device export evidence:

- latest accepted `30fps` export with `video + slow motion + text motion`:
  - output file was produced
  - output video stream reported roughly `8fps`
  - text motion was therefore visibly stepped even though the export setting
    was `30fps`
- follow-up stable-path exports after removing the failed `TimestampAdjustment`
  attempt showed:
  - `video + text motion` requested at `30fps` produced an actual `24fps` stream
  - `video + text motion` requested at `90fps` also produced an actual `24fps`
    stream
  - `video + slow motion + text motion` requested at `30fps` produced `130`
    video frames over roughly `13.36s`, which is about `9.7fps`
  - this exactly matches the reported stepped/choppy text motion in the slow
    motion case

Technical conclusion:

- `EditedMediaItem.Builder.setFrameRate(...)` is not a frame generator for
  normal video input; for video sources it behaves as a maximum output frame
  rate rather than creating missing intermediate frames
- `EditedMediaItem.Builder.setSpeed(...)` is still the official Media3 lane for
  constant media speed, but it does not by itself provide authored overlay frame
  interpolation
- `CanvasOverlay` is evaluated with the current frame `presentationTimeUs`, so
  text/image/shape animation tied to the same slowed media item is limited by
  the sparse frames that reach the overlay
- the current FPS selector changes requested encoder settings and bitrate
  planning, but does not force constant-output-frame generation for slowed media

Required correction:

- the current export closure cannot rely on FPS selection alone for authored
  motion smoothness
- the current narrow independent overlay-clock repair must either:
  - be generalized into a supported authored compositor/effects lane
  - or be replaced by a validated `Media3 GL` / compositor-backed lane
- until that happens, `slow motion + authored animation` must not be marked
  closed or professional-grade even if the file exports successfully

April 10 failed implementation checkpoint:

- a first attempt added a fixed-cadence `TimestampAdjustment` pass before
  `OverlayEffect` when authored overlays were rendered over video
- real-device testing rejected this attempt: `video + text motion` at `30fps`
  failed with Media3 `ERROR_CODE_MUXING_TIMEOUT`, and the muxer watchdog reported
  that no output sample was written for `10000ms`
- the failing attempt has been removed from the production export path so the
  accepted `video + text motion` baseline is not broken
- high-FPS authored export is no longer blocked by the old current-stage
  authored-motion gate; the remaining gate is the real encoder capability check
- fixed-cadence authored motion still requires a safer implementation path,
  likely a separate authored/compositor pass or a validated Media3 custom effect
  that does not starve the muxer

April 10 narrow repair checkpoint:

- a narrower repair path is now implemented in
  [Stage6ExportManager.kt](/Users/mx/Documents/InGeneBMFPro/sources/ui/fusionx-clean-ui-2/android/app/src/main/kotlin/com/fusionx/fusionx_clean_ui_2/Stage6ExportManager.kt)
  to break the direct clock coupling between slowed media and motion text
- instead of attaching motion text only to the slowed `EditedMediaItem`, the
  native export path can now build:
  - a media base sequence that still owns trim and `setSpeed(...)`
  - and a transparent-image overlay sequence that owns motion-text rendering on
    the export timeline clock
- the transparent overlay sequence is currently created from a cached
  `transparent-<width>x<height>.png` asset in the app cache directory and is
  given:
  - explicit image mime type
  - explicit `MediaItem.Builder.setImageDurationMs(...)`
  - explicit `EditedMediaItem.Builder.setFrameRate(...)`
- this path is intentionally narrow:
  - it is a current-stage motion-text repair slice
  - it is not yet the final full canonical compositor generation promised by the
    long-term professional export plan

April 10 asset-loader blocker and fix:

- the first build of the independent motion-text overlay sequence failed
  immediately on device with:
  - `ERROR_CODE_FAILED_RUNTIME_CHECK`
  - `ExportException: Asset loader error`
  - `IllegalStateException: The asset loader has no audio or video track to output. Try setting an image duration on input image MediaItems.`
- root cause:
  - the transparent PNG overlay asset was passed into Media3 as an image input
    without `MediaItem.Builder.setImageDurationMs(...)`
  - Media3 therefore rejected the item before export actually started
- corrective action:
  - the transparent overlay `MediaItem` now sets:
    - `MimeTypes.IMAGE_PNG`
    - `setImageDurationMs(durationMs)`
- latest installed build after the fix:
  - package `com.fusionx.fusionx_clean_ui_2`
  - device `lastUpdateTime = 2026-04-10 05:44:38`

Current documented status after the fix:

- the immediate `asset loader error` blocker introduced by the new overlay path
  is resolved
- export has moved from "architectural plan only" to "narrow independent
  authored overlay clock implemented in native export"
- the export file is still **not closed**
- remaining acceptance still depends on:
  - real-device confirmation that the new path keeps speed isolated to the media
    clip instead of affecting motion text timing
  - real-device confirmation of smoothness and quality at accepted FPS settings
  - broader cleanup and generalization beyond the current narrow transparent
    overlay sequence implementation

April 10 urgent blur-parity blocker:

- real-device review has now identified another important current-stage blocker:
  blur-heavy motion-text presets can look correct in preview but lose their
  real blur character after export
- current verified root cause:
  - preview renders blur through Flutter
    `ImageFiltered(imageFilter: ui.ImageFilter.blur(...))`
  - export no longer treats raw `BlurMaskFilter(...)` as the primary truth path
  - export now uses a contract-driven premultiplied bitmap Gaussian first path
    for supported motion-text blur, with `BlurMaskFilter(...)` retained only as
    fallback
- consequence:
  - export blur is still not yet an accepted final GL/compositor blur lane
  - on device it can still visually collapse into:
    - softened white
    - opacity-like fading
    - edge darkening
    - border/fringe artifacts
    - much weaker blur than the preview shows
- important judgment:
  - this is not a minor preset-tuning issue
  - it is another renderer-parity problem between preview and export
  - blur must remain in the current-stage blocker list until the export blur
    model matches preview semantics closely enough on device
- required acceptance test later:
  - choose a motion-text preset with intentionally strong blur presence
  - verify preview blur visually
  - export at accepted FPS settings
  - compare whether the blurred halo/diffusion remains present after export
  - reject current-stage visual acceptance if the result still looks like
    simple opacity softening instead of real blur

## Required Remaining Work

### Workstream 1: Stabilize Accepted Export Runtime

Goal:

- make the currently accepted export lane stable and trustworthy on device

Required work:

- finish runtime duration-truth stabilization
- finish validation truth so the failure reason always matches the actual cause
- keep preflight honest:
  - unsupported cases must stop before export starts
  - supported cases must not be blocked by stale diagnostics
- confirm that expected duration, actual duration, resolution, FPS, and codec
  reporting are sourced from the real execution path

Exit criteria:

- no false blocker in accepted current-scope projects
- no false validation failure in accepted current-scope projects
- failure cards always show real values, not placeholder or stale values

Current implementation checkpoint:

- export runtime now separates:
  - `execution duration`
  - and `timeline duration`
- native validation now compares the output file against execution truth first,
  while still surfacing timeline duration as additional diagnostics when it
  differs
- export session diagnostics are now expected to expose both values honestly
  instead of collapsing them into one ambiguous target duration

### Workstream 2: Text Motion Acceptance Hardening

Goal:

- raise text motion from "working path" to "accepted current-stage quality"

Required work:

- keep deterministic motion-text program as the only authoritative text-motion
  truth for export
- keep the new independent motion-text overlay clock path documented as a
  narrow current-stage implementation, not as full compositor parity
- finish parity cleanup for:
  - typography
  - interpolation
  - blur semantics
  - layout anchoring
  - letter-spacing stability
  - reveal timing
- keep `motionTextRenderTrack` isolated as fallback/debug material only
- verify that exported motion text no longer exhibits:
  - ghost trails
  - first-second-only motion
  - frozen frame stacking
  - severe typography collapse
  - preview-visible blur disappearing or collapsing into opacity-like softening
- fix measured text-layout consistency between fill and blur rendering so
  `lineHeight` and alignment are not mismatched
- generalize the narrow independent overlay-clock repair into an accepted
  authored visual lane for text, image, and shape animation over slowed or
  sped media
- confirm on device that the new transparent-image overlay sequence truly keeps
  speed isolated to the media clip and does not reintroduce `asset loader`
  regressions
- define an honest acceptance threshold:
  - accepted current-stage quality
  - not full preview-perfect parity claim

Exit criteria:

- current motion-text presets export without obvious visual corruption
- movement remains readable and continuous at accepted FPS settings, including
  the `slow motion + text motion` accepted case
- remaining gaps are documented as limitations, not hidden

### Workstream 3: FPS And Encoder Quality Closure

Goal:

- make FPS selection and quality policy real, documented, and testable

Required work:

- keep `30 / 60 / 90 / 120` as true export settings, not UI-only labels
- validate device capability gating for unsupported H.264 size/rate profiles
- verify bitrate ladder behavior per preset and FPS
- surface:
  - selected FPS
  - actual FPS
  - video bitrate
  - audio bitrate
  - encoder name
- confirm that higher FPS improves authored overlay smoothness where the source
  media path allows it, without pretending it creates detail that the source
  does not contain
- keep the UI honest that `60/90/120fps` authored motion is accepted only when
  the authored visual lane and the real device encoder capability gate both pass

Exit criteria:

- FPS selection is real end-to-end
- unsupported profiles fail early and honestly
- supported profiles export successfully with clear diagnostics
- selected FPS and actual exported stream cadence are reported side by side

### Workstream 4: Code Cleanup And Ownership Split

Goal:

- reduce export maintenance risk before calling the file closed

Required cleanup:

- split [Stage6ExportManager.kt](/Users/mx/Documents/InGeneBMFPro/sources/ui/fusionx-clean-ui-2/android/app/src/main/kotlin/com/fusionx/fusionx_clean_ui_2/Stage6ExportManager.kt) into clear ownership units:
  - preflight and bridge parsing
  - visual assembly and compositor routing
  - motion-text renderer
  - encoder plan and Transformer runner
  - output validation and diagnostics
- split [export_composition_models.dart](/Users/mx/Documents/InGeneBMFPro/sources/ui/fusionx-clean-ui-2/lib/features/editor/domain/models/export_composition_models.dart) into:
  - graph schema and capability contracts
  - visual compositor graph
  - motion-text export program bridge
  - blocker and limitation messaging
- split [stage6_export_controller.dart](/Users/mx/Documents/InGeneBMFPro/sources/ui/fusionx-clean-ui-2/lib/core/engine/stage6_export_controller.dart) into:
  - state models
  - event normalization
  - bridge client
- split [export_bottom_sheet.dart](/Users/mx/Documents/InGeneBMFPro/sources/ui/fusionx-clean-ui-2/lib/features/editor/presentation/widgets/export_bottom_sheet.dart) into:
  - settings
  - runtime progress
  - diagnostics cards

Exit criteria:

- no single export file remains an unbounded "god file"
- export ownership is readable by subsystem
- failure fixing no longer requires touching every export layer at once

### Workstream 5: Device Acceptance And Closure Review

Goal:

- finish the current export file with evidence, not optimism

Required matrix:

- video only
- video + audio
- video + motion text
- video + slow motion + motion text
- video + fast motion + motion text
- video + blur-heavy motion-text preset
- 720p / 1080p / Original
- 30fps accepted path
- 60fps or higher only after the authored visual lane and encoder capability
  gate pass on device
- success path
- cancel path
- failure path
- open/share/save handoff

Required closure review:

- update export documentation to match the final accepted current scope
- keep deferred items explicitly deferred
- remove any claims that overstate parity

Exit criteria:

- accepted-scope matrix passes on device
- documentation matches actual product behavior
- export file can be marked closed for the current stage

## Strict Execution Order

The current closure plan must be executed in this order:

1. `Workstream 1` - runtime and validation stabilization
2. `Workstream 2` - text motion acceptance hardening
3. `Workstream 3` - FPS and encoder quality closure
4. `Workstream 4` - code cleanup and ownership split
5. `Workstream 5` - device acceptance and closure review

No new export feature branch should jump ahead of this order.

## What Counts As "Closed For Now"

The export file is closed for the current stage when:

- the accepted current scope exports successfully on device
- the text motion lane is accepted as stable and usable
- diagnostics are honest
- FPS and encoder settings are real and documented
- the export code is cleaned enough for safe future maintenance
- deferred future-generation items are explicitly documented and not confused
  with the current close-out target

## Parent Reference

This closure plan is a controlled subset of:

- [Professional Export System Plan](/Users/mx/Documents/InGeneBMFPro/docs/process/professional-export-system-plan.md)

Use this document to close the current export file.
Use the professional export plan to continue the next export generation later.
