---
name: dkucc-data-ingest
description: >-
  DKUCC /work keepalive via periodic touch and space checks.
  Use for cron touch and monthly df/du inspection. For snapshot restore after
  data loss, use dkucc-data-recovery (weak reference; do not merge).
  Does not include Spectralmae git sync.
custom: true
managed_by_ccswitch: true
---

# DKUCC data ingest & /work keepalive

## Related skills (weak reference — do not merge)

- **dkucc-data-recovery** — NFS `.snapshot` + `rsync` restore after purge/delete; IT evidence. This skill only does **prevention** (touch / space check).

## Touch 保活（每月两次）

核心命令：

```bash
NETID=$(whoami)
nice find "/work/${NETID}" -type f -exec touch {} +
```

**部署**：`~/bin/touch_work_timestamps.sh`（`WORK_ROOT=/work/$(whoami)`，日志 `~/logs/touch_work.log`）。

**Cron（登录节点 rw335 + 节点 zs175，每月 1 日、15 日 03:00）**：

```cron
0 3 1,15 * * $HOME/bin/touch_work_timestamps.sh >> $HOME/logs/touch_work.cron.log 2>&1
```

全目录 touch 在 TB 级数据上可能运行数小时；用 `tmux` 或 `nohup` 手动跑时同理。

## 明确不做

- **不要**部署 `git_sync_spectralmae.sh` 或 Spectralmae / cc-switch 的 auto-git-sync cron。
- **不要**在此 skill 中维护 AndroidWorld 相关流程。

## 脚本

| 脚本 | 用途 |
|------|------|
| `scripts/touch_work_timestamps.sh` | 与集群 `~/bin` 部署版一致 |
| `scripts/monthly_check.sh` | `df`/`du` + 检查 touch 日志（手动或按需 cron） |

## SSH

- rw335（登录节点）：`ssh -o BatchMode=yes dkucc-login-01`
- zs175：`ssh -o BatchMode=yes dkucc-zs175`
