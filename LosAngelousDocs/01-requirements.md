# 01 — 需求与验收标准（G1）

> 维护者：Doc Agent ｜ 最近更新：2026-11-20 ｜ 状态：已确认（G1 2026-11-20；CR-001 G4 通过）

## R-001 查询无匹配必须安全退出（P0，v1）

- **来源**：CR-001
- **背景**：`cmd_query` 在 `top` 为空时仍访问 `top[0][0]`，空查询会抛 `IndexError`，打断开工流程。
- **描述**：当查询没有任何候选时，系统应输出可读提示，不抛未捕获异常，并按约定返回退出码。
- **成功指标**：`query qqqzzz` 无 traceback；提示包含「没有匹配」；退出码符合 A-001。
- **验收标准**：
  - AC-001-1：`python3 skills/leverage-protocol/scripts/capability_index.py query qqqzzz` → stdout 含「没有匹配」，不含 `Traceback`，exit 1（A-001 确认后可能调整）。
  - AC-001-2：同一命令加 `--allow-empty` → exit 0，提示不变。
  - AC-001-3：`--json` 模式 → 输出合法 JSON，`confident=false`，exit 1，无 traceback。
- **NFR 影响**：无新增依赖；查询性能不变；不写入敏感信息。
- **影响面**：`cmd_query`；CLI 退出码；文档中关于退出码的说明。
- **不在范围内**：评分算法本身。
- **变更历史**：v1 2026-11-20 初始。

## R-002 否定边界不得作为正向匹配信号（P1，v1）

- **来源**：CR-001
- **背景**：description 完整进入 `all_text`，分词不区分「适用信号」与「不适用于」。反向词会抬高无关 Skill 的分数，造成误路由。
- **描述**：在构建索引与打分前，应剥离 description 中的显式否定从句；正向信号保持可匹配。
- **成功指标**：
  - `query "书摘 读后感"` 不再把 `huashu-nuwa` 判为 confident。
  - `plan "给游戏调数值平衡"` 中 `game-design-mechanics` 进入前三，且分数高于 `game-design-tetrad`。
  - 正向词查询（如「机制平衡」）仍能命中 `game-design-mechanics`。
- **验收标准**：
  - AC-002-1：`query "书摘 读后感" --json` → `huashu-nuwa` 的 `confident=false`，且不作为唯一高分候选。
  - AC-002-2：`plan "给游戏调数值平衡"` → 输出前三包含 `game-design-mechanics`，且其分数高于 `game-design-tetrad`。
  - AC-002-3：`query "机制平衡"` → `game-design-mechanics` 仍排第一（回归）。
  - AC-002-4（夹具边界）：临时 roots 下放两个 Skill，A 的 description 含「不用于：数据库迁移」，B 含「适用信号：数据库迁移」；`query "数据库迁移"` 命中 B，不把 A 判为 confident。
- **NFR 影响**：索引构建增加一次文本预处理；无网络；无新依赖。
- **影响面**：`tokenize` / `build_index` / `score`；所有 Skill 的排名可能变化。
- **不在范围内**：重写匹配模型、引入向量检索。
- **变更历史**：v1 2026-11-20 初始。

## R-003 缓存必须感知 roots 变化（P1，v1）

- **来源**：CR-001
- **背景**：索引缓存保存了 `roots`，但 `stale()` 只比较 mtime；换 roots 后会复用旧索引。
- **描述**：加载缓存时应先比较请求的 roots 与缓存记录的 roots；不一致则重建。
- **成功指标**：换 roots 后缓存自动重建；roots 相同或仅顺序不同时不重复重建。
- **验收标准**：
  - AC-003-1：用 roots A 构建到同一 `--out`，再用 roots B 查询 → 缓存 roots 变为 B，且能返回 B 中独有的 Skill。
  - AC-003-2：roots 不变连续查询两次 → 第二次不重建（`generated_at` 不变）。
  - AC-003-3：roots 集合相同但顺序不同 → 视为相同，不重建。
