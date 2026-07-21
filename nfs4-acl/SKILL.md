---
name: nfs4-acl
description: >-
  Manages NFSv4 ACL permissions on Duke DKUCC /work storage (Isilon OneFS).
  Use when granting collaborator access, fixing 070 permission failures,
  or setting up inheritable OWNER@ ACEs on /work/<owner> trees.
custom: true
managed_by_ccswitch: true
---

# NFSv4 ACL on DKUCC /work

Agent-facing runbook for Duke DKUCC `/work` storage. Every major step below uses **plan → execute → verify**. Follow steps in order unless Part E or Part F applies.

## Related skills (weak reference — do not merge)

- **dkucc-permission-audit** — read-only audit of *natural* permissions on `/dkucc/home` and `/work` (identity, umask, `nfs4_getfacl`, new-file probe). Optional before grants; **not** a required gate. Hand off here when the user needs ACL changes, collaborator grants, or 070 repair.
- Keep this skill as the authoritative **mutation / 070 / grant** runbook. Do not fold audit prose into this file.

## Placeholders

| Symbol | Meaning |
|--------|---------|
| `<WORK_ROOT>` | `/work` mount root |
| `<OWNER>` | Directory owner's NetID (no domain) |
| `<COLLABORATOR>` | Collaborator's NetID (no domain) |
| `<OWNER_WORK_DIR>` | Owner's share root, e.g. `<WORK_ROOT>/<OWNER>` or a subdir like `<WORK_ROOT>/<OWNER>/project/` |

Principal format in ACEs: `<COLLABORATOR>@oit.duke.edu`

**Never use real NetIDs in examples, logs, or skill output.** Use placeholders only.

In shell commands below, replace `<WORK_ROOT>`, `<OWNER>`, `<COLLABORATOR>`, and `<OWNER_WORK_DIR>` with real values before running.

---

## Part A: Background

### Storage and tools

- **Mount:** `<WORK_ROOT>` is Isilon OneFS via NFSv4 (`oit-nas-dku13.oit.duke.edu:/ifs/oit-nas-dku13/dkucc-work`).
- **ACL tools:** Use `nfs4_getfacl` / `nfs4_setfacl`. Do **not** use POSIX `getfacl` / `setfacl`.
- **Who can modify ACLs:** Only the directory owner (`OWNER@`) or a principal with `C` (write ACL) on that path.

### NFSv4 ACL model (critical)

On OneFS/NFSv4, **the owner has no implicit supremacy**. Effective permissions come from **ACE entries only**. POSIX mode bits (`ls -la`, `stat`) are **synthesized** from ACEs and can mislead you.

Both POSIX mode and NFSv4 ACEs apply. Always inspect with `nfs4_getfacl`; do not rely on `chmod` alone to grant access.

### Permission mask reference

Full collaboration (owner-level, minus change-owner): `rwaDdxtTnNcCoy`

| Letter | On directory | On file |
|--------|--------------|---------|
| r | list | read |
| w | create file | write |
| a | create subdir | append |
| d | — | delete file |
| D | delete children | — |
| x | enter | execute |
| t/T | read/write attributes | read/write attributes |
| n/N | read/write xattrs | read/write xattrs |
| c/C | read/write ACL | read/write ACL |
| y | sync I/O | sync I/O |
| o | change owner | change owner |

| Mask | Effect |
|------|--------|
| `rwaDdxtTnNcCy` | Full file ops; **cannot** call `nfs4_setfacl` or grant access to others |
| `rwaDdxtTnNcCoy` | Same plus `C`: can modify ACL and delegate access |

Prefer omitting `C` for collaborators unless they must manage permissions.

### ACE syntax

```
A::<principal>:<permissions>        # direct ACE on this object
A:fd:<principal>:<permissions>       # inherit to new files and subdirs (also applies here)
A:fdi:<principal>:<permissions>      # inherit-only (i); does not grant access on this dir itself
```

**`fdi` flags:** `f` = file-inherit, `d` = dir-inherit, `i` = inherit-only. An `A:fdi:OWNER@` ACE ensures **CREATOR OWNER** semantics on new children without duplicating direct owner ACEs on the parent.

---

## Part B: The 070 failure mode

### Symptom

After granting collaborator access, **new** directories and files show mode **`070`** (`d---rwx---` for dirs, `---rwx---` for files). The owner (`<OWNER>`) gets `PermissionError` on `touch`, write, or `mkdir` inside their own tree.

### Root cause

