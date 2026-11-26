# PROJECT_BRAIN — LosSKILL

> 维护者：Doc Agent（G2.5 增量合并：Steward） ｜ 最近更新：2026-11-26 ｜ 状态：已确认（CR-001 G4 通过；CR-002 G4 通过 2026-11-20；CR-007 G1 已确认 2026-11-26，G3 有条件通过（F-1 已修，F-2→CR-008），G4 返工（P1: check-docs current_cr））

## 1. 项目定位

个人开发环境备份 + AI Skill 收藏库。`skills/` 下的内容首先是给 AI 读的触发器与操作指令，不是给人看的教程。

## 2. 架构地图

| 模块 | 职责 | 边界（不负责） |
|---|---|---|
| `skills/` | Skill 正文、触发词、能力卡、角色提示词 | 不承载运行时代码 |
| `scripts/` | 自检、脚手架、同步、项目接入、报告/日志脚本 | 不替代各 Skill 的领域逻辑 |
| `configs/` | Claude / VS Code 等本机配置备份 | 不保存密钥 |
| `LosAngelousDocs/` | 需求、设计、任务、报告、状态 | 不是 Skill 索引（索引在 `SKILLS.md`） |
| `SKILLS.md` | Skill 索引与触发边界 | 不是自动生成物，需手工登记 |

## 3. 不变量与契约

- 目录名 = frontmatter `name`，kebab-case。
- description 必须包含「不用于 / 不适用 / 不涉及」边界。
- 新增/改名 Skill 必须在 `SKILLS.md` 登记。
- 角色提示词只有一份正文：`skills/dev-workflow/references/01–04-*.md`。
- 保护所有 `LosAngelous:` / `LOS:` 手动注释：不改、不删、不移动。
- 不提交本地产物与密钥；身份信息用环境变量。
- 交付前 `./scripts/validate.sh` 必须 0 ERROR；现状 0 ERROR / 0 WARN（36 个 Skill，2026-11-26 复核）。
- 文档根目录 = `LosAngelousDocs/`（不用 `docs/`）；`DOCS_CONTRACT.md` 是唯一契约，未登记路径不得创建；`check-docs --gate g1` 现状 0 ERROR / 3 legacy WARN（`AUTHORIZATIONS.md` / `PROJECT_BRAIN.md` / `WORKLOG.md` 在文档根）。
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

- 能力索引（`capability_index.py`）：T-001 已修空查询并提交（`27d08f3`）；T-002 已实现索引侧否定从句剥离并提交（`f149b96`，行号 `:119` / `:195`），G3 有条件通过；T-003 已实现 roots 缓存感知并提交（`37774e2`），G3 通过。
- G4 总审通过（`LosAngelousDocs/reports/meta-2026-11-20-CR-001.md`，2026-11-20）：三任务 AC 独立复现全通过；无 P0/P1。
- 已知限制（T-002 G3）：P1 缓存不感知脚本版本（默认缓存已重建缓解，根治 CR-005）；P2 分号枚举残留负向词（候选 CR-006）；P3 `not\s+for` 无词边界。
- 历史：否定词缺陷曾导致 `plan "给游戏调数值平衡"` 返回 tetrad 第一、mechanics 缺席；T-002 已修复。
- 报告工具链：CR-002 已修复回填锚点、全键幂等、`--time` 格式、usage 硬编码、无 python3 相对链接，并新增 `scripts/selftest.sh` + CI；G4 通过（`meta-2026-11-20-CR-002.md`）。
  - 已知限制（CR-002 G4 P3）：`worklog.sh` mv 失败路径会残留临时文件；`--no-worklog` 仍强制计算相对路径；`--force` 会为同一幂等键追加 AUTH；`selftest.sh` 的 `make_bin` 缺 `head`、仅 finish-report 做插行、SKIP 不计失败；`LosAngelousDocs/CHANGELOG.md` 已建立（CR-002 收尾；2026-11-26 复核存在，已含 CR-001 / CR-002 / CR-007 条目）。
