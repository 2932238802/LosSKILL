#!/usr/bin/env bash
# 校验 docs 树契约；--gate g1 同时做 G1 门禁检查
#
# 用法：
#   ./scripts/check-docs.sh <文档根目录>
#   ./scripts/check-docs.sh /path/to/project/LosAngelousDocs --gate g1
#   ./scripts/check-docs.sh <文档根目录> --project-root /path/to/project
#
# 检查项：
#   1. DOCS_CONTRACT.md 存在，核心文件/目录条目齐全
#   2. 契约声明的 file / dir 真实存在
#   3. docs 顶层没有未登记的文件/目录
#   4. reports/ 下只有规范命名的报告、review-index.md、archive/、ci/
#   5. 编号文档若拆成同名目录，必须有 README.md，且不能同时保留同名 .md
#   6. --gate g1：有真实 CR / R / AC / T 编号，STATUS.md 标记「G1 已确认：是」
#
# 退出码：0 = 通过（允许 WARN）；1 = 有 ERROR；2 = 用法/路径错误

set -uo pipefail

usage() {
  awk '
    NR == 1 { next }
    /^#/ { while (pending > 0) { print ""; pending-- }
           line = $0; sub(/^# ?/, "", line); print line; started = 1; next }
    /^[[:space:]]*$/ { if (started) pending++; next }
    { exit }
  ' "$0"
}

doc_root=""
gate=""
project_root=""

while [ "$#" -gt 0 ]; do
  case "$1" in
    --gate) [ "$#" -ge 2 ] || { echo "Error: --gate 需要值（g1）" >&2; exit 2; }; gate="$2"; shift ;;
    --project-root) [ "$#" -ge 2 ] || { echo "Error: --project-root 需要路径" >&2; exit 2; }; project_root="$2"; shift ;;
    -h|--help) usage; exit 0 ;;
    -*) echo "Error: 未知选项 $1" >&2; exit 2 ;;
    *)
      if [ -z "$doc_root" ]; then doc_root="$1"; else echo "Error: 多余参数 $1" >&2; exit 2; fi
      ;;
  esac
  shift
done

[ -n "$doc_root" ] || { echo "Error: 缺少文档根目录" >&2; usage >&2; exit 2; }
[ -d "$doc_root" ] || { echo "Error: 文档根目录不存在：$doc_root" >&2; exit 2; }
doc_root="$(cd "$doc_root" && pwd)"

case "$gate" in
  ""|g1) ;;
  *) echo "Error: --gate 目前只支持 g1" >&2; exit 2 ;;
esac

errors=0
warnings=0
err() { echo "  [ERROR] $*" >&2; errors=$((errors + 1)); }
warn() { echo "  [WARN ] $*"; warnings=$((warnings + 1)); }
trim() {
  local s="$1"
  s="${s#"${s%%[![:space:]]*}"}"
  s="${s%"${s##*[![:space:]]}"}"
  printf '%s' "$s"
}
contains() {
  local needle="$1" item
  shift
  for item in "$@"; do
    [ "$item" = "$needle" ] && return 0
  done
  return 1
}

core_files=(
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
core_dirs=(reports)
stems=(
  00-overview
  00-requirements-intake
  01-requirements
  02-architecture
  03-design
  04-tasks
  05-decisions
)

echo "check-docs: $doc_root${gate:+ (gate=$gate)}"

contract="$doc_root/DOCS_CONTRACT.md"
if [ ! -f "$contract" ]; then
  err "缺少 DOCS_CONTRACT.md（先运行 scripts/init-docs.sh \"$doc_root\"）"
  echo "check-docs: FAIL（$errors ERROR, $warnings WARN）"
  exit 1
fi

declared_files=()
declared_dirs=()
optional_dirs=()

while IFS='|' read -r kind path _owner _purpose; do
  kind="$(trim "$kind")"
  path="$(trim "$path")"
  case "$kind" in
    file) declared_files+=("$path") ;;
    dir) declared_dirs+=("$path") ;;
    'dir?') optional_dirs+=("$path") ;;
  esac
done < <(grep -E '^[[:space:]]*(file|dir|dir[?])[[:space:]]*\|' "$contract" || true)

if [ "${#declared_files[@]}" -eq 0 ]; then
  err "DOCS_CONTRACT.md 没有可解析的 file 条目（需要 doc-contract-v1 代码块）"
fi

for f in "${core_files[@]}"; do
  contains "$f" "${declared_files[@]}" || err "契约缺少核心文件条目：$f"
done
for d in "${core_dirs[@]}"; do
  contains "$d" "${declared_dirs[@]}" || err "契约缺少核心目录条目：$d"
done

for f in "${declared_files[@]}"; do
  [ -f "$doc_root/$f" ] || err "声明的文件不存在：$f"
done
for d in "${declared_dirs[@]}"; do
  [ -d "$doc_root/$d" ] || err "声明的目录不存在：$d/"
