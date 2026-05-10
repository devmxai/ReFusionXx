#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APK_PATH="$ROOT_DIR/build/app/outputs/flutter-apk/app-debug.apk"

cd "$ROOT_DIR"

echo "[PDS-23] Running targeted professional QA suite..."
flutter test test/scene_component_runtime_regression_test.dart
flutter test test/scene_director_brief_templates_regression_test.dart
flutter test test/scene_director_intelligence_test.dart
flutter test test/scene_visual_closure_loop_service_test.dart
flutter test test/scene_design_scorecard_test.dart
flutter test test/scene_lovable_parity_acceptance_suite_test.dart

echo "[PDS-23] Building debug APK..."
flutter build apk --debug

if [[ ! -f "$APK_PATH" ]]; then
  echo "[PDS-23] ERROR: APK was not produced at $APK_PATH"
  exit 1
fi

echo "[PDS-23] Checking connected Android devices..."
ADB_DEVICES="$(adb devices | tail -n +2 | sed '/^\s*$/d')"
if [[ -z "$ADB_DEVICES" ]]; then
  echo "[PDS-23] No connected device detected. Skipping install."
  echo "[PDS-23] To install later: adb install -r \"$APK_PATH\""
  exit 0
fi

echo "[PDS-23] Device(s) found:"
echo "$ADB_DEVICES"
echo "[PDS-23] Installing APK..."
adb install -r "$APK_PATH"
echo "[PDS-23] Install completed."
