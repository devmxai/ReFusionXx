# 01 - Engine Files Manifest

This file lists the files that define the recoverable live scrub subsystem.

Use the backup repository and tag as the exact source of truth:

```bash
git clone https://github.com/devmxai/refusion-stable-live-scrub-beta10.git
cd refusion-stable-live-scrub-beta10
git checkout stable-live-scrub-beta10
```

## Android Native Engine Core

Copy these files exactly when restoring the native scrub engine:

```text
sources/ui/fusionx-clean-ui-2/android/app/src/main/kotlin/com/fusionx/fusionx_clean_ui_2/Stage5NativeScrubEngine.kt
sources/ui/fusionx-clean-ui-2/android/app/src/main/kotlin/com/fusionx/fusionx_clean_ui_2/Stage5SurfaceScrubDecoder.kt
sources/ui/fusionx-clean-ui-2/android/app/src/main/kotlin/com/fusionx/fusionx_clean_ui_2/Stage5TimelineScrubPlatformView.kt
sources/ui/fusionx-clean-ui-2/android/app/src/main/kotlin/com/fusionx/fusionx_clean_ui_2/Stage5ScrubOverlayTextureView.kt
sources/ui/fusionx-clean-ui-2/android/app/src/main/kotlin/com/fusionx/fusionx_clean_ui_2/Stage5ScrubRenderHost.kt
sources/ui/fusionx-clean-ui-2/android/app/src/main/kotlin/com/fusionx/fusionx_clean_ui_2/Stage5ScrubPreviewProxyManager.kt
```

## Android Required Hosts

These files are not scrub-only, but the scrub engine depends on their exact
integration points:

```text
sources/ui/fusionx-clean-ui-2/android/app/src/main/kotlin/com/fusionx/fusionx_clean_ui_2/MainActivity.kt
sources/ui/fusionx-clean-ui-2/android/app/src/main/kotlin/com/fusionx/fusionx_clean_ui_2/Stage5PreviewPlatformView.kt
sources/ui/fusionx-clean-ui-2/android/app/src/main/kotlin/com/fusionx/fusionx_clean_ui_2/Stage5PreviewPlatformViewFactory.kt
sources/ui/fusionx-clean-ui-2/android/app/src/main/kotlin/com/fusionx/fusionx_clean_ui_2/Stage5TransportManager.kt
```

Only the scrub-related integration points should be restored from these host
files if the destination project has evolved.

## Flutter Bridge Core

```text
sources/ui/fusionx-clean-ui-2/lib/features/editor/presentation/widgets/native_timeline_scrub_surface.dart
sources/ui/fusionx-clean-ui-2/lib/core/engine/live_scrub_preview_sources.dart
sources/ui/fusionx-clean-ui-2/lib/core/engine/stage5_native_transport_controller.dart
```

## Flutter Host Integration

These files contain scrub integration inside larger editor widgets:

```text
sources/ui/fusionx-clean-ui-2/lib/features/editor/presentation/screens/fusionx_clean_ui_screen.dart
sources/ui/fusionx-clean-ui-2/lib/features/editor/presentation/widgets/timeline_panel.dart
sources/ui/fusionx-clean-ui-2/lib/features/editor/presentation/widgets/native_preview_surface.dart
sources/ui/fusionx-clean-ui-2/lib/features/editor/presentation/models/editor_asset_item.dart
sources/ui/fusionx-clean-ui-2/lib/features/editor/presentation/models/timeline_mock_models.dart
sources/ui/fusionx-clean-ui-2/lib/features/editor/presentation/models/timeline_time.dart
```

Do not blindly replace these host files in a newer project. Instead, port the
named methods and contracts described in the next files.

## Tests To Restore With The Engine

```text
sources/ui/fusionx-clean-ui-2/test/native_timeline_scrub_surface_test.dart
sources/ui/fusionx-clean-ui-2/test/timeline_panel_native_scrub_regions_test.dart
sources/ui/fusionx-clean-ui-2/test/native_preview_surface_test.dart
```

These are not enough by themselves, but they protect the existing widget and
hit-test contracts.

