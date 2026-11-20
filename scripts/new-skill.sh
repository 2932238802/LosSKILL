#!/usr/bin/env bash
# 新建一个 Skill：创建目录与 SKILL.md，并在 SKILLS.md 的「待归类」登记。
#
# 用法：
#   ./scripts/new-skill.sh my-skill --desc "当用户……时使用，产出……"
#   ./scripts/new-skill.sh my-skill --desc "……" --not-for "相邻场景（该用 xxx）"
#   ./scripts/new-skill.sh my-skill --title "标题" --source-type book --source-title "书名" --tags "tag1, tag2"
#
# 选项：
#   --desc TEXT         触发场景与产出（必填；description 会补「不用于」边界）
#   --not-for TEXT      不用于什么（默认待补充）
#   --title TEXT        SKILL.md 一级标题（默认用 name）
#   --source-type TYPE  book|video|podcast|course|interview|collected（默认 collected）
#   --source-title TEXT 来源标题（默认待补充）
#   --tags TEXT         metadata.tags（默认待补充）
#   --no-index          不写入 SKILLS.md
#   --no-validate       创建后不跑 validate.sh
#   -h, --help          显示帮助

set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
skills_root="$repo_root/skills"
template="$repo_root/_template/SKILL.md"
index="$repo_root/SKILLS.md"

usage() { sed -n '2,18p' "$0" | sed 's/^# \{0,1\}//'; }

name=""
desc=""
not_for=""
title=""
source_type="collected"
source_title="待补充"
tags="待补充"
write_index=1
run_validate=1

while [ "$#" -gt 0 ]; do
  case "$1" in
    --desc)         [ "$#" -ge 2 ] || { echo "Error: --desc 需要内容" >&2; exit 2; }; desc="$2"; shift ;;
    --not-for)      [ "$#" -ge 2 ] || { echo "Error: --not-for 需要内容" >&2; exit 2; }; not_for="$2"; shift ;;
    --title)        [ "$#" -ge 2 ] || { echo "Error: --title 需要内容" >&2; exit 2; }; title="$2"; shift ;;
    --source-type)  [ "$#" -ge 2 ] || { echo "Error: --source-type 需要内容" >&2; exit 2; }; source_type="$2"; shift ;;
    --source-title) [ "$#" -ge 2 ] || { echo "Error: --source-title 需要内容" >&2; exit 2; }; source_title="$2"; shift ;;
    --tags)         [ "$#" -ge 2 ] || { echo "Error: --tags 需要内容" >&2; exit 2; }; tags="$2"; shift ;;
    --no-index)     write_index=0 ;;
    --no-validate)  run_validate=0 ;;
    -h|--help)      usage; exit 0 ;;
    -*)             echo "Error: 未知选项 $1（见 --help）" >&2; exit 2 ;;
    *)
      if [ -z "$name" ]; then name="$1"; else echo "Error: 多余的参数 $1" >&2; exit 2; fi
      ;;
  esac
  shift
done

[ -n "$name" ] || { echo "Error: 缺少 Skill 名（kebab-case）" >&2; usage; exit 2; }
printf '%s' "$name" | grep -qE '^[a-z0-9]+(-[a-z0-9]+)*$' || {
  echo "Error: Skill 名必须是 kebab-case：$name" >&2; exit 2
}
[ -f "$template" ] || { echo "Error: $template not found" >&2; exit 1; }

case "$source_type" in
  book|video|podcast|course|interview|collected) ;;
  *) echo "Error: --source-type 只能是 book|video|podcast|course|interview|collected" >&2; exit 2 ;;
esac

if [ -e "$skills_root/$name" ]; then
  echo "Error: skills/$name 已存在，不覆盖" >&2; exit 1
fi

if [ -z "$desc" ]; then
  if [ -t 0 ]; then
    read -r -p "触发场景与产出（用户会怎么说 → 产出什么）: " desc
  fi
  [ -n "$desc" ] || { echo "Error: 缺少 --desc" >&2; exit 2; }
fi

# 统一补「不用于」边界，保证 validate 的硬要求
case "$desc" in
  *不用于*|*不适用*|*不涉及*) ;;
  *) [ -n "$not_for" ] || not_for="相邻但不应触发的场景（请补充）"; desc="$desc。不用于$not_for。" ;;
esac
[ -n "$title" ] || title="$name"

yaml_quote() {
  printf '"%s"' "$(printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g')"
}

mkdir -p "$skills_root/$name"
target="$skills_root/$name/SKILL.md"
body="$(awk 'BEGIN{fm=0} /^---[[:space:]]*$/{fm++; next} fm>=2{print}' "$template")"
# 去掉模板正文开头的空行，避免生成三个连续换行
body="$(printf '%s\n' "$body" | sed '/./,$!d')"

{
  printf -- '---\n'
  printf 'name: %s\n' "$name"
  printf 'description: |\n'
  printf '%s\n' "$desc" | sed 's/^/  /'
  printf 'metadata:\n'
  printf '  source-type: %s\n' "$source_type"
  printf '  source-title: %s\n' "$(yaml_quote "$source_title")"
  printf '  created: %s\n' "$(date +%F)"
  printf '  tags: %s\n' "$(yaml_quote "$tags")"
  printf -- '---\n\n'
  printf '# %s\n' "$title"
  printf '%s\n' "$body" | sed '/^# Skill 标题/d'
} > "$target"

echo "Created: skills/$name/SKILL.md"

# 在 SKILLS.md 的「待归类」登记
if [ "$write_index" -eq 1 ]; then
  if [ ! -f "$index" ]; then
    echo "  [warn] SKILLS.md 不存在，跳过索引登记" >&2
  else
    if ! grep -qF '<!-- new-skill-rows -->' "$index"; then
      cat >> "$index" <<'EOF'

---

## 待归类（新增 Skill 先登记在这里）

| Skill | 何时用（触发信号） | 产出 | 不用于 | 路径 |
|---|---|---|---|---|
<!-- new-skill-rows -->
EOF
    fi
    esc_desc="$(printf '%s' "$desc" | tr '\n' ' ' | sed 's/|/\\|/g')"
    esc_nf="$(printf '%s' "${not_for:-见 description}" | tr '\n' ' ' | sed 's/|/\\|/g')"
    row="| [\`$name\`](skills/$name/SKILL.md) | $esc_desc | 待补充 | $esc_nf | \`skills/$name/\` |"
    tmp="$(mktemp)"
    awk -v row="$row" '{print} /<!-- new-skill-rows -->/{print row}' "$index" > "$tmp"
    mv "$tmp" "$index"
    echo "Indexed: SKILLS.md（待归类；可再移到对应小节）"
  fi
fi

if [ "$run_validate" -eq 1 ]; then
  echo
  if "$repo_root/scripts/validate.sh"; then
    echo "validate: OK"
  else
    echo "validate: FAILED（文件已保留，请修正后重跑）" >&2
    exit 1
  fi
fi

echo
echo "下一步：补全 skills/$name/SKILL.md 的正文与 references/，然后跑 ./scripts/validate.sh"
