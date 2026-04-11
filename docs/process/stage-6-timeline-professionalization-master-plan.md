# Stage 6 Timeline Professionalization Master Plan

## Status

Active execution reference.

Current recorded execution state:

- `Stage 0 - Baseline Freeze And Instrumented Truth`: closed
- `Stage 1 - Single Playback Clock Ownership`: closed
- `Stage 2 - Professional Live Scrub Engine`: parked at accepted interim baseline
- `Stage 3 - Zoom And Ruler Canonicalization`: closed
- `Stage 4 - Trim Interaction Hardening`: closed
- `Stage 5 - Gesture State Machine Lock`: closed
- `Stage 6 - Structural Edit Semantics`: closed
- `Stage 7 - Multi-Track And Mobile Navigation Quality`: parked at accepted interim baseline
- `Stage 8 - Motion And Text Timeline Integration`: closed
- `Stage 9 - Performance Hardening`: active

This document is now the strict development guide for timeline work until the
timeline is considered professionally stable, mobile-friendly, and ready for
future motion/text/effects growth.

No timeline slice may be treated as complete unless:

1. implementation is finished
2. local verification passes
3. the APK is installed on the connected real device
4. the exact stage acceptance scenarios are tested on device
5. the result is accepted before moving to the next stage

## Goal

Build a timeline that is:

- smooth and stable on mobile
- exact in time math
- safe for future motion and text expansion
- strict in ownership boundaries
- resistant to regression when more tools are added later

## Current Engineering Assessment

Current estimated maturity: `74%` of a global-grade mobile editing timeline.

Current estimated strength by axis:

- interaction stability: `70%`
- scrub fidelity: `72%`
- trim ergonomics: `78%`
- zoom and ruler behavior: `76%`
- playback smoothness: `68%`
- architecture and state ownership: `71%`
- extensibility for professional motion/text: `80%`

This means the current timeline is now a strong near-professional mobile
editing base, but it is not yet acceptable as a fully closed world-class
timeline.

Latest pushed timeline checkpoint in `BETA1`:

- timeline lane chrome has been simplified back toward a neutral professional
  look
- the timeline now prefers insertion-driven track creation over pre-seeded
  empty track rows
- text preset insertion now ensures a text track exists before the first
  generated text clip is added
- scrub now has dedicated background gesture coverage in the empty spacer below
  the ruler and the empty timeline area below the last visible track
- long-press same-track reorder now enters through an animated morph from the
  normal clip geometry into compact reorder cards
- magnetic insertion feel is now stronger during same-track reorder, with a
  clearer temporary insertion gap and softer rightward push for downstream clips
- non-video clip movement now uses true temporal placement with preserved gaps
- moved text clips now respect their shifted timing in runtime evaluation
- non-video clip movement no longer auto-jumps the playhead
- this pushed checkpoint is built, analyzed, and installed on the connected
  device, but the broader manipulation acceptance matrix is still open

## Non-Negotiable Rules

- Flutter remains the only owner of canonical editor timeline truth
- native `Media3` remains the owner of playback and preview transport
- no second hidden timeline truth may appear in native code
- no playback feature may rely on accidental UI scroll state
- no feature may be accepted if it improves appearance but weakens timing truth
- no stage may introduce regressions in:
  - playback
  - scrub
  - trim
  - zoom
  - structural edits
- every stage must be tested on the connected real device before the next one
- timeline work must stay compatible with future:
  - motion text
  - keyframes
  - effects
  - export orchestration
- timeline work should also avoid hard-coding fixed media/text/audio lane mocks
  when insertion-driven track truth is the intended UX

## Core Diagnosis

The timeline is currently held back by five structural gaps:

1. playback time ownership is not strict enough
2. playback follow is still too scroll-driven instead of display-driven
3. gesture ownership is still fragmented between scrub, trim, zoom, reorder
4. transport session switching is still vulnerable around preview and play
5. timeline model is still UI-forward in some areas instead of engine-forward

## Global Execution Method

Every stage below must follow this loop exactly:

