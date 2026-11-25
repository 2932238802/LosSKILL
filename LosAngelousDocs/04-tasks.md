# 04 — 任务（CR-001～CR-002）

> 维护者：Doc Agent ｜ 最近更新：2026-11-20 ｜ 状态：CR-002 G4 通过；收尾提交待授权

## G4 结论（CR-002）

- 2026-11-20：通过，0 阻断；18/18 AC 与 UAT 由 Meta 独立复现；AUTH-006 的 CI 变更由 Meta 追认 A2，AUTH-005 scope 以 G4 报告交叉覆盖。
- 后续：F-5～F-10（P3）转后续 CR；文档收尾 F-1～F-4 已完成。

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
- **阻塞原因**：无；2026-11-20 完成并提交 `27d08f3`，证据见 `LosAngelousDocs/reports/dev-2026-11-20-T-001.md`。

## T-002 剥离否定边界从句（状态：DONE）

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
- **阻塞原因**：无；2026-11-20 G2 完成，证据见 `LosAngelousDocs/reports/dev-2026-11-20-T-002.md`（未提交，待 G3）。
- **G3 结论**：有条件通过（`AUTH-20261120-002`）；P1 缓存版本化 → CR-005；P2 分号枚举残留 → 候选 CR-006；P3 `not\s+for` 词边界已记录。提交：`f149b96`（默认缓存已重建）。

## T-003 缓存感知 roots（状态：DONE）

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
- **G2 结论**：完成；证据见 `LosAngelousDocs/reports/dev-2026-11-20-T-003.md`（未提交，待 G3）。
- **G3 结论**：通过（`AUTH-20261120-003`）；P3-1 相对 roots 相等性依赖比较时 CWD（设计 §3 规定，非本任务引入）；P3-2 `OSError` 回退为防御性冗余。提交：`37774e2`。

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
| AC-002-1 | `query "书摘 读后感" --json` | T-002 | 已通过 |
| AC-002-2 | `plan "给游戏调数值平衡"` | T-002 | 已通过 |
| AC-002-3 | `query "机制平衡"` | T-002 | 已通过 |
| AC-002-4 | 临时 roots 夹具 | T-002 | 已通过 |
| AC-003-1 | roots A→B 缓存复现 | T-003 | 已通过 |
| AC-003-2 | 连续查询 `generated_at` | T-003 | 已通过 |
| AC-003-3 | roots 顺序变化 | T-003 | 已通过 |
| AC-004-1 | 带后缀标题连跑两次，WORKLOG 1 行 + 回填 1 条 | T-004 | 已通过 |
| AC-004-2 | 无后缀标题连跑两次，1 行 / 1 条 | T-004 | 已通过 |
| AC-004-3 | 无匹配标题 → WARN，WORKLOG 1 行 | T-004 | 已通过 |
| AC-004-4 | 不同报告不误去重 | T-004 | 已通过 |
| AC-005-1 | `--time` → `LOG-YYYYMMDD-HHMMSS` | T-005 | 已通过 |
| AC-005-2 | 默认时间格式不变 | T-005 | 已通过 |
| AC-005-3 | 同一秒 `-2` 后缀 | T-005 | 已通过 |
| AC-006-1 | `-h` 含关键选项 | T-005 | 已通过 |
| AC-006-2 | 头部插行后 `-h` 仍完整 | T-005 | 已通过 |
| AC-006-3 | `bash -n` 通过 | T-005 | 已通过 |
| AC-007-1 | 有 python3 → 相对链接 | T-005 | 已通过 |
| AC-007-2 | 无 python3 → realpath 相对链接 | T-005 | 已通过 |
| AC-007-3 | 两者都无 → exit 2 | T-005 | 已通过 |
| AC-008-1 | `selftest.sh` exit 0 | T-006 | 已通过 |
| AC-008-2 | 故障注入后 selftest 失败 | T-006 | 已通过 |
| AC-008-3 | CI 调用 selftest | T-006 | 已通过 |
| AC-008-4 | 覆盖 CR-002 用例 | T-006 | 已通过 |
| AC-008-5 | 不污染仓库 | T-006 | 已通过 |

