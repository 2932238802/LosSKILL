# SKILLS.md — Skill 索引

> 给 AI 的读取说明：先读本文件。按「触发信号」找到对应 Skill，再只加载该 Skill 的 `SKILL.md`；任务跨域时最多再加载 1 个。没有命中任何一行时，不要硬套，直接说明超出本库范围。

本仓库当前收录 **2 个技能包（16 个 Skill 目录）**：`sandra-sales` 系列（8 个）与 `game-design` 系列（8 个）。

---

## 一、sandra-sales 系列（《桑德拉销售原则》蒸馏）

适用场景：B2B 大额、关系型销售的机会判断、会谈设计、异议处理、谈钱、签约与复盘。
不适用：书摘/读后感/扮演作者、通用营销与投放、法定招标的逐条应答与合规审查、定价策略与折扣授权。

### 1. 独立能力 Skill（可直接单点触发）

| Skill | 何时用（触发信号） | 产出 | 不用于 | 路径 |
|---|---|---|---|---|
| [`sandra-sales-qualify`](skills/sandra-sales-qualify/SKILL.md) | 纠结某个机会要不要继续跟；客户一直「感兴趣」却不推进；想判断是否该放弃某个客户/项目；怀疑在陪标、套信息、当备胎；不确定见没见到真正决策者 | 痛 / 预算 / 决策三柱状态 + 「继续 / 调整 / 结案」结论 | 已进入法定招标流程的项目；「怎么问出痛」（用 pain-diagnosis） | `skills/sandra-sales-qualify/` |
| [`sandra-sales-pain-diagnosis`](skills/sandra-sales-pain-diagnosis/SKILL.md) | 客户说「先看看」「有兴趣但不推进」；方案发出去没回音；要准备诊断式提问；分不清「需求」和「痛」 | 痛的表现 / 原因 / 影响 + 客户是否亲口承认 | 已给定招标规格的技术应答；谈价格（用 money-talk） | `skills/sandra-sales-pain-diagnosis/` |
| [`sandra-sales-upfront-contract`](skills/sandra-sales-upfront-contract/SKILL.md) | 要见重要客户、要设计会谈议程；客户总临时改议程/改参会人；谈完没有结论 | 五要素（目的/时间/客户议题/我方议题/期待结果）+ 犯规约定 | 法定招标流程内的会议；纯售后回访 | `skills/sandra-sales-upfront-contract/` |
| [`sandra-sales-objections`](skills/sandra-sales-objections/SKILL.md) | 客户提价格、交期、功能、案例等具体异议；问题「话里有话」；怀疑在套信息；要提前处理产品短板 | 自造 / 真实 / 烟幕三类分诊 + 拆引信清单 + 应答动作 | 客户一直不表态（用路由包的 considered-no）；法定招标答疑 | `skills/sandra-sales-objections/` |
| [`sandra-sales-money-talk`](skills/sandra-sales-money-talk/SKILL.md) | 要报价；客户说太贵 / 预算不足；销售自己「一谈钱就心虚」 | 谈预算的时机 + 差距出现时的三句话 + 不自我证明规则 | 定价策略与折扣授权；判断价格异议是否为烟幕（用 objections） | `skills/sandra-sales-money-talk/` |
| [`sandra-sales-review`](skills/sandra-sales-review/SKILL.md) | 要复盘这次拜访；团队复盘会流于形式；想知道某次会谈为什么没推进 | 整体 / 模块 / 情景再现 / 底层四层结论 + 最多 3 条下阶段动作 | 尚未发生的拜访规划（用 upfront-contract）；机会去留（用 qualify） | `skills/sandra-sales-review/` |
| [`sandra-sales-demand-gen`](skills/sandra-sales-demand-gen/SKILL.md) | 线索不够、怎么开发客户；年度目标怎么拆到每周；客户分级、转介绍机制、创收时间审计 | ICP + 分级规则 + 转介绍源 + 创收时间占比 + 行为量日历（标注转化率是实测还是假设） | 存量客户经营（用路由包的 account-growth）；单笔机会判断 | `skills/sandra-sales-demand-gen/` |

