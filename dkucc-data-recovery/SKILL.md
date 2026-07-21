---
name: dkucc-data-recovery
description: >-
  Recovers missing or purged data on Duke DKUCC /work (and optionally /dkucc/home)
  from short-lived NFS Isilon snapshots under .snapshot/ using rsync.
  Use when files disappeared, directories look emptied, retention may have purged data,
  user asks about "no backup" vs snapshots, needs IT ticket evidence after loss,
  or needs post-restore touch keepalive. Not for ACL grants (use nfs4-acl)
  and not for routine touch-only cron (use dkucc-data-ingest).
custom: true
managed_by_ccswitch: true
---

# DKUCC Data Recovery

Recover data from **NFS snapshots** on DKUCC Isilon mounts. Prefer evidence and
`rsync` over guessing. Every major step: **plan → execute → verify**.

## Related skills (weak reference — do not merge)

| Skill | Role |
|-------|------|
| **dkucc-data-ingest** | Routine `/work` **touch** keepalive / space checks (prevention) |
| **dkucc-cluster-guide** | Retention policy background; storage layout |
| **nfs4-acl** | Permission grants / 070 — unrelated to snapshot restore |
| **dkucc-permission-audit** | Read-only permission audit — unrelated to restore |

This skill owns **detect loss → snapshot compare → rsync restore → verify → optional IT evidence**.
Do not fold the detailed 070/grant runbook into this file.

## Placeholders

| Symbol | Meaning |
|--------|---------|
| `<NETID>` | Owner NetID (`whoami`) |
| `<WORK>` | `/work/<NETID>` |
| `<HOME>` | `/dkucc/home/<NETID>` (same snapshot idea; different pool name) |
| `<REL>` | Path relative to `<WORK>` or `<HOME>` (e.g. `datasets/foo`) |
| `<SNAP>` | Full snapshot directory name under `.snapshot/` |

Prefer placeholders in docs; use `$(whoami)` on the live host.

## Policy: 「无备份」vs 快照

| Claim | Meaning |
|-------|---------|
| **No official backup** | OIT does not promise long-term archival restore for users |
| **Snapshots exist** | Short-cycle NFS snaps under `.snapshot/`; usable **while retained** |
| **If snap rolled off** | Cluster-side restore unlikely; need off-site copy or IT ticket (no guarantee) |

One-liner: 发现丢失 → 查 `.snapshot` → 选定删前快照 → `rsync` → 校验 → `touch` →（可选）工单。

---

## Part A — Confirm loss (not wrong path)

**Plan:** Prove the live path is empty/wrong, not a typo.

**Execute:**

```bash
NETID=$(whoami)
REL="<REL>"
ls -la "/work/${NETID}/${REL}"
du -sh "/work/${NETID}/${REL}"
stat "/work/${NETID}/${REL}"
```

**Verify — suspicious signals:**

- Path exists but `du` is tiny (KB) while it used to be GBs
- Child dirs share the same early-morning `Modify` timestamp
- Optional: scan `~/.bash_history` for intentional `rm` of that tree (see Part F / `scan-bash-history.sh`)

Script helper:

```bash
bash ~/.cc-switch/skills/dkucc-data-recovery/scripts/check-live-path.sh --rel <REL>
```

---

## Part B — List snapshots

**Plan:** See which snap dates still exist.

**Execute:**

```bash
ls -la /work/$(whoami)/.snapshot/
```

**Typical names (prefix can change; always `ls` first):**

- Work: `24_ifsoitnasdku13dkuccwork_YYYY-MM-DD_00:00`
- Home: `24_ifsoitnasdku13dkucchome_YYYY-MM-DD_00:00` under `/dkucc/home/$USER/.snapshot/`

**Verify:** At least one snap older than the suspected delete window. If `.snapshot` missing/empty → skip to Part F.

```bash
bash ~/.cc-switch/skills/dkucc-data-recovery/scripts/list-snapshots.sh
# optional: --root home
```

---

## Part C — Compare before / after; pick restore source

**Plan:** Choose the **latest snap that still holds full data before the loss**.

**Execute:**

```bash
NETID=$(whoami)
REL="<REL>"
# Replace SNAP_* with real directory names from Part B
du -sh "/work/${NETID}/.snapshot/<SNAP_BEFORE>/${REL}"
du -sh "/work/${NETID}/.snapshot/<SNAP_AFTER>/${REL}"
```

**Verify:** `SNAP_BEFORE` has expected size/file count; `SNAP_AFTER` empty or collapsed.

```bash
bash ~/.cc-switch/skills/dkucc-data-recovery/scripts/compare-snapshots.sh \
  --rel <REL> --before <SNAP_BEFORE> --after <SNAP_AFTER>
```

---

## Part D — Restore with `rsync` (never `cp -a` as primary)

**Plan:** Copy from snapshot tree into live tree.

**Why not `cp -a`:** Snapshot and live paths may appear as the same inode; `cp -a` often errors with `are the same file` and copies nothing.

**Execute:**

```bash
NETID=$(whoami)
SNAP="<SNAP>"          # full name, e.g. 24_ifsoitnasdku13dkuccwork_2026-05-15_00:00
REL="<REL>"
SRC="/work/${NETID}/.snapshot/${SNAP}/${REL}"
DEST="/work/${NETID}/${REL}"

mkdir -p "${DEST}"
rsync -a --info=progress2 "${SRC}/" "${DEST}/"
du -sh "${DEST}"
```

