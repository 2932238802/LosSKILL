#!/usr/bin/env bash
# 脚本自测：在 mktemp 沙箱中回归 CR-002 的脚本行为，不修改仓库文件。
#
# 覆盖：
#   - worklog 追加 / 全键去重 / --time 格式 / 同秒 -2 后缀
#   - finish-report 回填（带后缀标题）/ 幂等 / 无锚点 WARN / 不同报告不去重
#   - 无 python3 时的相对链接（realpath 回退）/ python3 与 realpath 都无时 exit 2
#   - usage 完整性（9 个脚本 -h，含头部插行后仍完整）
#   - capability_index query 空结果（T-001 回归）
#
# 用法：
#   ./scripts/selftest.sh
#   SELFTEST_SRC_DIR=/tmp/broken/scripts ./scripts/selftest.sh   # 指定待测脚本目录（故障注入演示）
#
# 选项：
#   -h, --help   显示本帮助
#
# 已知限制（CR-002 评审 P3，不在本自测范围，未改行为）：
#   --force 重跑会追加 AUTH；--time 帮助文案未展开；CHANGELOG 缺失未断言。

set -uo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
src_dir="${SELFTEST_SRC_DIR:-$repo_root/scripts}"

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
    -h|--help) usage; exit 0 ;;
    *) echo "Error: 未知选项 $1" >&2; exit 2 ;;
  esac
done

[ -d "$src_dir" ] || { echo "Error: 待测脚本目录不存在：$src_dir" >&2; exit 2; }
for f in worklog.sh finish-report.sh; do
  [ -f "$src_dir/$f" ] || { echo "Error: 缺少 $src_dir/$f" >&2; exit 2; }
done

sandbox="$(mktemp -d "${TMPDIR:-/tmp}/losskill-selftest.XXXXXX")" || exit 2
cleanup() {
  if [ "${SELFTEST_KEEP:-0}" = "1" ]; then
    echo "保留下沙箱：$sandbox" >&2
  else
    rm -rf "$sandbox"
  fi
}
trap cleanup EXIT INT TERM

pass_n=0
fail_n=0
pass() { printf 'PASS  %s\n' "$1"; pass_n=$((pass_n + 1)); }
fail() { printf 'FAIL  %s\n' "$1" >&2; fail_n=$((fail_n + 1)); }
skip() { printf 'SKIP  %s\n' "$1"; }

count_rows() {
  [ -f "$1" ] || { echo 0; return; }
  local n
  n="$(grep -cE '^\| LOG-' "$1" 2>/dev/null)" || n=0
  echo "${n:-0}"
}
count_log_lines() {
  [ -f "$1" ] || { echo 0; return; }
  local n
  n="$(grep -cE '^- 工作日志：' "$1" 2>/dev/null)" || n=0
  echo "${n:-0}"
}

# ---- 沙箱：复制待测脚本与最小夹具 ----
sb_scripts="$sandbox/scripts"
work="$sandbox/work"
mkdir -p "$sb_scripts" "$work"
cp "$src_dir/worklog.sh" "$src_dir/finish-report.sh" "$sb_scripts/"
chmod +x "$sb_scripts/worklog.sh" "$sb_scripts/finish-report.sh"
wlog="$sb_scripts/worklog.sh"
freport="$sb_scripts/finish-report.sh"

meta_block() {
  printf '<!-- report-meta\n'
  printf 'role: dev\n'
  printf 'gate: G2\n'
  printf 'cr: CR-002\n'
  printf 'task: T-099\n'
  printf 'status: 完成\n'
  printf 'action: %s\n' "$1"
  printf 'commit: -\n'
  printf 'auth_level: -\n'
  printf 'auth_action: -\n'
  printf 'auth_policy: -\n'
  printf 'auth_evidence: -\n'
  printf 'auth_scope: -\n'
  printf 'auth_expires: 随 CR 结束\n'
  printf 'auth_key: -\n'
  printf '%s\n' '-->'
}

