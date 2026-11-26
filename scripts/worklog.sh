#!/usr/bin/env bash
# 追加一条 Agent 工作日志到 WORKLOG.md（只追加，最新在上）。
#
# 用法：
#   ./scripts/worklog.sh --file LosAngelousDocs/WORKLOG.md \
#     --role dev --gate G2 --cr CR-004 --task T-012 \
#     --action "实现登录限流与 3 个回归测试" \
#     --report LosAngelousDocs/reports/dev-2026-11-20-T-012.md \
#     --commit a1b2c3d --auth AUTH-20261120-001 --status 完成
#
# 选项：
#   --file PATH      WORKLOG 路径（默认 WORKLOG.md）
#   --role ROLE      doc / dev / review / steward / meta / user
#   --gate GATE      G0 / G1 / G2 / G2.5 / G3 / G3.5 / G4
#   --cr ID          需求卡 ID（可空）
#   --task ID        任务 ID（可空）
#   --action TEXT    做了什么（必填）
#   --report PATH    报告路径或 Markdown 链接（可空）
#   --commit HASH    提交 hash（可空）
#   --auth ID        授权条目 ID（可空）
#   --status TEXT    完成 / 返工 / 阻塞 / 有条件通过…（默认 完成）
#   --time TEXT      覆盖时间（默认当前本地时间，便于测试；取 14 位数字，可带分隔符）
#   --dry-run        只打印将写入的行
#   -h, --help       帮助

set -euo pipefail

file="WORKLOG.md"
role=""
gate=""
cr="-"
task="-"
action=""
report="-"
commit="-"
auth="-"
status="完成"
time_override=""
dry_run=0

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
    --file)    [ "$#" -ge 2 ] || { echo "Error: --file 需要路径" >&2; exit 2; }; file="$2"; shift 2 ;;
    --role)    [ "$#" -ge 2 ] || { echo "Error: --role 需要值" >&2; exit 2; }; role="$2"; shift 2 ;;
    --gate)    [ "$#" -ge 2 ] || { echo "Error: --gate 需要值" >&2; exit 2; }; gate="$2"; shift 2 ;;
    --cr)      [ "$#" -ge 2 ] || { echo "Error: --cr 需要值" >&2; exit 2; }; cr="$2"; shift 2 ;;
    --task)    [ "$#" -ge 2 ] || { echo "Error: --task 需要值" >&2; exit 2; }; task="$2"; shift 2 ;;
    --action)  [ "$#" -ge 2 ] || { echo "Error: --action 需要值" >&2; exit 2; }; action="$2"; shift 2 ;;
    --report)  [ "$#" -ge 2 ] || { echo "Error: --report 需要值" >&2; exit 2; }; report="$2"; shift 2 ;;
    --commit)  [ "$#" -ge 2 ] || { echo "Error: --commit 需要值" >&2; exit 2; }; commit="$2"; shift 2 ;;
    --auth)    [ "$#" -ge 2 ] || { echo "Error: --auth 需要值" >&2; exit 2; }; auth="$2"; shift 2 ;;
    --status)  [ "$#" -ge 2 ] || { echo "Error: --status 需要值" >&2; exit 2; }; status="$2"; shift 2 ;;
    --time)    [ "$#" -ge 2 ] || { echo "Error: --time 需要值" >&2; exit 2; }; time_override="$2"; shift 2 ;;
    --dry-run) dry_run=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Error: 未知选项 $1" >&2; exit 2 ;;
  esac
done

[ -n "$role" ] || { echo "Error: 缺少 --role" >&2; exit 2; }
[ -n "$gate" ] || { echo "Error: 缺少 --gate" >&2; exit 2; }
[ -n "$action" ] || { echo "Error: 缺少 --action" >&2; exit 2; }

case "$role" in
  doc|dev|review|steward|meta|user) ;;
  *) echo "Error: --role 只能是 doc / dev / review / steward / meta / user" >&2; exit 2 ;;
esac

