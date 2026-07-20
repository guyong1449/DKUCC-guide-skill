---
name: dkucc-nfs4-acl-collaboration
description: Explain and triage DKUCC /work NFSv4 ACLs. Use for ACE inspection, 070 owner lockouts, GPU-job permission checks, and routing to the full nfs4-acl grant runbook.
---

## DKUCC NFSv4 ACL 概览与排错

`/work` 使用 NFSv4 ACL。仅目录 owner 或拥有 `C`（write ACL）权限者可以修改 ACL；不能用 POSIX `getfacl` / `setfacl` 代替。先选择一个具体项目子目录，而不是默认共享整个 `/work/<OWNER>`，然后检查和备份：

```bash
mount | grep /work
id
nfs4_getfacl <OWNER_WORK_DIR>
TS=$(date +%Y%m%d_%H%M%S)
nfs4_getfacl <OWNER_WORK_DIR> > /tmp/acl-backup-${TS}.txt
```

### 原版的边界

协作者 principal 格式是 `<COLLABORATOR>@oit.duke.edu`。有效权限来自 ACE，owner 没有隐式全权；`ls -la` 显示的模式位可能误导。常见 ACE 语法：

```bash
A::<principal>:<permissions>      # 直接 ACE
A:fd:<principal>:<permissions>    # 继承到新文件和子目录
A:fdi:<principal>:<permissions>   # 仅继承
```

完整授权、递归 grant 与坏 ACL 的全表替换不在原版 cluster guide 中，应转用完整 `nfs4-acl` runbook；不要在本概览的基础上猜测 `nfs4_setfacl` 参数。

### 验证与异常处理

```bash
nfs4_getfacl <OWNER_WORK_DIR> | grep -E 'OWNER@|<COLLABORATOR>@'
mkdir -p <OWNER_WORK_DIR>/_070_probe
stat -c '%a %n' <OWNER_WORK_DIR>/_070_probe
rm -rf <OWNER_WORK_DIR>/_070_probe
```

若 mode 是 070 且 owner 写入失败，原版将根因指向缺少 `A:fdi:OWNER@` 的继承链；按完整 `nfs4-acl` runbook 的 fdi OWNER@、chmod 补救、端到端验证顺序处理。所有增量操作报 `Invalid argument` 时，停止修改、保留备份，并按该 runbook 的 Part F 或管理员指引处理。

提交 GPU 作业前确认输出根可写、继承链包含 `A:fdi:OWNER@`。GPU 节点可以在挂载存在且权限允许时应急改 ACL，但新的 `sbatch` 仍只能在登录节点执行。
