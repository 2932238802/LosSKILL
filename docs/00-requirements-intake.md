# 00 — 需求受理（G0）

> 维护者：Doc Agent ｜ 最近更新：2026-11-20 ｜ 状态：G1 已确认（2026-11-20）；CR-001 G4 通过

## CR-001 能力索引路由正确性

- **类型**：缺陷 / 技术债
- **问题与价值**：
  - [事实] `capability_index.py:313-317` 在 `top` 为空时仍访问 `top[0][0]`，`query qqqzzz` 抛 `IndexError`（已复现，exit 1）。
  - [事实] `stale():221-225` 只比较 mtime，不比较 `index["roots"]`；换 roots 后仍复用旧索引（已复现：缓存 roots 不变，查询返回空）。
  - [事实] `build_index:182` 把完整 description 拼进 `all_text`，`tokenize:119-141` 不剥离「不用于 / 不适用 / 不涉及」从句，`score:259-274` 无法区分正负信号。实测 `query "书摘 读后感"` 把 `huashu-nuwa` 判为 0.81；`plan "给游戏调数值平衡"` 把 `game-design-tetrad` 排第一，`game-design-mechanics` 完全缺席。
  - **价值**：能力索引是开工第 0 步的路由入口；空查询崩溃会打断流程，误路由会把任务交给错误 Skill。
- **目标用户与场景**：使用 `leverage-protocol` 的 Agent 与用户；在仓库根执行 `query` / `plan` 选择能力。
- **成功指标**：
  - 基线：`query qqqzzz` traceback；`plan "给游戏调数值平衡"` 无 mechanics；换 roots 不重建。
  - 目标：无匹配有明确提示且无 traceback；mechanics 进入 `plan` 前三且高于 tetrad；roots 变化触发重建。
  - 可观察验收场景：在仓库根依次运行 R-001～R-003 的 AC 命令，输出与退出码符合预期。
- **范围**：`skills/leverage-protocol/scripts/capability_index.py` 的 query / tokenize / build_index / score / stale 逻辑，以及必要的命令行验收。
- **非目标**：
  - 不修 F-02 / F-06 / F-08 / F-16（属 CR-002 / CR-003）。
  - 不改 Skill 正文语义、不重写匹配算法、不引入第三方依赖。
  - 不改 `SKILLS.md` 与 `SKILL.md` 的命令路径（属 CR-003）。
- **NFR**：
  - 性能：索引构建与查询不引入额外全量扫描；构建时间相对现状不明显增加。
  - 安全：不联网，不读取新路径，不写入敏感信息。
  - 隐私与数据保留：不适用（只读本地 Skill 元数据）。
  - 兼容性：CLI 参数保持；缓存格式可兼容旧索引，必要时自动重建；退出码变化需 A-001 确认。
  - 可观测性：无匹配与重建给出可读提示，不吞异常。
  - 成本：无新增基础设施或依赖。
- **约束与依赖**：Python 标准库；当前 `HEAD 69f1830`；输入 `docs/fix-report-2026-11-20.md`。
- **风险与未知**：
  - 剥离否定从句可能误删描述中的有效内容；需定义终止边界（A-002）。
  - roots 比较需考虑绝对路径、顺序、符号链接（A-003）。
  - 退出码语义在修复报告正文与 §5 验收之间冲突（A-001）。
- **选项**：
  - A. 做（F-01 + F-10 + F-09；代价约 0.5–1 天；风险中）
  - B. 拆小（先修 F-01，其余另开 CR；代价小，但误路由仍在）
  - C. 先 spike（用 22 个 description 验证剥离规则与排名变化；时间盒 0.5 天；产出规则与对照表）
  - D. 缓办（等待 A-001 / A-002 结论）
  - E. 不做（接受崩溃与误路由）
- **推荐**：A。F-01 是 P0，F-10 已造成实际误路由，二者在同一条评分链上，一起改的验证成本最低；F-09 是独立小修。
- **关联需求 / 任务**：R-001 / R-002 / R-003；T-001 / T-002 / T-003
- **状态**：已完成（G4 通过，2026-11-20；收尾提交待授权）

## CR-002 报告与日志脚本可靠性

- **类型**：缺陷 / 技术债 / 效率
- **问题与价值**：
  - [事实] `finish-report.sh:302-305` 只用 `^## .*报告[[:space:]]*$` 匹配插入点；标题带后缀（如 `## Dev Agent 交付报告 — T-099`）时不回填也不报错；重跑同一报告会重复追加 WORKLOG（已复现：2 条 T-099、报告 0 条回填）。
  - [事实] `worklog.sh:73` 的 `--time` 用 `tr -cd '0-9' | cut -c1-14`，生成 `LOG-20261120100000`，与默认 `LOG-YYYYMMDD-HHMMSS` 不一致。
  - [事实] 8 个脚本的 `usage()` 使用硬编码 `sed -n '2,37p'` 等行号（如 `finish-report.sh:56`、`worklog.sh:41`），头部注释一变就错位。
  - [事实] `finish-report.sh:191-194` 在没有 `python3` 时保持传入路径，可能写出绝对链接。
  - [事实] `scripts/selftest.sh` 不存在；CI 只跑 `validate.sh`，没有脚本回归。
  - **价值**：WORKLOG / AUTH 是 G4 审计与授权追溯的证据链；静默失败和重复会让审计失真。