done
for d in "${optional_dirs[@]}"; do
  if [ -e "$doc_root/$d" ] && [ ! -d "$doc_root/$d" ]; then
    err "可选目录位置不是目录：$d"
  fi
done

top_dirs=()
for d in "${declared_dirs[@]}" "${optional_dirs[@]}"; do
  case "$d" in
    */*) ;;
    *) top_dirs+=("$d") ;;
  esac
done

while IFS= read -r -d '' entry; do
  name="$(basename "$entry")"
  case "$name" in .*) continue ;; esac
  if [ -d "$entry" ]; then
    if contains "$name" "${top_dirs[@]}"; then
      :
    elif contains "$name" "${stems[@]}"; then
      [ -f "$entry/README.md" ] || err "拆分目录缺少 README.md：$name/"
      [ -f "$doc_root/$name.md" ] && err "同时存在 $name.md 与 $name/（功能重复，只保留一种）"
    else
      err "未登记目录：$name/（新增路径需在 DOCS_CONTRACT.md 登记并经用户批准）"
    fi
  elif [ -f "$entry" ]; then
    contains "$name" "${declared_files[@]}" || err "未登记文件：$name（新增路径需在 DOCS_CONTRACT.md 登记并经用户批准）"
  fi
done < <(find "$doc_root" -mindepth 1 -maxdepth 1 -print0)

report_re='^(doc|dev|review|meta|steward|spike)-[0-9]{4}-[0-9]{2}-[0-9]{2}-.+\.md$'
check_report_file() {
  local file="$1" rel="$2"
  if ! basename "$file" | grep -Eq "$report_re"; then
    err "报告命名不规范：$rel（应为 <角色>-<YYYY-MM-DD>-<范围>.md）"
  fi
}

reports_dir="$doc_root/reports"
if [ -d "$reports_dir" ]; then
  while IFS= read -r -d '' entry; do
    name="$(basename "$entry")"
    case "$name" in .*) continue ;; esac
    if [ -d "$entry" ]; then
      case "$name" in
        archive)
          while IFS= read -r -d '' sub; do
            sname="$(basename "$sub")"
            case "$sname" in .*) continue ;; esac
            if [ -d "$sub" ]; then
              err "reports/archive/ 下不允许子目录：$sname/"
            else
              check_report_file "$sub" "reports/archive/$sname"
            fi
          done < <(find "$entry" -mindepth 1 -maxdepth 1 -print0)
          ;;
        ci) ;;
        *) err "reports/ 下未登记目录：$name/（只允许 archive/、ci/）" ;;
      esac
    else
      case "$name" in
        review-index.md) ;;
        *) check_report_file "$entry" "reports/$name" ;;
      esac
    fi
  done < <(find "$reports_dir" -mindepth 1 -maxdepth 1 -print0)
fi

if [ "$gate" = "g1" ]; then
  grep -qE 'CR-[0-9]+' "$doc_root/00-requirements-intake.md" 2>/dev/null \
    || err "G1：00-requirements-intake.md 没有真实 CR 编号"
  grep -qE 'R-[0-9]+' "$doc_root/01-requirements.md" 2>/dev/null \
    || err "G1：01-requirements.md 没有真实 R 编号"
  grep -qE 'AC-[0-9]+' "$doc_root/01-requirements.md" 2>/dev/null \
    || err "G1：01-requirements.md 没有真实 AC 编号"
  grep -qE 'T-[0-9]+' "$doc_root/04-tasks.md" 2>/dev/null \
    || err "G1：04-tasks.md 没有真实 T 编号"
  grep -qE 'DoR' "$doc_root/04-tasks.md" 2>/dev/null \
    || err "G1：04-tasks.md 缺少 DoR"
  grep -qF '当前门禁' "$doc_root/STATUS.md" 2>/dev/null \
    || err "G1：STATUS.md 缺少「当前门禁」"
  grep -qE 'G1[[:space:]]*已确认[[:space:]]*(：|:)[[:space:]]*是' "$doc_root/STATUS.md" 2>/dev/null \
    || err "G1：STATUS.md 未写「G1 已确认：是」（用户确认后才可写）"
fi

if [ -n "$project_root" ]; then
  if [ -d "$project_root" ]; then
    project_root="$(cd "$project_root" && pwd)"
    for f in PROJECT_BRAIN.md AUTHORIZATIONS.md WORKLOG.md; do
      [ -f "$project_root/$f" ] || warn "项目根缺少 $f（建议用 bootstrap-project.sh 生成）"
    done
  else
    warn "project-root 不存在，跳过项目根检查：$project_root"
  fi
fi

if [ "$errors" -gt 0 ]; then
  echo "check-docs: FAIL（$errors ERROR, $warnings WARN）"
  exit 1
fi
echo "check-docs: OK（$errors ERROR, $warnings WARN）"
exit 0
