# 四角色开发工作流 Prompt

四个**通用、自包含**的角色 Prompt，对应一套完整的开发闭环：

```
需求受理 (G0) → 文档/AC/任务 (G1) → 开发 (G2) → 上下文合并 (G2.5) → 评审 (G3) → 跨模块检查 (G3.5) → 总审 (G4) → 发布/复盘
```

每个 Prompt 都可以直接粘进任意 AI 工具的新会话（Claude Code、DSH、Codex CLI、Cursor 等），不需要再解释"你是谁、该做什么"。四者共享同一套文档约定、ID 规则、门禁、证据格式和结论用词，所以能真正串起来，而不是四段各自为政的话。

---

## 一、四个角色

| # | 文件 | 角色 | 唯一职责 | 核心产出 |
|---|---|---|---|---|
| 1 | [`01-doc-agent.md`](01-doc-agent.md) | **Doc Agent** | 受理需求、把项目真实状态写成可执行文档 | 需求卡 `CR-xxx`、`<文档根目录>/00` ~ `05`、任务拆解、DoR/G1 确认 |
| 2 | [`02-dev-agent.md`](02-dev-agent.md) | **Dev Agent** | 严格按文档实现，交付可验证的代码 | 代码 + 测试 + 文档同步 + G2 开发报告 |
| 3 | [`03-review-agent.md`](03-review-agent.md) | **Review Agent** | 独立、对抗性地审查实现与影响面 | 评审报告 + 回归结果 + G3 结论 |
| 4 | [`04-meta-review-agent.md`](04-meta-review-agent.md) | **Meta Review Agent / Steward** | 复核文档、实现、评审、流程与结果；Steward 模式维护项目大脑 | 总审报告 + UAT/结果层 + 评分卡 + 上下文增量合并 |
| 5 | [`05-context-protocol.md`](05-context-protocol.md) | **上下文协议** | 四角色共用的记忆与阅读规则 | 大脑读取顺序、阅读预算、增量块、会话复用 |
| 6 | [`06-authorization.md`](06-authorization.md) | **授权协议** | 范围信封、A0/A1w/A1c/A2/A3 分级、台账 | 一次批准、分级记账、越界升级、G3 接受记录 |
| 7 | [`07-speed.md`](07-speed.md) | **提速协议** | 并行派发、门禁合流、预热、模型分层与状态脚本 | 并行组规则、`workflow-status.sh`、反模式 |

### 角色边界（这是整套设计的关键）

| 角色 | 能做 | 不能做 |
|---|---|---|
| Doc | 受理需求、调研、写文档、拆任务、确认 DoR/G1 | 改代码、做评审、替产品拍板 |
| Dev | 按任务实现、写测试、同步文档 | 改需求/AC、自我批准、接未就绪任务、顺手重构 |
| Review | 读代码、跑回归、提缺陷 | 改代码、改文档、采信 Dev 自述 |
| Meta / Steward | 独立复核一切、UAT/结果验收、发布门、下返工指令；维护 `PROJECT_BRAIN.md`；批准 A2 并审计台账 | 复述报告、和稀泥、直接改代码/文档、把大脑写成第二份架构文档 |

> 边界越清晰，四个 Agent 的结论越值钱。任何一个角色"顺手把活干了"，都会破坏下一个角色的独立性。

---

## 二、共享约定（已写进每份 Prompt）

四份 Prompt 都内嵌了同一套约定。正文只在 `_shared-conventions.md` 维护，由 `scripts/render-dev-workflow.sh` 渲染进 01–04 并同步 `prompts/`；**不要手工改 01–04 中标记内的共享块**：

