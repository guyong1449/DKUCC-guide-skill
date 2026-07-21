#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "${SCRIPT_DIR}/common.sh"

NETID="$(whoami)"
ROOT_KIND="work"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --netid) NETID="$2"; shift 2 ;;
    --root) ROOT_KIND="$2"; shift 2 ;;
    -h|--help)
      echo "Usage: list-snapshots.sh [--root work|home] [--netid NETID]"
      exit 0
      ;;
    *) die "unknown arg: $1" ;;
  esac
done
resolve_root "${ROOT_KIND}" "${NETID}"

echo "=== Snapshots under ${SNAP_ROOT} ==="
if [[ ! -d "${SNAP_ROOT}" ]]; then
  echo "STATUS: .snapshot missing — no user-visible snaps; go to IT evidence path"
  exit 0
fi
ls -la "${SNAP_ROOT}"
echo "HINT: names often contain '${SNAP_HINT}_YYYY-MM-DD_00:00'"
