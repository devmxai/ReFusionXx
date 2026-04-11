# Future Stage 7 Draft - Export Contract And Native Orchestration Baseline

Status: `FUTURE-GATED DRAFT`

## Important Scope Rule

- this document does **not** open `Stage 7`
- `Stage 6 - Real Import And Timeline Truth` remains the only active open stage
- this draft exists only to define the first export phase that becomes legal **after** `Stage 6` is closed

## Why This Draft Exists

The project now has:

- real import
- native preview / transport
- accepted scrub and seam baselines
- accepted timeline truth baseline

But it still does **not** have:

- a real export pipeline
- an export composition model
- native export orchestration
- output-file validation

This draft prevents premature or patchy export work by defining the first correct export entry point before implementation begins.

## Official Constraints

### Project Ownership Lock

From `Stage 4`:

- Flutter owns editor UI and timeline presentation
- Android native / `Media3` owns preview transport
- `BMFLite / BMF` owns processing and effects
- export orchestration must be **project-owned native integration**

Reference:

- [stage-4-architecture-lock.md](/Users/mx/Documents/InGeneBMFPro/docs/process/stage-4-architecture-lock.md)

### BMF / BMFLite Official Interpretation

Official review for this draft concluded:

- `BMF` is suitable as an export processing/runtime backend
- `BMF` officially supports graph-based media processing with decode, filter, concat, overlay, encode, and mux workflows
- `BMFLite` must **not** be assumed to be the primary export stack without stronger official evidence
- the safe first export path should target `BMF` full export processing, with `BMFLite` remaining optional for later client-side processing needs

Official references:

- [BMF overview](https://babitmf.github.io/docs/bmf/overview/)
- [BMF FFmpeg compatibility](https://babitmf.github.io/docs/bmf/multiple_features/ffmpeg_fully_compatible/)
- [BMF filter module](https://babitmf.github.io/docs/bmf/api/filter_module/)
- [BMF encode module](https://babitmf.github.io/docs/bmf/api/encode_module/)
- [BMF GitHub](https://github.com/BabitMF/bmf)

### Media3 Official Interpretation

Official review for this draft concluded:

- `Media3` is not preview-only; Android also provides `Transformer`
- however, the project must **not** blur preview ownership and export ownership
- `Media3 ExoPlayer` remains the preview / transport authority in the current app
- the export phase must still be opened as a separate native export orchestration layer
- if `Media3 Transformer` is evaluated later, it must be evaluated as a bounded export backend, not as the owner of the whole export architecture

Official references:

- [Android audio and video overview](https://developer.android.com/media/audio-and-video)
- [Media3 Transformer](https://developer.android.com/media/media3/transformer)
- [Media3 multi-asset editing](https://developer.android.com/media/media3/transformer/multi-asset)
- [Transformer API reference](https://developer.android.com/reference/androidx/media3/transformer/Transformer)

## Current Readiness Judgment

Current code review concluded:

- the app has no export pipeline today
- the share/export UI remains a placeholder only
- `Stage 6` is still open
- the current source of truth suitable for future export is the Flutter timeline truth:
  - track ordering
  - clip ordering
  - clip source URI / asset identity
  - clip source offsets
  - clip durations
  - imported media metadata needed for composition

This means:

- preview state must not become export state
- playback position must not become export truth
- UI-only selection state must not become export truth

## First Legal Export Phase

The first legal export phase, once `Stage 6` is closed, is:

`Stage 7 - Export Contract And Native Orchestration Baseline`

Its purpose is **not** to deliver full editor export.

Its purpose is only to create:

- a normalized export composition contract
- a native export orchestrator
- a first real output-file baseline

## Stage 7 Phase 1 Definition

### Goal

Build the smallest real export baseline that proves the architecture is correct.

### Allowed Scope

- single video track only
- imported media only
- clip windows from timeline truth only
- native export orchestration only
- one output file only
- progress / success / failure reporting only
- no effects beyond what is required to prove cut / concat correctness

### Explicitly Not Included

- multi-track export
- text export
- image overlay export
- transition export
- template export
- AI/script-driven motion export
- BMFLite live runtime integration changes
- 4K optimization claims
- screen-capture-based export
- preview-state capture as export

## Required Architecture For Phase 1

Phase 1 must define all of the following before any export code is considered complete:

1. `ExportComposition`
- normalized from Flutter timeline truth
- no preview-only state
- no UI-only state

2. `ExportBridgeContract`
- Flutter requests export
- native owns execution
- progress is explicit
- completion is explicit
- failure is explicit

3. `Native Export Orchestrator`
- receives normalized composition
- builds the export graph / pipeline
- writes output to a real file path
- reports lifecycle events back to Flutter

4. `Backend Boundary`
- `ExoPlayer` remains preview transport only
- export backend is evaluated independently
- `BMF` full is the primary official export-processing candidate for the first baseline

## First Baseline Output

The first accepted export baseline must prove only this:

- one imported source clip can export correctly
- two adjacent clips can export correctly in the right order
- trim / source offset is honored
- output file exists
- output file plays
- output duration is sane
- output aspect ratio is sane

This is the first real closure target.

It is intentionally smaller than:

- full editor parity
- performance tuning
- 4K export

## Validation Rules

Every export slice must follow the same strict loop:

1. implement one bounded change only
2. build and run on device
3. verify expected behavior
4. inspect errors immediately if behavior deviates
5. fix regressions before moving on
6. update documentation before the next slice

## Exit Gates For The Future Stage 7 Phase 1

Phase 1 may be accepted only when all of the following are true:

- `Stage 6` is already closed first
- a real export request reaches native code through a stable bridge contract
- native export produces a real playable output file
- the output reflects timeline clip ordering and trim truth
- progress / success / failure are observable in the app
- preview / scrub / timeline behavior from the accepted baseline does not regress

## Forbidden Work Before Stage 6 Closure

The following remain forbidden while `Stage 6` is still open:

- starting real export code
- declaring `Stage 7` active
- changing the current `Next Allowed Step`
- treating the share button as real export
- using preview capture as export
- using player state as export truth
- expanding scope to 4K, transitions, overlays, or templates

## Future Queue After Phase 1

Only after the first export baseline is accepted should the queue expand to:

1. multi-clip parity improvements
2. audio correctness
3. image / text / overlay support
4. transition export
5. performance and 4K benchmarking

## Supervisory Judgment

Current supervisory judgment from `Maxwell`:

- implementation of export code now: `stop`
- future-gated draft definition now: `adjust` and allowed
- official Stage 7 opening: blocked until `Stage 6` closes