An **inheritable collaborator ACE** (`A:fd:<COLLABORATOR>@...`) exists on `<OWNER_WORK_DIR>` (or an ancestor write root) but **no inheritable OWNER@ ACE** (`A:fdi:OWNER@...` or equivalent).

OneFS synthesizes POSIX owner bits as `---` when a named-user inherit ACE is present without a matching inheritable `OWNER@` ACE. The collaborator may have full access while the owner appears locked out.

**umask does NOT fix this.** The mode is derived from ACL inheritance, not umask.

### Verification experiment

Run as `<OWNER>` after reproducing the failure (collaborator inherit ACE present, no OWNER@ inherit):

**Plan:** Confirm mount, identity, and that new objects show 070.

**Execute:**

```bash
# Pre-check
mount | grep '<WORK_ROOT>'
id
nfs4_getfacl <OWNER_WORK_DIR> | grep -E 'OWNER@|<COLLABORATOR>@'

# Create a test object (may fail or produce 070)
mkdir -p <OWNER_WORK_DIR>/_070_test/sub
stat -c '%A %a %n' <OWNER_WORK_DIR>/_070_test <OWNER_WORK_DIR>/_070_test/sub
touch <OWNER_WORK_DIR>/_070_test/sub/file.txt 2>&1 || true
stat -c '%A %a %n' <OWNER_WORK_DIR>/_070_test/sub/file.txt 2>/dev/null || true
```

**Verify:** Expect `070` on new dir/file and owner write failure. `nfs4_getfacl` on the new dir shows collaborator inherit ACEs but **no** inherited `OWNER@`.

**Cleanup:** `rm -rf <OWNER_WORK_DIR>/_070_test` (after fix, or via parent ACL if owner cannot delete).

---

## Part C: Complete grant workflow (one-pass)

Use when granting `<COLLABORATOR>` access to `<OWNER_WORK_DIR>`. Do **all** steps in order.

### Step 0 — Pre-flight

**Plan:** Confirm you are on DKUCC, `<WORK_ROOT>` is mounted, you are `<OWNER>` (or have `C`), and you know the target path. Substitute all placeholders in the commands below with real paths and NetIDs.

**Execute:**

```bash
mount | grep '<WORK_ROOT>'
id   # must show uid/groups for <OWNER>
test -d <OWNER_WORK_DIR> && echo "target exists"

# Backup ACL before any change
TS=$(date +%Y%m%d_%H%M%S)
nfs4_getfacl <OWNER_WORK_DIR> > /tmp/acl-backup-${TS}.txt
echo "Backup: /tmp/acl-backup-${TS}.txt"

# Baseline: count existing 070 objects
find <OWNER_WORK_DIR> -user <OWNER> -perm 070 2>/dev/null | wc -l
nfs4_getfacl <OWNER_WORK_DIR>
```

**Verify:** Mount present; `id` matches `<OWNER>`; backup file non-empty; you understand current ACEs.

---

### Step 1 — Grant collaborator ACL

**Plan:** Add direct + inherit ACEs for `<COLLABORATOR>`. Choose Method 1 (top only) or Method 2 (recursive) based on whether existing files must be touched.

| Approach | Commands | When to use |
|----------|----------|-------------|
| **Method 1:** directory only | `nfs4_setfacl -a` (no `-R`) on target | New files inherit via `A:fd:`; existing files unchanged |
| **Method 2:** recursive | `nfs4_setfacl -R -a` on target | Collaborator must access/modify **existing** content |

**Execute (Method 1 — usual for new collaboration):**

```bash
nfs4_setfacl -a 'A::<COLLABORATOR>@oit.duke.edu:rwaDdxtTnNcCy' <OWNER_WORK_DIR>
nfs4_setfacl -a 'A:fd:<COLLABORATOR>@oit.duke.edu:rwaDdxtTnNcCy' <OWNER_WORK_DIR>
```

**Execute (Method 2 — add if tree already has content collaborator must touch):**

```bash
nfs4_setfacl -R -a 'A::<COLLABORATOR>@oit.duke.edu:rwaDdxtTnNcCy' <OWNER_WORK_DIR>
nfs4_setfacl -R -a 'A:fd:<COLLABORATOR>@oit.duke.edu:rwaDdxtTnNcCy' <OWNER_WORK_DIR>
```

**Warning:** `-R` walks the entire subtree and is **slow** on large trees. Confirm `<OWNER_WORK_DIR>` is the intended target before running.

Running both Method 1 and Method 2 on the same directory creates duplicate ACE entries (harmless but noisy).

**Verify:**

