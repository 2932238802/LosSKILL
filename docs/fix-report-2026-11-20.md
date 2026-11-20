# LosSKILL 修复报告 — 2026-11-20

> 依据：同日审阅报告（`D:\Temp\LosSKILL-review-2026-11-20.md`，97 行，P0×1 / P1×18 / P2×14）。
> 范围：dev-workflow 协议与脚本、leverage-protocol 索引脚本、game-design / sandra-sales 卡片重复、huashu-nuwa 版本与示例、效率类改造。
> 基线：`main` = `29d94bc`（领先 `origin/main` 11 个提交）；`./scripts/validate.sh` 当前 0 ERROR。
> 原则：只改证据确凿的项；语义存疑项（D2/D3、E3）先标「待复核」，不凭推断改内容。

## 0. 总表

| ID | 级别 | 问题 | 证据 | 改法 | 预估 |
|---|---|---|---|---|---|
| F-01 | P0 | `query` 无命中崩溃 | `capability_index.py:317` | `top` 判空，输出「没有匹配」并 exit 0 | 5 min |
| F-02 | P1 | `needs-review.md` 死链（4 处） | `sandra-sales/references/glossary.md:28` 等 | 新建汇总页，把现有段落挪进去 | 15 min |
| F-03 | P1 | A1 批准链死结 | `06-authorization.md:16,52` vs `SKILL.md:76` | 把「写文档」移出 A1（改 A0+登记） | 10 min |
| F-04 | P1 | commit 时机矛盾 | `06:158` vs `SKILL.md:84` | 统一为「G3 通过后 commit」 | 5 min |
| F-05 | P1 | A2 委托未实现 | `06:38` vs `finish-report.sh:205` | 脚本允许 review 记 A2（受信封开关约束） | 20 min |
| F-06 | P1 | WORKLOG 回填/去重失效 | `finish-report.sh:302-306` | 回填改为锚定 meta 块/首个标题，失败即 WARN | 20 min |
| F-07 | P1 | 台账落点不一致 | `SKILL.md:36`、`06:59` vs `bootstrap-project.sh:115-124` | 统一为「项目根」，协议措辞改掉 | 10 min |
| F-08 | P1 | 文档命令路径错 | `leverage-protocol/SKILL.md:152` | 改为 `python3 skills/leverage-protocol/scripts/…` | 2 min |
| F-09 | P1 | 缓存不看 roots | `capability_index.py:221-238`（roots 已在 `build_index:196` 存下，`stale()` 没用） | `stale()` 先比 roots 再比 mtime | 10 min |
| F-10 | P1 | 「不适用于」被当正向信号 | `capability_index.py:182`（`all_text` 含整段 description）、`:259` 打分 | 分词前剥离「不用于/不适用于/不涉及…」从句 | 20 min |
| F-11 | P1 | 14 对卡片与独立 skill 逐字重复 | game-design 8 对、sandra-sales 7 对 | 卡片改 3 行指针（保留引用价值，去掉正文） | 40 min |
| F-12 | P1 | `capability-id` 7/7 不一致 | `game-design-*/SKILL.md:9` vs `capability-index.md` | 批量对齐 id | 15 min |
| F-13 | P1 | `ceNN` 编号无对照表 | 7 处 SKILL + 6 处卡片 | 新增 `references/failure-modes.md` 对照表 | 30 min |
| F-14 | P1 | huashu 版本号/更新检查/示例 | `SKILL.md:14,229-233`、`package.json:3` | 版本对齐 + 更新查 nuwa-skill 仓库 + 示例降级标注 | 20 min |
| F-15 | P2 | 一批小项（见 §4） | 见各条 | 批量修 | 40 min |
| F-16 | 效率 | 没有 pre-commit、没有脚本自测 | `.git/hooks/pre-commit` 不存在 | 装 hook + 新增 `scripts/selftest.sh` + CI 接入 | 40 min |
| F-17 | 效率 | 22 个 description 合计 9.6KB，每次会话注入 | 最长 6 个 500–900 字 | 压到 1–2 句 | 25 min |
| F-18 | 效率 | 每门禁都产出「报告+LOG+AUTH」 | `SKILL.md:50-54`、`06` | S 级免报告，只记一行 | 待拍板 |

合计约 **5.5 小时**；其中 **B1 批（F-01/02/06/08/16）约 1.5 小时**，其余可分批。

## 1. 批次与顺序

