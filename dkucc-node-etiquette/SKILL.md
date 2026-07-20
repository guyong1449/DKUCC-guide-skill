---
name: dkucc-node-etiquette
description: Decide whether a DKUCC task belongs on the login node or a Slurm-allocated compute node. Use before running training, heavy I/O, GPU work, or Slurm commands.
---

## 登录节点与计算节点分工

登录节点可用于编辑、Git、轻量测试，以及 `sbatch`、`squeue`、`scancel`、`sacct`。不要在登录节点跑训练、长期 CPU 密集操作、大型压缩或 GPU 服务。

官网允许通过 VS Code 连接登录节点做代码排错和脚本管理，但不允许借此执行高强度计算。需要 VS Code 风格的交互计算环境时，进入 OnDemand 并使用 CodeServer，让 Slurm 分配资源。

GPU 和长训练必须由 Slurm 分配计算节点。快速判断当前位置：

```bash
echo "SLURM_JOB_ID=${SLURM_JOB_ID:-<login-node>}"
hostname
nvidia-smi 2>/dev/null || echo "没有 GPU：可能在登录节点"
```

`nfs4_setfacl` 是例外：若 `/work` 已挂载且你是 owner 或有 `C` 权限，可在计算节点修 ACL；但新的作业仍应回登录节点提交。长时间交互工作使用 `tmux`，避免 SSH 断开丢失 shell。
