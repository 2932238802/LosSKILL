# Claude Code 配置备份

这里保存的是本机 `~/.claude/` 里**需要跨电脑恢复**的个性化配置。部署脚本：

```bash
./scripts/install-claude-config.sh            # 部署到 ~/.claude
./scripts/install-claude-config.sh --dry-run  # 只看会改什么
CLAUDE_CONFIG_DIR=/tmp/cc-test ./scripts/install-claude-config.sh   # 试装到别处
```

`setup.sh` / `scripts/install.sh` 选择「个人环境配置」时会自动调用。脚本幂等：内容相同跳过，覆盖前备份为 `*.losskill.bak`。

## 备份内容

| 文件 | 作用 |
|---|---|
| `settings.json` | 权限、模型、通知 hook、状态栏、主题 |
| `statusline.py` | 状态栏：模型 · 目录 · git · 上下文 · 花费 |
| `themes/catppuccin-mocha.json` | 自定义主题 |
| `hooks/notify.sh` | WSL → Windows Toast 通知（队列 + 常驻守护进程） |
| `hooks/toast.ps1` | 单条 Toast 直连（回退方案） |
| `hooks/toastd.ps1` | Toast 守护进程，监听队列目录 |
| `hooks/README-toast.md` | 通知链路说明 |

**agents 不在这里存副本。** 四个角色文件由 `install-claude-config.sh` 从 `skills/dev-workflow/references/01–04-*.md` 生成，前面加 frontmatter（`name` / `description` / `tools`）。这样角色正文只有一份，不会再次出现三处副本分叉。

## 换机器时要改的

1. **模型**：`settings.json` 的 `"model"` 是当前机器使用的模型；目标机器没有这个模型时删掉该行即可。
2. **通知队列盘符**：默认 `D:\Temp\claude-toast` / `/mnt/d/Temp/claude-toast`。没有 D 盘时改队列目录，**WSL 与 Windows 两侧要保持一致**：
   - WSL：`export CLAUDE_TOAST_DIR=/mnt/c/Temp/claude-toast`
   - Windows：给 toastd 设置同名环境变量，或直接改 `toastd.ps1` 里的 `D:\Temp\claude-toast`
   `notify.sh` 与 `toastd.ps1` 都读取 `CLAUDE_TOAST_DIR`；但 WSL 的环境变量默认不会传进 Windows 进程，所以两侧都要设。
3. **Windows 原生环境**：`settings.json` 和 `notify.sh` 是 WSL 方案；`install.ps1` 在 Windows 上只部署主题与 agents，不覆盖 settings/hooks，避免通知命令指向不存在的 bash。

## 不备份的东西

`history.jsonl`、`projects/`、`sessions/`、`file-history/`、`plugins/`、`shell-snapshots/` 属于会话数据或本机缓存，不进仓库；`settings.local.json` 含项目级授权，继续由全局 gitignore 忽略。
