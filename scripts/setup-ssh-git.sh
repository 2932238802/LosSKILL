#!/usr/bin/env bash
# 只做一件事：把 Git 提交方式切到 SSH，并把公钥送去 GitHub。
#
# 行为：
#   1. 已有 ~/.ssh/id_ed25519 就复用（不重建、不覆盖）
#   2. 缺密钥才生成（默认注释用 SSH_EMAIL，默认 19857198709@163.com）
#   3. 公钥注释里已经带着该邮箱 → 认为「已加过 GitHub」，不再提示粘贴
#   4. 可选：把当前仓库的 origin 从 https:// 改成 git@（只改 remote，不动历史）
#
# 用法：
#   ./scripts/setup-ssh-git.sh
#   SSH_EMAIL=me@example.com ./scripts/setup-ssh-git.sh

set -uo pipefail

SSH_KEY_PATH="$HOME/.ssh/id_ed25519"
SSH_KEY_PUB="$SSH_KEY_PATH.pub"
SSH_EMAIL="${SSH_EMAIL:-19857198709@163.com}"
GITHUB_KEYS_URL="https://github.com/settings/keys"

echo "=== Git over SSH 初始化 ==="

# ---------- 1. 密钥 ----------
mkdir -p "$HOME/.ssh" && chmod 700 "$HOME/.ssh"
if [ -f "$SSH_KEY_PATH" ]; then
    echo "✓ 已存在 SSH 私钥：$SSH_KEY_PATH（复用，不重建）"
else
    echo "🔑 未找到密钥，生成 ed25519（注释：$SSH_EMAIL）"
    ssh-keygen -t ed25519 -C "$SSH_EMAIL" -f "$SSH_KEY_PATH" -N ""
fi

if [ ! -f "$SSH_KEY_PUB" ]; then
    echo "⚠️ 找不到公钥 $SSH_KEY_PUB，无法继续（私钥可能不完整）" >&2
    exit 1
fi
chmod 644 "$SSH_KEY_PUB"

# ---------- 2. 是否需要去 GitHub 添加 ----------
pub_content="$(cat "$SSH_KEY_PUB")"
if printf '%s' "$pub_content" | grep -qF "$SSH_EMAIL"; then
    echo "✓ 公钥注释已是 $SSH_EMAIL —— 视为已加入 GitHub，跳过粘贴提示"
else
    echo
    echo "=== 把这行公钥加到 GitHub ==="
    echo "页面：$GITHUB_KEYS_URL"
    echo "-------------------------------------------------------------"
    echo "$pub_content"
    echo "-------------------------------------------------------------"
fi

# ---------- 3. 验证连通性（可选，5 秒超时） ----------
if command -v timeout >/dev/null 2>&1; then
    out="$(timeout 5 ssh -o StrictHostKeyChecking=accept-new -o BatchMode=yes -T git@github.com 2>&1 || true)"
    if printf '%s' "$out" | grep -qi "successfully authenticated"; then
        echo "✓ SSH 认证成功：$(printf '%s' "$out" | head -1)"
    elif printf '%s' "$out" | grep -qi "permission denied"; then
        echo "⚠️ GitHub 还认不出这个密钥（多半是公钥还没加上去，或加到了别的账号）"
    else
        echo "· 连通性未确认（离线或被墙属正常，不影响本地 commit）"
    fi
fi

# ---------- 4. 当前仓库是否切成 SSH ----------
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    cur="$(git remote get-url origin 2>/dev/null || true)"
    if [ -n "$cur" ]; then
        case "$cur" in
            https://github.com/*)
                ssh_url="$(printf '%s' "$cur" | sed -E 's#https://github.com/#git@github.com:#')"
                read -r -p "把 origin 从 HTTPS 改成 SSH？[$cur -> $ssh_url] [y/N] " -n 1 -r
                echo
                if [[ "${REPLY:-}" =~ ^[Yy]$ ]]; then
                    git remote set-url origin "$ssh_url"
                    echo "✓ origin -> $ssh_url"
                fi
                ;;
            git@github.com:*)
                echo "✓ origin 已经是 SSH：$cur"
                ;;
            *)
                echo "· origin 不是 GitHub：$cur（未改动）"
                ;;
        esac
    fi
else
    echo "· 当前目录不是 Git 仓库；克隆时直接用 git clone git@github.com:USER/REPO.git 即可"
fi