```bash
nfs4_getfacl <OWNER_WORK_DIR> | grep '<COLLABORATOR>@'
# Expect both A:: and A:fd: lines
```

---

### Step 2 — Solution 1: Add inheritable OWNER@ ACE (CRITICAL)

**Do this immediately after Step 1.** Skipping this step causes the 070 failure mode (Part B).

**Plan:** Add `A:fdi:OWNER@` on the grant root and on every **intermediate active write root** where new dirs/files will be created (existing trees often have multiple such roots).

**Execute — top level:**

```bash
nfs4_setfacl -a 'A:fdi:OWNER@:rwaDxtTnNcCy' <OWNER_WORK_DIR>
```

**Execute — intermediate active write roots** (if tree already exists; adjust paths to your layout):

```bash
# Examples — apply to each directory that receives new writes
for d in \
  <OWNER_WORK_DIR>/<ACTIVE_WRITE_ROOT_1> \
  <OWNER_WORK_DIR>/<ACTIVE_WRITE_ROOT_2> \
  <OWNER_WORK_DIR>/<ACTIVE_WRITE_ROOT_2>/.nested \
  <OWNER_WORK_DIR>/<ACTIVE_WRITE_ROOT_2>/.archive \
  ; do
  if [ -d "$d" ]; then
    nfs4_setfacl -a 'A:fdi:OWNER@:rwaDxtTnNcCy' "$d"
    echo "Applied fdi OWNER@ on $d"
  fi
done
```

**Execute — bulk propagation to all owner-owned directories** (existing large trees):

```bash
echo "Directory count:" $(find <OWNER_WORK_DIR> -user <OWNER> -type d 2>/dev/null | wc -l)
LOG=/tmp/nfs4-fdi-owner-$(date +%Y%m%d_%H%M%S).log
COUNT=0
while IFS= read -r -d '' d; do
  nfs4_setfacl -a 'A:fdi:OWNER@:rwaDxtTnNcCy' "$d" && \
    echo "OK $d" >> "$LOG" || echo "FAIL $d" >> "$LOG"
  COUNT=$((COUNT + 1))
  if [ $((COUNT % 100)) -eq 0 ]; then echo "Progress: $COUNT dirs..."; fi
done < <(find <OWNER_WORK_DIR> -user <OWNER> -type d -print0)
echo "Done. Log: $LOG"
```

**Verify:**

```bash
nfs4_getfacl <OWNER_WORK_DIR> | grep 'A:fdi:OWNER@'
# Spot-check intermediate roots
nfs4_getfacl <OWNER_WORK_DIR>/<ACTIVE_WRITE_ROOT_1> 2>/dev/null | grep -E 'A:fdi:OWNER@|A:fd:OWNER@' || true
```

---

### Step 3 — Fix existing 070 objects (chmod remediation)

**Plan:** Repair POSIX mode on objects already created with 070. ACLs may already be correct; `chmod` fixes synthesized mode bits for owner usability.

**Execute:**

```bash
find <OWNER_WORK_DIR> -user <OWNER> -type d -perm 070 -exec chmod 0775 {} +
find <OWNER_WORK_DIR> -user <OWNER> -type f -perm 070 -exec chmod 0664 {} +
```

**If chmod fails on a 070 directory:** The owner may still have ACL-modify rights via NFSv4 on the **parent**. Try:

```bash
nfs4_setfacl -a 'A:fdi:OWNER@:rwaDxtTnNcCy' <parent-of-stuck-dir>
chmod 0775 <stuck-dir>
```

**Symlinks showing 070 are harmless — ignore them.**

**Verify:**

```bash
find <OWNER_WORK_DIR> -user <OWNER> -type d -perm 070 | head
find <OWNER_WORK_DIR> -user <OWNER> -type f -perm 070 | head
# Expect no real dirs/files (symlinks may remain)
```

---

### Step 4 — End-to-end verification

**Plan:** Prove new objects get correct mode and owner can write deep in the tree.

**Execute:**

```bash
VERIFY=<OWNER_WORK_DIR>/_acl_verify/sub/subsub
mkdir -p "$VERIFY"
stat -c '%A %a %n' <OWNER_WORK_DIR>/_acl_verify <OWNER_WORK_DIR>/_acl_verify/sub "$VERIFY"
touch "$VERIFY/testfile"
stat -c '%A %a %n' "$VERIFY/testfile"
nfs4_getfacl "$VERIFY"
```

**Verify:**

- Each level shows **`770`** (or `775`/`664`), **not `070`**.
- `touch` succeeds (no `PermissionError`).
- `nfs4_getfacl` on new dir shows inherited **`OWNER@`** and **`<COLLABORATOR>@`** ACEs.

