#!/usr/bin/env bash
# 解析标准报告头部，自动追加 WORKLOG 与 AUTHORIZATIONS，并回填 LOG-ID。
#
# 用法：
#   ./scripts/finish-report.sh --report docs/reports/dev-2026-11-20-T-012.md
#   ./scripts/finish-report.sh --report docs/reports/review-2026-11-20-T-012.md --dry-run
#   ./scripts/finish-report.sh --report ... --worklog docs/WORKLOG.md --ledger docs/AUTHORIZATIONS.md
#
# 报告头部格式（放在报告标题下方）：
#   <!-- report-meta
#   role: dev
#   gate: G2
#   cr: CR-004
#   task: T-012
#   status: 完成
#   action: 实现登录限流与 3 个回归测试
#   commit: a1b2c3d
#   auth_level: -
#   auth_action: -
#   auth_policy: -
#   auth_evidence: -
#   auth_scope: -
#   auth_expires: 随 CR 结束
#   auth_key: -
#   -->
#
# 没有 meta 块时，会尝试从「任务 / 范围 / 来源 CR / 结论 / 门禁」等行兜底解析。
#
# 选项：
#   --report PATH      必填
#   --worklog PATH     默认 WORKLOG.md
#   --ledger PATH      默认 AUTHORIZATIONS.md
#   --role / --gate / --cr / --task / --status / --action / --commit   覆盖解析结果
#   --no-worklog       不写工作日志
#   --no-auth          不写授权台账
#   --force            已存在 LOG/AUTH 时仍追加
#   --dry-run          只打印，不写入
#   -h, --help

set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
worklog_script="$repo_root/scripts/worklog.sh"

report=""
worklog="WORKLOG.md"
ledger="AUTHORIZATIONS.md"
do_worklog=1
do_auth=1
dry_run=0
force=0

role_override=""; gate_override=""; cr_override=""; task_override=""
status_override=""; action_override=""; commit_override=""

usage() { sed -n '2,37p' "$0" | sed 's/^# \{0,1\}//'; }

while [ "$#" -gt 0 ]; do
  case "$1" in
    --report)        [ "$#" -ge 2 ] || { echo "Error: --report 需要路径" >&2; exit 2; }; report="$2"; shift 2 ;;
    --worklog)       [ "$#" -ge 2 ] || { echo "Error: --worklog 需要路径" >&2; exit 2; }; worklog="$2"; shift 2 ;;
    --ledger)        [ "$#" -ge 2 ] || { echo "Error: --ledger 需要路径" >&2; exit 2; }; ledger="$2"; shift 2 ;;
    --role)          [ "$#" -ge 2 ] || { echo "Error: --role 需要值" >&2; exit 2; }; role_override="$2"; shift 2 ;;
    --gate)          [ "$#" -ge 2 ] || { echo "Error: --gate 需要值" >&2; exit 2; }; gate_override="$2"; shift 2 ;;
    --cr)            [ "$#" -ge 2 ] || { echo "Error: --cr 需要值" >&2; exit 2; }; cr_override="$2"; shift 2 ;;
    --task)          [ "$#" -ge 2 ] || { echo "Error: --task 需要值" >&2; exit 2; }; task_override="$2"; shift 2 ;;
    --status)        [ "$#" -ge 2 ] || { echo "Error: --status 需要值" >&2; exit 2; }; status_override="$2"; shift 2 ;;
    --action)        [ "$#" -ge 2 ] || { echo "Error: --action 需要值" >&2; exit 2; }; action_override="$2"; shift 2 ;;
    --commit)        [ "$#" -ge 2 ] || { echo "Error: --commit 需要值" >&2; exit 2; }; commit_override="$2"; shift 2 ;;
    --no-worklog)    do_worklog=0; shift ;;
    --no-auth)       do_auth=0; shift ;;
    --force)         force=1; shift ;;
    --dry-run)       dry_run=1; shift ;;
    -h|--help)       usage; exit 0 ;;
    *)               echo "Error: 未知选项 $1" >&2; exit 2 ;;
  esac
done

[ -n "$report" ] || { echo "Error: 缺少 --report" >&2; exit 2; }
[ -f "$report" ] || { echo "Error: 报告不存在：$report" >&2; exit 1; }
[ -x "$worklog_script" ] || { echo "Error: $worklog_script 不存在或不可执行" >&2; exit 1; }

role=""; gate=""; cr=""; task=""; status=""; action=""; commit=""
auth_level="-"; auth_action=""; auth_policy="-"; auth_evidence=""; auth_scope="-"
auth_expires="随 CR 结束"; auth_key=""
has_meta=0

while IFS=$'\t' read -r k v; do
  [ -z "$k" ] && continue
  has_meta=1
  v="$(printf '%s' "$v" | sed 's/[[:space:]]*$//')"
  case "$k" in
    role) role="$v" ;;
    gate) gate="$v" ;;
    cr) cr="$v" ;;
    task) task="$v" ;;
    status) status="$v" ;;
    action) action="$v" ;;
    commit) commit="$v" ;;
    auth_level) auth_level="$v" ;;
    auth_action) auth_action="$v" ;;
    auth_policy) auth_policy="$v" ;;
    auth_evidence) auth_evidence="$v" ;;
    auth_scope) auth_scope="$v" ;;
    auth_expires) auth_expires="$v" ;;
    auth_key) auth_key="$v" ;;
  esac
