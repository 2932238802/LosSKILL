#!/usr/bin/env bash
# 解析标准报告头部，自动追加 WORKLOG 与 AUTHORIZATIONS，并回填 LOG-ID。
#
# 用法：
#   ./scripts/finish-report.sh --report LosAngelousDocs/reports/dev-2026-11-20-T-012.md
#   ./scripts/finish-report.sh --report LosAngelousDocs/reports/review-2026-11-20-T-012.md --dry-run
#   ./scripts/finish-report.sh --report ... --worklog LosAngelousDocs/WORKLOG.md --ledger LosAngelousDocs/AUTHORIZATIONS.md
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
#   --report PATH      必填（--backfill 模式下不需要）
#   --worklog PATH     默认 <项目根>/WORKLOG.md（未给 --project-root 时为 ./WORKLOG.md）
#   --ledger PATH      默认 <项目根>/AUTHORIZATIONS.md
#   --project-root DIR 项目根；用于解析 WORKLOG / AUTHORIZATIONS 默认路径
#   --role / --gate / --cr / --task / --status / --action / --commit   覆盖解析结果
#   --backfill         只回填台账：要求同时给 --auth 与 --commit
#   --auth ID          配合 --backfill，指定 AUTH-YYYYMMDD-NNN
#   --no-worklog       不写工作日志
#   --no-auth          不写授权台账
#   --force            忽略已存在记录，重跑回填与 AUTH；WORKLOG 仍按全键去重
#   --dry-run          只打印，不写入
#   -h, --help

# auth_level 取值：A1c（分支 commit，Review 批）、A2（push/依赖/CI，Steward 批）。
# A1w 由 G1 信封授权，只记 WORKLOG，不写台账；旧值 A1 视为 A1c 并给出提示。

set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
worklog_script="$repo_root/scripts/worklog.sh"

report=""
worklog="WORKLOG.md"
ledger="AUTHORIZATIONS.md"
worklog_set=0
ledger_set=0
project_root=""
do_worklog=1
do_auth=1
dry_run=0
force=0
backfill=0
backfill_auth=""

role_override=""; gate_override=""; cr_override=""; task_override=""
status_override=""; action_override=""; commit_override=""

usage() {
  # 截取开头连续注释块（直到第一行代码），不依赖固定行号（设计 §6.4）
  awk '
    NR == 1 { next }
    /^#/ { while (pending > 0) { print ""; pending-- }
           line = $0; sub(/^# ?/, "", line); print line; started = 1; next }
    /^[[:space:]]*$/ { if (started) pending++; next }
    { exit }
  ' "$0"
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --report)        [ "$#" -ge 2 ] || { echo "Error: --report 需要路径" >&2; exit 2; }; report="$2"; shift 2 ;;
    --worklog)       [ "$#" -ge 2 ] || { echo "Error: --worklog 需要路径" >&2; exit 2; }; worklog="$2"; worklog_set=1; shift 2 ;;
    --ledger)        [ "$#" -ge 2 ] || { echo "Error: --ledger 需要路径" >&2; exit 2; }; ledger="$2"; ledger_set=1; shift 2 ;;
    --project-root)  [ "$#" -ge 2 ] || { echo "Error: --project-root 需要路径" >&2; exit 2; }; project_root="$2"; shift 2 ;;
    --backfill)      backfill=1; shift ;;
    --auth)          [ "$#" -ge 2 ] || { echo "Error: --auth 需要 ID" >&2; exit 2; }; backfill_auth="$2"; shift 2 ;;
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

# --project-root 只解析默认路径；显式 --worklog / --ledger 优先
if [ -n "$project_root" ]; then
  [ -d "$project_root" ] || { echo "Error: 项目根不存在：$project_root" >&2; exit 2; }
  project_root="$(cd "$project_root" && pwd)"
  [ "$worklog_set" -eq 1 ] || worklog="$project_root/WORKLOG.md"
  [ "$ledger_set" -eq 1 ] || ledger="$project_root/AUTHORIZATIONS.md"
fi

# --backfill：只回填台账里某条 AUTH 的 commit hash，不解析报告
if [ "$backfill" -eq 1 ]; then
  [ "$do_worklog" -eq 1 ] || { echo "Error: --backfill 不能与 --no-worklog 同用" >&2; exit 2; }
  [ -n "$backfill_auth" ] || { echo "Error: --backfill 需要 --auth AUTH-YYYYMMDD-NNN" >&2; exit 2; }
  commit="$commit_override"
  [ -n "$commit" ] && [ "$commit" != "-" ] || { echo "Error: --backfill 需要 --commit <hash>" >&2; exit 2; }
  printf '%s' "$commit" | grep -qE '^[0-9a-fA-F]{7,40}$' || {
    echo "Error: commit 应为 7–40 位十六进制：$commit" >&2; exit 2; }
  [ -f "$ledger" ] || { echo "Error: 授权台账不存在：$ledger" >&2; exit 1; }
  rc=0
  awk -v id="$backfill_auth" -v commit="$commit" '
    BEGIN { found=0; inblock=0; done=0 }
    $0 ~ "^## " id "$" { found=1; inblock=1; print; next }
    inblock && /^## / {
      if (!done) { print "- Commit：" commit; done=1 }
      inblock=0; print; next
    }
    inblock && /^- Commit：/ {
      if (!done) { print "- Commit：" commit; done=1 }
      next
    }
    inblock && /^- 幂等键：/ {
      print
      if (!done) { print "- Commit：" commit; done=1 }
      next
    }
    { print }
    END {
      if (!found) exit 3
      if (inblock && !done) print "- Commit：" commit
    }
  ' "$ledger" > "$ledger.backfill.tmp" || rc=$?
  rc=${rc:-0}
  if [ "$rc" -eq 3 ]; then rm -f "$ledger.backfill.tmp"; echo "Error: 台账中找不到 $backfill_auth" >&2; exit 1; fi
  if [ "$rc" -ne 0 ]; then rm -f "$ledger.backfill.tmp"; echo "Error: 回填失败（awk exit $rc）" >&2; exit 1; fi
  if [ "$dry_run" -eq 1 ]; then
    echo "AUTH (dry-run) backfill: $backfill_auth <- $commit"
    rm -f "$ledger.backfill.tmp"
  else
    mv "$ledger.backfill.tmp" "$ledger"
    echo "[backfill] $backfill_auth <- $commit"
  fi
  exit 0