### 2. 路由入口与参考包

| Skill | 作用 | 何时用 | 路径 |
|---|---|---|---|
| [`sandra-sales`](skills/sandra-sales/SKILL.md) | 13 张能力卡的路由表 + 全书概览 + 术语表 + 决策速查；覆盖下面 6 张**没有独立 Skill** 的能力卡 | 「桑德拉这套方法怎么用」；命中下表中的主题；需要原文引文与背景 | `skills/sandra-sales/` |

路由包内附带的参考文件（按需加载，不必全读）：

| 文件 | 内容 |
|---|---|
| `references/overview.md` | 全书七层骨架、关键判断规则、成书边界与内部张力 |
| `references/cheatsheet.md` | 决策规则速查（不需要原文依据时） |
| `references/glossary.md` | 术语表 |
| `references/capability-index.md` | 完整意图与关键词索引（路由表未覆盖时先查这里） |
| `references/capabilities/*.md` | 13 张能力卡原文与背景（见下） |

### 3. 13 张能力卡对照

| # | 能力卡 | 主题 | 独立 Skill？ |
|---|---|---|---|
| 1 | `sandra-sales-qualify.md` | 机会甄别与去留 | ✅ `sandra-sales-qualify` |
| 2 | `sandra-sales-pain-diagnosis.md` | 痛诊断 | ✅ `sandra-sales-pain-diagnosis` |
| 3 | `sandra-sales-upfront-contract.md` | 事先约定 | ✅ `sandra-sales-upfront-contract` |
| 4 | `sandra-sales-objections.md` | 反对意见分诊 | ✅ `sandra-sales-objections` |
| 5 | `sandra-sales-money-talk.md` | 谈钱 / 预算 | ✅ `sandra-sales-money-talk` |
| 6 | `sandra-sales-review.md` | 拜访复盘 | ✅ `sandra-sales-review` |
| 7 | `sandra-sales-demand-gen.md` | 客户开发 | ✅ `sandra-sales-demand-gen` |
| 8 | `free-work-gate.md` | 免费工作闸门（免费方案/测试/拆项报价） | ❌ 走路由包 |
| 9 | `considered-no.md` | 含糊即拒绝（「再考虑考虑」「有消息联系你」） | ❌ 走路由包 |
| 10 | `low-threat-dialogue.md` | 低威胁对话（示弱、装傻、第三方故事、柔和挑破） | ❌ 走路由包 |
| 11 | `timing-fit.md` | 时机匹配（方案做多深、月底要不要催单） | ❌ 走路由包 |
| 12 | `pre-sign-reversal.md` | 反悔测试（签约前防反悔、合同发出没动静） | ❌ 走路由包 |
| 13 | `account-growth.md` | 客户经营（复购下滑、份额被蚕食、关系好却压价） | ❌ 走路由包 |

> 第 1–7 张的独立 Skill 是从能力卡「晋级」出来的完整版；路由包里的同名卡保留原文引文与行号，用于溯源。两者同时安装时，**优先用独立 Skill**，路由包只作背景补充。

## 二、game-design 系列（《游戏设计艺术（第2版）》蒸馏）

适用场景：游戏与互动体验设计——体验目标、结构与主题、机制与平衡、原型与迭代、方案评审、叙事与角色、试玩测试，以及动机、界面、团队、商业、社群、伦理六类支撑问题。
不适用：非游戏产品设计、纯引擎/编程实现、买量与 ASO 等增长执行、法律与合同意见。

### 1. 独立能力 Skill（可直接单点触发）

