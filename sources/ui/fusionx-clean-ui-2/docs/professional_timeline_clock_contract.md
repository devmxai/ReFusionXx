# Professional Timeline Clock Contract

Status: official execution plan  
Scope: timeline clock, playback stability, scrub handoff, zoom stability, scoped timelines, keyframes, effects, and transitions  
Package: `com.refusion.app`

## Execution Status

- Phase 0: completed. Baseline writer audit documented in `docs/professional_timeline_clock_audit.md`.
- Phase 1: completed as isolated infrastructure. `TimelineClockCoordinator` exists in `lib/features/editor/domain/services/timeline_clock_coordinator.dart` with tests in `test/timeline_clock_coordinator_test.dart`.
- Phase 2: device-validated candidate. Main timeline playback start, native playback samples, and scrub handoff now pass through `TimelineClockCoordinator`; playback start rejects native samples that are not close to the requested frame, and scrub-to-play waits for the scrub handoff to settle before starting. The legacy motion-preview frame ticker is no longer allowed to own playback sample/display time while the coordinator owns playback. Real-device validation on April 25, 2026 reported high stability for play/pause and Live Scrub.
- Phase 3: in progress. `TimelineGeometryMapper` exists in `lib/features/editor/domain/services/timeline_geometry_mapper.dart` with tests in `test/timeline_geometry_mapper_test.dart`; central `TimelinePanel` time/offset mapping, playback visual follow, clip move, trim drag, and native scrub pointer delta calculations now route through it.
- Live Scrub status: protected. No Stage5 Live Scrub native engine behavior was migrated or rewritten by this phase.

## 0. Non-Negotiable Live Scrub Protection

Live Scrub is a protected production path.

This plan must not rebuild, replace, or degrade the current Stage5 Live Scrub path. Any implementation must treat Live Scrub as a high-value existing capability and integrate with it through an adapter layer first.

Strict rules:

- Do not rewrite the Stage5 live scrub engine as part of this plan.
- Do not change Stage5 live scrub native files unless a specific, reviewed fix requires it.
- Do not use playback stability work as a reason to weaken scrub responsiveness.
- Do not accept any phase if fast scrub, slow scrub, zoomed-in scrub, and reverse scrub regress.
- If a clock fix conflicts with scrub quality, stop and redesign the integration layer.
- The target is 100% professional stability, not a partial visual mask.

The goal is to make Live Scrub safer by giving it a proper timeline clock contract, not to disturb the working scrub path.

## 1. Problem Statement

The current timeline can show playback jumps, scroll refreshes, preview/timeline divergence, and unstable handoff after Live Scrub because time ownership is distributed across multiple systems:

- Flutter UI display time.
- ScrollController position.
- Native playback position.
- Playback sample notifier.
- Live Scrub settle state.
- Scoped layer local time.
- Transition scope local time.
- Keyframe and effect evaluators.

The professional requirement is simple:

`playhead time = scroll position = preview frame = native player position = keyframe evaluation time`

Every timeline mode must derive from this same truth.

## 2. Core Principle

Build a single authoritative clock owner:

`TimelineClockCoordinator`

It is the only component allowed to decide the current timeline time and interaction phase.

Other systems may request time changes, but they must not independently write timeline time, scroll position, preview time, or keyframe evaluation time.

## 3. Timeline Clock State Machine

The coordinator must expose a strict state machine:

- `idle`
- `paused`
- `scrubbing`
- `scrubSettling`
- `playStarting`
- `playing`
- `pausing`
- `seeking`
- `zooming`
- `structuralEditing`

Invalid combinations are forbidden. Examples:

- The system must not be `playing` and `scrubSettling` at the same time.
- The system must not be `zooming` while accepting timeline time drift from playback samples.
- The system must not be `scrubbing` while playback samples drive the visible time.

Each phase must define:

- Who may request time changes.
- Who may confirm time changes.
- Whether native transport is authoritative.
- Whether preview frames are requested or streamed.
- Whether scroll is user-owned or clock-owned.

## 4. Single Time API

All timeline time changes must go through coordinator commands:

```dart
clock.scrubStart(anchorTime);
clock.scrubUpdate(targetTime);
clock.scrubEnd(finalTime);
clock.playFrom(time);
clock.pauseAt(time);
clock.seekTo(time);
clock.zoomStart(anchorTime);
clock.zoomUpdate(anchorTime, scale);
clock.zoomEnd(anchorTime);
clock.applyNativeSample(sampleTime);
clock.applyStructuralEdit(resultingTime);
```

