#!/usr/bin/env bash
# LosSKILL 自检（Linux / macOS / WSL 版，等价于 scripts/validate.ps1）
#
# 检查项：
#   1. 每个 skills/<name>/ 都有 SKILL.md
#   2. SKILL.md 有 YAML frontmatter，且 name 与目录名一致、为 kebab-case
#   3. description 存在、长度合理、含「不用于 / 不适用」边界说明
#   4. SKILL.md 里引用的 references/*.md 等相对路径真实存在
#   5. 是否出现绝对路径（/home/... 或 C:\...）
#   6. 是否已登记进 SKILLS.md
#
# 用法：./scripts/validate.sh        退出码 0 = 全部通过，1 = 有错误

set -uo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
skills_root="$repo_root/skills"
index_path="$repo_root/SKILLS.md"

[ -d "$skills_root" ] || { echo "skills/ not found: $skills_root" >&2; exit 1; }
index_text=""
[ -f "$index_path" ] && index_text="$(cat "$index_path")"

errors=0
warnings=0
err() { echo "  [ERROR] $*" >&2; errors=$((errors + 1)); }
warn() { echo "  [WARN ] $*"; warnings=$((warnings + 1)); }

checked=0
for dir in "$skills_root"/*/; do
    [ -d "$dir" ] || continue
    name="$(basename "$dir")"
    rel="skills/$name"
    file="$dir/SKILL.md"
    checked=$((checked + 1))

    if [ ! -f "$file" ]; then
        err "$rel: missing SKILL.md"
        continue
    fi

    text="$(cat "$file")"

    # ---- frontmatter ----
    if ! printf '%s' "$text" | head -1 | grep -qx -- '---'; then
        err "$rel: no YAML frontmatter"
    else
        fm="$(printf '%s\n' "$text" | awk 'NR==1{next} /^---[[:space:]]*$/{exit} {print}')"
        fm_name="$(printf '%s\n' "$fm" | sed -nE 's/^name:[[:space:]]*(.+?)[[:space:]]*$/\1/p' | head -1 | tr -d "'\"")"

        if [ -z "$fm_name" ]; then
            err "$rel: frontmatter missing 'name'"
        elif [ "$fm_name" != "$name" ]; then
            err "$rel: frontmatter name '$fm_name' != folder name"
        elif ! printf '%s' "$fm_name" | grep -qE '^[a-z0-9]+(-[a-z0-9]+)*$'; then
            err "$rel: name '$fm_name' is not kebab-case"
        fi

        # description 允许单行或块状（|）
        desc="$(printf '%s\n' "$fm" | awk '/^description:/{flag=1; sub(/^description:[[:space:]]*/,""); if ($0 != "" && $0 != "|" && $0 != ">") print; next} flag && /^[^[:space:]]/{flag=0} flag{print}')"
        desc_len=${#desc}
        if [ "$desc_len" -eq 0 ]; then
            err "$rel: frontmatter missing 'description'"
        else
            [ "$desc_len" -lt 40 ] && warn "$rel: description shorter than 40 chars ($desc_len)"
            if ! printf '%s' "$desc" | grep -qE '不用于|不适用|不涉及|Not for|not for'; then
                warn "$rel: description has no explicit 'not for' clause (AI may over-trigger)"
            fi
        fi
    fi

    # ---- 相对引用是否真实存在 ----
    refs="$(printf '%s\n' "$text" |
        grep -oE '`references/[^`]+\.md`|\]\([^)]+\.md(#[^)]*)?\)' |
        sed -E 's/^`//; s/`$//; s/^\]\(//; s/\)$//; s/#.*$//' | sort -u)"
    while IFS= read -r r; do
        [ -z "$r" ] && continue
        case "$r" in http*|/*) continue ;; esac
        # 跳过占位符与通配符（如 references/projects/<项目>.md、capabilities/*.md）
        case "$r" in *'<'*|*'>'*|*'*'*) continue ;; esac
        [ -f "$dir/$r" ] || err "$rel: referenced file not found -> $r"
    done <<< "$refs"

    # ---- 绝对路径 ----
    abs="$(printf '%s\n' "$text" | grep -oE '(^|[[:space:]`("'"'"'])(/[Uu]sers/|/home/|[A-Za-z]:\\)[^[:space:]`"'"'"')]+' | sed -E 's/^[[:space:]`("'"'"']//' | sort -u)"
    while IFS= read -r a; do
        [ -z "$a" ] && continue
        warn "$rel: absolute path referenced -> $a"
    done <<< "$abs"

    # ---- SKILLS.md 覆盖 ----
    if [ -n "$index_text" ] && ! printf '%s' "$index_text" | grep -qF -- "$name"; then
        warn "$rel: not mentioned in SKILLS.md"
    fi
done

# ---- 常驻规则文件 ----
if [ -f "$repo_root/AGENTS.md" ]; then
    if [ ! -f "$repo_root/CLAUDE.md" ] || ! grep -qF '@AGENTS.md' "$repo_root/CLAUDE.md"; then
        warn "CLAUDE.md 未导入 @AGENTS.md（Claude Code 不会自动读 AGENTS.md）"
    fi
fi

echo "Checked $checked skill(s) under $skills_root"
echo
[ "$warnings" -gt 0 ] && echo "WARNINGS ($warnings)"
if [ "$errors" -gt 0 ]; then
    echo "ERRORS ($errors)"
    exit 1
fi
echo "All skills OK."