| 批次 | 内容 | 前置 | 完成后 |
|---|---|---|---|
| **B1 立即**（今天） | F-01、F-02、F-06、F-08、F-16 | 无 | 跑 `selftest.sh` + `validate.sh`，全绿 |
| **B2 协议一致性** | F-03、F-04、F-05、F-07 | 需拍板「A1 是否包含写文档」 | 用沙箱跑一遍 G2→G3→commit 流程 |
| **B3 内容去重** | F-11、F-12、F-13、F-14、F-17 | 需拍板「卡片保留还是删」 | validate + 抽样读 3 对卡片 |
| **B4 收尾** | F-15、F-18 | F-18 需拍板 | 全量回归 |

## 2. B1 逐项方案

### F-01 `query` 判空（P0）

- 位置：`skills/leverage-protocol/scripts/capability_index.py:313-317`。`if top and top[0][0] >= …` 在 `top` 为空时落到 `else`，而 `else` 里又直接取 `top[0][0]`，于是 `IndexError`。
- 改法：

```python
    if not confident:
        if top and top[0][0] >= args.min_score:
            print("分数过线但证据不足（只命中一个泛词，或缺少第二个区分性词）。不要仅凭它硬套；先说明将直接处理。")
        elif top:
            print(f"没有足够匹配的已装 Skill（最高分 {top[0][0]:.2f} < {args.min_score}）。不要硬套；先说明将直接处理。")
        else:
            print("没有匹配的已装 Skill。不要硬套；先说明将直接处理。")
        print("最接近的候选（仅供参考）：")
```

- 验收：`python3 skills/leverage-protocol/scripts/capability_index.py query "qqqzzz"; echo $?` → 打印「没有匹配」、不再抛 `IndexError`；退出码保持 1（脚本现有语义：无匹配=非 0，`--allow-empty` 时=0）。若要改成 0，需同时调整 :323 的返回值，并同步 `SKILL.md` 说明。

### F-02 死链修复（P1）

- 现状：`needs-review.md` 全仓 0 个文件，被 4 处引用（`glossary.md:28`、`capabilities/low-threat-dialogue.md:70`、`capabilities/sandra-sales-upfront-contract.md:67`、`capabilities/sandra-sales-demand-gen.md:31`）。
- 改法：新建 `skills/sandra-sales/references/needs-review.md`，把 4 处括号里已有的「作者盲点 / 口径瑕疵」原句搬进去成条目；引用处保留指针。**不新增任何未在原文出现的断言。**
- 验收：`grep -rn "needs-review" skills/sandra-sales | awk -F: '{print $1}' | sort -u` 里每处都能找到对应文件；`validate.sh` 仍 0 ERROR。

### F-06 WORKLOG 回填（P1）

- 现状：`finish-report.sh:302-306` 只有匹配 `^## .*报告[[:space:]]*$` 才插入日志行；标题带后缀（`## Dev Agent 交付报告 — T-099`）时静默不写，重跑同一报告会重复追加（实测 2 条 `T-099`）。
- 改法（二选一，推荐 a）：
  - a) 锚点改为「meta 块结束后的第一个空行」：找不到 `<-- report-meta` 时再回退到首个 `## ` 标题后插入；
  - b) 保留现锚点，但插入失败时 `echo "[warn] 未找到日志插入点，请手工补 - 工作日志：行" >&2`，并且**去重键改用 (role, gate, cr, task, action) 哈希**，不依赖报告回填。
- 验收：沙箱里对 `## Dev Agent 交付报告 — T-099` 跑两次 `finish-report.sh`，`WORKLOG.md` 中 `T-099` 行数 = 1；报告里出现 `- 工作日志：LOG-*`。

### F-08 路径修正（P1）

- 位置：`skills/leverage-protocol/SKILL.md:152`（`SKILLS.md:222` 同步）
- 改法：`python3 skills/leverage-protocol/scripts/capability_index.py plan "…"`（从仓库根可用）。
- 验收：仓库根照抄命令，退出码 0（当前 `can't open file`）。

### F-16 自动化（效率）

- `./scripts/install-git-hooks.sh` 启用 `.githooks/pre-commit`（30 秒）。
- 新增 `scripts/selftest.sh`：把本次沙箱用例固化——worklog 追加/去重、finish-report 回填与幂等、A3 拒绝、bootstrap 中文 slug、`capability_index query` 空结果。
- `.github/workflows/validate.yml` 增加一步 `./scripts/selftest.sh`。
- 验收：`./scripts/selftest.sh` 退出 0；故意改坏 `worklog.sh` 的去重逻辑时该脚本能报红。

## 3. B2 协议项

| ID | 冲突原文 | 建议统一为 |
|---|---|---|
| F-03 | A1 含「写文档」，但 Review 在 G1 未入场 | A1 只含「代码/配置/提交」；文档与报告记为 A0 并登记，Review 在 G3 抽查 |
| F-04 | `06:158`「G2 内 commit 前请求 A1」 vs `SKILL.md:84`「G3 后提交」 | 统一为「G3 通过后 commit；Review 在 G3 报告里记 A1」 |
| F-05 | `06:38` 允许 `delegate_a2_to_review: true`，脚本拒绝 Review 记 A2 | 脚本允许 review + 信封开关为 true 时记 A2；否则维持报错 |
| F-07 | 文档根目录 vs 项目根 | 统一为项目根；文档根≠项目根时在信封 `ledger_path` 覆盖 |

