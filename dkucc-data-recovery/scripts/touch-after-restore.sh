#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "${SCRIPT_DIR}/common.sh"

usage() {
  echo "Usage: touch-after-restore.sh --rel <REL> [--root work|home]"
  exit 1
}

NETID="$(whoami)"
ROOT_KIND="work"
REL=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --netid) NETID="$2"; shift 2 ;;
    --root) ROOT_KIND="$2"; shift 2 ;;
    --rel) REL="$2"; shift 2 ;;
    -h|--help) usage ;;
    *) die "unknown arg: $1" ;;
  esac
done
[[ -n "${REL}" ]] || usage
resolve_root "${ROOT_KIND}" "${NETID}"
TARGET="${ROOT}/${REL}"
[[ -d "${TARGET}" ]] || die "not a directory: ${TARGET}"

echo "Counting files under ${TARGET} ..."
COUNT="$(find "${TARGET}" -type f 2>/dev/null | wc -l | tr -d ' ')"
echo "file_count=${COUNT}"
echo "Touching (nice find -exec touch) — large trees may take hours; prefer tmux"
nice find "${TARGET}" -type f -exec touch {} +
echo "touch done at $(date -Is)"
echo "For monthly whole-tree keepalive see skill dkucc-data-ingest"
