# DKUCC /work 上的 NFSv4 ACL

面向用户与 agent 的中文参考，与 [SKILL.md](SKILL.md) 同等深度。每个主要步骤均包含 **计划 → 执行 → 验证**。

## 占位符

| 符号 | 含义 |
|------|------|
| `<WORK_ROOT>` | `/work` 挂载根 |
| `<OWNER>` | 目录 owner 的 NetID（不含域名） |
| `<COLLABORATOR>` | 协作者的 NetID（不含域名） |
| `<OWNER_WORK_DIR>` | 共享根目录，如 `<WORK_ROOT>/<OWNER>` 或 `<WORK_ROOT>/<OWNER>/project/` |

ACE 中的主体格式：`<COLLABORATOR>@oit.duke.edu`

**示例和输出中禁止使用真实 NetID**，一律使用占位符。

下文 shell 命令中的 `<WORK_ROOT>`、`<OWNER>`、`<COLLABORATOR>`、`<OWNER_WORK_DIR>` 等占位符，执行前须替换为实际路径与 NetID。

---

## 第一部分：背景

### 存储与工具

- **挂载：** `<WORK_ROOT>` 为 Isilon OneFS，NFSv4 挂载（`oit-nas-dku13.oit.duke.edu:/ifs/oit-nas-dku13/dkucc-work`）。
- **ACL 工具：** 使用 `nfs4_getfacl` / `nfs4_setfacl`，**不要**用 POSIX 的 `getfacl` / `setfacl`。
- **谁可以改 ACL：** 仅目录 owner（`OWNER@`）或在该路径上拥有 `C`（写 ACL）权限的主体。

### NFSv4 ACL 模型（关键）

在 OneFS/NFSv4 上，**owner 没有隐式最高权限**。有效权限完全来自 **ACE 条目**。`ls -la`、`stat` 显示的 POSIX 模式位是 **由 ACE 合成** 的，可能具有误导性。

POSIX 模式与 NFSv4 ACE 同时生效。务必用 `nfs4_getfacl` 检查，不能单靠 `chmod` 授权。

### 权限字母对照

完整协作权限（owner 级，不含改 owner）：`rwaDdxtTnNcCoy`

| 字母 | 目录上含义 | 文件上含义 |
|------|-----------|-----------|
| r | 列出目录内容 | 读取文件数据 |
| w | 创建文件 | 写入文件数据 |
| a | 创建子目录 | 追加数据 |
| d | — | 删除该文件 |
| D | 删除子目录/子文件 | — |
| x | 进入目录 | 执行文件 |
| t/T | 读/写属性 | 读/写属性 |
| n/N | 读/写扩展属性 | 读/写扩展属性 |
| c/C | 读/写 ACL | 读/写 ACL |
| y | 同步 I/O | 同步 I/O |
| o | 改 owner | 改 owner |

| 权限串 | 效果 |
|--------|------|
| `rwaDdxtTnNcCy` | 完整文件操作；**不能**调用 `nfs4_setfacl` 或授权他人 |
| `rwaDdxtTnNcCoy` | 同上，且含 `C`：可改 ACL 并分发权限 |

协作者默认不给 `C`，除非对方需要管理权限。

### ACE 语法

```
A::<principal>:<permissions>        # 直接 ACE，作用于当前对象
A:fd:<principal>:<permissions>     # 继承到新文件和子目录（也在当前目录生效）
A:fdi:<principal>:<permissions>    # 仅继承（i）；不在当前目录本身授予访问
```

**`fdi` 标志：** `f` = 文件继承，`d` = 目录继承，`i` = 仅继承。`A:fdi:OWNER@` 确保新建子对象上的 **CREATOR OWNER** 语义，而不会在父目录重复叠加直接 owner ACE。

---

## 第二部分：070 失败模式

### 现象

