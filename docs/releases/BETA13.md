# BETA13

## Status

- snapshot type: `beta tag`
- repository: `https://github.com/devmxai/FBMFX`
- tag target branch at creation time: `codex/timeline-motion-progress`
- app version: `1.0.0-beta.13+13`
- current timeline stage: `Stage 9 - Performance Hardening`
- timeline stage status: `active`
- export/effects track status: `active handoff recorded, not closed`

## Scope

`BETA13` preserves the project after the recent export/effects architecture
wave and the documentation handoff that freezes the exact resume point for each
subsystem before opening the next timeline-focused workstream.

This beta captures the project at the point where:

- the export system is no longer only baseline media export
- motion text has a stronger deterministic and GL-assisted effects lane
- non-text authored visuals now exist in graph/program/runtime truth
- timeline continuation is documented through a dedicated manipulation plan

## What This Snapshot Includes

### Export / Effects

The current export/effects snapshot now includes:

1. real `Media3 Transformer` export backbone
2. canonical `ExportComposition` and `canonicalEffectsGraph`
3. stronger deterministic motion-text export lane
4. shaped paragraph/full-text layout semantics for motion text before blur
5. first isolated overlay-sequence GL effect stack for:
   - `GaussianBlur`
   - `AlphaScale`
6. `Canonical Effects` diagnostics in native export and UI
7. `Motion/Text Parity` diagnostics tied to the actual runtime-preferred path
8. real `visualCompositorGraph` routing for authored overlays
9. first `authoredVisualSurfaceProgram` for:
   - image
   - shape
   - mask
   - videoClip
10. first native authored-surface runtime evaluator that resolves:
    - transform
    - opacity
    - blur
    - shape sizing
11. `Authored Surfaces` diagnostics in the export sheet
12. explicit export subsystem handoff/resume documentation

Primary export references at this snapshot:

- [Professional Export Audit Gap And Cleanup Plan](/Users/mx/Documents/InGeneBMFPro/docs/process/professional-export-audit-gap-and-cleanup-plan.md)
- [Professional Effects Render And Export Plan](/Users/mx/Documents/InGeneBMFPro/docs/process/professional-effects-render-and-export-plan.md)
- [Professional Export Subsystem Handoff And Resume Map](/Users/mx/Documents/InGeneBMFPro/docs/process/professional-export-subsystem-handoff-and-resume-map.md)

### Timeline

The current timeline snapshot now includes:

1. current master-plan state still recorded with `Stage 9` active
2. a separate scoped plan for the next manipulation-focused timeline wave
3. documented pause boundary between export/effects continuation and timeline
   continuation

Primary timeline references at this snapshot:

- [Stage 6 Timeline Professionalization Master Plan](/Users/mx/Documents/InGeneBMFPro/docs/process/stage-6-timeline-professionalization-master-plan.md)
- [Stage 6 Timeline Professionalization - Stage 9 Performance Hardening](/Users/mx/Documents/InGeneBMFPro/docs/process/stage-6-timeline-professionalization-stage-9-performance-hardening.md)
- [Stage 6 Timeline Professionalization - Track Manipulation And Interaction Plan](/Users/mx/Documents/InGeneBMFPro/docs/process/stage-6-timeline-professionalization-track-manipulation-and-interaction-plan.md)

## Engineering Meaning Of This Snapshot

At `BETA13`, the project is materially stronger in two ways:

- export/effects work is now recoverable per subsystem instead of as one vague
  unfinished track
- timeline work can now continue in a scoped way without losing the exact
  resume point for:
  - effects
  - transitions
  - camera
  - compositor
  - audio/speed

This beta should be treated as:

- a strong architectural/export checkpoint
- a documentation and resume-safety checkpoint
- a clean handoff point before the next timeline manipulation phase

## What Is Still Open

This snapshot does **not** mean export is closed.

Still open after `BETA13`:

1. broader shared authored-surface backend routing
2. image/shape execution through the shared isolated effects lane
3. final compositor-backed authored multi-layer execution
4. transition execution
5. camera execution
6. richer audio graph and curve-speed export
7. stronger device acceptance and visual validation for effects parity

Timeline also remains open:

1. Stage 9 is still active
2. the next manipulation workstream has only been planned, not implemented yet

## Validation Snapshot

The latest local validation completed for this snapshot includes:

- `flutter analyze`
- `flutter test test/export_composition_builder_test.dart test/motion_text_raster_contract_test.dart`
- `./android/gradlew -p android app:compileDebugKotlin`

## Resume Point

If work resumes later with:

`continue export plan`

the correct export reference is:

- [Professional Export Subsystem Handoff And Resume Map](/Users/mx/Documents/InGeneBMFPro/docs/process/professional-export-subsystem-handoff-and-resume-map.md)

If work resumes later with:

`continue timeline plan`

the correct next timeline reference is:

- [Stage 6 Timeline Professionalization - Track Manipulation And Interaction Plan](/Users/mx/Documents/InGeneBMFPro/docs/process/stage-6-timeline-professionalization-track-manipulation-and-interaction-plan.md)
