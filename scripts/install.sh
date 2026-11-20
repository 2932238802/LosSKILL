#!/usr/bin/env bash
# Install skills from the LosSKILL repo into a target skills directory.
# Copy only: no network access, and nothing inside a skill is executed.
#
# Usage:
#   ./scripts/install.sh                       # all skills -> default target
#   ./scripts/install.sh sandra-sales          # one skill (or a,b,c)
#   ./scripts/install.sh all ~/.claude/skills  # explicit target
#
# Default target: $HOME/.dsh/skills (override with LOSSKILL_TARGET)
# Works with bash 3.2+ (macOS default), no external deps beyond find/coreutils.

set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
source_root="$repo_root/skills"

if [ ! -d "$source_root" ]; then
  echo "Error: $source_root not found" >&2
  exit 1
fi

skill="${1:-all}"
target="${2:-${LOSSKILL_TARGET:-$HOME/.dsh/skills}}"

# Installable skills: sub-directories that contain SKILL.md
available=()
while IFS= read -r dir; do
  if [ -n "$dir" ] && [ -f "$dir/SKILL.md" ]; then
    available[${#available[@]}]="$(basename "$dir")"
  fi
done < <(find "$source_root" -mindepth 1 -maxdepth 1 -type d | sort)

if [ "${#available[@]}" -eq 0 ]; then
  echo "Error: no installable skill found under $source_root" >&2
  exit 1
fi

names=()
if [ "$skill" = "all" ]; then
  names=("${available[@]}")
else
  IFS=',' read -r -a raw <<< "$skill"
  for item in "${raw[@]}"; do
    name="$(echo "$item" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')"
    [ -z "$name" ] && continue
    found=0
    for a in "${available[@]}"; do
      if [ "$a" = "$name" ]; then found=1; fi
    done
    if [ "$found" -eq 0 ]; then
      echo "Error: unknown skill '$name'. Available: ${available[*]}" >&2
      exit 1
    fi
    names[${#names[@]}]="$name"
  done
fi

if [ "${#names[@]}" -eq 0 ]; then
  echo "Error: nothing to install" >&2
  exit 1
fi

mkdir -p "$target"
echo "Repo  : $repo_root"
echo "Target: $target"
echo

installed=0
skipped=0
for name in "${names[@]}"; do
  src="$source_root/$name"
  dst="$target/$name"

  if [ -e "$dst" ]; then
    echo "  Already exists, skipped: $dst (remove it first to reinstall)" >&2
    skipped=$((skipped + 1))
    continue
  fi

  cp -R "$src" "$dst"
  count="$(find "$dst" -type f | wc -l | tr -d ' ')"
  echo "  [OK] $name ($count files)"
  installed=$((installed + 1))
done

echo
echo "Done: $installed installed, $skipped skipped."

# --- Additional: Personal environment configuration (optional)
# 支持环境变量跳过交互：LOSSKILL_ENV=yes 直接应用 / no 跳过
if [ "${LOSSKILL_ENV:-}" = "yes" ]; then
    REPLY="y"
elif [ "${LOSSKILL_ENV:-}" = "no" ]; then
    REPLY="n"
else
    read -p "Do you want to install personal environment configurations (configs & software for WSL2/development)? [y/N] " -n 1 -r
    echo
fi
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "Applying personal environment configurations..."

    # ---------- 配置文件部署（带备份，可重复执行） ----------
    backup_if_exists() { [ -e "$1" ] && cp -a "$1" "$1.losskill.bak" 2>/dev/null || true; }

    # git 配置
    if [ -f "$repo_root/configs/.gitconfig" ]; then
        if [ -f "$HOME/.gitconfig" ] && cmp -s "$repo_root/configs/.gitconfig" "$HOME/.gitconfig"; then
            echo "  .gitconfig 已是最新，跳过"
        else
            backup_if_exists "$HOME/.gitconfig"
            cp -f "$repo_root/configs/.gitconfig" "$HOME/.gitconfig"
            echo "  ✅ .gitconfig 已部署（旧文件备份为 ~/.gitconfig.losskill.bak）"
        fi
    fi

    # Neovim：直接 cp -R 到已存在的目录会变成 ~/.config/nvim/nvim，必须拷内容
    if [ -d "$repo_root/configs/nvim" ]; then
        mkdir -p "$HOME/.config/nvim"
        backup_if_exists "$HOME/.config/nvim/init.vim"
        cp -R "$repo_root/configs/nvim/." "$HOME/.config/nvim/"
        echo "  ✅ Neovim 配置已同步到 ~/.config/nvim"
    fi
    
    # Claude Code 配置（settings / hooks / statusline / theme / agents）
    if [ -f "$repo_root/scripts/install-claude-config.sh" ]; then
        echo "  Deploying Claude Code config..."
        bash "$repo_root/scripts/install-claude-config.sh"
    fi

    # --- WSL2/Dev environment setup
    # Detect WSL2 environment
    if grep -qi Microsoft /proc/version; then
        echo "  Detected WSL2 environment, applying WSL-specific development configs"
        
        # Install Oh My Posh (with huvix theme)
        echo "    Installing Oh My Posh..."
        if ! command -v oh-my-posh >/dev/null; then
            sudo apt update && sudo apt install -y unzip fontconfig
            curl -s https://ohmyposh.dev/install.sh | bash -s
        fi
        
        # ---------- Oh My Posh: 固定使用 huvix 主题 ----------
        # 注意：老写法有两个坑，这里都修掉了：
        #   1) grep -q "oh-my-posh init" 会让已存在 kali 主题的用户永远不写 huvix；
        #   2) 下载到 ~/.poshthemes 的 URL 常常 404，导致 --config 指向不存在的文件。
        BASHRC="$HOME/.bashrc"
        OMP_THEME_DIR="$HOME/.config/oh-my-posh/themes"
        OMP_THEME="$OMP_THEME_DIR/huvix.omp.json"
        mkdir -p "$OMP_THEME_DIR"
        if [ ! -f "$OMP_THEME" ]; then
            # oh-my-posh 安装脚本会把全部主题下载到 ~/.cache/oh-my-posh/themes，优先复用
            if [ -f "$HOME/.cache/oh-my-posh/themes/huvix.omp.json" ]; then
                cp -f "$HOME/.cache/oh-my-posh/themes/huvix.omp.json" "$OMP_THEME"
            else
                curl -fsSL --max-time 20 \
                    https://raw.githubusercontent.com/JanDeVisser/oh-my-posh/main/themes/huvix.omp.json \
                    -o "$OMP_THEME" 2>/dev/null || rm -f "$OMP_THEME"
            fi
        fi

        if [ -f "$OMP_THEME" ]; then
            # 清掉所有旧的 oh-my-posh init 行（例如 kali 主题），只保留 LosSKILL 这一段
            sed -i '/oh-my-posh init bash --config/d' "$BASHRC"
            sed -i '/# Oh My Posh terminal theme (huvix)/d' "$BASHRC"
            if ! grep -q "LosSKILL: Oh My Posh (huvix)" "$BASHRC"; then
                cat >> "$BASHRC" << 'OMP_EOF'

# LosSKILL: Oh My Posh (huvix)
if command -v oh-my-posh >/dev/null 2>&1; then
    eval "$(oh-my-posh init bash --config "$HOME/.config/oh-my-posh/themes/huvix.omp.json")"
fi
OMP_EOF
            fi
            echo "    ✅ Oh My Posh 已切换为 huvix 主题（$OMP_THEME）"
        else
            echo "    ⚠️ 未能获取 huvix 主题文件，保留原提示符；可手动执行："
            echo "       cp ~/.cache/oh-my-posh/themes/huvix.omp.json $OMP_THEME"
        fi
        
        # Install C++ development tools (build-essential)
        echo "    Installing C++ development tools..."
        sudo apt install -y build-essential g++ gcc make
        
        # Install Rust
        echo "    Installing Rust language..."
        if ! command -v rustup >/dev/null; then
            curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
            # Add Rust to current session PATH
            source "$HOME/.cargo/env"
        fi
        
        # Install Chinese language pack for WSL2
        echo "    Installing Chinese language pack for WSL2..."
        sudo apt install -y language-pack-zh-hans language-pack-zh-hans-base
        # Set default locale to Chinese (optional)
        if ! grep -q "LANG=zh_CN.UTF-8" /etc/default/locale; then
            echo "LANG=zh_CN.UTF-8" | sudo tee -a /etc/default/locale
            echo "    ✅ Default locale set to Chinese"
        fi
        
        # Install fzf for history search (PowerShell-like feature)
        echo "    Installing fzf for history search..."
        if ! command -v fzf >/dev/null; then
            sudo apt install -y fzf
        fi
        
        # Setup SSH key for GitHub - check if exists before creating
        echo "    Setting up SSH key for Git..."
        SSH_EMAIL="${SSH_EMAIL:-19857198709@163.com}"
        SSH_KEY_PATH="$HOME/.ssh/id_ed25519"
        SSH_KEY_PUB="$SSH_KEY_PATH.pub"
        mkdir -p "$HOME/.ssh" && chmod 700 "$HOME/.ssh"
        if [ ! -f "$SSH_KEY_PATH" ]; then
            ssh-keygen -t ed25519 -C "$SSH_EMAIL" -f "$SSH_KEY_PATH" -N ""
            echo "    ✅ 已创建 SSH 密钥（注释：$SSH_EMAIL）"
        else
            echo "    ✅ 已有 SSH 密钥，复用不重建"
        fi
        if [ -f "$SSH_KEY_PUB" ] && grep -qF "$SSH_EMAIL" "$SSH_KEY_PUB"; then
            echo "    ✅ 公钥注释已是 $SSH_EMAIL —— 视为已加入 GitHub，跳过粘贴提示"
        elif [ -f "$SSH_KEY_PUB" ]; then
            echo -e "\n    === 把这行公钥加到 GitHub ==="
            echo "    页面：https://github.com/settings/keys"
            echo "    $(cat "$SSH_KEY_PUB")"
            echo "    ------------------------------------"
        fi
        # ---------- 历史：前缀搜索 + 可视匹配列表 ----------
        # 老写法用 PROMPT_COMMAND + $READLINE_LINE，但 READLINE_LINE 只在
        # bind -x 的上下文里存在，在 PROMPT_COMMAND 里恒为空 → 永远不生效（或每行刷屏）。
        # 这里改成三件真正有效的事：
        #   1) ↑/↓ 只翻「以当前输入开头」的历史
        #   2) Ctrl+X Ctrl+H 打印 <History(N)> 匹配列表
        #   3) Ctrl+R 用 fzf 弹层搜索（没装 fzf 则退回 bash 自带 Ctrl+R）
        BASHRC="$HOME/.bashrc"
        # 先备份，再清掉历史遗留的坏块（旧脚本从标记行一直写到文件末尾）
        cp -f "$BASHRC" "$BASHRC.losskill.bak" 2>/dev/null || true
        if grep -q "PowerShell-like command history suggestion" "$BASHRC"; then
            awk '/# WSL2: PowerShell-like command history suggestion/{drop=1} drop==0{print}' \
                "$BASHRC" > "$BASHRC.tmp" && mv "$BASHRC.tmp" "$BASHRC"
            echo "    🧹 已移除旧的历史提示坏块（备份：$BASHRC.losskill.bak）"
        fi

        if ! grep -q "LosSKILL: history prefix search" "$BASHRC"; then
            cat >> "$BASHRC" << 'HIST_EOF'

# LosSKILL: history prefix search + visible match list
HISTSIZE=100000
HISTFILESIZE=200000
HISTCONTROL=ignoredups:ignorespace
shopt -s histappend

# 输入前缀后按 ↑ / ↓：只翻「以当前输入开头」的历史
bind '"\e[A": history-search-backward'
bind '"\e[B": history-search-forward'

# Ctrl+X Ctrl+H：把以当前输入开头的最近 10 条历史打印成 <History(N)> 列表
__los_hist_list() {
    local pat="${READLINE_LINE:-}" count=10 body n
    body=$(history | sed -E 's/^ *[0-9]+ +//' | grep -F -- "$pat" | awk '!seen[$0]++' | tail -n "$count")
    if [ -z "$body" ]; then
        printf '\n\033[2m<History(0)> no match for "%s"\033[0m\n' "$pat"
        return
    fi
    n=$(printf '%s\n' "$body" | wc -l | tr -d ' ')
    printf '\n\033[1;36m<History(%s)>\033[0m\n' "$n"
    printf '%s\n' "$body" | sed 's/^/  > /'
}
bind -x '"\C-x\C-h": __los_hist_list'

# Ctrl+R：fzf 弹层模糊搜索历史；没有 fzf 就用 bash 自带的增量搜索
if command -v fzf >/dev/null 2>&1; then
    __los_fzf_history() {
        local sel
        sel=$(history | sed -E 's/^ *[0-9]+ +//' | awk '!seen[$0]++' | tac |
              fzf --height=40% --reverse --border --info=inline \
                  --prompt='history> ' --header='<History> Enter 选中，Esc 取消') || return 0
        READLINE_LINE="$sel"
        READLINE_POINT=${#READLINE_LINE}
    }
    bind -x '"\C-r": __los_fzf_history'
else
    bind '"\C-r": reverse-search-history'
fi
HIST_EOF
            echo "    ✅ 历史前缀搜索已配置（↑/↓ 翻匹配、Ctrl+X Ctrl+H 看列表、Ctrl+R 搜索）"
        fi
        
    else
        # Regular Linux: install common dev tools
        echo "  Installing common development tools (curl, git, etc.)"
        if command -v apt >/dev/null; then
            sudo apt update && sudo apt install -y curl git
        elif command -v brew >/dev/null; then
            brew update && brew install curl git
        elif command -v yum >/dev/null; then
            sudo yum install -y curl git
        else
            echo "  No recognized package manager found, skipping basic tool installation"
        fi
        
        # SSH setup (for regular Linux) —— 逻辑与 WSL 分支一致
        echo "  SSH setup:"
        SSH_EMAIL="${SSH_EMAIL:-19857198709@163.com}"
        SSH_KEY_PATH="$HOME/.ssh/id_ed25519"
        SSH_KEY_PUB="$SSH_KEY_PATH.pub"
        mkdir -p "$HOME/.ssh" && chmod 700 "$HOME/.ssh"
        if [ ! -f "$SSH_KEY_PATH" ]; then
            ssh-keygen -t ed25519 -C "$SSH_EMAIL" -f "$SSH_KEY_PATH" -N ""
            echo "    ✅ 已创建 SSH 密钥（注释：$SSH_EMAIL）"
        else
            echo "    ✅ 已有 SSH 密钥，复用不重建"
        fi
        if [ -f "$SSH_KEY_PUB" ] && grep -qF "$SSH_EMAIL" "$SSH_KEY_PUB"; then
            echo "    ✅ 公钥注释已是 $SSH_EMAIL —— 视为已加入 GitHub"
        elif [ -f "$SSH_KEY_PUB" ]; then
            echo "    把公钥加到 GitHub：https://github.com/settings/keys"
            echo "    $(cat "$SSH_KEY_PUB")"
        fi
    fi
    
    echo "Personal environment configuration applied successfully!"
fi

echo "Note: some tools need a session restart or skill list refresh before the new skills appear."