1. implement only the stage scope
2. run local verification
3. build APK
4. install on the connected Android device
5. test only the acceptance scenarios for that stage
6. record pass/fail truthfully
7. update the stage documentation, master plan, and any active handoff note so
   the current execution state is explicit and recoverable later
8. only then open the next stage

## Stage 0 - Baseline Freeze And Instrumented Truth

### Goal

Freeze the current accepted baseline before more deep timeline changes.

### Scope

- capture the currently accepted timeline behavior
- define the protected regressions list
- add lightweight runtime logging only if needed for timing diagnostics

### Must Not Change

- existing trim UI
- current zoom UI
- current motion/text behavior

### Acceptance Gate

- app builds
- real device installs
- baseline issues are reproducible and documented
- no behavioral changes are introduced in this stage

## Stage 1 - Single Playback Clock Ownership

### Goal

Make playback time visually owned by one authoritative display clock.

Implementation reference:

- [Stage 6 Timeline Professionalization - Stage 1 Single Playback Clock Ownership](/Users/mx/Documents/InGeneBMFPro/docs/process/stage-6-timeline-professionalization-stage-1-single-playback-clock-ownership.md)

### Scope

- remove double-driving between native transport samples and local display motion
- define one clear playback-follow owner
- stop any play-start regression to old or zero position

### Must Not Change

- scrub behavior
- trim behavior
- zoom behavior

### Acceptance Gate

- first play does not snap backward
- timeline no longer jitters at play start
- timeline follows playback continuously without visible bounce

## Stage 2 - Professional Live Scrub Engine

### Goal

Make live scrub precise, immediate, and stable across the entire video.

### Scope

- unify scrub dispatch policy
- remove delayed final stuck frame
- ensure scrub fidelity is consistent from start to end of timeline
- keep scrub strong under zoom-in and zoom-out

### Must Not Change

- play/pause correctness
- trim handles
- structural edit truth

### Acceptance Gate

- live scrub feels immediate
- no final delayed frame appears after releasing the finger
- scrub near timeline end is not worse than scrub near timeline start
- scrub remains usable on short and long clips

## Stage 3 - Zoom And Ruler Canonicalization

### Goal

Make zoom mathematically stable and ruler spacing globally readable.

### Scope

- lock playhead-centered zoom behavior
- keep zoom stable at any touch point inside timeline
- formalize ruler spacing rules for:
  - coarse seconds
  - normal seconds
  - seconds plus frames
  - fine frames
- ensure end-of-timeline labeling always reflects true total duration

### Must Not Change

- scrub stability
- trim correctness

### Acceptance Gate

- pinch works reliably from anywhere inside the timeline
- ruler labels remain readable and mathematically consistent
- final visible end label always matches the true end of content

## Stage 4 - Trim Interaction Hardening

### Goal

Make trim as reliable and professional as modern mobile editors.

Implementation reference:

- [Stage 6 Timeline Professionalization - Stage 4 Trim Interaction Hardening](/Users/mx/Documents/InGeneBMFPro/docs/process/stage-6-timeline-professionalization-stage-4-trim-interaction-hardening.md)

### Scope

- finalize trim handle capture reliability
- enforce pure horizontal trim ownership
- keep track rows vertically stable during trim
- preserve playhead barrier behavior
- ensure trim preview remains exact and readable

### Must Not Change

- scrub outside trim mode
- playback stability

### Acceptance Gate

- trim handle capture works from first touch consistently
- no vertical drift occurs while trimming
- trim edges stop at correct legal limits
- playhead remains stable and is not dragged by trim

## Stage 5 - Gesture State Machine Lock

### Goal

Give the timeline one explicit interaction state machine.

Implementation reference:

- [Stage 6 Timeline Professionalization - Stage 5 Gesture State Machine Lock](/Users/mx/Documents/InGeneBMFPro/docs/process/stage-6-timeline-professionalization-stage-5-gesture-state-machine-lock.md)

### Scope

- define and enforce:
  - idle
  - playback
  - scrub
  - trim
  - zoom
  - reorder
- ensure one pointer flow has one owner only
- remove gesture ambiguity paths