**Cleanup:**

```bash
rm -rf <OWNER_WORK_DIR>/_acl_verify
```

---

### Step 5 — Post-grant checklist

**Plan:** Confirm no remaining 070 objects and document changes.

**Execute:**

```bash
REMAINING=$(find <OWNER_WORK_DIR> -user <OWNER> -perm 070 2>/dev/null | wc -l)
echo "Remaining 070 entries: $REMAINING (expect 0 or symlinks only)"
nfs4_getfacl <OWNER_WORK_DIR>
```

**Verify:** `REMAINING` is 0 or symlinks only. Record:

- Backup path (`/tmp/acl-backup-*.txt`)
- Method 1 vs 2 used
- Intermediate dirs patched
- Bulk propagation log path (if run)
- Remaining 070 count

**Collaborator smoke test** (as `<COLLABORATOR>`):

```bash
cat <OWNER_WORK_DIR>/some_existing_file    # read
echo "test" > <OWNER_WORK_DIR>/collab_test.txt
rm <OWNER_WORK_DIR>/collab_test.txt
mkdir <OWNER_WORK_DIR>/collab_subdir
rmdir <OWNER_WORK_DIR>/collab_subdir
nfs4_getfacl <OWNER_WORK_DIR>
```

---

## Part D: Pitfalls and safety

### Common pitfalls

1. **`touch` false failure** — `touch` creates the file (`w` on parent) then sets timestamps (`T` on file). Inherited ACL on new files often lacks `T`, so exit code is 1 even though the file was created. Verify with `ls`, not `$?` from `touch`. Prefer `echo 'content' > file` in scripts.
2. **070 lockout (Part B)** — Collaborator inherit ACE without `A:fdi:OWNER@` causes owner mode `---`. Always run Step 2 immediately after Step 1.
3. **Existing files unchanged after Method 1** — Inherit ACEs affect only **new** children. Use `-R` (Method 2) for existing content.
4. **Duplicate ACEs** — Running Method 1 then Method 2 duplicates entries. Functionally fine; cosmetic clutter only.
5. **Cannot self-elevate** — Without `C`, `nfs4_setfacl` fails. `<OWNER>` must run grant commands.
6. **Intermediate write roots** — Granting only on top-level `<OWNER_WORK_DIR>` may miss nested roots (`<ACTIVE_WRITE_ROOT_1>/`, `<ACTIVE_WRITE_ROOT_2>/.nested/`, etc.) where jobs actually create files. Patch each active write root in Step 2.

### Safety

- Share a **specific subdir** (`<OWNER_WORK_DIR>`), not all of `<WORK_ROOT>/<OWNER>/`.
- Full-home share exposes dotfiles, configs, and everything the collaborator can delete.
- `<WORK_ROOT>` has **no backup**; files older than **75 days** may be purged (Duke policy).
- Omit `C` for collaborators unless they must delegate access.
- Always backup ACL with `nfs4_getfacl` before changes (Step 0).
- **Method 2 (`-R`)** is slow on large trees; double-check the target path before recursive grants.

---

## Part E: Collaborator already granted but 070 not fixed

**Symptom:** `nfs4_getfacl` already shows `A:fd:<COLLABORATOR>@...` on `<OWNER_WORK_DIR>`, but owner still sees 070 on new objects or cannot write.

**Plan:** Skip Step 1. Run Steps 2 → 3 → 4 → 5.

**Execute:**

1. **Step 2** — Add inheritable `OWNER@` (`A:fdi:OWNER@` preferred, or `A:fd:OWNER@`) on grant root, intermediate write roots, and bulk-propagate if needed.
2. **Step 3** — `chmod` remediation on existing 070 dirs/files.
3. **Step 4** — End-to-end `_acl_verify` test.
4. **Step 5** — Post-grant checklist.

**Verify:** Same criteria as Part C Steps 4–5.

Quick diagnostic:

```bash
nfs4_getfacl <OWNER_WORK_DIR> | grep -E 'OWNER@|<COLLABORATOR>@'
find <OWNER_WORK_DIR> -user <OWNER> -perm 070 | wc -l
```

If collaborator ACEs exist but no inheritable `OWNER@` (`A:fdi:OWNER@` or `A:fd:OWNER@`) anywhere in the inheritance chain, you are in this scenario.

---

## Part F: Broken ACL state (incremental SETACL blocked)

