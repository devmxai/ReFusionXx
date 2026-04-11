# Future Preview Architecture - Composition-Based Multi-Clip Evaluation

Status: `FUTURE-GATED DRAFT`

## Important Scope Rule

- this document does **not** open a new active implementation slice by itself
- `Stage 6 - Real Import And Timeline Truth` remains the only active open stage
- `Stage 6 / Track B` remains the only legal implementation focus until its current ceiling is documented honestly
- this draft exists to define the first legal preview-architecture escalation path **if** the current `ExoPlayer playlist/clipping` path is confirmed to have reached an unacceptable seam ceiling on the physical device

## Why This Draft Exists

The current runtime path has already received the strongest bounded fixes that fit its architecture:

- cut/delete correctness recovery
- same-source continuity repair
- boundary classification lock
- removal of manual cross-run handoff
- preload / renderer prewarming tuning
- preview retention tuning

Yet device validation still shows a visible residual seam hold at:

- `A -> B`
- and, at times, surviving `A1 -> A3` after deleting a middle region

The product requirement is stricter than “good enough playlist playback”.

For the main editing preview, the user expectation is:

- adjacent clips behave like one continuous timeline
- playback-through-cut feels immediate
- no stale last-frame hold remains
- no deleted time appears to be crossed
- multi-clip preview behaves like an editor composition, not like a consumer playlist

This document defines the future architectural path to evaluate if the current `Media3 ExoPlayer playlist` path is proven insufficient for that requirement.

## Agent Review Summary

This draft is based on the current reviewed consensus:

- `Hypatia`:
  the remaining `A -> B` hold is increasingly likely to be a practical ceiling of the current `ExoPlayer playlist/clipping` preview path, not just a small remaining bug
- `Tesla`:
  `Media3` officially exposes `CompositionPlayer`, but it is still experimental and must not be treated as a drop-in bug fix without a separately gated evaluation
- `Dirac`:
  a composition-backed preview path does not conflict with `BMF` long-term; it is compatible with keeping `BMF` as the later effects/render/export execution layer
- `Nash`:
  the direction is strong only if the editor keeps one canonical composition/timeline truth and does not create a second competing source of truth
- `Maxwell`:
  this is a valid long-term architecture direction, but it is **not** legal to open it as an ad hoc implementation detour inside the current `Stage 6 / Track B` without a formal ceiling judgment and a separately gated future slice

## Official Basis

### What Media3 Officially Supports

Official Media3 documentation and release notes confirm the following:

- `Transformer` supports multi-asset editing concepts with:
  - `EditedMediaItem`
  - `EditedMediaItemSequence`
  - `Composition`
- `CompositionPlayer` exists as an official API
- `CompositionPlayer` is published as experimental and still under development
- `CompositionPlayer` is exposed as a `Player` implementation, which makes it hostable by Media3 UI layers that operate on `Player`

Primary references:

- [Media3 release notes](https://developer.android.com/jetpack/androidx/releases/media3)
- [Media3 Transformer getting started](https://developer.android.com/media/media3/transformer/getting-started)
- [Media3 multi-asset editing](https://developer.android.com/media/media3/transformer/multi-asset)
- [CompositionPlayer API](https://developer.android.com/reference/androidx/media3/transformer/CompositionPlayer)

### What The Official Docs Do Not Promise

The official docs do **not** let us claim that:

- `CompositionPlayer` is already the final stable production answer for every editor use case
- arbitrary cut boundaries always become zero-lag automatically
- all timeline transition patterns are already supported

Officially documented current limitation examples include:

- compositions do not yet support video or audio crossfading in the current `Transformer` composition model
- `CompositionPlayer` remains experimental

Therefore this direction must be evaluated honestly, not sold as a guaranteed silver bullet before validation.

## Architectural Judgment

### Executive Verdict

`Composition-based multi-clip preview` is a strong officially available evaluation direction inside `Media3` for an editor-grade multi-clip preview path.

It is not yet a proven default production path.

It is **not** a cosmetic patch.

It is a real preview-architecture move that better matches editor semantics than raw playlist playback.

### Why It Is Stronger Than The Current Path

The current path treats multi-clip preview mainly as:

- `playlist items`
- plus `clipping`
- plus seam ownership logic

That is fundamentally closer to playback orchestration than to editor composition semantics.

A composition-backed preview path is closer to:

- edited clip sequences
- source windows as first-class editing units
- timeline continuity as an editor concept

This makes it, as an architectural inference rather than a direct official guarantee, a more natural candidate for:

- multi-clip preview continuity
- later effects
- later text and overlay tracks
- later template/preset expansion
- later export alignment

### Why It Does Not Conflict With BMF

This direction remains compatible with the project’s long-term architecture:

- Flutter/project-owned model keeps timeline truth
- `Media3` can own preview playback semantics for the editor
- `BMF` remains the long-term execution/processing/render/export layer candidate

This means:

- preview architecture can improve without sacrificing the later `BMF` path
- normalized composition truth can later feed both:
  - preview
  - export / render

## Non-Negotiable Ownership Rules

If this future track is ever opened, all of the following must remain true:

- Flutter/project-owned model remains the only source of timeline truth
- `Composition-based preview` is read-only with respect to timeline semantics
- preview does not invent clip ordering, merge deleted time back in, or reinterpret structural edits
- `single-clip fast path` may exist only as an optimization, never as a second editor truth
- export ownership remains separate and future-gated

## When This Track Becomes Legal

This draft becomes legal to open only after all of the following are documented:

1. the current `Stage 6 / Track B` path has restored cut/delete correctness
2. the accepted scrub baseline remains preserved
3. a physical-device ceiling check confirms that residual seam hold remains materially unacceptable on the current `ExoPlayer playlist/clipping` path
4. the ceiling is documented honestly rather than hidden behind UI masking
5. the next allowed step is updated explicitly to authorize this evaluation slice

Until then, this document is reference-only.

## What This Future Track Would Evaluate

If opened, the evaluation would focus only on:

- replacing the current multi-clip preview projection for the main video track
- using a composition-backed preview model for adjacent edited clips
- comparing seam continuity against the current playlist path on a real device
- preserving current cut/delete truth
- preserving the current scrub baseline or improving it without regression

It would not immediately include:

- export
- BMF render/export changes
- text animation system
- motion-authoring system
- template system
- full transitions engine

## First Legal Evaluation Slice

If this future track is activated, the first allowed slice is:

`Composition-Based Preview Baseline`

Its goal is only to prove:

- two adjacent video clips can preview through a composition-backed path
- cut/delete truth is preserved
- `A -> B` seam continuity is materially better than the current playlist baseline
- no new crash or scrub regression is introduced

That slice is **not** full editor migration.

## Required Success Criteria

This direction should be considered successful only if device validation proves:

- `A -> B` is materially smoother than the current playlist path
- `A1 -> A3` after middle delete is materially smoother than the current playlist path
- deleted time never reappears
- playhead truth remains aligned with preview truth
- scrub does not regress
- no new preview crashes are introduced

## Failure Criteria

This direction should be rejected or paused if:

- it introduces a second source of truth
- it regresses cut/delete correctness
- it destabilizes scrub
- it produces no meaningful seam improvement on device
- the experimental API surface proves too unstable for the current project stage

## Relationship To Export

This document does **not** open export work.

However, if successful, it would strengthen the long-term architecture by aligning:

- editor timeline semantics
- preview semantics
- future normalized composition model
- later export orchestration

This is a compatibility benefit, not permission to start export now.

## Governance Verdict

The reviewed verdict is:

- long-term architectural direction: `YES`
- legal immediate implementation inside current `Track B`: `NO`
- legal future-gated evaluation after ceiling confirmation: `YES`

## References

- [Stage 6 Real Import And Timeline Truth](/Users/mx/Documents/InGeneBMFPro/docs/process/stage-6-real-import-and-timeline-truth.md)
- [Stage 6 Track B - Edit Correctness And Seam Continuity Recovery](/Users/mx/Documents/InGeneBMFPro/docs/process/stage-6-track-b-edit-correctness-and-seam-continuity-recovery.md)
- [Stage 6 Closure Checklist](/Users/mx/Documents/InGeneBMFPro/docs/process/stage-6-closure-checklist.md)
- [Future Stage 7 Draft - Export Contract And Native Orchestration Baseline](/Users/mx/Documents/InGeneBMFPro/docs/process/future-stage-7-export-contract-and-native-orchestration-baseline.md)
- [BMF Motion Architecture Feasibility](/Users/mx/Documents/InGeneBMFPro/docs/research/bmf-motion-architecture-feasibility.md)
- [Media3 release notes](https://developer.android.com/jetpack/androidx/releases/media3)
- [Media3 multi-asset editing](https://developer.android.com/media/media3/transformer/multi-asset)
- [CompositionPlayer API](https://developer.android.com/reference/androidx/media3/transformer/CompositionPlayer)