### Must Not Change

- existing accepted UI look
- timeline truth ownership

### Acceptance Gate

- no gesture randomly fails on first touch
- no timeline interaction mode interferes with another unexpectedly
- mobile interaction feels deterministic

## Stage 6 - Structural Edit Semantics

### Goal

Move from UI-correct edits to editor-correct semantics.

Implementation reference:

- [Stage 6 Timeline Professionalization - Stage 6 Editing Semantics Hardening](/Users/mx/Documents/InGeneBMFPro/docs/process/stage-6-timeline-professionalization-stage-6-editing-semantics-hardening.md)

### Scope

- finalize split
- finalize duplicate
- finalize delete
- formalize gap policy
- formalize ripple policy
- formalize position-mode boundaries if introduced later

### Must Not Change

- exact clip source ranges
- canonical timeline truth

### Acceptance Gate

- repeated edit chains remain correct
- no hidden timeline drift appears after many edits
- timeline remains coherent after split/trim/delete sequences

## Stage 7 - Multi-Track And Mobile Navigation Quality

### Goal

Make the timeline strong under dense multi-track mobile use.

Implementation reference:

- [Stage 6 Timeline Professionalization - Stage 7 Multi-Track And Mobile Navigation Quality](/Users/mx/Documents/InGeneBMFPro/docs/process/stage-6-timeline-professionalization-stage-7-multi-track-and-mobile-navigation-quality.md)

### Scope

- stable row behavior across video, image, audio, text, lip sync
- reduce accidental vertical scroll conflicts
- improve navigation clarity under dense content
- preserve touch targets under compact zoom levels

### Must Not Change

- single-track accepted behavior

### Acceptance Gate

- dense timelines remain editable on device
- no essential control becomes too difficult to capture
- navigation remains understandable without desktop assumptions

## Stage 8 - Motion And Text Timeline Integration

### Goal

Make the timeline a safe long-term host for professional motion.

Implementation reference:

- [Stage 6 Timeline Professionalization - Stage 8 Motion And Text Timeline Integration](/Users/mx/Documents/InGeneBMFPro/docs/process/stage-6-timeline-professionalization-stage-8-motion-and-text-timeline-integration.md)

### Scope

- lock the contract between timeline truth and motion text entries
- ensure motion text timing remains canonical
- ensure future keyframes/effects do not create competing time ownership
- prepare timeline selection/editing for richer motion authoring

### Must Not Change

- current accepted text preset workflow
- current accepted text modify workflow

### Acceptance Gate

- text/motion clips obey the same timeline truth as media clips
- no motion-specific timing layer bypasses the canonical timeline

### Closure State

- read-side motion/text timeline truth is in place
- motion/text selection and preview alignment is in place
- motion/text delete semantics are in place
- motion/text duplicate semantics are in place
- motion/text trim/timing participation is in place
- motion/text post-edit selection/time/preview canonicalization is in place
- motion/text trim preview feedback is in place
- motion/text canonical timing-range contract is in place
- Stage 8 is accepted as closed at this baseline
- next recommended work should continue from:
  - a dedicated `Time Remapping / Speed Graph` stage
  - or later keyframe/effects timing work

## Stage 9 - Performance Hardening

### Goal

Make the timeline resilient under real device pressure.

### Scope

- profile rebuild cost
- profile playback follow cost
- profile scrub under short and long clips
- reduce hot rebuild surfaces
- separate static and rapidly changing subtrees where necessary

### Must Not Change

- visible interaction behavior
- canonical timing rules

### Acceptance Gate

- playback looks smooth on device
- scrub remains smooth under stress
- no high-frequency UI jank remains in accepted scenarios

### Current Resume Point

- current-state motion/text timeline projection is memoized
- current display tracks reuse cached motion/text projection
- current motion/text lookup paths reuse cached entries in the common case
- next work should continue from:
  - on-device playback/scrub acceptance
  - then another hot-surface reduction slice if needed

## Stage 10 - Closure And Future-Proof Lock

### Goal

Close the timeline file as a professional foundation, not just a working UI.

