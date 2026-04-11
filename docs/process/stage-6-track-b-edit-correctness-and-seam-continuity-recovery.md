# Stage 6 Track B - Edit Correctness And Seam Continuity Recovery

## Status

Active.

This document is the only authorized execution plan for the current `Stage 6 / Track B` blocker.

All non-preservation work outside this slice is blocked until this slice is accepted on a real device.

Allowed exception:

- baseline-preservation fixes for the already accepted `Track A` contract, if a new `Track B` change accidentally regresses it

## Why This Slice Exists

Current device validation shows two related failures:

1. cut/delete correctness can still degrade after multiple structural edits, especially when the same track later contains more than one source
2. playback can still hitch at the seam between surviving clip pieces or between two adjacent source files

In practical terms, the user can:

- split one clip into several pieces
- delete a middle piece
- add another video later on the same main track

and then observe one or more of these failures:

- deleted time appears to come back during playback
- a short surviving piece plays as if the full source is still active
- the playhead freezes while the preview keeps moving
- the last frame of the left clip hangs too long before the next clip appears

This means `Track B` is no longer just "cross-source seam polish".
It is now the root playback-correctness slice for:

- runtime-real cuts
- runtime-real deletes
- deterministic playhead truth
- seam continuity at clip boundaries

## Agent Review Summary

The current plan is based on a reviewed consensus:

- `Hypatia`:
  current failures are primarily in native runtime projection and seam/run semantics, not in Flutter's basic timeline truth
- `Tesla`:
  official `Media3` documentation supports playlists, clipping, and preload, but does not guarantee zero-lag arbitrary cut boundaries, especially when clip starts are not keyframe-safe
- `Raman`:
  mainstream editor semantics require ripple delete on the main track, runtime-real surviving pieces, and boundary crossing that behaves like one continuous timeline
- `Maxwell`:
  it is valid to block all other implementation work until this slice is accepted, provided we keep `Track A` preservation legal and do not mix this work with export, picker polish, or UI masking

## Official Constraints We Must Respect

This slice must stay inside the current real runtime architecture:

- Flutter owns:
  - clip order
  - clip durations
  - source windows
  - timeline truth
- native `Media3` transport owns:
  - playback handoff
  - player projection
  - seam traversal

This slice must not pretend that `BMF` is the live playback owner today.
For the current app build, the live preview path is still:

- `Flutter -> MethodChannel -> Stage5TransportManager -> Media3/ExoPlayer -> PlayerView`

That means:

- `BMF` is not the root cause of this blocker
- `Media3` seam and clipping behavior is the relevant official constraint

Important official limits:

- `MediaItem.ClippingConfiguration` does not guarantee a seamless transition into a clip if the clip start is not keyframe-safe
- exact seeking has real decoder cost and cannot be treated as free
- preload is an optimization, not a correctness guarantee

Therefore this slice can require:

- runtime-correct cuts and deletes
- strong seam continuity
- no fake UI-only cuts
- no heavy hitch

but it must not claim undocumented guarantees from `Media3`.

If a zero-lag ceiling remains after the correctness work is complete, that must be recorded honestly as a runtime-architecture limit, not hidden by a cosmetic patch.

## Non-Negotiable Semantic Contract

For the main video track, the product contract is:

- `split` creates independently addressable pieces with exact source windows
- `delete` on the main track behaves as ripple delete
- the removed duration disappears from the timeline completely
- the surviving left and right clips become direct neighbors with zero timeline gap
- playback after delete must reflect only the surviving clips
- the deleted region must never reappear during playback
- the playhead must advance in timeline time, not in stale source time
- crossing from one clip to the next must hand off to the right clip without stale replay, fake deleted time, or visually broken boundary ownership

This contract applies equally to:

- a single imported source split into many pieces
- multiple sources on the same track
- mixtures of same-source pieces plus later cross-source clips

## Scope

This slice includes only:

- structural edit correctness after `split`, `delete`, `trim`, `duplicate`, and later `add`
- playhead correctness after structural edit commits
- same-source gapped seam behavior after deleting a middle region
- adjacent cross-source seam behavior on normal playback
- scrub no-regression gates relevant to seam work

This slice excludes:

