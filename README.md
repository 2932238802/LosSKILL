# LosSKILL — 可被任意 AI 直接加载的 Skill 仓库

这个仓库是**个人 Skill 库**：把从书、长视频、播客、课程、访谈里蒸馏出来的方法，以及日常收集整理的有效方法，写成一个个**自包含、可被 AI 直接调用**的 Skill 文件夹。

目标很简单：**别人（或别的 AI）把这个仓库下载下来，不用读文档、不用改编，就能直接用。**

- 每个 Skill 都是独立的文件夹，核心只有一份 `SKILL.md`
- 所有引用文件都用**相对路径**，复制/移动整个文件夹不会断链
- 仓库根目录的 `SKILLS.md` 是全部 Skill 的索引，AI 可以先读索引再按需加载某一个
- 新增 Skill 有固定模板 `_template/`，保持结构一致

---

## 快速使用

### 方式一：手动复制（最通用，任何 AI 都适用）

1. 下载本仓库（`Code` → `Download ZIP`，或 `git clone`）
2. 把 `skills/` 下你需要的那个文件夹，复制进你的 AI 工具的 skills 目录
3. 新开一个会话，AI 就能在技能列表里看到它

不知道放哪：任何支持 Skill 的工具，认的都是「**一个目录 + 目录里有 `SKILL.md`**」。把文件夹放进去即可。

### 方式二：一条命令安装（Windows / macOS / Linux）

在仓库根目录执行：

```powershell
# Windows PowerShell（默认目标：%USERPROFILE%\.dsh\skills）
powershell -ExecutionPolicy Bypass -File .\scripts\install.ps1                                # 全部
powershell -ExecutionPolicy Bypass -File .\scripts\install.ps1 -Skill sandra-sales             # 只装这一套
powershell -ExecutionPolicy Bypass -File .\scripts\install.ps1 -Target 'D:\MyProject\.claude\skills' -Force
```

```bash
# macOS / Linux（默认目标：~/.dsh/skills，可用 LOSSKILL_TARGET 覆盖）
./scripts/install.sh                # 全部
./scripts/install.sh sandra-sales   # 单个
./scripts/install.sh all ~/.claude/skills
```

> Windows 上如果提示「脚本未 digitally signed」，就是因为默认执行策略是 Restricted，用上面的 `-ExecutionPolicy Bypass` 即可，不需要改系统设置。

脚本参数：`-Skill` 支持单名、逗号分隔多个、或 `all`；`-Target` 指定目录；`-Force` 覆盖已存在的同名 Skill（只删除目标目录下那一个文件夹）。

脚本只做复制，不联网、不执行 Skill 里的任何指令。

### 方式三：让 AI 自己装

对任何有文件读写能力的 AI 说：

> 读一下 `SKILLS.md`，把其中 `sandra-sales` 系列安装到你的 skill 目录，然后告诉我怎么触发它们。

---

## 各工具默认的 Skill 目录

| 工具 | 默认目录 | 说明 |
|---|---|---|
| DeepSeek Harness (DSH) | `~/.dsh/skills/` | 本机已在该目录验证这 8 个 Skill 可被正常列出与触发 |
| Claude Code | `~/.claude/skills/`（个人）或 `<项目>/.claude/skills/`（项目） | 目录名即 Skill 名 |
| Codex CLI / 兼容 Agent Skills 的客户端 | 见各自配置，认 `SKILL.md` 约定 | 指向 `skills/<name>/` 即可 |
| Cursor / Windsurf / Cline 等 | 项目内 `.cursor/rules`、`.windsurfrules` 等 | 可把某个 `SKILL.md` 内容贴为规则；或使用支持 skills 目录的插件 |
| 任意自研 Agent | 任意目录 | 加载规则：读 `SKILL.md` 的 frontmatter，`description` 命中即加载正文 |

