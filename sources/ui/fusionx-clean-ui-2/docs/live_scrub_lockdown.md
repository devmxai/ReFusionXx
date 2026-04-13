# Live Scrub Lockdown

## Version

- label: `beta 3 scrub fix`
- repository: `ReFusion / fusionx-clean-ui-2`
- baseline before this lock: `2d9d7be` (`Polish live scrub and transition editing`)

## Current Status

- estimated live scrub quality: about `90%`
- current build is considered the protected scrub baseline for ongoing work
- if later feature work destabilizes scrub, return to this locked version first
- do not run deep scrub experiments on unrelated feature threads

## What Is Good In This Build

- slow drag scrub is stable enough to continue product work
- medium / fast drag scrub is significantly improved versus the previous state
- horizontal timeline pan now drives the same preview-time path instead of
  behaving like viewport-only movement
- scrub seek policy now keys off the latest scrub target instead of only the
  currently rendered player position
- Flutter-side preview scrub dispatch now coalesces in-flight requests instead
  of flooding the platform channel during fast motion

## Known Remaining Limitation

- live scrub is not considered fully solved yet
- minor stutter / inconsistency can still appear at higher speeds
- final release-frame behavior is better, but not yet guaranteed by a true
  render-confirmed settle path
- proxy scrub runtime remains disabled in the user-facing path

## Protected Files

These files are the current scrub baseline and should be treated as sensitive:

- `lib/features/editor/presentation/widgets/timeline_panel.dart`
- `lib/core/engine/stage5_native_transport_controller.dart`
- `android/app/src/main/kotlin/com/fusionx/fusionx_clean_ui_2/Stage5TransportManager.kt`
- `lib/features/editor/presentation/screens/fusionx_clean_ui_screen.dart`
- `lib/core/engine/live_scrub_pipeline.dart`

## Non-Negotiable Rules

- do not bypass `LiveScrubPipeline` for timeline scrub behavior
- do not reintroduce a separate viewport-only horizontal movement path when the
  user expects preview-following scrub
- do not base scrub seek decisions on stale rendered position when a fresher
  scrub target already exists
- do not flood the transport with parallel scrub preview requests
- do not change scrub behavior as a side effect of scoped timeline, animate, FX,
  text, trim, or transition work
- do not enable proxy runtime in user-facing builds unless it is clearly better
  than the current protected baseline

## Quick Regression Checklist

After any timeline-related change, verify all of the following first:

1. slow press-and-drag scrub tracks the finger proportionally
2. medium / fast press-and-drag scrub does not collapse into stale jumps
3. horizontal left/right drag also updates preview continuously
4. releasing the finger does not show an obviously delayed final frame
5. seam crossing does not flash a stale previous frame

## Recovery Direction

If scrub regresses:

1. compare against the `beta 3 scrub fix` commit/tag first
2. inspect diffs in the protected files before touching anything else
3. revert scrub-sensitive changes as a unit, not piecemeal by guesswork
4. restore this locked state before continuing feature work

## Next Product Priority

- continue with scoped layer workflow next
- keep live scrub stable while building:
  - double tap on `video`
  - double tap on `image`
  - double tap on `text`
  - open scoped timeline
  - preserve main timeline quality
  - keep `Animate` separate from `FX`
