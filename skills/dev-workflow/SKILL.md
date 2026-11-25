---
name: dev-workflow
description: |
  四角色开发工作流：G0 需求受理 → G1 需求/AC/任务确认 → G2 开发 → G3 评审 → G4 总审。主会话担任 Doc Agent/协调者，只写文档与状态、不写业务代码；开发、评审、总审分别交给独立 Dev / Review / Meta Agent（优先用子代理，避免占用主会话上下文）。用户说“按开发工作流来”“走流程开发”“用四个 Agent”“先出需求卡再开发”时使用。不用于纯问答、一次性脚本、没有文档根目录的临时改动。
---

# 四角色开发工作流

主会话担任 **Doc Agent 与协调者**。开发、评审、总审必须交给独立角色；主会话不写业务代码、不做评审、不做最终验收。

本 skill 自带四份完整角色提示词：

| 文件 | 角色 | 使用时机 |
| --- | --- | --- |
| `references/01-doc-agent.md` | Doc Agent | 需求受理、写 R/AC/T、文档审计 |
| `references/02-dev-agent.md` | Dev Agent | G1 确认后实现任务、处理评审返工 |
| `references/03-review-agent.md` | Review Agent | G2 自检完成后独立评审（G3） |
| `references/04-meta-review-agent.md` | Meta Review Agent | G3 通过后全链路总审 + UAT（G4）；兼 Steward 模式维护大脑 |
| `references/05-context-protocol.md` | 上下文协议 | 所有角色开工第 0 步；大脑 / 增量 / 阅读预算 / 会话复用 |
| `references/06-authorization.md` | 授权协议 | 范围信封 / A0–A3 分级 / 台账 / 角色分工 |

`references/00-workflow-readme.md` 是四个角色的总说明与使用建议。

如果当前环境支持自定义子代理（如 Claude Code 的 `~/.claude/agents/`），把四份角色文件分别注册为 `doc-agent` / `dev-agent` / `review-agent` / `meta-review-agent`，由主会话调度；否则把对应文件全文发给一个全新会话，作为该角色的系统提示词。

## 0. 共享大脑（先读这个）

项目根应有一个 `PROJECT_BRAIN.md`（没有时找 `<文档根目录>/PROJECT_BRAIN.md`），保存架构地图、模块边界、不变量、契约、验证命令、热点、测试地图、决策索引与最近变更。

- 所有角色**开工第 0 步读它**，再读任务相关文档与改动面代码，不通读全仓库。
- 每份报告必须有「上下文增量」；Steward 在 G2.5 合并回大脑。
- 新项目用 `$LOSSKILL_HOME/scripts/bootstrap-project.sh` 生成；协议细节见 `references/05-context-protocol.md`。
- `LOSSKILL_HOME` 指向 LosSKILL 仓库根目录，记录在 `PROJECT_BRAIN.md` 第 1 节（bootstrap 会自动写入）。所有脚本命令统一写成 `$LOSSKILL_HOME/scripts/...`；`LOSSKILL_HOME` 缺失时先问用户，**不得假设当前项目下有 `scripts/`**。

## 0.6 授权（委托信封）

用户只在 G1 批准一次「范围信封」（允许路径、命令、提交上限、到期、禁止项），写进 `<文档根目录>/AUTHORIZATIONS.md`。日常动作按级别执行并记账：

| 级别 | 例子 | 批准人 |
|---|---|---|
| A0 | 读代码、跑测试、lint、build | Agent 自主 |
| A1 | 改代码、写文档、feature 分支 commit | Review（记账） |
| A2 | push、PR、合并 main、依赖/构建配置 | Steward/Meta（信封可委托 Review 批低风险） |
| A3 | 生产部署、删库、force push、密钥/权限 | 用户本人，永不委托 |

- Review **不能**批准自己的 G3 结论；G3 接受由 Steward 或用户记账。
- 越出信封一律停下问用户；过期/超提交上限自动失效。
- Agent 不能替代 Claude Code 的权限弹窗；宿主权限仍由 harness 控制。
- 细节见 `references/06-authorization.md`。

## 0.7 工作日志

每个角色交付报告后，填好报告头部的 `report-meta`，运行 `$LOSSKILL_HOME/scripts/finish-report.sh --report <报告>`：它同时写 `WORKLOG.md` 与（如填写了 auth 字段）`AUTHORIZATIONS.md`，并回填 `LOG-ID`。Steward 在 G4 审计两本账。

