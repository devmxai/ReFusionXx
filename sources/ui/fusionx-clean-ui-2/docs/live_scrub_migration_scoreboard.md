# Live Scrub Migration Scoreboard

## Purpose

This document is the operational scoreboard for the live scrub migration.

It is not a broad history document and it is not a speculative design note.
Its job is narrower and stricter:

- record what is already complete
- record what is only partially migrated
- record which legacy paths are still alive
- record what is still missing before the migration is truly 100% complete
- give the monitor a fixed checklist to update after each implementation step

This document should be treated as the working source of truth for migration
progress. Older status-style notes that describe live scrub as broadly stable
must not override this scoreboard.

## Current Verdict

The migration is advanced, but not complete.

The codebase currently contains:

- a real native frame-store and native preview overlay foundation
- a partially working native scrub rendering path
- a still-active Flutter-owned scrub cadence
- a transport layer with the old active-scrub seek entrypoints removed

In plain terms:

- the new system exists
- transport-side seek scrub is removed
- ownership of the hot path is still split between Flutter and native
- preview sourcing is still tied to the original media URI rather than a real proxy asset

## Architectural Boundary

The target boundary is strict:

- Flutter announces `scrub_started` and `scrub_ended`
- Android native owns touch-move handling during active scrub
- native computes `x -> timeline time -> frame index -> draw`
- scrub frames come from indexed frame storage or a real proxy-backed source
- `ExoPlayer` performs only the final exact settle after touch-up
- nearest-ready fallback is temporary and must not be the final quality bar

Anything that keeps Flutter in the per-frame scrub path is still hybrid.

## Scoreboard

### Complete

- Binding migration mandate exists and correctly defines the target architecture in
  [docs/live_scrub_migration_mandate.md](/tmp/refusion-install/sources/ui/fusionx-clean-ui-2/docs/live_scrub_migration_mandate.md).
- Indexed scrub frame storage exists:
  [android/app/src/main/kotlin/com/fusionx/fusionx_clean_ui_2/Stage5ScrubFrameStore.kt](/tmp/refusion-install/sources/ui/fusionx-clean-ui-2/android/app/src/main/kotlin/com/fusionx/fusionx_clean_ui_2/Stage5ScrubFrameStore.kt)
- Background frame extraction exists:
  [android/app/src/main/kotlin/com/fusionx/fusionx_clean_ui_2/Stage5ScrubFrameExtractor.kt](/tmp/refusion-install/sources/ui/fusionx-clean-ui-2/android/app/src/main/kotlin/com/fusionx/fusionx_clean_ui_2/Stage5ScrubFrameExtractor.kt)
- Preparation/orchestration for scrub frame windows exists:
  [android/app/src/main/kotlin/com/fusionx/fusionx_clean_ui_2/Stage5ScrubPreparationManager.kt](/tmp/refusion-install/sources/ui/fusionx-clean-ui-2/android/app/src/main/kotlin/com/fusionx/fusionx_clean_ui_2/Stage5ScrubPreparationManager.kt)
- Native preview overlay exists above the player surface:
  [android/app/src/main/kotlin/com/fusionx/fusionx_clean_ui_2/Stage5PreviewPlatformView.kt](/tmp/refusion-install/sources/ui/fusionx-clean-ui-2/android/app/src/main/kotlin/com/fusionx/fusionx_clean_ui_2/Stage5PreviewPlatformView.kt)
- Native bitmap drawing surface exists:
  [android/app/src/main/kotlin/com/fusionx/fusionx_clean_ui_2/Stage5ScrubOverlayTextureView.kt](/tmp/refusion-install/sources/ui/fusionx-clean-ui-2/android/app/src/main/kotlin/com/fusionx/fusionx_clean_ui_2/Stage5ScrubOverlayTextureView.kt)

### Partial

- Session separation exists, but Flutter still initiates and drives active scrub cadence:
  [lib/core/engine/live_scrub_pipeline.dart](/tmp/refusion-install/sources/ui/fusionx-clean-ui-2/lib/core/engine/live_scrub_pipeline.dart)
- Native scrub rendering exists, but still receives target updates through Flutter and
  `MethodChannel`:
  [android/app/src/main/kotlin/com/fusionx/fusionx_clean_ui_2/Stage5NativeScrubEngine.kt](/tmp/refusion-install/sources/ui/fusionx-clean-ui-2/android/app/src/main/kotlin/com/fusionx/fusionx_clean_ui_2/Stage5NativeScrubEngine.kt)