> 本仓库两个安装脚本的默认目标都是 `~/.dsh/skills`（Windows 与 Linux/macOS 一致）。装到别的工具时用 `-Target` 或第二个参数显式指定即可，例如 `./scripts/install.sh all ~/.claude/skills`。

---

## 当前收录

完整清单（含触发时机、边界、文件结构）见 **[SKILLS.md](SKILLS.md)**。

| Skill | 一句话 | 来源 |
|---|---|---|
| `sandra-sales` | 《桑德拉销售原则》总入口：13 张能力卡的路由 + 全书概览/术语/速查 | 蒸馏 · 书籍 |
| `sandra-sales-qualify` | 机会甄别：痛/预算/决策三柱，继续还是结案 | 蒸馏 · 书籍 |
| `sandra-sales-pain-diagnosis` | 痛诊断：把「需求」问成可查证的「痛」 | 蒸馏 · 书籍 |
| `sandra-sales-upfront-contract` | 事先约定：会谈五要素，杜绝「谈完没结论」 | 蒸馏 · 书籍 |
| `sandra-sales-objections` | 反对意见分诊：自造 / 真实 / 烟幕 | 蒸馏 · 书籍 |
| `sandra-sales-money-talk` | 谈钱：预算时机与差距出现时的三句话 | 蒸馏 · 书籍 |
| `sandra-sales-review` | 拜访复盘：四层结论 + 最多 3 条下阶段动作 | 蒸馏 · 书籍 |
| `sandra-sales-demand-gen` | 客户开发：ICP、分级、转介绍、行为量日历 | 蒸馏 · 书籍 |
| `game-design` | 《游戏设计艺术（第2版）》总入口：13 张能力卡的路由 + 全书概览/术语/速查 | 蒸馏 · 书籍 |
| `game-design-experience` | 体验目标：一句可检验的体验陈述 + 场景 + 兴趣曲线 | 蒸馏 · 书籍 |
| `game-design-tetrad` | 四元素与主题：机制/故事/美学/技术四栏拆解 | 蒸馏 · 书籍 |
| `game-design-prototype` | 原型与迭代：问题陈述 → 风险排序 → 最小原型 | 蒸馏 · 书籍 |
| `game-design-review` | 八项测试：立项与砍留的结构化评审 | 蒸馏 · 书籍 |
| `game-design-mechanics` | 机制与平衡：期望值、十二类平衡、有意义的选择 | 蒸馏 · 书籍 |
| `game-design-narrative` | 故事与角色：珍珠串/故事机/英雄之旅 + 间接控制 | 蒸馏 · 书籍 |
| `game-design-playtest` | 试玩测试：五问定义、观察、问卷与访谈 | 蒸馏 · 书籍 |

> `sandra-sales` 是「路由 + 参考包」，其余 7 个是可直接单点触发的独立 Skill。两者可同时安装：独立 Skill 命中时优先用它，路由包负责没有独立 Skill 的 6 张能力卡与全书背景。

> `game-design` 同样是「路由 + 参考包」，其余 7 个是可直接单点触发的独立 Skill。路由包覆盖玩家动机、界面、团队文档、商业模式、社群、伦理 6 张能力卡与全书背景。
> 两套系列互不依赖，可只装一套；同一系列内，独立 Skill 命中时优先用它。

### 装好之后怎么触发

不需要记 Skill 名，正常说业务问题就会命中：

