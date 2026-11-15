#!/usr/bin/env bash
# LosSKILL 一键总入口：新电脑 git clone 之后，一条命令恢复全部环境。
#
# 流程：技能安装 → 个人环境配置 → SSH → dsh 插件 → 自检
#
# 用法：
#   ./setup.sh                 # 全流程（环境配置走交互式询问）
#   ./setup.sh --yes           # 全流程，环境配置直接 yes（新电脑首选）
#   ./setup.sh --with-blesh    # 全流程 + 额外安装 ble.sh（实时历史候选）
#   ./setup.sh --validate-only # 只自检
#
# 可单独跑某一步：
#   ./scripts/install.sh
#   ./scripts/setup-ssh-git.sh
#   ./scripts/install-dsh-plugins.sh
#   ./scripts/install-blesh.sh
#   ./scripts/validate.sh

set -uo pipefail
cd "$(dirname "$0")"

env_opt=""
with_blesh=0
only_validate=0
for a in "$@"; do
    case "$a" in
        --yes) env_opt="yes" ;;
        --with-blesh) with_blesh=1 ;;
        --validate-only) only_validate=1 ;;
        -h|--help) sed -n '2,22p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *) echo "未知参数：$a（见 --help）" >&2; exit 2 ;;
    esac
done

step() { printf '\n\033[1;36m== %s ==\033[0m\n' "$1"; }
ok()   { printf '  ✅ %s\n' "$1"; }

if [ "$only_validate" -eq 1 ]; then
    step "自检"
    ./scripts/validate.sh
    exit $?
fi

step "1/5 安装 AI Skills + 个人环境配置"
if [ -n "$env_opt" ]; then
    LOSSKILL_ENV="$env_opt" ./scripts/install.sh
else
    ./scripts/install.sh
fi
ok "技能与环境配置完成"

step "2/5 SSH（GitHub 提交方式）"
# 非交互跑：origin 是否切 SSH 保持默认不改，只处理密钥与提示
./scripts/setup-ssh-git.sh </dev/null || true
ok "SSH 处理完成"

step "3/5 dsh 插件"
if command -v node >/dev/null 2>&1 && [ -d "$HOME/.dsh/profiles" ]; then
    ./scripts/install-dsh-plugins.sh || true
else
    echo "  跳过：未检测到 dsh profile（先安装并启动过一次 dsh web 再跑）"
fi

if [ "$with_blesh" -eq 1 ]; then
    step "3.5/5 ble.sh（实时历史候选，可选）"
    ./scripts/install-blesh.sh || true
fi

step "4/5 自检"
./scripts/validate.sh

step "5/5 收尾提示"
echo "  · 开新终端（或 source ~/.bashrc）让 oh-my-posh / 历史配置生效"
echo "  · 若第 2 步提示公钥，去 https://github.com/settings/keys 粘贴一次即可"
echo "  · dsh 插件生效需重启 dsh web 进程，或刷新 http://127.0.0.1:3080"
echo
echo "全部完成 🎉"
