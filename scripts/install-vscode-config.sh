#!/usr/bin/env bash
# 部署 configs/vscode/ 到 VS Code 用户配置目录。
#
# 用法：
#   ./scripts/install-vscode-config.sh                    # 自动探测并部署 settings/keybindings
#   ./scripts/install-vscode-config.sh --dir /path/User   # 显式指定用户目录
#   ./scripts/install-vscode-config.sh --with-extensions  # 额外安装 extensions.txt（联网）
#   ./scripts/install-vscode-config.sh --dry-run
#
# 说明：settings.json 是原样备份，可能含机器专属路径（如 clangd.path）；
# 恢复后请按目标机器删改。扩展默认不安装，需显式 --with-extensions。

set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
src_dir="$repo_root/configs/vscode"
user_dir=""
with_extensions=0
dry_run=0

usage() {
  # 截取开头连续注释块（直到第一行代码），不依赖固定行号（设计 §6.4）
  awk '
    NR == 1 { next }
    /^#/ { while (pending > 0) { print ""; pending-- }
           line = $0; sub(/^# ?/, "", line); print line; started = 1; next }
    /^[[:space:]]*$/ { if (started) pending++; next }
    { exit }
  ' "$0"
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --dir)
      [ "$#" -ge 2 ] || { echo "Error: --dir 需要目录" >&2; exit 2; }
      user_dir="$2"; shift 2 ;;
    --with-extensions)
      with_extensions=1; shift ;;
    --dry-run)
      dry_run=1; shift ;;
    -h|--help)
      usage; exit 0 ;;
    *)
      echo "Unknown argument: $1" >&2; exit 2 ;;
  esac
done

[ -d "$src_dir" ] || { echo "Error: $src_dir not found" >&2; exit 1; }

detect_user_dir() {
  if grep -qi Microsoft /proc/version 2>/dev/null; then
    if command -v cmd.exe >/dev/null 2>&1 && command -v wslpath >/dev/null 2>&1; then
      local appdata
      appdata="$(cmd.exe /c 'echo %APPDATA%' 2>/dev/null | tr -d '\r')"
      if [ -n "$appdata" ]; then
        printf '%s/Code/User' "$(wslpath -u "$appdata")"
        return 0
      fi
    fi
    return 1
  fi
  case "$(uname -s)" in
    Darwin) printf '%s/Library/Application Support/Code/User' "$HOME" ;;
    *)      printf '%s/Code/User' "${XDG_CONFIG_HOME:-$HOME/.config}" ;;
  esac
}

if [ -z "$user_dir" ]; then
  user_dir="$(detect_user_dir)" || {
    echo "未找到 VS Code 用户目录。请用 --dir 指定，例如：" >&2
    echo "  --dir /mnt/c/Users/<WindowsUser>/AppData/Roaming/Code/User" >&2
    exit 1
  }
fi

install_file() {
  local src="$1" dst="$2" label="$3"
  if [ -e "$dst" ] && cmp -s "$src" "$dst"; then
    echo "  [skip] $label 已是最新"
    return 0
  fi
  if [ -e "$dst" ]; then
    echo "  [backup] $dst -> $dst.losskill.bak"
    [ "$dry_run" -eq 1 ] || cp -a "$dst" "$dst.losskill.bak"
  else
    echo "  [add] $label"
  fi
  [ "$dry_run" -eq 1 ] && return 0
  mkdir -p "$(dirname "$dst")"
  cp "$src" "$dst"
  chmod 644 "$dst" 2>/dev/null || true
}

echo "Repo  : $repo_root"
echo "Target: $user_dir"
[ "$dry_run" -eq 1 ] && echo "Mode  : dry-run（不会写入）"
echo

install_file "$src_dir/settings.json"   "$user_dir/settings.json"   "settings.json"
install_file "$src_dir/keybindings.json" "$user_dir/keybindings.json" "keybindings.json"

if [ "$with_extensions" -eq 1 ]; then
  if ! command -v code >/dev/null 2>&1; then
    echo "  [warn] 未找到 code 命令，跳过扩展安装" >&2
  else
    count=0
    while IFS= read -r id; do
      [ -z "$id" ] && continue
      echo "  [extension] $id"
      [ "$dry_run" -eq 1 ] || code --install-extension "$id" --force >/dev/null 2>&1 || \
        echo "    [warn] 安装失败：$id" >&2
      count=$((count + 1))
    done < "$src_dir/extensions.txt"
    echo "  扩展处理：$count 个"
  fi
fi

echo
echo "VS Code 配置部署完成。设置含机器专属路径时请按目标机器修改。"
