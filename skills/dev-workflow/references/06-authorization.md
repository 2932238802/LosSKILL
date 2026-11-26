# 授权协议（委托信封）

目标：**用户只批准一次「范围信封」，信封内的动作由 Agent 执行并记账；越界和危险操作仍然回到人。**

先明确三条边界：

1. **Agent 不能替用户点 Claude Code 的权限弹窗。** 工具权限由宿主（harness）强制，不在 Prompt 里。
2. **Agent 不能批准自己的结论。** Dev 不在 G2 提交；Review 不批自己的 G3 结论。
3. **A3 永不委托。** 数据迁移、生产发布、密钥、权限、不可逆删除，只能由人确认。

## 1. 授权级别（唯一口径）

| 级别 | 动作 | 授权来源 | 批准人 | 记账位置 |
|---|---|---|---|---|
| **A0 只读/验证** | 读代码、跑测试、lint、build、写临时目录 | 信封 | Agent 自主 | WORKLOG（仅失败或异常时记） |
| **A1w 写入** | 改业务代码、测试、文档、`PROJECT_BRAIN.md` 增量（**不 commit**） | **G1 信封（用户一次批准）** | 用户（信封）；执行者在已批准路径内自记 | WORKLOG（AUTH 列写 `ENV-<policy>` 或 `-`） |
| **A1c 提交** | 在信封分支上 `git commit` | 信封 + G3 结论（通过 / 有条件通过） | **Review** | `AUTHORIZATIONS.md` 一条 `AUTH-*`，`auth_level: A1c` |
| **A2 共享状态** | push、PR、合并 main、依赖清单 / lockfile、构建 / CI 配置 | 信封 | Steward/Meta（可委托 Review 批准低风险 A2） | `AUTHORIZATIONS.md` `AUTH-*`，`auth_level: A2` |
| **A3 高风险/不可逆** | 生产部署、删库、force push、改鉴权/密钥、外部付费、批量删除 | — | 用户本人 | `AUTH-*`，用户确认后人工记，脚本不代记 |

三条硬解释：

- **A1w 不是 Review 批准的。** 批准发生在 G1：用户对信封里的路径与命令点头。执行者只负责「不越界」并在 WORKLOG 留一行；Review 在 G3 检查是否越界，但**不补批 A1w**。
- **A1c 才是 Review 批准的。** Review 审过工作区、给出通过 / 有条件通过后，才批准 commit 并写 AUTH。
- **A2 优先于 A1w/A1c。** 只要动作是依赖、lockfile、构建 / CI 配置，一律 A2，即使改动很小（AUTH-006 的教训）。

拿不准时**升级一级**，不要降级。

### 1.1 风险分类参考

| 改动 | 默认级别 |
|---|---|
| `LosAngelousDocs/**`、`*.md`、注释、文案 | A1w |
| `src/**`、`tests/**`（在 `allowed_paths` 内） | A1w |
| `PROJECT_BRAIN.md`、`brain/modules/**` | A1w（只有 Steward 合并增量） |
| feature 分支 commit | A1c |
| 依赖清单 / lockfile（`package.json`、`Cargo.toml`、`requirements.txt`） | A2 |
| 构建 / CI 配置（`.github/workflows/**`、`Dockerfile`、构建脚本） | A2 |
| push、创建 PR、合并 main | A2 |
| `migrations/**`、schema、种子数据 | A3（或 A2 + 人工确认） |
| `auth/**`、权限、角色、鉴权中间件 | A3 |
| `deploy/**`、`.env`、密钥、生产配置 | A3 |
| `rm -rf`、`git push --force`、删库、批量删除 | A3 |

### 1.2 A2 是否可以委托给 Review

默认 A2 由 Steward 批准。如果用户在信封里显式写 `delegate_a2_to_review: true`，Review 可以批准**低风险 A2**，但必须同时满足：

- G3 已由 Steward 或用户接受（Review 不能自批 G3）；
- 只做：push 当前 feature 分支、创建 PR、合并到 main；
- 不碰 `forbidden`、依赖、鉴权、数据模型、`deploy/`；
- 验证命令与回归全绿，且报告里有证据。

高风险 A2 与所有 A3 仍然回到 Steward/用户。

## 2. 角色

| 角色 | 授权职责 |
|---|---|
| 用户 | 在 G1 批准「范围信封」；A3 决策；记录（或委托 Steward 记录）G3 接受；可随时撤销 |
| Doc | 把信封写进 `AUTHORIZATIONS.md`；维护策略变更记录；不批准执行动作 |
| Dev | 在信封内做 A0/A1w；**不得自批，不得 commit**；越界时停下等待 |
| Review | 批准并记录 A1c；核对 A2 证据；**不得批准自己的 G3 结论**；检查 A1w 是否越界 |
| Steward/Meta | 批准 A2；记录 G3 接受（或由用户记）；执行 G2.5/G3.5 的 A1w 并记 WORKLOG；G4 审计台账完整性；A3 一律上报用户 |