- **目标用户与场景**：执行 Doc/Dev/Review/Meta 的 Agent；每次交付报告运行 `scripts/finish-report.sh`。
- **成功指标**：
  - 带后缀标题的报告连跑两次 → WORKLOG 1 行、报告 1 条回填。
  - `--time` 统一生成 `LOG-YYYYMMDD-HHMMSS`。
  - 所有脚本 `-h` 输出完整，不依赖固定行号。
  - 无 `python3` 时不写绝对链接（相对路径或明确报错）。
  - `./scripts/selftest.sh` exit 0；故意破坏去重时失败；CI 调用它。
- **范围**：`scripts/finish-report.sh`、`scripts/worklog.sh`、相关 `usage()`、新增 `scripts/selftest.sh`、`.github/workflows/validate.yml`。
- **非目标**：不修 CR-003 的协议矛盾；不修 F-15.3/4/6/7；不改 WORKLOG/AUTH 表结构（除非幂等键必需，需在设计说明）；不引入第三方依赖。
- **NFR**：性能（仍为 O(报告大小)）；安全（不新增外部调用）；隐私（不适用）；兼容（旧 WORKLOG/AUTH 可读，旧报告仍可处理）；可观测（失败必须 WARN 或非零退出）；成本（无新增基础设施）。
- **约束与依赖**：Bash + 标准工具；当前 `HEAD edd0a1b`；selftest 需复制脚本到临时目录做故障注入。
- **风险与未知**：
  - 去重键过宽会误跳过不同动作，过窄会重复。
  - 故障注入不能破坏真实 `scripts/`。
  - 无 `python3` 场景需用 PATH 模拟。
- **选项**：
  - A. 做（F-06 + F-15.1/2/5 + F-16 selftest/CI；约 0.5–1 天）
  - B. 拆小（只修 F-06；其余另开）
  - C. 只做脚本修复，不做 selftest
  - D. 缓办
  - E. 不做
- **推荐**：A。F-06 是 P1 证据链缺陷，selftest 是防止复发的唯一低成本手段；F-15.1/2/5 是同批小修。
- **关联需求 / 任务**：R-004 / R-005 / R-006 / R-007 / R-008；T-004 / T-005 / T-006
- **状态**：G1 已确认（2026-11-20）；G2 进行中

## 后续候选（未受理）

| 编号 | 主题 | 主要项 |
|---|---|---|
| CR-003 | 文档与引用一致性 | F-02、F-08、F-03/04/05/07、F-15.6/7/13 |
| CR-004 | 内容去重与编号 | F-11/12/13/14/17（需先拍板卡片保留方式） |
| CR-005（候选） | 能力索引缓存版本化 | 脚本升级后旧缓存不失效；T-002 报告登记的残留风险（默认缓存已重建缓解，根治待办） |
| CR-006（候选） | 否定从句分号枚举覆盖 | `ai-comment-protection` 用 `；` 枚举否定项，首条分号后的负向词仍命中（T-002 G3 P2） |

## 假设与待确认

| 编号 | 问题 | 证据 | 需要谁回答 | 截止 | 状态 |
|---|---|---|---|---|---|
| A-001 | 无匹配时退出码保持 1 还是改 0？ | 报告 F-01 说保持 1；报告 §5 期望 0；`capability_index.py:323` 现为 1 | 用户 | G1 | 已确认：保持 1，`--allow-empty` 时 0 |
| A-002 | 否定从句剥离到哪里为止？ | `capability_index.py:182`、`:119-141` | 用户 / Dev | G1 | 已确认：从标记切到句末（`。；;` 或换行），只影响分词 |
| A-003 | roots 如何比较？ | `:221-225` 忽略 `index["roots"]` | Dev | G2 DoR | 已确认：resolve 后去重、排序比较 |

## 报告核实时发现的口径修正

- F-02 死链实际 7 处（含 `rust-atomics-and-locks/test-results.md:63`），不是 4 处。
- F-08 命令路径错误实际 10 处（`leverage-protocol/SKILL.md` 6 处 + `SKILLS.md` 4 处），不是 2 处。
- F-11 实际 14 对 = game-design 7 对 + sandra-sales 7 对。
- F-13 实际 7 个 SKILL + 13 个非 SKILL 文件引用 ceNN。
- F-16 的“没有 pre-commit”不成立：`core.hooksPath=.githooks`，hook 已生效；缺的是 `scripts/selftest.sh` 与 CI 步骤。
- 报告 §5 的 `query qqqzzz` 期望 exit 0 与 F-01 正文冲突（见 A-001）。
