#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "${SCRIPT_DIR}/common.sh"

usage() {
  cat <<'EOF'
Usage: check-live-path.sh --rel <REL> [--root work|home] [--netid NETID]
EOF
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

echo "=== Live path check ==="
echo "target=${TARGET}"
if [[ ! -e "${TARGET}" ]]; then
  echo "STATUS: path does not exist"
  exit 0
fi
ls -lad "${TARGET}"
du -sh "${TARGET}" 2>/dev/null || true
stat "${TARGET}"
if [[ -d "${TARGET}" ]]; then
  echo "--- top children (du) ---"
  du -sh "${TARGET}"/* 2>/dev/null | head -30 || echo "(no children or permission denied)"
fi
echo "HINT: tiny du + shared early-morning Modify → suspect bulk purge"
