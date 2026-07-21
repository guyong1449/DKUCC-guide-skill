---
name: dkucc-permission-audit
description: >-
  Audits a DKUCC user's natural (default) permissions on /dkucc/home and /work:
  identity/groups, umask, POSIX mode vs NFSv4 ACL, and new-file creation probes.
  Use when the user asks to check permissions, natural access, who can read home/work,
  whether OWNER@ inheritance is healthy, whether modes are misleading (e.g. 777+),
  or before granting collaborator ACL (pair with nfs4-acl for fixes).
custom: true
managed_by_ccswitch: true
---

# DKUCC Permission Audit

Audit **natural** (as-deployed, no collaborator grants yet) effective access for the
current NetID on Duke DKUCC storage. Prefer **evidence from commands** over guessing
from `ls -la` alone.

Related skills (weak reference — do not merge):

- **nfs4-acl** — grant/fix collaborator ACE, repair 070, rewrite OWNER@ inherit. Optional hand-off after audit; **not** auto-run. This skill stays read-only unless the user explicitly asks to change ACL.
- **dkucc-cluster-guide** — storage layout, retention, Slurm background

## Placeholders

| Symbol | Meaning |
|--------|---------|
| `<NETID>` | Current user NetID (`whoami`) |
| `<HOME>` | `/dkucc/home/<NETID>` — not login-node local `/home` |
| `<WORK>` | `/work/<NETID>` |

In examples and agent replies, prefer placeholders over real NetIDs when documenting
for others; when auditing the live user, use `$(whoami)`.

## When this skill applies

| User intent | Action |
|-------------|--------|
| 「检查自然权限 / 默认权限」 | Full audit (Parts A–E) |
| 「别人能不能读我的 home/work」 | Parts B–D + interpret EVERYONE@ / other |
| 「新建文件是什么权限」 | Part D probe |
| 「/work 看起来 777 安全吗」 | Part C NFS4 + Part E interpretation |
| 「要不要先查再加协作者」 | Full audit, then hand off to **nfs4-acl** |

## Tools rule

| Path | Prefer | Avoid for ACL truth |
|------|--------|---------------------|
| `<HOME>` | `ls -ld`, `getfacl` *and* `nfs4_getfacl` | Relying only on mode bits |
| `<WORK>` | **`nfs4_getfacl` / `nfs4_setfacl`** | POSIX `getfacl`/`setfacl` as source of truth |

On OneFS/NFSv4, **owner has no implicit supremacy**. Effective rights come from ACE
entries. POSIX modes (`drwxrwxrwx`) are often **synthesized** and can mislead.

## Quick path (one script)

```bash
bash ~/.cc-switch/skills/dkucc-permission-audit/scripts/audit-natural-perms.sh
# optional target netid (must own the dirs or have read rights):
bash ~/.cc-switch/skills/dkucc-permission-audit/scripts/audit-natural-perms.sh <NETID>
```

Then summarize with the table in Part E. For mask letter meanings, load
[references/interpretation.md](references/interpretation.md).

---

## Part A — Identity and umask

**Plan:** Establish who the process is and default create mask.

**Execute:**

```bash
id
umask
whoami
```

**Verify / report:**

| Field | What to note |
|-------|----------------|
| uid / gid | NetID and primary group (often `dukeusers`) |
| groups | Expect `dkucc`; faculty may also have `dkucc-faculty` |
| umask | Commonly `0022` → new files tend toward `644`/`755` **when** ACL inheritance does not override |

Umask alone does **not** explain `/work` 070 failures; those are ACL inheritance issues (see **nfs4-acl**).

---

## Part B — Mount and path sanity

**Plan:** Confirm the user is looking at NFS home/work, not local `/home`.

**Execute:**

```bash
NETID=$(whoami)
df -h "/dkucc/home/${NETID}" "/work/${NETID}"
mount | grep -E 'dkucc-home|dkucc-work'
which nfs4_getfacl nfs4_setfacl
```

**Verify:**

- Home mount ≈ `.../dkucc-home` on `/dkucc/home`
- Work mount ≈ `.../dkucc-work` on `/work`, type `nfs4`
- `nfs4_getfacl` present under `/usr/bin`

If `df` fails for another NetID’s tree, stop: no permission to audit that path.

---

## Part C — Directory natural ACL (home + work)

**Plan:** Capture POSIX view and NFS4 ACE view for both roots.

**Execute:**

