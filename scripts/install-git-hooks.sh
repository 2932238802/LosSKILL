#!/usr/bin/env bash
# 启用仓库自带的 Git hooks（当前只有一个 pre-commit：跑 validate.sh）。
#
# 用法：
#   ./scripts/install-git-hooks.sh              # 启用
#   ./scripts/install-git-hooks.sh --uninstall  # 取消 core.hooksPath

set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"

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

if [ ! -d "$repo_root/.git" ] && ! git -C "$repo_root" rev-parse --git-dir >/dev/null 2>&1; then
  echo "Not a git checkout: $repo_root" >&2
  exit 0
fi

case "${1:-}" in
  --uninstall)
    git -C "$repo_root" config --unset core.hooksPath 2>/dev/null || true
    echo "已取消 core.hooksPath（恢复 Git 默认 hooks）"
    exit 0 ;;
  "") ;;
  -h|--help)
    usage; exit 0 ;;
  *)
    echo "Unknown argument: $1" >&2; exit 2 ;;
esac

if [ ! -f "$repo_root/.githooks/pre-commit" ]; then
  echo "Error: .githooks/pre-commit not found" >&2
  exit 1
fi

chmod +x "$repo_root/.githooks/"* 2>/dev/null || true
git -C "$repo_root" config core.hooksPath .githooks
echo "✅ pre-commit 自检已启用（core.hooksPath=.githooks）"
echo "   提交前会运行 ./scripts/validate.sh；跳过用 git commit --no-verify"