| 约定 | 内容 |
|---|---|
| 文档目录 | 默认 `LosAngelousDocs/`，不再使用 `docs/`（避免与项目自带 docs 重名）。用户明确指定的路径优先；项目已有自己的文档目录时先确认沿用还是新建；都没有则必须询问 |
| 文档树契约 | `<文档根目录>/DOCS_CONTRACT.md` 是唯一契约：允许的路径、唯一职责、维护者、单一事实来源；未登记路径由 `$LOSSKILL_HOME/scripts/check-docs.sh` 拦截 |
| 标准文档集 | `DOCS_CONTRACT` / `STATUS` / `00-overview` / `00-requirements-intake` / `01-requirements` / `02-architecture` / `03-design` / `04-tasks` / `05-decisions` / `CHANGELOG` / `reports/`（含 `review-index.md`、`archive/`）/ `assets/` / `ci/`（MCP 只读） |
| ID 规则 | 需求卡 `CR-xxx`、需求 `R-xxx`（变更升版 `v2`）、验收标准 `AC-xxx`、任务 `T-xxx`、决策 `D-xxx`、假设 `A-xxx`；分配后不复用 |
| 门禁 | `G0` 需求受理 → `G1` 需求/AC/任务确认 → `G2` 开发完成 → `G2.5` 上下文增量合并 → `G3` 评审通过 → `G3.5` 跨模块检查（可选）→ `G4` 总审通过；跳门需用户授权。G2.5/G3.5 必须留 WORKLOG 行（G3.5 可豁免） |
| 上下文 | 所有角色第 0 步读 `PROJECT_BRAIN.md`；每份报告带「上下文增量」；阅读预算 S ≤ 5 / M ≤ 15 / L 分阶段；同一 CR 内 Dev/Steward 复用会话；并行规则见 `07-speed.md` |
| 授权 | 用户在 G1 批准一次「范围信封」；**A1w**（改代码/文档/大脑，不 commit）由信封授权、记 WORKLOG；**A1c**（当前分支 commit，单分支默认 `main`）由 Review 在 G3 后记账；A2 由 Steward（可委托 Review 批低风险）；A3 只由用户；Review 不得自批 G3，G3 接受记 WORKLOG；台账只追加 A1c/A2/A3 |
| 工作日志 | 每个角色交付报告后填 `report-meta`，运行 `$LOSSKILL_HOME/scripts/finish-report.sh --project-root <项目根>`，自动写 `WORKLOG.md` 与（A1c/A2 时）`AUTH-*`；记录根默认项目根，存量项目可用文档根；Steward 在 G4 审计 |
| 任务状态 | `TODO` / `DOING` / `DONE` / `BLOCKED` / `DROPPED` |
| 证据格式 | `文件:行号`、命令 + 关键输出、commit hash；无证据必须标 `[推断]` |
| 严重度 | `P0` 阻断 / `P1` 严重 / `P2` 一般 / `P3` 建议 |
| 结论词 | 评审：`通过` / `有条件通过` / `不通过`；总审：`通过` / `返工` |
| 状态面板 | `<文档根目录>/STATUS.md`：当前 CR、门禁、进行中任务、阻塞、下一步、最近报告 |
| 报告落盘 | `<文档根目录>/reports/<角色>-<日期>-<范围>.md` |
| 用户注释保护 | `LosAngelous:` / `LOS:` 开头的用户手写注释，任何角色都不得修改/删除/覆盖/重排 |
| 交互补充 | 信息缺失或要求不明确时先问、等回答，不得用主观假设继续 |
| 强制交接 | 每份报告结尾必须有"下一步交接"：交给谁 / 依据 / 携带材料 / 可直接复制的 Prompt |

### 为什么要有 AC（验收标准）

整条链路靠 AC 传递"什么叫做完"，最后用结果层确认"是否真的解决"：

```
CR 成功指标 → R/AC → Dev 逐条实现并验证 → Review 逐条判定 → Meta 复核 + UAT/结果层
```

没有可测试的 AC，后面三个角色全部只能互相打嘴仗；没有结果层，又会"正确地通过一个错误的需求"。所以 Doc Prompt 把"AC 覆盖正常/边界/错误"写成了硬要求，Meta 则单独增加结果层。

---

## 三、怎么用

### 基本流程

**直接把对应文件全文发给 Agent 即可**，不需要提前填表。Agent 会先确认身份，再向你索要缺少的信息；缺哪样问哪样。

