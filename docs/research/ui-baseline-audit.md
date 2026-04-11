# UI Baseline Audit

Reference repository:

- [https://github.com/devmxai/fusionx-clean-ui-2](https://github.com/devmxai/fusionx-clean-ui-2)

Status: `COMPLETE FOR STAGE 0`

Local source path:

- [sources/ui/fusionx-clean-ui-2](/Users/mx/Documents/InGeneBMFPro/sources/ui/fusionx-clean-ui-2)

Provenance:

- origin: `https://github.com/devmxai/fusionx-clean-ui-2`
- commit: `7990d4acf2d60cb37ecdb872d7733da2cf0ad975`

## What The UI Already Contains

- Flutter editor shell layout
- top bar, tools bar, preview stage, timeline, media dock, and bottom sheet
- mock editing interactions such as selection, split, trim, duplicate, delete, reorder, and visual play/pause behavior

## What Is Mock-Only Or Missing

From the repository README and code:

- the repo is explicitly `UI-only`
- it explicitly excludes:
  - playback engine
  - native media player
  - platform channels for media control
  - export pipeline
  - preview backend
- playback-like behavior is driven by `Timer.periodic`
- preview is a mock canvas rather than real media rendering
- thumbnail generation currently returns an empty list
- asset path resolution is disabled in the shipped screen

Key local references:

- [sources/ui/fusionx-clean-ui-2/README.md](/Users/mx/Documents/InGeneBMFPro/sources/ui/fusionx-clean-ui-2/README.md)
- [sources/ui/fusionx-clean-ui-2/lib/features/editor/presentation/screens/fusionx_clean_ui_screen.dart](/Users/mx/Documents/InGeneBMFPro/sources/ui/fusionx-clean-ui-2/lib/features/editor/presentation/screens/fusionx_clean_ui_screen.dart)
- [sources/ui/fusionx-clean-ui-2/lib/features/editor/presentation/widgets/preview_stage.dart](/Users/mx/Documents/InGeneBMFPro/sources/ui/fusionx-clean-ui-2/lib/features/editor/presentation/widgets/preview_stage.dart)
- [sources/ui/fusionx-clean-ui-2/lib/features/editor/presentation/widgets/timeline_panel.dart](/Users/mx/Documents/InGeneBMFPro/sources/ui/fusionx-clean-ui-2/lib/features/editor/presentation/widgets/timeline_panel.dart)
- [sources/ui/fusionx-clean-ui-2/lib/core/media/native_media_thumbnailer.dart](/Users/mx/Documents/InGeneBMFPro/sources/ui/fusionx-clean-ui-2/lib/core/media/native_media_thumbnailer.dart)

## Best Future Integration Seams

- `PreviewStage` is the cleanest host for a later native preview surface
- `TimelinePanel` already exposes useful UI-facing callbacks for time changes, scrubbing, selection, and reorder
- `TimelineAssetPathResolver` is a natural seam for real thumbnails and asset-backed clips
- media dock and bottom-sheet callbacks already separate import/add actions from rendering

## Risk If Treated As Backend-Ready

- false confidence in playback readiness
- confusion between visual demo time and real media transport
- hidden backend gaps around import, preview, seek, scrub, and export
- inaccurate debugging later if mock behavior is mistaken for completed integration
