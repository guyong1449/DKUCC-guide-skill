#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "${SCRIPT_DIR}/common.sh"

usage() {
  cat <<'EOF'
Usage: compare-snapshots.sh --rel <REL> --before <SNAP> --after <SNAP> [--root work|home]
EOF
  exit 1
}

NETID="$(whoami)"
ROOT_KIND="work"
REL=""
BEFORE=""
AFTER=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --netid) NETID="$2"; shift 2 ;;
    --root) ROOT_KIND="$2"; shift 2 ;;
    --rel) REL="$2"; shift 2 ;;
    --before) BEFORE="$2"; shift 2 ;;
    --after) AFTER="$2"; shift 2 ;;
    -h|--help) usage ;;
    *) die "unknown arg: $1" ;;
  esac
done
[[ -n "${REL}" && -n "${BEFORE}" && -n "${AFTER}" ]] || usage
resolve_root "${ROOT_KIND}" "${NETID}"

SRC_B="${SNAP_ROOT}/${BEFORE}/${REL}"
SRC_A="${SNAP_ROOT}/${AFTER}/${REL}"

echo "=== BEFORE: ${SRC_B} ==="
if [[ -e "${SRC_B}" ]]; then
  du -sh "${SRC_B}" 2>/dev/null || true
  du -sh "${SRC_B}"/* 2>/dev/null | head -20 || true
else
  echo "MISSING"
fi

echo "=== AFTER: ${SRC_A} ==="
if [[ -e "${SRC_A}" ]]; then
  du -sh "${SRC_A}" 2>/dev/null || true
  du -sh "${SRC_A}"/* 2>/dev/null | head -20 || true
else
  echo "MISSING"
fi

echo "Pick restore source = BEFORE snap if it still holds full data."
