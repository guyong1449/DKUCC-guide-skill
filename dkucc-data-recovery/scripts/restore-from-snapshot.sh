#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "${SCRIPT_DIR}/common.sh"

usage() {
  cat <<'EOF'
Usage: restore-from-snapshot.sh --snap <SNAP> --rel <REL> [--root work|home] [--dry-run]
  Do NOT use cp -a as primary restore (same-inode issue on NFS snaps).
EOF
  exit 1
}

NETID="$(whoami)"
ROOT_KIND="work"
REL=""
SNAP=""
DRY_RUN=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --netid) NETID="$2"; shift 2 ;;
    --root) ROOT_KIND="$2"; shift 2 ;;
    --rel) REL="$2"; shift 2 ;;
    --snap) SNAP="$2"; shift 2 ;;
    --dry-run) DRY_RUN=1; shift ;;
    -h|--help) usage ;;
    *) die "unknown arg: $1" ;;
  esac
done
[[ -n "${REL}" && -n "${SNAP}" ]] || usage
[[ "$(whoami)" == "${NETID}" ]] || die "run as owner ${NETID} (current=$(whoami))"
resolve_root "${ROOT_KIND}" "${NETID}"

SRC="${SNAP_ROOT}/${SNAP}/${REL}"
DEST="${ROOT}/${REL}"
[[ -e "${SRC}" ]] || die "snapshot source missing: ${SRC}"

echo "SRC=${SRC}"
echo "DEST=${DEST}"
mkdir -p "${DEST}"

RSYNC_FLAGS=(-a --info=progress2)
if [[ "${DRY_RUN}" -eq 1 ]]; then
  RSYNC_FLAGS+=(--dry-run)
  echo "DRY-RUN: no writes"
fi

# Trailing slashes: copy contents into DEST
rsync "${RSYNC_FLAGS[@]}" "${SRC}/" "${DEST}/"
echo "=== post du ==="
du -sh "${DEST}"
echo "Next: touch-after-restore.sh --rel ${REL} --root ${ROOT_KIND}"
