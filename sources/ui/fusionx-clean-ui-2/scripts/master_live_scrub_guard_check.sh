#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ALLOWLIST_FILE="${ROOT_DIR}/docs/master_live_scrub_guard_allowlist.txt"

SCRUB_NATIVE_FILES=(
  "android/app/src/main/kotlin/com/fusionx/fusionx_clean_ui_2/Stage5TimelineScrubPlatformView.kt"
  "android/app/src/main/kotlin/com/fusionx/fusionx_clean_ui_2/Stage5NativeScrubEngine.kt"
  "android/app/src/main/kotlin/com/fusionx/fusionx_clean_ui_2/Stage5SurfaceScrubDecoder.kt"
  "android/app/src/main/kotlin/com/fusionx/fusionx_clean_ui_2/Stage5ScrubOverlayTextureView.kt"
)

LIVE_SCRUB_DOMAIN_FILES=(
  "lib/features/editor/domain/models/master_live_scrub_visual_program_models.dart"
  "lib/features/editor/domain/models/master_live_scrub_descriptor_models.dart"
  "lib/features/editor/domain/services/master_live_scrub_program_adapter.dart"
  "lib/features/editor/domain/services/master_live_scrub_descriptor_projection.dart"
)

if [[ ! -f "${ALLOWLIST_FILE}" ]]; then
  echo "Missing allowlist: ${ALLOWLIST_FILE}" >&2
  exit 1
fi

ALLOWLIST="$(cat "${ALLOWLIST_FILE}")"
VIOLATIONS=0

# Rule 1: no ExoPlayer-like seek/setMediaItem path in active scrub native files.
SEEK_MATCHES="$(
  cd "${ROOT_DIR}" && rg -nH "\\.seekTo\\(|\\.setMediaItem\\(" \
    "${SCRUB_NATIVE_FILES[@]}" --no-heading || true
)"

while IFS= read -r line; do
  [[ -z "${line}" ]] && continue
  file="${line%%:*}"
  token=""
  if [[ "${line}" == *"currentExtractor.seekTo("* ]]; then
    token="extractor.seekTo.allowed"
  elif [[ "${line}" == *".setMediaItem("* ]]; then
    token="active_scrub.setMediaItem.disallowed"
  else
    token="active_scrub.seekTo.disallowed"
  fi

  key="${file}:${token}"
  if ! grep -Fqx "${key}" <<< "${ALLOWLIST}"; then
    echo "master-live-scrub-guard violation (seek/media): ${line}" >&2
    VIOLATIONS=$((VIOLATIONS + 1))
  fi
done <<< "${SEEK_MATCHES}"

# Rule 2: no thumbnail/poster fallback language in active scrub native path.
FALLBACK_MATCHES="$(
  cd "${ROOT_DIR}" && rg -nH "(thumbnail|poster)" \
    "${SCRUB_NATIVE_FILES[@]}" --no-heading -i || true
)"

if [[ -n "${FALLBACK_MATCHES}" ]]; then
  while IFS= read -r line; do
    [[ -z "${line}" ]] && continue
    echo "master-live-scrub-guard violation (fallback token): ${line}" >&2
    VIOLATIONS=$((VIOLATIONS + 1))
  done <<< "${FALLBACK_MATCHES}"
fi

# Rule 3: no direct transition compositor path inside live scrub domain contracts.
COMPOSITOR_MATCHES="$(
  cd "${ROOT_DIR}" && rg -nH \
    "(ProfessionalVideoTransitionCompositorManager|renderInteractiveFrame|interactiveNativeTransitionSurface)" \
    "${LIVE_SCRUB_DOMAIN_FILES[@]}" --no-heading || true
)"

if [[ -n "${COMPOSITOR_MATCHES}" ]]; then
  while IFS= read -r line; do
    [[ -z "${line}" ]] && continue
    echo "master-live-scrub-guard violation (transition compositor coupling): ${line}" >&2
    VIOLATIONS=$((VIOLATIONS + 1))
  done <<< "${COMPOSITOR_MATCHES}"
fi

# Rule 4: no scrub clock source usage unless allowlisted for diagnostics.
CLOCK_MATCHES="$(
  cd "${ROOT_DIR}" && rg -nH "(DateTime\\.now\\(|Stopwatch\\()" \
    "${LIVE_SCRUB_DOMAIN_FILES[@]}" --no-heading || true
)"

while IFS= read -r line; do
  [[ -z "${line}" ]] && continue
  file="${line%%:*}"
  token=""
  if [[ "${line}" == *"DateTime.now("* ]]; then
    token="DateTime.now("
  else
    token="Stopwatch("
  fi
  key="${file}:${token}"
  if ! grep -Fqx "${key}" <<< "${ALLOWLIST}"; then
    echo "master-live-scrub-guard violation (clock source): ${line}" >&2
    VIOLATIONS=$((VIOLATIONS + 1))
  fi
done <<< "${CLOCK_MATCHES}"

if [[ ${VIOLATIONS} -gt 0 ]]; then
  echo "master-live-scrub-guard: ${VIOLATIONS} violation(s)" >&2
  exit 1
fi

echo "master-live-scrub-guard: passed"
