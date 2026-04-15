# Live Scrub to PRO Documentation

## Purpose

This document records the live scrub migration from the original transport-backed,
player-coupled preview model to the current PRO-oriented native scrub architecture.
It is the historical and technical reference for what was changed, why it was changed,
what was deleted, what remains incomplete, and what rules are now mandatory for any
future work on scrub behavior.

This document is intentionally broader than the binding mandate in
`docs/live_scrub_migration_mandate.md`.
The mandate defines the target architecture.
This document explains the migration story from the original implementation to the
current build state.

## Mandatory Rule

The live scrub migration is governed by a non-negotiable rule:

- No future scrub work may reintroduce ExoPlayer into the active per-frame live scrub path.
- No future scrub work may reintroduce Flutter-side per-frame image transport for live scrub.
- No hybrid workaround is allowed if it violates the migration mandate.
- Any future implementation change must continue from the mandated architecture rather than
  branching into a separate individual workaround.

This is an explicit architectural constraint, not an optimization preference.

## Original Problem

The original live scrub behavior was built around the transport/player path:

- Flutter timeline gestures emitted scrub updates.
- Those updates eventually drove transport-backed scrub behavior.
- ExoPlayer and transport-backed exact/coalesced seek logic were still involved in the
  scrub lifecycle.
- Multiple generations of fallback logic were layered on top:
  transport seek preview, proxy preview attempts, Flutter-side dispatch loops,
  texture sessions, and direct decode experiments.

This caused the class of failures that repeatedly appeared during development:

- visible latency between finger motion and displayed frame
- reverse scrub instability
- frame snapping only on release
- black flashes during scrub handoff
- race conditions between scrub sessions
- player lifecycle contamination of the scrub path
- architectural confusion caused by hybrid display pipelines

## Migration Summary

The migration progressed through several stages.

### Stage 0: Transport-Backed Scrub

Initial behavior was centered on transport/player ownership:

- scrub lifecycle flowed through transport `setScrubbing(...)`
- player and transport still owned active scrub state
- legacy seek-coalescing behavior remained in the path
- Flutter was in the hot path for scrub updates

This architecture proved unsuitable for PRO-grade scrub precision.

### Stage 1: Direct Preview Experiments

Several intermediate experiments were built to try to reduce latency:

- proxy preview dispatch
- Flutter texture overlays
- direct native decode sessions
- latest-wins request loops
- independent scrub texture sessions

These experiments provided useful findings but did not solve the root problem because the
system remained partly hybrid:

- session lifecycle still leaked through transport
- player ownership was not fully removed
- render visibility and handoff were unstable
- per-frame dispatch still depended on Flutter and MethodChannel traffic

### Stage 2: Architectural Lock

The migration was formally locked by documentation:

- `docs/live_scrub_architecture.md` was marked as superseded for the old transport-backed path
- `docs/live_scrub_migration_mandate.md` was created as the binding directive

This established the rule that future scrub work must follow the target architecture:

1. pre-extracted indexed scrub frames
2. dedicated native scrub render surface
3. native touch hot path
4. ExoPlayer only for final settle/playback

### Stage 3: Frame Extraction Pipeline

The first real foundation layer was introduced:

- `Stage5ScrubFrameExtractor.kt`
- `Stage5ScrubFrameStore.kt`
- `Stage5ScrubPreparationManager.kt`

This layer changed the model from "decode on demand during scrub" to
"prepare scrub frames ahead of time and look them up by index".

Core characteristics:

- extraction runs in the background
- import is not blocked by extraction
- frames are downscaled to preview size
- indexed lookup is O(1) by frame index
- short clips can use memory-tier storage
- longer clips can use disk-tier storage
- every clip now has scrub readiness metadata

This was the first true step toward removing decode cost from the active scrub path.

### Stage 4: Native Render Ownership

The render surface moved into the native preview container:

- `Stage5ScrubOverlayTextureView.kt`
- `Stage5ScrubRenderHost.kt`
- `Stage5PreviewPlatformView.kt`
- `Stage5PreviewPlatformViewFactory.kt`
- `Stage5NativeScrubEngine.kt`