now="${time_override:-$(date '+%Y-%m-%d %H:%M:%S %z')}"
if [ -n "$time_override" ]; then
  # 任何时间输入统一为 LOG-YYYYMMDD-HHMMSS；不足 14 位数字则拒绝（设计 §6.3）
  digits="$(printf '%s' "$time_override" | tr -cd '0-9')"
  if [ "${#digits}" -lt 14 ]; then
    echo "Error: --time 需包含至少 14 位数字（YYYYMMDDHHMMSS）：$time_override" >&2
    exit 2
  fi
  digits="${digits:0:14}"
  base_id="LOG-${digits:0:8}-${digits:8:8}"
else
  base_id="LOG-$(date '+%Y%m%d-%H%M%S')"
fi

escape_cell() {
  printf '%s' "$1" | tr '\n' ' ' | sed 's/|/\\|/g'
}

if [ "$dry_run" -eq 0 ] && [ ! -f "$file" ]; then
  mkdir -p "$(dirname "$file")"
  cat > "$file" <<'EOF'
# 工作日志

> 每个 Agent 完成一次工作后追加一行；只追加，不删改，最新在最上面。

| ID | 时间 | 角色 | 门禁 | CR / T | 做了什么 | 报告 | Commit | AUTH | 状态 |
|---|---|---|---|---|---|---|---|---|---|
<!-- worklog:rows -->
EOF
fi

if [ "$dry_run" -eq 0 ] && ! grep -qF '<!-- worklog:rows -->' "$file"; then
  printf '\n| ID | 时间 | 角色 | 门禁 | CR / T | 做了什么 | 报告 | Commit | AUTH | 状态 |\n|---|---|---|---|---|---|---|---|---|---|\n<!-- worklog:rows -->\n' >> "$file"
fi

# 同一秒内多次追加时，用 -2、-3 去重
id="$base_id"
if [ "$dry_run" -eq 0 ]; then
  n=1
  while grep -qF "| $id |" "$file"; do
    n=$((n + 1))
    id="${base_id}-$n"
  done
fi

# 报告：路径转 Markdown 链接；已经是链接或 URL 就原样保留
report_cell="$report"
if [ "$report" != "-" ] && [ -n "$report" ]; then
  case "$report" in
    http*|*']('*) report_cell="$report" ;;
    /*|[A-Za-z]:[\\/]*)
      # 绝对路径：直接做链接目标，不拼接到 WORKLOG 目录
      report_cell="[$(basename "$report")]($report)"
      ;;
    *)
      wd="$(dirname "$file")"
      [ -e "$wd/$report" ] || echo "  [warn] 报告不存在：$wd/$report" >&2
      report_cell="[$(basename "$report")]($report)"
      ;;
  esac
fi
role_cell="$(escape_cell "$role")"
gate_cell="$(escape_cell "$gate")"
cr_task_cell="$(escape_cell "$cr") / $(escape_cell "$task")"
action_cell="$(escape_cell "$action")"
report_cell_esc="$(escape_cell "$report_cell")"

# 幂等：同一 report + role + gate + cr + task + action 已写入则跳过（D-007 / 设计 §6.2）
if [ "$dry_run" -eq 0 ] && [ "$report_cell" != "-" ]; then
  needle="| $role_cell | $gate_cell | $cr_task_cell | $action_cell | $report_cell_esc |"
  existing_id="$(grep -F -- "$needle" "$file" 2>/dev/null | head -1 | awk -F'|' '{ gsub(/^[[:space:]]+|[[:space:]]+$/, "", $2); print $2 }' || true)"
  if [ -n "$existing_id" ]; then
    echo "[skip] WORKLOG $existing_id（幂等键已存在）" >&2
    echo "$existing_id"
    exit 0
  fi
fi

row="| $(escape_cell "$id") | $(escape_cell "$now") | $role_cell | $gate_cell | $cr_task_cell | $action_cell | $report_cell_esc | $(escape_cell "$commit") | $(escape_cell "$auth") | $(escape_cell "$status") |"

if [ "$dry_run" -eq 1 ]; then
  echo "$row"
  exit 0
fi

tmp="$(mktemp)"
awk -v row="$row" '{ print } /<!-- worklog:rows -->/{ print row }' "$file" > "$tmp"
mv "$tmp" "$file"

echo "$id"
