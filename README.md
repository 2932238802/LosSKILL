# LosSKILL — 个人环境配置仓库 + AI Skill 收藏

这个仓库是**个人开发环境备份方案**，同时也是**个人 AI Skill 收藏库**：
1. 收集自己的代码习惯、AI 辅助方法、工作流程（整理为可被 AI 直接调用的 Skill）
2. 包含个人配置（快捷键、软件安装指令、开发环境设置）
3. 提供一键配置脚本，在新电脑上拉取仓库后运行指令，就能快速配置好所有环境、软件和个人习惯。

目标很简单：**用这个仓库，在新电脑上最快 5 分钟就能恢复自己的全部开发环境，包含 AI 技能和工作流，不用重新设置，不用整理配置。**

- 「AI Skill」部分：保持原有 Skill 目录结构，可被任意 AI 工具直接加载
- 「环境配置」部分：新增 `configs/`（个人配置文件）和 `scripts/env-setup/`（环境安装脚本）
- 新增 `install.sh`/`install.ps1` 扩展功能：除了复制 AI Skill，还能执行环境安装指令

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

## 核心能力：AI 注释保护（自动保护你的 LOS: 注释）

本仓库新增了 **AI 规则 Skill** — `ai-comment-protection`，用于：
✅ **禁止 AI 修改/删除你的 `LOS:` 开头的手动注释**
✅ **AI 修改包含注释的代码时，必须保留所有 `LOS:` 注释**
✅ **AI 必须记录修改过程中保留的 `LOS:` 注释，不得覆盖**

当你将 LosSKILL 仓库加载到任意 AI 工具后，AI 会自动遵守这条规则：只要检测到文件中以 `// LOS:`、`# LOS:`、`/* LOS:` 等开头的注释，就绝对不会修改、删除或覆盖这些注释，只会原封不动保留它们。

### 个人环境配置功能

本仓库同时具备 **AI Skill 收藏** 和 **个人开发环境备份** 能力：
1. **AI Skill 部分**：原有技能目录，包含可被 AI 工具直接加载的工作流、方法指南（含 `ai-comment-protection` 规则，保护你的手动注释）
2. **环境配置部分**：
   - `configs/`：个人配置文件（git 配置、bash 别名、Neovim 配置等）
   - 一键配置脚本：`./scripts/install.sh` 完成 Skill 安装后，可选择自动部署个人配置

### 一键恢复环境（新电脑专用）
在新电脑上，拉取仓库后运行：
```bash
cd LosSKILL
./setup.sh               # 回车即弹出菜单，按序号勾选要执行的步骤（无需记任何参数）
```
菜单长这样：输入 `1 2 3` 再回车就是「勾选第 1/2/3 项」，`a` 全选、`c` 清空、`q` 退出，回车开始执行。六个步骤分别是：AI Skills、个人环境、SSH、dsh 插件、ble.sh（可选）、自检。

只想装 Skills + 环境（不碰 SSH / dsh 插件）时，仍可单独跑：
```bash
./scripts/install.sh      # 分步脚本，交互式
```
`./setup.sh` 也保留了快捷参数（自动化用，日常不需要记）：`--yes`（全量执行）、`--with-blesh`（全量 + ble.sh）、`--validate-only`（只自检）。

脚本会先安装所有 AI Skill（包括注释保护规则），然后询问是否应用个人环境配置：
- 部署 `.gitconfig` 与 Neovim 配置（覆盖前自动备份为 `*.losskill.bak`）；`.bashrc` 只作为**模板**参考，脚本只向真实 `.bashrc` 追加受管配置块，不会整文件覆盖
- 自动识别系统包管理器（apt/brew/yum），安装常用开发工具（git、curl 等）
- 同步 Neovim、VS Code 等编辑器配置
- **WSL2 环境专属**：安装 Oh My Posh（huvix 主题）、中文语言包、C++ 和 Rust 开发工具，以及历史前缀搜索（↑/↓、Ctrl+X Ctrl+H、Ctrl+R）
- **Git SSH 自动配置**：无论 WSL 还是普通 Linux，自动创建 ED25519 SSH 密钥，并提示你将公钥添加到 GitHub（`https://github.com/settings/keys`），配置 SSH 提交方式，无需每次输入 Git 密码。

