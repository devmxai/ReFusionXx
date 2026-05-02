#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ALLOWLIST_FILE="${ROOT_DIR}/docs/master_clock_bridge_guard_allowlist.txt"

if [[ ! -f "${ALLOWLIST_FILE}" ]]; then
  echo "Missing allowlist: ${ALLOWLIST_FILE}" >&2
  exit 1
fi

MATCHES="$(
  cd "${ROOT_DIR}" && rg -n "_timelineClockCoordinator\\." \
    lib/features/editor/presentation \
    --no-heading || true
)"

if [[ -z "${MATCHES}" ]]; then
  echo "master-clock-bridge-guard: no direct coordinator access found"
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
  if [[ "${line}" == *"_timelineClockCoordinator.dispose("* ]]; then
    token="_timelineClockCoordinator.dispose()"
  else
    token="_timelineClockCoordinator.direct_access"
  fi
  key="${file}:${token}"

  if ! grep -Fqx "${key}" <<< "${ALLOWLIST}"; then
    echo "master-clock-bridge-guard violation: ${line}" >&2
    VIOLATIONS=$((VIOLATIONS + 1))
  fi
done <<< "${MATCHES}"

if [[ ${VIOLATIONS} -gt 0 ]]; then
  echo "master-clock-bridge-guard: ${VIOLATIONS} unapproved direct coordinator access(es)" >&2
  exit 1
fi

echo "master-clock-bridge-guard: passed (${MATCH_COUNT} baseline matches)"