| Skill | 何时用（触发信号） | 产出 | 不用于 | 路径 |
|---|---|---|---|---|
| [`game-design-experience`](skills/game-design-experience/SKILL.md) | 说不清玩家该获得什么感受；玩家说「不好玩」但说不出哪不好；节奏平、前 10 分钟留不住人；想诊断早退 | 一句话体验陈述 + 场景约束 + 特征—表达表 + 兴趣曲线 | 具体数值平衡（用 mechanics）；方案全量评审（用 review）；执行试玩（用 playtest） | `skills/game-design-experience/` |
| [`game-design-tetrad`](skills/game-design-tetrad/SKILL.md) | 拆竞品结构；美术/玩法/技术各做各的；一个功能单看很酷但不知该不该加；主题不统一 | 四元素拆解 + 耦合检查 + 一句话主题 + 取舍清单 | 体验目标与节奏（用 experience）；数值平衡（用 mechanics）；叙事结构（用 narrative） | `skills/game-design-tetrad/` |
| [`game-design-prototype`](skills/game-design-prototype/SKILL.md) | 有想法但不知先做哪块；创意不够；预算或时间砍半要重排；迭代多版仍不收敛 | 问题陈述 + 风险表 + 原型计划 + 每轮判定标准 | 判断方案是否优秀（用 review）；执行试玩（用 playtest）；规则数值（用 mechanics） | `skills/game-design-prototype/` |
| [`game-design-review`](skills/game-design-review/SKILL.md) | 方案能不能立项；老板问砍不砍；修改后要不要重审；需要一份结构化评审清单 | 八项状态表 + 冲突项 + 结论 + 修改清单 | 生成创意（用 prototype）；只调数值（用 mechanics）；执行试玩（用 playtest） | `skills/game-design-review/` |
| [`game-design-mechanics`](skills/game-design-mechanics/SKILL.md) | 玩家总用同一招；选择没意义；奖励通胀；概率、经济、难度要调 | 七项机制地图 + 期望值核算 + 十二类平衡审计 + 调参顺序 | 体验目标（用 experience）；开发排期（用 prototype）；找玩家测试（用 playtest） | `skills/game-design-mechanics/` |
| [`game-design-narrative`](skills/game-design-narrative/SKILL.md) | 剧情和玩法打架；角色只会站桩发任务；玩家不按路线走又不想用空气墙；世界观与分支 | 结构选择表 + 角色功能/关系图 + 间接控制方案 | 对白文笔；整体节奏（用 experience）；规则数值（用 mechanics） | `skills/game-design-narrative/` |
| [`game-design-playtest`](skills/game-design-playtest/SKILL.md) | 验证新手能否学会；问卷全高分但留存低；准备焦点小组；要分析玩家反馈 | 五问测试计划 + 观察表 + 问卷/访谈提纲 + 结论 | 修 Bug（QA）；方案全量评审（用 review）；调数值（用 mechanics） | `skills/game-design-playtest/` |

### 2. 路由入口与参考包

| Skill | 作用 | 何时用 | 路径 |
|---|---|---|---|
| [`game-design`](skills/game-design/SKILL.md) | 13 张能力卡的路由表 + 全书概览 + 术语表 + 决策速查；覆盖下面 6 张**没有独立 Skill** 的能力卡 | 提到书名；问题跨体验/动机/界面/社群/商业/伦理多个域；需要原文引文与背景 | `skills/game-design/` |

路由包内附带的参考文件（按需加载，不必全读）：

| 文件 | 内容 |
|---|---|
| `references/overview.md` | 全书九部分骨架、关键命题、2015 年成书边界 |
| `references/cheatsheet.md` | 13 条决策规则速查（不需要原文依据时） |
| `references/glossary.md` | 术语表与透镜编号说明（OCR 缺失处已标注） |
| `references/capability-index.md` | 完整意图与关键词索引（路由表未覆盖时先查这里） |
| `references/capabilities/*.md` | 13 张能力卡原文与背景（见下） |

### 3. 13 张能力卡对照

