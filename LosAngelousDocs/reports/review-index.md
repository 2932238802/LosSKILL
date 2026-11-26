# 评审记忆索引（review-index）

> 维护者：Steward / Meta ｜ 最近更新：2026-11-26 ｜ 用途：按模块与缺陷类型检索历次评审，避免重复评审与重复缺陷。

## 报告清单

| 日期 | CR / T | 角色 | 门禁 | 结论 | 报告 |
|---|---|---|---|---|---|
| 2026-11-20 | CR-001 / DOC-001 | doc | G1 | 完成 | [doc-2026-11-20-CR-001.md](doc-2026-11-20-CR-001.md) |
| 2026-11-20 | CR-001 / T-001 | dev | G2 | 完成 | [dev-2026-11-20-T-001.md](dev-2026-11-20-T-001.md) |
| 2026-11-20 | CR-001 / T-001 | review | G3 | 通过（AUTH-20261120-001） | [review-2026-11-20-T-001.md](review-2026-11-20-T-001.md) |
| 2026-11-20 | CR-001 / T-002 | dev | G2 | 完成 | [dev-2026-11-20-T-002.md](dev-2026-11-20-T-002.md) |
| 2026-11-20 | CR-001 / T-002 | review | G3 | 有条件通过（AUTH-20261120-002） | [review-2026-11-20-T-002.md](review-2026-11-20-T-002.md) |
| 2026-11-20 | CR-001 / T-003 | dev | G2 | 完成 | [dev-2026-11-20-T-003.md](dev-2026-11-20-T-003.md) |
| 2026-11-20 | CR-001 / T-003 | review | G3 | 通过（AUTH-20261120-003） | [review-2026-11-20-T-003.md](review-2026-11-20-T-003.md) |
| 2026-11-20 | CR-001 | meta | G4 | 通过（0 阻断） | [meta-2026-11-20-CR-001.md](meta-2026-11-20-CR-001.md) |
| 2026-11-20 | CR-002 / T-004 | review | G3 | 不通过（P1×2：失败静默、去重键缺字段） | [review-2026-11-20-T-004.md](review-2026-11-20-T-004.md) |
| 2026-11-20 | CR-002 / T-004 | review | G3 | 有条件通过（AUTH-20261120-004；r2 复审） | [review-2026-11-20-T-004-r2.md](review-2026-11-20-T-004-r2.md) |
| 2026-11-20 | CR-002 / T-005 | review | G3 | 有条件通过（AUTH-20261120-005；首轮 P2 遗留） | [review-2026-11-20-T-005.md](review-2026-11-20-T-005.md) |
| 2026-11-20 | CR-002 / T-005 | review | G3 | 通过（AUTH-20261120-005；r2 复审） | [review-2026-11-20-T-005-r2.md](review-2026-11-20-T-005-r2.md) |
| 2026-11-20 | CR-002 / T-006 | review | G3 | 通过（AUTH-20261120-006） | [review-2026-11-20-T-006.md](review-2026-11-20-T-006.md) |
| 2026-11-20 | CR-002 | meta | G4 | 通过（0 阻断；AUTH-006 追认 A2） | [meta-2026-11-20-CR-002.md](meta-2026-11-20-CR-002.md) |
| 2026-11-26 | CR-007 / T-008 | review | G3 | 有条件通过（0 P0 / 0 P1；P2×2：追溯漏 AC-009-4、workflow-status 信封取错 policy；A1c 已批） | [review-2026-11-26-T-008.md](review-2026-11-26-T-008.md) |
| 2026-11-26 | CR-007 / T-008 | review | G3 | 通过（r2 复评 G4 P1 修复：current_cr `\3`→`\2` + selftest 回归；g2.5/g1/g3 0 ERROR；无 P0/P1；沿用 AUTH-20261126-001） | [review-2026-11-26-T-008-r2.md](review-2026-11-26-T-008-r2.md) |
| 2026-11-26 | CR-008 / T-009 | review | G3 | 有条件通过（0 P0 / 0 P1；P2×1：legacy 未标注 CR 信封块无法按 CR 选中、回退并标注；P3×5；A1c 已批，条件=提交排除 skills/vesta.md） | [review-2026-11-26-T-009.md](review-2026-11-26-T-009.md) |

## 模块热点

| 模块 / 文件 | 高发函数 | 已发现缺陷类型 | 后续 |
|---|---|---|---|
| `skills/leverage-protocol/scripts/capability_index.py` | `cmd_query`（空候选）/ `strip_negated`（否定从句）/ `stale`+`normalize_roots`（缓存） | 空输入崩溃、否定边界被当正向信号（分号枚举残留）、缓存不感知脚本版本与相对 roots | CR-005 缓存版本化；CR-006 分号枚举；selftest 固化（CR-002） |
| `scripts/finish-report.sh` / `scripts/worklog.sh` | 回填锚点 / 幂等匹配 / stderr 捕获 | R-1/R-2 已修复（失败可见、全键去重）；首轮曾现失败静默与去重键过窄 | 有条件通过 AUTH-20261120-004；P2 `--force` 文案与 P3 留 T-005/T-006；selftest 固化 |
| `scripts/selftest.sh` | 用例断言 / 受限 PATH 夹具 `make_bin` / SKIP 语义 | 受限 PATH 白名单缺 `head`（无假绿）；SKIP 不失败；头部注释覆盖范围夸大 | P3 非阻断；后续补 `head` 与 CI 下 SKIP 计失败 |
| `scripts/check-docs.sh` | `current_cr` / `g1_confirmed` / G3 结论 / `find_latest_report` | `current_cr` 替换串曾写 `\3`（正则仅 2 组）→ GNU sed 越界、stderr 被吞 → 回退取 intake 最大 CR，g2.5/g3.5 误判（CR-007 G4 P1，已修 `\2`）；G1/G3 状态字段曾不识别 `**` 加粗（CR-007 修复）；g3 门禁按文件名取最新 review，不按 CR 过滤；旧报告格式会压住当前 CR | `\2` 已回归固化（selftest 28b）；下次先查 `current_cr` 与 g3 取报告范围 |
| `scripts/workflow-status.sh` | `field` / 信封 `policy` 选择 | `field` 已兼容 `**` 加粗；但信封取 `policy:` 用 `head -1`，多 policy 时永远显示第一条（POLICY-CR-001），误报 max_commits/expires（CR-007 G3 P2，转后续小修） | 下次脚本评审优先查信封选择逻辑 |
| `scripts/workflow-status.sh` / `scripts/check-docs.sh`（CR-008） | `envelope_for_cr` / `current_cr` / `find_latest_report` | 信封 `head -1` 误报（CR-007 P2）、空 CR 回落候选、字典序取旧报告——均已修并加 selftest；遗留：未标注 CR 的 legacy 信封块无法按 CR 选中（CR-008 P2，回退有「回退」标注）、无 GNU `find -printf` 时回退字典序仍存旧序（P3，R-014 NFR 接受）、g3.5 有豁免行时短路为空 CR 不报错（P3） | 新信封标题必须带 `（CR-xxx）`；补 g3.5 空 CR / `none/-` / 未标注块回退用例 |

## 使用约定

- 新评审完成并 G3 接受后，追加一行到「报告清单」；不改历史行。
- 同一模块再次评审时，先查本索引的「已发现缺陷类型」，回归相关用例。