- picker / bottom-sheet work
- export
- BMFLite runtime processing
- transitions/effects authoring
- text animation
- proxy/preview architecture changes outside what is needed to document a hard limit

## Strict Problem Statement

We must stop treating every boundary as the same kind of boundary.

At runtime, every boundary between clip `N` and clip `N+1` must be classified as exactly one of:

1. `same-source contiguous seam`
2. `same-source gapped seam`
3. `cross-source seam`

The runtime path must preserve this classification all the way into native playback projection.

Without this, multiple structural edits collapse into ambiguous playback behavior.

## Required Ownership Lock

This slice is valid only if all of the following remain true:

- Flutter remains the only owner of timeline truth
- native does not invent, merge, or reinterpret deleted source time back into the sequence
- there is exactly one authoritative seam path during validation
- scrub safety invariants from the accepted seam baseline remain intact:
  - no `setMediaItems(...)` during active scrub
  - no `prepare()` during active scrub
  - no double-seek ownership
  - no follow-up correction seek fighting the current seek

## Forbidden Work

The following are forbidden until this slice is accepted:

- opening export work
- opening Stage 7
- picker or bottom-sheet performance work
- UI masking that hides hitch or stale playback
- making native the source of timeline truth
- weakening the accepted scrub baseline just to make seam playback look better
- mixing this plan with unrelated polish

## Execution Plan

The execution order inside `Track B` is now locked as follows:

1. `Phase 1 - Boundary Classification Lock`
2. `Phase 2A - Structural Edit Commit Recovery`
3. `Phase 2 - Structural Edit Projection Correctness`
4. `Phase 2B - Time-Exact Timeline Geometry`
5. `Phase 3 - Authoritative Playback Path Lock`
6. `Phase 4 - Playhead Truth Recovery`
7. `Phase 5 - Seam Continuity Recovery`
8. `Phase 6 - Ceiling Check Against Official Constraints`

This order is intentional:

- structural edit commit safety must be restored before more seam work
- runtime-real surviving windows must be correct before seam smoothness is tuned further
- time-exact visual geometry must follow runtime truth, not lead it

### Phase 1 - Boundary Classification Lock

Goal:

- make every runtime boundary explicit before any further playback changes

Required outcome:

- each adjacent pair of clips is classified as:
  - same-source contiguous
  - same-source gapped
  - cross-source
- this classification becomes part of the projected runtime model for `Track B`

Blocked if:

- any runtime path still infers boundary type implicitly from a flat playlist only

### Phase 2A - Structural Edit Commit Recovery

Goal:

- treat `split`, `delete`, `trim`, and `duplicate` as explicit structural edit commits, not as ordinary mutations on an already hot runtime path

Required outcome:

- active scrub state is fully closed before a structural edit commit is projected
- native receives one committed post-edit projection only
- previous decoder/playlist ownership is shut down cleanly before the new post-edit projection becomes authoritative
- deleting the middle piece from `A1/A2/A3` leaves `A1/A3` as the only surviving source windows in runtime playback
- `MediaCodecVideoRenderer` / `CodecException` / `Unexpected runtime error` no longer appears as part of the post-edit commit path

Blocked if:

- deleting a middle segment can still tear down the renderer into an unstable state
- post-edit playback still depends on stale player ownership from the pre-edit projection

### Phase 2 - Structural Edit Projection Correctness

Goal:

- after any structural edit commit, native playback must reflect the exact surviving clip windows and nothing else

Required outcome:

- delete removes only the selected timeline duration
- surviving clips keep their exact source windows
- no deleted source time can re-enter playback
- a short surviving piece never plays as if its full source is still active

Blocked if:

- a deleted middle region still appears during playback
- a surviving short piece expands back into the original source

### Phase 2B - Time-Exact Timeline Geometry

Goal:

- make the visible cut position match timeline time exactly, instead of allowing minimum-width clip rendering to distort the cut location

Required outcome:

- the visible cut seam is anchored to real timeline time
- the playhead position, split point, cut marker, seam marker, and runtime projection all derive from one canonical timeline coordinate
- split/delete no longer look like they "shift" or "refresh" the green track to a different time than the playhead

Blocked if:

- the user can still place the playhead at one second and see the cut render as if it happened somewhere else
- split/delete still appear visually unstable because geometry is dominated by minimum-width clip rendering