### SSH Git 提交方式（自动处理）
脚本会自动生成你的 SSH 密钥，并在控制台显示公钥内容，按提示复制到 GitHub 的 SSH 密钥页面即可。完成后，Git 提交将通过 SSH 加密，更安全且无需重复认证。

### WSL2 环境增强（自动配置）
在 WSL2 环境下运行 `./scripts/install.sh` 应用个人环境配置时，会自动完成：
1. **中文语言包安装**：自动安装 `language-pack-zh-hans`，设置 WSL2 默认 locale 为中文，支持中文界面和输入
2. **Oh My Posh（huvix 主题）**：安装 Oh My Posh，把主题文件固定到 `~/.config/oh-my-posh/themes/huvix.omp.json`，**并删除旧的 kali 主题 init 行**，避免两套提示符互相覆盖
3. **历史搜索（三个真实可用的功能）**：
   - 输入前缀后按 **↑ / ↓**：只翻「以当前输入开头」的历史（等价 PowerShell 的 UpArrow）
   - **Ctrl+X Ctrl+H**：把匹配的最近 10 条打印成 `<History(N)>` 列表
   - **Ctrl+R**：fzf 弹层模糊搜索历史（未装 fzf 时退回 bash 自带的增量搜索）
4. **C++/Rust 开发环境**：安装编译工具和 Rust 语言环境

#### 要「边打字边列历史」就装 ble.sh
截图里的 `<-/10>` + `[History]` 列表是 **PowerShell 的 PSReadLine ListView 预测**；bash/readline 没有对等机制。要最接近的效果，可额外装 `ble.sh`（bash 行编辑器，自带历史补全菜单）：
```bash
./scripts/install-blesh.sh    # 或 ./setup.sh --with-blesh
```
装完后敲命令前缀会自动出现历史候选菜单。注意 ble.sh 会接管 readline（替代上面 ↑/↓、Ctrl+R 的绑定），还原方式见脚本末尾说明。

#### 为什么旧版脚本没有效果
旧脚本把匹配逻辑挂在 `PROMPT_COMMAND` 上，并读取 `$READLINE_LINE`。但 `READLINE_LINE` **只在 `bind -x` 绑定的函数里才有值**，在 `PROMPT_COMMAND` 里恒为空，导致条件判断永远成立、匹配串永远为空 —— 所以既不会按你输入的前缀过滤，也不会有任何视觉反馈。现在改成 `bind -x` 绑定 `Ctrl+X Ctrl+H` 后才真正拿得到当前输入。

### AI 注释保护规则（自动生效）
当你加载本仓库到任意 AI 工具后，规则自动生效：
- 识别所有以 `LOS:` 开头的注释（无论用 `//`、`#`、`/*` 等注释符）
- AI 不得修改、删除、移动这些注释
- AI 修改代码时，必须保留这些注释内容，不得覆盖
- 如果修改需要涉及注释所在代码块，AI 必须在回复中明确说明已保留这些注释的位置和内容


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
├─ configs/               # 个人配置：由安装脚本部署到 home
│  ├─ .gitconfig          # git 别名与行为
│  ├─ .bashrc             # bash 模板（含历史搜索块，仅作参考/示例）
│  ├─ powershell-profile.ps1  # PowerShell 7 配置：PSReadLine 历史预测(Layout 列表)、别名、Oh My Posh
│  └─ nvim/init.vim       # Neovim 配置
├─ setup.sh              # 一键总入口：技能 → 环境 → SSH → dsh 插件 → 自检
└─ scripts/
   ├─ install.sh          # 分步安装（WSL2 / Linux / macOS：Skill + 环境 + SSH）
   ├─ install.ps1         # 分步安装（Windows：Skill + 环境 + SSH + winget）
   ├─ install-dsh-plugins.sh  # 给 dsh 的 profile 批量装插件（幂等，npm 直连）
   ├─ install-blesh.sh    # 可选：装 ble.sh，实现「边打字边列历史」
   ├─ setup-ssh-git.sh    # 只做 SSH 密钥与 GitHub 提交方式
   ├─ validate.sh         # 自检（Linux / WSL，等价 validate.ps1）
   └─ validate.ps1        # 自检（Windows）
