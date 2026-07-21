#!/usr/bin/env bash
# Shared helpers for dkucc-data-recovery scripts.
# shellcheck shell=bash

die() { echo "ERROR: $*" >&2; exit 1; }

resolve_root() {
  local root_kind="${1:-work}"
  local netid="${2:-$(whoami)}"
  case "${root_kind}" in
    work)
      ROOT="/work/${netid}"
      SNAP_HINT="dkuccwork"
      ;;
    home)
      ROOT="/dkucc/home/${netid}"
      SNAP_HINT="dkucchome"
      ;;
    *)
      die "unknown --root '${root_kind}' (use work|home)"
      ;;
  esac
  SNAP_ROOT="${ROOT}/.snapshot"
  [[ -d "${ROOT}" ]] || die "missing ${ROOT}"
}

parse_common_args() {
  NETID="$(whoami)"
  ROOT_KIND="work"
  REL=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --netid) NETID="$2"; shift 2 ;;
      --root) ROOT_KIND="$2"; shift 2 ;;
      --rel) REL="$2"; shift 2 ;;
      *)
        # leave unknown for caller
        break
        ;;
    esac
  done
  resolve_root "${ROOT_KIND}" "${NETID}"
  REMAINING_ARGS=("$@")
}
