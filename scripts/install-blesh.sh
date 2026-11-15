#!/usr/bin/env bash
# 可选安装 ble.sh（bash 行编辑器）——实现「边打字边列历史候选」，最接近 PowerShell 的
# PSReadLine ListView 预测效果。
#
# 说明：
#   - ble.sh 会接管 readline，因此前面用 bind 绑的 ↑/↓、Ctrl+R、Ctrl+X Ctrl+H 会被替代；
#     ble.sh 自带更完整的历史补全菜单与历史搜索（C-r / M-? 等）。
#   - 体积较大（几十 MB），默认不装；想还原只需删除 ~/.local/share/blesh 和 ~/.blerc，
#     并移除 ~/.bashrc 里的 ble.sh 块。
#
# 用法：
#   ./scripts/install-blesh.sh            # 装 nightly
#   BLESH_VERSION=v0.4.0 ./scripts/install-blesh.sh

set -euo pipefail

BLESH_HOME="${BLESH_HOME:-$HOME/.local/share/blesh}"
VERSION="${BLESH_VERSION:-nightly}"
URL="https://github.com/akinomyoga/ble.sh/releases/download/${VERSION}/ble-${VERSION}.tar.xz"

command -v curl >/dev/null || { echo "需要 curl" >&2; exit 1; }
command -v tar  >/dev/null || { echo "需要 tar" >&2; exit 1; }
command -v xz   >/dev/null || { echo "需要 xz（Ubuntu: sudo apt install -y xz-utils）" >&2; exit 1; }

mkdir -p "$BLESH_HOME"
echo "==> 下载 ble.sh（$VERSION）"
tmp="$(mktemp --suffix=.tar.xz)"
curl -fsSL --max-time 120 "$URL" -o "$tmp"
echo "==> 解压到 $BLESH_HOME"
tar -xJf "$tmp" -C "$BLESH_HOME"
rm -f "$tmp"

ble_entry="$(find "$BLESH_HOME" -maxdepth 3 -name ble.sh -not -path '*/lib/*' -print -quit 2>/dev/null || true)"
if [ -z "$ble_entry" ]; then
    echo "错误：解压后找不到 ble.sh" >&2
    exit 1
fi
echo "==> 找到入口：$ble_entry"

# 写 ble.sh 的配置（历史补全菜单）
cat > "$HOME/.blerc" << 'BLERC'
# LosSKILL: ble.sh 配置（历史补全菜单，仿 PowerShell）
bleopt history_share=1
bleopt complete_auto_history=1
bleopt complete_menu_complete=1
bleopt complete_auto_complete=1
bleopt menu_style=align
bleopt exec_errexit_mark=
BLERC

# 追加 bashrc 加载块（幂等）
BASHRC="$HOME/.bashrc"
if ! grep -q "LosSKILL: ble.sh" "$BASHRC"; then
    cat >> "$BASHRC" << 'BASHRC_EOF'

# LosSKILL: ble.sh（装了才生效；会接管 readline）
if [ -n "$(find "$HOME/.local/share/blesh" -maxdepth 3 -name ble.sh -not -path '*/lib/*' -print -quit 2>/dev/null)" ]; then
    [[ $- == *i* ]] && source "$(find "$HOME/.local/share/blesh" -maxdepth 3 -name ble.sh -not -path '*/lib/*' -print -quit)"
fi
BASHRC_EOF
    echo "==> 已写入 $BASHRC"
else
    echo "==> $BASHRC 已有 ble.sh 块，跳过"
fi

echo
echo "完成。开新终端（或 exec bash -l）后："
echo "  · 敲命令前缀时自动出现历史候选菜单（含 [history] 来源）"
echo "  · C-r 历史搜索；Tab 在候选里循环"
echo "还原：rm -rf ~/.local/share/blesh ~/.blerc，再删掉 ~/.bashrc 里的 ble.sh 块"
