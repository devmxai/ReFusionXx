#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

echo "[master-live-scrub] guard check"
scripts/master_live_scrub_guard_check.sh

echo "[master-live-scrub] targeted tests"
flutter test \
  test/master_live_scrub_descriptor_projection_test.dart \
  test/master_live_scrub_preflight_payload_test.dart \
  test/stage5_live_scrub_capabilities_test.dart \
  test/master_live_scrub_program_adapter_test.dart \
  test/master_frame_evaluation_read_adapter_test.dart

echo "[master-live-scrub] analyze"
flutter analyze

echo "[master-live-scrub] preflight verify passed"