授予协作者权限后，**新建**的目录和文件显示模式 **`070`**（目录 `d---rwx---`，文件 `---rwx---`）。owner（`<OWNER>`）在自己的目录树里 `touch`、写入或 `mkdir` 时出现 `PermissionError`。

### 根因

`<OWNER_WORK_DIR>`（或某个祖先写入根）上存在 **可继承的协作者 ACE**（`A:fd:<COLLABORATOR>@...`），但 **没有可继承的 OWNER@ ACE**（`A:fdi:OWNER@...` 或等价项）。

OneFS 在存在命名用户继承 ACE 且缺少对应可继承 `OWNER@` ACE 时，会将 POSIX owner 位合成为 `---`。协作者可能有完整访问权，而 owner 看起来被锁在外面。

**umask 无法修复此问题。** 模式来自 ACL 继承，而非 umask。

### 验证实验

在 `<OWNER>` 身份下，于已复现失败的环境（有协作者继承 ACE、无 OWNER@ 继承）中执行：

**计划：** 确认挂载、身份，以及新对象是否为 070。

**执行：**

```bash
mount | grep '<WORK_ROOT>'
id
nfs4_getfacl <OWNER_WORK_DIR> | grep -E 'OWNER@|<COLLABORATOR>@'

mkdir -p <OWNER_WORK_DIR>/_070_test/sub
stat -c '%A %a %n' <OWNER_WORK_DIR>/_070_test <OWNER_WORK_DIR>/_070_test/sub
touch <OWNER_WORK_DIR>/_070_test/sub/file.txt 2>&1 || true
stat -c '%A %a %n' <OWNER_WORK_DIR>/_070_test/sub/file.txt 2>/dev/null || true
```

**验证：** 新建目录/文件应为 `070`，owner 写入失败。新目录的 `nfs4_getfacl` 显示协作者继承 ACE，但 **没有** 继承的 `OWNER@`。

**清理：** 修复后 `rm -rf <OWNER_WORK_DIR>/_070_test`；若 owner 无法删除，通过父目录 ACL 处理。

---

## 第三部分：完整授权流程（一次跑通）

向 `<COLLABORATOR>` 授予 `<OWNER_WORK_DIR>` 访问权时，**按顺序完成全部步骤**。

### 步骤 0 — 预检

**计划：** 确认在 DKUCC 上、`<WORK_ROOT>` 已挂载、当前为 `<OWNER>`（或有 `C`）、目标路径正确。执行下方命令前，将 `<WORK_ROOT>`、`<OWNER>`、`<COLLABORATOR>` 等占位符替换为实际路径与 NetID。

**执行：**

```bash
mount | grep '<WORK_ROOT>'
id
test -d <OWNER_WORK_DIR> && echo "target exists"

TS=$(date +%Y%m%d_%H%M%S)
nfs4_getfacl <OWNER_WORK_DIR> > /tmp/acl-backup-${TS}.txt
echo "Backup: /tmp/acl-backup-${TS}.txt"

find <OWNER_WORK_DIR> -user <OWNER> -perm 070 2>/dev/null | wc -l
nfs4_getfacl <OWNER_WORK_DIR>
```

**验证：** 挂载正常；`id` 为 `<OWNER>`；备份文件非空；已了解当前 ACE。

---

### 步骤 1 — 授予协作者 ACL

**计划：** 为 `<COLLABORATOR>` 添加直接 ACE 与继承 ACE。根据是否需要访问已有文件，选择方式 1（仅顶层）或方式 2（递归）。

| 方式 | 命令 | 适用场景 |
|------|------|----------|
| **方式 1：** 仅目录 | 对目标 `nfs4_setfacl -a`（不加 `-R`） | 新文件靠 `A:fd:` 继承；已有文件不变 |
| **方式 2：** 递归 | 对目标 `nfs4_setfacl -R -a` | 协作者必须访问/修改 **已有** 内容 |

**执行（方式 1 — 新协作常用）：**