- **NFR 影响**：无额外全量扫描；仅在 roots 变化时重建。
- **影响面**：`stale` / `load_or_build`；缓存 JSON 格式不变。
- **不在范围内**：缓存位置与文件名变更。
- **变更历史**：v1 2026-11-20 初始。

## 影响分析（CR-001）

| 维度 | 内容 |
|---|---|
| 受影响需求 | R-001、R-002、R-003（新增） |
| 受影响 AC | AC-001-1～3、AC-002-1～4、AC-003-1～3 |
| 受影响模块 / 接口 | `skills/leverage-protocol/scripts/capability_index.py` 的 `cmd_query`、`tokenize`、`build_index`、`score`、`stale`、`load_or_build` |
| 受影响数据 / 配置 | `~/.cache/capability-index/index.json`（格式不变；roots 已存在）；CLI 参数不变 |
| 受影响测试 | 当前无自动化测试；本 CR 用命令行验收，selftest 固化留到 CR-002 |
| 受影响文档 | `LosAngelousDocs/01-requirements.md`、`LosAngelousDocs/03-design.md`、`LosAngelousDocs/04-tasks.md`；`leverage-protocol/SKILL.md` 的退出码说明（如 A-001 改变语义） |
| 兼容与迁移 | 旧缓存可读；roots 不一致时自动重建；无需数据迁移 |
| 风险 | 中：剥离否定从句会改变全局排名，可能影响其他查询；用 AC-002-3 与抽样回归缓解 |

## R-004 finish-report 回填与幂等（P1，v1）

- **来源**：CR-002
- **背景**：标题带后缀时回填静默失败；重跑同一报告会重复追加 WORKLOG。
- **描述**：报告头部的 meta 块结束处或首个 `## ` 标题应作为回填锚点；同一报告重复运行只产生一条 WORKLOG 与一条回填。
- **成功指标**：带后缀标题连跑两次 → 1 行 / 1 条；不同报告不误去重。
- **验收标准**：
  - AC-004-1：标题 `## Dev Agent 交付报告 — T-099`、meta 完整；运行两次 → WORKLOG 中 T-099 行数=1，报告中 `- 工作日志：` 恰好 1 条。
  - AC-004-2：标题 `## 报告`（无后缀）连跑两次 → 1 行 / 1 条（回归）。
  - AC-004-3：有 meta 但无匹配 `## ` 标题 → stderr 含 WARN「未找到日志插入点」，WORKLOG 仍只写 1 行；重跑不重复。
  - AC-004-4：两个不同报告（同 role/gate/cr/task、不同 action）→ WORKLOG 2 行（不误去重）。
- **NFR 影响**：失败必须可见；不改变 WORKLOG 表结构。
- **影响面**：`scripts/finish-report.sh`、`scripts/worklog.sh`。
- **不在范围内**：AUTH 幂等逻辑（已有）。
- **变更历史**：v1 2026-11-20 初始。

## R-005 worklog --time 格式统一（P2，v1）

- **来源**：CR-002
- **背景**：`--time` 路径生成无连字符 ID，与默认格式不一致。
- **描述**：任何时间输入都格式化为 `LOG-YYYYMMDD-HHMMSS`。
- **验收标准**：
  - AC-005-1：`--time "2026-11-20 10:00:00"` → `LOG-20261120-100000`。
  - AC-005-2：默认时间仍是 `LOG-YYYYMMDD-HHMMSS`。
  - AC-005-3：同一秒多条仍生成 `-2` 后缀。
- **NFR 影响**：不改表结构；旧 ID 仍可读。
- **影响面**：`scripts/worklog.sh`。
- **不在范围内**：历史 ID 迁移。
- **变更历史**：v1 2026-11-20 初始。

## R-006 usage() 去硬编码（P2，v1）

- **来源**：CR-002
- **背景**：`usage()` 用固定行号截取注释，头部一改就错位。
- **描述**：`-h` 输出应覆盖全部选项注释，不依赖 `sed -n '2,37p'` 这类固定范围。
- **验收标准**：
  - AC-006-1：`scripts/finish-report.sh -h` 含 `--force`；`scripts/worklog.sh -h` 含 `--time`。
  - AC-006-2：在临时副本头部注释插入一行后，`-h` 仍包含最后一个选项。
  - AC-006-3：`bash -n scripts/*.sh setup.sh` 通过。