| # | 能力卡 | 主题 | 独立 Skill？ |
|---|---|---|---|
| 1 | `game-design-experience.md` | 体验目标、场景与兴趣曲线 | ✅ `game-design-experience` |
| 2 | `game-design-tetrad.md` | 四元素与统一主题 | ✅ `game-design-tetrad` |
| 3 | `game-design-prototype.md` | 创意、原型与迭代 | ✅ `game-design-prototype` |
| 4 | `game-design-review.md` | 八项测试评审 | ✅ `game-design-review` |
| 5 | `game-design-mechanics.md` | 机制设计与平衡 | ✅ `game-design-mechanics` |
| 6 | `game-design-narrative.md` | 故事、世界与角色 | ✅ `game-design-narrative` |
| 7 | `game-design-playtest.md` | 试玩测试设计与执行 | ✅ `game-design-playtest` |
| 8 | `game-design-player.md` | 玩家动机与心流诊断 | ❌ 走路由包 |
| 9 | `game-design-interface.md` | 游戏界面与反馈设计 | ❌ 走路由包 |
| 10 | `game-design-team.md` | 团队协作与设计文档 | ❌ 走路由包 |
| 11 | `game-design-business.md` | 商业模式与推销 | ❌ 走路由包 |
| 12 | `game-design-community.md` | 多人游戏与社群设计 | ❌ 走路由包 |
| 13 | `game-design-ethics.md` | 设计伦理与责任评估 | ❌ 走路由包 |

> 第 1–7 张的独立 Skill 是从能力卡「晋级」出来的完整版；路由包里的同名卡保留原文引文与页码，用于溯源。两者同时安装时，**优先用独立 Skill**，路由包只作背景补充。
> 本系列基于 638 页扫描件 OCR 蒸馏，透镜框内问题大多未被识别；书中案例与经验值不等于实证结论，引用时保留「书中案例」限定。

---

## 三、组合用法（常见的跨 Skill 链路）

| 场景 | 加载顺序 |
|---|---|
| 新机会第一次接触后判断去留 | `pain-diagnosis` → `qualify` |
| 重要客户拜访前 | `upfront-contract` →（按需）`pain-diagnosis` |
| 客户说贵 | `objections`（先判断是不是烟幕）→ `money-talk` |
| 谈完客户不给下一步 | `considered-no`（路由包）→ `qualify` |
| 方案发出去没回音 | `pain-diagnosis` → `timing-fit`（路由包）→ `qualify` |
| 口头同意但不签 | `pre-sign-reversal`（路由包）→ `money-talk` |
| 拜访后团队复盘 | `review` →（按需）`upfront-contract` |
| 季度初定目标与行为量 | `demand-gen` →（存量部分）`account-growth`（路由包） |

**game-design 系列**

| 场景 | 加载顺序 |
|---|---|
| 新想法从 0 到可玩 | `game-design-prototype` → `game-design-tetrad`（结构）→ `game-design-experience`（目标） |
| 玩家说不好玩但说不清 | `game-design-experience` → `game-design-mechanics`（若涉及数值）→ `game-design-playtest`（验证） |
| 方案要立项或砍留 | `game-design-review` →（缺试玩证据）`game-design-playtest` |
| 剧情和玩法打架 | `game-design-narrative` → `game-design-experience`（整体节奏） |
| 上线后流失 | `game-design`（路由到动机/界面/社群）→ `game-design-playtest` |

---

## 四、索引维护规则

- 新增 Skill：在「一」下新建小节，表格补齐 Skill 名、触发信号、产出、不用于、路径
- 触发信号要写**客户/用户的原话**，不要写抽象名词（「含糊即拒绝」不如「客户反复说再考虑考虑」好命中）
- 「不用于」列必须写，否则 AI 会在相邻场景误触发
- 一个 Skill 只解决一类任务；跨域时在「二」里写组合链路，不要合并 Skill