```bash
nfs4_setfacl -a 'A::<COLLABORATOR>@oit.duke.edu:rwaDdxtTnNcCy' <OWNER_WORK_DIR>
nfs4_setfacl -a 'A:fd:<COLLABORATOR>@oit.duke.edu:rwaDdxtTnNcCy' <OWNER_WORK_DIR>
```

**执行（方式 2 — 树中已有内容需协作者操作时追加）：**

```bash
nfs4_setfacl -R -a 'A::<COLLABORATOR>@oit.duke.edu:rwaDdxtTnNcCy' <OWNER_WORK_DIR>
nfs4_setfacl -R -a 'A:fd:<COLLABORATOR>@oit.duke.edu:rwaDdxtTnNcCy' <OWNER_WORK_DIR>
```

**警告：** `-R` 会遍历整个子树，在大型目录树上 **很慢**。执行前请确认 `<OWNER_WORK_DIR>` 为目标路径。

同一目录同时跑方式 1 和 2 会产生重复 ACE（功能无影响，输出较乱）。

**验证：**

```bash
nfs4_getfacl <OWNER_WORK_DIR> | grep '<COLLABORATOR>@'
```

---

### 步骤 2 — 方案 1：添加可继承 OWNER@ ACE（关键）

**必须在步骤 1 之后立即执行。** 跳过会导致第二部分描述的 070 失败。

**计划：** 在授权根及每个 **中间活跃写入根**（已有树中实际创建新文件/目录的位置）添加 `A:fdi:OWNER@`。

**执行 — 顶层：**

```bash
nfs4_setfacl -a 'A:fdi:OWNER@:rwaDxtTnNcCy' <OWNER_WORK_DIR>
```

**执行 — 中间写入根**（已有树；按实际布局调整路径）：

