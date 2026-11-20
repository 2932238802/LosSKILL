#!/usr/bin/env bash
# 为一个项目接入常驻规则：生成 AGENTS.md / CLAUDE.md，并在本仓库登记 L2 项目卡。
#
# 用法：
#   ./scripts/bootstrap-project.sh /path/to/Project
#   ./scripts/bootstrap-project.sh /path/to/Project --name Forus --stack "Rust + Vue" \
#       --verify "cargo test && npm run build" --docs docs
#
# 选项：
#   --name NAME       项目名（默认取目录名）
#   --slug SLUG       L2 文件名（默认由 name 转小写 kebab-case）
#   --stack TEXT      技术栈（默认待补充）
#   --verify CMD      默认验证命令（默认待补充）
#   --docs DIR        文档根目录（默认「待确认」）
#   --force           覆盖已存在的文件（先备份为 *.losskill.bak）
#   --dry-run         只打印动作
#   -h, --help        帮助

set -euo pipefail
# Bash 5.2+ 默认会把替换串里的 & 当成「匹配内容」；这里关掉，保证命令原样写入
shopt -u patsub_replacement 2>/dev/null || true

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
template_dir="$repo_root/templates/project"
l2_dir="$repo_root/skills/leverage-protocol/references/projects"

usage() { sed -n '2,18p' "$0" | sed 's/^# \{0,1\}//'; }

project_path=""
name=""
slug=""
stack="待补充"
verify_cmd="待补充"
docs="待确认（用 dev-workflow 的 G0 确认）"
force=0
dry_run=0

while [ "$#" -gt 0 ]; do
  case "$1" in
    --name)   [ "$#" -ge 2 ] || { echo "Error: --name 需要内容" >&2; exit 2; }; name="$2"; shift ;;
    --slug)   [ "$#" -ge 2 ] || { echo "Error: --slug 需要内容" >&2; exit 2; }; slug="$2"; shift ;;
    --stack)  [ "$#" -ge 2 ] || { echo "Error: --stack 需要内容" >&2; exit 2; }; stack="$2"; shift ;;
    --verify) [ "$#" -ge 2 ] || { echo "Error: --verify 需要内容" >&2; exit 2; }; verify_cmd="$2"; shift ;;
    --docs)   [ "$#" -ge 2 ] || { echo "Error: --docs 需要内容" >&2; exit 2; }; docs="$2"; shift ;;
    --force|-f) force=1 ;;
    --dry-run) dry_run=1 ;;
    -h|--help) usage; exit 0 ;;
    -*) echo "Error: 未知选项 $1" >&2; exit 2 ;;
    *)
      if [ -z "$project_path" ]; then project_path="$1"; else echo "Error: 多余参数 $1" >&2; exit 2; fi
      ;;
  esac
  shift
done

[ -n "$project_path" ] || { echo "Error: 缺少项目路径" >&2; usage; exit 2; }
[ -d "$project_path" ] || { echo "Error: 项目目录不存在：$project_path" >&2; exit 1; }
project_abs="$(cd "$project_path" && pwd)"
[ -n "$name" ] || name="$(basename "$project_abs")"

if [ -z "$slug" ]; then
  slug="$(printf '%s' "$name" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/-/g; s/^-+//; s/-+$//')"
  [ -n "$slug" ] || slug="project"
fi
printf '%s' "$slug" | grep -qE '^[a-z0-9]+(-[a-z0-9]+)*$' || {
  echo "Error: slug 必须是 kebab-case：$slug（用 --slug 指定）" >&2; exit 2
}

[ -d "$template_dir" ] || { echo "Error: $template_dir not found" >&2; exit 1; }

l2_path="$l2_dir/$slug.md"
today="$(date +%F)"

render() {
  local content
  content="$(cat "$1")"
  content="${content//'{{PROJECT_NAME}}'/$name}"
  content="${content//'{{PROJECT_PATH}}'/$project_abs}"
  content="${content//'{{STACK}}'/$stack}"
  content="${content//'{{VERIFY_CMD}}'/$verify_cmd}"
  content="${content//'{{DOC_ROOT}}'/$docs}"
  content="${content//'{{L2_PATH}}'/$l2_path}"
  content="${content//'{{LOSSKILL_PATH}}'/$repo_root}"
  content="${content//'{{DATE}}'/$today}"
  printf '%s\n' "$content"
}

write_file() {
  local src="$1" dst="$2"
  if [ -e "$dst" ]; then
    if [ "$force" -ne 1 ]; then
      echo "  [skip] $dst 已存在（--force 覆盖并备份）"
      return 0
    fi
    echo "  [backup] $dst -> $dst.losskill.bak"
    [ "$dry_run" -eq 1 ] || cp -a "$dst" "$dst.losskill.bak"
  fi
  echo "  [write] $dst"
  [ "$dry_run" -eq 1 ] && return 0
  mkdir -p "$(dirname "$dst")"
  render "$src" > "$dst"
}

echo "Project: $project_abs"
echo "Name   : $name"
echo "Slug   : $slug"
echo "L2     : $l2_dir/$slug.md"
[ "$dry_run" -eq 1 ] && echo "Mode   : dry-run（不会写入）"
echo

write_file "$template_dir/AGENTS.md" "$project_abs/AGENTS.md"
write_file "$template_dir/CLAUDE.md" "$project_abs/CLAUDE.md"
write_file "$template_dir/PROJECT_BRAIN.md" "$project_abs/PROJECT_BRAIN.md"
# 台账 append-only：即使 --force 也不覆盖已有授权记录
if [ -e "$project_abs/AUTHORIZATIONS.md" ]; then
  echo "  [skip] $project_abs/AUTHORIZATIONS.md 已存在（台账只追加，不覆盖）"
else
  write_file "$template_dir/AUTHORIZATIONS.md" "$project_abs/AUTHORIZATIONS.md"
fi
write_file "$template_dir/L2.md" "$l2_dir/$slug.md"

echo
echo "完成。下一步："
echo "  1. 补全 $project_abs/PROJECT_BRAIN.md 的架构、不变量、验证命令"
echo "  2. 补全 $project_abs/AGENTS.md 的雷区与指针"
echo "  3. 在 $project_abs/AUTHORIZATIONS.md 确认本轮范围信封（G1 时由用户批准）"
echo "  4. 补全 $l2_dir/$slug.md 的项目专属信号"
echo "  5. 新开 Claude Code 会话让 @AGENTS.md 生效"