- Editor screen builds a source-backed preview session and now pushes target updates directly to
  native without the old Flutter-side latest-wins dispatch loop, but the cadence is still owned
  by Flutter:
  [lib/features/editor/presentation/screens/fusionx_clean_ui_screen.dart](/tmp/refusion-install/sources/ui/fusionx-clean-ui-2/lib/features/editor/presentation/screens/fusionx_clean_ui_screen.dart)
- Real asset proxy generation now exists as a native background job, and Flutter assets can now
  carry a distinct `previewUri`, proxy state, and proxy error:
  [android/app/src/main/kotlin/com/fusionx/fusionx_clean_ui_2/Stage5ScrubProxyManager.kt](/tmp/refusion-install/sources/ui/fusionx-clean-ui-2/android/app/src/main/kotlin/com/fusionx/fusionx_clean_ui_2/Stage5ScrubProxyManager.kt),
  [android/app/src/main/kotlin/com/fusionx/fusionx_clean_ui_2/MainActivity.kt](/tmp/refusion-install/sources/ui/fusionx-clean-ui-2/android/app/src/main/kotlin/com/fusionx/fusionx_clean_ui_2/MainActivity.kt),
  [lib/core/engine/stage5_native_transport_controller.dart](/tmp/refusion-install/sources/ui/fusionx-clean-ui-2/lib/core/engine/stage5_native_transport_controller.dart),
  and
  [lib/features/editor/presentation/models/editor_asset_item.dart](/tmp/refusion-install/sources/ui/fusionx-clean-ui-2/lib/features/editor/presentation/models/editor_asset_item.dart).
- Frame-store preparation is now gated behind proxy readiness for video assets, so the scrub
  store no longer falls back to `sourceUri` while the proxy is still being built. Active proxy
  scrub also waits for the proxy-backed store to be ready before opening the native texture
  session:
  [lib/features/editor/presentation/screens/fusionx_clean_ui_screen.dart](/tmp/refusion-install/sources/ui/fusionx-clean-ui-2/lib/features/editor/presentation/screens/fusionx_clean_ui_screen.dart)
- Transport controller now exposes texture-session APIs plus general playback and final-settle
  APIs, but no active-scrub seek entrypoint:
  [lib/core/engine/stage5_native_transport_controller.dart](/tmp/refusion-install/sources/ui/fusionx-clean-ui-2/lib/core/engine/stage5_native_transport_controller.dart)
- Native rendering can still fall back to the nearest ready frame when the exact target frame is
  not prepared yet:
  [android/app/src/main/kotlin/com/fusionx/fusionx_clean_ui_2/Stage5NativeScrubEngine.kt](/tmp/refusion-install/sources/ui/fusionx-clean-ui-2/android/app/src/main/kotlin/com/fusionx/fusionx_clean_ui_2/Stage5NativeScrubEngine.kt)
  and
  [android/app/src/main/kotlin/com/fusionx/fusionx_clean_ui_2/Stage5ScrubFrameStore.kt](/tmp/refusion-install/sources/ui/fusionx-clean-ui-2/android/app/src/main/kotlin/com/fusionx/fusionx_clean_ui_2/Stage5ScrubFrameStore.kt).
- Diagnostics hooks now exist for scrub sessions, settle seeks, rendered-first-frame handoff,
  exact hits, nearest-ready fallback, and frame misses:
  [android/app/src/main/kotlin/com/fusionx/fusionx_clean_ui_2/Stage5TransportManager.kt](/tmp/refusion-install/sources/ui/fusionx-clean-ui-2/android/app/src/main/kotlin/com/fusionx/fusionx_clean_ui_2/Stage5TransportManager.kt),
  [android/app/src/main/kotlin/com/fusionx/fusionx_clean_ui_2/Stage5NativeScrubEngine.kt](/tmp/refusion-install/sources/ui/fusionx-clean-ui-2/android/app/src/main/kotlin/com/fusionx/fusionx_clean_ui_2/Stage5NativeScrubEngine.kt),
  and
  [lib/core/engine/stage5_native_transport_controller.dart](/tmp/refusion-install/sources/ui/fusionx-clean-ui-2/lib/core/engine/stage5_native_transport_controller.dart).
