---
name: dkucc-nfs4-acl-collaboration
description: Safely share DKUCC /work directories using NFSv4 ACLs. Use for collaborator grants, 070 owner lockouts, inherited ACE checks, or nfs4_setfacl Invalid argument failures.
---

## DKUCC NFSv4 ACL 协作

`/work` 使用 NFSv4 ACL。仅目录 owner 或拥有 `C`（write ACL）权限者可以修改 ACL；不能用 POSIX `getfacl` / `setfacl` 代替。先选择一个具体项目子目录，而不是默认共享整个 `/work/<OWNER>`，然后检查和备份：

```bash
mount | grep /work
id
nfs4_getfacl <OWNER_WORK_DIR>
TS=$(date +%Y%m%d_%H%M%S)
nfs4_getfacl <OWNER_WORK_DIR> > /tmp/acl-backup-${TS}.txt
```

### 标准授权流程

协作者 principal 格式是 `<COLLABORATOR>@oit.duke.edu`。先对共享根添加直接和继承 ACE；此权限串不含 `C`，协作者不能转授权限：

```bash
nfs4_setfacl -a 'A::<COLLABORATOR>@oit.duke.edu:rwaDdxtTnNcCy' <OWNER_WORK_DIR>
nfs4_setfacl -a 'A:fd:<COLLABORATOR>@oit.duke.edu:rwaDdxtTnNcCy' <OWNER_WORK_DIR>
nfs4_setfacl -a 'A:fdi:OWNER@:rwaDxtTnNcCy' <OWNER_WORK_DIR>
nfs4_getfacl <OWNER_WORK_DIR> | grep -E 'OWNER@|<COLLABORATOR>@'
```

不要遗漏最后一条 `A:fdi:OWNER@`：缺少它时，owner 新建对象可能变为 `070` 且无法写入；`umask` 无法修复这一问题。只有协作者必须访问既有内容时，才审慎使用 `nfs4_setfacl -R`；对大树执行前再次确认目标路径。

### 验证与异常处理

```bash
nfs4_getfacl <OWNER_WORK_DIR> | grep -E 'OWNER@|<COLLABORATOR>@'
mkdir -p <OWNER_WORK_DIR>/_070_probe
stat -c '%a %n' <OWNER_WORK_DIR>/_070_probe
rm -rf <OWNER_WORK_DIR>/_070_probe
```

若出现 070，先补 `A:fdi:OWNER@`，再在确认范围内修复既有对象，并重新创建 probe 验证：

```bash
find <OWNER_WORK_DIR> -user <OWNER> -type d -perm 070 -exec chmod 0775 {} +
find <OWNER_WORK_DIR> -user <OWNER> -type f -perm 070 -exec chmod 0664 {} +
```

若所有增量 `nfs4_setfacl` 操作都报 `Invalid argument`，停止修改并保留备份 ACL。该异常需要按经验证的完整 ACL 表替换流程处理；在没有该 runbook 或管理员确认时，不要自行执行 `-S` 全表替换。
