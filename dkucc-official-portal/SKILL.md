---
name: dkucc-official-portal
description: Navigate and verify DKUCC guidance against the official website or its saved HTML snapshot. Use when locating official pages for login, storage, Slurm, GPU, MATLAB, software, Open OnDemand, Jupyter, training, or when reconciling a DKUCC guide with current official wording.
---

## DKUCC 官网导航与核验

优先使用 [DKUCC 官网](https://dkucc.dukekunshan.edu.cn/) 描述集群用途、登录、存储、软件和 OnDemand。2026-07-20 的未登录访问会跳转 Duke SSO，这是访问实测；页面正文只明确标注 GPU 与存储收费页需要登录。无法在线读取时，使用仓库中的 `../dkucc.dukekunshan.edu.cn/` HTML 快照，并注明快照日期。

### 页面路由

| 问题 | 官网页面 | 本地目录 |
|---|---|---|
| 集群概况、最新地址、资源摘要 | 首页 | `00-home/` |
| SSH、VPN、登录节点与 VS Code 边界 | `dcc-login/` | `dcc-login/` |
| Home、`/work`、保留期限、文件传输 | `dcc-files/` | `dcc-files/` |
| Slurm 作业 | `dcc-slurm/` | `dcc-slurm/` |
| 交互式 GPU 资源 | `dcc-usage/` | `dcc-usage/` |
| GPU 与存储收费 | `gpu_storage_charge_model` | `gpu_storage_charge_model/` |
| MATLAB | `matlab/` | `matlab/` |
| 环境模块与用户软件 | `software-modules/`、`software-user/` | 同名目录 |
| Web 入口、文件、作业、Shell、交互应用 | `openondemand/`、`openondemand-gettingstarted/` | 同名目录 |
| Jupyter Lab | `openondemand-jupyter/` | `openondemand-jupyter/` |
| 培训 | `help-training/` | `help-training/` |

### 核验规则

1. 从目标目录读取 `.html` 正文，忽略配套 `_files` 目录中的 CSS、JavaScript、字体和图片。
2. 记录页面标题、正文事实和原始 URL。不要根据导航标题推测缺失页面内容。
3. 若目录没有 HTML，明确写“本地缓存缺页”，再查看在线官网；两者都不可用时停止扩写。
4. 官网快照与 Slurm 实时输出冲突时，区分静态说明与动态状态。主机名、分区、GRES、时限和账号权限以 `sinfo`、`scontrol`、`sacctmgr` 及管理员确认为准。
5. 不把产品机制推导为 DKUCC 政策。例如 Remote-SSH 会部署 VS Code Server，但官网缓存只允许 VS Code 做排错和脚本管理，并要求计算使用 OnDemand CodeServer；不能据此声称官网禁止下载 VS Code。

### 已核对的官网事实（快照日期：2026-07-20）

- DKUCC 由 DKU IT 管理，是使用 AlmaLinux 与 Slurm 的通用高性能、高吞吐计算集群。
- 首页快照写明 10 Gbps 互连、400 TB Dell EMC Isilon，以及所有集群数据均不备份。
- `Working with files` 将 Home 文件系统列为 1 TB，将 `/work` 列为 50 TB 共享高速卷；两者均无备份，`/work` 中超过 75 天的文件会自动清理。该页禁止存储敏感数据。
- 首页快照列出教学资源为 24 张 RTX 4090 24 GB 与 8 张 L20 48 GB，学习与研究资源为 16 张 A40 48 GB 与 8 张 L20 48 GB。资源规划不等于用户权限。
- 校外 SSH 需要 VPN。登录节点只适合轻量文件传输、编辑、提交和监控作业。
- OnDemand 通过 Slurm 运行交互式会话，可管理文件、作业、Shell 和交互式应用。

每次引用容量、保留期、收费或资源数量时都附快照日期，并提醒用户在线复核。
