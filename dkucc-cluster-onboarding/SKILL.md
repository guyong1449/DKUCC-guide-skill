---
name: dkucc-cluster-onboarding
description: Onboard a DKUCC user after SSH access works. Use for first-login checks, home versus /work storage layout, and safe project-directory planning.
---

## DKUCC 首次登录与存储

登录后先核验身份、挂载和可见队列：

```bash
hostname
whoami
pwd
df -h /dkucc/home/$USER /work/$USER
sinfo -s
```

`sinfo` 可见分区不等于账号有权限；提交前另用 `sacctmgr show assoc` 检查。

DKUCC 分为登录节点、Slurm 调度层和 CPU/GPU 计算节点。数据不会随作业自动保留；计算节点本地临时盘上的唯一 checkpoint 会随作业结束而丢失。

### 路径规划

| 位置 | 用途 |
|---|---|
| `/dkucc/home/<NETID>` | `.ssh`、shell 配置、小脚本 |
| `/work/<NETID>` | 仓库、数据、Conda 环境、checkpoint、Slurm 日志 |

建议创建 `repos/`、`data/`、`envs/`、`outputs/` 和 `slurm/`。home 和 work 都是网络文件系统；不要把唯一数据副本放在 `/work`，计算节点本地临时盘也不应保存唯一 checkpoint。

`/work` 使用 NFSv4 ACL。需要协作授权时转用 `dkucc-nfs4-acl-collaboration`，不要先尝试 POSIX `setfacl`。