## 3. 范围信封（G1 批准一次）

放在 `AUTHORIZATIONS.md` 顶部：

```yaml
policy: CR-xxx
granted_by: user
granted_at: 2026-11-20
expires: 2026-11-27        # 到期自动失效
branch: feat/xxx           # A1c/A2 只允许在该分支或基于它
allowed_paths:             # A1w/A1c 允许改动的路径
  - src/
  - tests/
allowed_commands:          # 允许自动执行的高频命令
  - ./scripts/validate.sh
  - cargo test
max_commits: 5
max_parallel: 3            # 同时进行写操作的 Agent 上限（见 07-speed.md）
delegate_a2_to_review: false   # true 时允许 Review 批准低风险 A2（见 1.2）
forbidden:                 # 显式禁止，优先级最高
  - deploy/
  - .env
  - migrations/
escalate_when:
  - 新增依赖
  - 修改鉴权/权限
  - 改动数据模型
```

信封之外的动作一律停下，给用户一屏决策：要做什么、风险、替代方案、回滚方式。

### 3.1 记录根（台账与日志放哪）

- **默认（新项目）**：项目根 `AUTHORIZATIONS.md` 与 `WORKLOG.md`。`bootstrap-project.sh` 与 `templates/project/` 都按这个生成。
- **存量兼容**：若项目根没有、但 `<文档根目录>/` 下有这两个文件，也可接受；在 `STATUS.md` 写 `记录根：文档根（legacy）`。
- **两处都有时以项目根为准**，文档根那份标记为过期，不再追加。
- 工具统一用 `--project-root <项目根>`（脚本会据此解析默认路径）；显式 `--worklog` / `--ledger` 优先级最高。

## 4. 台账（append-only，只记 A1c/A2/A3）

台账**不记录 A1w**：A1w 由 G1 信封授权，记在 WORKLOG 即可。A1c/A2/A3 每次记一条，不要删改旧条目：

```markdown
## AUTH-20261120-001

- 时间：2026-11-20 14:05
- CR/T：CR-004 / T-012
- 动作：提交 feat/xxx 的 3 个文件
- 级别：A1c
- 策略条款：P-02（allowed_paths、max_commits）
- 证据：`./scripts/validate.sh` 通过；`git diff --stat` 3 files
- 批准：review-agent
- 范围：branch=feat/xxx，commit=待生成
- 有效期：随 CR 结束
- 撤销：否
- 幂等键：CR-004:T-012:提交 feature 分支:A1c
```

规则：

- 一条授权对应一个可复述的动作，不写「已授权本次开发」。
- 证据必须能定位：命令输出、测试名、diff、报告路径。
- **commit 生成后回填真实 hash**：运行
  `$LOSSKILL_HOME/scripts/finish-report.sh --backfill --auth AUTH-YYYYMMDD-NNN --commit <hash> [--ledger <路径>]`
  它只在对应条目追加 `- Commit：<hash>`，不改旧行。
- 撤销时追加 `- 撤销：是（时间 / 原因 / 批准人）`，不要删除原条目。
- AUTH ID 单调递增，不跳号、不复用；G4 抽查最近 10 条与 commit 是否对得上。
- 推荐用 `$LOSSKILL_HOME/scripts/finish-report.sh --report <报告>` 自动写入：它校验 A1c 默认=Review（Dev 自行提交的例外允许 Steward/Meta）、A2=Steward，并用「幂等键」防止重复追加。

### 4.1 G3 接受（不是授权，不占 AUTH）

Review 给出 G3 结论后，**接受**由 Steward 或用户记录；它不是 A1c/A2/A3，不写台账：

```bash
$LOSSKILL_HOME/scripts/worklog.sh --file <记录根>/WORKLOG.md \
  --role steward --gate G3 --cr CR-xxx --task T-xxx \
  --action "接受 G3 结论：通过（Review 报告 <路径>）" \
  --report <review 报告路径> --status 接受
```

- 用户本人在对话里明确说「接受」也可以；由 Steward 补记一行，`role=user`。
- `check-docs --gate g3` 会检查 WORKLOG 是否有 `G3` 接受行，或 `STATUS.md` 是否写 `G3 已接受：`；缺失给 WARN。

### 4.2 授权请求与决定（短模板）

请求（Dev/Review 提出）：

