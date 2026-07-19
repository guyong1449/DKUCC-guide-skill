#!/bin/bash
set -euo pipefail

NETID="$(whoami)"
WORK_ROOT="/work/${NETID}"
LOG="${HOME}/logs/touch_work.log"

mkdir -p "$(dirname "$LOG")"
{
  echo "=== $(date -Is) touch_work_timestamps start NETID=${NETID} WORK_ROOT=${WORK_ROOT} ==="
  if [[ ! -d "$WORK_ROOT" ]]; then
    echo "ERROR: WORK_ROOT not found: $WORK_ROOT"
    exit 1
  fi
  nice find "$WORK_ROOT" -type f -exec touch {} +
  echo "Touched files under ${WORK_ROOT}"
  echo "=== $(date -Is) touch_work_timestamps done ==="
} >> "$LOG" 2>&1
