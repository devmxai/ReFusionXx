# Stage 6 Seam Boundary Stabilization

## Goal

- remove the crash when scrubbing across the seam between adjacent clips on the same main video track
- preserve live scrub quality as much as possible while eliminating seam-specific transport instability
- do this without workaround-only logic that would block future professional timeline work

## Why This Slice Exists

Current Stage 6 validation shows:

- single-clip import, playback, and scrub are accepted
- multi-clip scrub can still crash when the playhead crosses a seam between `clip1` and `clip2`
- earlier seam-protection attempts either:
  - prevented the crash but killed live scrub, or
  - restored live scrub but brought the crash back

This means the current issue is not a small bug. It is a seam-boundary stability problem in the current playback model.

## Official Constraints

The following constraints are grounded in official Android `Media3` documentation:

- `Player.setMediaItems(...)` clears the playlist; for in-place timeline changes, `replaceMediaItems`, `removeMediaItems`, and `moveMediaItems` are the official direct mutation APIs:
  [Player](https://developer.android.com/reference/androidx/media3/common/Player)
- `ExoPlayer.setScrubbingModeEnabled(true)` is intended for user scrubbing sessions and should remain a short-lived interaction mode:
  [ExoPlayer](https://developer.android.com/reference/androidx/media3/exoplayer/ExoPlayer)
- current official `Media3 1.9.x` release notes include seam-relevant scrub fixes:
  - seeking into other media items while in scrubbing mode could cause `IllegalStateException`
  - seeking near the end of a media item in scrubbing mode could jump to the next media item
  These fixes make `1.9.x` the strongest official baseline for this slice, even though it raises `minSdk` to `23`:
  [Media3 release notes](https://developer.android.com/jetpack/androidx/releases/media3)
- `PlayerView.setKeepContentOnPlayerReset(true)` is an official way to reduce black-frame flashes when the player is reset or re-prepared:
  [PlayerView](https://developer.android.com/reference/androidx/media3/ui/PlayerView)
- `MediaItem.ClippingConfiguration.Builder.setStartsAtKeyFrame(...)` matters for clip-boundary behavior; if the start is not guaranteed to be a key frame, transitions into the clip may not be seamless:
  [ClippingConfiguration.Builder](https://developer.android.com/reference/androidx/media3/common/MediaItem.ClippingConfiguration.Builder)
- `DefaultPreloadManager` is the official preload path for neighboring items, but it is an optimization layer, not the first-line fix for broken seam ownership:
  [DefaultPreloadManager](https://developer.android.com/media/media3/exoplayer/preloading-media/preloadmanager/create)

## Architectural Inference

The following decisions are project-owned architectural rules. They are compatible with the official APIs, but they are not quoted as formal `Media3` guarantees:

- all internal clip windows are treated as half-open intervals: `[startMs, endMs)`
- any seam shared by `clip1` and `clip2` is interpreted as the start of `clip2`
- no internal clip except the last clip may be targeted with an exact seek to its logical end
- Flutter owns timeline truth; native Android owns playback handoff only

## Ownership Lock

This slice is valid only if the ownership split stays strict:

- Flutter owns:
  - clip order
  - clip durations
  - clip source windows
  - track layout truth
- Native Android / `Media3` owns:
  - player lifecycle
  - preview surface
  - seam playback handoff
  - scrub transport behavior

Native must not become the source of timeline truth in this slice.

## Scope

This slice covers only:

1. seam-boundary interpretation
2. seam-safe seek mapping
3. scrub-time boundary handling
4. stable playlist mutation strategy
5. preview reset protection
6. device validation at seam boundaries

This slice does **not** cover:

- bottom-sheet thumbnail performance
- transitions/effects
- export
- BMFLite live processing
- iOS parity
- proxy/preview media generation

## Required Exit Gates Before Implementation

These gates were required by the monitor review and are now adopted as mandatory:

- the seam contract must be documented before any code change
- the ownership matrix must remain explicit: Flutter timeline truth, native seam handoff only
- during scrub there must be:
  - zero `setMediaItems(...)`
  - zero `prepare()`
  - zero follow-up correction seeks
  - zero double-seek ownership
- outside scrub there must be no exact seek to the logical end of an internal clip
- only one seam path may be active during validation; any fragile legacy fast path must be disabled or placed behind a flag
- regression validation must confirm:
  - import still works
  - accepted scrub baseline does not regress
  - selection contract does not regress
  - preview does not reintroduce avoidable black flashes

## Execution Order

The architecture reviewer and monitor both required the following order:

### Phase 1 - Boundary Contract

- raise the app to the strongest official seam/scrub baseline first:
  - `Media3 1.9.x`
  - `minSdk 23`
- formalize seam mapping as `[start, end)` for all internal clips
- treat `timelinePosition == seam` as `clip2@0`
- allow exact logical end only for the final clip in the active sequence

### Phase 2 - Single Seam Owner

- remove any dual ownership between:
  - global timeline seek mapping
  - player boundary correction
- there must be exactly one native seam handoff path during playback and scrub

### Phase 3 - Stable Seek Mapping

- rebuild `resolveTimelineSeekPoint(...)` to be deterministic and boundary-safe
- never return an internal clip target equal to its logical end
- guarantee stable mapping for:
  - slow scrub
  - fast scrub
  - play-through at seam

### Phase 4 - Stable Playlist Strategy

- keep the playlist shape fixed during an active scrub session
- do not call `setMediaItems(...)` or `prepare()` during scrub
- for edit-time updates, prefer official direct mutation APIs where applicable:
  - `replaceMediaItems`
  - `removeMediaItems`
  - `moveMediaItems`
- only after phases 1 to 4 are stable may we consider adjacent-item preload

### Phase 5 - Preview Reset Protection

- keep `setKeepContentOnPlayerReset(true)`
- do not use visual protection as a substitute for boundary correctness
- any remaining black frame after this phase is treated as a transport issue, not a UI issue

### Phase 6 - Device Validation

The slice is not closed until all of these pass on the physical Android device:

1. scrub slowly across a seam between two adjacent clips on the same track
2. scrub quickly across the same seam
3. play through the seam normally
4. split then scrub across the new seam
5. delete the middle clip and scrub/play across the resulting seam
6. repeat the above with:
  - same-source adjacent clips
  - mixed-source adjacent clips

## Deferred Optimization

These items are intentionally deferred until seam stability is proven:

- `DefaultPreloadManager` for adjacent items
- visual seam polish beyond the current seam marker
- picker performance work
- proxy/preview media path

The architecture review explicitly required preload to remain **after** seam correctness, not before it.

## Long-Term Note

This slice is the strongest professional next step inside the current `Media3` model.

It must not be misrepresented as the final answer for all future professional scrub cases. If the product later requires truly aggressive NLE-style live scrub across dense multi-clip timelines and long-GOP sources, a separate preview/proxy path may still be required.

## Review Outcome

This plan was reviewed before implementation by:

- architecture review: `ADJUST`, approved with execution-order changes
- monitor review: `ADJUST`, approved with explicit exit gates
- Media3 documentation review: `proceed with adjustments`

Final verdict:

- proceed
- but only with the phased order defined above
- and only after documenting the seam contract and ownership lock first

## Implementation Status

Current implementation progress inside this slice:

- `Phase 1 - Boundary Contract`:
  - still active
  - internal clip ends remain half-open for non-final clips via timeline seek mapping
- `Phase 2 - Single Seam Owner`:
  - in progress
  - current recovery build adds:
    - Flutter-side `latest-wins` scrub dispatch
    - native Android multi-item scrub seek coalescing
- `Phase 3 - Stable Seek Mapping`:
  - still active
  - not yet accepted on device
- `Phase 4 - Stable Playlist Strategy`:
  - still active
  - no playlist rebuilds are allowed during active scrub
  - same-source timeline continuity is now partially improved:
    - adjacent segments from the same `sourceUri` are now allowed to use the single-source timeline path when ordered safely
    - full-source clips are no longer forced through clipping configuration when no clipping window is actually needed

Current validation focus:

- repeated slow scrub across the same seam multiple times
- verify that live preview does not degrade after repeated `clip1 -> clip2` passes
- verify that `clip2 -> clip1` remains stable
- verify playback-through-cut smoothness after `split`
- verify whether any remaining hitch is now limited to `cross-source` seams only

## Current Outcome

Latest device validation has accepted the current seam-recovery build as the saved working baseline for this slice.

What is accepted now:

- `Media3 1.9.3` + `minSdk 23` remain the official seam baseline
- Flutter-side `latest-wins` scrub dispatch is active
- native Android multi-item scrub seek coalescing is active
- multi-clip live scrub is currently good enough to preserve this version and continue later work from it
- same-source playback continuity is now materially improved for the current saved baseline:
  - split seams from the same source are no longer restricted to the earlier single-segment-only fast path
  - full-source adjacent items no longer receive unnecessary clipping configuration
- latest user validation confirms that same-source seam playback is improved clearly enough to preserve this version

What this does not mean:

- this slice is not declared universally perfect for every future clip combination
- `Stage 6` itself is not closed by this acceptance
- cross-source seam playback continuity, picker performance, and remaining timeline polish still stay outside this acceptance