# ---- 1. worklog 追加 ----
wl1="$work/wl-append.md"
out1="$("$wlog" --file "$wl1" --role dev --gate G2 --cr CR-002 --task T-097 \
  --action "追加测试" --report - 2>/dev/null)"
rc1=$?
if [ "$rc1" -eq 0 ] && [ "$(count_rows "$wl1")" -eq 1 ] \
  && grep -qF '追加测试' "$wl1" \
  && printf '%s' "$out1" | grep -qE '^LOG-[0-9]{8}-[0-9]{6}'; then
  pass "worklog 追加（1 行，输出 LOG ID）"
else
  fail "worklog 追加（rc=$rc1 rows=$(count_rows "$wl1") out=$out1）"
fi

# ---- 2. worklog 全键去重 ----
wl2="$work/wl-dedup.md"
"$wlog" --file "$wl2" --role dev --gate G2 --cr CR-002 --task T-096 \
  --action "去重测试" --report "r.md" >/dev/null 2>&1
"$wlog" --file "$wl2" --role dev --gate G2 --cr CR-002 --task T-096 \
  --action "去重测试" --report "r.md" >/dev/null 2>"$work/dedup.err"
if [ "$(count_rows "$wl2")" -eq 1 ] && grep -q '\[skip\]' "$work/dedup.err"; then
  pass "worklog 全键去重（同键仅 1 行）"
else
  fail "worklog 全键去重（rows=$(count_rows "$wl2")）"
fi

# ---- 3. --time 格式统一 ----
wl3="$work/wl-time.md"
id3="$("$wlog" --file "$wl3" --role dev --gate G2 --cr CR-002 --task T-095 \
  --action "时间格式" --time "2026-11-20 10:00:00" 2>/dev/null)"
if [ "$id3" = "LOG-20261120-100000" ]; then
  pass "--time 格式（LOG-YYYYMMDD-HHMMSS）"
else
  fail "--time 格式（got=$id3）"
fi

# ---- 4. 同秒 -2 后缀 ----
wl4="$work/wl-suffix.md"
id4a="$("$wlog" --file "$wl4" --role dev --gate G2 --cr CR-002 --task T-094 \
  --action "同秒甲" --time "2026-11-20 11:11:11" 2>/dev/null)"
id4b="$("$wlog" --file "$wl4" --role dev --gate G2 --cr CR-002 --task T-094 \
  --action "同秒乙" --time "2026-11-20 11:11:11" 2>/dev/null)"
if [ "$id4a" = "LOG-20261120-111111" ] && [ "$id4b" = "LOG-20261120-111111-2" ]; then
  pass "同秒 -2 后缀"
else
  fail "同秒 -2 后缀（a=$id4a b=$id4b）"
fi

# ---- 5. finish-report 带后缀标题回填 + 幂等 ----
repA="$work/repA.md"
wlA="$work/wl-A.md"
{
  printf '## Dev Agent 交付报告 — T-099\n\n'
  meta_block "带后缀标题回填"
  printf '正文开始。\n'
} > "$repA"
"$freport" --report "$repA" --worklog "$wlA" --no-auth >/dev/null 2>"$work/errA1"
"$freport" --report "$repA" --worklog "$wlA" --no-auth >/dev/null 2>"$work/errA2"
if [ "$(count_rows "$wlA")" -eq 1 ] && [ "$(count_log_lines "$repA")" -eq 1 ]; then
  pass "finish-report 带后缀标题回填 + 幂等（1 行 / 1 条）"
else
  fail "finish-report 带后缀标题回填 + 幂等（rows=$(count_rows "$wlA") loglines=$(count_log_lines "$repA")）"
fi

# ---- 6. finish-report 无后缀标题回填 + 幂等（回归） ----
repB="$work/repB.md"
wlB="$work/wl-B.md"
{
  printf '## 报告\n\n'
  meta_block "无后缀标题回填"
  printf '\n正文。\n'
} > "$repB"
"$freport" --report "$repB" --worklog "$wlB" --no-auth >/dev/null 2>&1
"$freport" --report "$repB" --worklog "$wlB" --no-auth >/dev/null 2>&1
if [ "$(count_rows "$wlB")" -eq 1 ] && [ "$(count_log_lines "$repB")" -eq 1 ]; then
  pass "finish-report 无后缀标题回填 + 幂等（1 行 / 1 条）"
