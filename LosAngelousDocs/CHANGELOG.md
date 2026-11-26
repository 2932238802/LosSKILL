# CHANGELOG

> 面向使用者的变更记录。格式：`## [未发布]` + 新增 / 变更 / 修复 / 移除。

## [未发布]

### 新增

- `scripts/selftest.sh` 与 CI `Run script selftest` 步骤（CR-002）
- `LosAngelousDocs/` 四角色工作流文档、`PROJECT_BRAIN.md`、`review-index.md`（CR-001 / CR-002）
- `scripts/workflow-status.sh`：只读诊断当前门禁、下一步与必跑检查（CR-007）
- `dev-workflow/references/07-speed.md`：并行派发、门禁合流、预热、模型分层（CR-007）
- `finish-report.sh --backfill`：提交后回填 AUTH 的真实 commit（CR-007）
- `check-docs --gate g2.5|g3.5`：G2.5/G3.5 的 WORKLOG 与豁免检查（CR-007）

### 修复

- 能力索引：空查询崩溃、否定边界误匹配、缓存忽略 roots（CR-001）
- `finish-report`：带后缀标题回填静默失败、WORKLOG 重复（CR-002）
- 无 `python3` 时报告链接可能为绝对路径（CR-002）
- `worklog.sh` 收到绝对报告路径时不再拼成错误相对链接（CR-007）
- `check-docs.sh` 容忍 `STATUS.md` 中加粗的 `**G1 已确认**：是` / `**G3 已接受**：` 字段（CR-007）
- `workflow-status.sh` 按当前 CR 选范围信封；`current_cr` 对「无」不再回退候选 CR；`check-docs --gate g2.5|g3.5` 空值明确报错；`find_latest_report` 按 mtime 取最新 `-rN` 报告（CR-008）

### 变更

- 各脚本 `-h` 改为注释块提取，不再依赖固定行号（CR-002）
- `worklog --time` 统一为 `LOG-YYYYMMDD-HHMMSS`（CR-002）
- 授权协议收敛为 `A1w`（信封预授权，记 WORKLOG）/`A1c`（Review 批，记台账）/`A2`/`A3`；G2.5/G3.5 与 G3 接受只记 WORKLOG（CR-007）
- 记录根统一为项目根，存量项目可沿用文档根（legacy）；`finish-report` 新增 `--project-root`（CR-007）
- 开发改为单分支：一律在 `main` 提交，不建长期 feature 分支；远端只保留 `main`（AGENTS.md）
- 清零 `validate.sh` 警告：11 个 Skill 补「不用于」触发边界；`red-tie-xhs` 去掉绝对路径并支持 `RED_TIE_FONT_DIR` 自定义字体目录（0 ERROR / 0 WARN）