```bash
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

**执行 — 批量传播到 owner 拥有的所有目录**（大型已有树）：

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

**验证：**

```bash
nfs4_getfacl <OWNER_WORK_DIR> | grep 'A:fdi:OWNER@'
nfs4_getfacl <OWNER_WORK_DIR>/<ACTIVE_WRITE_ROOT_1> 2>/dev/null | grep -E 'A:fdi:OWNER@|A:fd:OWNER@' || true
```

---

### 步骤 3 — 修复已有 070 对象（chmod 补救）

**计划：** 修复已以 070 创建的对象的 POSIX 模式。ACL 可能已正确；`chmod` 修正合成的模式位以便 owner 使用。

**执行：**

```bash
find <OWNER_WORK_DIR> -user <OWNER> -type d -perm 070 -exec chmod 0775 {} +
find <OWNER_WORK_DIR> -user <OWNER> -type f -perm 070 -exec chmod 0664 {} +
```

**若对 070 目录 chmod 失败：** owner 可能仍可通过 **父目录** 的 NFSv4 ACL 修改权限。尝试：

```bash
nfs4_setfacl -a 'A:fdi:OWNER@:rwaDxtTnNcCy' <stuck-dir的父目录>
chmod 0775 <stuck-dir>
```

**符号链接显示 070 无害 — 可忽略。**

**验证：**

```bash
find <OWNER_WORK_DIR> -user <OWNER> -type d -perm 070 | head
find <OWNER_WORK_DIR> -user <OWNER> -type f -perm 070 | head
```

---

### 步骤 4 — 端到端验证

**计划：** 证明树深处新建对象模式正确且 owner 可写。

**执行：**

```bash
VERIFY=<OWNER_WORK_DIR>/_acl_verify/sub/subsub
mkdir -p "$VERIFY"
stat -c '%A %a %n' <OWNER_WORK_DIR>/_acl_verify <OWNER_WORK_DIR>/_acl_verify/sub "$VERIFY"
touch "$VERIFY/testfile"
stat -c '%A %a %n' "$VERIFY/testfile"
nfs4_getfacl "$VERIFY"
```

**验证：**

- 各级为 **`770`**（或 `775`/`664`），**不是 `070`**。
- `touch` 成功。
- 新目录的 `nfs4_getfacl` 含继承的 **`OWNER@`** 与 **`<COLLABORATOR>@`** ACE。

**清理：**

```bash
rm -rf <OWNER_WORK_DIR>/_acl_verify
```

---

### 步骤 5 — 授权后检查清单

**计划：** 确认无残留 070，并记录变更。

**执行：**

```bash
REMAINING=$(find <OWNER_WORK_DIR> -user <OWNER> -perm 070 2>/dev/null | wc -l)
echo "Remaining 070 entries: $REMAINING"
nfs4_getfacl <OWNER_WORK_DIR>
```

**验证：** `REMAINING` 为 0 或仅符号链接。记录：备份路径、使用的方式 1/2、修补的中间目录、批量日志路径、070 残留数。

**协作者冒烟测试**（以 `<COLLABORATOR>` 身份）：

```bash
cat <OWNER_WORK_DIR>/某个已有文件
echo "test" > <OWNER_WORK_DIR>/collab_test.txt
rm <OWNER_WORK_DIR>/collab_test.txt
mkdir <OWNER_WORK_DIR>/collab_subdir
rmdir <OWNER_WORK_DIR>/collab_subdir
nfs4_getfacl <OWNER_WORK_DIR>
```

---

## 第四部分：常见坑与安全

### 常见坑

1. **`touch` 误报失败** — `touch` 先创建文件（父目录要 `w`）再改时间戳（文件要 `T`）。新文件继承 ACL 常缺 `T`，文件已创建但 exit 1。用 `ls` 确认，脚本里优先 `echo 'content' > file`。
2. **070 锁死（第二部分）** — 仅有协作者继承 ACE、无 `A:fdi:OWNER@` 时 owner 模式为 `---`。步骤 1 后必须立即执行步骤 2。
3. **方式 1 不改旧文件** — 继承 ACE 只影响 **新建** 子对象。已有内容需 `-R`（方式 2）。
4. **重复 ACE** — 方式 1+2 同目录会产生重复条目，功能正常。
5. **无法自我提权** — 无 `C` 时 `nfs4_setfacl` 失败，须 `<OWNER>` 执行。
6. **中间写入根** — 仅在顶层授权可能遗漏 `<ACTIVE_WRITE_ROOT_1>/`、`<ACTIVE_WRITE_ROOT_2>/.nested/` 等实际写入位置。步骤 2 须逐个修补。

### 安全建议

- 共享 **具体子目录**（`<OWNER_WORK_DIR>`），不要共享整个 `<WORK_ROOT>/<OWNER>/`。
- 共享整个 home 会暴露 dotfile、配置，且协作者可删除全部内容。
- `<WORK_ROOT>` **无备份**，超过 **75 天** 的文件可能被清理（Duke 政策）。
- 协作者默认不给 `C`。
- 改 ACL 前务必备份（步骤 0）。
- **方式 2（`-R`）** 在大型目录树上很慢；递归授权前请再次确认目标路径。

---

## 第五部分：协作者已授权但 070 未修复

**现象：** `nfs4_getfacl` 已有 `A:fd:<COLLABORATOR>@...`，但 owner 新建对象仍为 070 或无法写入。

**计划：** 跳过步骤 1，直接执行步骤 2 → 3 → 4 → 5。

**执行：**

1. **步骤 2** — 在授权根、中间写入根添加可继承 `OWNER@`（优先 `A:fdi:OWNER@`，或 `A:fd:OWNER@`；后者同样满足可继承 OWNER@ 要求），必要时批量传播。
2. **步骤 3** — 对已有 070 目录/文件执行 chmod 补救。
3. **步骤 4** — `_acl_verify` 端到端测试。
4. **步骤 5** — 检查清单。

**验证：** 同第三部步骤 4–5 标准。

快速诊断：

```bash
nfs4_getfacl <OWNER_WORK_DIR> | grep -E 'OWNER@|<COLLABORATOR>@'
find <OWNER_WORK_DIR> -user <OWNER> -perm 070 | wc -l
```

若已有协作者 ACE 但继承链上没有任何可继承 `OWNER@`（`A:fdi:OWNER@` 或 `A:fd:OWNER@`），即属此场景。

---

## 第六部分：坏 ACL 状态（增量 SETACL 全部失败）

**现象：** 所有 **增量** `nfs4_setfacl` 操作均返回 `Invalid argument` — `-a`、`-x`、`-m`、`-i` 全部失败。与 POSIX owner 身份 **无关**；`nfs4_setfacl --test` 本地预览可能正常，但实际写入仍失败。第五部分的补救（通过 `-a` 添加 `A:fdi:OWNER@`）无法执行。

**2026 年 6 月 Isilon OneFS 实测验证**（如 Spectralmae `datasets/` 目录树）。

### 诊断特征

处于坏状态的目录 ACL 常同时存在以下多项：

1. **缺少** `A:fdi:OWNER@`
2. **重复的协作者 ACE**（如 3× `A:fd:<COLLABORATOR>@` + 2× `A::<COLLABORATOR>@`）
3. 协作者 ACE 使用 **旧权限串**（如 `rwx` 而非 `rwaDdxtTnNcCoy`）
4. 存在 **Storage Admins 组 ACE：** `A:g:Storage Admins@oit.duke.edu:rxtncy`

### Storage Admins ACE（Duke/Isilon）

- **含义：** Duke 存储管理员组 `Storage Admins@oit.duke.edu` 的 NFSv4 ACE，权限串 `rxtncy`（读、执行、读属性、读 ACL 等），使存储管理员可通过组 membership 管理该目录。
- **坏 ACL 期间：** **包含** Storage Admins 的整表 `-S` 也会 `Invalid argument`；**不含** Storage Admins 的干净模板可以成功。
- **`-S` 修复成功后：** Storage Admins ACE **不会自动保留**（模板中未包含）。
- **owner 无法加回：** `nfs4_setfacl -a` 尝试恢复 Storage Admins 仍返回 `Invalid argument`；须由 **DKUCC/Isilon 管理员** 在 OneFS 侧恢复。
- **对普通协作的影响：** 去掉 Storage Admins 通常 **不影响** owner 与协作者使用；仅影响依赖该组 ACE 的存储管理员访问。

### 修复路径（整表替换）

增量 `-a` 在此场景不可用。先用 `--test -S` 验证，再用 `nfs4_setfacl -S`（stdin ACL 列表）整表替换。

**计划：** 备份 ACL，按已知正常授权根（如 SkillReuse 子树）构建干净模板，用 `--test -S` 验证后执行 `-S`。

**执行 — 先测试再应用：**

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

将 `<COLLABORATOR>` 替换为实际 NetID。若参考树使用不同权限串（如协作者不含 `C`：`rwaDdxtTnNcCy`），相应调整模板。

**验证：**

```bash
nfs4_getfacl <OWNER_WORK_DIR>
# 增量操作应恢复可用
nfs4_setfacl -a 'A:fdi:OWNER@:rwaDxtTnNcCy' <OWNER_WORK_DIR>

# 抽查：新建目录应为 770，非 070
mkdir -p <OWNER_WORK_DIR>/_broken_acl_verify/sub
stat -c '%A %a %n' <OWNER_WORK_DIR>/_broken_acl_verify <OWNER_WORK_DIR>/_broken_acl_verify/sub
rm -rf <OWNER_WORK_DIR>/_broken_acl_verify
```

**修复后注意：**

- **勿用 `-x` 删除 `A:fdi:OWNER@`** — `-x` 会移除继承项，可能再次触发 070（第二部分）。
- 若树中仍有 070 对象，修复后执行第三部步骤 3–5。
