#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "${SCRIPT_DIR}/common.sh"

usage() {
  cat <<'EOF'
Usage: print-it-evidence.sh --rel <REL> --size "<desc>" --window "<window>" \
  [--snap-before SNAP] [--snap-after SNAP] [--root work|home]
EOF
  exit 1
}

NETID="$(whoami)"
ROOT_KIND="work"
REL=""
SIZE=""
WINDOW=""
SNAP_BEFORE=""
SNAP_AFTER=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --netid) NETID="$2"; shift 2 ;;
    --root) ROOT_KIND="$2"; shift 2 ;;
    --rel) REL="$2"; shift 2 ;;
    --size) SIZE="$2"; shift 2 ;;
    --window) WINDOW="$2"; shift 2 ;;
    --snap-before) SNAP_BEFORE="$2"; shift 2 ;;
    --snap-after) SNAP_AFTER="$2"; shift 2 ;;
    -h|--help) usage ;;
    *) die "unknown arg: $1" ;;
  esac
done
[[ -n "${REL}" && -n "${SIZE}" && -n "${WINDOW}" ]] || usage
resolve_root "${ROOT_KIND}" "${NETID}"
TARGET="${ROOT}/${REL}"

echo "========== [1] Problem overview =========="
echo "user=$(whoami) uid=$(id -u) host=$(hostname)"
echo "path=${TARGET}"
echo "size_desc=${SIZE}"
echo "window=${WINDOW}"
echo "mount:"
df -h "${ROOT}" | tail -1
date

echo "========== [2] Live path stat =========="
if [[ -e "${TARGET}" ]]; then
  stat "${TARGET}"
  du -sh "${TARGET}" 2>/dev/null || true
else
  echo "live path missing"
fi

echo "========== [3] Snapshot compare =========="
if [[ -n "${SNAP_BEFORE}" ]]; then
  echo "--- BEFORE ${SNAP_BEFORE} ---"
  du -sh "${SNAP_ROOT}/${SNAP_BEFORE}/${REL}" 2>/dev/null || echo "missing"
  du -sh "${SNAP_ROOT}/${SNAP_BEFORE}/${REL}"/* 2>/dev/null | head -15 || true
else
  echo "(no --snap-before)"
fi
if [[ -n "${SNAP_AFTER}" ]]; then
  echo "--- AFTER ${SNAP_AFTER} ---"
  du -sh "${SNAP_ROOT}/${SNAP_AFTER}/${REL}" 2>/dev/null || echo "missing"
  du -sh "${SNAP_ROOT}/${SNAP_AFTER}/${REL}"/* 2>/dev/null | head -15 || true
else
  echo "(no --snap-after)"
fi

echo "========== [4] bash_history rm probe =========="
HIST="${HOME}/.bash_history"
if [[ -f "${HIST}" ]]; then
  rm_total=$(grep -cE '^[[:space:]]*rm[[:space:]]+' "${HIST}" 2>/dev/null || true)
  [[ -n "${rm_total}" ]] || rm_total=0
  rm_filt=$(grep -E '^[[:space:]]*rm[[:space:]]+' "${HIST}" 2>/dev/null \
    | grep -viE '\.pth|checkpoint|ckpt' \
    | grep -cF "${TARGET}" || true)
  [[ -n "${rm_filt}" ]] || rm_filt=0
  echo "total rm lines: ${rm_total}"
  echo "rm mentioning target (exclude .pth|checkpoint|ckpt): ${rm_filt}"
  echo "sample:"
  grep -E '^[[:space:]]*rm[[:space:]]+' "${HIST}" 2>/dev/null \
    | grep -viE '\.pth|checkpoint|ckpt' \
    | grep -F "${TARGET}" \
    | tail -20 || echo "(none)"
  echo "(prefer: scripts/scan-bash-history.sh --rel ${REL})"
else
  echo "no ${HIST}"
fi

echo "========== [5] ACL glance (informational) =========="
ls -ld "${ROOT}" "${TARGET}" 2>/dev/null || true
command -v nfs4_getfacl >/dev/null && nfs4_getfacl "${TARGET}" 2>/dev/null | head -20 || true

echo "See references/it-ticket-template.md for ticket body."
