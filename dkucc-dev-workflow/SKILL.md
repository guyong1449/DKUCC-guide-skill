---
name: dkucc-dev-workflow
description: Set up day-to-day DKUCC development workflows with Conda, Git, and remote editors. Use for environment placement, repository layout, Cursor/VS Code Remote SSH, or proxy-related remote install failures.
---

## DKUCC 开发工作流

Conda 环境可放在 `/work/<NETID>/envs/`：

```bash
conda create -p /work/<NETID>/envs/myenv python=3.11 -y
source "$(conda info --base)/etc/profile.d/conda.sh"
conda activate /work/<NETID>/envs/myenv
export PYTHONNOUSERSITE=1
```

Git 仓库建议放在 `/work/<NETID>/repos/`。在登录节点执行 `git pull` / `git push`，避免大量计算作业同时推送；数据集和模型权重不要直接放进普通 Git 历史。

Remote SSH 前先验证普通 `ssh dkucc`。如果 Cursor 或 VS Code 的远端服务器下载需要代理、出现 localhost connection refused，或发生远端安装失败，转用 `dkucc-clash-forwarding`；不要把代理桥接配置混入 SSH 基础配置。

### VS Code Remote-SSH 与 CodeServer

官网允许 VS Code 连接登录节点，用于排查代码和管理脚本，但禁止借此在登录节点或通过 `common`、`scavenger` 分区连接的计算节点上执行高强度计算。需要运行代码时，进入 OnDemand 并使用 CodeServer，让 Slurm 分配交互式资源。

桌面版 VS Code 客户端安装在本机。Remote-SSH 可能在远端安装或更新 VS Code Server，但官网缓存没有写“禁止下载 VS Code”，也没有明确禁止该服务器组件。不要把 Remote-SSH 的下载机制推导为集群政策；组件安装受阻时联系 DKUCC 支持，不要手动安装桌面版 VS Code 或修改系统配置。

### skills 同步

若使用统一 skills 仓库，原版流程为：

```bash
cd ~/.cc-switch/skills
git remote -v
git pull
```

首次克隆时将 `<SKILLS_REPO_URL>` 替换为实际远端，然后运行仓库中的 Linux deploy 脚本。不要把私钥或 token 写进 skill 正文。
