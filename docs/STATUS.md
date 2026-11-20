# STATUS

> 维护者：Doc Agent ｜ 最近更新：2026-11-20 ｜ 状态：CR-002 T-005 G3 通过，待提交

## 当前

- **当前 CR**：CR-002 报告与日志脚本可靠性
- **当前门禁**：G3 通过（T-005，`AUTH-20261120-005`）→ 待提交 → T-006
- **进行中任务**：T-005 提交确认（用户）
- **阻塞**：无
- **下一步**：用户确认提交信息 → commit → 派发 T-006
- **范围信封**：POLICY-CR-002（已扩展 `setup.sh`；2026-11-20 批准，2026-11-27 到期，最多 3 次提交）

## 已完成

- **CR-001**：G4 通过（0 阻断），收尾提交 `edd0a1b`；CR-005（缓存版本化）、CR-006（分号枚举）转后续。
- T-001 `27d08f3`、T-002 `f149b96`、T-003 `37774e2`；AUTH-20261120-001/002/003。

## CR-002 任务状态

| 任务 | 状态 | 阻塞原因 |
|---|---|---|
| T-004 finish-report 回填与幂等 | DONE（G3 有条件通过，4f341e3） | P2/P3 转 T-005/T-006 |
| T-005 worklog / usage 小修 | DONE（G3 通过） | P3 AUTH scope 交 G4 |
| T-006 selftest 与 CI | TODO | 等 T-004/T-005 |

## 文档

- 需求卡：`docs/00-requirements-intake.md`（CR-001 已完成；CR-002 G0 已确认）
- 需求/AC：`docs/01-requirements.md`（R-001～R-008）
- 设计：`docs/03-design.md`（§1～§6）
- 任务/追溯：`docs/04-tasks.md`（T-001～T-006）
- 决策：`docs/05-decisions.md`（D-001～D-008）
- 大脑：`docs/PROJECT_BRAIN.md`

## 报告

- CR-001：Doc/Dev/Review/Meta 报告见 `docs/reports/`，索引 `docs/reports/review-index.md`
- CR-002 Doc G1 报告：`docs/reports/doc-2026-11-20-CR-002.md`（LOG-20261120-145405）
- CR-002 Dev T-004 报告：`docs/reports/dev-2026-11-20-T-004.md`（LOG-20261120-145704，G3 不通过，返工中）
- CR-002 Review T-004 报告：`docs/reports/review-2026-11-20-T-004.md`（LOG-20261120-150444，不通过，无 AUTH）
- CR-002 Dev T-004 r2 报告：`docs/reports/dev-2026-11-20-T-004-r2.md`（LOG-20261120-150702，待复审）
- CR-002 Review T-004 r2 报告：`docs/reports/review-2026-11-20-T-004-r2.md`（LOG-20261120-151315，AUTH-20261120-004，G3 有条件通过）
- CR-002 Dev T-005 报告：`docs/reports/dev-2026-11-20-T-005.md`（LOG-20261120-151754，待 G3）
- CR-002 Review T-005 报告：`docs/reports/review-2026-11-20-T-005.md`（LOG-20261120-152748，AUTH-20261120-005，G3 有条件通过）
- CR-002 Dev T-005 r2 报告：`docs/reports/dev-2026-11-20-T-005-r2.md`（LOG-20261120-153315，待复审）
- CR-002 Review T-005 r2 报告：`docs/reports/review-2026-11-20-T-005-r2.md`（LOG-20261120-154044，AUTH-20261120-005，G3 通过）

## 最近提交

- `4f341e3` fix(scripts): 修复报告回填静默失败与 WORKLOG 幂等键（T-004）
- `edd0a1b` docs(workflow): 收尾 CR-001 G4 总审记录
- `37774e2` fix(leverage-protocol): 缓存感知 roots 变化（T-003）
- `f149b96` fix(leverage-protocol): 剥离否定边界从句，修正技能路由（T-002）
- `27d08f3` fix(leverage-protocol): 空查询安全退出并提示无匹配（T-001）

## 备注

- CR-001 非阻断后续：CR-005 缓存版本化、CR-006 分号枚举；默认缓存已重建。
- CR-002 关键设计：D-006 范围、D-007 幂等键、D-008 无 python3 回退。
- F-16 修正：pre-commit 已生效（`core.hooksPath=.githooks`），缺的是 selftest/CI。
- T-004 偏差待评审：`--force` 不再产生重复 WORKLOG 行；去重键为「报告链接 + action」，未显式比较 role/gate/cr/task。
- T-004 G3 复审：有条件通过（`AUTH-20261120-004`）；R-1/R-2 已修；P2 `--force` 文案 → T-005，P3 dry-run/meta 未闭合 → T-005/T-006。
- T-005 G3 P2：R-006「所有脚本」只覆盖 5/8；4 个脚本已返工补齐，复审通过。信封已扩展 `setup.sh`。
- T-005 P3：AUTH-20261120-005 的 scope 未含返工新增的 4 个脚本（幂等 skip）；G4 需以复审报告为准记录授权链。