**Symptom:** Every **incremental** `nfs4_setfacl` operation fails with `Invalid argument` — `-a`, `-x`, `-m`, and `-i` all fail. This is **independent of POSIX owner identity**; `nfs4_setfacl --test` may preview successfully but the actual write still fails. Part E remediation (adding `A:fdi:OWNER@` via `-a`) cannot proceed.

**Validated on Isilon OneFS, June 2026** (e.g. Spectralmae `datasets/` tree).

### Diagnostic signatures

A directory ACL in this broken state often combines several of:

1. **Missing** `A:fdi:OWNER@`
2. **Duplicate collaborator ACEs** (e.g. 3× `A:fd:<COLLABORATOR>@` + 2× `A::<COLLABORATOR>@`)
3. **Legacy permission masks** on collaborator ACEs (e.g. `rwx` instead of `rwaDdxtTnNcCoy`)
4. A **Storage Admins group ACE:** `A:g:Storage Admins@oit.duke.edu:rxtncy`

### Storage Admins ACE (Duke/Isilon)

- **What it is:** An NFSv4 ACE for the Duke storage-admin group `Storage Admins@oit.duke.edu` with mask `rxtncy` (read, execute, attribute read, ACL read, etc.). It lets storage admins manage the directory via group membership.
- **While ACL is broken:** A full-table `-S` that **includes** this ACE also fails with `Invalid argument`. A **clean template without** Storage Admins succeeds.
- **After successful `-S` fix:** The Storage Admins ACE is **not retained** (the template does not include it).
- **Owner cannot re-add it:** `nfs4_setfacl -a` to restore Storage Admins still returns `Invalid argument`. **DKUCC/Isilon admins** must restore it on the OneFS side if required.
- **Impact on normal collaboration:** Removing Storage Admins typically does **not** affect owner or collaborator access. It only affects storage admins who rely on that group ACE.

### Remediation path (full-table replace)

Incremental `-a` is not viable here. Use `nfs4_setfacl -S` (stdin ACL list) after validating with `--test`.

**Plan:** Backup ACL, build a clean template aligned with a known-good grant root (e.g. SkillReuse subtree), test with `--test -S`, then apply `-S`.

**Execute — test then apply:**

```bash
TS=$(date +%Y%m%d_%H%M%S)
nfs4_getfacl <OWNER_WORK_DIR> > /tmp/acl-backup-broken-${TS}.txt

nfs4_setfacl --test -S - <OWNER_WORK_DIR> <<'EOF'
A:fdi:OWNER@:rwaDdxtTnNcCoy
A::OWNER@:rwaDdxtTnNcCoy
A::GROUP@:rwaDxtTnNcy
A::<COLLABORATOR>@oit.duke.edu:rwaDdxtTnNcCoy
A:fd:<COLLABORATOR>@oit.duke.edu:rwaDdxtTnNcCoy
A::EVERYONE@:rwaDxtTnNcy
EOF

nfs4_setfacl -S - <OWNER_WORK_DIR> <<'EOF'
A:fdi:OWNER@:rwaDdxtTnNcCoy
A::OWNER@:rwaDdxtTnNcCoy
A::GROUP@:rwaDxtTnNcy
A::<COLLABORATOR>@oit.duke.edu:rwaDdxtTnNcCoy
A:fd:<COLLABORATOR>@oit.duke.edu:rwaDdxtTnNcCoy
A::EVERYONE@:rwaDxtTnNcy
EOF
```

Replace `<COLLABORATOR>` with the actual NetID. Adjust the template if your reference tree uses different masks (e.g. omit `C` for collaborators: `rwaDdxtTnNcCy`).

**Verify:**

```bash
nfs4_getfacl <OWNER_WORK_DIR>
# Incremental ops should work again
nfs4_setfacl -a 'A:fdi:OWNER@:rwaDxtTnNcCy' <OWNER_WORK_DIR>

# Spot test: new dir should be 770, not 070
mkdir -p <OWNER_WORK_DIR>/_broken_acl_verify/sub
stat -c '%A %a %n' <OWNER_WORK_DIR>/_broken_acl_verify <OWNER_WORK_DIR>/_broken_acl_verify/sub
rm -rf <OWNER_WORK_DIR>/_broken_acl_verify
```

**Post-fix cautions:**

- Do **not** remove `A:fdi:OWNER@` with `-x` during cleanup — `-x` removes inherit ACEs and can re-trigger 070 (Part B).
- After fix, run Part C Steps 3–5 if the tree still has 070 objects or needs end-to-end verification.

---

## Reference

For the same content in Chinese, see [reference-zh.md](reference-zh.md).
