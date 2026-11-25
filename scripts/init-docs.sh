#!/usr/bin/env bash
# 初始化 docs 树骨架（非破坏性：已存在的文件一律跳过，不覆盖）
#
# 用法：
#   ./scripts/init-docs.sh <文档根目录>
#   ./scripts/init-docs.sh /path/to/project/LosAngelousDocs --name Demo
#   ./scripts/init-docs.sh <文档根目录> --dry-run
#
# 选项：
#   --name NAME   项目名（默认取文档根目录的父目录名）
#   --dry-run     只打印将做什么，不写文件
#   -h, --help    显示本帮助
#
# 产物（均位于 <文档根目录>）：
#   DOCS_CONTRACT.md / STATUS.md / 00-overview.md / 00-requirements-intake.md
#   01-requirements.md / 02-architecture.md / 03-design.md / 04-tasks.md
#   05-decisions.md / CHANGELOG.md / reports/review-index.md
#   reports/archive/ 与 assets/（含 .gitkeep）
#
# 注意：不创建 ci/ 与 reports/ci/，它们由 ci-artifacts MCP 按需生成。

set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
template_dir="$repo_root/templates/project/LosAngelousDocs"

usage() {
  # 截取开头连续注释块（直到第一行代码），不依赖固定行号
  awk '
    NR == 1 { next }
    /^#/ { while (pending > 0) { print ""; pending-- }
           line = $0; sub(/^# ?/, "", line); print line; started = 1; next }
    /^[[:space:]]*$/ { if (started) pending++; next }
    { exit }
  ' "$0"
}

doc_root=""
name=""
dry_run=0

while [ "$#" -gt 0 ]; do
  case "$1" in
    --name)   [ "$#" -ge 2 ] || { echo "Error: --name 需要内容" >&2; exit 2; }; name="$2"; shift ;;
    --dry-run) dry_run=1 ;;
    -h|--help) usage; exit 0 ;;
    -*) echo "Error: 未知选项 $1" >&2; exit 2 ;;
    *)
      if [ -z "$doc_root" ]; then doc_root="$1"; else echo "Error: 多余参数 $1" >&2; exit 2; fi
      ;;
  esac
  shift
done

[ -n "$doc_root" ] || { echo "Error: 缺少文档根目录" >&2; usage >&2; exit 2; }
[ -d "$template_dir" ] || { echo "Error: 模板目录不存在：$template_dir" >&2; exit 1; }

parent="$(dirname "$doc_root")"
[ -d "$parent" ] || { echo "Error: 父目录不存在：$parent" >&2; exit 1; }
doc_root_abs="$(cd "$parent" && pwd)/$(basename "$doc_root")"

if [ -z "$name" ]; then
  name="$(basename "$(dirname "$doc_root_abs")")"
fi

today="$(date +%F)"

files=(
  DOCS_CONTRACT.md
  STATUS.md
  00-overview.md
  00-requirements-intake.md
  01-requirements.md
  02-architecture.md
  03-design.md
  04-tasks.md
  05-decisions.md
  CHANGELOG.md
)
dirs=(
  reports
  reports/archive
  assets
)

echo "docs root: $doc_root_abs"
echo "project  : $name"
[ "$dry_run" -eq 1 ] && echo "mode     : dry-run（不会写入）"
echo

for d in "${dirs[@]}"; do
  if [ -d "$doc_root_abs/$d" ]; then
    echo "  [skip] $d/"
  else
    echo "  [mkdir] $d/"
    [ "$dry_run" -eq 1 ] || mkdir -p "$doc_root_abs/$d"
  fi
done

install_file() {
  local rel="$1" src="$template_dir/$1" dst="$doc_root_abs/$1" content
  if [ -e "$dst" ]; then
    echo "  [skip] $rel"
    return 0
  fi
  echo "  [write] $rel"
  [ "$dry_run" -eq 1 ] && return 0
  mkdir -p "$(dirname "$dst")"
  content="$(cat "$src")"
  content="${content//'{{DATE}}'/$today}"
  content="${content//'{{PROJECT_NAME}}'/$name}"
  printf '%s\n' "$content" > "$dst"
}

for f in "${files[@]}"; do
  install_file "$f"
done
install_file "reports/review-index.md"

ensure_gitkeep() {
  local rel="$1/.gitkeep"
  if [ -e "$doc_root_abs/$rel" ]; then
    echo "  [skip] $rel"
  else
    echo "  [write] $rel"
    [ "$dry_run" -eq 1 ] || touch "$doc_root_abs/$rel"
  fi
}
ensure_gitkeep "reports/archive"
ensure_gitkeep "assets"

echo
echo "完成。下一步："
echo "  1. Doc Agent 填写 00~05（G1 前必须填出真实 CR / R / AC / T）"
echo "  2. G1 前运行：$repo_root/scripts/check-docs.sh \"$doc_root_abs\" --gate g1"
echo "  3. 新增路径：先改 DOCS_CONTRACT.md 并获用户批准，再创建"