This changed the display model from Flutter-owned per-frame preview presentation to
native-owned stacked preview rendering.

Key result:

- scrub frames are now drawn by native code inside the preview platform view
- the preview surface can sit above the player surface
- Flutter no longer needs to receive frame bytes to display them

### Stage 5: Removal of the Old Direct Decode Path

The transitional live decoder/Flutter texture bridge was removed:

- `Stage5LiveScrubDecoderSession.kt` was deleted
- `Stage5ScrubPreviewTextureManager.kt` was deleted

This removed an entire path that was no longer compatible with the mandated architecture.

### Stage 6: Session Lifecycle Separation

The live scrub pipeline was updated so that scrub sessions no longer drive transport
scrub mode during active scrub:

- `TransportBackedScrubPreviewController` became a no-op for active scrub frames
- `LiveScrubPipeline.beginSession(...)` now pauses playback but does not enter transport
  scrub mode
- `LiveScrubPipeline.endSession(...)` now performs the final exact seek only

This is a major architectural boundary:

- ExoPlayer is no longer in the active per-frame path
- transport-backed scrub mode is no longer the owner of active scrub session lifecycle
- the only player participation that remains in this path is final settle

### Stage 7: Frame Store Tightening Toward PRO Lookup

The frame store was improved to move closer to a real `frames[index]` model:

- memory-tier storage now retains `Bitmap` frames directly
- disk-tier storage stores JPEG files and caches decoded bitmaps in a small `LruCache`
- the native scrub engine now reads `Bitmap` frames from the store directly
  instead of decoding JPEG byte arrays on every update

This is not the final zero-allocation hot path yet, but it is a meaningful move away from
decode-per-update behavior.

## Current Architecture

At the time of writing, the current architecture is:

### Playback

- ExoPlayer still owns normal playback
- ExoPlayer still owns exact final settle after scrub end
- ExoPlayer still powers the preview surface during non-scrub playback

### Active Scrub

- active scrub rendering uses pre-extracted frames from `Stage5ScrubFrameStore`
- frames are displayed by the native scrub surface hosted by the preview platform view
- Flutter no longer displays live scrub frames via `Image.memory`
- the old direct live decoder path is gone
- the old transport-backed per-frame player seek path is removed from `LiveScrubPipeline`

### Scrub Readiness

- every relevant asset may carry scrub store readiness state
- readiness is surfaced into editor asset metadata and live scrub source descriptors
- extraction continues in the background after import

## Current Build State: 2026-04-15 Main Handoff

This section documents the exact state being pushed to the official `main`
branch for external review.

The current build is not considered PRO-complete. It contains the migration
foundation and several hardening passes, but user testing still reports the
following failure:

- during active live scrub, the first movement may advance only one frame or a
  very small amount
- after that first movement, the playhead and timeline can feel heavy or stuck
- the preview can behave as if only one frame was loaded rather than tracking
  the finger continuously
- the issue appears unchanged after the latest hot-path hardening patch

### What Was Migrated Successfully

The current code has moved substantial parts of live scrub away from the old
player-coupled path:

- `LiveScrubPipeline` no longer uses the transport/player path to present
  active scrub frames.
- `Stage5ScrubFrameStore` provides indexed frame storage for scrub preview.
- `Stage5ScrubPreparationManager` owns background window extraction requests.
- `Stage5NativeScrubEngine` owns native scrub-session state and render-loop
  scheduling.
- `Stage5PreviewPlatformView` hosts a native scrub overlay above the player
  surface.
- `Stage5ScrubOverlayTextureView` draws scrub frames natively instead of
  sending frame bytes through Flutter.

This means the architecture has moved away from `Flutter image bytes` and away
from using `ExoPlayer.seekTo()` as the per-frame live scrub display mechanism.

### What Is Still Not Complete

The current build still has the following architectural gaps:

- active touch-move still originates in Flutter timeline gesture handling
- each target update still crosses a `MethodChannel`
- the frame extractor still uses `MediaMetadataRetriever` against the current
  source URI rather than a real low-GOP proxy file