验收方式：沙箱项目里走一遍「G2 Dev 报告 → G3 Review 报告（含 A1）→ finish-report → commit」，四本文件（报告/WORKLOG/AUTHORIZATIONS/STATUS）内容自洽，脚本无报错。

## 4. P2 批量清单（F-15）

1. `worklog.sh --time` 生成 `LOG-20261120100000`（无连字符）→ 统一 `LOG-YYYYMMDD-HHMMSS`。
2. `usage()` 硬编码 `sed -n '2,37p'` / `'2,26p'` → 改用 `awk '/^#/' | head` 或标记区间。
3. `validate.sh:66-68` 边界词只 WARN → 若 SKILLS.md/AGENTS 要求"必须含"，升 ERROR（或改文档为"建议"）。
4. `bootstrap-project.sh:61-64` 中文名 slug 退化为 `project` → 用拼音/`--slug` 强制，或拒绝非 ASCII 并提示。
5. `finish-report.sh:191-194` 无 python3 时写绝对链接 → 用 `realpath --relative-to` 兜底，或强制拒绝绝对路径。
6. `05-context-protocol.md:134`「同时写 WORKLOG 与 AUTH」→ 改为「WORKLOG 必写，AUTH 仅在 auth_level 非 - 时写」。
7. `06-authorization.md:162` 把 G4 说成"审计台账" → 与 `SKILL.md:72` 对齐为「全链路总审/UAT，台账审计是其一部分」。
8. `sandra-sales-qualify` 结论档位三处不一致 → 统一为「继续/调整/结案」。
9. `game-design/SKILL.md:38-44`「先读本文件再加载卡」与「已安装优先用独立 Skill」冲突 → 删前一句。
10. `dsh-cockpit/references/local-paths.md` 全篇 `D:\` 绝对路径 → 顶部加「本机专用，换盘需改」提示（个人备份类，不强行改相对）。
11. `dsh-cockpit` 成本口径（$0.05 vs $0.06/$0.09、+40% vs +50%）→ 以 `local-paths.md` 实测表为准，SKILL 改引用。
12. `rust-atomics-and-locks/SKILL.md:4` 补「不用于其他语言（C/C++/Go）并发」。
13. `leverage-protocol/references/projects/theseus.md:3`「最后验证 2026-11-19」与全表「未执行」矛盾 → 改「来源核对：2026-11-19（未执行）」。
14. 删 `skills/leverage-protocol/scripts/__pycache__/`。
15. 可选：把 D2/D3（销售能力边界互相推）标「待复核」后再改，不凭推断改话术。

## 5. 统一验收命令

```bash
cd ~/LosAngelous/LosSKILL
./scripts/validate.sh                       # 期望 0 ERROR / 0 WARN
./scripts/selftest.sh                       # 期望 exit 0（F-16 新增）
python3 skills/leverage-protocol/scripts/capability_index.py query qqqzzz   # 期望提示 + exit 0
python3 skills/leverage-protocol/scripts/capability_index.py plan "给游戏调数值平衡" | head -3  # 期望 mechanics/数值相关在前
bash -n scripts/*.sh setup.sh               # 语法
git status --short                          # 只应出现本次改动的文件
```

## 6. 回滚

- 代码/脚本：`git checkout -- <file>`；新增文件（`references/needs-review.md`、`scripts/selftest.sh`、`failure-modes.md`）直接删除。
- 协议文档：同上。
- 卡片去重（F-11）涉及 14 个文件，建议单独一个 commit，便于整体 `git revert`。
- 不涉及数据迁移，无不可逆操作。

## 7. 明确不做

- 不重写四角色流程本身（是否过重见 F-18，需拍板）。
- 不改 `sandra-sales` / `game-design` 的正文语义（除死链、编号、档位这类可核对的机械修正）。
- 不碰 `books/`、`dist/`、`scripts/vesta-e2e/`、`*.lnk` 等本地产物。
- 不主动 `push`；每个批次独立 commit，信息用 `fix(scope):` 中文正文。

## 8. 待拍板

1. **F-11**：卡片是「保留为指针」还是「直接删除、只留独立 skill」？
2. **F-18**：S 级小改是否免掉「报告+LOG+AUTH」三件套？
3. **F-03**：A1 是否保留「写文档」？（影响 Doc 在 G1 的记账方式）