- Final settle is stricter than before because transport now waits for rendered-first-frame
  before dropping `isScrubSettling`, but it still has a watchdog fallback and is therefore not
  full binary proof yet:
  [android/app/src/main/kotlin/com/fusionx/fusionx_clean_ui_2/Stage5TransportManager.kt](/tmp/refusion-install/sources/ui/fusionx-clean-ui-2/android/app/src/main/kotlin/com/fusionx/fusionx_clean_ui_2/Stage5TransportManager.kt).

### Legacy Still Alive

- Flutter still owns scrub gesture cadence in
  [lib/features/editor/presentation/widgets/timeline_panel.dart](/tmp/refusion-install/sources/ui/fusionx-clean-ui-2/lib/features/editor/presentation/widgets/timeline_panel.dart):
  throttle, timer, momentum, and per-frame time dispatch.
- Flutter still owns per-move native target updates in
  [lib/features/editor/presentation/screens/fusionx_clean_ui_screen.dart](/tmp/refusion-install/sources/ui/fusionx-clean-ui-2/lib/features/editor/presentation/screens/fusionx_clean_ui_screen.dart);
  the old `_dispatchProxyScrubPreview` collapse loop is gone, but the hot path is still not
  native-owned yet.

### Missing

- Native touch capture for active scrub does not exist yet.
- Strict proxy-only preview is only partially complete: video scrub no longer falls back to the
  original `sourceUri`, but Flutter still owns the decision to warm, defer, and eventually begin
  the native proxy session.
- Active scrub still uses per-frame `MethodChannel` traffic, even though the older Flutter-side
  latest-wins dispatch loop has been removed.
- Final settle handoff is not yet guarded by a strict “show player only after rendered frame”
  rule.
- A permanent runtime monitor/UI proof layer for migration invariants does not exist yet, even
  though raw diagnostics endpoints now exist.
- Exact-frame guarantee does not exist yet; nearest-ready fallback can still substitute an
  adjacent frame when coverage is incomplete.

## Four Workstreams

### 1. Old-Path Auditor

Focus:

- find every reachable piece of legacy seek-based scrub
- classify each piece as active, dormant, or ambiguous
- define exact deletion targets

Primary files:

- [android/app/src/main/kotlin/com/fusionx/fusionx_clean_ui_2/Stage5TransportManager.kt](/tmp/refusion-install/sources/ui/fusionx-clean-ui-2/android/app/src/main/kotlin/com/fusionx/fusionx_clean_ui_2/Stage5TransportManager.kt)
- [android/app/src/main/kotlin/com/fusionx/fusionx_clean_ui_2/MainActivity.kt](/tmp/refusion-install/sources/ui/fusionx-clean-ui-2/android/app/src/main/kotlin/com/fusionx/fusionx_clean_ui_2/MainActivity.kt)
- [lib/core/engine/stage5_native_transport_controller.dart](/tmp/refusion-install/sources/ui/fusionx-clean-ui-2/lib/core/engine/stage5_native_transport_controller.dart)
- [lib/features/editor/presentation/widgets/timeline_panel.dart](/tmp/refusion-install/sources/ui/fusionx-clean-ui-2/lib/features/editor/presentation/widgets/timeline_panel.dart)

### 2. New-Path Auditor

Focus:

- verify exactly how complete the native frame-store and native overlay path is
- identify what is already trustworthy
- identify the real blockers causing heavy or non-1:1 scrub behavior

Primary files:

- [android/app/src/main/kotlin/com/fusionx/fusionx_clean_ui_2/Stage5NativeScrubEngine.kt](/tmp/refusion-install/sources/ui/fusionx-clean-ui-2/android/app/src/main/kotlin/com/fusionx/fusionx_clean_ui_2/Stage5NativeScrubEngine.kt)
- [android/app/src/main/kotlin/com/fusionx/fusionx_clean_ui_2/Stage5ScrubPreparationManager.kt](/tmp/refusion-install/sources/ui/fusionx-clean-ui-2/android/app/src/main/kotlin/com/fusionx/fusionx_clean_ui_2/Stage5ScrubPreparationManager.kt)
- [android/app/src/main/kotlin/com/fusionx/fusionx_clean_ui_2/Stage5PreviewPlatformView.kt](/tmp/refusion-install/sources/ui/fusionx-clean-ui-2/android/app/src/main/kotlin/com/fusionx/fusionx_clean_ui_2/Stage5PreviewPlatformView.kt)
- [android/app/src/main/kotlin/com/fusionx/fusionx_clean_ui_2/Stage5ScrubOverlayTextureView.kt](/tmp/refusion-install/sources/ui/fusionx-clean-ui-2/android/app/src/main/kotlin/com/fusionx/fusionx_clean_ui_2/Stage5ScrubOverlayTextureView.kt)

