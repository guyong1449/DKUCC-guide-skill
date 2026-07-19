---
name: dkucc-ssh-ldap-auth
description: Diagnose DKUCC SSH public-key authentication, especially when ssh-copy-id or ~/.ssh/authorized_keys does not enable key login because LDAP AuthorizedKeysCommand is in use.
---

## DKUCC LDAP 公钥认证

DKUCC 可能经 `AuthorizedKeysCommand` 从 LDAP 查询账号的 `sshPublicKey`，而不是仅读取 home 中的 `authorized_keys`。因此 `ssh-copy-id` 成功不等于免密登录一定成功。

### 收集证据

在本机运行：

```bash
ssh -v dkucc 2>&1 | grep -E 'Offering|Authentication succeeded|Permission denied'
ssh-keygen -lf ~/.ssh/id_ed25519.pub
```

Windows PowerShell 用 `Select-String` 替代 `grep`。在已登录节点上可只读检查：

```bash
grep -E 'AuthorizedKeys|ldap' /etc/ssh/sshd_config
```

### 处理顺序

1. 保留 `~/.ssh`（推荐 755）与 `authorized_keys`（推荐 600）的正常权限。
2. 将 `id_ed25519.pub` 的完整单行和本地指纹发给 Duke IT / DKUCC 支持，请其核验 LDAP `sshPublicKey`。
3. 附上 `ssh -v` 的 `Offering public key` 和拒绝片段。

绝不发送私钥。不要因为 LDAP 未更新而反复换密钥；先让管理员确认已登记的是哪一个公钥。
