# IT / OIT 工单模板（数据丢失）

## Subject

```text
/work storage unexpected data loss — request NFS audit logs
```

## Body

```text
Subject: /work 存储数据意外删除 — 请求 NFS 审计日志

用户: <NETID> (UID <uid>)
主机: <hostname>
路径: /work/<NETID>/<REL>/
挂载: oit-nas-dku13 / dkucc-work（以 df 为准）

问题: 约 <SIZE> 研究数据在 <WINDOW> 被清空或消失。
证据: 快照对比（删前完整 / 删后空或不存在）、目录 mtime、bash_history 排查结果。
用户是否已从快照自行恢复: <是/否；快照日期>

请求:
1. 查询该时段 NFS 文件删除/重命名审计日志及操作来源
2. 确认是否触发自动清理或配额/retention 策略
3. 说明如何避免再次发生

附件: print-it-evidence.sh 终端输出截图
```

将 `<NETID>`、`<REL>`、`<SIZE>`、`<WINDOW>` 换成实际值。Home 丢失时把路径改为 `/dkucc/home/<NETID>/…`，挂载名改为 `dkucc-home`。