```bash
# 1. 需求受理 + 文档
新会话 → 发送 01-doc-agent.md → 先确认【文档生成路径】【项目现状】【本次需求】
（首次建立：$LOSSKILL_HOME/scripts/init-docs.sh <文档根目录>；先产出 CR 需求卡让你选"做 / 拆小 / 先 spike / 缓办 / 不做"= G0；确认后才写 R/AC/T）
（G1 前：$LOSSKILL_HOME/scripts/check-docs.sh <文档根目录> --gate g1 必须 0 ERROR，STATUS.md 写 G1 已确认：是）

# 2. 开发（G1 确认后）
新会话 → 发送 02-dev-agent.md → 确认【项目路径】【本次任务（CR/T）】【上一轮反馈】
（先核对 DoR，不满足就退回；建议每个任务开一个新会话）

# 3. 评审（G2 完成并自检后）
新会话 → 发送 03-review-agent.md → 确认【项目路径】【评审范围】【文档位置】
（按影响面跑回归，不只审 diff）

# 4. 总审 + 结果验收（G3 通过后）
新会话 → 发送 04-meta-review-agent.md → 确认【项目路径】【本次范围】【已有材料】
（五层总审：文档 / 实现 / 评审 / 流程 / 结果；UAT 通过后才给 G4）
```

### 门禁速查

| 门 | 谁负责 | 出口条件 |
|---|---|---|
| **G0** 需求受理 | Doc + 用户 | `CR-xxx` 需求卡确认；选项（做/拆小/spike/缓/不做）已选定 |
| **G1** 需求冻结 | Doc + Steward + 用户 | R/AC/T/影响分析/DoR/NFR 已确认；Steward 完成影响预判；用户同时批准「范围信封」；`check-docs --gate g1` 为 0 ERROR 且 `STATUS.md` 写 `G1 已确认：是` |
| **G2** 开发完成 | Dev | DoD 全部满足，自检报告与「上下文增量」已出（不等于评审通过） |
| **G2.5** 上下文合并 | Steward | 增量合并进 `PROJECT_BRAIN.md`，标记过期内容；不改代码、不替代评审；WORKLOG 留 `gate=G2.5` 行 |
| **G3** 评审通过 | Review | 结论为 `通过` / `有条件通过`，回归与影响面已覆盖；Review 不得自批 G3，接受由 Steward/用户记 WORKLOG |
| **G3.5** 跨模块检查 | Steward（可选） | 检查跨 CR/跨模块耦合与大脑一致性；高风险改动必做；WORKLOG 留 `gate=G3.5` 行或 STATUS 写豁免 |
| **G4** 总审通过 | Steward/Meta + 用户 | 五层总审通过，UAT/结果层达成，发布准备就绪 |

> 跳门不是绝对禁止，但必须由用户明确授权，并在报告里写明原因与影响。

> 门禁有机器检查：`check-docs.sh <文档根目录> --gate g1|g2|g3|g4`，以及 `--gate g2.5|g3.5`。G1 验需求/AC/任务与确认标记；G2 验 dev 报告与 AC 映射；G2.5/G3.5 验 WORKLOG 行（G3.5 可豁免）；G3 验 review 报告、结论、review-index 与 G3 接受记录；G4 验 meta 报告或「G4 豁免」。

> 提交时序固定：Dev 不 commit（A1w 记 WORKLOG）→ Review 在 G3 结论后批准 A1c → 主会话执行 commit 并用 `finish-report.sh --backfill` 回填 hash → push 属 A2，由 Steward 批准。用户明确要求 Dev 自行提交时，A1c 改由 Steward 记账。

### 一个需求到来时的完整链路

```
需求到达
  → Doc 产出 CR 需求卡（问题/价值/成功指标/NFR/选项）
  → G0：用户选择做 / 拆小 / spike / 缓 / 不做
  → Doc 写 R/AC/T + 影响分析 + DoR + 追溯矩阵
  → G1：用户确认需求与验收标准
  → Dev 按风险×价值做最小纵切 → 实现 → 回归 → 自检（G2）
  → Review 按影响面评审 + 回归（G3）
  → Meta 五层总审 + UAT/成功指标验证（G4）
  → 发布 / 回滚预案 / 复盘
```

### 交互原则（重要）

四个 Agent 都被要求：**要求不明确时先问，不主观臆断**。具体表现为：

- 一次把问题列清：缺什么、为什么影响结论、可选项与代价、推荐项；
- 你的回答仍然含糊，它会继续追问，直到能落成可测试的 AC 或明确行为；
- 只有你明确说"按你的判断来"，它才会采用默认方案，并在报告里标 `[假设]`；
- Doc Agent 在文档路径确认前只做只读调研，不创建/修改任何文档。

### 交接约定（每份报告都必须有）

每个 Agent 回复你时，最后必须给一个"**下一步交接**"块，包含四样东西：

