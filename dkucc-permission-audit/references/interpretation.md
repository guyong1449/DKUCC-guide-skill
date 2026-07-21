# Interpreting DKUCC permission audit output

Load this when summarizing `scripts/audit-natural-perms.sh` or Parts C–E of the skill.

## POSIX mode vs NFSv4 ACE

| Signal | Trust for `/dkucc/home` | Trust for `/work` |
|--------|-------------------------|-------------------|
| `ls -ld` mode | Useful first look | **Unreliable alone** (often synthesized) |
| `getfacl` | Useful | Informational only |
| `nfs4_getfacl` | Recommended | **Required source of truth** |

`drwxrwxrwx+` on `/work/<NETID>` does **not** mean every user can read your new files.
Always check the **new-file probe** ACE for `EVERYONE@` / `GROUP@`.

## Common ACE principals

| Principal | Meaning |
|-----------|---------|
| `OWNER@` | Directory/file owner |
| `GROUP@` | Owning group (often maps poorly; treat as “group ACE”) |
| `EVERYONE@` | Everyone else |
| `<netid>@oit.duke.edu` | Named collaborator (not “natural”; see **nfs4-acl**) |

## ACE flags

| Flag form | Meaning |
|-----------|---------|
| `A::principal:mask` | Applies to this object |
| `A:fd:principal:mask` | Applies here + inherits to new files/dirs |
| `A:fdi:principal:mask` | Inherit-only (`i`); does not grant on this object itself |

Healthy work roots usually include both:

- `A::OWNER@:rwaDdxtTnNcCoy` (or similar full owner mask)
- `A:fdi:OWNER@:rwaDdxtTnNcCoy` (inherit so **new** children stay owner-writable)

## Permission letters (short)

| Letter | Dir | File |
|--------|-----|------|
| r | list | read |
| w | create file | write |
| a | create subdir | append |
| d | — | delete |
| D | delete children | — |
| x | enter | execute |
| t/T | read/write attrs | same |
| n/N | read/write xattrs | same |
| c/C | read/write ACL | same (`C` = can `nfs4_setfacl`) |
| o | change owner | change owner |
| y | sync | sync |

| Mask pattern | Typical meaning |
|--------------|-----------------|
| `rwaDdxtTnNcCoy` | Full owner-like (incl. ACL + chown bit) |
| `rwaDdxtTnNcCy` | Full ops but **no** `C` → cannot grant others |
| `rxtncy` | Read/list/enter style |
| `tcy` | Attr/sync only — **no content read/write** |

## Healthy “natural” patterns (examples)

These are common on DKUCC; always confirm with live output.

### Home

- Dir mode often `755` / `drwxr-xr-x`
- NFS4: `OWNER@` write; `GROUP@`/`EVERYONE@` read+enter
- New file often `600` → others cannot read file contents even if they can enter the tree

### Work

- Dir may show `777+` while NFS4 still restricts new files
- Expect `A:fdi:OWNER@` present
- New file: `OWNER@` full; `EVERYONE@` often `tcy` only

## Red flags

| Finding | Likely issue | Next skill |
|---------|--------------|------------|
| New work objects `070` / owner `PermissionError` | Missing inheritable `OWNER@` with named-user inherit | **nfs4-acl** |
| Want to grant collaborator, no `C` on OWNER | Cannot `nfs4_setfacl` | **nfs4-acl** / admin |
| Auditing `/home/$USER` on login node | Wrong filesystem (local XFS) | Use `/dkucc/home/$USER` |
| `EVERYONE@` has `r` on **new files** and that is undesired | Over-permissive inherit | **nfs4-acl** tighten |
| Missing home/work mount | Account/path problem | **dkucc-cluster-guide** |

## Verdict heuristics

1. **List root** ≠ **read file contents**. Separate them in the report.
2. Prefer probe results over parent-directory mode.
3. If only auditing: do not mutate ACL.
4. If user then asks to share a subtree: switch to **nfs4-acl** with plan → execute → verify.
