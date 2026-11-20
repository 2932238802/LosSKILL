#!/usr/bin/env bash
# LosSKILL 一键总入口：新电脑 git clone 之后，一条命令恢复全部环境。
#
# 默认（直接回车）：弹出交互式菜单，用序号勾选要执行哪些步骤。
# 也支持快捷参数，方便脚本/CI 复用：
#   ./setup.sh --yes            # 全部执行，环境配置直接 yes
#   ./setup.sh --with-blesh     # 全部执行 + 额外装 ble.sh
#   ./setup.sh --validate-only  # 只自检

set -uo pipefail
cd "$(dirname "$0")"

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

step() { printf '\n\033[1;36m== %s ==\033[0m\n' "$1"; }
ok()   { printf '  ✅ %s\n' "$1"; }

ITEMS=(
  "安装 AI Skills（自动探测 ~/.claude/skills 或 ~/.dsh/skills）"
  "个人环境 + Claude 配置 + WSL2 增强（中文/oh-my-posh/C++/Rust/历史/SSH）"
  "单独配置 SSH（密钥 + origin 切 SSH，可重复跑）"
  "安装 dsh 插件（npm 直连，幂等）"
  "安装 ble.sh（边打字边列历史候选，可选）"
  "运行自检"
)

run_item() {
  case "$1" in
    0) LOSSKILL_ENV=no  ./scripts/install.sh ;;
    1) LOSSKILL_ENV=yes ./scripts/install.sh ;;
    2) ./scripts/setup-ssh-git.sh </dev/null || true ;;
    3) ./scripts/install-dsh-plugins.sh || true ;;
    4) ./scripts/install-blesh.sh || true ;;
    5) ./scripts/validate.sh ;;
  esac
}

run_all() {
  step "1/5 安装 AI Skills"
  run_item 0
  step "2/5 个人环境 + WSL2 增强"
  run_item 1
  step "3/5 SSH"
  run_item 2
  step "4/5 dsh 插件"
  run_item 3
  step "5/5 自检"
  run_item 5
  echo
  echo "  · 开新终端（或 source ~/.bashrc）让 oh-my-posh / 历史配置生效"
  echo "  · 若第 3 步提示公钥，去 https://github.com/settings/keys 粘贴一次"
  echo "  · dsh 插件生效需重启 dsh web 进程，或刷新 http://127.0.0.1:3080"
  echo
  echo "全部完成 🎉"
}

# ---------- 快捷参数 ----------
for a in "$@"; do
  case "$a" in
    --validate-only) ./scripts/validate.sh; exit $? ;;
    -h|--help) usage; exit 0 ;;
  esac
done
for a in "$@"; do
  case "$a" in
    --with-blesh) run_item 4 ;;
    --yes) ;;
    *) echo "未知参数：$a（见 --help）" >&2; exit 2 ;;
  esac
done
if [ "$#" -gt 0 ]; then
  run_all
  exit $?
fi

# ---------- 交互式菜单 ----------
menu() {
  local -a sel=(0 0 0 0 0 0)
  local input tok i n
  while true; do
    echo
    echo "  LosSKILL 配置菜单"
    echo "  输入序号切换勾选（可多个，空格分隔）｜ a=全选  c=清空  Enter=执行  q=退出"
    echo
    for i in "${!ITEMS[@]}"; do
      mark=" "
      [ "${sel[$i]}" = 1 ] && mark="x"
      printf '   [%s] %d. %s\n' "$mark" "$((i+1))" "${ITEMS[$i]}"
    done
    printf '\n  选择> '
    read -r input || { echo; return 1; }
    case "$input" in
      q|Q) echo "已取消"; return 1 ;;
      "")  break ;;
      a|A) sel=(1 1 1 1 1 1) ;;
      c|C) sel=(0 0 0 0 0 0) ;;
      *)
        for tok in $input; do
          case "$tok" in
            [1-6]) sel[$((tok-1))]=$((1 - ${sel[$((tok-1))]})) ;;
            *) echo "  ⚠️ 忽略无效序号：$tok" ;;
          esac
        done
        ;;
    esac
  done

  n=0
  for i in "${!sel[@]}"; do
    [ "${sel[$i]}" = 1 ] || continue
    n=$((n+1))
    step "[$n] ${ITEMS[$i]}"
    run_item "$i"
  done
  [ "$n" -eq 0 ] && { echo "未选择任何项，退出"; return 1; }

  echo
  echo "  · 开新终端（或 source ~/.bashrc）让 oh-my-posh / 历史配置生效"
  echo "  · dsh 插件生效需重启 dsh web 进程，或刷新 http://127.0.0.1:3080"
  echo
  echo "选择执行完成 ✅"
}

menu
