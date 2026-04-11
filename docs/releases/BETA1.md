# BETA1

## Status

- snapshot type: `beta tag`
- repository: `https://github.com/devmxai/ReFusionXx`
- tag target branch at creation time: `main`
- app version: `1.0.0-beta.1+1`
- current timeline stage: `Stage 9 - Performance Hardening`
- timeline stage status: `active`
- export/effects track status: `paused at documented handoff`

## Scope

`BETA1` is the first official snapshot in the new `ReFusionXx` repository.

It preserves the full current project state by importing the validated legacy
workspace snapshot that had most recently shipped in the earlier repository as
`BETA15`.

This beta captures the project at the point where:

- same-track video reorder now enters through an animated morph into compact
  cards with stronger magnetic insertion feedback
- the reorder card state no longer leaves the original long strip visible under
  the compact UI and no longer shows the temporary side handle
- the reorder animation crash was fixed at the root by allowing the timeline
  panel to own both required tickers safely
- non-video timeline clips now move in time with real preserved gaps instead of
  pretending to be reorder-only clips
- gaps before moved non-video clips render as true empty timeline space instead
  of `+` placeholder cards
- moved motion-text clips now obey their shifted real start time during
  preview/runtime evaluation
- moving non-video clips no longer auto-jumps the playhead or recenters the
  visible timeline

## What This Snapshot Includes

### Timeline

The current timeline snapshot now includes:

1. neutral monochrome lane visuals below the ruler
2. insertion-driven track creation instead of pre-seeded empty rows
3. background scrub gesture coverage across track and empty timeline regions
4. animated long-press reorder entry into compact same-track cards
5. stronger same-track magnetic insertion feedback during reorder
6. hidden base-row strip during reorder card mode
7. global pointer-backed reorder drag continuity after the row morph
8. true temporal movement for non-video clips with preserved empty gaps
9. runtime-correct shifted timing for moved motion-text clips
10. no automatic playhead jump during non-video clip movement

Primary timeline references at this snapshot:

- [Stage 6 Timeline Professionalization Master Plan](/Users/mx/Documents/InGeneBMFPro/docs/process/stage-6-timeline-professionalization-master-plan.md)
- [Stage 6 Timeline Professionalization - Stage 9 Performance Hardening](/Users/mx/Documents/InGeneBMFPro/docs/process/stage-6-timeline-professionalization-stage-9-performance-hardening.md)
- [Stage 6 Timeline Professionalization - Track Manipulation And Interaction Plan](/Users/mx/Documents/InGeneBMFPro/docs/process/stage-6-timeline-professionalization-track-manipulation-and-interaction-plan.md)
- [Current Thread Handoff And Resume Packet](/Users/mx/Documents/InGeneBMFPro/docs/process/current-thread-handoff-and-resume-packet.md)

### Export / Effects

The export/effects track in this beta is intentionally unchanged in execution
scope from the documented handoff state.

Primary export references at this snapshot:

- [Professional Export Subsystem Handoff And Resume Map](/Users/mx/Documents/InGeneBMFPro/docs/process/professional-export-subsystem-handoff-and-resume-map.md)
- [Professional Export Audit Gap And Cleanup Plan](/Users/mx/Documents/InGeneBMFPro/docs/process/professional-export-audit-gap-and-cleanup-plan.md)
- [Professional Effects Render And Export Plan](/Users/mx/Documents/InGeneBMFPro/docs/process/professional-effects-render-and-export-plan.md)

## Engineering Meaning Of This Snapshot

At `BETA1`, the timeline is materially stronger in four practical ways:

- the long-press reorder interaction is closer to a deliberate professional
  mobile editing experience
- non-video clips now obey real time placement semantics instead of visual-only
  shifting
- motion-text timing now follows the moved clip's actual project range during
  runtime evaluation
- the user's playhead is no longer hijacked while moving non-video clips

This beta should be treated as:

- a pushed manipulation checkpoint
- a resume-safe documentation checkpoint
- a stronger base for the next focused on-device acceptance pass

## What Is Still Open

This snapshot does **not** mean timeline manipulation is fully accepted.

Still open after `BETA1`:

1. focused on-device validation for first-insert track creation with:
   - video
   - image
   - audio
   - text preset
2. focused on-device validation that scrub behaves correctly from:
   - track surfaces
   - empty timeline regions
3. focused on-device validation that reorder remains precise on short and long
   clip rows
4. focused on-device validation that non-video movement remains precise and
   runtime-correct after drop
5. Stage 9 remains active

Export/effects also remains open:

1. the same paused handoff from the post-`BETA13` export documentation remains
   the correct resume point
2. this beta does not widen export runtime support

## Validation Snapshot

The validation completed for this snapshot includes:

- `dart format`
- `flutter analyze`
- `flutter build apk --debug`
- latest `adb install -r .../app-debug.apk` completed on the connected device
  with:
  - package: `com.fusionx.fusionx_clean_ui_2`
  - device: `SM-S908N`
  - `versionName = 1.0.0-beta.1`
  - `lastUpdateTime = 2026-04-11 04:19:30`

## Resume Point

If work resumes later with:

`continue timeline plan`

the correct next timeline reference is:

- [Stage 6 Timeline Professionalization - Track Manipulation And Interaction Plan](/Users/mx/Documents/InGeneBMFPro/docs/process/stage-6-timeline-professionalization-track-manipulation-and-interaction-plan.md)

If work resumes later with:

`continue export plan`

the correct export reference is:

- [Professional Export Subsystem Handoff And Resume Map](/Users/mx/Documents/InGeneBMFPro/docs/process/professional-export-subsystem-handoff-and-resume-map.md)