### 3. Migration Architect

Focus:

- define the clean boundary
- pick the safe phase order
- define what must be built before deletion
- define binary exit criteria for every phase

Primary files:

- [docs/live_scrub_migration_mandate.md](/tmp/refusion-install/sources/ui/fusionx-clean-ui-2/docs/live_scrub_migration_mandate.md)
- [lib/core/engine/live_scrub_pipeline.dart](/tmp/refusion-install/sources/ui/fusionx-clean-ui-2/lib/core/engine/live_scrub_pipeline.dart)
- [lib/features/editor/presentation/screens/fusionx_clean_ui_screen.dart](/tmp/refusion-install/sources/ui/fusionx-clean-ui-2/lib/features/editor/presentation/screens/fusionx_clean_ui_screen.dart)

### 4. المراقب

Focus:

- maintain the scoreboard
- verify invariants after each implementation step
- state exactly what still remains

This role must be updated after every migration phase, not only at the end.

## Invariants

The following must remain true or become true and then never regress:

- `ExoPlayer.seekTo()` count during active scrub = `0`
- Flutter per-frame `MethodChannel` scrub traffic during active scrub = `0`
- active scrub display source = native frame store / proxy frames only
- `Stage5TransportManager` owns playback and final settle, not active scrub rendering
- active scrub has one owner only
- scrub overlay remains visible until playback settle is actually ready
- readiness gating prevents half-active sessions with missing frames
- nearest-ready fallback is measured and then eliminated or tightly contained
- no optimization is allowed to reintroduce seek-backed live scrub

## Recommended Start Phase

The first correct phase is `Instrumentation census`.

Why this is first:

- the codebase still contains Flutter-owned and native-owned hot-path fragments
- ownership must be proven before the remaining Flutter cadence is removed
- instrumentation gives a binary baseline for every later deletion

Instrumentation must count:

- calls to `renderScrubPreviewTextureFrame`
- calls to `Stage5NativeScrubEngine.updateTarget`
- calls to `ExoPlayer.seekTo()` during active scrub
- frame-coverage hits and misses around the requested target
- nearest-ready fallback usage versus exact-frame hits

## Phase Order

1. `Instrumentation census`
   Output:
   counters and logs proving which scrub path is active right now

2. `Lock the contract`
   Output:
   prevent any new or existing active scrub path from routing back to player-seek logic

3. `Prove the frame source`
   Output:
   confirm scrub frames come from indexed storage or a real proxy-backed source, not from the
   original playback path

4. `Move input native`
   Output:
   native `MotionEvent` ownership of the hot path

5. `Keep one render owner`
   Output:
   native overlay owns the entire active scrub display and hands off only after settle is ready

6. `Delete legacy scrub`
   Output:
   remove the remaining Flutter-owned per-frame scrub cadence and any residual hybrid routing

7. `Binary verify`
   Output:
   all success criteria proven on device

## Monitor Checklist

- [ ] Contract locked: no player-backed active scrub path remains reachable
- [ ] Frame source proven: scrub frames come from indexed store or real proxy source
- [ ] Native input active: Flutter no longer sends per-frame scrub updates
- [ ] Single render owner active: native overlay owns active scrub visuals
- [ ] Clean handoff active: player becomes visible only after settle frame is ready
- [x] Transport scrub APIs deleted: transport no longer exposes active-scrub seek entrypoints
- [ ] Legacy scrub deleted: no Flutter-owned per-frame scrub cadence remains
- [ ] Exact-frame delivery active: nearest-ready fallback is no longer used in normal scrub
- [ ] Binary verification passed: 0 scrub-time seeks, continuous native draw, no black flash, no final snap

## What Still Remains Right Now

- native touch hot path
- real proxy-backed frame source
- removal of Flutter per-frame scrub dispatch
- strict settle handoff
- binary runtime proof layer for migration invariants
- elimination or strict containment of nearest-ready fallback

## Monitor Audit Notes

The monitor currently considers this document directionally correct but not yet
strict enough in three places:

- `proxyPreview` should not be read as “real proxy asset exists now”; current code still uses
  the original `sourceUri` as the preview source.
- `transport limited to playback and final settle only` should be read as “old active-scrub seek
  entrypoints are deleted,” not as “transport owns nothing else.”
- current native rendering can still fall back to the nearest ready frame, so the migration has
  not yet reached exact-frame parity under incomplete coverage.
