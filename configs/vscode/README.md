# VS Code 配置备份

来源：Windows 侧 `%APPDATA%\Code\User`（本机为 `C:\Users\admin\AppData\Roaming\Code\User`）。

| 文件 | 内容 |
|---|---|
| `settings.json` | 用户设置（主题、字体、格式化、C/C++、CMake 等） |
| `keybindings.json` | 自定义快捷键 |
| `extensions.txt` | 已安装扩展 ID（从 `~/.vscode/extensions` 去重导出，2026-11-20 共 295 个） |

部署：

```bash
./scripts/install-vscode-config.sh                    # 自动探测用户目录
./scripts/install-vscode-config.sh --dir /path/User   # 显式指定
./scripts/install-vscode-config.sh --with-extensions  # 额外安装扩展（联网，较慢）
./scripts/install-vscode-config.sh --dry-run
```

覆盖前备份为 `*.losskill.bak`。

## 注意

- `settings.json` 是**原样备份**，含机器专属路径（如 `clangd.path` 指向旧用户名 `hspcadmin`）。恢复后按目标机器删改。
- 设置里可能引用未安装的扩展，VS Code 会提示；按 `extensions.txt` 补装即可。
- 扩展列表包含历史安装项，`--with-extensions` 会逐个安装，约 295 个，耗时较长；只想恢复常用项时，先裁剪 `extensions.txt`。
- 不备份 `globalStorage/`、`workspaceStorage/`、`History/`、`sync/` 等会话或缓存数据。