```

---

## 贡献 / 新增 Skill 的约定

1. 复制 `_template/` 为 `skills/<你的skill名>/`
2. 目录名用 **kebab-case**，与 frontmatter 的 `name` 完全一致
3. `description` 必须写清三件事：**什么时候用**、**产出什么**、**不用于什么**（第三点决定 AI 会不会误触发）
4. 正文用相对路径引用附件；不要依赖仓库外的文件
5. 在 `SKILLS.md` 增加一行索引
6. 单文件控制在 ~500 行内；长内容拆进 `references/`，正文只留「何时读哪个文件」
7. 跑一遍自检：Linux/WSL 用 `./scripts/validate.sh`，Windows 用 `powershell -ExecutionPolicy Bypass -File .\scripts\validate.ps1`

详细规范见 [_template/GUIDE.md](_template/GUIDE.md)。

---

## 说明与边界

- 本仓库是**方法蒸馏**，不是原书替代品。`sandra-sales` 与 `game-design` 系列的能力卡保留了原文引文与页码，用于溯源；引用与商用请遵守原书版权。
- `game-design` 系列的来源是 638 页扫描件的 OCR 文本：透镜框内问题大多缺失，财务数字不可读，部分案例为作者转述。卡片已在相应位置标注边界，不要当作实证结论。
- 蒸馏内容中的案例均为书内案例的改写，比例类数字（如「90% 的方案提交过早」）书中无出处，只作方向参考，不可当阈值使用。
- Skill 是给 AI 的操作指令，不构成法律、财务、定价授权建议；涉及合规与授权的场景，Skill 内部会要求转人工。

## DeepSeek Harness 集成

### 1. 安装 DeepSeek Harness
使用以下命令全局安装 DeepSeek Harness（需要 Node.js ≥ 18）：
```bash
npm install -g @deepseek-ai/dsh
```

### 2. 自动安装插件脚本
仓库新增了 `scripts/install-dsh-plugins.sh` 脚本，用于为 Web  Profile 自动安装常用插件：
- 插件列表：`dshmarket`（插件市场）、`dsh-prompt`（提示管理）、`dsh-prompt-history`（提示历史）、`dsh-mole`（代码调试工具）

使用方法：
```bash
cd LosSKILL
./scripts/install-dsh-plugins.sh
```
脚本默认**直接走 npm** 装进 `~/.dsh/profiles/web`（本机 `dsh plugin add` 会踩 pnpm panic，见下），已安装且版本一致的会跳过，失败时才回退到 `dsh plugin` 命令。可选参数：
```bash
./scripts/install-dsh-plugins.sh dshmarket foo@1.2.3   # 只装指定插件
DSH_PROFILE=desktop ./scripts/install-dsh-plugins.sh   # 装到别的 profile
```

> 已知问题：本机 `dsh plugin --profile web add <pkg>` 报
> `Main thread panicked ... current dir is an absolute path with drive letter`（pnpm exit 9）。
> 这是 pnpm 在 WSL 下解析工作目录的 bug，与插件本身无关；改用 npm 直装即可绕开。

---

## License

代码与文档采用 [MIT](LICENSE)。`sandra-sales` 系列蒸馏文本基于《桑德拉销售原则》，其原始内容版权归原作者/出版方所有。
