#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ALLOWLIST_FILE="${ROOT_DIR}/docs/master_clock_current_time_guard_allowlist.txt"
TARGET_FILE="lib/features/editor/presentation/screens/fusionx_clean_ui_screen.dart"

if [[ ! -f "${ALLOWLIST_FILE}" ]]; then
  echo "Missing allowlist: ${ALLOWLIST_FILE}" >&2
  exit 1
fi

MATCHES="$(
  cd "${ROOT_DIR}" && rg -nH "_currentTime\\s*=" "${TARGET_FILE}" --no-heading || true
)"

if [[ -z "${MATCHES}" ]]; then
  echo "master-clock-current-time-guard: no _currentTime assignments found"
  exit 0
fi

ALLOWLIST="$(cat "${ALLOWLIST_FILE}")"
VIOLATIONS=0
MATCH_COUNT=0

while IFS= read -r line; do
  [[ -z "${line}" ]] && continue
  MATCH_COUNT=$((MATCH_COUNT + 1))
  file="${line%%:*}"
  token=""
  if [[ "${line}" == *"TimelineTime _currentTime = TimelineTime.zero;"* ]]; then
    token="_currentTime.init"
  elif [[ "${line}" == *"_currentTime = clamped;"* ]]; then
    token="_currentTime.setter"
  elif [[ "${line}" == *"_currentTime = clockTime;"* ]]; then
    token="_currentTime.clock_snapshot"
  else
    token="_currentTime.unapproved_assignment"
  fi
  key="${file}:${token}"

  if ! grep -Fqx "${key}" <<< "${ALLOWLIST}"; then
    echo "master-clock-current-time-guard violation: ${line}" >&2
    VIOLATIONS=$((VIOLATIONS + 1))
  fi
done <<< "${MATCHES}"

if [[ ${VIOLATIONS} -gt 0 ]]; then
  echo "master-clock-current-time-guard: ${VIOLATIONS} unapproved _currentTime assignment(s)" >&2
  exit 1
fi

echo "master-clock-current-time-guard: passed (${MATCH_COUNT} baseline matches)"