No widget should directly coordinate a playback start by mixing:

- `setCurrentTime`
- `setPlaybackSampleTime`
- native `seekTo`
- native `play`
- scroll `jumpTo`

Those actions must become coordinator-owned side effects.

## 5. Time To Geometry Contract

Timeline geometry must be deterministic:

```text
scrollOffset = geometry.offsetForTime(clock.time)
time = geometry.timeForOffset(scrollOffset)
```

Rules:

- The playhead is fixed in viewport space.
- The content scrolls according to clock time.
- Zoom must preserve the exact anchor frame.
- Zoom must not change preview frame.
- Scroll offset must never be used as an independent time source during playback.
- Visual translation must not be used as a substitute for real scroll movement in native playback.

The same mapping must be used by:

- Main timeline.
- Scoped layer timeline.
- Transition scope timeline.
- Ruler.
- Native scrub surface regions.
- Keyframe lanes.

## 6. Playback Start Contract

When the user presses Play:

1. Read the start time from `TimelineClockCoordinator`.
2. End or supersede any pending scrub settle for the same target time.
3. Send a single native command: `playFrom(startTime)`.
4. Enter `playStarting(startTime)`.
5. Reject stale native samples older than the requested start time.
6. Accept the first valid native sample as the playback confirmation.
7. Enter `playing`.
8. Drive preview, timeline scroll, ruler, keyframes, effects, and scopes from the accepted clock time.

Acceptance criteria:

- Play after forward scrub starts from the exact final scrub frame.
- Play after reverse scrub starts from the exact final scrub frame.
- Pause then Play starts from the exact paused frame.
- No track jump, no refresh flash, no preview/timeline divergence.

## 7. Live Scrub Contract

Live Scrub remains native-optimized, but its lifecycle must be represented in the coordinator.

Flow:

```text
native scrub down -> clock.scrubStart(anchorTime)
native scrub move -> clock.scrubUpdate(time)
native scrub up   -> clock.scrubEnd(finalTime)
native settle     -> clock.scrubSettling(finalTime)
settle complete   -> clock.pausedAt(finalTime)
```

The coordinator must not slow down scrub input. It should adapt scrub events, not replace the scrub engine.

Acceptance criteria:

- Fast Live Scrub remains responsive.
- Slow Live Scrub remains stable frame-by-frame.
- Reverse Live Scrub does not jitter between adjacent frames.
- Deep zoom Live Scrub remains precise.
- Scrub-to-play handoff has no jump.

## 8. Native Transport Adapter

Native transport is not always the clock owner.

It is authoritative only in these phases:

- `playStarting`, after the first valid confirmed sample.
- `playing`, for accepted playback samples.
- `seeking`, when confirming requested seek completion.

It is not authoritative during:

- user scrub updates,
- zoom gestures,
- structural edit transactions,
- scoped timeline edits,
- manual keyframe dragging.

The adapter must expose typed events:

```dart
NativePlaybackStarted(requestedTime, firstSampleTime)
NativePlaybackSample(sampleTime)
NativePlaybackPaused(positionTime)
NativeSeekConfirmed(requestedTime, actualTime)
NativeScrubSettleConfirmed(targetTime)
NativeTransportStalled(lastKnownTime)
```

Raw native position events should not directly mutate UI time.

## 9. Scoped Timeline Projection Contract

Scoped timelines must not own independent clocks.

They receive projected time:

```text
layerLocalTime = globalClock.time - layerStartTime
transitionLocalTime = globalClock.time - transitionWindowStartTime
```

Rules:

- Main timeline is the global clock context.
- Layer scope is a projection over the selected layer.
- Transition scope is a projection over the transition work area.
- Editing keyframes in scope changes authored local times, not the global clock owner.
- Playback in scope still uses the same global/native transport clock.

## 10. Keyframe And Effect Evaluation Contract

All keyframe and effect evaluation must read from:

```dart
clock.evaluationTime
```

No effect may evaluate from:

- widget local state,
- scroll position,
- native raw position,
- stale playback sample,
- independent scoped timer.

This applies to:

- opacity,
- position,
- scale,
- blur,
- text animation,
- imported script motion,
- transition parameters,
- future shape/image/video effects.

Preview, Live Scrub, playback, and export must use the same evaluator rules.

## 11. Transition Timeline Contract

