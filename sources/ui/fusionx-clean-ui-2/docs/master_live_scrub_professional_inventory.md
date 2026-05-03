# Master Live Scrub Professional Inventory

Status: Phase 0 inventory (documentation only)  
Plan: `docs/master_live_scrub_professional_plan.md`  
Date: 2026-05-03  
Branch: `codex/unified-keyframe-ops-foundation-20260426`

## 0. Scope

This document inventories the current Live Scrub path without changing behavior.

It covers:

- current Flutter handoff flow;
- current native Stage5 scrub classes and responsibilities;
- current descriptor/config fields sent across the scrub boundary;
- missing professional fields required by the Master Live Scrub Professional
  plan;
- baseline device validation checklist for later phases.

## 1. Current Flutter Live Scrub Handoff

### 1.1 Entry Surface

`TimelinePanel` uses `scrubSurfaceBuilder` to mount
`NativeTimelineScrubSurface` in editor scope, transition scope, unified
transition scope, layer scope, and scene-layer scope contexts.

Current binding includes:

- `currentTime` + `currentTimeListenable`;
- `timelineDurationTime`;
- `timelineOffsetTime`;
- `secondsWidth`;
- `timelineFps`;
- `configRevision`;
- `regions`;
- `previewSources`;
- callbacks: `onScrubStart`, `onScrubTimeChanged`, `onScrubEnd`, optional
  `onTap`.

### 1.2 Flutter -> Native Config Channel

`NativeTimelineScrubSurface` sends `creationParams` and `updateConfig` payloads
to the view channel:

- `currentPositionMs`
- `timelineDurationMs`
- `timelineOffsetMs`
- `secondsWidth`
- `timelineFps`
- `targetWidth`
- `targetHeight`
- `tapEnabled`
- `regions[]`
- `previewSources[]`

### 1.3 Native -> Flutter Callback Channel

`NativeTimelineScrubSurface` receives:

- `scrubStart(positionMs)`
- `scrubTimeChanged(positionMs)`
- `scrubEnd(positionMs)`
- `tap(positionMs)`

and maps them into `TimelineTime` callbacks.

### 1.4 Screen-Level Scrub Ownership

`FusionXCleanUiScreen` currently routes scrub lifecycle through:

- `_handleScrubStateChanged(...)`
- `_handleTimelineScrubFinalized(...)`
- scope variants that delegate to shared clock-safe flow.

The flow already touches master clock boundaries via:

- `_syncTimelineClockDuration()`
- `_scrubStartTimelineClockAt(...)`
- `_scrubUpdateTimelineClockAt(...)`
- `_scrubEndTimelineClockAt(...)`
- `_confirmScrubSettledTimelineClockAt(...)`
- `_applyTimelineClockSnapshotToUi()`

### 1.5 Pre-Scrub Readiness/Warmup Bridge

Flutter uses `Stage5NativeTransportController` calls:

- `primeScrubPreviewSources(...)`
- `awaitTimelineScrubReady(positionMs, timeoutMs)`
- `settleAfterScrubPositionMs(...)`
- `recoverPreviewSurface(...)`

## 2. Current Native Stage5 Class Inventory

### 2.1 `Stage5TimelineScrubPlatformView`

Responsibility:

- owns Android timeline scrub input view;
- parses Flutter `updateConfig`;
- maps `previewSources` into `Stage5NativeScrubSourceDescriptor`;
- emits scrub callbacks (`scrubStart`, `scrubTimeChanged`, `scrubEnd`, `tap`);
- drives `Stage5NativeScrubEngine` on gesture lifecycle:
  `primeTimelinePosition`, `activatePrimedSession`, `scrubTimelinePosition`,
  `commitFinalTimelinePosition`.

### 2.2 `Stage5NativeScrubEngine`

Responsibility:

- session ownership for active native scrub rendering;
- source warmup/proxy warmup coordination;
- readiness workflow (`awaitTimelineScrubReady`, `activatePrimedSession`);
- runtime target updates (`primeTimelinePosition`, `scrubTimelinePosition`,
  `commitFinalTimelinePosition`, `beginSession`, `updateTarget`);
- render-host registration and output surface visibility;
- boundary warmup and diagnostics.

### 2.3 `Stage5SurfaceScrubDecoder`

Responsibility:

- per-source decoder/extractor setup for scrub output surface;
- low-latency frame stepping and target-position rendering;
- controlled seek/forward decode strategy for scrub usage;
- decoder force-seek support and lifecycle release.