1. **交给谁**：Dev / Review / Meta / Doc / 用户；
2. **依据**：哪个门禁、哪个结论、哪些返工项；
3. **携带材料**：文档根目录、`CR/T` 编号、commit、报告路径；
4. **可直接复制的 Prompt**：你把它原样发给下一个 Agent 即可。

例如 Doc Agent 在 G1 确认后应输出：

```text
## 下一步交接
- 交给：Dev Agent
- 依据：CR-001 已确认；G1 已通过；T-001 满足 DoR
- 携带材料：LosAngelousDocs/、T-001、LosAngelousDocs/reports/dev-...、影响分析

请把下面这段发给 Dev Agent：
【项目路径】/path/to/project
【本次任务】T-001（CR-001）
【上一轮反馈】无
【文档根目录】/path/to/project/LosAngelousDocs
【文档就绪】check-docs --gate g1：退出码 0
```

各角色的交接去向：

| 当前 Agent | 通过 / 完成时 | 阻塞 / 不通过时 |
|---|---|---|
| Doc | → Dev（G1 已确认） | → 用户（G0/G1 未确认） |
| Dev | → Review（G2 完成） | → Doc / 用户（DoR、AC、环境缺口） |
| Review | → Meta（G3 通过） | → Dev（返工）/ Doc（标准不清） |
| Meta | → 用户 / 发布负责人（G4） | → Dev / Doc / Review（按返工项拆开） |

> 硬规则：**G1 未确认不得把 Prompt 交给 Dev**；返工必须写具体编号，不要让下一个 Agent "按报告修一下"。

### 推荐的节奏

- **大项目 / 首次接入**：完整跑 `G0 → G1 → Dev（按任务）→ Review（每个任务或每组）→ Meta + UAT（每轮）`。
- **小改动 / 修 Bug**：满足 S 条件时走「S 快车道」（一行 G0 → G1-lite → Dev → Review 快评 → 提交 → 用户验收），跳过 G2.5/G3.5/G4；超出 S 条件立即转完整流程。
- **需求中途变化**：先建新 `CR-xxx` 或升版 `R-xxx v2`，重新确认 G1 与影响面，再让 Dev 动手；不要把变更直接塞给 Dev。
- **返工**：把 Meta 的返工指令原样贴给对应 Agent 的下一轮，作为【上一轮反馈】。不要重写，保留证据链。同一门禁最多返工 2 轮，第 3 轮必须由用户裁决（继续 / 回 G1 / 拆小 / 放弃）。

### 提速（并行与合流）

完整规则见 [`07-speed.md`](07-speed.md)，要点：

- **并行任务**：同一 CR 内文件不相交、无依赖的 T 可同时派多个 Dev；默认最多 3 个写代理；主会话负责合流并检查没有同一文件被两个 T 改过。
- **并行评审**：每个 T 独立 Review，主会话汇总；Review 的独立性不变。
- **G2.5 与 G3 并行**：Steward 合大脑不阻塞 Review，但必须在 commit 前完成。
- **门禁合流**：需求清楚时 G0+G1 一次确认；小 diff 把 G2.5 并入 G3；单模块可豁免 G3.5；纯文案/样式/文档可豁免 G4。合流必须写进 `STATUS.md`。
- **预热**：G1 确认前允许 Dev 只读调研（A0），写操作仍等确认。
- **状态脚本**：每次接手先跑 `$LOSSKILL_HOME/scripts/workflow-status.sh <文档根目录> --project-root <项目根>`，不要凭记忆推断当前阶段。
- **模型分层**：机械/记账用快模型，实现用主模型，评审/总审用强模型。

### 每轮需要带上的材料

| 会话 | 最少输入（可提前给，也可等它问） |
|---|---|
| Doc | 项目路径 + **项目现状** + **本次需求** + **文档生成路径**；已有 CR/需求文档（如有） |
| Dev | 项目路径 + 任务 ID（`CR-xxx` / `T-xxx`）+ DoR 状态 + 上轮反馈（如有） |
| Review | 项目路径 + 评审范围（任务/提交区间/PR）+ 文档位置 + 影响分析/回归范围 |
| Meta | 项目路径 + 范围 + 三份报告路径 + `STATUS.md` / CR（或明确说"无"） |

---

## 四、设计取舍（为什么角色提示词不各自做成 Skill）

