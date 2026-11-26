#!/usr/bin/env bash
# 校验 docs 树契约；--gate g1 同时做 G1 门禁检查
#
# 用法：
#   ./scripts/check-docs.sh <文档根目录>
#   ./scripts/check-docs.sh /path/to/project/LosAngelousDocs --gate g1
#   ./scripts/check-docs.sh /path/to/project/LosAngelousDocs --gate g2|g3|g4
#   ./scripts/check-docs.sh /path/to/project/LosAngelousDocs --gate g2.5|g3.5
#   ./scripts/check-docs.sh <文档根目录> --project-root /path/to/project
#
# 检查项：
#   1. DOCS_CONTRACT.md 存在，核心文件/目录条目齐全
#   2. 契约声明的 file / dir 真实存在
#   3. docs 顶层没有未登记的文件/目录
#   4. reports/ 下只有规范命名的报告、review-index.md、archive/、ci/
#   5. 编号文档若拆成同名目录，必须有 README.md，且不能同时保留同名 .md
#   6. --gate g1：有真实 CR / R / AC / T 编号，STATUS.md 标记「G1 已确认：是」
#   7. --gate g2：有 dev-*.md 报告（含 report-meta），04-tasks.md 有 AC 映射
#   8. --gate g3：有 review-*.md 报告且结论合法，reports/review-index.md 存在，G3 接受已记录
#   9. --gate g4：有 meta/steward 报告且结论合法，或 STATUS.md 记录「G4 豁免」
#  10. --gate g2.5 / g3.5：WORKLOG 有对应门禁行；g3.5 可用「G3.5 豁免」代替
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

project_root_abs=""
if [ -n "$project_root" ] && [ -d "$project_root" ]; then
  project_root_abs="$(cd "$project_root" && pwd)"
fi

case "$gate" in
  ""|g1|g2|g2.5|g3|g3.5|g4) ;;
  *) echo "Error: --gate 只支持 g1 / g2 / g2.5 / g3 / g3.5 / g4" >&2; exit 2 ;;
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
    case "$name" in
      WORKLOG.md|AUTHORIZATIONS.md|PROJECT_BRAIN.md)
        # 记录根默认项目根；文档根属存量兼容（legacy），不按未登记文件拦截
        warn "记录文件在文档根：$name（legacy；建议移到项目根）"
        ;;
      *)
        contains "$name" "${declared_files[@]}" || err "未登记文件：$name（新增路径需在 DOCS_CONTRACT.md 登记并经用户批准）"
        ;;
    esac
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
  grep -qE 'G1[[:space:]]*已确认[[:space:]]*\**[[:space:]]*(：|:)[[:space:]]*\**[[:space:]]*是' "$doc_root/STATUS.md" 2>/dev/null \
    || err "G1：STATUS.md 未写「G1 已确认：是」（用户确认后才可写）"
fi

find_latest_report() {
  local role="$1" dirs=("$reports_dir") latest=""
  [ -d "$reports_dir/archive" ] && dirs+=("$reports_dir/archive")
  # 优先按 mtime 取最新（-r2 应优于 base）；GNU find -printf 不可用时回退字典序
  if find "$reports_dir" -maxdepth 0 -printf '%p\n' >/dev/null 2>&1; then
    latest="$(find "${dirs[@]}" -maxdepth 1 -type f -name "$role-[0-9][0-9][0-9][0-9]-*.md" \
      -printf '%T@ %p\n' 2>/dev/null | sort -n | tail -1 | sed -E 's/^[^ ]+ //')"
  fi
  if [ -z "$latest" ]; then
    latest="$(find "${dirs[@]}" -maxdepth 1 -type f -name "$role-[0-9][0-9][0-9][0-9]-*.md" -print 2>/dev/null | sort | tail -1)"
  fi
  printf '%s' "$latest"
}

g1_confirmed() {
  grep -qE 'G1[[:space:]]*已确认[[:space:]]*\**[[:space:]]*(：|:)[[:space:]]*\**[[:space:]]*是' "$doc_root/STATUS.md" 2>/dev/null
}

# 记录根：默认项目根；存量项目允许文档根（legacy）
record_file() {
  local n="$1"
  if [ -n "$project_root_abs" ] && [ -f "$project_root_abs/$n" ]; then
    printf '%s' "$project_root_abs/$n"; return 0
  fi
  if [ -f "$doc_root/$n" ]; then
    printf '%s' "$doc_root/$n"; return 0
  fi
  return 1
}

current_cr() {
  local raw val
  raw="$(grep -E '^[[:space:]]*-?[[:space:]]*\**[[:space:]]*当前 CR[[:space:]]*\**[[:space:]]*(：|:)' "$doc_root/STATUS.md" 2>/dev/null | head -1)"
  if [ -n "$raw" ]; then
    val="$(printf '%s' "$raw" | sed -E 's/^[[:space:]]*-?[[:space:]]*\**[[:space:]]*当前 CR[[:space:]]*\**[[:space:]]*(：|:)[[:space:]]*//')"
    val="$(printf '%s' "$val" | tr -d '*')"
    val="$(printf '%s' "$val" | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//')"
    case "$val" in
      # 只取编号，忽略状态字段后面的描述文字
      CR-*) printf '%s' "$(printf '%s' "$val" | grep -oE 'CR-[0-9]+' | head -1)"; return 0 ;;
      # STATUS 明确写「无 / none / - / 空白」时返回空，不回退候选 CR
      *) printf ''; return 0 ;;
    esac
  fi
  # 仅当缺「当前 CR」字段时才回退 intake 最大编号（保持旧行为）
  grep -oE 'CR-[0-9]+' "$doc_root/00-requirements-intake.md" 2>/dev/null | sort -t- -k2 -n | tail -1
}

