# 本机路径与命令（只在这个环境有效）

这份文件解决一个问题：**要动手时，东西都在哪、怎么跑。** 换机器只要改这张表。

## 目录

| 东西 | 路径 |
| --- | --- |
| 工作根 | `D:\PROJECT\Ds` |
| 工具目录 | `D:\PROJECT\Ds\tools`（索引见 `INDEX.md`） |
| 派单台账 | `D:\PROJECT\Ds\tools\claude-ledger.jsonl` |
| 原始回执 | `D:\PROJECT\Ds\tools\runs\<id>.json` |
| 进度 / 任务表 / 任务池 | `D:\PROJECT\Ds\_progress\` |
| 授权队列 / 放行规则 | `D:\PROJECT\Ds\_progress\approvals.json` / `allowlist.json` |
| WorkBuddy 调用日志 | `D:\PROJECT\Ds\tools\wb-bridge\calls.jsonl` |
| 驾驶舱后端 | `D:\PROJECT\Ds\tools\dashboard\server.mjs` |
| 驾驶舱前端（Vue） | `D:\PROJECT\Ds\cockpit`（构建到 `dist/`） |
| 临时文件 | `D:\Temp` |

## 命令

```powershell
# 派活（只读）
.\claude-dispatch.ps1 -Task '<四件套>' -Allow 'Bash(npm run typecheck:*)'

# 派活（允许改文件）
.\claude-dispatch.ps1 -Mode write -Allow 'Bash(npm run *:*)' -Task '<四件套>'

# 复核（续接同一条会话）
.\claude-dispatch.ps1 -Continue -Task '自查：改了什么、验了什么、哪条没过'

# 看花费
.\claude-ledger.ps1 -Query summary

# 起驾驶舱
node D:\PROJECT\Ds\tools\dashboard\server.mjs    # http://127.0.0.1:8899/app/
```

## 环境事实（会变，改前先验）

- WSL 发行版：`Ubuntu-26.04`，仓库在 `~/LosAngelous/Vesta`
- Claude Code 走自定义启动器 `start_claude_code_jz`（网关 + `deepseek-v4-flash`），**不要在 Windows 侧另配登录**
- 路径都集中在 `tools\paths.json`；换盘符/用户名只改它，再跑 `sync-mcp.ps1`
- WorkBuddy 通过本地 MCP（`~/.workbuddy/mcp.json` 的 `ds-taskboard`）主动来取活，所以是**它拉**，不是我们推

## 成本参考（实测 2026-11-13）

| 场景 | 花费 |
| --- | --- |
| 新开会话，2 轮 | ≈ $0.06 |
| 新开会话，4 轮（含被拒重试） | ≈ $0.09 |
| 续接同一条会话，1 轮 | ≈ $0.06（新增 token 只有几百） |
