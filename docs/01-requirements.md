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
| 受影响文档 | `docs/01-requirements.md`、`docs/03-design.md`、`docs/04-tasks.md`；`leverage-protocol/SKILL.md` 的退出码说明（如 A-001 改变语义） |
| 兼容与迁移 | 旧缓存可读；roots 不一致时自动重建；无需数据迁移 |
| 风险 | 中：剥离否定从句会改变全局排名，可能影响其他查询；用 AC-002-3 与抽样回归缓解 |
