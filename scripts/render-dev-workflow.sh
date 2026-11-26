#!/usr/bin/env bash
# 渲染 dev-workflow 四份角色文件的「共享约定」，并同步 prompts/ 副本。
#
# 单一正文：skills/dev-workflow/references/_shared-conventions.md
# 共享块在 01–04 中用以下标记定位，不要手工编辑标记内内容：
#   <!-- SHARED-CONVENTIONS:BEGIN --> ... <!-- SHARED-CONVENTIONS:END -->
#
# 用法：
#   ./scripts/render-dev-workflow.sh          # 渲染 + 同步 prompts/
#   ./scripts/render-dev-workflow.sh --check  # 只检查；落后则退出码 1
#
# 退出码：0 = 一致（或已渲染）；1 = 有文件落后 / 缺文件

set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
ref_dir="$repo_root/skills/dev-workflow/references"
src="$ref_dir/_shared-conventions.md"
prompts_dir="$repo_root/prompts/dev-workflow"
roles=(01-doc-agent.md 02-dev-agent.md 03-review-agent.md 04-meta-review-agent.md)
plain=(05-context-protocol.md 06-authorization.md 07-speed.md)

check=0
case "${1:-}" in
  --check) check=1 ;;
  "") ;;
  -h|--help)
    awk '
      NR == 1 { next }
      /^#/ { while (pending > 0) { print ""; pending-- }
             line = $0; sub(/^# ?/, "", line); print line; started = 1; next }
      /^[[:space:]]*$/ { if (started) pending++; next }
      { exit }
    ' "$0"
    exit 0 ;;
  *) echo "Error: 未知参数 $1" >&2; exit 2 ;;
esac

[ -f "$src" ] || { echo "Error: 缺少 $src" >&2; exit 1; }

render_one() {
  local file="$1" out="$2"
  awk '
    FNR == NR {
      if ($0 ~ /<!-- SHARED-CONVENTIONS:BEGIN -->/) inblock = 1
      if (inblock) block = block $0 ORS
      if ($0 ~ /<!-- SHARED-CONVENTIONS:END -->/) inblock = 0
      next
    }
    /<!-- SHARED-CONVENTIONS:BEGIN -->/ { printf "%s", block; skip = 1; next }
    /<!-- SHARED-CONVENTIONS:END -->/ { skip = 0; next }
    !skip { print }
  ' "$src" "$file" > "$out"
}

fail=0
for role in "${roles[@]}"; do
  f="$ref_dir/$role"
  if [ ! -f "$f" ]; then
    echo "Error: 缺少 $f" >&2
    fail=1
    continue
  fi
  if ! grep -q '<!-- SHARED-CONVENTIONS:BEGIN -->' "$f"; then
    echo "Error: $role 缺少 SHARED-CONVENTIONS 标记" >&2
    fail=1
    continue
  fi
  tmp="$(mktemp)"
  render_one "$f" "$tmp"
  if [ "$check" -eq 1 ]; then
    cmp -s "$tmp" "$f" || { echo "out of date: skills/dev-workflow/references/$role"; fail=1; }
  elif ! cmp -s "$tmp" "$f"; then
    cp "$tmp" "$f"
    echo "[render] skills/dev-workflow/references/$role"
  fi
  rm -f "$tmp"
done

mkdir -p "$prompts_dir"
sync_pair() {
  local srcf="$1" dstf="$2" label="$3"
  if [ "$check" -eq 1 ]; then
    cmp -s "$srcf" "$dstf" || { echo "out of date: $label"; fail=1; }
  elif ! cmp -s "$srcf" "$dstf" 2>/dev/null; then
    cp "$srcf" "$dstf"
    echo "[sync] $label"
  fi
}

for f in "${roles[@]}" "${plain[@]}"; do
  sync_pair "$ref_dir/$f" "$prompts_dir/$f" "prompts/dev-workflow/$f"
done
sync_pair "$ref_dir/00-workflow-readme.md" "$prompts_dir/README.md" "prompts/dev-workflow/README.md"

if [ "$check" -eq 1 ]; then
  if [ "$fail" -ne 0 ]; then
    echo "dev-workflow 渲染结果落后：运行 scripts/render-dev-workflow.sh" >&2
    exit 1
  fi
  echo "dev-workflow 渲染一致。"
else
  echo "dev-workflow 已渲染并同步。"
fi
