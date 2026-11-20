#!/usr/bin/env bash
# 把 configs/claude/ 部署到 Claude Code 配置目录（默认 ~/.claude）。
#
# 用法：
#   ./scripts/install-claude-config.sh            # 部署
#   CLAUDE_CONFIG_DIR=/tmp/cc ./scripts/install-claude-config.sh
#   ./scripts/install-claude-config.sh --dry-run  # 只显示将要做什么
#
# 幂等：内容相同则跳过；覆盖前备份为 *.losskill.bak。
# agents 不存副本，从 skills/dev-workflow/references/ 生成，避免多处漂移。

set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
src_root="$repo_root/configs/claude"
dst_root="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
dry_run=0

for arg in "$@"; do
  case "$arg" in
    --dry-run) dry_run=1 ;;
    -h|--help) sed -n '2,11p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "Unknown argument: $arg" >&2; exit 2 ;;
  esac
done

[ -d "$src_root" ] || { echo "Error: $src_root not found" >&2; exit 1; }

install_file() {
  local src="$1" dst="$2" mode="${3:-644}" label="${4:-$2}"
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
  chmod "$mode" "$dst"
}

echo "Repo  : $repo_root"
echo "Target: $dst_root"
[ "$dry_run" -eq 1 ] && echo "Mode  : dry-run（不会写入）"
echo

install_file "$src_root/settings.json"                "$dst_root/settings.json"                644 "settings.json"
install_file "$src_root/statusline.py"                "$dst_root/statusline.py"                755 "statusline.py"
install_file "$src_root/themes/catppuccin-mocha.json" "$dst_root/themes/catppuccin-mocha.json" 644 "themes/catppuccin-mocha.json"

for f in notify.sh toast.ps1 toastd.ps1 README-toast.md; do
  [ -f "$src_root/hooks/$f" ] || continue
  mode=644
  [ "$f" = "notify.sh" ] && mode=755
  install_file "$src_root/hooks/$f" "$dst_root/hooks/$f" "$mode" "hooks/$f"
done

# agents：角色正文只有一份，位于 skills/dev-workflow/references/
gen_agent() {
  local name="$1" desc="$2" tools="$3" body="$4"
  local body_path="$repo_root/skills/dev-workflow/references/$body"
  if [ ! -f "$body_path" ]; then
    echo "  [warn] 缺少角色文件：$body_path" >&2
    return 0
  fi
  local tmp
  tmp="$(mktemp)"
  {
    printf -- '---\n'
    printf 'name: %s\n' "$name"
    printf 'description: %s\n' "$desc"
    printf 'tools: %s\n' "$tools"
    printf -- '---\n\n'
    cat "$body_path"
  } >"$tmp"
  install_file "$tmp" "$dst_root/agents/$name.md" 644 "agents/$name.md"
  rm -f "$tmp"
}

gen_agent doc-agent \
  '需求受理与开发文档维护：确认文档根目录、产出 CR 需求卡、R/AC/任务、影响分析与 STATUS。只读调研并写文档，不写业务代码、不做评审。用于新需求、需求变更、文档审计。' \
  'Read, Grep, Glob, Bash, Write, Edit, WebFetch, WebSearch' \
  '01-doc-agent.md'

gen_agent dev-agent \
  '按已确认的开发文档实现任务：读 DoR/AC，改代码、跑验证、更新任务状态并交付 G2 报告。用于 G1 确认后的功能实现或评审返工。' \
  'Read, Write, Edit, Bash, Grep, Glob' \
  '02-dev-agent.md'

gen_agent review-agent \
  '独立评审 Dev 改动：按影响面跑回归、逐条判定 AC、找缺陷并给 G3 结论。只读代码与运行验证，不改代码、不采信 Dev 自述。用于 G2 完成后的评审。' \
  'Read, Grep, Glob, Bash' \
  '03-review-agent.md'

gen_agent meta-review-agent \
  '全链路总审：独立复核文档、实现、评审、流程与结果层，做 UAT 与成功指标验收，给 G4 结论和分层返工指令。用于 G3 通过后的总审。' \
  'Read, Grep, Glob, Bash' \
  '04-meta-review-agent.md'

echo
echo "Claude 配置部署完成。重启 Claude Code 后生效。"
