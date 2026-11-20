# 04 — 任务（CR-001）

> 维护者：Doc Agent ｜ 最近更新：2026-11-20 ｜ 状态：T-001 DONE（待 G3）；T-002 / T-003 TODO

## T-001 查询空结果判空（状态：DONE）

- **来源**：CR-001 / R-001（v1）
- **关联需求**：AC-001-1、AC-001-2、AC-001-3
- **目标**：无匹配时输出可读提示，不再抛 `IndexError`。
- **涉及文件/模块**：`skills/leverage-protocol/scripts/capability_index.py`（`cmd_query`）
- **前置依赖**：A-001 退出码结论
- **DoR**：
  - [x] AC 可测
  - [x] 无前置代码依赖
  - [x] A-001 已确认（G1：保持 exit 1）
  - [x] 影响面已分析
  - [x] 环境可用（Python 3、仓库根）
- **验证方式**：
  - `python3 skills/leverage-protocol/scripts/capability_index.py query qqqzzz` → 含「没有匹配」、无 `Traceback`、exit 1
  - 加 `--allow-empty` → exit 0
  - 加 `--json` → 合法 JSON、`confident=false`、exit 1
- **回归范围**：`query` 的正常命中、低分候选、`--json`；`plan` 不受影响。
- **发布/回滚**：无发布；单文件回滚。
- **风险**：低；只改空分支。
- **规模**：S
- **阻塞原因**：无；2026-11-20 完成，证据见 `docs/reports/dev-2026-11-20-T-001.md`。

## T-002 剥离否定边界从句（状态：TODO）

- **来源**：CR-001 / R-002（v1）
- **关联需求**：AC-002-1、AC-002-2、AC-002-3、AC-002-4
- **目标**：`不用于 / 不适用 / 不涉及 / Not for` 后的词不再抬高匹配分数，正向信号仍可命中。
- **涉及文件/模块**：`skills/leverage-protocol/scripts/capability_index.py`（`tokenize` / `build_index` / `score`）
- **前置依赖**：A-002 剥离边界结论；T-001 可并行
- **DoR**：
  - [x] AC 可测（含夹具边界 AC-002-4）
  - [x] 无前置代码依赖
  - [x] A-002 已确认（G1：切到句末）
  - [x] 影响面已分析
  - [x] 环境可用
- **验证方式**：
  - `query "书摘 读后感" --json` → `huashu-nuwa` 不 confident
  - `plan "给游戏调数值平衡"` → `game-design-mechanics` 进前三且高于 `game-design-tetrad`
  - `query "机制平衡"` → `game-design-mechanics` 第一
  - 临时 roots 夹具覆盖「不用于 X」vs「适用信号 X」
- **回归范围**：全部 22 个 Skill 的查询排名；抽样对照修复前后 top 3；`plan` 输出。
- **发布/回滚**：无发布；单文件回滚。
- **风险**：中；会改变全局排名，可能影响其他查询。
- **规模**：M
- **阻塞原因**：无（G1 已确认，等待 T-001 完成）。

## T-003 缓存感知 roots（状态：TODO）

- **来源**：CR-001 / R-003（v1）
- **关联需求**：AC-003-1、AC-003-2、AC-003-3
- **目标**：roots 变化时重建索引，不再复用旧 roots 的缓存。
- **涉及文件/模块**：`skills/leverage-protocol/scripts/capability_index.py`（`stale` / `load_or_build`）
- **前置依赖**：无（可与 T-001/T-002 并行，但改动同一文件，建议串行）
- **DoR**：
  - [x] AC 可测
  - [x] 无前置代码依赖
  - [x] 无需用户决策（A-003 由 Dev 按设计 3 节实现）
  - [x] 影响面已分析
  - [x] 环境可用
- **验证方式**：
  - roots A 构建 → roots B 查询 → 缓存 roots 变 B，B 独有 Skill 可命中
  - roots 不变连续查询 → `generated_at` 不变
  - roots 顺序不同、集合相同 → 不重建
- **回归范围**：正常缓存复用；mtime 过期逻辑；`--refresh`。
- **发布/回滚**：无发布；单文件回滚。
- **风险**：低。
- **规模**：S
- **阻塞原因**：无（与 T-002 串行，避免同文件冲突）。

## 任务顺序与关键路径

`T-001 → T-002 → T-003`

- T-001 是最薄的端到端纵切，先验证「改代码 → 跑命令 → 报告」链路。
- T-002 价值最高但风险最大，放在 T-001 之后。
- T-003 与前两者同文件，串行避免冲突。

## AC ↔ 验证追溯矩阵

| AC | 验证方式 | 对应任务 | 状态 |
|---|---|---|---|
| AC-001-1 | `query qqqzzz` 文本输出 + exit 1 | T-001 | 已通过 |
| AC-001-2 | `query qqqzzz --allow-empty` + exit 0 | T-001 | 已通过 |
| AC-001-3 | `query qqqzzz --json` + 合法 JSON | T-001 | 已通过 |
| AC-002-1 | `query "书摘 读后感" --json` | T-002 | 待验证 |
| AC-002-2 | `plan "给游戏调数值平衡"` | T-002 | 待验证 |
| AC-002-3 | `query "机制平衡"` | T-002 | 待验证 |
| AC-002-4 | 临时 roots 夹具 | T-002 | 待验证 |
| AC-003-1 | roots A→B 缓存复现 | T-003 | 待验证 |
| AC-003-2 | 连续查询 `generated_at` | T-003 | 待验证 |
| AC-003-3 | roots 顺序变化 | T-003 | 待验证 |
