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

### skills 同步

若使用统一 skills 仓库，原版流程为：

```bash
cd ~/.cc-switch/skills
git remote -v
git pull
```

首次克隆时将 `<SKILLS_REPO_URL>` 替换为实际远端，然后运行仓库中的 Linux deploy 脚本。不要把私钥或 token 写进 skill 正文。
