# Stage 6 Timeline Professionalization - Stage 0 Baseline Freeze

## Status

Accepted baseline freeze for the professionalization track.

This document freezes the current accepted timeline baseline before deeper
timeline architecture changes begin.

It is the official `must not regress` reference for the new
timeline-professionalization path.

## Purpose

The timeline now has enough real functionality that further changes can easily
improve one axis while damaging another.

Stage 0 exists to stop that drift.

From this point onward, no timeline stage may be accepted unless it preserves
the baseline behaviors listed below.

## Current Accepted Baseline

The following behaviors are now treated as protected baseline truth:

1. the app opens and the native preview initializes on the connected Android device
2. real media can still be imported into the timeline
3. the timeline ruler and left time readout now share the same visual header system
4. trim mode exists and can expose visible trim handles on the selected video clip
5. timeline zoom and ruler modes exist and remain functionally usable
6. live scrub is usable enough to continue development
7. structural timeline edits still rebuild native timeline playback truth
8. motion text still projects into the text track and remains visible in the editor flow

## Accepted Known Imperfections

The following are known and remain open.

They are not considered regressions of the frozen baseline because they are the
reason this professionalization track now exists:

- playback start can still feel visually unstable in some sessions
- playback follow is not yet globally smooth enough
- scrub still needs stronger low-latency consistency
- interaction ownership between scrub/trim/zoom is improved but not fully locked
- transport and preview session switching still need stricter guarantees
- the timeline is not yet global-grade under long sessions and dense future use

## Current Timeline Assessment Snapshot

Current estimated maturity before professionalization stages:

- overall maturity: `58%`
- interaction stability: `52%`
- scrub fidelity: `57%`
- trim ergonomics: `68%`
- zoom and ruler behavior: `64%`
- playback smoothness: `41%`
- architecture and state ownership: `46%`
- motion/text extensibility: `70%`

This snapshot is not a marketing score.

It is an engineering guide used to evaluate whether later stages are actually
improving the system.

## Forbidden Regressions

The following would reject a later stage immediately:

- imported media stops opening or preview transport breaks
- trim mode stops exposing or committing trim correctly
- scrub becomes worse than the current accepted baseline
- zoom becomes unusable or loses ruler readability
- motion text disappears from the text timeline path
- the header ruler/time readout alignment regresses again
- timeline edits stop rebuilding native playback truth
- the connected device can no longer validate the timeline flow end-to-end

## Stage 0 Working Rules

- do not change timeline behavior in this stage unless the change is purely diagnostic and non-invasive
- do not add speculative fixes here
- do not widen scope into Stage 1 behavior yet
- if extra diagnostics are needed later, they must be:
  - debug-only
  - removable
  - behavior-neutral

## Real-Device Validation Set

Every later stage must keep passing these device checks:

1. open the app and confirm preview/timeline render normally
2. import one real video and verify playback opens
3. press play from timeline start and watch the first seconds
4. scrub near the beginning, middle, and end of the same video
5. zoom out and zoom in and verify ruler readability remains acceptable
6. enable trim mode, capture both handles, and perform legal trims
7. verify the playhead barrier behavior still holds during trim
8. confirm the text track still appears and remains compatible with the editor shell

## Immediate Next Allowed Stage

The next allowed implementation stage is:

- `Stage 1 - Single Playback Clock Ownership`

That stage is now the highest-priority development step because the current
largest quality gap is playback smoothness and playback-follow stability.

## References

- [Stage 6 Timeline Professionalization Master Plan](/Users/mx/Documents/InGeneBMFPro/docs/process/stage-6-timeline-professionalization-master-plan.md)
- [Stage 6 Real Import And Timeline Truth](/Users/mx/Documents/InGeneBMFPro/docs/process/stage-6-real-import-and-timeline-truth.md)
- [Stage 6 Timeline Interaction Contract](/Users/mx/Documents/InGeneBMFPro/docs/process/stage-6-timeline-interaction-contract.md)