done < <(awk '
  /<!--[[:space:]]*report-meta/ { inmeta=1; next }
  inmeta && /-->/ { exit }
  inmeta {
    line=$0
    sub(/^[[:space:]]*/, "", line)
    if (line == "") next
    key=line; sub(/:.*/, "", key)
    val=line; sub(/^[^:]*:[[:space:]]*/, "", val)
    print key "\t" val
  }
' "$report")

# 兜底：从报告标题与常见字段解析
if [ "$has_meta" -eq 0 ]; then
  heading="$(grep -m1 '^## ' "$report" || true)"
  case "$heading" in
    *"Doc Agent"*)  role="doc" ;;
    *"Dev Agent"*)  role="dev" ;;
    *"Review Agent"*) role="review" ;;
    *"Meta Review"*) role="meta" ;;
  esac

  field() {
    grep -m1 -E "^- $1：" "$report" 2>/dev/null |
      sed -E "s/^- $1：[[:space:]]*//" |
      sed 's/[[:space:]]*$//' || true
  }

  if [ -z "$gate" ]; then gate="$(field '门禁')"; fi
  gate="$(printf '%s' "$gate" | grep -oE 'G[0-9]+(\.[0-9]+)?' | head -1 || true)"
  if [ -z "$cr" ]; then cr="$(grep -oE 'CR-[0-9]+' "$report" | head -1 || true)"; fi
  if [ -z "$task" ]; then task="$(grep -oE 'T-[0-9]+' "$report" | head -1 || true)"; fi
  if [ -z "$status" ]; then status="$(field '结论')"; fi
  if [ -z "$status" ]; then status="$(field '总审结论')"; fi
  if [ -z "$action" ]; then action="$(field '一句话理由')"; fi
  if [ -z "$action" ]; then action="$(field '本次目标')"; fi
  if [ -z "$commit" ]; then commit="$(grep -oE '[0-9a-f]{7,40}' "$report" | head -1 || true)"; fi
  if [ -z "$cr" ]; then cr="-"; fi
  if [ -z "$task" ]; then task="-"; fi
  if [ -z "$commit" ]; then commit="-"; fi
fi

[ -n "$role_override" ] && role="$role_override"
[ -n "$gate_override" ] && gate="$gate_override"
[ -n "$cr_override" ] && cr="$cr_override"
[ -n "$task_override" ] && task="$task_override"
[ -n "$status_override" ] && status="$status_override"
[ -n "$action_override" ] && action="$action_override"
[ -n "$commit_override" ] && commit="$commit_override"

if [ -z "$cr" ]; then cr="-"; fi
if [ -z "$task" ]; then task="-"; fi
if [ -z "$commit" ]; then commit="-"; fi
if [ -z "$status" ]; then status="完成"; fi

case "$role" in
  doc) [ -n "$gate" ] || gate="G1" ;;
  dev) [ -n "$gate" ] || gate="G2" ;;
  review) [ -n "$gate" ] || gate="G3" ;;
  steward|meta) [ -n "$gate" ] || gate="G4" ;;
  *) echo "Error: 无法识别角色（doc/dev/review/steward/meta）；用 --role 指定" >&2; exit 2 ;;
esac
[ -n "$gate" ] || { echo "Error: 缺少门禁；用 --gate 指定" >&2; exit 2; }
[ -n "$action" ] || { echo "Error: 缺少 action；请在 report-meta 或 --action 提供" >&2; exit 2; }
case "$action" in
  "一句话结果"|"一句话理由"|"待填写"|"-")
    echo "Error: action 仍是占位文本，请填写实际结果" >&2; exit 2 ;;
esac
case "$cr" in
  *xxx*) echo "Error: CR 仍是占位文本（$cr），请填写真实 CR" >&2; exit 2 ;;
esac
case "$task" in
  *xxx*) echo "Error: Task 仍是占位文本（$task），请填写真实任务" >&2; exit 2 ;;
esac

# 报告相对 WORKLOG 的路径
report_abs="$(cd "$(dirname "$report")" && pwd)/$(basename "$report")"
if [ -d "$(dirname "$worklog")" ]; then
  worklog_dir="$(cd "$(dirname "$worklog")" && pwd)"
else
  worklog_dir="$(pwd)"
fi
rel_report="$report"
if command -v python3 >/dev/null 2>&1; then
  rel_report="$(python3 -c 'import os,sys; print(os.path.relpath(sys.argv[1], sys.argv[2]))' "$report_abs" "$worklog_dir")"
fi