Transitions must become first-class timeline windows driven by the same clock.

Transition scope uses:

```text
transitionProgress = (globalClock.time - overlapStart) / overlapDuration
```

Rules:

- Moving transition keyframes changes real transition timing.
- Presets and imported scripts compile to the same property channels.
- Preview and export use the same transition evaluator.
- Transition scope must not invent a separate playback clock.

## 12. Zoom Contract

Zoom is geometry-only.

During zoom:

- The current clock time is locked.
- Preview frame must not change.
- Playhead frame must not change.
- Ruler expands/contracts around the locked frame.
- Scroll offset is derived from `geometry.offsetForTime(lockedTime)`.

On zoom end:

- The same locked time remains current.
- No seek should be sent unless the user actually changed time.
- No Live Scrub event should be synthesized.

Acceptance criteria:

- Zoom in at second 10 remains second 10.
- Zoom out at frame 24 remains frame 24.
- Preview does not advance or reverse during zoom.
- Ruler labels do not drift under the playhead.

## 13. Implementation Phases

### Phase 0: Audit And Baseline Freeze

Document all current writers of time and scroll:

- `_currentTime`
- `_timelineDisplayTimeNotifier`
- `_playbackSampleTimeNotifier`
- native transport state position
- TimelinePanel display time
- scroll position
- scope local time notifiers

Exit criteria:

- A list of all writers exists.
- No code behavior change.

### Phase 1: Coordinator Skeleton

Create `TimelineClockCoordinator` with state, commands, and read-only outputs.

Exit criteria:

- Unit tests validate state transitions.
- No UI is migrated yet.

### Phase 2: Main Timeline Playback Ownership

Route Play, Pause, and native playback samples through the coordinator.

Exit criteria:

- Pause/play has no jump.
- Forward scrub then play has no jump.
- Reverse scrub then play has no jump.
- Existing Live Scrub quality is unchanged.

### Phase 3: Time Geometry Ownership

Move timeline time-to-scroll mapping behind one geometry contract.

Exit criteria:

- Zoom preserves exact frame.
- Playback moves real scroll, not visual-only transforms.
- Native scrub regions update from the same geometry.

### Phase 4: Live Scrub Adapter Integration

Wrap Live Scrub events into coordinator commands without rewriting scrub internals.

Exit criteria:

- Slow scrub is stable.
- Reverse scrub is stable.
- Deep zoom scrub is stable.
- No Stage5 regression.

### Phase 5: Scoped Timeline Projection

Connect layer scope and transition scope as projections of global clock.

Exit criteria:

- Scoped playback matches main timeline playback.
- Keyframes in scope evaluate correctly during scrub and play.
- Transition scope does not drift from global timeline.

### Phase 6: Keyframes And Effects Evaluator

Force all animation/effect evaluation to read from coordinator evaluation time.

Exit criteria:

- Manual keyframes work in scrub/play/export.
- Scripted effects work in scrub/play/export.
- Transition keyframes are real, not visual-only.

### Phase 7: Export Parity

Use the same clock/evaluator model to feed export graph timing.

Exit criteria:

- Preview and export match within accepted visual tolerance.

## 14. Test Matrix

Required tests before accepting any phase:

- Play from paused frame.
- Pause at frame, play again.
- Forward Live Scrub, release, play.
- Reverse Live Scrub, release, play.
- Live Scrub while playing.
- Zoom in then play.
- Zoom out then play.
- Deep zoom slow scrub.
- Transition scope playback.
- Layer scope playback.
- Keyframe drag then play.
- Keyframe move-to-playhead then play.
- Effect value edit then scrub/play.
- Script import then scrub/play.

## 15. Rejection Criteria

Reject any implementation if:

- Live Scrub becomes slower.
- Play causes a visible jump.
- Preview moves while timeline does not.
- Timeline moves while preview does not.
- Playhead can move outside real timeline content.
- Keyframes evaluate differently in scrub and playback.
- Scope timeline uses a separate clock engine.
- A visual transform hides a real clock mismatch.

## 16. Final Target

The final target is a 2026-grade professional timeline:

- one clock,
- one geometry mapping,
- one evaluator,
- one native transport adapter,
- projections for scopes,
- no fake visual correction,
- no scrub regression,
- no playback jump,
- no preview/timeline divergence.

This plan is the foundation for professional transitions, scoped layer animation, scriptable motion, keyframes, effects, and export parity.
