# 工作日志 — {{PROJECT_NAME}}

> 每个 Agent 完成一次工作后追加一行；只追加，不删改，最新在最上面。
> 详细证据在报告里；本文件只做跨角色、跨 CR 的索引。
> 维护：各角色写自己的行；Steward 在 G4 审计完整性。

| ID | 时间 | 角色 | 门禁 | CR / T | 做了什么 | 报告 | Commit | AUTH | 状态 |
|---|---|---|---|---|---|---|---|---|---|
<!-- worklog:rows -->

## 使用规则

- 优先用 `finish-report.sh`：填好报告头部 `report-meta` 后运行，自动追加并回填 `LOG-ID`。
- 手工补录时才直接用脚本：
  ```bash
  {{LOSSKILL_PATH}}/scripts/worklog.sh --file WORKLOG.md \
    --role dev --gate G2 --cr CR-004 --task T-012 \
    --action "实现登录限流与 3 个回归测试" \
    --report LosAngelousDocs/reports/dev-2026-11-20-T-012.md \
    --commit a1b2c3d --auth AUTH-20261120-001 --status 完成
  ```
- `ID` 由脚本生成（`LOG-YYYYMMDD-HHMMSS`），不要手写。
- 一条记录对应一次可复述的工作，不写“已完成本次开发”。
- **必须留行的门禁**：A1w 每个任务（`G2`）、`G2.5`、`G3.5`（或 STATUS 写豁免）、G3 接受（`role=steward|user`，`status=接受`）。A1c/A2/A3 另写 `AUTHORIZATIONS.md`，在 `AUTH` 列引用。
- 报告链接写相对路径；commit 写短 hash；没有授权动作时 AUTH 写 `-`。
- 更正时不要改旧行：追加一条“更正”，在 `做了什么` 里引用原 `LOG-ID`。
