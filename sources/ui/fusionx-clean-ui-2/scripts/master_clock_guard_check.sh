#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ALLOWLIST_FILE="${ROOT_DIR}/docs/master_clock_guard_allowlist.txt"

if [[ ! -f "${ALLOWLIST_FILE}" ]]; then
  echo "Missing allowlist: ${ALLOWLIST_FILE}" >&2
  exit 1
fi

MATCHES="$(
  cd "${ROOT_DIR}" && rg -n "DateTime\\.now\\(|Stopwatch\\(" \
    lib/features/editor/presentation/widgets \
    lib/features/editor/presentation/services \
    --no-heading || true
)"

if [[ -z "${MATCHES}" ]]; then
  echo "master-clock-guard: no preview clock sources found"
  exit 0
fi

ALLOWLIST="$(cat "${ALLOWLIST_FILE}")"
VIOLATIONS=0
MATCH_COUNT=0

while IFS= read -r line; do
  [[ -z "${line}" ]] && continue
  MATCH_COUNT=$((MATCH_COUNT + 1))
  file="${line%%:*}"
  if [[ "${line}" == *"DateTime.now("* ]]; then
    token="DateTime.now("
  elif [[ "${line}" == *"Stopwatch("* ]]; then
    token="Stopwatch("
  else
    continue
  fi

  key="${file}:${token}"
  if ! grep -Fqx "${key}" <<< "${ALLOWLIST}"; then
    echo "master-clock-guard violation: ${line}" >&2
    VIOLATIONS=$((VIOLATIONS + 1))
  fi
done <<< "${MATCHES}"

if [[ ${VIOLATIONS} -gt 0 ]]; then
  echo "master-clock-guard: ${VIOLATIONS} new unapproved preview-time clock source(s)" >&2
  exit 1
fi

echo "master-clock-guard: passed (${MATCH_COUNT} baseline matches)"
