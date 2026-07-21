#!/usr/bin/env bash
# Audit natural DKUCC permissions for home + work.
# Usage: audit-natural-perms.sh [NETID]
set -euo pipefail

NETID="${1:-$(whoami)}"
HOME_DIR="/dkucc/home/${NETID}"
WORK_DIR="/work/${NETID}"

die() { echo "ERROR: $*" >&2; exit 1; }

[[ -d "${HOME_DIR}" ]] || die "missing ${HOME_DIR}"
[[ -d "${WORK_DIR}" ]] || die "missing ${WORK_DIR}"

section() {
  printf '\n========== %s ==========\n' "$1"
}

section "Identity"
id
echo "whoami=$(whoami)  target_netid=${NETID}"
echo -n "umask="; umask

section "Mounts"
df -h "${HOME_DIR}" "${WORK_DIR}" || true
mount | grep -E 'dkucc-home|dkucc-work' || true
command -v nfs4_getfacl || echo "WARN: nfs4_getfacl not found"
command -v nfs4_setfacl || echo "WARN: nfs4_setfacl not found"

section "HOME directory (${HOME_DIR})"
ls -ld "${HOME_DIR}"
echo "--- getfacl ---"
getfacl -p "${HOME_DIR}" 2>/dev/null || echo "(getfacl unavailable)"
echo "--- nfs4_getfacl ---"
nfs4_getfacl "${HOME_DIR}" 2>/dev/null || echo "(nfs4_getfacl failed)"

section "WORK directory (${WORK_DIR})"
ls -ld "${WORK_DIR}"
echo "--- getfacl (informational only; NFS4 is source of truth) ---"
getfacl -p "${WORK_DIR}" 2>/dev/null || echo "(getfacl unavailable)"
echo "--- nfs4_getfacl ---"
nfs4_getfacl "${WORK_DIR}" 2>/dev/null || echo "(nfs4_getfacl failed)"

section "New-file probe (create + inspect + delete)"
TMPH=""
TMPW=""
cleanup() {
  [[ -n "${TMPH}" && -e "${TMPH}" ]] && rm -f "${TMPH}" || true
  [[ -n "${TMPW}" && -e "${TMPW}" ]] && rm -f "${TMPW}" || true
}
trap cleanup EXIT

if [[ "$(whoami)" != "${NETID}" ]]; then
  echo "SKIP probe: current user $(whoami) != ${NETID} (cannot create as owner)"
else
  TMPH=$(mktemp -p "${HOME_DIR}" .permtest.XXXXXX)
  TMPW=$(mktemp -p "${WORK_DIR}" .permtest.XXXXXX)

  echo "--- home new file: ${TMPH} ---"
  ls -l "${TMPH}"
  getfacl -p "${TMPH}" 2>/dev/null || true
  nfs4_getfacl "${TMPH}" 2>/dev/null || true

  echo "--- work new file: ${TMPW} ---"
  ls -l "${TMPW}"
  nfs4_getfacl "${TMPW}" 2>/dev/null || true
fi

section "OWNER@ inherit quick grep (work)"
nfs4_getfacl "${WORK_DIR}" 2>/dev/null | grep -E 'OWNER@|EVERYONE@|GROUP@' || true
if nfs4_getfacl "${WORK_DIR}" 2>/dev/null | grep -q 'A:fdi:OWNER@'; then
  echo "OK: A:fdi:OWNER@ present on work root"
else
  echo "WARN: A:fdi:OWNER@ NOT found — check inherit / 070 risk if named-user fd ACEs exist"
fi

section "Done"
echo "Interpret with: ~/.cc-switch/skills/dkucc-permission-audit/references/interpretation.md"
