# Professional Unified Timeline Presentation Inventory

Status: PUTP-00 baseline inventory  
Package: `com.refusion.app`  
Date: 2026-05-11  
Source plan: `docs/professional_unified_timeline_presentation_plan.md`

## 1. Purpose

This document records the current timeline entry points and scope routes before
any production wiring for unified timeline presentation.

This is a read-only inventory and safety checkpoint.

## 2. Current Timeline Rendering Branches

The editor currently renders `TimelinePanel` through multiple branches in
`FusionXCleanUiScreen`:

- transition focus timeline
- unified transition scope timeline
- layer scope timeline
- scene layer scope timeline
- scene scope timeline
- root composition timeline

Reference points:

- [fusionx_clean_ui_screen.dart](/Users/mx/Documents/ReFusionXx/sources/ui/fusionx-clean-ui-2/lib/features/editor/presentation/screens/fusionx_clean_ui_screen.dart:25953)
- [fusionx_clean_ui_screen.dart](/Users/mx/Documents/ReFusionXx/sources/ui/fusionx-clean-ui-2/lib/features/editor/presentation/screens/fusionx_clean_ui_screen.dart:26102)
- [fusionx_clean_ui_screen.dart](/Users/mx/Documents/ReFusionXx/sources/ui/fusionx-clean-ui-2/lib/features/editor/presentation/screens/fusionx_clean_ui_screen.dart:26225)
- [fusionx_clean_ui_screen.dart](/Users/mx/Documents/ReFusionXx/sources/ui/fusionx-clean-ui-2/lib/features/editor/presentation/screens/fusionx_clean_ui_screen.dart:26351)
- [fusionx_clean_ui_screen.dart](/Users/mx/Documents/ReFusionXx/sources/ui/fusionx-clean-ui-2/lib/features/editor/presentation/screens/fusionx_clean_ui_screen.dart:26449)
- [fusionx_clean_ui_screen.dart](/Users/mx/Documents/ReFusionXx/sources/ui/fusionx-clean-ui-2/lib/features/editor/presentation/screens/fusionx_clean_ui_screen.dart:26603)

## 3. Scope Navigation Entry Points

Current route methods include:

- [fusionx_clean_ui_screen.dart](/Users/mx/Documents/ReFusionXx/sources/ui/fusionx-clean-ui-2/lib/features/editor/presentation/screens/fusionx_clean_ui_screen.dart:4407) `_enterSceneScope`
- [fusionx_clean_ui_screen.dart](/Users/mx/Documents/ReFusionXx/sources/ui/fusionx-clean-ui-2/lib/features/editor/presentation/screens/fusionx_clean_ui_screen.dart:4461) `_exitSceneScope`
- [fusionx_clean_ui_screen.dart](/Users/mx/Documents/ReFusionXx/sources/ui/fusionx-clean-ui-2/lib/features/editor/presentation/screens/fusionx_clean_ui_screen.dart:4508) `_enterSceneLayerScope`
- [fusionx_clean_ui_screen.dart](/Users/mx/Documents/ReFusionXx/sources/ui/fusionx-clean-ui-2/lib/features/editor/presentation/screens/fusionx_clean_ui_screen.dart:4551) `_exitSceneLayerScope`
- [fusionx_clean_ui_screen.dart](/Users/mx/Documents/ReFusionXx/sources/ui/fusionx-clean-ui-2/lib/features/editor/presentation/screens/fusionx_clean_ui_screen.dart:4577) `_exitUnifiedTransitionScope`
- [fusionx_clean_ui_screen.dart](/Users/mx/Documents/ReFusionXx/sources/ui/fusionx-clean-ui-2/lib/features/editor/presentation/screens/fusionx_clean_ui_screen.dart:5633) `_exitLayerScope`

## 4. Timeline Core Data Inputs

Current timeline projection currently relies on:

- [timeline_mock_models.dart](/Users/mx/Documents/ReFusionXx/sources/ui/fusionx-clean-ui-2/lib/features/editor/presentation/models/timeline_mock_models.dart:4) `TimelineTrackKind`
- [timeline_mock_models.dart](/Users/mx/Documents/ReFusionXx/sources/ui/fusionx-clean-ui-2/lib/features/editor/presentation/models/timeline_mock_models.dart:23) `TimelineVisualKind`
- [timeline_mock_models.dart](/Users/mx/Documents/ReFusionXx/sources/ui/fusionx-clean-ui-2/lib/features/editor/presentation/models/timeline_mock_models.dart:186) `TimelineClipData`
- [timeline_mock_models.dart](/Users/mx/Documents/ReFusionXx/sources/ui/fusionx-clean-ui-2/lib/features/editor/presentation/models/timeline_mock_models.dart:466) `TimelineTrackData`
- [timeline_mock_models.dart](/Users/mx/Documents/ReFusionXx/sources/ui/fusionx-clean-ui-2/lib/features/editor/presentation/models/timeline_mock_models.dart:554) `TimelineAnimationLaneData`

## 5. Existing Add Actions

Current add action enum already contains required layer-like actions:

- `videoLayer`
- `imageLayer`
- `textLayer`
- `shapeLayer`
- `audioLayer`
- `nullLayer`
- `adjustmentLayer`

Reference:

- [fusionx_clean_ui_screen.dart](/Users/mx/Documents/ReFusionXx/sources/ui/fusionx-clean-ui-2/lib/features/editor/presentation/screens/fusionx_clean_ui_screen.dart:128)

## 6. Protected Paths (No-Touch Under PUTP)

PUTP must not touch:

- `Stage5TimelineScrubPlatformView`
- `Stage5NativeScrubEngine`
- `Stage5SurfaceScrubDecoder`
- `Stage5ScrubOverlayTextureView`
- `Stage5PreviewPlatformView`
- Flutter Live Scrub handoff paths
- `native_timeline_scrub_surface.dart`

## 7. PUTP-00 Exit Gate

The inventory is valid only if:

- no timeline engine rewrite was started,
- no Stage5/Live Scrub file is in the write set,
- no effect evaluator change was introduced,
- no keyframe evaluator change was introduced.
