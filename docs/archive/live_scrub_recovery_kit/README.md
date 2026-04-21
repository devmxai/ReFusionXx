# Live Scrub Recovery Kit

This kit documents the current ReFusion live scrub engine as a recoverable
subsystem. It is written for future rebuilds, emergency restores, and clean-room
ports into a new Flutter/Android project.

The goal is simple: if the main project regresses or a new project starts from
zero, following this kit must restore the same live scrub behavior and quality
as the current `beta-10-timeline-fixed` baseline.

## Frozen Reference

- Primary repo: `https://github.com/devmxai/ReFusionXx`
- Backup repo: `https://github.com/devmxai/refusion-stable-live-scrub-beta10`
- Backup tag: `stable-live-scrub-beta10`
- Source baseline tag: `beta-10-timeline-fixed`
- Source baseline commit: `27c910dd57f5ce6bc4fab74789e194a0f1ab3c25`
- App package: `com.refusion.app`
- App workspace: `sources/ui/fusionx-clean-ui-2`

## Backup Repository Rule

The backup repository is frozen. Do not develop in it, do not force-push to it,
and do not replace it with newer experiments.

Use it only as a recovery vault and comparison baseline. All normal development
must happen in the primary repo:

```text
https://github.com/devmxai/ReFusionXx
```

## What This Kit Protects

The protected user-facing behavior is active timeline live scrub:

```text
finger moves on timeline
-> preview updates continuously
-> player does not perform per-frame seek
-> final touch-up settles playback once
```

The current engine is native-owned during active scrub. Flutter provides
timeline state, viewport geometry, media descriptors, and final callbacks. The
native side owns touch capture, target mapping, decoder rendering, overlay
visibility, and active scrub frame presentation.

## Canonical Runtime Path

```text
TimelinePanel
-> NativeTimelineScrubSurface
-> AndroidView: com.refusion.app/stage5_timeline_scrub
-> Stage5TimelineScrubPlatformView
-> Stage5NativeScrubEngine
-> Stage5SurfaceScrubDecoder
-> Stage5ScrubOverlayTextureView
-> screen
```

Final settle path:

```text
NativeTimelineScrubSurface scrubEnd
-> FusionXCleanUiScreen
-> Stage5NativeTransportController.settleAfterScrubPositionMs
-> Stage5TransportManager.settleAfterScrub
-> ExoPlayer exact settle after touch-up only
```

## Kit Files

- [01_engine_files_manifest.md](01_engine_files_manifest.md)
- [02_flutter_integration_manifest.md](02_flutter_integration_manifest.md)
- [03_android_integration_manifest.md](03_android_integration_manifest.md)
- [04_runtime_contract.md](04_runtime_contract.md)
- [05_restore_from_scratch.md](05_restore_from_scratch.md)
- [06_validation_matrix.md](06_validation_matrix.md)
- [07_forbidden_changes.md](07_forbidden_changes.md)
- [08_regression_triage.md](08_regression_triage.md)

Read them in order. Do not skip the validation matrix.

## One-Sentence Rule

During active live scrub, the displayed scrub frame belongs to the native scrub
engine, not to Flutter, not to the timeline widget, and not to ExoPlayer.