## CR-002 任务

### T-004 finish-report 回填与幂等（状态：DONE（G3 有条件通过））

- **来源**：CR-002 / R-004（v1）
- **关联需求**：AC-004-1～4
- **目标**：带后缀标题也能回填；同一报告重复运行只产生一条 WORKLOG 与一条回填。
- **涉及文件/模块**：`scripts/finish-report.sh`、`scripts/worklog.sh`
- **前置依赖**：G1 确认（已完成）
- **DoR**：AC 可测；设计 §6.1/6.2 已定；环境可用
- **验证方式**：沙箱报告连跑两次计数；无匹配标题 WARN；不同报告不误去重
- **回归范围**：现有报告回填、AUTH 写入、WORKLOG 格式
- **发布/回滚**：无发布；脚本单文件回滚
- **风险**：中；幂等键过宽会误跳过
- **规模**：M
- **阻塞原因**：G3 不通过（2 P1），返工 R-1/R-2；评审报告 `LosAngelousDocs/reports/review-2026-11-20-T-004.md`。
- **G3 结论**：不通过（2026-11-20，`LOG-20261120-150444`，无 AUTH）。R-1：WORKLOG 写入失败被静默吞掉；R-2：去重键缺 role/gate/cr/task，与 D-007 / 设计 §6.2 不符。
- **返工**：R-1/R-2 已修，报告 `LosAngelousDocs/reports/dev-2026-11-20-T-004-r2.md`（`LOG-20261120-150702`）；待 G3 复审。
- **G3 复审**：有条件通过（2026-11-20，`AUTH-20261120-004`，`LOG-20261120-151315`）；无 P0/P1；P2 `--force` 文案、P3 dry-run/meta 未闭合等转 T-005/T-006。提交：`4f341e3`。
- **完成说明**：`finish-report.sh` 回填锚点改为「meta 结束后的第一个空行 → 首个 `## ` 标题 → WARN 跳过」；`worklog.sh` 写前按 D-007 全键（report + role + gate + cr + task + action）去重。4 条 AC 均在 mktemp 沙箱复现通过；`validate.sh` 0 ERROR，`bash -n scripts/*.sh setup.sh` 通过。
- **G3 返工（2026-11-20）**：R-1（`worklog.sh` 失败被 `set -e` 吞掉、临时文件残留）与 R-2（去重键缺 role/gate/cr/task）已修复；失败路径回显 stderr 并以原退出码退出，去重按全键匹配。证据见 `LosAngelousDocs/reports/dev-2026-11-20-T-004-r2.md`（未提交，待 G3）。P2 `--force` 文案与 P3 项记录在报告中，留 T-005 / T-006。

### T-005 worklog 与 usage 小修（状态：DONE（G3 通过））