else
  fail "finish-report 无后缀标题回填 + 幂等（rows=$(count_rows "$wlB") loglines=$(count_log_lines "$repB")）"
fi

# ---- 7. finish-report 无锚点 WARN，WORKLOG 仍 1 行 ----
repC="$work/repC.md"
wlC="$work/wl-C.md"
{
  meta_block "无锚点 WARN"
  printf '正文直接开始，无空行、无标题。\n'
} > "$repC"
"$freport" --report "$repC" --worklog "$wlC" --no-auth >/dev/null 2>"$work/errC1"
"$freport" --report "$repC" --worklog "$wlC" --no-auth >/dev/null 2>"$work/errC2"
if [ "$(count_rows "$wlC")" -eq 1 ] \
  && grep -q '未找到日志插入点' "$work/errC1" \
  && grep -q '未找到日志插入点' "$work/errC2"; then
  pass "finish-report 无锚点 WARN + 幂等（1 行）"
else
  fail "finish-report 无锚点 WARN + 幂等（rows=$(count_rows "$wlC")）"
fi

# ---- 8. 不同报告（不同 action）不误去重 ----
repD="$work/repD.md"
repE="$work/repE.md"
wlDE="$work/wl-DE.md"
{ printf '## 报告\n\n'; meta_block "动作甲"; printf '\n正文。\n'; } > "$repD"
{ printf '## 报告\n\n'; meta_block "动作乙"; printf '\n正文。\n'; } > "$repE"
"$freport" --report "$repD" --worklog "$wlDE" --no-auth >/dev/null 2>&1
"$freport" --report "$repE" --worklog "$wlDE" --no-auth >/dev/null 2>&1
if [ "$(count_rows "$wlDE")" -eq 2 ]; then
  pass "不同报告不误去重（2 行）"
else
  fail "不同报告不误去重（rows=$(count_rows "$wlDE")）"
fi

# ---- 9/10. 受限 PATH 夹具 ----
make_bin() { # $1=目标目录 $2=是否包含 realpath(1/0)
  local dir="$1" want_realpath="$2" c p
  mkdir -p "$dir"
  for c in bash dirname basename awk grep sed date mktemp cat mv rm tr mkdir; do
    p="$(command -v "$c" 2>/dev/null || true)"
    [ -n "$p" ] && ln -s "$p" "$dir/$c"
  done
  if [ "$want_realpath" = "1" ]; then
    p="$(command -v realpath 2>/dev/null || true)"
    [ -n "$p" ] && ln -s "$p" "$dir/realpath"
  fi
}

# ---- 9. 无 python3、有 realpath → 相对链接 ----
bin_rp="$sandbox/bin-realpath"
make_bin "$bin_rp" 1
if [ -e "$bin_rp/realpath" ]; then
  wlP="$work/wl-P.md"
  mkdir -p "$work/reports"
  { printf '## 报告\n\n'; meta_block "无 python3 路径"; printf '\n正文。\n'; } > "$work/reports/repP.md"
  PATH="$bin_rp" "$freport" --report "$work/reports/repP.md" --worklog "$wlP" \
    --no-auth >/dev/null 2>"$work/errP"
  rcP=$?
  linkP="$(grep -oE '\[[^]]*\]\([^)]*\)' "$wlP" 2>/dev/null | head -1)"
  if [ "$rcP" -eq 0 ] && [ "$(count_rows "$wlP")" -eq 1 ] \
    && [ -n "$linkP" ] && ! printf '%s' "$linkP" | grep -q '](/'; then
    pass "无 python3、有 realpath → 相对链接"
  else
    fail "无 python3、有 realpath（rc=$rcP link=$linkP）"
  fi
else
  skip "无 python3 相对链接（本机缺少 realpath）"
fi

