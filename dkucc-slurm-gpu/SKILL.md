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

`--gres` 指定类型和数量：原版示例为 `gpu:l20:N`、`gpu:h20:N` 与 `gpu:a40:N`。`Requested node configuration not available` 通常表示 GRES 类型或数量超过节点配置。

原版将 `common-gpu` 的例子写作 `gpu:a40:N`，即 A40。原版未出现 `g20-gpu`；若用户提到“g20”，先用 `sinfo` / `scontrol` 核验是否实际指 `h20-gpu`，不要猜测。A40 是 48 GB GDDR6 ECC 的 Ampere GPU；L20 是 48 GB 档 Ada GPU；H20 有 96 GB 型号。卡的产品规格不等于当前分区可用资源，实际选择以前述命令和 `nvidia-smi` 为准。

2026-07-20 的官网首页快照列出教学资源为 RTX 4090 与 L20，学习和研究资源为 A40 与 L20，没有列出 H20；同日登录节点的 Slurm 快照可见 `h20-gpu`。官网资源摘要与实时分区属于不同层次，申请时以 Slurm 输出和账号 association 为准。

checkpoint 是训练可恢复快照，至少应包含模型权重、优化器状态和训练进度。计算节点本地盘可能随作业结束而清空；将数据、训练输出和 checkpoint 分别放在 `/work/<NETID>/data/` 与 `/work/<NETID>/outputs/` 等持久目录，才能在抢占、超时或重启后续训。

交互调试使用 `srun --partition=l20-gpu --gres=gpu:l20:1 --time=01:00:00 --pty bash -l`；长训使用 `sbatch`。双模式脚本可在无 `SLURM_JOB_ID` 时 `sbatch "$0" "$@"`，有该变量时执行计算节点逻辑。原版还支持 `#SBATCH --array=0-9` 与 `--dependency=afterok:<JOBID>` 分段续跑。

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
