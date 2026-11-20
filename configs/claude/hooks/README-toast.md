# Claude Code → Windows 通知链路（2026-11-13 优化版）

## 结论先说

- WSL 里的 `sudo` 已经配了 `NOPASSWD:ALL`（`/etc/sudoers.d/losangelous`），**不会弹密码、也不会碰 Windows UAC**，耗时基本为 0。
- 你在 Windows 侧看到的"要授权的弹窗"，是 `~/.claude/hooks/notify.sh` 发的**通知 toast**（标题 `Claude Code · <项目>`），由 Claude Code 的 `Notification` 钩子在 `permission_prompt` 时触发，不是 UAC。
- 优化前：每条通知冷启动一次 `powershell.exe` → 弹窗 **800–1000 ms** 才出现；dismiss 再冷启动一次，且有 marker 竞态，偶发"没弹/没撤"。
- 优化后：常驻守护进程 + 文件队列 → **31–55 ms**（实测）。只有守护进程不在时才有一次 0.9–2.4 s 冷启动（12 小时空闲才退出一次）。

## 结构

```
Claude Code (WSL)
   └─ Notification hook ──> ~/.claude/hooks/notify.sh
                                │  写 req-*.req 到 /mnt/d/Temp/claude-toast/
                                ▼
                  D:\Temp\claude-toast\  (Windows 侧队列目录)
                                │  FileSystemWatcher（≤1.5s 一轮，心跳同时刷新）
                                ▼
                  toastd.ps1（常驻，WinRT 只加载一次）
                                └─ ToastNotificationManager.Show() → 通知
```

## 文件

| 文件 | 作用 |
| --- | --- |
| `~/.claude/hooks/notify.sh` | 钩子入口：解析事件 JSON、拼标题正文、入队；失败回退旧路径 |
| `~/.claude/hooks/toastd.ps1` | 常驻守护：监听队列、弹/撤通知、维护心跳与 pid |
| `~/.claude/hooks/toast.ps1` | 旧直连脚本，仅作回退（守护进程起不来时用） |
| `~/.claude/hooks/notify.sh.bak.20261113` | 优化前原版，回滚用 |
| `D:\Temp\claude-toast\` | 队列目录：`req-*.req`、`heartbeat`、`daemon.pid`、`toastd.log` |

## 队列协议（避免 JSON 转义，纯两行文本）

`req-<纳秒>-<pid>.req`，UTF-8：

```
第一行 = 标题
第二行 = 正文
```

撤通知写 `__remove__` + 空行。先写 `.tmp-*` 再 `mv` 成 `.req`，保证不读到半截文件。

## 生命周期

- 由 `notify.sh` 按需拉起：`heartbeat` 的 mtime 超过 20 s 视为死掉，自动重启。
- 心跳每轮循环刷新（≤1.5 s），**空闲时也不会被误判为死掉**（这是第一版的坑，已修）。
- 用 `Start-Process -WindowStyle Hidden` 启动，脱离 WSL 控制台，终端关掉不会连带杀死它。
- 互斥量 `Local\ClaudeToastDaemon` 保证单实例。
- 空闲 720 分钟自动退出，下次通知再拉起。

## 实测（同一会话内）

| 场景 | 优化前 | 优化后 |
| --- | --- | --- |
| hook 入队返回 | 62–86 ms（但弹窗还在 1 s 后） | 31–55 ms（弹窗已出） |
| 弹窗真正出现 | 750–970 ms | ≈ 入队时间 + 30–60 ms |
| 撤通知 | 再冷启动 ≈800 ms | 同一条路径，≈同上 |
| 空闲 35 s 后再发 | — | 55 ms（守护进程存活） |

## 常用命令

```bash
# 状态
cat /mnt/d/Temp/claude-toast/daemon.pid
tail -20 /mnt/d/Temp/claude-toast/toastd.log

# 手动测一条
printf '%s' '{"notification_type":"permission_prompt","message":"test","cwd":"/path/to/project"}' \
  | ~/.claude/hooks/notify.sh

# 手动撤
~/.claude/hooks/notify.sh dismiss

# 停掉守护进程
powershell.exe -NoProfile -Command "Get-WmiObject Win32_Process -Filter \"Name='powershell.exe'\" | Where-Object { \$_.CommandLine -like '*-File *toastd.ps1*' } | ForEach-Object { Stop-Process -Id \$_.ProcessId -Force }"
```

## 回滚

```bash
cp ~/.claude/hooks/notify.sh.bak.20261113 ~/.claude/hooks/notify.sh
chmod +x ~/.claude/hooks/notify.sh
# 再按上面的命令停掉守护进程
```

## 排障

- **完全收不到**：Windows 设置 → 系统 → 通知，确认通知开着、专注助手没开；`toastd.log` 里出现 `ERR` 说明 WinRT 失败，会退回 `toast.ps1`。
- **有延迟**：看 `daemon.pid` 的进程是否活着、`heartbeat` 是否在 20 s 内；不新鲜就是在冷启动。
- **重复弹**：确认只有一个 `-File *toastd.ps1*` 进程，按上面的命令全停掉再让它自启。
- **不要**为了"稳定"去关 UAC 或改 `PromptOnSecureDesktop`——这条链路跟 UAC 无关。

## 附：sudo 现状

```
$ sudo -n true; echo $?
0
$ sudo -n -l
    (ALL : ALL) ALL
    (ALL) NOPASSWD: ALL
```

免密 = 任何以 `losangelous` 身份运行的进程都能直接拿到 root。若能接受收窄，建议改成
`NOPASSWD` 白名单（只列真正要用的命令）；需要的话我可以按你实际用到的命令生成一份。