### 2.4 `Stage5PreviewPlatformView`

Responsibility:

- owns `PlayerView` + scrub overlay texture composition host;
- registers itself as `Stage5ScrubRenderHost`;
- exposes scrub output surface acquisition/release;
- syncs player visibility with scrub overlay visibility;
- applies scrub content aspect ratio transform.

### 2.5 `Stage5ScrubOverlayTextureView`

Responsibility:

- owns TextureView output surface for scrub frames;
- exposes acquire/release output surface;
- applies content-aspect transform for scrub output fit.

### 2.6 `MainActivity` Bridge Points

Transport methods used by scrub path include:

- `primeScrubPreviewSources`
- `awaitTimelineScrubReady`
- playback settle/play/pause/seek methods that coordinate with scrub session.

## 3. Current Descriptor And Config Inventory

### 3.1 Flutter Descriptor Model (`LiveScrubPreviewSourceDescriptor`)

Current fields:

- identity: `clipId`, `assetId`, `scrubStoreKey`, `label`
- source: `sourceUri`, `previewUri`
- timeline window: `timelineStartMs`, `timelineEndMs`, `durationMs`
- source window: `sourceStartMs`, `sourceDurationMs`
- timing modifier: `playbackRate`
- source geometry: `sourceWidth`, `sourceHeight`
- state metadata: `status`, `frameIntervalMs`, `frameCount`, `storageTier`

### 3.2 Native Descriptor Model (`Stage5NativeScrubSourceDescriptor`)

Current fields:

- `clipId`
- `assetId`
- `scrubStoreKey`
- `sourceUri`
- `previewUri`
- `timelineStartMs`
- `timelineEndMs`
- `durationMs`
- `sourceStartMs`
- `sourceDurationMs`
- `playbackRate`
- `sourceWidth`
- `sourceHeight`

Native helper behavior:

- `containsPosition(...)`
- `resolveSourcePositionMs(...)`
- `resolveSourceOffsetMs(...)`
- `sourceAspectRatio()`

### 3.3 Surface Config Model (`Stage5TimelineScrubSurfaceConfig`)

Current fields:

- `currentPositionMs`
- `timelineDurationMs`
- `timelineOffsetMs`
- `secondsWidth`
- `timelineFps`
- `targetWidth`
- `targetHeight`
- `tapEnabled`
- `regions[]`
- `previewSources[]`

## 4. Missing Professional Descriptor Fields (Gap List)

Compared to `Master Live Scrub Professional Plan` contracts, current path is
still missing explicit professional fields:

- no explicit `MasterLiveScrubFrameRequest` object at scrub-render boundary;
- no explicit `requestId`, `presentationTime`, `frameIndex`,
  `commitFrameNumber`, or `sourceRevision` in scrub descriptor payload;
- no explicit per-surface `visible canvas rect`;
- no explicit `crop rect`;
- no explicit normalized transform matrix;
- no explicit per-surface evaluated opacity value in descriptor payload;
- no explicit z-order field in scrub descriptor payload;
- no explicit `effect program id` list;
- no explicit transition role metadata (`outgoing`/`incoming`/etc.);
- no explicit `validity` / `blocker reasons` channel per surface;
- no explicit `LiveScrubVisualProgram` data contract serialized from
  `MasterFrameEvaluation`;
- no explicit `LiveScrubParityReport` contract for runtime parity claims.

Important nuance:

- current descriptor can derive source media time from timeline position via
  `sourceStartMs/sourceDurationMs/playbackRate`, but this is implicit and not
  yet represented as explicit per-frame visual-program output.

## 5. Baseline Device Validation Checklist (For Later Phases)

Run these checks on a connected Android device before and after each Live Scrub
phase:

1. fast forward scrub on a single long video clip.
2. slow frame-by-frame scrub on the same clip.
3. reverse scrub with frequent direction changes.
4. zoomed timeline scrub at high timeline magnification.
5. cross-source boundary scrub between two different video assets.
6. scrub, release, then immediate play from settled frame.
7. scrub while transition windows exist, then scrub outside transition windows.
8. verify no black frames, no frozen thumbnail frame, no audio-only playback
   after scrub handoff.
9. verify responsiveness does not regress on ordinary non-transition scrub.

## 6. Phase 0 Completion Statement

Phase 0 constraints were respected:

- no Stage5 native file behavior changed;
- no Flutter scrub handoff behavior changed;
- no renderer/GPU/transition/effect implementation started;
- inventory is documentation-only and ready for Phase 0 review.