- **NFR 影响**：无新增依赖。
- **影响面**：各脚本 `usage()`。
- **不在范围内**：重写帮助文案。
- **变更历史**：v1 2026-11-20 初始。

## R-007 无 python3 时的报告链接（P2，v1）

- **来源**：CR-002
- **背景**：`finish-report.sh:191-194` 在无 `python3` 时可能写出绝对链接。
- **描述**：优先用 `python3` 计算相对路径；否则用 `realpath --relative-to`；两者都无则明确报错。
- **验收标准**：
  - AC-007-1：有 `python3` → WORKLOG 中为相对链接。
  - AC-007-2：无 `python3`、有 `realpath` → 仍为相对链接。
  - AC-007-3：两者都无 → exit 2，stderr 明确，不写绝对链接。
- **NFR 影响**：不改变现有默认路径。
- **影响面**：`scripts/finish-report.sh`。
- **不在范围内**：重写报告路径规则。
- **变更历史**：v1 2026-11-20 初始。

## R-008 脚本自测与 CI（效率，v1）

- **来源**：CR-002
- **背景**：脚本没有回归，F-06 这类缺陷只能靠人工发现。
- **描述**：新增 `scripts/selftest.sh`，覆盖 CR-002 行为并接入 CI。
- **验收标准**：
  - AC-008-1：`./scripts/selftest.sh` exit 0。
  - AC-008-2：复制 `worklog.sh` 到临时目录并破坏去重 → selftest 对应用例非零。
  - AC-008-3：CI `validate.yml` 调用 selftest。
  - AC-008-4：覆盖 worklog 追加/去重、finish-report 回填/幂等、`--time` 格式、无 python3 路径、usage 完整性、`query qqqzzz` 空结果（T-001 回归）。
  - AC-008-5：selftest 不修改仓库文件，使用 mktemp 并清理。
- **NFR 影响**：CI 时长增加可接受；无新依赖。
- **影响面**：`scripts/selftest.sh`、`.github/workflows/validate.yml`。
- **不在范围内**：全量端到端测试。
- **变更历史**：v1 2026-11-20 初始。

## 影响分析（CR-002）

| 维度 | 内容 |
|---|---|
| 受影响需求 | R-004、R-005、R-006、R-007、R-008（新增） |
| 受影响 AC | AC-004-1～4、AC-005-1～3、AC-006-1～3、AC-007-1～3、AC-008-1～5 |
| 受影响模块 / 接口 | `scripts/finish-report.sh`、`scripts/worklog.sh`、各脚本 `usage()`、`scripts/selftest.sh`（新）、CI |
| 受影响数据 / 配置 | WORKLOG / AUTH 表结构不变；旧 ID 可读 |
| 受影响测试 | 新增 selftest；CI 增加一步 |
| 受影响文档 | `LosAngelousDocs/03-design.md`、`LosAngelousDocs/04-tasks.md`、`LosAngelousDocs/05-decisions.md` |
| 兼容与迁移 | 旧报告仍可处理；无需迁移 |
| 风险 | 中：幂等键过宽会误跳过，过窄会重复；用 AC-004-4 与 selftest 覆盖 |

## R-009 文档树契约与 G1 门禁（P0，v1）

