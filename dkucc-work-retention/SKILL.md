---
name: dkucc-work-retention
description: Maintain and check DKUCC /work data that may be subject to retention. Use for dataset keepalive, cron setup, storage checks, and distinguishing retention from Slurm time limits.
---

## DKUCC `/work` 数据保留

`/work` 通常无备份。关于“约 75 天未访问清理”的说法不是固定承诺；先查 Duke OIT / DKUCC 的当前政策，并为重要数据保留站外副本。

### 一次性保活

原版的命令如下。大目录会运行较久，应在登录节点执行：

```bash
find /work/<NETID> -type f -print0 | xargs -0 touch
```

### cron 与训练内保活

先运行 `crontab -e`，再按自己的路径加入原版的每 30 天任务：

```bash
crontab -e
```

```cron
0 2 */30 * * find /work/<NETID> -type f -print0 2>/dev/null | xargs -0 -r touch >> /work/<NETID>/slurm/touch.log 2>&1
```

长训可在脚本中启动 30 天一次的后台 touch，训练结束后 `kill $TOUCH_PID`。检查最旧文件时使用 `find /work/<NETID> -type f -printf '%T@\n' | sort -n | head -1`；若接近你所知的保留窗口，立即 touch 并检查 cron。

`touch` 只能缓解保留风险，不替代备份，也不能延长 Slurm 的作业时限。
