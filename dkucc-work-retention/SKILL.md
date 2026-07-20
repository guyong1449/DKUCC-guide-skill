---
name: dkucc-work-retention
description: Maintain and check DKUCC /work data that may be subject to retention. Use for dataset keepalive, cron setup, storage checks, and distinguishing retention from Slurm time limits.
---

## DKUCC `/work` 数据保留

2026-07-20 的官网 `Working with files` 快照明确写明：`/work` 无备份，超过 75 天的文件会自动清理。页面没有说明清理依据是访问时间还是修改时间，也没有承诺恢复窗口，因此先查当期政策，并为重要数据保留站外副本。

### 一次性保活

原版使用以下命令。大目录会产生较重 I/O，不要直接在登录节点扫描整个 `/work/<NETID>`；将路径限制为需要保留的目录，并通过 Slurm CPU allocation 执行：

```bash
srun --partition=common --time=04:00:00 --mem=2G --cpus-per-task=1 \
  bash -lc 'find /work/<NETID>/data /work/<NETID>/outputs -type f -print0 | xargs -0 -r touch'
```

### cron 自动提交

不要使用原版的 `0 2 */30 * *`；cron 日期字段中的 `*/30` 不是固定每 30 天。创建 `/work/<NETID>/slurm/touch-work.sh`：

```bash
#!/bin/bash
#SBATCH --job-name=touch-work
#SBATCH --partition=common
#SBATCH --time=04:00:00
#SBATCH --mem=2G
#SBATCH --cpus-per-task=1
#SBATCH --output=/work/<NETID>/slurm/logs/touch-work-%j.out
#SBATCH --error=/work/<NETID>/slurm/logs/touch-work-%j.err

set -euo pipefail
find /work/<NETID>/data /work/<NETID>/outputs -type f -print0 2>/dev/null | xargs -0 -r touch
```

先创建日志目录，再验证作业脚本：

```bash
mkdir -p /work/<NETID>/slurm/logs
sbatch /work/<NETID>/slurm/touch-work.sh
```

确认作业成功后再运行 `crontab -e`，加入下列规则：

```bash
crontab -e
```

```cron
0 2 1 * * /usr/bin/sbatch /work/<NETID>/slurm/touch-work.sh >> /work/<NETID>/slurm/touch-submit.log 2>&1
```

该表达式表示每月 1 日 02:00，由 cron 提交作业，实际扫描在 Slurm CPU 节点运行。检查最旧文件也应限制路径，并放到 CPU allocation 中：

```bash
srun --partition=common --time=01:00:00 --mem=2G --cpus-per-task=1 bash -lc '
  find /work/<NETID>/data /work/<NETID>/outputs -type f -printf "%T@\n" 2>/dev/null | sort -n | head -1
'
```

若最旧时间接近保留窗口，先确认备份和当期政策，再运行已验证的保活作业。

`touch` 是原版 skill 的保活办法，但官网没有承诺它一定能阻止清理。它不替代备份，也不能延长 Slurm 的作业时限。
