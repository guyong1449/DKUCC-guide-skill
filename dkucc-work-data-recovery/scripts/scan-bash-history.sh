#!/usr/bin/env bash
# Scan ~/.bash_history for intentional rm of a live path (IT evidence / Part F).
# Derived from DKUCC incident investigation pattern (2026-05 hyperspectral case).
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "${SCRIPT_DIR}/common.sh"

usage() {
  cat <<'EOF'
Usage: scan-bash-history.sh --rel <REL> [--root work|home] [--netid NETID] [--lines N]
  Grep bash_history for rm touching the target path.
  Excludes noisy training artifact deletions (.pth / checkpoint / ckpt) by default.

  Notes:
  - History file is always the caller HOME/.bash_history (not the --netid home).
  - --netid only changes the TARGET path string used for grep.
  - Match is literal absolute TARGET; relative/~/\$VAR forms in history may be missed.
EOF
  exit 1
}

NETID="$(whoami)"
ROOT_KIND="work"
REL=""
LINES=20
while [[ $# -gt 0 ]]; do
  case "$1" in
    --netid) NETID="$2"; shift 2 ;;
    --root) ROOT_KIND="$2"; shift 2 ;;
    --rel) REL="$2"; shift 2 ;;
    --lines) LINES="$2"; shift 2 ;;
    -h|--help) usage ;;
    *) die "unknown arg: $1" ;;
  esac
done
[[ -n "${REL}" ]] || usage
resolve_root "${ROOT_KIND}" "${NETID}"
TARGET="${ROOT}/${REL}"
HIST="${HOME}/.bash_history"

echo "=== bash_history scan ==="
echo "target=${TARGET}"
echo "hist=${HIST}"

if [[ ! -f "${HIST}" ]]; then
  echo "STATUS: no ${HIST}"
  exit 0
fi

echo "---------- counts ----------"
rm_total=$(grep -cE '^[[:space:]]*rm[[:space:]]+' "${HIST}" 2>/dev/null || true)
[[ -n "${rm_total}" ]] || rm_total=0
rm_raw=$(grep -E '^[[:space:]]*rm[[:space:]]+' "${HIST}" 2>/dev/null | grep -cF "${TARGET}" || true)
[[ -n "${rm_raw}" ]] || rm_raw=0
rm_filt=$(grep -E '^[[:space:]]*rm[[:space:]]+' "${HIST}" 2>/dev/null \
  | grep -viE '\.pth|checkpoint|ckpt' \
  | grep -cF "${TARGET}" || true)
[[ -n "${rm_filt}" ]] || rm_filt=0
echo "total rm lines: ${rm_total}"
echo "rm lines mentioning target (raw): ${rm_raw}"
echo "rm lines mentioning target (exclude .pth|checkpoint|ckpt): ${rm_filt}"

echo "---------- sample rm lines (filtered) ----------"
grep -E '^[[:space:]]*rm[[:space:]]+' "${HIST}" 2>/dev/null \
  | grep -viE '\.pth|checkpoint|ckpt' \
  | grep -F "${TARGET}" \
  | tail -n "${LINES}" || echo "(none)"

echo "---------- related history (path mentions, filtered) ----------"
grep -F "${TARGET}" "${HIST}" 2>/dev/null \
  | grep -viE '\.pth|checkpoint|ckpt' \
  | tail -n "${LINES}" || echo "(none)"

echo "HINT: empty filtered rm sample supports 'no intentional user rm' in an IT ticket;"
echo "      match is literal absolute TARGET only (relative/~/\$VAR forms may be missed);"
echo "      history is incomplete (new shells, HISTCONTROL, cleared hist) — not proof alone;"
echo "      .pth|checkpoint|ckpt filter can also hide a real delete (false negative)."