# 授权台账
auth_id=""
if [ "$do_auth" -eq 1 ] && [ -n "$auth_level" ] && [ "$auth_level" != "-" ]; then
  [ -f "$ledger" ] || { echo "Error: 授权台账不存在：$ledger" >&2; exit 1; }
  grep -qF '<!-- auth:rows -->' "$ledger" || {
    echo "Error: $ledger 缺少 <!-- auth:rows --> 标记" >&2; exit 1
  }
  case "$auth_level" in
    A1) [ "$role" = "review" ] || { echo "Error: A1 只能由 review 记录" >&2; exit 2; } ;;
    A2) case "$role" in steward|meta) ;; *) echo "Error: A2 只能由 steward/meta 记录" >&2; exit 2 ;; esac ;;
    A3) echo "Error: A3 只能由用户确认，脚本不代记" >&2; exit 2 ;;
    *) echo "Error: 未知 auth_level：$auth_level" >&2; exit 2 ;;
  esac
  if [ -z "$auth_action" ] || [ "$auth_action" = "-" ]; then
    echo "Error: 缺少 auth_action" >&2; exit 2
  fi
  if [ -z "$auth_evidence" ] || [ "$auth_evidence" = "-" ]; then
    echo "Error: 缺少 auth_evidence" >&2; exit 2
  fi
  [ -n "$auth_key" ] || auth_key="${cr}:${task}:${auth_action}:${auth_level}"

  existing_auth="$(awk -v key="- 幂等键：$auth_key" '
    /^## AUTH-/ { id=$2 }
    index($0, key) { print id; exit }
  ' "$ledger")"

  if [ -n "$existing_auth" ] && [ "$force" -ne 1 ]; then
    auth_id="$existing_auth"
    echo "[skip] AUTH $auth_id（幂等键已存在）"
  else
    day="$(date +%Y%m%d)"
    n=1
    while grep -q "^## AUTH-${day}-$(printf '%03d' "$n")$" "$ledger"; do
      n=$((n + 1))
    done
    auth_id="AUTH-${day}-$(printf '%03d' "$n")"

    approver="$role"
    case "$role" in
      review) approver="review-agent" ;;
      steward) approver="steward" ;;
      meta) approver="steward/meta" ;;
    esac

    block="
## $auth_id

- 时间：$(date '+%Y-%m-%d %H:%M:%S %z')
- CR/T：$cr / $task
- 动作：$auth_action
- 级别：$auth_level
- 策略条款：$auth_policy
- 证据：$auth_evidence
- 批准：$approver
- 范围：$auth_scope
- 有效期：$auth_expires
- 撤销：否
- 幂等键：$auth_key
"

    if [ "$dry_run" -eq 1 ]; then
      echo "AUTH (dry-run): $auth_id"
    else
      tmp="$(mktemp)"
      awk -v block="$block" '{ print } index($0, "<!-- auth:rows -->") { print block }' "$ledger" > "$tmp"
      mv "$tmp" "$ledger"
      echo "[write] AUTH $auth_id"
    fi
  fi
fi

# 工作日志
log_id=""
if [ "$do_worklog" -eq 1 ]; then
  existing_log="$(grep -oE '工作日志：LOG-[A-Za-z0-9-]+' "$report" | head -1 | sed 's/.*：//' || true)"
  if [ -n "$existing_log" ] && [ "$force" -ne 1 ] && grep -qF "| $existing_log |" "$worklog" 2>/dev/null; then
    log_id="$existing_log"
    echo "[skip] WORKLOG $log_id（报告已记录）"
  else
    args=()
    args[${#args[@]}]="--file";   args[${#args[@]}]="$worklog"
    args[${#args[@]}]="--role";   args[${#args[@]}]="$role"
    args[${#args[@]}]="--gate";   args[${#args[@]}]="$gate"
    args[${#args[@]}]="--cr";     args[${#args[@]}]="$cr"
    args[${#args[@]}]="--task";   args[${#args[@]}]="$task"
    args[${#args[@]}]="--action"; args[${#args[@]}]="$action"
    args[${#args[@]}]="--report"; args[${#args[@]}]="$rel_report"
    args[${#args[@]}]="--commit"; args[${#args[@]}]="$commit"
    args[${#args[@]}]="--status"; args[${#args[@]}]="$status"
    [ -n "$auth_id" ] && { args[${#args[@]}]="--auth"; args[${#args[@]}]="$auth_id"; }

    if [ "$dry_run" -eq 1 ]; then
      echo "WORKLOG (dry-run): $("$worklog_script" "${args[@]}" --dry-run)"
    else
      log_id="$("$worklog_script" "${args[@]}")"
      echo "[write] WORKLOG $log_id"
    fi
  fi
fi

# 回填报告里的工作日志行
if [ "$dry_run" -eq 0 ] && [ -n "$log_id" ]; then
  tmp="$(mktemp)"
  if grep -q '^- 工作日志：' "$report"; then
    sed "s|^- 工作日志：.*|- 工作日志：$log_id（已追加）|" "$report" > "$tmp"
  else
    awk -v line="- 工作日志：$log_id（已追加）" '
      /^## .*报告[[:space:]]*$/ { print; print ""; print line; next }
      { print }
    ' "$report" > "$tmp"
  fi
  mv "$tmp" "$report"
fi

echo
echo "LOG  : ${log_id:--}"
echo "AUTH : ${auth_id:--}"
if [ "$dry_run" -eq 1 ]; then
  echo "Mode : dry-run（未写入）"
fi
