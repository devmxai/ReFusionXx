# Timeline Runtime Boundary

## Purpose

This document defines `Phase 0.5 - Timeline Runtime Boundary`.

The goal is to protect the accepted `beta-10-timeline-fixed` timeline behavior
without freezing future development. New features may interact with timeline
playback, seek, cut, delete, scrub, transitions, and scope projection, but they
must do so through stable runtime contracts instead of directly mutating the
native live scrub or transport internals.

This is not a ban on live scrub changes. It is a safety boundary.

## Current Protected Baseline

The current accepted baseline is:

- tag: `beta-10-timeline-fixed`
- commit: `27c910d release: beta 10 Timeline Fixed`
- package: `com.refusion.app`

The protected behavior includes:

- live scrub remains responsive in the root timeline
- cut/delete does not leave playback in audio-only or black-preview state
- seek/play starts from the current playhead target
- selecting and deselecting tracks does not steal background scrub ownership
- trim handles do not conflict with scrub or track selection

## Required Architecture

Future timeline features must flow through this shape:

```text
Feature
-> TimelineRuntime command
-> TimelineCommandQueue
-> TimelineRuntimeState transition
-> Adapter contract
-> Native scrub / transport / preview path
```

Feature work must not flow through this shape:

```text
Feature
-> direct Stage5NativeScrubEngine / Stage5TransportManager mutation
```

## Implemented Boundary Types

The initial boundary lives in:

`lib/features/editor/application/timeline_runtime/`

It defines:

- `TimelineRuntimeController`
- `TimelineCommandQueue`
- `TimelineRuntimeState`
- `TimelineRuntimeDiagnostics`
- `TimelineTransportRuntimeAdapter`
- `TimelineScrubRuntimeAdapter`
- `TimelinePreviewRuntimeAdapter`
- `TimelineProjectionAdapter`

The first implementation is intentionally non-invasive. It does not change the
current `beta-10` UI behavior by itself. It creates the safe route that later
work must use.

## Runtime Responsibilities

`TimelineRuntimeController` owns sequencing for sensitive commands:

- `prepareProjection`
- `commitStructuralEdit`
- `requestSeek`
- `requestPlayback`
- `pausePlayback`
- `beginScrubAt`
- `updateScrubPosition`
- `endScrubAt`

`TimelineCommandQueue` serializes commands so that `play` cannot overtake a
pending `cut/delete/prepare/readiness` sequence.

`TimelineRuntimeState` makes runtime ownership explicit with phases:

- `idle`
- `structuralCommit`
- `transportPreparing`
- `scrubReadinessPending`
- `scrubActive`
- `scrubSettling`
- `ready`
- `playing`
- `paused`
- `error`

`TimelineRuntimeDiagnostics` records command IDs, command kinds, target times,
timeline revisions, phases, and failures. This is required because live scrub
failures are often timing failures, not simple Dart logic failures.

## Adapter Contracts

Adapters are the only future bridge to fragile internals:

- `TimelineTransportRuntimeAdapter` wraps play, pause, seek, scrub settle, and
  timeline segment preparation.
- `TimelineScrubRuntimeAdapter` wraps native scrub config flush and readiness.
- `TimelinePreviewRuntimeAdapter` wraps preview freshness checks.
- `TimelineProjectionAdapter` converts root or scope timeline projections into
  transport-ready segments.

`Scope Layer`, transitions, FX lanes, and keyframes must use these contracts.
They must not call native scrub or transport internals directly.

## Development Rule

If a future feature needs timeline runtime behavior:

1. Add or reuse a `TimelineRuntime` command.
2. Add or reuse an adapter contract.
3. Add diagnostics for the new command.
4. Add regression coverage for the user journey.
5. Only then wire the feature to runtime.

If the feature truly needs a new live scrub behavior, it must be implemented as
an explicit runtime contract, not an incidental patch inside the native scrub
path.

## Regression Harness

Before shipping timeline-sensitive work, validate:

- one video: scrub `1s -> 3s -> 1s`, release, then play from `1s`
- two videos: scrub from clip A to clip B, return to clip A, then play
- split/delete inside one clip, scrub back, then play
- split/delete before a second clip, scrub back, then play
- tap empty space clears selection, tap track restores selection
- trim handle drag does not steal background scrub
- first scrub immediately after inserting a second video remains responsive

The minimum automated checks for this phase are:

```bash
flutter test test/timeline_runtime_boundary_test.dart
flutter test test/native_timeline_scrub_surface_test.dart
flutter test test/timeline_panel_native_scrub_regions_test.dart
```

Device validation should additionally record `adb logcat` for `Stage5`,
`TimelineScrub`, `AndroidRuntime`, and `ExoPlayer` markers when investigating a
regression.

## Guardrail Script

Use:

```bash
dart run tool/check_timeline_runtime_guardrails.dart
```

The guardrail does not ban protected changes. It forces them to be explicit.
If a protected file is changed, set:

```bash
TIMELINE_RUNTIME_APPROVED=1
TIMELINE_RUNTIME_CHANGE_REASON="short reason"
```

This keeps development moving while preventing accidental damage to the runtime
path.