- **来源**：CR-002 / R-005、R-006、R-007（v1）
- **关联需求**：AC-005-1～3、AC-006-1～3、AC-007-1～3
- **目标**：统一 `--time` 格式、去掉 usage 硬编码、无 python3 时不写绝对链接。
- **涉及文件/模块**：`scripts/worklog.sh`、`scripts/finish-report.sh`、`scripts/install-*.sh`、`setup.sh`、各脚本 `usage()`
- **前置依赖**：G1 确认
- **DoR**：AC 可测；设计 §6.3–6.5 已定；环境可用
- **验证方式**：三种时间格式；`-h` 完整性（含 install-* 与 setup.sh）；PATH 模拟无 python3
- **回归范围**：worklog 默认路径、finish-report 正常回填
- **发布/回滚**：无发布；脚本回滚
- **风险**：低
- **规模**：M
- **阻塞原因**：无
- **P2 返工**：用户已批准信封扩展 `setup.sh`；补齐 `install-claude-config.sh`、`install-git-hooks.sh`、`install-vscode-config.sh`、`setup.sh` 的 usage，去掉固定行号。
- **完成说明**（2026-11-20，G2）：`worklog.sh --time` 取 14 位数字统一输出 `LOG-YYYYMMDD-HHMMSS`，不足 14 位 exit 2；5 个脚本的 `usage()` 改为 awk 截取开头连续注释块（去掉固定行号）；`finish-report.sh` `--force` 帮助文案与实际行为对齐；无 python3 时用 `realpath --relative-to` 回退，两者都无则 exit 2 且不写链接。证据见 `LosAngelousDocs/reports/dev-2026-11-20-T-005.md`（未提交，待 G3）。
- **G3 结论**：有条件通过（2026-11-20，`AUTH-20261120-005`，`LOG-20261120-152748`）；无 P0/P1。P2：R-006「所有脚本」只覆盖 5/8——`install-claude-config.sh`、`install-git-hooks.sh`、`install-vscode-config.sh` 与根目录 `setup.sh` 仍用固定行号；P3：`--force` 重跑 AUTH 追加、`--time` 帮助说明、T-005 在 G3 前标 DONE。
- **G3 复审**：通过（2026-11-20，`AUTH-20261120-005` 沿用，`LOG-20261120-154044`）；4 个脚本已补齐；P3 AUTH scope 未含返工文件，交 G4 记录。提交：`beac653`。
- **P2 返工完成**（2026-11-20，G2 r2）：4 个脚本（`install-claude-config.sh`、`install-git-hooks.sh`、`install-vscode-config.sh`、`setup.sh`）改用与 T-005 相同的 awk `usage()`；头部插入 1 行/5 行后 `-h` 均输出到最后一个选项，`setup.sh -h` 不再输出 `set`/`cd` 代码行。证据见 `LosAngelousDocs/reports/dev-2026-11-20-T-005-r2.md`（未提交，待 G3 复审）。

### T-006 selftest 与 CI（状态：DONE（G3 通过））

- **来源**：CR-002 / R-008（v1）
- **关联需求**：AC-008-1～5
- **目标**：新增 `scripts/selftest.sh`，覆盖 CR-002 行为并接入 CI。
- **涉及文件/模块**：`scripts/selftest.sh`（新）、`.github/workflows/validate.yml`
- **前置依赖**：T-004、T-005
- **DoR**：AC 可测；设计 §6.6 已定；环境可用
- **验证方式**：`./scripts/selftest.sh`；故障注入；CI 语法检查
- **回归范围**：`validate.sh`、全部脚本 `bash -n`
- **发布/回滚**：无发布；删除新增文件即可
- **风险**：中；需保证沙箱不污染仓库
- **规模**：M
- **阻塞原因**：无（G1 已确认；T-004/T-005 已提交；G2 开发完成）。
- **完成说明**（2026-11-20，G2）：新增 `scripts/selftest.sh`（13 个用例，mktemp 沙箱 + trap 清理，支持 `SELFTEST_SRC_DIR` 覆盖以便故障注入）；`.github/workflows/validate.yml` 在 `validate.sh` 后新增 `Run script selftest` 步骤。`./scripts/selftest.sh` → PASS=13 FAIL=0，exit 0；篡改去重后 exit 1 且对应用例 FAIL。`validate.sh` 0 ERROR，`bash -n scripts/*.sh setup.sh` 通过，YAML 可解析。证据见 `LosAngelousDocs/reports/dev-2026-11-20-T-006.md`（未提交，待 G3）。
- **G3 结论**：通过（2026-11-20，`AUTH-20261120-006`，`LOG-20261120-155125`）；无 P0/P1/P2。P3：`make_bin` 白名单缺 `head`；头部注释称 9 脚本插行但仅 finish-report 验证；无 python3/realpath 时用例 SKIP 但整体 exit 0。提交：`4573bbd`。

## CR-002 任务顺序

`T-004 → T-005 → T-006`

- T-004 是证据链主缺陷，优先。
- T-005 与 T-004 同文件，串行。
- T-006 覆盖前两者，最后做。