- 修复输入：`LosAngelousDocs/fix-report-2026-11-20.md`（commit `69f1830`）。
- pre-commit 已生效：`core.hooksPath=.githooks`；`scripts/selftest.sh` 与 CI 自测已补齐（CR-002）。
- 残留风险：索引缓存不感知脚本版本（`stale()` 只比 Skill 文件 mtime）；升级后需 `build` 重建缓存。候选 CR-005。
- CR-007（工作流基线 + 告警清零，retro）：G1 已确认 2026-11-26；T-007 DONE（新增 `DOCS_CONTRACT.md` + `check-docs.sh` 容忍加粗 G1/G3 字段），T-008 G3 有条件通过（F-1 已修，F-2→CR-008）；G4 返工：`check-docs.sh` `current_cr()` 反引用 `\3` 越界致 `--gate g2.5` 误判 FAIL（P1，Review 漏报）。

## 6. 决策索引

- D-001：修复工作拆为 CR-001～CR-004，首轮 CR-001（路由正确性）。
- D-002：本轮流程文档根目录 = `LosAngelousDocs/`；`WORKLOG.md` / `AUTHORIZATIONS.md` / `STATUS.md` 也放 `LosAngelousDocs/`，与 `bootstrap-project.sh` 的项目根约定暂不一致，**已在 CR-007 统一**（记录根默认项目根，存量文档根按 legacy 兼容）。
- D-006～D-008（CR-002）：范围 = F-06 + F-15.1/2/5 + selftest/CI；幂等键 = 报告路径 + role/gate/cr/task/action；无 python3 时用 `realpath --relative-to` 回退。

## 7. 最近变更

- 2026-11-20：提交修复报告 `69f1830`；建立 CR-001 文档与任务；T-001 完成并提交 `27d08f3`（G3 通过，AUTH-20261120-001）；T-002 完成并提交 `f149b96`（G3 有条件通过，AUTH-20261120-002，默认缓存已重建）；T-003 完成并提交 `37774e2`（G3 通过，AUTH-20261120-003）。 G4 总审通过：F-01/F-09/F-10 主例达成，残留分号枚举（CR-006）与缓存版本化（CR-005）转后续，非阻断。
- 2026-11-20：CR-001 收尾提交 `edd0a1b`；启动 CR-002（报告/日志脚本可靠性 + selftest），G1 待确认。
- 2026-11-20：CR-002 T-004 完成并提交 `4f341e3`（G3 有条件通过，AUTH-20261120-004）；T-005 完成并提交 `beac653`（G3 通过，AUTH-20261120-005）；T-006 完成并提交 `4573bbd`（G3 通过，AUTH-20261120-006）。G4 总审通过（`LosAngelousDocs/reports/meta-2026-11-20-CR-002.md`）：18 条 AC 与 UAT 独立复现全通过，无 P0/P1；AUTH-006 的 CI 变更按 A2 由 Meta 追认；文档收尾（F-1～F-4）与脚本健壮性（F-5～F-10）转后续。
- 2026-11-26：CR-007（retro）G1 确认并补 `DOCS_CONTRACT.md`。`5c09e61` 收敛授权协议（`A1w`/`A1c`/`A2`/`A3`，G2.5/G3.5 与 G3 接受记 WORKLOG），新增 `07-speed.md` 提速协议、`workflow-status.sh`、`finish-report --backfill`、`check-docs --gate g2.5|g3.5`（34 文件，+1126/−217）；`d6bce31` 为 11 个 Skill 补「不用于」边界、`red-tie-xhs` 去绝对路径并支持 `RED_TIE_FONT_DIR`（15 文件，+44/−24），`validate.sh` 达 0 ERROR / 0 WARN；工作区另有 `check-docs.sh` 加粗正则兼容修复（未提交，POLICY-CR-007）。追溯：R-009/R-010/R-011 → T-007/T-008 → `reports/doc-2026-11-26-CR-007.md` / `reports/dev-2026-11-26-T-008.md`。
