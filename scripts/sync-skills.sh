#!/usr/bin/env bash
# 同步 skills/ 到 AI 工具的 skills 目录（复制或软链接）。
#
# 用法：
#   ./scripts/sync-skills.sh                          # 全部；自动探测目标；复制；跳过已存在
#   ./scripts/sync-skills.sh --link                   # 全部；软链接（仓库改完立即生效）
#   ./scripts/sync-skills.sh --link --force           # 全部；用软链接替换已有副本
#   ./scripts/sync-skills.sh sandra-sales,game-design # 只同步指定 Skill
#   ./scripts/sync-skills.sh all ~/.claude/skills     # 显式目标
#   ./scripts/sync-skills.sh --copy --dry-run         # 只看会做什么
#
# 选项：
#   --link        软链接模式（默认 copy）
#   --copy        复制模式
#   --force       覆盖目标里已存在的同名 Skill/链接（只删目标下那一个目录）
#   --dry-run     不写入，只打印动作
#   --target DIR  目标目录；也可用第二个位置参数或 LOSSKILL_TARGET
#
# 目标为 auto（默认）时：LOSSKILL_TARGET > CLAUDE_CONFIG_DIR/skills
# > 已存在的 ~/.claude/skills > 已存在的 ~/.dsh/skills > ~/.claude/skills。

set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
source_root="$repo_root/skills"

mode="copy"
force=0
dry_run=0
target_arg="auto"
positional=()

usage() { sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'; }

while [ "$#" -gt 0 ]; do
  case "$1" in
    --link)     mode="link" ;;
    --copy)     mode="copy" ;;
    --force|-f) force=1 ;;
    --dry-run)  dry_run=1 ;;
    --target)
      [ "$#" -ge 2 ] || { echo "Error: --target 需要目录参数" >&2; exit 2; }
      target_arg="$2"; shift ;;
    -h|--help)  usage; exit 0 ;;
    --)         shift; while [ "$#" -gt 0 ]; do positional[${#positional[@]}]="$1"; shift; done ;;
    -*)         echo "Error: 未知选项 $1（见 --help）" >&2; exit 2 ;;
    *)          positional[${#positional[@]}]="$1" ;;
  esac
  [ "$#" -gt 0 ] && shift
done

skill_arg="all"
[ "${#positional[@]}" -ge 1 ] && skill_arg="${positional[0]}"
[ "${#positional[@]}" -ge 2 ] && target_arg="${positional[1]}"
[ "${#positional[@]}" -gt 2 ] && { echo "Error: 参数过多（见 --help）" >&2; exit 2; }

[ -d "$source_root" ] || { echo "Error: $source_root not found" >&2; exit 1; }

resolve_target() {
  if [ "$target_arg" != "auto" ]; then
    printf '%s' "$target_arg"; return 0
  fi
  if [ -n "${LOSSKILL_TARGET:-}" ]; then
    printf '%s' "$LOSSKILL_TARGET"; return 0
  fi
  # 显式指定了 Claude 配置目录时，优先装到它的 skills/
  if [ -n "${CLAUDE_CONFIG_DIR:-}" ]; then
    printf '%s' "$CLAUDE_CONFIG_DIR/skills"; return 0
  fi
  local claude_skills="$HOME/.claude/skills"
  if [ -d "$claude_skills" ]; then
    printf '%s' "$claude_skills"; return 0
  fi
  if [ -d "$HOME/.dsh/skills" ]; then
    printf '%s' "$HOME/.dsh/skills"; return 0
  fi
  printf '%s' "$claude_skills"
}

target="$(resolve_target)"

# 可安装的 Skill：包含 SKILL.md 的一级目录
available=()
while IFS= read -r dir; do
  if [ -n "$dir" ] && [ -f "$dir/SKILL.md" ]; then
    available[${#available[@]}]="$(basename "$dir")"
  fi
done < <(find "$source_root" -mindepth 1 -maxdepth 1 -type d | sort)

[ "${#available[@]}" -gt 0 ] || { echo "Error: no installable skill found under $source_root" >&2; exit 1; }

names=()
if [ "$skill_arg" = "all" ]; then
  names=("${available[@]}")
else
  IFS=',' read -r -a raw <<< "$skill_arg"
  for item in "${raw[@]}"; do
    name="$(printf '%s' "$item" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')"
    [ -z "$name" ] && continue
    found=0
    for a in "${available[@]}"; do
      [ "$a" = "$name" ] && found=1
    done
    [ "$found" -eq 1 ] || { echo "Error: unknown skill '$name'. Available: ${available[*]}" >&2; exit 1; }
    names[${#names[@]}]="$name"
  done
fi
[ "${#names[@]}" -gt 0 ] || { echo "Error: nothing to sync" >&2; exit 1; }

# 防止把目标指到仓库自身，造成自引用
target_abs="$target"
case "$target_abs" in
  /*) ;;
  *) target_abs="$PWD/$target_abs" ;;
esac
if [ -d "$(dirname "$target_abs")" ]; then
  target_abs="$(cd "$(dirname "$target_abs")" && pwd)/$(basename "$target_abs")"
fi
case "$target_abs" in
  "$repo_root"|"$repo_root"/*) echo "Error: 目标不能位于仓库内：$target" >&2; exit 1 ;;
esac

echo "Repo  : $repo_root"
echo "Target: $target"
echo "Mode  : $mode$([ "$dry_run" -eq 1 ] && echo ' (dry-run)')"
echo

[ "$dry_run" -eq 1 ] || mkdir -p "$target"

linked=0; copied=0; updated=0; skipped=0
for name in "${names[@]}"; do
  src="$source_root/$name"
  dst="$target/$name"

  if [ "$mode" = "link" ]; then
    if [ -L "$dst" ] && [ "$(readlink "$dst")" = "$src" ]; then
      echo "  [skip] $name 已链接到仓库"
      skipped=$((skipped + 1)); continue
    fi
    if [ -e "$dst" ] || [ -L "$dst" ]; then
      if [ "$force" -ne 1 ]; then
        echo "  [skip] $name 已存在（用 --force 替换为软链接）"
        skipped=$((skipped + 1)); continue
      fi
      echo "  [replace] $name"
      [ "$dry_run" -eq 1 ] || rm -rf "$dst"
      updated=$((updated + 1))
    else
      echo "  [link] $name"
      linked=$((linked + 1))
    fi
    [ "$dry_run" -eq 1 ] || ln -s "$src" "$dst"
  else
    if [ -e "$dst" ] || [ -L "$dst" ]; then
      if [ "$force" -ne 1 ]; then
        echo "  [skip] $name 已存在（用 --force 覆盖，或 --link 改为软链接）"
        skipped=$((skipped + 1)); continue
      fi
      echo "  [replace] $name"
      [ "$dry_run" -eq 1 ] || rm -rf "$dst"
      updated=$((updated + 1))
    else
      echo "  [copy] $name"
      copied=$((copied + 1))
    fi
    [ "$dry_run" -eq 1 ] || cp -R "$src" "$dst"
  fi
done

echo
if [ "$dry_run" -eq 1 ]; then
  echo "Dry-run 完成：未写入任何文件。"
else
  echo "完成：$linked 个新链接，$copied 个新复制，$updated 个替换，$skipped 个跳过。"
fi
