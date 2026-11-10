#!/usr/bin/env bash
# Install skills from the LosSKILL repo into a target skills directory.
# Copy only: no network access, and nothing inside a skill is executed.
#
# Usage:
#   ./scripts/install.sh                       # all skills -> default target
#   ./scripts/install.sh sandra-sales          # one skill (or a,b,c)
#   ./scripts/install.sh all ~/.claude/skills  # explicit target
#
# Default target: $HOME/.dsh/skills (override with LOSSKILL_TARGET)
# Works with bash 3.2+ (macOS default), no external deps beyond find/coreutils.

set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
source_root="$repo_root/skills"

if [ ! -d "$source_root" ]; then
  echo "Error: $source_root not found" >&2
  exit 1
fi

skill="${1:-all}"
target="${2:-${LOSSKILL_TARGET:-$HOME/.dsh/skills}}"

# Installable skills: sub-directories that contain SKILL.md
available=()
while IFS= read -r dir; do
  if [ -n "$dir" ] && [ -f "$dir/SKILL.md" ]; then
    available[${#available[@]}]="$(basename "$dir")"
  fi
done < <(find "$source_root" -mindepth 1 -maxdepth 1 -type d | sort)

if [ "${#available[@]}" -eq 0 ]; then
  echo "Error: no installable skill found under $source_root" >&2
  exit 1
fi

names=()
if [ "$skill" = "all" ]; then
  names=("${available[@]}")
else
  IFS=',' read -r -a raw <<< "$skill"
  for item in "${raw[@]}"; do
    name="$(echo "$item" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')"
    [ -z "$name" ] && continue
    found=0
    for a in "${available[@]}"; do
      if [ "$a" = "$name" ]; then found=1; fi
    done
    if [ "$found" -eq 0 ]; then
      echo "Error: unknown skill '$name'. Available: ${available[*]}" >&2
      exit 1
    fi
    names[${#names[@]}]="$name"
  done
fi

if [ "${#names[@]}" -eq 0 ]; then
  echo "Error: nothing to install" >&2
  exit 1
fi

mkdir -p "$target"
echo "Repo  : $repo_root"
echo "Target: $target"
echo

installed=0
skipped=0
for name in "${names[@]}"; do
  src="$source_root/$name"
  dst="$target/$name"

  if [ -e "$dst" ]; then
    echo "  Already exists, skipped: $dst (remove it first to reinstall)" >&2
    skipped=$((skipped + 1))
    continue
  fi

  cp -R "$src" "$dst"
  count="$(find "$dst" -type f | wc -l | tr -d ' ')"
  echo "  [OK] $name ($count files)"
  installed=$((installed + 1))
done

echo
echo "Done: $installed installed, $skipped skipped."
echo "Note: some tools need a session restart or skill list refresh before the new skills appear."
