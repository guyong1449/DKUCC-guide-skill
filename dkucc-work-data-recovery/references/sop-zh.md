# DKUCC `/work`（及 home）数据恢复 — 中文 SOP

适用于 `/work/<NETID>/` 与 `/dkucc/home/<NETID>/`（NFS / Isilon）。

权威 agent 流程见同目录上级 `SKILL.md`。本文件供人类阅读与工单附件。

## 「无备份」与快照

`/work` 与 home **没有**面向用户的正式长期备份。挂载卷通常有短周期 `.snapshot/`。快照仍在则可 `rsync` 自救；滚掉后只能站外副本或 IT 工单（不保证）。

## 步骤摘要

1. 确认 live 路径：`ls` / `du` / `stat`
2. `ls …/.snapshot/`
3. 对比删前/删后 `du`，选定删前完整快照
4. `rsync -a`（不要主用 `cp -a`）
5. `find | wc -l` + `touch`
6. 排查 `~/.bash_history`（是否有针对该路径的 `rm`；排除 `.pth`/`checkpoint`/`ckpt` 噪声）
7. 无快照则收集证据开工单

一句话：丢失 → `.snapshot` → 删前快照 → `rsync` → 校验 → `touch` →（可选）历史排查 / 工单。

## 脚本

```bash
SKILL=~/.cc-switch/skills/dkucc-work-data-recovery
bash $SKILL/scripts/list-snapshots.sh
bash $SKILL/scripts/scan-bash-history.sh --rel <REL>
bash $SKILL/scripts/restore-from-snapshot.sh --snap <SNAP> --rel <REL>
bash $SKILL/scripts/touch-after-restore.sh --rel <REL>
bash $SKILL/scripts/print-it-evidence.sh --rel <REL> --size "..." --window "..."
```

Home：各脚本加 `--root home`。恢复前大树建议 `--dry-run`。

## bash_history 排查（工单证据）

实测可用模式（占位符化）：

```bash
TARGET="/work/$(whoami)/<REL>"
HIST="$HOME/.bash_history"

grep -cE '^[[:space:]]*rm[[:space:]]+' "$HIST" || true
grep -E '^[[:space:]]*rm[[:space:]]+' "$HIST" \
  | grep -viE '\.pth|checkpoint|ckpt' \
  | grep -cF "$TARGET" || true
grep -F "$TARGET" "$HIST" | grep -viE '\.pth|checkpoint|ckpt' | tail -20
```

或：

```bash
bash ~/.cc-switch/skills/dkucc-work-data-recovery/scripts/scan-bash-history.sh --rel <REL>
```

说明：

- 过滤训练产物删除噪声后，「针对目标路径的 `rm` 计数为 0」可写入工单叙述。
- 匹配的是**字面绝对路径** `TARGET`；相对路径、`~/…`、变量展开形式可能漏报。
- 历史本身不完整，不能单独当结论；`.pth|checkpoint|ckpt` 过滤也可能造成假阴性。

## 案例背景（2026-05）

路径：`/work/<NETID>/datasets/hyperspectral/`（约 31GB）在短窗口内被清空。

排查要点（来自当事人 `bash_history` 模式，已抽象）：

1. `du` / `ls` 对比删前快照 `…dkuccwork_YYYY-MM-DD_00:00` 与删后次日快照
2. 用 `grep` 扫 `~/.bash_history` 中针对该路径的 `rm`（排除 `.pth`/`checkpoint`/`ckpt`）
3. 快照仍在时，用 `rsync -a` 从删前快照拷回 live 树，再 `touch`

详见 `SKILL.md` Part B–F 与 `scripts/`。