### Phase 3 - Authoritative Playback Path Lock

Goal:

- choose one authoritative playback projection for post-edit playback and disable competing interpretations

Required outcome:

- after structural edit commit, playback uses one stable projection path only
- same-source contiguous runs may preserve continuity
- same-source gapped seams are not flattened into a fake continuous source
- cross-source seams remain explicit boundaries

Blocked if:

- the same edit can still be interpreted differently by two runtime paths

### Phase 4 - Playhead Truth Recovery

Goal:

- the playhead must move according to timeline time, not stale source time

Required outcome:

- playhead position after delete/play matches surviving timeline duration exactly
- the playhead never freezes at an old seam while the preview continues as if the source were uncut
- playback state and visible preview agree on the active surviving clip

Blocked if:

- the playhead stops while the preview keeps playing stale source content

### Phase 5 - Seam Continuity Recovery

Goal:

- remove the obvious last-frame hold and heavy hitch at surviving seams without regressing scrub

Required outcome:

- same-source gapped seams no longer feel like deleted time is still being crossed
- cross-source seams no longer hold the last frame of the left clip for an obviously incorrect extra beat
- scrub remains at least as good as the accepted current baseline

Blocked if:

- same-source split/delete seams regress again
- cross-source seam still looks visibly broken on device
- scrub regresses

### Phase 6 - Ceiling Check Against Official Constraints

Goal:

- determine honestly whether the remaining seam behavior is still within the current `Media3` ceiling

Required outcome:

- if the seam result is accepted on device, `Track B` can close
- if a visible residual hitch remains that cannot be removed without breaking official constraints, this must be documented as a current-path ceiling and escalated as a future preview-architecture decision

Blocked if:

- we hide a real runtime limit behind cosmetic behavior

## Required Device Validation Matrix

`Track B` is not accepted until all of these pass on the physical device:

1. import video `A`
2. split `A` into at least four pieces
3. delete the second piece
4. delete another middle piece
5. play through the surviving `A` pieces
6. confirm deleted source time never reappears
7. confirm a surviving short piece does not play as the full original source
8. import video `B`
9. play `A-survivors -> B`
10. confirm the seam does not show black, stale replay, or obvious last-frame hold
11. scrub across the same seams
12. confirm accepted scrub baseline is not regressed

## Acceptance Criteria

`Track B` closes only if:

- cuts are runtime-real, not visual-only
- deletes are ripple-real on the main track
- surviving pieces keep exact source truth after multiple edits
- no deleted region reappears in playback
- playhead truth matches preview truth
- same-source gapped seams are correct and materially smooth
- cross-source seams are correct and materially smooth
- accepted scrub quality is preserved

## Exact Next Allowed Step

The next allowed implementation step is:

- `Phase 2A - Structural Edit Commit Recovery`
- followed immediately by:
  - `Phase 2 - Structural Edit Projection Correctness`
  - `Phase 2B - Time-Exact Timeline Geometry`

No further seam polish may begin until those phases are completed and revalidated on the device.

## References

- [Stage 6 Real Import And Timeline Truth](/Users/mx/Documents/InGeneBMFPro/docs/process/stage-6-real-import-and-timeline-truth.md)
- [Stage 6 Seam Boundary Stabilization](/Users/mx/Documents/InGeneBMFPro/docs/process/stage-6-seam-boundary-stabilization.md)
- [Stage 6 Closure Checklist](/Users/mx/Documents/InGeneBMFPro/docs/process/stage-6-closure-checklist.md)
- [Future Preview Architecture - Composition-Based Multi-Clip Evaluation](/Users/mx/Documents/InGeneBMFPro/docs/process/future-preview-architecture-composition-based-multi-clip-evaluation.md) `reference-only`
- [Media3 Playlists](https://developer.android.com/media/media3/exoplayer/playlists)
- [MediaItem.ClippingConfiguration.Builder](https://developer.android.com/reference/androidx/media3/common/MediaItem.ClippingConfiguration.Builder)
- [Media3 Preload Manager](https://developer.android.com/media/media3/exoplayer/preloading-media/preloadmanager/create)
- [Media3 Troubleshooting](https://developer.android.com/media/media3/exoplayer/troubleshooting)
- [BMF Overview](https://babitmf.github.io/docs/bmf/overview/)