它是跨角色、跨 CR 的历史索引，不是 STATUS 或大脑的替代品。细节见 `references/05-context-protocol.md` 与 `references/06-authorization.md`。

## 0.8 文档树契约（G1 的硬前提）

`<文档根目录>/DOCS_CONTRACT.md` 是文档根目录的**唯一契约**：列出允许的文件/目录、唯一职责、维护者、写入规则，以及「单一事实来源」表。未登记的路径一律视为流程违规。

- **首次建立文档**：`$LOSSKILL_HOME/scripts/init-docs.sh <文档根目录>`，一次性铺齐 `DOCS_CONTRACT.md`、`STATUS.md`、`00`–`05`、`CHANGELOG.md`、`reports/review-index.md`、`reports/archive/`、`assets/`。
- **开工第 0 步**：读 `PROJECT_BRAIN.md` 后读 `DOCS_CONTRACT.md`，再读任务文档。
- **不得新建未登记的文件/目录**。确需新增时，由 Doc 说明用途、与现有路径的重叠、维护者，经用户批准后更新契约，再创建。
- **报告命名固定**：`reports/<角色>-<YYYY-MM-DD>-<范围>.md`；只允许 `archive/`、`ci/` 两个子目录。
- **CI 区域只读**：`ci/` 与 `reports/ci/` 由 ci-artifacts MCP 写入，Agent 只读。
- **G1 出口三件套**（缺一不得派发 Dev）：
  1. 用户明确确认 CR/R/AC/T；
  2. `$LOSSKILL_HOME/scripts/check-docs.sh <文档根目录> --gate g1` 退出码 0（0 ERROR）；
  3. `STATUS.md` 写 `G1 已确认：是`。

## 1. 开工

1. 确认 **文档根目录**。默认 `LosAngelousDocs/`；不得使用 `docs/`（易与项目自带 docs 重名）。项目已有自己的文档目录时，先确认沿用还是新建 `LosAngelousDocs/`；新建时运行 `$LOSSKILL_HOME/scripts/init-docs.sh <文档根目录>`。
2. 收集 **项目现状** 与 **本次需求**；缺什么问什么，不猜。
3. 新需求 / 变更先做 **G0**：产出 `CR-xxx` 需求卡（问题、价值、成功指标、NFR、选项与代价），由用户选择做 / 拆小 / spike / 缓 / 不做。
4. G0 通过后写 R/AC/T、影响分析与追溯矩阵，发 **G1 摘要**，等用户明确确认。

## 2. 门禁与交接

```
G0 需求受理（Doc + 用户）
 → G1 需求/AC/任务确认（Doc + Steward 影响预判）
 → G2 开发完成（Dev Agent）
 → G2.5 上下文增量合并（Steward，轻量）
 → G3 评审通过（Review Agent）
 → G3.5 跨模块检查（Steward，可选）
 → G4 总审通过（Steward/Meta + 用户，风险触发）
```

- **G1 未确认，不得启动 Dev**。
- **G1 出口硬检查**：用户确认 + `check-docs --gate g1` 0 ERROR + `STATUS.md` 的 `G1 已确认：是`，三者缺一不得派发。
- **G2/G3/G4 同样是机器检查**：`$LOSSKILL_HOME/scripts/check-docs.sh <文档根目录> --gate g2|g3|g4`，角色交付前必须 0 ERROR（g2 验 dev 报告与 AC 映射；g3 验 review 报告、结论与 review-index；g4 验 meta 报告或「G4 豁免」）。
- **G2 未完成，不得启动 Review**；G2.5 只合并增量，不替代评审。
- **G3 未通过，不得启动 Meta**。
- 跳门必须由用户明确授权，并写进 `STATUS.md` 与报告。
- 角色独立性：Review 不采信 Dev 报告作证据；Meta 不采信 Review 结论作证据。

### 2.1 提交与推送（固定时序）

**谁在什么时候提交只有这一条链，其他写法一律视为流程违规：**

