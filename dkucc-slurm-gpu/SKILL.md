---
name: dkucc-slurm-gpu
description: Submit and diagnose DKUCC GPU Slurm jobs. Use for partition access, GRES requests, sbatch/srun templates, shared-GPU preemption, SIGKILL, OOM, timeouts, and checkpoint recovery.
---

## DKUCC Slurm GPU 作业

只在登录节点提交和管理作业。先查权限和资源；看到分区不等于可以提交：

```bash
sacctmgr show assoc user=$USER format=Account,Partition,QOS,MaxJobs,MaxTRES -P
sinfo -o "%P %a %l %G %N" | head -30
```

部分账号的 `sacctmgr` 输出可能不完整；若它与 `sbatch` 结果冲突，以实际提交结果和管理员确认信息为准。

### 提交前置条件

Slurm 在脚本执行前打开日志文件，因此先创建目录：

```bash
mkdir -p /work/<NETID>/slurm/logs
```

最小资源请求应包含 `--partition`、`--gres`、`--mem`、`--time`、`--chdir`、`--output` 和 `--error`。以 `sinfo` 显示的 GPU 类型和数量为准，不要照搬旧的 GRES 名称。

### 共享 GPU 抢占

`l20-gpu`、`h20-gpu` 和 `common-gpu` 的抢占策略可能导致无依赖批量长作业互相抢占，表现为 DDP 进程集体 `SIGKILL` / exit code `-9`。先核验当前设置：

```bash
for p in l20-gpu h20-gpu common-gpu; do
  scontrol show partition "$p" | tr ' ' '\n' | grep -E '^PartitionName=|^PreemptMode=|^PriorityJobFactor=|^MaxTime='
done
scontrol show config | grep -iE 'Preempt|PriorityCalc|PriorityWeight'
```

长训用 `afterok` 串行提交，或等待上一个完成：

```bash
jid1=$(sbatch --partition=l20-gpu job1.sh | awk '{print $NF}')
sbatch --partition=l20-gpu --dependency=afterok:${jid1} job2.sh
```

依赖链会阻止同一批 downstream 作业在前一作业完成前成为互相抢占的候选项，但无法消除其他用户或更高优先级作业的抢占。因此仍必须周期性保存 checkpoint。

### 失败分类

```bash
sacct -j <JOBID> --format=JobID,State,ExitCode,Elapsed,Timelimit,MaxRSS,DerivedExitCode
```

- `-9`、低 `MaxRSS`、后续 pending job 很快启动：优先检查抢占，使用 checkpoint 续跑。
- `TIMEOUT`：将训练拆段，并以依赖链续跑。
- `MaxRSS` 接近 `--mem`：CPU 内存不足，提高内存或减少 worker / 保存峰值。
- CUDA OOM：缩小 batch、做梯度累积或申请更多 GPU。