`dev-workflow` 本身是触发式 Skill（用户说「按开发工作流来」时加载）；四份角色 Prompt 是它的 `references/`，不单独注册为 Skill：

- 角色是**常驻身份**，需要主会话主动派发，并要求 Agent 在整场会话里保持同一边界；
- 单独做成 Skill 会在不该触发时触发，也难携带「你不许做什么」这类强约束；
- 在 Claude Code 中，它们由 `scripts/install-claude-config.sh` 从 `references/` 生成 `~/.claude/agents/{doc,dev,review,meta-review}-agent.md`（frontmatter 写 `name` / `description` / `tools`），由主会话调度。

注意：subagent 模式会改变工作方式（由主会话调度，而不是你手动切换上下文）；不装 subagent 时，仍可把对应文件全文发给一个全新会话。

---

## 五、使用建议与常见问题

### Q：文档必须叫 `LosAngelousDocs/`、文件名必须叫 `00-overview.md` 吗？

不需要叫 `docs/`——本工作流默认用 **`LosAngelousDocs/`**，避免与项目自带的 `docs/` 重名。Doc Agent 的第一轮交互会和你确认文档根目录；项目已有自己的文档目录时，先问清是沿用还是新建 `LosAngelousDocs/`。文件名优先沿用项目已有命名体系，只要求在 `DOCS_CONTRACT.md` 里能映射到标准职责（如 `architecture.md` 对应 `02-architecture`），不会为了套模板而重命名或复制文档。

### Q：Agent 能自己在文档根目录下新建目录/文件吗？

不能。`DOCS_CONTRACT.md` 是唯一路径清单；未登记路径会被 `$LOSSKILL_HOME/scripts/check-docs.sh` 在 G1/G3/G4 拦截。确需新增时，由 Doc 说明用途、与现有路径的重叠、维护者，用户批准后更新契约再创建。报告命名也固定为 `reports/<角色>-<YYYY-MM-DD>-<范围>.md`。

### Q：项目已经有一套文档怎么办？

Doc Agent 的目标 B 就是干这个的：先做**差异审计**（缺失 / 过时 / 矛盾 / AC 不可测 / 断链），先报告再写入，不覆盖原有有效内容。

### Q：Dev 说文档有问题，该听谁的？

Prompt 里的规则是：影响 AC/契约/对外行为 → **停下交互确认**；纯内部实现细节 → 可采用最小改动，但必须披露 `[假设]`；明显笔误且修正不改变语义 → 按显然正确的一处实现并标注。**任何角色都不能为了自洽去改需求。**

### Q：我在文档里写的 `LosAngelous:` 注释会被覆盖吗？

不会。四个 Prompt 都把它写进共享约定：任何角色不得修改、删除、覆盖、合并或重排。Doc Agent 更新文档时要求先扫描、定点编辑、写后逐条核对；Review 和 Meta 都把它列为必查项，发现破坏会报缺陷/返工。

### Q：Agent 一直追问会不会很烦？

追问只发生在"会影响结论"的信息上。每个 Prompt 都要求**一次把问题列清**（缺什么、影响、选项、推荐），而不是挤牙膏。如果你希望它自行决定，明确说"按你的判断来"，它才会采用默认方案并在报告里标注 `[假设]`。

### Q：需求很模糊，或者我还没决定要不要做，怎么办？

Doc Agent 的第一阶段就是 **G0 需求受理**：它不会直接写 R/AC/T，而是先产出一张 `CR-xxx` 需求卡，把问题、价值、成功指标、NFR、风险和选项摆清楚——包括"拆小 / 先 spike / 缓办 / 不做"。你选定之后，才进入文档细化。Doc 不替你做产品决定。

### Q：Dev 说 DoR 没就绪、把任务退回了，是不是在推活？

不是。DoR 是任务级"可开工"标准：AC 可测、依赖已清、决策已记、影响面已分析、测试环境可用。缺这些就开工，最后返工成本更高。Dev 退回时应写明"缺什么、由谁补"，Doc/用户补齐后再继续。

### Q：UAT / 结果验收谁来做？

Meta Agent 负责组织 UAT：按 AC 在真实环境走用户视角的操作，记录实际 vs 期望；你负责确认"这是不是我要的"。如果实现符合 AC 但 AC 本身没覆盖你的真实问题，Meta 会把它归因为**需求缺陷**（回到 Doc/CR），而不是让 Dev 背锅。

