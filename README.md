# DKUCC Guide Skills

按日常操作拆分的 DKUCC 技能包。每个技能只处理一个明确问题；涉及集群状态、权限或保留政策时，先运行其中的只读核验命令。

| 技能 | 适用场景 |
|---|---|
| `dkucc-ssh-bootstrap` | Windows/macOS 首次安装和配置 SSH |
| `dkucc-cluster-onboarding` | 首次登录、目录规划、存储自检 |
| `dkucc-ssh-ldap-auth` | 公钥、LDAP 和免密登录失败 |
| `dkucc-node-etiquette` | 判断登录节点与计算节点职责 |
| `dkucc-slurm-gpu` | GPU 作业、抢占、SIGKILL 和 checkpoint |
| `dkucc-work-retention` | `/work` 保留风险、保活和检查 |
| `dkucc-nfs4-acl-collaboration` | NFSv4 ACL 协作、070 和坏 ACL |
| `dkucc-dev-workflow` | Conda、Git、Cursor/VS Code 远程开发 |

源材料：`guyong1449/skills@c1eb114`；集群策略以 Duke IT / DKUCC 管理员的当期说明为准。

## 外部交叉引用

| 资源 | 何时使用 | 不可用时 |
|---|---|---|
| `dkucc-clash-forwarding` | Cursor / VS Code 远端下载需要本地代理 | 不要把代理参数混入普通 SSH 配置；先保持基础 SSH 可用 |
| Duke IT / DKUCC 支持 | LDAP 公钥登记、主机指纹或分区权限核验 | 不发送私钥，不猜测目录权限或账号配置 |
| Duke OIT / DKUCC 政策 | `/work` 保留期限与例外 | 视为无备份风险，保留站外副本 |
