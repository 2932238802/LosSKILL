# STATUS

> 维护者：Doc Agent ｜ 最近更新：2026-11-20 ｜ 状态：T-002 G3 有条件通过，待提交决策

## 当前

- **当前 CR**：CR-001 能力索引路由正确性
- **当前门禁**：G3 有条件通过（T-002，`AUTH-20261120-002`）→ 待提交决策 → T-003
- **进行中任务**：T-002 提交决策（用户）
- **阻塞**：无
- **下一步**：用户决定 P2 处置与是否提交 → 刷新默认缓存 → 派发 T-003
- **范围信封**：POLICY-CR-001（`docs/AUTHORIZATIONS.md`，2026-11-20 批准，2026-11-27 到期，最多 3 次提交）

## 任务状态

| 任务 | 状态 | 阻塞原因 |
|---|---|---|
| T-001 查询空结果判空 | DONE（G3 通过，27d08f3） | — |
| T-002 剥离否定边界从句 | DONE（G3 有条件通过） | P1/P2/P3 见备注 |
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
- Dev T-002 报告：`docs/reports/dev-2026-11-20-T-002.md`（LOG-20261120-135629，待 G3）
- Review T-002 报告：`docs/reports/review-2026-11-20-T-002.md`（LOG-20261120-140137，AUTH-20261120-002，G3 有条件通过）

## 最近提交

- `27d08f3` fix(leverage-protocol): 空查询安全退出并提示无匹配（T-001）
- `69f1830` docs: 添加 2026-11-20 修复报告

## 备注

- `core.hooksPath=.githooks`，pre-commit 已生效；修复报告 F-16 的「没有 pre-commit」不成立。
- 本轮 `WORKLOG.md` / `AUTHORIZATIONS.md` 放 `docs/`，与 bootstrap 的项目根约定暂不一致，留待 CR-003（F-07）统一。
- 工作区在 T-001 提交后干净；T-002 的改动将在 G3 通过后提交。
- 评审 P3（非阻塞）：Dev 报告对 `03-design.md` 的「待 A-001」描述滞后；文档已更新。
- `docs/reports/review-index.md` 不存在；建议由 Doc 在 CR-002 建立报告索引。
- 残留风险（T-002 报告）：索引缓存不感知脚本版本，升级后需 `--refresh` 或删除缓存；建议后续 CR-005。
- T-002 G3 条件：
  - P1 缓存版本化 → 转 CR-005；合并后需刷新默认缓存。
  - P2 `ai-comment-protection` 用 `；` 枚举否定项，首条分号后的负向词残留（实测「纯写作」「问答」「非代码文本」误判）→ 候选 CR-006。
  - P3 `not\s+for` 无词边界；「换行」终止符因 `clean_scalar` 合并多行而不可达（当前无 Skill 触发）。
