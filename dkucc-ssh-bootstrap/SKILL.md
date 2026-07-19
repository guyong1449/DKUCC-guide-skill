---
name: dkucc-ssh-bootstrap
description: Set up first-time SSH access to DKUCC from Windows or macOS. Use when a user needs OpenSSH installation, an SSH config entry, key generation, or safe first connection to dkucc-login-01.
---

## DKUCC SSH 初始化

用于本机尚不能 SSH 连接 DKUCC 的场景。目标主机是 `dkucc-login-01.rc.duke.edu`；校外访问的 VPN 要求以 Duke IT 当前政策为准。

### Windows

先在 PowerShell 运行 `ssh -V`。若未安装，在 Windows 11 进入“设置 → 系统 → 可选功能 → 查看功能”，在 Windows 10 进入“设置 → 应用 → 可选功能 → 添加功能”，安装 OpenSSH Client。也可在管理员 PowerShell 中运行：

```powershell
Add-WindowsCapability -Online -Name OpenSSH.Client~~~~0.0.1.0
```

创建 `%USERPROFILE%\.ssh\config`，写入：

```sshconfig
Host dkucc
    HostName dkucc-login-01.rc.duke.edu
    User <NETID>
    IdentityFile ~/.ssh/id_ed25519
    ServerAliveInterval 60
    ServerAliveCountMax 3
```

### macOS

macOS 自带 OpenSSH。运行：

```bash
mkdir -p ~/.ssh && chmod 700 ~/.ssh
nano ~/.ssh/config
chmod 600 ~/.ssh/config
```

配置内容与 Windows 相同。

### 创建密钥与首次连接

```bash
ssh-keygen -t ed25519 -C "<NETID>@duke.edu"
```

私钥 `id_ed25519` 只能保留在本机；可登记的是 `id_ed25519.pub`。首次登录需要账号已开通密码认证，或由 Duke IT / DKUCC 将 `id_ed25519.pub` 的完整单行登记至 LDAP `sshPublicKey`。登记后运行 `ssh dkucc`。若仍失败，转用 `dkucc-ssh-ldap-auth` 收集详细日志；绝不发送私钥。

首次连接前，通过 DKUCC / Duke IT 的可信渠道取得 SSH 主机密钥 SHA256 指纹，只有终端显示的指纹一致时才接受。主机名不能验证主机密钥。已保存指纹变化时停止连接，联系管理员确认。