- **来源**：CR-007
- **背景**：`LosAngelousDocs/` 没有 `DOCS_CONTRACT.md`，`check-docs --gate g1` 直接失败，后续 CR 无法过门禁。
- **描述**：补契约并登记现有文件；让本仓库能通过 G1 机器检查。
- **验收标准**：
  - AC-009-1：`DOCS_CONTRACT.md` 存在，含核心 10 个文件与 `reports` 目录条目。
  - AC-009-2：`./scripts/check-docs.sh LosAngelousDocs --gate g1` 退出码 0（0 ERROR）。
  - AC-009-3：文档根现有文件全部登记，或属于 legacy 记录文件（`WORKLOG.md` / `AUTHORIZATIONS.md` / `PROJECT_BRAIN.md`）。
  - AC-009-4：`check-docs` 容忍 `STATUS.md` 中加粗的 `**G1 已确认**：是` / `**G3 已接受**：` 写法（G1 实测发现）。
  - AC-009-5：`current_cr()` 优先取 `STATUS.md` 的「当前 CR」；即使 `00-requirements-intake.md` 存在更高编号的候选 CR，`--gate g2.5` 仍按当前 CR 判定（G4 P1 回归）。
- **NFR 影响**：无新增依赖；纯文档 + 两处脚本修复。
- **影响面**：`LosAngelousDocs/DOCS_CONTRACT.md`（新）、`scripts/check-docs.sh`（G1/G3 正则、`current_cr`）、`scripts/selftest.sh`（回归用例）。
- **不在范围内**：移动 legacy 记录文件到项目根。
- **变更历史**：v1 2026-11-26 初始。

## R-010 已提交改动可追溯与独立复核（P1，v1）

- **来源**：CR-007
- **背景**：`5c09e61`（协议 + 提速）与 `d6bce31`（WARN 清零）在工作流外提交，缺 CR/R/AC/T 与独立复核。
- **描述**：retro 补齐文档与报告，由 Review 独立复核两个提交，不重做实现。
- **验收标准**：
  - AC-010-1：CR-007 卡、R/AC/T 与追溯矩阵存在。
  - AC-010-2：Doc 报告与 Dev G2 报告落盘到 `reports/`。
  - AC-010-3：Review 报告逐条判定 AC，并给出合法结论。
  - AC-010-4：Review 无 P0/P1；如有，转返工并记录。
- **NFR 影响**：不改变运行时行为。
- **影响面**：`LosAngelousDocs/reports/`、`STATUS.md`、`WORKLOG.md`。
- **不在范围内**：重新实现或修改 `skills/` / `scripts/`。
- **变更历史**：v1 2026-11-26 初始。

## R-011 Skill 告警清零（P1，v1）

- **来源**：CR-007
- **背景**：`validate.sh` 原有 16 个 WARN（11 个 description 缺边界、5 个 `red-tie-xhs` 绝对路径）。
- **描述**：补触发边界，去掉硬编码路径，`validate.sh` 达到 0 ERROR / 0 WARN。
- **验收标准**：
  - AC-011-1：`./scripts/validate.sh` 0 ERROR / 0 WARN。
  - AC-011-2：11 个 Skill 的 description 含「不用于 / Not for」边界。
  - AC-011-3：`red-tie-xhs` 的 `SKILL.md` 不含 `C:\` / `E:\` 绝对路径；`template.py` 支持 `RED_TIE_FONT_DIR`。
- **NFR 影响**：无新增依赖；字体探测失败时给出明确报错。
- **影响面**：12 个 Skill 的 `SKILL.md`、`skills/red-tie-xhs/references/template.py`。
- **不在范围内**：改写 Skill 正文能力。
- **变更历史**：v1 2026-11-26 初始。

## 影响分析（CR-007）

| 维度 | 内容 |
|---|---|
| 受影响需求 | R-009、R-010、R-011（新增） |
| 受影响 AC | AC-009-1～5、AC-010-1～4、AC-011-1～3 |
| 受影响模块 / 接口 | 文档树、`reports/`、Skill 元数据；无运行时接口 |
| 受影响数据 / 配置 | 无数据迁移；新增 `DOCS_CONTRACT.md` |
| 受影响测试 | 复用 `validate.sh`、`check-docs.sh`、`selftest.sh`；无新增测试 |
| 受影响文档 | `00-requirements-intake.md`、`01-requirements.md`、`04-tasks.md`、`STATUS.md`、`CHANGELOG.md` |
| 兼容与迁移 | legacy 记录文件保留原位，`check-docs` 给 WARN 不报错 |
| 风险 | 低：纯文档与元数据；retro 报告需 Review 独立取证 |