- the hot path is not yet true native touch capture
- the scrub render engine is native, but the input cadence is still driven by
  Flutter timeline updates
- readiness gating and extraction windows exist, but they are not enough to
  guarantee continuous response for every video and every position

These gaps explain why the build can still feel heavy even after ExoPlayer was
removed from the active display path.

### Latest Hot-Path Hardening Patch

The latest patch attempted to remove synchronous work from the MethodChannel
touch path:

- `Stage5NativeScrubEngine.beginSession(...)` and `updateTarget(...)` now record
  the latest target and schedule a render loop instead of synchronously decoding
  and drawing before returning to Flutter.
- extraction requests are de-duplicated by store key and frame index so the
  render retry loop does not repeatedly reschedule the same target.
- bitmap lookup/disk decode is no longer performed while holding the scrub
  engine monitor.
- `Stage5PreviewPlatformView.presentScrubFrame(...)` now draws the frame before
  posting only the visibility switch to the UI thread.
- the scrub overlay clears with transparent mode instead of filling black.
- disk decoded frame cache was increased to reduce repeated JPEG decode churn.

This patch was validated with:

- `flutter analyze`
- `./gradlew :app:compileDebugKotlin`
- `flutter build apk --debug`
- installation on device `R3CT10LKLSX`

User verification after installation still reported no visible improvement, so
this patch should be treated as a diagnostic hardening step, not as the final
fix.

### Current Root-Cause Hypothesis

The strongest current hypothesis is that the remaining freeze is caused by the
fact that the hot path is still not native end-to-end:

1. Flutter timeline gesture handling computes scrub time.
2. Flutter updates timeline display state.
3. Flutter calls `renderScrubPreviewTextureFrame(...)` over `MethodChannel`.
4. Native records the target and asynchronously tries to extract or render.
5. If frames are not already available, the visual output cannot keep up with
   finger movement.

Even if the native renderer is asynchronous, Flutter remains the owner of
per-frame input cadence. That still allows UI rebuild pressure, MethodChannel
backpressure, frame-store misses, or extraction latency to make scrub feel like
it only moved once and then stalled.

### Required Next Direction

The next architectural step should not be another Flutter-side coalescing or
throttling patch. The next real migration step is:

- implement native touch capture for active scrub
- compute frame index from touch position natively
- request/present frames from native without per-frame Flutter calls
- notify Flutter only for scrub start and scrub end

Until native touch capture is complete, the migration should be considered
partially complete and still vulnerable to the exact symptom currently reported.

## What Has Been Deleted or Neutralized

The migration has already removed or neutralized the following:

- Flutter `Image.memory` live scrub frame display path
- old direct decoder session based scrub path
- old scrub preview texture manager bridge
- transport/player participation in `LiveScrubPipeline.presentFrame(...)`
- transport/player ownership of active scrub begin/end inside the pipeline

The following legacy pieces still exist in the codebase but are now architectural debt
to be removed in the next migration phase:

- Flutter-side per-frame scrub dispatch loop
- Flutter-side timeline-driven hot path for active scrub updates
- MethodChannel per-frame update calls during active scrub
- transport-backed scrub-specific state in `Stage5TransportManager`
- legacy scrub state fields that still exist for compatibility with older code paths

## What Still Remains Before the PRO Target Is Complete

The migration is not finished yet.

The remaining work is now concentrated in one clear area:

### 1. Native Touch Hot Path

The current scrub still depends on Flutter timeline gesture updates.
This means:

- touch-move is still crossing the Flutter boundary
- MethodChannel per-frame update traffic still exists
- UI/timeline coupling can still introduce jitter

The next strict step is:

- capture scrub touch in native code
- compute frame index in native code
- draw directly in native code
- notify Flutter only on scrub start and scrub end

### 2. Full Deletion of Hybrid Scrub Dispatch

The current `_dispatchProxyScrubPreview(...)` and related Flutter dispatch logic still exist.
These must be deleted once native touch capture is live.

### 3. Handoff Finalization