1. **Dev 不 commit**：G2 交付工作区改动 + 变更清单 + 报告（commit 列写「工作区未提交」）。
2. **Review 审工作区**：用 `git diff` 评审；G3 结论给出后，**仅在通过 / 有条件通过时**记 A1（commit 授权）并回填 `AUTH-*`。
3. **主会话执行 commit**：核对 A1 条目、与用户确认提交信息后，由主会话执行 `git add` / `git commit`；主会话不改业务代码。提交后把真实 hash 回填报告、`STATUS.md` 与版本表。
4. **push 属 A2**：由 Steward 批准并记账；用户明确要求才推送，默认 `origin/main`。

- **例外（用户明确要求 Dev 自行提交）**：Dev 可在 G2 提交，但 A1 必须由 Steward 记账（Review 此时尚未评审，不得自证）；G3 的评审对象即该 commit。
- **一个需求一个 commit**：不同 CR 的代码、文档、报告不混在同一个提交里；跨 CR 的同一文件用 hunk 级暂存。
- **新任务开工前先检查工作区**：`git status` 有未提交改动时，先结束上一个需求的提交，再开始新需求；不得把上一个需求的改动带进新任务。
- **提交信息与用户交互式确认**：先给出一条建议信息（`[feat]` / `[fix]` / `[docs]` + 一句话），请用户补充或修改，确认后再执行 `git commit`。
- **G4 复验基线**：以提交后的 HEAD 为准；若提交发生在总审期间，在报告中说明。
- 未经用户确认的提交信息或推送目标，不得自行决定。

### 2.2 G4 触发规则（按复杂度，避免过度总审）

G4 是成本最高的门禁，按改动风险选择，不默认全量启动：

- **必须启动 G4**：涉及数据模型 / 迁移 / 种子、接口或鉴权 / 权限、新增依赖或构建配置、跨模块或多页面、不可逆操作或发布风险高；或 G3 结论为“有条件通过”、存在 P2。
- **可跳过 G4（需用户同意）**：纯文案 / 样式 / 导航位置 / 文档 / 版本号；不改数据、接口、鉴权；代码改动 ≤ 3 个文件；G3 通过且无 P0/P1。
- **跳过时**：在 `STATUS.md` 记“G4 豁免（用户授权 + 适用规则）”，保留 G3 报告与提交；版本表、归档状态与发布说明仍要回填。
- **拿不准**：默认启动 G4，或先问用户；不得以“节省 token”为由跳过高风险改动。

### 2.3 返工轮次上限

同一 CR 在同一门禁的返工**最多 2 轮**；第 3 轮必须停下，由用户在以下选项中决定：

- 继续（写明为什么前两轮没收敛、本轮改法有何不同）；
- 回到 G1 重定范围或 AC；
- 拆成更小的 CR；
- 暂停或放弃。

补充规则：

- Review「不通过」只把 P0/P1 列为阻断项；P2/P3 不阻断，可给「有条件通过」并转后续任务。
- 每轮返工把上一轮的 finding 编号原样带回，不重写证据链。
- 超过 2 轮仍不收敛，通常是需求/AC 问题，不是 Dev 手速问题：优先回 Doc，而不是继续加压 Dev。

### 2.4 S 快车道（与 AGENTS.md 的 S 小改对齐）

**适用条件（全部满足）**：单文件或 ≤ 3 个文件；不改接口 / 数据模型 / 鉴权 / 依赖 / 构建配置；不新增文档路径；风险低。

**流程**：

```
G0 一行记录（问题 + 范围）→ G1-lite（1 个 CR / R / AC / T，用户确认）
→ Dev 实现并自证 → Review 快评（跑构建与相关测试 + 看 diff + 判 AC）
→ 主会话 commit（Review 记 A1）→ 用户验收
```

- **保留**：编号、AC、证据格式、`check-docs --gate g1`、A1 记账、主会话 commit。
- **跳过**：G0 的选项讨论（拆小/spike 等）、G2.5、G3.5、G4、Review 的 15 维全量清单。
- **Review 快评**：只跑构建 + 相关测试 + 看 diff + 逐条判 AC；结论仍用「通过 / 有条件通过 / 不通过」。
- **升级触发**：一旦碰到接口、数据、鉴权、依赖、多模块或新增路径，立即停止 S 通道，转完整流程并说明原因。
- **记录**：`STATUS.md` 写 `通道：S`，报告与 WORKLOG 标注「S 通道」。

## 3. 派发开发 / 评审 / 总审

每个执行角色使用独立上下文，简报必须自包含：

