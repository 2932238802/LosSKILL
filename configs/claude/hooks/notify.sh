#!/usr/bin/env bash
# Claude Code hook:
#   notify.sh          -> 弹 Windows 通知（Notification 事件）
#   notify.sh dismiss  -> 撤掉通知（PreToolUse / PermissionDenied / Stop / UserPromptSubmit）
#
# 2026-11-13 优化：不再每条通知冷启动 PowerShell（原来 800-1000ms）。
# 改为把请求写进队列目录，由常驻 toastd.ps1（FileSystemWatcher）立刻弹出，约 30-80ms。
# 守护进程没起来会自动拉起（Start-Process 脱离控制台，避免随终端关闭被杀）；
# 拉起失败则回退到旧的 toast.ps1 直连方式。
set -u

# 队列目录；改盘符时要与 toastd.ps1 保持一致（Windows 侧不会自动继承 WSL 环境变量）
QDIR="${CLAUDE_TOAST_DIR:-/mnt/d/Temp/claude-toast}"
HB="$QDIR/heartbeat"
MARKER="${TMPDIR:-/tmp}/claude-notify-active"
PS1="$HOME/.claude/hooks/toast.ps1"
DAEMON="$HOME/.claude/hooks/toastd.ps1"
TAG="claude-code"

daemon_alive() {
  [ -f "$HB" ] || return 1
  local now mtime
  now=$(date +%s)
  mtime=$(stat -c %Y "$HB" 2>/dev/null) || return 1
  [ $((now - mtime)) -lt 20 ]
}

start_daemon() {
  local p i
  [ -f "$DAEMON" ] || return 1
  p=$(wslpath -w "$DAEMON" 2>/dev/null) || return 1
  powershell.exe -NoProfile -Command "Start-Process -WindowStyle Hidden -FilePath 'powershell.exe' -ArgumentList @('-NoProfile','-ExecutionPolicy','Bypass','-File','$p')" >/dev/null 2>&1
  i=0
  while [ "$i" -lt 40 ]; do
    daemon_alive && return 0
    sleep 0.1
    i=$((i + 1))
  done
  return 1
}

enqueue() {
  local tmp f
  mkdir -p "$QDIR" 2>/dev/null || return 1
  tmp="$QDIR/.tmp-$$-$RANDOM"
  printf '%s\n%s\n' "$1" "$2" >"$tmp" 2>/dev/null || return 1
  f="$QDIR/req-$(date +%s%N)-$$.req"
  mv -f "$tmp" "$f" 2>/dev/null || return 1
}

legacy_ps() {
  local p
  p=$(wslpath -w "$PS1" 2>/dev/null) || return 0
  powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "$p" "$@" >/dev/null 2>&1 &
}

if [ "${1:-}" = "dismiss" ]; then
  [ -f "$MARKER" ] || exit 0
  rm -f "$MARKER"
  if daemon_alive; then
    enqueue "__remove__" ""
  else
    legacy_ps -Remove -Tag "$TAG" -Group claude
  fi
  exit 0
fi

payload=$(cat)

t=""; msg=""; cwd=""
[[ $payload =~ \"notification_type\"[[:space:]]*:[[:space:]]*\"([^\"]*)\" ]] && t="${BASH_REMATCH[1]}"
[[ $payload =~ \"message\"[[:space:]]*:[[:space:]]*\"([^\"]*)\" ]] && msg="${BASH_REMATCH[1]}"
[[ $payload =~ \"cwd\"[[:space:]]*:[[:space:]]*\"([^\"]*)\" ]] && cwd="${BASH_REMATCH[1]}"

case "$t" in
  permission_prompt) label="需要你授权" ;;
  idle_prompt) label="在等你输入" ;;
  agent_needs_input) label="子代理在等你输入" ;;
  agent_completed) label="子代理已完成" ;;
  elicitation_dialog) label="需要你填写信息" ;;
  quota_auto_resume_fired) label="额度恢复，自动继续" ;;
  *) label="需要你的操作" ;;
esac

proj="claude"
[ -n "$cwd" ] && proj="${cwd##*/}"
[ -z "$proj" ] && proj="claude"

msg=$(printf '%s' "$msg" | tr -s '[:space:]' ' ')
msg="${msg:0:180}"

title="Claude Code · ${proj}"
if [ -n "$msg" ]; then
  body="${label}：${msg}"
else
  body="${label}"
fi

: >"$MARKER"
if daemon_alive || start_daemon; then
  enqueue "$title" "$body"
else
  legacy_ps -Title "$title" -Body "$body" -Tag "$TAG" -Group claude
fi

seq=$(printf '\a\033]9;%s\a' "$title")
esc=${seq//\\/\\\\}
esc=${esc//\"/\\\"}
printf '{"terminalSequence":"%s"}' "$esc"
exit 0