# ---- 10. python3 与 realpath 都无 → exit 2 ----
bin_norp="$sandbox/bin-nonerealpath"
make_bin "$bin_norp" 0
repQ="$work/repQ.md"
{ printf '## 报告\n\n'; meta_block "两者都无"; printf '\n正文。\n'; } > "$repQ"
PATH="$bin_norp" "$freport" --report "$repQ" --worklog "$work/wl-Q.md" \
  --no-auth >/dev/null 2>"$work/errQ"
rcQ=$?
if [ "$rcQ" -eq 2 ] && grep -qE '无法计算相对路径|缺少 python3 与 realpath' "$work/errQ" \
  && [ ! -s "$work/wl-Q.md" ]; then
  pass "python3 与 realpath 都无 → exit 2 且不写链接"
else
  fail "python3 与 realpath 都无（rc=$rcQ）"
fi

# ---- 11. usage 完整性（9 个脚本 -h） ----
usage_scripts=(
  "$repo_root/scripts/bootstrap-project.sh"
  "$repo_root/scripts/finish-report.sh"
  "$repo_root/scripts/install-claude-config.sh"
  "$repo_root/scripts/install-git-hooks.sh"
  "$repo_root/scripts/install-vscode-config.sh"
  "$repo_root/scripts/new-skill.sh"
  "$repo_root/scripts/sync-skills.sh"
  "$repo_root/scripts/worklog.sh"
  "$repo_root/setup.sh"
)
usage_bad=""
for s in "${usage_scripts[@]}"; do
  [ -f "$s" ] || { usage_bad="$usage_bad ${s##*/}:missing"; continue; }
  hout="$("$s" -h 2>/dev/null)"
  hrc=$?
  [ "$hrc" -eq 0 ] && [ -n "$hout" ] || usage_bad="$usage_bad ${s##*/}:rc=$hrc"
done
fin_h="$("$repo_root/scripts/finish-report.sh" -h 2>/dev/null)"
wlog_h="$("$repo_root/scripts/worklog.sh" -h 2>/dev/null)"
if [ -z "$usage_bad" ] \
  && printf '%s' "$fin_h" | grep -q -- '--force' \
  && printf '%s' "$wlog_h" | grep -q -- '--time'; then
  pass "usage 完整性（9 个脚本 -h 且关键选项齐全）"
else
  fail "usage 完整性（问题：${usage_bad:-关键选项缺失}）"
fi

# ---- 12. usage 头部插行后仍完整（不依赖固定行号） ----
head_fr="$sandbox/scripts/finish-report-head.sh"
{
  head -1 "$src_dir/finish-report.sh"
  printf '# 测试：额外插入的头部注释行，应不影响 usage 截取。\n'
  tail -n +2 "$src_dir/finish-report.sh"
} > "$head_fr"
chmod +x "$head_fr"
hout2="$("$head_fr" -h 2>/dev/null)"
if printf '%s' "$hout2" | grep -q -- '--force' \
  && printf '%s' "$hout2" | grep -q -- '--dry-run'; then
  pass "usage 头部插行后仍完整"
else
  fail "usage 头部插行（关键选项缺失）"
fi

# ---- 13. query 空结果（T-001 回归） ----
cap_py="$repo_root/skills/leverage-protocol/scripts/capability_index.py"
if command -v python3 >/dev/null 2>&1 && [ -f "$cap_py" ]; then
  idx_out="$sandbox/index.json"
  qout="$(python3 "$cap_py" query qqqzzz --roots "$repo_root/skills" --out "$idx_out" 2>&1)"
  qrc=$?
  if [ "$qrc" -eq 1 ] \
    && printf '%s' "$qout" | grep -q '没有匹配' \
    && ! printf '%s' "$qout" | grep -q 'Traceback'; then
    pass "query qqqzzz 空结果（无匹配，exit 1，无 traceback）"
  else
    fail "query qqqzzz 空结果（rc=$qrc）"
  fi
else
  skip "query 空结果（缺少 python3 或 capability_index.py）"
fi

# ---- 汇总 ----
echo
echo "selftest: PASS=$pass_n FAIL=$fail_n"
if [ "$fail_n" -gt 0 ]; then
  exit 1
fi
exit 0