### Q：Review 和 Meta 会不会重复？

会检查同一份代码，但目的不同：

- Review 回答"这次改动有没有问题、影响面/回归是否覆盖"；
- Meta 回答"Review 的结论能不能信、还有没有漏、文档和流程闭环没有、以及**用户的问题是否真的解决**"。

Meta 的价值恰恰在于**不信任 Review**，并多一层结果验收。如果两者结论完全一致且都基于证据，那说明流程是健康的。

### Q：怎么防止四个 Agent 互相背书？

四条机制已经写进 Prompt：

1. **证据格式强制**：每条结论必须能定位到文件行号或命令输出。
2. **独立性规则**：Review 不得把 Dev 报告当证据；Meta 不得把 Review 结论当证据。
3. **结论可推出**：通过/不通过必须由 AC 表和 findings 直接推出，不允许"总体感觉"。
4. **门禁与结果层**：G0-G4 按序通过；Meta 必须做 UAT/成功指标验证，不能只验 AC。

### Q：上下文太长怎么办？

- 先读 `PROJECT_BRAIN.md`，只读任务相关的模块卡与改动面代码；不要把全仓库塞进上下文。
- 报告落盘到 `<文档根目录>/reports/`，下一轮只带路径 + 增量块，不带全文。
- 同一 CR 内 Dev/Steward 复用会话；跨 CR 新建会话，新会话只读大脑 + 相关报告。
- Review 只读大脑 + 本次增量 + diff + 改动面/调用方/测试；按 `review-index.md` 决定先看哪里。
- Meta 只需读大脑 + 报告 + 抽查代码，不需要读全部实现细节。

### Q：授权能不能全交给 Agent？

可以委托「信封内的程序性授权」，不能委托 A3：

- 用户在 G1 批准一次范围信封（路径、命令、提交上限、到期、禁止项）。
- **A1w**（改代码/测试/文档/大脑，不 commit）由信封授权，执行者记 WORKLOG；**A1c**（当前分支 commit，单分支默认 `main`）由 Review 在 G3 后批准并记账；A2（push、PR、合并、依赖、构建/CI）由 Steward；A3（生产、删库、密钥、force push）永远由用户确认。
- Review 不能批准自己的 G3 结论，否则是自证；G3 接受由 Steward 或用户记 WORKLOG（不占 AUTH）。
- Agent 不能替用户点 Claude Code 的权限弹窗；宿主权限仍由 harness 控制。
- 台账 `AUTHORIZATIONS.md` 只追加 A1c/A2/A3，不删改；A1w/G2.5/G3.5/G3 接受记 WORKLOG。默认项目根，存量项目可用文档根；G4 审计缺失/越界。详见 `06-authorization.md`。

### Q：怎么知道每个 Agent 做过什么？

看项目根 `WORKLOG.md`：每行有 ID、时间、角色、门禁、CR/T、动作、报告链接、commit、AUTH、状态。填好报告头部的 `report-meta` 后运行 `$LOSSKILL_HOME/scripts/finish-report.sh`，会自动追加并回填 `LOG-ID`；详细证据仍在 `reports/`。STATUS 只记当前状态，WORKLOG 记历史流水。

### Q：中文项目 / 英文项目都适用吗？

适用。Prompt 是中文，但产物语言跟随项目：项目文档是英文就用英文写，代码注释跟随代码库习惯。

---

## 六、文件清单

```
skills/dev-workflow/references/
├─ 00-workflow-readme.md     ← 本文件
├─ _shared-conventions.md    ← 共享约定单一正文（渲染进 01–04）
├─ 01-doc-agent.md           ← 文档生成与维护
├─ 02-dev-agent.md           ← 开发实现
├─ 03-review-agent.md        ← 独立代码评审
├─ 04-meta-review-agent.md   ← 全链路总审 / Steward
├─ 05-context-protocol.md    ← 上下文协议（大脑 / 增量 / 预算 / 复用）
├─ 06-authorization.md       ← 授权协议（信封 / A1w / A1c / A2 / A3 / 台账）
└─ 07-speed.md               ← 提速协议（并行 / 门禁合流 / 预热 / 模型分层）
```

渲染与副本同步：`./scripts/render-dev-workflow.sh`；只检查不写入：`--check`（`validate.sh` 会调用它，落后即报错）。
