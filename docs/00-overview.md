# 00 — 项目总览

> 维护者：Doc Agent ｜ 最近更新：2026-11-20 ｜ 状态：草稿（G1 待确认）

## 一句话定位

给 AI 用的个人 Skill 与开发环境备份库：把可复用的工作方法、角色协议和本机配置沉淀成可触发、可验证的文件。

## 目标与非目标

**目标**

- 提供可被 AI 直接加载的 Skill（触发词、边界、操作步骤）。
- 提供可重复执行的验证与同步脚本。
- 记录本机配置与开发流程，便于迁移和恢复。

**非目标**

- 不是通用教程库，不追求给人从头阅读的完整性。
- 不承载业务项目代码。
- 不保存密钥、真实邮箱、私钥或本地产物。

## 运行方式

| 命令 | 用途 | 已验证 |
|---|---|---|
| `./scripts/validate.sh` | Skill 自检 | 是，当前 `All skills OK.` |
| `python3 skills/leverage-protocol/scripts/capability_index.py query "…"` | 查 Skill | 是 |
| `python3 skills/leverage-protocol/scripts/capability_index.py plan "…"` | 组合能力计划 | 是 |
| `./scripts/new-skill.sh my-skill --desc "…"` | 新建 Skill | 未在本次执行 |
| `./scripts/sync-skills.sh --dry-run` | 预览同步 | 未在本次执行 |
| `./scripts/finish-report.sh --report <报告>` | 写 WORKLOG/AUTH | 是（沙箱复现过缺陷） |

## 目录地图

| 目录 | 一句话 |
|---|---|
| `skills/` | Skill 正文、能力卡、角色提示词 |
| `scripts/` | 校验、脚手架、同步、报告脚本 |
| `configs/` | Claude / VS Code 配置备份 |
| `docs/` | 本轮新增的需求、设计、任务、状态与报告 |
| `.githooks/` | 通过 `core.hooksPath` 生效的 pre-commit |

## 当前状态

- `HEAD`：`69f1830`（修复报告已入库）。
- `validate.sh`：0 ERROR。
- 流程文件：本轮新建 `PROJECT_BRAIN.md`、`STATUS.md`、`00-requirements-intake.md`、`01-requirements.md`、`02-architecture.md`、`03-design.md`、`04-tasks.md`、`05-decisions.md`、`WORKLOG.md`。
- 已知限制：`PROJECT_BRAIN.md` 与 `STATUS.md` 为最小版本，后续 CR 逐步补全。

## 术语

| 术语 | 定义 |
|---|---|
| Skill | 带 frontmatter、可被 AI 触发的目录，入口为 `SKILL.md` |
| 能力卡 | 路由 Skill 下 `references/capabilities/` 的细分文档 |
| CR / R / AC / T | 需求卡 / 需求 / 验收标准 / 任务 |
| G0–G4 | 需求受理 / 需求确认 / 开发 / 评审 / 总审 |
| 信封 | 用户在 G1 一次批准的范围与授权边界 |
