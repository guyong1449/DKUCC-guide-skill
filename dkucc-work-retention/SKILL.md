---
name: dkucc-work-retention
description: Maintain and check DKUCC /work data that may be subject to retention. Use for dataset keepalive, cron setup, storage checks, and distinguishing retention from Slurm time limits.
---

## DKUCC `/work` 数据保留

`/work` 通常无备份。关于“约 75 天未访问清理”的说法不是固定承诺；先查 Duke OIT / DKUCC 的当前政策，并为重要数据保留站外副本。

### 手动保活

TB 级目录可能运行数小时，建议在 `tmux` 中执行：

```bash
NETID=$(whoami)
nice find "/work/${NETID}" -type f -exec touch {} +
```

### 部署定期任务

本技能包在 `scripts/touch_work_timestamps.sh` 中附带经过审查的脚本。将 `<SKILL_DIR>` 替换为本技能安装目录；不要在 cron 中拼临时命令：

```bash
mkdir -p ~/bin ~/logs
install -m 700 <SKILL_DIR>/scripts/touch_work_timestamps.sh ~/bin/touch_work_timestamps.sh
~/bin/touch_work_timestamps.sh
tail -n 50 ~/logs/touch_work.log
```

确认手动执行成功后，再通过 `crontab -e` 加入：

```cron
0 3 1,15 * * $HOME/bin/touch_work_timestamps.sh >> $HOME/logs/touch_work.cron.log 2>&1
```

`touch` 只能缓解保留风险，不替代备份，也不能延长 Slurm 的作业时限。