worklog_has_gate() {
  local wl cr="$2" gate="$1"
  wl="$(record_file WORKLOG.md)" || return 1
  if [ -n "$cr" ]; then
    grep -qE "\|[[:space:]]*${gate}[[:space:]]*\|.*${cr}" "$wl"
  else
    grep -qE "\|[[:space:]]*${gate}[[:space:]]*\|" "$wl"
  fi
}

g3_accepted() {
  grep -qE 'G3[[:space:]]*已接受[[:space:]]*\**[[:space:]]*(：|:)' "$doc_root/STATUS.md" 2>/dev/null && return 0
  local wl
  wl="$(record_file WORKLOG.md)" || return 1
  grep -qE '\|[[:space:]]*G3[[:space:]]*\|.*接受' "$wl"
}

if [ "$gate" = "g2.5" ]; then
  cr="$(current_cr)"
  if [ -z "$cr" ]; then
    err "G2.5：STATUS.md 未给出当前 CR（为空/无），无法核对 WORKLOG；先写「当前 CR：CR-xxx」"
  else
    worklog_has_gate "G2.5" "$cr" \
      || err "G2.5：WORKLOG 没有 G2.5 行（$cr）（Steward 合并增量后必须记一行）"
  fi
  if [ -n "$project_root_abs" ] && [ -f "$project_root_abs/PROJECT_BRAIN.md" ]; then :;
  elif [ -f "$doc_root/PROJECT_BRAIN.md" ]; then :;
  else warn "G2.5：找不到 PROJECT_BRAIN.md（项目根或文档根）"; fi
fi

if [ "$gate" = "g3.5" ]; then
  if grep -qE 'G3\.5[[:space:]]*豁免' "$doc_root/STATUS.md" 2>/dev/null; then
    :
  else
    cr="$(current_cr)"
    if [ -z "$cr" ]; then
      err "G3.5：STATUS.md 未给出当前 CR（为空/无），无法核对 WORKLOG；或在 STATUS.md 写「G3.5 豁免：<理由>」"
    elif ! worklog_has_gate "G3.5" "$cr"; then
      err "G3.5：WORKLOG 没有 G3.5 行（$cr），且 STATUS.md 未写「G3.5 豁免」"
    fi
  fi
fi

if [ "$gate" = "g2" ]; then
  g1_confirmed || err "G2：STATUS.md 未写「G1 已确认：是」"
  dev_report="$(find_latest_report dev)"
  if [ -z "$dev_report" ]; then
    err "G2：reports/（含 archive/）下没有 dev-*.md 开发报告"
  else
    grep -qF '<!-- report-meta' "$dev_report" \
      || err "G2：$(basename "$dev_report") 缺少 report-meta（finish-report.sh 无法记账）"
  fi
  grep -qE 'AC-[0-9]+' "$doc_root/04-tasks.md" 2>/dev/null \
    || err "G2：04-tasks.md 没有 AC 映射"
fi

if [ "$gate" = "g3" ]; then
  review_report="$(find_latest_report review)"
  if [ -z "$review_report" ]; then
    err "G3：reports/（含 archive/）下没有 review-*.md 评审报告"
  else
    if ! grep -qE '(结论|判定)[[:space:]]*(：|:)[[:space:]]*(通过|有条件通过|不通过)[[:space:]]*$' "$review_report"; then
      err "G3：$(basename "$review_report") 缺少合法结论（通过 / 有条件通过 / 不通过）"
    fi
    if grep -qE '\[P0\]|\[P1\]' "$review_report" \
      && grep -qE '(结论|判定)[[:space:]]*(：|:)[[:space:]]*通过[[:space:]]*$' "$review_report"; then
      warn "G3：结论为「通过」但报告中含 P0/P1，请复核严重度与结论"
    fi
  fi
  [ -f "$reports_dir/review-index.md" ] \
    || err "G3：缺少 reports/review-index.md（评审记忆）"
  g3_accepted \
    || warn "G3：未见 G3 接受记录（STATUS.md 写「G3 已接受：」或 WORKLOG 记 gate=G3 status=接受）"
fi

if [ "$gate" = "g4" ]; then
  meta_report="$(find_latest_report meta)"
  [ -z "$meta_report" ] && meta_report="$(find_latest_report steward)"
  exempt=0
  if grep -qE 'G4[[:space:]]*豁免' "$doc_root/STATUS.md" 2>/dev/null; then
    exempt=1
  fi
  if [ "$exempt" -eq 0 ]; then
    if [ -z "$meta_report" ]; then
      err "G4：没有 meta/steward 总审报告，且 STATUS.md 未记录「G4 豁免」"
    elif ! grep -qE '(总审)?结论[[:space:]]*(：|:)[[:space:]]*(通过|返工)[[:space:]]*$' "$meta_report"; then
      err "G4：$(basename "$meta_report") 缺少总审结论（通过 / 返工）"
    fi
  fi
  grep -qE 'G4' "$doc_root/STATUS.md" 2>/dev/null \
    || err "G4：STATUS.md 未记录 G4 结果或豁免"
  if [ -n "$project_root_abs" ]; then
    for f in WORKLOG.md AUTHORIZATIONS.md; do
      [ -f "$project_root_abs/$f" ] || [ -f "$doc_root/$f" ] \
        || err "G4：项目根与文档根都缺少 $f（记录根至少一处）"
    done
  fi
fi

if [ -n "$project_root" ]; then
  if [ -d "$project_root" ]; then
    for f in PROJECT_BRAIN.md AUTHORIZATIONS.md WORKLOG.md; do
      [ -f "$project_root_abs/$f" ] || [ -f "$doc_root/$f" ] \
        || warn "缺少 $f（项目根或文档根；建议用 bootstrap-project.sh 生成）"
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
