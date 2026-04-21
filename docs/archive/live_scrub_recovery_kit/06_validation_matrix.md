# 06 - Validation Matrix

This matrix is mandatory after any restore, port, or change touching live scrub
adjacent files.

## Build Checks

From:

```text
sources/ui/fusionx-clean-ui-2
```

Run:

```bash
flutter analyze
flutter test
cd android
./gradlew :app:assembleDebug
```

## Unit/Widget Checks

Required tests:

```bash
flutter test test/native_timeline_scrub_surface_test.dart
flutter test test/timeline_panel_native_scrub_regions_test.dart
flutter test test/native_preview_surface_test.dart
```

## Device Matrix

Test on a physical Android device.

Videos:

- 30-second 720p
- 60-second 1080p
- 20-second portrait clip
- square clip inside portrait canvas
- long 4K clip if available
- two clips with different aspect ratios

## Required Manual Checks

### Single Clip

- Import first clip.
- Live scrub immediately.
- Scrub forward slowly.
- Scrub forward quickly.
- Scrub backward slowly.
- Scrub backward quickly.
- Lift finger at random frames.

Pass criteria:

- preview updates during finger movement
- no final-frame snap to wrong frame
- no black flash during active scrub
- no stuck first frame
- no delayed final frame after lift

### Two Clips

- Import clip A.
- Import clip B.
- Scrub inside clip A.
- Scrub inside clip B.
- Scrub across A/B boundary forward.
- Scrub across A/B boundary backward.

Pass criteria:

- first scrub after adding clip B works
- cross-boundary scrub does not crash
- second clip does not stretch to canvas incorrectly
- scrub overlay geometry matches normal preview geometry
- playhead position and displayed frame stay coherent

### Normal Playback After Scrub

- Scrub to a position.
- Lift finger.
- Press play.
- Let playback cross a clip boundary.

Pass criteria:

- playback resumes from lifted position
- no extra seek jump
- no pause at boundary
- no black frame between clips

## Performance Checks

Record observations:

```text
first scrub latency:
steady scrub smoothness:
cross-boundary scrub smoothness:
final settle stability:
black frames:
wrong frames:
crash/ANR:
```

Required target:

- active scrub should feel continuous after import
- no repeated regression where quality improves only after repeated scrubbing
- no ANR
- no crash

## Regression Rule

If any check fails, stop and compare against:

```text
https://github.com/devmxai/refusion-stable-live-scrub-beta10
tag: stable-live-scrub-beta10
```

Do not patch unrelated timeline/export code until the failed contract is
identified.

