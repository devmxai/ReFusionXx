# Next Thread Handoff

## Project

- name: ReFusion / fusionx-clean-ui-2
- local path: `/tmp/refusion-install/sources/ui/fusionx-clean-ui-2`
- github baseline: `2d9d7be` (`Polish live scrub and transition editing`)

## Current Status

- live scrub is now back to a protected working baseline and is considered
  stable enough to continue from
- estimated live scrub quality: about `90%`
- remaining live scrub issue:
  - some stutter / minor inconsistency still exists
  - we will return to polish it later
- do not continue deep live scrub experiments in the next thread first
- if scrub regresses, return first to `docs/live_scrub_lockdown.md`

## Next Priority

Build the scoped layer workflow.

### Goal

When the user does `double tap` on a layer:

- `video`
- `image`
- `text`

the app should open a scoped timeline for that exact layer, using the same feel
and quality as the main timeline.

## Scope Rules For The Next Thread

- keep the main timeline behavior unchanged
- keep current live scrub behavior unchanged
- do not rewrite scrub architecture while building scoped layer workflow
- do not start audio scope now
- focus only on:
  - layer scope entry on `double tap`
  - scoped timeline shell
  - clear split between `Animate` and `FX`

## Audio Note

Audio scope is postponed for later and should become a dedicated audio studio,
for example:

- noise reduction
- voice cleanup
- audio enhancement

## Short Direction

Next thread starts from:

1. `double tap` on `video/image/text`
2. open scoped timeline
3. preserve main timeline quality
4. separate `Animate` from `FX`
