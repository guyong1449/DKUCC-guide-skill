#!/bin/bash
set -euo pipefail
WORK_ROOT="${1:-/work/$(whoami)}"
echo "=== $(date -Is) monthly_check WORK_ROOT=${WORK_ROOT} ==="
df -h "$WORK_ROOT" | tail -1
du -sh "$WORK_ROOT" 2>/dev/null || echo "du failed for ${WORK_ROOT}"
TOUCH_LOG="${HOME}/logs/touch_work.log"
if [[ -f "$TOUCH_LOG" ]]; then
  echo "--- last lines of ${TOUCH_LOG} ---"
  tail -30 "$TOUCH_LOG"
else
  echo "WARN: missing ${TOUCH_LOG}"
fi
CRON_LOG="${HOME}/logs/touch_work.cron.log"
if [[ -f "$CRON_LOG" ]]; then
  echo "--- last lines of ${CRON_LOG} ---"
  tail -10 "$CRON_LOG"
fi