```bash
NETID=$(whoami)
HOME_DIR="/dkucc/home/${NETID}"
WORK_DIR="/work/${NETID}"

echo "=== HOME ls / getfacl / nfs4 ==="
ls -ld "${HOME_DIR}"
getfacl -p "${HOME_DIR}" 2>/dev/null || true
nfs4_getfacl "${HOME_DIR}"

echo "=== WORK ls / getfacl / nfs4 ==="
ls -ld "${WORK_DIR}"
getfacl -p "${WORK_DIR}" 2>/dev/null || true
nfs4_getfacl "${WORK_DIR}"
```

**Verify checklist:**

| Check | Healthy “natural” signal |
|-------|---------------------------|
| Home `OWNER@` | Direct ACE with write + usually `c` (read ACL); often without needing collaborator grants |
| Home `EVERYONE@` / `other` | Often `r-x` / `rxtncy` — others can **list/enter**, not write |
| Work `OWNER@` | Direct `A::OWNER@:...` with full ops; ideally includes `C` if owner must set ACL |
| Work `A:fdi:OWNER@` | Present → new children inherit owner rights (prevents classic 070 lockout) |
| Work `EVERYONE@` | May look wide on the **directory**; still must read **new-file** probe (Part D) |

Flag anomalies:

- Work missing `A:fdi:OWNER@` (or equivalent inherit) while named-user `A:fd:` exists → 070 risk
- Owner lacks `C` but needs to grant collaborators → escalate to **nfs4-acl** / admin
- Home is local `/home` on a login node with no `.snapshot` / different mount → wrong tree

---

## Part D — New-file probe (effective create semantics)

**Plan:** Create ephemeral files under both roots; record mode + NFS4 ACE; delete.

**Execute:**

```bash
NETID=$(whoami)
HOME_DIR="/dkucc/home/${NETID}"
WORK_DIR="/work/${NETID}"

TMPH=$(mktemp -p "${HOME_DIR}" .permtest.XXXXXX)
TMPW=$(mktemp -p "${WORK_DIR}" .permtest.XXXXXX)

echo "=== new home file ==="
ls -l "${TMPH}"
getfacl -p "${TMPH}" 2>/dev/null || true
nfs4_getfacl "${TMPH}" 2>/dev/null || true

echo "=== new work file ==="
ls -l "${TMPW}"
nfs4_getfacl "${TMPW}"

rm -f "${TMPH}" "${TMPW}"
```

**Verify / typical natural outcomes (illustrative, not universal):**

| Location | Often observed | Meaning |
|----------|----------------|---------|
| Home new file | mode `600` (`-rw-------`) | Only owner reads/writes content |
| Work new file | `OWNER@` has `rwa...`; `GROUP@`/`EVERYONE@` often `tcy` only | Others **cannot** read file body despite parent dir looking `777` |

If work new file is `070` / owner cannot write → **stop auditing narrative**; switch to **nfs4-acl** Part B/E.

---

## Part E — Structured report (required output)

Return a short structured summary to the user:

```markdown
## Identity
- NetID / groups / umask

## Mounts
- home: <filesystem> | work: <filesystem>

## Home (`/dkucc/home/<NETID>`)
- POSIX: <mode>
- NFS4 OWNER / GROUP / EVERYONE: <one line each>
- New-file probe: <mode + who can read>

## Work (`/work/<NETID>`)
- POSIX: <mode> (+ if present)
- NFS4 OWNER (direct + fdi?): <yes/no + mask>
- NFS4 GROUP / EVERYONE: <one line each>
- New-file probe: <OWNER vs EVERYONE>

## Verdict
- Who can list home/work roots
- Who can read newly created files
- OWNER@ inherit healthy? (yes/no)
- Next step: none | touch retention | nfs4-acl grant/fix | IT ticket
```

Interpretation details and ACE mask letters: [references/interpretation.md](references/interpretation.md).

---

## Part F — Boundaries

- **Do not** change ACL while “auditing” unless the user explicitly asks to fix/grant.
- **Do not** treat `ls` mode on `/work` as security proof; always cite `nfs4_getfacl`.
- **Do not** use local `/home` on the login node as the DKUCC home root.
- Collaborator grants, 070 repair, `nfs4_setfacl -S` table rewrites → **nfs4-acl** (weak hand-off only; never merge that runbook into this skill).
- Retention / snapshot recovery → **dkucc-cluster-guide** / **dkucc-data-ingest**, not this skill.

## Resources

| Path | Role |
|------|------|
| `scripts/audit-natural-perms.sh` | One-shot evidence dump (Parts A–D) |
| `references/interpretation.md` | Mask letters, healthy patterns, red flags |
