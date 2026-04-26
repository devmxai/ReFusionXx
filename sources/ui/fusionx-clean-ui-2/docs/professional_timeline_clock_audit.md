# Professional Timeline Clock Audit

Status: Phase 0 baseline audit  
Parent plan: `docs/professional_refusion_motion_keyframe_engine.md`  
Scope: current timeline time writers before coordinator migration

## Live Scrub Protection

This audit is read-only documentation. It does not authorize changing or rebuilding Stage5 Live Scrub.

Any future migration must preserve:

- fast Live Scrub,
- slow frame-accurate Live Scrub,
- reverse Live Scrub,
- deep zoom Live Scrub,
- current Stage5 native scrub quality.

## Current Time Writers

The current codebase has multiple writers or derived writers for the same timeline time concept. This is the root architectural reason playback, preview, scroll, scoped timelines, transitions, and keyframes can drift from each other.

### 1. Screen-Level Current Time

File:

- `lib/features/editor/presentation/screens/fusionx_clean_ui_screen.dart`

Current state:

- `_currentTime`
- `_setCurrentTime`

Current responsibility:

- Stores the editor timeline time.
- Updates display time.
- May update playback sample time when not playing native preview.

Risk:

- It can be updated independently from native transport samples and timeline scroll.

### 2. Timeline Display Time Notifier

File:

- `lib/features/editor/presentation/screens/fusionx_clean_ui_screen.dart`

Current state:

- `_timelineDisplayTimeNotifier`
- `_setTimelineDisplayTime`
- `_applyTimelineDisplayTime`

Current responsibility:

- Drives visible timeline time.
- Syncs transition focus and layer scope local notifiers.

Risk:

- It can be blocked by zoom locks or scrub handoff while native transport continues moving.

### 3. Playback Sample Time Notifier

File:

- `lib/features/editor/presentation/screens/fusionx_clean_ui_screen.dart`

Current state:

- `_playbackSampleTimeNotifier`
- `_setPlaybackSampleTime`

Current responsibility:

- Drives playback sample time for preview/scopes during native playback.

Risk:

- Preview can advance from playback samples while timeline display time is gated by scrub handoff, structural edit, trim preview, or scrub settling.

### 4. Native Transport Position

Files:

- `lib/core/engine/stage5_native_transport_controller.dart`
- `android/app/src/main/kotlin/com/fusionx/fusionx_clean_ui_2/Stage5TransportManager.kt`
- `android/app/src/main/kotlin/com/fusionx/fusionx_clean_ui_2/MainActivity.kt`

Current state:

- `Stage5TransportState.positionMs`
- native `buildState()["positionMs"]`
- method channel playback/seek/scrub commands

Current responsibility:

- Reports native playback position and scrub settle position.

Risk:

- Native position may arrive before/after Flutter display time changes.
- Raw samples can be stale relative to the user's latest scrub/play command.

### 5. TimelinePanel Local Display Time

File:

- `lib/features/editor/presentation/widgets/timeline_panel.dart`

Current state:

- `_displayTimeNotifier`
- `_setDisplayTime`
- `_applyReportedPlaybackSample`

Current responsibility:

- Draws the playhead/ruler/timeline at a local widget level.

Risk:

- It can be driven by widget `currentTime`, playback samples, internal ticker, native scrub callbacks, and zoom locks.

### 6. ScrollController Position

File:

- `lib/features/editor/presentation/widgets/timeline_panel.dart`

Current state:

- `_scrollController`
- `_driveScrollToTime`
- `_targetHorizontalOffsetForTime`
- `_effectiveHorizontalScrollOffset`

Current responsibility:

- Maps visible timeline content to the fixed playhead.

Risk:

- Scroll can become a second time source if it is not strictly derived from the clock.
- Visual-only follow can hide a mismatch instead of correcting it.

### 7. Native Scrub Surface

Files:

- `lib/features/editor/presentation/widgets/native_timeline_scrub_surface.dart`
- `lib/features/editor/presentation/widgets/timeline_panel.dart`
- `android/app/src/main/kotlin/com/fusionx/fusionx_clean_ui_2/Stage5TimelineScrubPlatformView.kt`

Current responsibility:

- Provides native optimized scrub input and preview handoff.

Risk:

- Its event lifecycle is not yet represented by one central clock state machine.
- Must be adapted carefully without weakening the existing Stage5 path.

### 8. Scoped Layer Time Projection

File:

- `lib/features/editor/presentation/screens/fusionx_clean_ui_screen.dart`

Current state:

- `_layerScopeDisplayTimeNotifier`
- `_layerScopePlaybackSampleTimeNotifier`
- `_layerScopeLocalTime`

Current responsibility:

- Converts global timeline time to selected layer local time.

Risk:

- Projection is currently synchronized from screen-level notifiers, not from a single clock contract.

### 9. Transition Scope Time Projection

File:

- `lib/features/editor/presentation/screens/fusionx_clean_ui_screen.dart`

Current state:

- `_transitionFocusDisplayTimeNotifier`
- `_transitionFocusPlaybackSampleTimeNotifier`
- `_transitionFocusLocalTime`

Current responsibility:

- Converts global timeline time to transition scope local time.

Risk:

- Transition keyframes/effects can drift if local scope time is not projected from the same global clock as playback.

### 10. Keyframe And Effect Evaluators

Files:

- `lib/features/editor/presentation/screens/fusionx_clean_ui_screen.dart`
- `lib/features/editor/presentation/widgets/timeline_transition_preview_overlay.dart`
- motion and transition authoring/evaluation services

Current responsibility:

- Evaluate animation/effect values for preview, scrub, playback, scoped timelines, and transitions.

Risk:

- If evaluators read different time inputs in preview/scrub/play/export, visible motion will not match timeline truth.

## Phase 0 Conclusion

The jump is not a single isolated button bug. The current architecture allows multiple time writers to compete.

The next safe step is Phase 1:

- add `TimelineClockCoordinator` as an isolated domain service,
- validate its state machine with tests,
- do not connect it to Live Scrub yet,
- do not change production timeline behavior until the contract is proven.
