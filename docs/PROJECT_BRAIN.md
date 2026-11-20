# PROJECT_BRAIN — LosSKILL

> 维护者：Doc Agent ｜ 最近更新：2026-11-20 ｜ 状态：草稿（G1 待确认）

## 1. 项目定位

个人开发环境备份 + AI Skill 收藏库。`skills/` 下的内容首先是给 AI 读的触发器与操作指令，不是给人看的教程。

## 2. 架构地图

| 模块 | 职责 | 边界（不负责） |
|---|---|---|
| `skills/` | Skill 正文、触发词、能力卡、角色提示词 | 不承载运行时代码 |
| `scripts/` | 自检、脚手架、同步、项目接入、报告/日志脚本 | 不替代各 Skill 的领域逻辑 |
| `configs/` | Claude / VS Code 等本机配置备份 | 不保存密钥 |
| `docs/` | 需求、设计、任务、报告、状态 | 不是 Skill 索引（索引在 `SKILLS.md`） |
| `SKILLS.md` | Skill 索引与触发边界 | 不是自动生成物，需手工登记 |

## 3. 不变量与契约

- 目录名 = frontmatter `name`，kebab-case。
- description 必须包含「不用于 / 不适用 / 不涉及」边界。
- 新增/改名 Skill 必须在 `SKILLS.md` 登记。
- 角色提示词只有一份正文：`skills/dev-workflow/references/01–04-*.md`。
- 保护所有 `LosAngelous:` / `LOS:` 手动注释：不改、不删、不移动。
- 不提交本地产物与密钥；身份信息用环境变量。
- 交付前 `./scripts/validate.sh` 必须 0 ERROR。
- 不主动 push，用户明确要求才推送。

## 4. 验证命令

```bash
./scripts/validate.sh
python3 skills/leverage-protocol/scripts/capability_index.py query "任务"
python3 skills/leverage-protocol/scripts/capability_index.py plan "任务"
bash -n scripts/*.sh setup.sh
git status --short
```

## 5. 热点与已知问题

- 能力索引（`capability_index.py`）：T-001 已修空查询并提交（`27d08f3`）；T-002 已实现索引侧否定从句剥离（待提交，行号漂移为 `:119` / `:195`），G3 有条件通过；T-003（roots 缓存）待做。
- 已知限制（T-002 G3）：P1 缓存不感知脚本版本（CR-005）；P2 分号枚举残留负向词（候选 CR-006）；P3 `not\s+for` 无词边界。
- 否定词缺陷已造成实际误路由：`plan "给游戏调数值平衡"` 返回 tetrad 第一，`game-design-mechanics` 缺席。
- 修复输入：`docs/fix-report-2026-11-20.md`（commit `69f1830`）。
- pre-commit 已生效：`core.hooksPath=.githooks`；缺的是 `scripts/selftest.sh` 与 CI 自测步骤。
- 残留风险：索引缓存不感知脚本版本（`stale()` 只比 Skill 文件 mtime）；升级后需 `--refresh` 或删除缓存。T-002 报告已登记，候选 CR-005。

## 6. 决策索引

- D-001：修复工作拆为 CR-001～CR-004，首轮 CR-001（路由正确性）。
- D-002：本轮流程文档根目录 = `docs/`；`WORKLOG.md` / `AUTHORIZATIONS.md` / `STATUS.md` 也放 `docs/`，与 `bootstrap-project.sh` 的项目根约定暂不一致，留待 CR-003 统一。

## 7. 最近变更

- 2026-11-20：提交修复报告 `69f1830`；建立 CR-001 文档与任务；T-001 完成并提交 `27d08f3`（G3 通过，AUTH-20261120-001）；T-002 完成，G3 有条件通过（AUTH-20261120-002，待提交）。