```markdown
## 授权请求
- 动作：
- 级别：A1w / A1c / A2 / A3
- 策略条款：P-xx
- 证据：命令 / 测试 / diff
- 回滚：
- 请求人：
```

决定（Review/Steward 回复）：

```markdown
## 授权决定
- 决定：批准 / 拒绝 / 升级
- 依据：
- AUTH ID：AUTH-YYYYMMDD-NNN
- 范围与有效期：
```

### 4.3 STATUS.md 授权字段

`<文档根目录>/STATUS.md` 增加：

```markdown
## 授权状态
- 记录根：项目根
- 当前信封：POLICY-CR-xxx
- 提交额度：2 / 5
- 到期：2026-11-27
- 待用户 A3：无
- 最近 AUTH：AUTH-20261120-002
- G3 已接受：是（Steward，2026-11-20）
```

## 5. 门禁怎么走

```text
G0  用户选做/不做
G1  用户批准范围信封 → Doc 写入 AUTHORIZATIONS.md
G2  Dev 在信封内 A1w 开发，**不 commit**，交付工作区改动与变更清单
G2.5 Steward 合并上下文增量（A1w，记 WORKLOG gate=G2.5）
G3  Review 审工作区并给结论；通过/有条件通过后由 Review 记 A1c（commit 授权）
    → 主会话按 A1c 执行 commit，回填真实 hash
    → G3 接受由 Steward 或用户记 WORKLOG（gate=G3, status=接受）
G3.5 Steward 跨模块检查（A1w，记 WORKLOG gate=G3.5；可豁免）
G4  Steward 审计台账；push 等 A2 由 Steward 批准；A3 回到用户
```

例外：用户明确要求 Dev 自行提交时，A1c 改由 Steward 记账（Review 尚未评审，不得自证）；G3 的评审对象即该 commit。

**G2.5 / G3.5 不是授权门**：它们只产生 A1w（写大脑 / 文档增量），不需要 Review 批；但必须各留一行 WORKLOG，否则 G4 记流程缺陷。

## 6. 执行与强制

- **协议层**：Agent 读本文件与 `AUTHORIZATIONS.md`；越界即停。
- **宿主层**：Claude Code 的权限弹窗仍由 harness 控制。想减少弹窗，用项目级 `.claude/settings.local.json` 加窄 allowlist，不要把 `Bash(*)` 放开。示例（按项目裁剪）：

  ```json
  {
    "permissions": {
      "allow": [
        "Bash(./scripts/validate.sh)",
        "Bash(git status)",
        "Bash(git diff:*)",
        "Bash(git add:*)",
        "Bash(git commit:*)"
      ]
    }
  }
  ```

  允许 `git commit` 只减少弹窗，不等于绕过授权：A1c 仍要 Review 记账。不要允许 push / deploy / rm。
- **Hook 层（可选）**：`PreToolUse` hook 可拦截高危命令（`rm -rf`、`git push --force`、`deploy/*`）并要求人工确认或直接拒绝；先上协议与台账，稳定后再加 hook。
- **审计**：G4 检查台账是否覆盖本轮所有 A1c/A2，以及 WORKLOG 是否覆盖 A1w、G2.5、G3.5 与 G3 接受；缺失记为流程缺陷（P1）。

## 7. 撤销与过期

- 用户可随时在 `AUTHORIZATIONS.md` 追加撤销条目，或把 `expires` 改为过去时间。
- CR 结束、分支合并、或超过 `max_commits` 时，信封自动失效。
- 过期后继续动作视为越权；Review/Steward 必须拒绝并在报告中记录。

## 8. 反模式

- ❌ 「这个 Agent 可信，所以全放开」——没有信封就没有边界。
- ❌ 让 Review 补批 A1w——批准在 G1，Review 只检查越界。
- ❌ Review 给自己发 G3 通过并记账——自证。
- ❌ 把 G3 接受写成 AUTH 条目——它不是授权。
- ❌ 台账只写「已授权」，没有范围、证据、批准人。
- ❌ 把 A3 塞进 A2 的批量授权里。
- ❌ 把 CI / 依赖改动记成 A1c——它们是 A2。
- ❌ 用 Agent 的叙述替代真实命令输出。

## 9. 最小落地

如果暂时不想引入台账文件，至少做到：

1. G1 用一句话写清本轮允许改哪些路径、最多几次提交、什么时候到期；
2. 每次 commit 前，由 Review 记一条 A1c；push 前由 Steward 记一条 A2；
3. A3 永远问用户；
4. G2.5 / G3.5 / G3 接受至少在 WORKLOG 各留一行。

完整落地用项目根 `AUTHORIZATIONS.md` 与 `WORKLOG.md`（项目模板已包含）。