**Preferred script:**

```bash
bash ~/.cc-switch/skills/dkucc-data-recovery/scripts/restore-from-snapshot.sh \
  --snap <SNAP> \
  --rel <REL>
# optional: --root home
# optional: --dry-run
```

**Verify:** `du` / file counts match snap source (Part E).

---

## Part E — Verify + touch keepalive

**Plan:** Confirm restore; refresh atime/mtime so retention is less likely to re-purge.

**Execute:**

```bash
NETID=$(whoami)
REL="<REL>"
find "/work/${NETID}/${REL}" -type f | wc -l
nice find "/work/${NETID}/${REL}" -type f -exec touch {} +
```

Large trees: run under `tmux` / `nohup`. For **monthly whole-tree touch**, hand off weakly to **dkucc-data-ingest** (do not duplicate cron policy here).

```bash
bash ~/.cc-switch/skills/dkucc-data-recovery/scripts/touch-after-restore.sh --rel <REL>
```

**Verify:** File count stable; touch completes without permission errors (ACL issues → **nfs4-acl** / **dkucc-permission-audit**, not this skill).

---

## Part F — No snapshot / need root cause → IT evidence

**Plan:** Collect evidence; user submits OIT/DKUCC ticket. Recovery not guaranteed.

**Collect at minimum:**

- `whoami`, `id`, `hostname`, `date`
- `df -h /work/$USER`
- `stat` on emptied dirs
- `du` of before/after snaps (or note snaps missing)
- Relevant `~/.bash_history` lines (see below)

### bash_history probe (IT evidence)

When filing a ticket or ruling out accidental `rm`, scan history **scoped to the lost path**. Filter out training-artifact deletes (`.pth` / `checkpoint` / `ckpt`) so counts stay meaningful.

```bash
TARGET="/work/$(whoami)/<REL>"
HIST="$HOME/.bash_history"

# Counts
grep -cE '^[[:space:]]*rm[[:space:]]+' "$HIST" || true
grep -E '^[[:space:]]*rm[[:space:]]+' "$HIST" \
  | grep -viE '\.pth|checkpoint|ckpt' \
  | grep -cF "$TARGET" || true

# Samples
grep -E '^[[:space:]]*rm[[:space:]]+' "$HIST" \
  | grep -viE '\.pth|checkpoint|ckpt' \
  | grep -F "$TARGET" | tail -20
grep -F "$TARGET" "$HIST" | grep -viE '\.pth|checkpoint|ckpt' | tail -20
```

**Script helper:**

```bash
bash ~/.cc-switch/skills/dkucc-data-recovery/scripts/scan-bash-history.sh --rel <REL>
```

**Caveat:** empty `rm` sample supports "no intentional user rm" in a ticket narrative, but:

- Matching is **literal absolute** `TARGET` only (`/work/$USER/<REL>`). Relative paths, `~/…`, or `$VAR` forms in history may be missed.
- History is **incomplete** (new shells, `HISTCONTROL`, cleared hist) and is not sole proof.
- Filtering `.pth|checkpoint|ckpt` can hide a real delete if the same line also matches those tokens.

```bash
bash ~/.cc-switch/skills/dkucc-data-recovery/scripts/print-it-evidence.sh \
  --rel <REL> \
  --size "<human size description>" \
  --window "<delete time window>" \
  --snap-before <SNAP_BEFORE> \
  --snap-after <SNAP_AFTER>
```

Ticket body template: [references/it-ticket-template.md](references/it-ticket-template.md).

---

## Part G — `/dkucc/home` (same method)

Home is also NFS with `.snapshot/` (`*dkucchome*`). Same Parts A–F with:

- Root: `/dkucc/home/<NETID>`
- Scripts: add `--root home`

Do **not** use login-node local `/home` (often local XFS, no these snaps).

---

## Part H — Required report format

After helping the user, return:

```markdown
## Loss check
- Live path / du / mtime signals

## Snapshots
- Available dates; chosen BEFORE snap

## Restore
- rsync command or script flags; dry-run? yes/no
- Post-du / file count

## Keepalive
- touch done? scope?

## Next
- none | schedule dkucc-data-ingest touch | IT ticket | off-site backup advice
```

---

## Boundaries

- **Do** use `rsync` from `.snapshot`; **do not** primary-restore with `cp -a`.
- **Do not** claim official long-term backup exists.
- **Do not** change NFSv4 ACL here.
- **Do not** merge this skill into **dkucc-data-ingest** (keepalive) or **nfs4-acl**.
- Destructive: restoring can overwrite live files under `<REL>` — confirm path; offer `--dry-run` first for large trees.

## Resources

| Path | Role |
|------|------|
| `scripts/check-live-path.sh` | Part A |
| `scripts/list-snapshots.sh` | Part B |
| `scripts/compare-snapshots.sh` | Part C |
| `scripts/restore-from-snapshot.sh` | Part D |
| `scripts/touch-after-restore.sh` | Part E |
| `scripts/print-it-evidence.sh` | Part F |
| `scripts/scan-bash-history.sh` | Part F — bash_history rm probe |
| `references/sop-zh.md` | Human-readable Chinese SOP (canonical narrative) |
| `references/it-ticket-template.md` | Ticket subject/body |
