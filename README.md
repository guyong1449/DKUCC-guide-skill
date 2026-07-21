# DKUCC Guide Skills

本仓库只保留可从 `guyong1449/skills` **完整同步、可独立运行** 的 DKUCC 技能。片段式中文摘要 skill 已移除，避免与完整 runbook 重复。

| 技能 | 适用场景 |
|---|---|
| `nfs4-acl` | `/work` NFSv4 ACL 授权、070 修复、OWNER@ 继承 |
| `dkucc-permission-audit` | 只读审计 home/`/work` 自然权限 |
| `dkucc-work-data-recovery` | `/work`/`home` NFS `.snapshot` 恢复、`bash_history` 排查与 IT 证据 |

弱引用（不合并）：

- 保活 / 定期 `touch` → 仍用 `guyong1449/skills` 中的 `dkucc-data-ingest`（本仓库不收录）
- 总手册 → `dkucc-cluster-guide`（本仓库不收录）
- 代理转发 → `dkucc-clash-forwarding`（本仓库不收录）

源材料以 `guyong1449/skills` 当期 `main` 为准；集群策略以 DKUCC 官网及 Duke IT 说明为准。

## 外部交叉引用

| 资源 | 何时使用 |
|---|---|
| [guyong1449/DKUCC-guide-skill](https://github.com/guyong1449/DKUCC-guide-skill) | 本仓库 |
| [guyong1449/skills](https://github.com/guyong1449/skills) | 权威完整 skills 根（含 data-ingest / cluster-guide / clash-forwarding） |
| [guyong1449/cisco-vpn-autoconnect](https://github.com/guyong1449/cisco-vpn-autoconnect) | Windows DKU VPN |
| Duke IT / DKUCC 支持 | LDAP 公钥、主机指纹、分区权限 |