The final settle path still needs the fully clean surface handoff sequence:

- scrub surface remains visible until player reports first rendered frame after settle
- then player surface returns
- then scrub surface hides

This must happen with no black frame and no visible swap.

### 4. PRO-Grade Hot Path Tightening

The frame store is improved, but still not fully final:

- disk-tier reads still decode from file on first access
- native draw path still uses bitmap retrieval per update
- further zero-allocation and reuse work is still possible

This is acceptable as an intermediate step, but not yet the absolute final PRO endpoint.

## Files Introduced for the Migration

Core migration files added in this phase:

- `android/app/src/main/kotlin/com/fusionx/fusionx_clean_ui_2/Stage5ScrubFrameStore.kt`
- `android/app/src/main/kotlin/com/fusionx/fusionx_clean_ui_2/Stage5ScrubFrameExtractor.kt`
- `android/app/src/main/kotlin/com/fusionx/fusionx_clean_ui_2/Stage5ScrubPreparationManager.kt`
- `android/app/src/main/kotlin/com/fusionx/fusionx_clean_ui_2/Stage5NativeScrubEngine.kt`
- `android/app/src/main/kotlin/com/fusionx/fusionx_clean_ui_2/Stage5ScrubRenderHost.kt`
- `android/app/src/main/kotlin/com/fusionx/fusionx_clean_ui_2/Stage5ScrubOverlayTextureView.kt`
- `docs/live_scrub_migration_mandate.md`

Core migration files substantially rewritten:

- `android/app/src/main/kotlin/com/fusionx/fusionx_clean_ui_2/MainActivity.kt`
- `android/app/src/main/kotlin/com/fusionx/fusionx_clean_ui_2/Stage5PreviewPlatformView.kt`
- `android/app/src/main/kotlin/com/fusionx/fusionx_clean_ui_2/Stage5PreviewPlatformViewFactory.kt`
- `lib/core/engine/live_scrub_pipeline.dart`
- `lib/core/engine/live_scrub_preview_sources.dart`
- `lib/core/engine/stage5_native_transport_controller.dart`
- `lib/features/editor/presentation/models/editor_asset_item.dart`
- `lib/features/editor/presentation/screens/fusionx_clean_ui_screen.dart`

Files removed because they no longer fit the target architecture:

- `android/app/src/main/kotlin/com/fusionx/fusionx_clean_ui_2/Stage5LiveScrubDecoderSession.kt`
- `android/app/src/main/kotlin/com/fusionx/fusionx_clean_ui_2/Stage5ScrubPreviewTextureManager.kt`

## Validation Performed So Far

The migration has been repeatedly validated with:

- `flutter analyze`
- `./android/gradlew :app:compileDebugKotlin`
- `flutter build apk --debug`
- real-device install and manual scrub checks

These validations confirm build integrity and progressive architectural migration,
but they do not yet certify completion of the full mandate.

The migration is only complete when the binary success criteria in
`docs/live_scrub_migration_mandate.md` are satisfied in full.

## Current Honest Status

This is the exact current status:

- The project has already moved away from the old transport/player-per-frame scrub model.
- The project now has a real frame extraction foundation.
- The project now has a native render surface in the preview stack.
- The project now has a scrub engine that reads from the extracted frame store.
- The project has removed the old direct decoder path.
- The project has removed transport/player from active per-frame scrub in the pipeline.

But:

- Flutter is still involved in active scrub event dispatch.
- Native touch capture is not finished yet.
- Per-frame MethodChannel calls still exist.
- Final handoff polish is not fully completed.

So the correct judgment is:

The migration is no longer conceptual.
It is now in a real advanced implementation state.
However, it is not yet the final PRO-complete architecture.

## Next Strict Step

The next strict architectural step is:

1. move timeline/playhead scrub touch capture to native
2. compute frame index natively
3. draw frames natively without per-frame Flutter participation
4. keep Flutter informed only of scrub start and scrub end
5. remove the remaining Flutter scrub dispatch loop

That is the remaining turning point from "advanced hybrid migration" to
"fully compliant Live Scrub PRO architecture".
