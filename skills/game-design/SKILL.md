---
name: game-design
description: |
  《游戏设计艺术（第2版）》来源路由入口。按任务加载对应能力卡：体验目标、四元素与主题、机制与平衡、
  原型与迭代、八项测试评审、故事与世界、试玩测试、玩家动机、界面、团队文档、商业模式、社群、伦理。
  当用户没有提到书名、但问题属于游戏/互动体验设计时使用。
  不用于：非游戏设计问题、纯引擎/编程实现、买量与 ASO 等增长执行、法律与合同意见。
metadata:
  cangjie.generated-by: cangjie-tools v2.5.0
  cangjie.variant: router
  cangjie.bundle-id: bundle.the-art-of-game-design
  cangjie.capability-count: 13
  cangjie.entrypoint-count: 8
---
# 游戏设计艺术（第2版） — 来源路由入口（compact pack）

## 触发与不触发

**适用**：与本书能力域相关的咨询与任务（见下方路由表的意图列）。
**不适用**：
- 非游戏产品、纯软件工程与美术制作流程
- 具体引擎/编程实现与性能优化
- 已上线产品的买量、ASO、直播运营等增长执行

## 核心原则（常驻速览，概览类问题读到这里即可回答）

1. 玩家买的是体验，不是规则、美术或代码；设计对象是体验，元素只是媒介。
2. 机制、故事、美学、技术四种元素地位平等，主题负责让它们朝同一方向工作。
3. 创意先求数量再筛选；设计通过"测试—改进"迭代推进，每轮先消除最大风险。
4. 平衡不是数值平均，而是把元素调到能传达目标体验。
5. 任何方案修改后都要重跑八项测试；第 8 项只能由目标玩家验证。
6. 试玩测试回答"玩家感受到了什么"，不是"玩家做了什么"。

## 能力路由（先读本表，按意图加载 1 张能力卡）

| 用户意图 | 先读 | 补读/备注 |
|---|---|---|
| 说清一款游戏要让玩家获得什么体验；诊断"体验不对/玩家早退"的原因；设计体验节奏与兴趣曲线 | references/capabilities/game-design-experience.md | 已晋级为独立 Skill `game-design-experience`（已安装时优先直接使用；本卡仅作原文与背景补充） |
| 用四元素分析一款游戏或竞品；判断游戏各部分是否统一；确定并执行统一主题 | references/capabilities/game-design-tetrad.md | 已晋级为独立 Skill `game-design-tetrad`（已安装时优先直接使用；本卡仅作原文与背景补充） |
| 从想法推进到可测试原型；规划迭代与风险消除顺序；做头脑风暴并筛选创意 | references/capabilities/game-design-prototype.md | 已晋级为独立 Skill `game-design-prototype`（已安装时优先直接使用；本卡仅作原文与背景补充） |
| 评审一个游戏设计方案；判断项目能否进入下一阶段；建立设计评审清单 | references/capabilities/game-design-review.md | 已晋级为独立 Skill `game-design-review`（已安装时优先直接使用；本卡仅作原文与背景补充） |
| 设计或审查核心机制；调整数值、难度与经济系统；消除最优策略与无意义选择 | references/capabilities/game-design-mechanics.md | 已晋级为独立 Skill `game-design-mechanics`（已安装时优先直接使用；本卡仅作原文与背景补充） |
| 设计故事与玩法的结合方式；设计角色阵容与关系；用间接控制引导玩家行为 | references/capabilities/game-design-narrative.md | 已晋级为独立 Skill `game-design-narrative`（已安装时优先直接使用；本卡仅作原文与背景补充） |
| 规划一场试玩测试；设计问卷与访谈问题；分析玩家反馈与观察记录 | references/capabilities/game-design-playtest.md | 已晋级为独立 Skill `game-design-playtest`（已安装时优先直接使用；本卡仅作原文与背景补充） |
| 诊断玩家流失与投入不足；设计奖励与动机系统；判断玩家处于无聊还是焦虑 | references/capabilities/game-design-player.md | references/capabilities/game-design-mechanics.md、references/capabilities/game-design-community.md |
| 设计 HUD、菜单与交互规格；诊断操作延迟与信息找不到；检查界面一致性 | references/capabilities/game-design-interface.md | references/capabilities/game-design-experience.md、references/capabilities/game-design-playtest.md |
| 写设计文档或一页设计；建立团队评审与决策流程；解决团队对设计的分歧 | references/capabilities/game-design-team.md | references/capabilities/game-design-review.md |
| 选择商业模式与付费方式；评估项目盈利与市场壁垒；准备向发行商/管理层推销 | references/capabilities/game-design-business.md | references/capabilities/game-design-ethics.md |
| 判断是否要做多人模式；设计合作/竞争与公会结构；诊断社群不活跃或恶意破坏 | references/capabilities/game-design-community.md | references/capabilities/game-design-player.md、references/capabilities/game-design-ethics.md |
| 评估设计的伦理风险；设计严肃/教育游戏并评估成效；判断是否接一个项目 | references/capabilities/game-design-ethics.md | references/capabilities/game-design-business.md、references/capabilities/game-design-player.md |

**非能力类查询**：
- 书名/作者/章节/整书概览 → references/overview.md
- 术语解释 → references/glossary.md
- 决策规则速查（不需要原文依据时） → references/cheatsheet.md
- 完整意图与关键词索引（本表未覆盖的意图先查这里） → references/capability-index.md

## 加载规则

- 每次任务先读本文件，再按路由表加载 **1** 张能力卡；任务明确跨域时最多加载 2 张。
- 概览/书名类问题不加载能力卡，用「核心原则」与 overview.md 回答。
- 路由表与 capability-index.md 都无法命中的意图，明确告知超出本书范围，不要硬套。

## 边界与判停

- 缺少目标玩家、场景或可玩原型时，先补齐信息，不凭空给结论
- 问题超出游戏设计范围（法律、财务、医疗、心理治疗）时，明确说明并停止
