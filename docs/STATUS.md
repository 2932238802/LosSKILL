# STATUS

> 维护者：Doc Agent ｜ 最近更新：2026-11-20 ｜ 状态：T-001 G3 通过，待提交

## 当前

- **当前 CR**：CR-001 能力索引路由正确性
- **当前门禁**：G3 通过（T-001）→ 待提交 → 继续 T-002
- **进行中任务**：T-001 提交确认（用户）
- **阻塞**：无
- **下一步**：用户确认提交信息 → commit → 派发 T-002
- **范围信封**：POLICY-CR-001（`docs/AUTHORIZATIONS.md`，2026-11-20 批准，2026-11-27 到期，最多 3 次提交）

## 任务状态

| 任务 | 状态 | 阻塞原因 |
|---|---|---|
| T-001 查询空结果判空 | DONE（G3 通过） | — |
| T-002 剥离否定边界从句 | TODO | 等 T-001 G3 通过 |
| T-003 缓存感知 roots | TODO | 与 T-002 串行 |

## 文档

- 需求卡：`docs/00-requirements-intake.md`
- 需求/AC：`docs/01-requirements.md`
- 架构：`docs/02-architecture.md`
- 设计：`docs/03-design.md`
- 任务/追溯：`docs/04-tasks.md`
- 决策：`docs/05-decisions.md`
- 大脑：`docs/PROJECT_BRAIN.md`

## 报告

- Doc G1 报告：`docs/reports/doc-2026-11-20-CR-001.md`（LOG-20261120-134111）
- Dev T-001 报告：`docs/reports/dev-2026-11-20-T-001.md`（LOG-20261120-134406）
- Review T-001 报告：`docs/reports/review-2026-11-20-T-001.md`（LOG-20261120-135013，AUTH-20261120-001，G3 通过）

## 最近提交

- `69f1830` docs: 添加 2026-11-20 修复报告

## 备注

- `core.hooksPath=.githooks`，pre-commit 已生效；修复报告 F-16 的「没有 pre-commit」不成立。
- 本轮 `WORKLOG.md` / `AUTHORIZATIONS.md` 放 `docs/`，与 bootstrap 的项目根约定暂不一致，留待 CR-003（F-07）统一。
- 工作区当前只有本轮新增的 `docs/` 文件未提交；按协议在 G3 通过后提交。
- 评审 P3（非阻塞）：Dev 报告对 `03-design.md` 的「待 A-001」描述滞后；文档已更新。
- `docs/reports/review-index.md` 不存在；建议由 Doc 在 CR-002 建立报告索引。
