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

下列容量与保留信息来自 2026-07-20 的官网快照：

| 位置 | 用途 |
|---|---|
| `/dkucc/home/<NETID>` | `.ssh`、shell 配置、小脚本；官网存储表列出的 Home 文件系统为 1 TB，不代表单用户配额 |
| `/work/<NETID>` | 仓库、数据、Conda 环境、checkpoint、Slurm 日志；官网存储表列为 50 TB 共享卷 |

建议创建 `repos/`、`data/`、`envs/`、`outputs/` 和 `slurm/`。home 和 work 都是网络文件系统，官网明确写明两者均无备份，且 `/work` 中超过 75 天的文件自动清理。不要把唯一数据副本放在 `/work`，计算节点本地临时盘也不应保存唯一 checkpoint。官网禁止在集群存储敏感数据。

`/work` 使用 NFSv4 ACL。需要协作授权时转用 `dkucc-nfs4-acl-collaboration`，不要先尝试 POSIX `setfacl`。