```
【项目路径】<绝对路径>
【LOSSKILL_HOME】<LosSKILL 仓库根目录绝对路径；脚本统一用 $LOSSKILL_HOME/scripts/...>
【文档根目录】<绝对路径>
【项目大脑】<PROJECT_BRAIN.md 路径；没有写"缺失">
【本次任务】T-xxx / CR-xxx / R-xxx（版本）
【上一轮反馈】无 / 评审报告路径 + 返工项编号
【授权】用户已确认 G1（或 G2/G3），可直接开工
【文档就绪】check-docs --gate g1 的退出码 + 关键输出（Doc 贴；Dev 必须自己复跑）
【验证环境】<启动命令、端口、临时数据目录、浏览器路径等>
【阅读预算】S ≤ 5 / M ≤ 15 / L 分阶段（超出需说明）
【报告】<落盘路径>
```

一次只派发一个阶段；等该角色返回并核对报告后，再进入下一阶段。返工时把报告路径与编号原样传回，不要重写证据链。同一 CR 内 Dev/Steward 复用同一会话；Review 跨 CR 新建会话。

## 4. 主会话（Doc）只做这些

- 维护文档：需求卡、R/AC/T、设计、影响分析、追溯矩阵、决策、STATUS。
- 维护 `DOCS_CONTRACT.md` 的路径登记：新增路径必须先说明用途、重叠与维护者，获用户批准后再创建。
- G1 前运行 `$LOSSKILL_HOME/scripts/check-docs.sh <文档根目录> --gate g1`，把退出码与关键行写进 G1 摘要；非 0 不得派发。
- G3 通过且 Review 已记 A1 后，按 §2.1 执行本次 commit；提交信息先经用户确认。主会话只做提交，不改业务代码。
- 核对执行角色的报告是否包含：变更清单、逐条 AC 证据、命令输出、回归、发布/回滚、偏差、交接块。
- 更新 `STATUS.md` 的当前 CR、门禁、任务状态、阻塞、下一步、报告链接。
- 如实转达结论；不替执行角色补充未验证的结论。
- `LosAngelous:` / `LOS:` 用户注释原样保留。

## 5. 主会话禁止

- ❌ 写业务代码、改测试、改配置（交给 Dev）。
- ❌ 做代码评审或给实现打分（交给 Review）。
- ❌ 宣称评审/总审通过（交给 Review / Meta）。
- ❌ 用自己的实现替代子代理，或让子代理“按报告随便修”。
- ❌ 在 G1 未确认时把任务交给 Dev。
- ❌ 在 `check-docs --gate g1` 非 0 或 `STATUS.md` 未写 `G1 已确认：是` 时派发 Dev。
- ❌ 允许任何 Agent 在文档根目录下新建未登记的文件/目录，或自创报告命名。
- ❌ 修改需求/AC 来迁就实现。

## 6. 报告与交接

每份报告（包括主会话的交付报告）结尾必须有：

- 交给谁、依据哪个门禁/结论、携带哪些材料；
- 一段可直接复制发送给下一位 Agent 的 Prompt（真实路径、ID、版本；未知项写“待确认”）；
- 「上下文增量」：触及模块、不变量/契约变化、测试变化、大脑需要更新的节、发现的过期信息。
- 「工作日志」：`LOG-ID`（已用 `$LOSSKILL_HOME/scripts/finish-report.sh` 追加；AUTH 条目同一脚本写入）。

报告落盘：`<文档根目录>/reports/<角色>-<YYYY-MM-DD>-<范围>.md`。

## 7. 上下文控制

完整协议见 `references/05-context-protocol.md`，要点：

- 开工第 0 步读 `PROJECT_BRAIN.md`，只读任务相关模块卡；代码只读改动面 + 调用方 + 测试。
- 遵守阅读预算（S ≤ 5、M ≤ 15、L 分阶段），超出需在报告中说明。
- 每份报告带「上下文增量」；Steward 在 G2.5 合并回大脑。
- 同一 CR 内 Dev/Steward 复用会话；Review 跨 CR 新建，返工可复用。
- 执行角色只返回摘要与报告路径；大段细节落盘，不塞回主会话。
- 主会话只保留：当前门禁、任务状态、阻塞、下一步、报告路径。
- 授权按 `references/06-authorization.md`：A0/A1 在信封内自动执行并记账；A2 由 Steward；A3 回用户。