| 你说 | 命中的 Skill | 你会拿到 |
|---|---|---|
| 「客户一直说再考虑考虑，是不是没戏了」 | `sandra-sales`（considered-no 卡） | 含糊即拒绝的判定 + 逼出具体下一步的话术 |
| 「这个单子还要不要跟」 | `sandra-sales-qualify` | 痛/预算/决策三柱状态表 + 继续/结案结论 |
| 「明天见这个客户，议程怎么设计」 | `sandra-sales-upfront-contract` | 会谈五要素表 + 犯规约定 |
| 「客户说太贵了」 | `sandra-sales-objections` → `sandra-sales-money-talk` | 先判是不是烟幕，再给差距出现时的三句话 |
| 「客户要免费做方案」 | `sandra-sales`（free-work-gate 卡） | 免费工作闸门的判断与拒绝话术 |
| 「复盘一下上周那次拜访」 | `sandra-sales-review` | 四层结论 + 最多 3 条下阶段动作 |
| 「玩家说不上哪不好，就是不想再开一局」 | `game-design-experience` | 体验陈述 + 场景约束 + 兴趣曲线诊断 |
| 「这个功能单看很酷，要不要加」 | `game-design-tetrad` | 四元素耦合检查 + 主题取舍 |
| 「预算砍半，原型先做哪块」 | `game-design-prototype` | 风险排序 + 最小原型计划 |
| 「玩家总用同一招，怎么调」 | `game-design-mechanics` | 最优策略定位 + 期望值/平衡审计 |
| 「剧情和关卡老打架」 | `game-design-narrative` | 结构选择 + 角色关系 + 间接控制 |

---

## 仓库结构

```
LosSKILL/
├─ README.md              # 本文件：怎么用、怎么装
├─ SKILLS.md              # 全部 Skill 的索引（AI 优先读这个）
├─ LICENSE                # MIT
├─ .gitattributes         # 统一 LF，保证 install.sh 在跨平台可用
├─ skills/                # 所有 Skill，一个文件夹一个 Skill
│  ├─ sandra-sales/
│  │  ├─ SKILL.md         # 必需：frontmatter(name/description) + 正文
│  │  └─ references/      # 可选：按需加载的参考文件
│  ├─ sandra-sales-qualify/
│  │  └─ SKILL.md
│  ├─ game-design/
│  │  ├─ SKILL.md
│  │  └─ references/
│  └─ game-design-experience/
│     └─ SKILL.md
├─ _template/             # 新增 Skill 的模板与写作规范
│  ├─ SKILL.md
│  └─ GUIDE.md
└─ scripts/
   ├─ install.ps1         # 安装（Windows）
   ├─ install.sh          # 安装（macOS / Linux）
   └─ validate.ps1        # 自检：frontmatter、命名、相对路径、索引覆盖
```

---

## 贡献 / 新增 Skill 的约定

1. 复制 `_template/` 为 `skills/<你的skill名>/`
2. 目录名用 **kebab-case**，与 frontmatter 的 `name` 完全一致
3. `description` 必须写清三件事：**什么时候用**、**产出什么**、**不用于什么**（第三点决定 AI 会不会误触发）
4. 正文用相对路径引用附件；不要依赖仓库外的文件
5. 在 `SKILLS.md` 增加一行索引
6. 单文件控制在 ~500 行内；长内容拆进 `references/`，正文只留「何时读哪个文件」
7. 跑一遍自检：`powershell -ExecutionPolicy Bypass -File .\scripts\validate.ps1`

详细规范见 [_template/GUIDE.md](_template/GUIDE.md)。

---

## 说明与边界

- 本仓库是**方法蒸馏**，不是原书替代品。`sandra-sales` 与 `game-design` 系列的能力卡保留了原文引文与页码，用于溯源；引用与商用请遵守原书版权。
- `game-design` 系列的来源是 638 页扫描件的 OCR 文本：透镜框内问题大多缺失，财务数字不可读，部分案例为作者转述。卡片已在相应位置标注边界，不要当作实证结论。
- 蒸馏内容中的案例均为书内案例的改写，比例类数字（如「90% 的方案提交过早」）书中无出处，只作方向参考，不可当阈值使用。
- Skill 是给 AI 的操作指令，不构成法律、财务、定价授权建议；涉及合规与授权的场景，Skill 内部会要求转人工。

## License

代码与文档采用 [MIT](LICENSE)。`sandra-sales` 系列蒸馏文本基于《桑德拉销售原则》，其原始内容版权归原作者/出版方所有。