### Scope

- verify all previous stages on device again as one combined pass
- confirm compatibility with future motion/effects/export growth
- document accepted contracts and deferred items

### Closure Criteria

The timeline may be considered professionally closed only when:

- playback is visually smooth
- scrub is immediate and stable
- trim is reliable and easy to capture
- zoom and ruler behavior are mathematically trustworthy
- gesture ownership is deterministic
- structural edits remain exact after repeated operations
- motion/text integration remains canonical
- no unresolved architecture contradiction remains between Flutter and native

## Immediate Next Execution Order

From now on, the project should move in this exact order:

1. `Stage 0 - Baseline Freeze And Instrumented Truth`
2. `Stage 1 - Single Playback Clock Ownership`
3. `Stage 2 - Professional Live Scrub Engine`
4. `Stage 3 - Zoom And Ruler Canonicalization`
5. `Stage 4 - Trim Interaction Hardening`
6. `Stage 5 - Gesture State Machine Lock`
7. `Stage 6 - Structural Edit Semantics`
8. `Stage 7 - Multi-Track And Mobile Navigation Quality`
9. `Stage 8 - Motion And Text Timeline Integration`
10. `Stage 9 - Performance Hardening`
11. `Stage 10 - Closure And Future-Proof Lock`

## Current Execution State

- `Stage 0 - Baseline Freeze And Instrumented Truth`: accepted and closed
- `Stage 1 - Single Playback Clock Ownership`: accepted and closed
- `Stage 2 - Professional Live Scrub Engine`: parked at an accepted interim
  baseline
- `Stage 3 - Zoom And Ruler Canonicalization`: accepted and closed
- `Stage 4 - Trim Interaction Hardening`: accepted and closed
- `Stage 5 - Gesture State Machine Lock`: accepted and closed
- `Stage 6 - Structural Edit Semantics`: accepted and closed
- `Stage 7 - Multi-Track And Mobile Navigation Quality`: parked at accepted interim baseline
- `Stage 8 - Motion And Text Timeline Integration`: accepted and closed
- `Stage 9 - Performance Hardening`: active

## References

- [Adobe Premiere Pro Timeline preferences](https://helpx.adobe.com/fi/premiere/desktop/get-started/preferences-and-settings/timeline-preferences.html)
- [Final Cut Pro for iPad - Zoom in and out of the timeline](https://support.apple.com/es-us/guide/final-cut-pro-ipad/dev6563543db/ipados)
- [Final Cut Pro for iPad - Extend or shorten timeline clips](https://support.apple.com/es-us/guide/final-cut-pro-ipad/deveddea57f8/ipados)
- [Final Cut Pro for iPad - Snap to items in the timeline](https://support.apple.com/es-us/guide/final-cut-pro-ipad/devef229b805/ipados)
- [Final Cut Pro for iPad - Edit in Position mode](https://support.apple.com/en-bn/guide/final-cut-pro-ipad/devefdc008a7/ipados)
- [DaVinci Resolve 18 Editors Guide](https://documents.blackmagicdesign.com/UserManuals/DaVinci-Resolve-18-Editors-Guide.pdf)
- [Android Media3 ScrubbingModeParameters.Builder](https://developer.android.com/reference/androidx/media3/exoplayer/ScrubbingModeParameters.Builder)
- [Flutter Performance Best Practices](https://docs.flutter.dev/perf/best-practices)
- [Flutter Gestures](https://docs.flutter.dev/ui/interactivity/gestures)
- [Stage 0 Baseline Freeze](/Users/mx/Documents/InGeneBMFPro/docs/process/stage-6-timeline-professionalization-stage-0-baseline-freeze.md)
- [Stage 1 Single Playback Clock Ownership](/Users/mx/Documents/InGeneBMFPro/docs/process/stage-6-timeline-professionalization-stage-1-single-playback-clock-ownership.md)
- [Stage 2 Professional Live Scrub Engine](/Users/mx/Documents/InGeneBMFPro/docs/process/stage-6-timeline-professionalization-stage-2-professional-live-scrub-engine.md)