fi

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
rel_report=""
# Windows 上 python3 可能是 Store 假壳（存在但执行失败），失败时回退 realpath
if command -v python3 >/dev/null 2>&1; then
  rel_report="$(python3 -c 'import os,sys; print(os.path.relpath(sys.argv[1], sys.argv[2]))' "$report_abs" "$worklog_dir" 2>/dev/null || true)"
fi
if [ -z "$rel_report" ]; then
  if command -v realpath >/dev/null 2>&1; then
    rel_report="$(realpath --relative-to="$worklog_dir" "$report_abs" 2>/dev/null || true)"
  fi
fi
if [ -z "$rel_report" ]; then
  echo "Error: 无法计算相对路径（python3 与 realpath 均不可用）：$report_abs 相对于 $worklog_dir" >&2
  exit 2
fi

# 授权台账
auth_id=""
case "$auth_level" in
  A1) echo "[warn] auth_level=A1 已废弃，按 A1c（commit）处理" >&2; auth_level="A1c" ;;
  A1w) echo "[skip] A1w（写入）只记 WORKLOG，不写台账" >&2; auth_level="-" ;;
esac
if [ "$do_auth" -eq 1 ] && [ -n "$auth_level" ] && [ "$auth_level" != "-" ]; then
  [ -f "$ledger" ] || { echo "Error: 授权台账不存在：$ledger" >&2; exit 1; }
  grep -qF '<!-- auth:rows -->' "$ledger" || {
    echo "Error: $ledger 缺少 <!-- auth:rows --> 标记" >&2; exit 1
  }
  case "$auth_level" in
    A1c) case "$role" in
          review) ;;
          steward|meta) ;;   # 例外：用户要求 Dev 自行提交时，由 Steward/Meta 记账
          *) echo "Error: A1c 只能由 review（或例外场景下的 steward/meta）记录" >&2; exit 2 ;;
        esac ;;
    A2) case "$role" in steward|meta) ;; *) echo "Error: A2 只能由 steward/meta 记录" >&2; exit 2 ;; esac ;;
    A3) echo "Error: A3 只能由用户确认，脚本不代记" >&2; exit 2 ;;
    *) echo "Error: 未知 auth_level：$auth_level（只接受 A1c / A2）" >&2; exit 2 ;;
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
      errfile="$(mktemp)"
      rc=0
      log_id="$("$worklog_script" "${args[@]}" 2>"$errfile")" || rc=$?
      if [ "$rc" -ne 0 ]; then
        if [ -s "$errfile" ]; then cat "$errfile" >&2; fi
        rm -f "$errfile"
        exit "$rc"
      fi
      # 成功时透传 WARN 等提示；[skip] 由下方统一打印，避免重复
      if [ -s "$errfile" ]; then
        grep -v '^\[skip\] WORKLOG' "$errfile" >&2 || true
      fi
      if grep -qF '[skip] WORKLOG' "$errfile"; then
        echo "[skip] WORKLOG $log_id（幂等键已存在）"
      else
        echo "[write] WORKLOG $log_id"
      fi
      rm -f "$errfile"
    fi
  fi
fi

# 回填报告里的工作日志行
if [ "$dry_run" -eq 0 ] && [ -n "$log_id" ]; then
  log_line="- 工作日志：$log_id（已追加）"
  tmp="$(mktemp)"
  if grep -q '^- 工作日志：' "$report"; then
    sed "s|^- 工作日志：.*|$log_line|" "$report" > "$tmp"
    mv "$tmp" "$report"
  else
    # 锚点：优先 report-meta 结束后的第一个空行；回退首个 ## 标题（设计 §6.1）
    anchor="$(awk '
      /<!--[[:space:]]*report-meta/ { inmeta = 1; next }
      inmeta { if ($0 ~ /-->/) { inmeta = 0; metadone = 1 } next }
      metadone && !found && $0 ~ /^[[:space:]]*$/ { print NR; found = 1; exit }
      END { exit(found ? 0 : 1) }
    ' "$report" || true)"
    if [ -n "$anchor" ]; then
      awk -v n="$anchor" -v line="$log_line" 'NR == n { print; print line; next } { print }' "$report" > "$tmp"
      mv "$tmp" "$report"
    else
      heading="$(awk '/^## / { print NR; exit }' "$report")"
      if [ -n "$heading" ]; then
        awk -v n="$heading" -v line="$log_line" 'NR == n { print; print ""; print line; next } { print }' "$report" > "$tmp"
        mv "$tmp" "$report"
      else
        echo "[warn] 未找到日志插入点" >&2
      fi
    fi
  fi
  rm -f "$tmp"
fi

echo
echo "LOG  : ${log_id:--}"
echo "AUTH : ${auth_id:--}"
if [ "$dry_run" -eq 1 ]; then
  echo "Mode : dry-run（未写入）"
fi
