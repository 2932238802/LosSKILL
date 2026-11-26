#!/usr/bin/env bash
# 只读工作流状态诊断：读 STATUS / 大脑 / 台账 / WORKLOG，打印当前门禁、下一步与必跑检查。
#
# 用法：
#   ./scripts/workflow-status.sh <文档根目录>
#   ./scripts/workflow-status.sh <文档根目录> --project-root /path/to/project
#   ./scripts/workflow-status.sh <文档根目录> --project-root . --check
#
# 选项：
#   --project-root DIR  项目根（默认：文档根目录的父目录）
#   --check             实际运行对应门禁的 check-docs，并打印退出码
#   --lines N           最近 WORKLOG 行数（默认 5）
#   -h, --help
#
# 退出码：0 = 诊断完成（不代表门禁通过）；2 = 用法/路径错误。

set -uo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
check_docs="$repo_root/scripts/check-docs.sh"

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
project_root=""
do_check=0
lines=5

while [ "$#" -gt 0 ]; do
  case "$1" in
    --project-root) [ "$#" -ge 2 ] || { echo "Error: --project-root 需要路径" >&2; exit 2; }; project_root="$2"; shift ;;
    --check)        do_check=1 ;;
    --lines)        [ "$#" -ge 2 ] || { echo "Error: --lines 需要数字" >&2; exit 2; }; lines="$2"; shift ;;
    -h|--help)      usage; exit 0 ;;
    -*)             echo "Error: 未知选项 $1" >&2; exit 2 ;;
    *)
      if [ -z "$doc_root" ]; then doc_root="$1"; else echo "Error: 多余参数 $1" >&2; exit 2; fi
      ;;
  esac
  shift
done

[ -n "$doc_root" ] || { echo "Error: 缺少文档根目录" >&2; usage >&2; exit 2; }
[ -d "$doc_root" ] || { echo "Error: 文档根目录不存在：$doc_root" >&2; exit 2; }
doc_root="$(cd "$doc_root" && pwd)"

if [ -z "$project_root" ]; then
  project_root="$(dirname "$doc_root")"
fi
[ -d "$project_root" ] || { echo "Error: 项目根不存在：$project_root" >&2; exit 2; }
project_root="$(cd "$project_root" && pwd)"

# 记录根：默认项目根；存量项目允许文档根
record_file() {
  local n="$1"
  [ -f "$project_root/$n" ] && { printf '%s' "$project_root/$n"; return 0; }
  [ -f "$doc_root/$n" ] && { printf '%s' "$doc_root/$n"; return 0; }
  return 1
}

field() { # STATUS 的单行字段
  sed -nE "s/^[[:space:]]*-?[[:space:]]*\**$1\**[[:space:]]*(：|:)[[:space:]]*(.*)$/\2/p" "$doc_root/STATUS.md" 2>/dev/null | head -1
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
      # 「无 / none / - / 空白」是明确的无活动 CR，不回退候选
      *) printf ''; return 0 ;;
    esac
  fi
  # 仅当 STATUS 缺「当前 CR」字段时才回退 intake 最大编号（保持旧行为）
  grep -oE 'CR-[0-9]+' "$doc_root/00-requirements-intake.md" 2>/dev/null | sort -t- -k2 -n | tail -1
}

# 按当前 CR 选 AUTHORIZATIONS.md 的范围信封。多个 ## 块时精确匹配块标题里的 CR；
# 无匹配则回退最后一条并标注；输出 TSV：MATCH/FALLBACK <policy> <expires> <max_commits> [<tag>]
envelope_for_cr() {
  local auth="$1" cr="$2"
  awk -v want="$cr" '
    function flush() {
      if (policy != "") {
        if (cr_tag == want && !matched) { m_policy = policy; m_exp = expy; m_max = maxc; matched = 1 }
        l_policy = policy; l_exp = expy; l_max = maxc; l_tag = cr_tag
      }
    }
    /^## / {
      flush()
      policy = ""; expy = ""; maxc = ""; cr_tag = ""
      if (match($0, /CR-[0-9]+/)) cr_tag = substr($0, RSTART, RLENGTH)
      next
    }
    policy == "" && /^policy:[[:space:]]*/ { line = $0; sub(/^policy:[[:space:]]*/, "", line); sub(/[[:space:]]+$/, "", line); policy = line; next }
    expy == "" && /^expires:[[:space:]]*/ { line = $0; sub(/^expires:[[:space:]]*/, "", line); sub(/[[:space:]]+$/, "", line); expy = line; next }
    maxc == "" && /^max_commits:[[:space:]]*/ { line = $0; sub(/^max_commits:[[:space:]]*/, "", line); sub(/[[:space:]]+$/, "", line); maxc = line; next }
    END {
      flush()
      if (matched) printf "MATCH\t%s\t%s\t%s\n", m_policy, m_exp, m_max
      else if (l_policy != "") printf "FALLBACK\t%s\t%s\t%s\t%s\n", l_policy, l_exp, l_max, l_tag
    }
  ' "$auth"
}

echo "== 工作流状态 =="
echo "文档根：$doc_root"
echo "项目根：$project_root"
if worklog="$(record_file WORKLOG.md)"; then echo "记录根：$(dirname "$worklog")"; else echo "记录根：缺失 WORKLOG.md"; fi
echo

cr="$(current_cr)"
gate="$(field '当前门禁')"
g1="$(field 'G1 已确认')"
channel="$(field '通道')"
pg="$(field '并行组')"
block="$(field '阻塞')"
next="$(field '下一步')"
accepted="$(field 'G3 已接受')"
exempt="$(field 'G4 豁免')"

if [ -n "$cr" ]; then echo "当前 CR：$cr"; else echo "当前 CR：无"; fi
echo "当前门禁：${gate:-未知}"
echo "G1 已确认：${g1:-未写}"
[ -n "$channel" ] && echo "通道：$channel"
[ -n "$pg" ] && echo "并行组：$pg"
[ -n "$accepted" ] && echo "G3 接受：$accepted"
[ -n "$exempt" ] && echo "G4 豁免：$exempt"
[ -n "$block" ] && [ "$block" != "无" ] && echo "阻塞：$block"
echo

# 大脑成熟度
if brain="$(record_file PROJECT_BRAIN.md)"; then
  echo "大脑：$brain"
  sed -nE 's/^>[[:space:]]*状态(：|:)[[:space:]]*(.*)$/  状态：\2/p' "$brain" 2>/dev/null | head -1
else
  echo "大脑：缺失 PROJECT_BRAIN.md"
fi

# 当前信封
if auth="$(record_file AUTHORIZATIONS.md)"; then
  if [ -z "$cr" ]; then
    echo "信封：无活动 CR（STATUS.md 当前 CR 为空，不显示历史 policy）"
  else
    envelope="$(envelope_for_cr "$auth" "$cr")"
    if [ -z "$envelope" ]; then
      echo "信封：未填写（AUTHORIZATIONS.md 没有 policy）"
    else
      IFS=$'\t' read -r env_kind env_policy env_expires env_max env_tag <<< "$envelope"
      if [ "$env_kind" = "FALLBACK" ]; then
        echo "信封：${env_policy}（回退：无 ${cr} 匹配信封，取最后一条${env_tag:+ $env_tag}；到期 ${env_expires:-未填写}，提交上限 ${env_max:-未填写}）"
      else
        echo "信封：${env_policy}（到期 ${env_expires:-未填写}，提交上限 ${env_max:-未填写}）"
      fi
    fi
  fi
else
  echo "信封：缺失 AUTHORIZATIONS.md"
fi
echo

# 最近 WORKLOG
if worklog="$(record_file WORKLOG.md)"; then
  echo "== 最近 $lines 条 WORKLOG =="
  grep -E '^\| LOG-' "$worklog" 2>/dev/null | head -n "$lines" | sed -E 's/^/  /'
  echo
fi

# 下一步建议
echo "== 下一步 =="
gate_num="$(printf '%s' "$gate" | grep -oE 'G[0-9]+(\.[0-9]+)?' | head -1)"
case "$gate_num" in
  G0)
    echo "  G0：写 CR 需求卡（00-requirements-intake.md），让用户选 做/拆小/spike/缓/不做。"
    echo "  无机器检查。"
    ;;
  G1)
    echo "  G1：确认 R/AC/T 与范围信封，写 STATUS「G1 已确认：是」。"
    echo "  必跑：check-docs --gate g1（0 ERROR 才可派 Dev）。"
    check_gate=g1
    ;;
  G2)
    echo "  G2：Dev 交付后，核对 DoD 与 AC 证据。"
    echo "  必跑：check-docs --gate g2；通过后派 Review。"
    check_gate=g2
    ;;
  G2.5)
    echo "  G2.5：Steward 合并上下文增量，WORKLOG 记 gate=G2.5 一行。"
    echo "  必跑：check-docs --gate g2.5；可与 G3 并行，但 commit 前必须完成。"
    check_gate=g2.5
    ;;
  G3)
    echo "  G3：Review 给结论；通过/有条件通过后记 A1c，主会话 commit，Steward/用户记 G3 接受。"
    echo "  必跑：check-docs --gate g3。"
    check_gate=g3
    ;;
  G3.5)
    echo "  G3.5：Steward 跨模块检查；不做则在 STATUS 写「G3.5 豁免：<理由>」。"
    echo "  必跑：check-docs --gate g3.5（或豁免）。"
    check_gate=g3.5
    ;;
  G4)
    echo "  G4：Steward/Meta 五层总审 + UAT；高风险必做，低风险可写「G4 豁免」。"
    echo "  必跑：check-docs --gate g4 --project-root $project_root。"
    check_gate=g4
    ;;
  *)
    echo "  无法从 STATUS 解析门禁；先补齐「当前门禁：Gx」字段。"
    ;;
esac
[ -n "$next" ] && echo "  STATUS 记录的下一步：$next"
echo

if [ "$do_check" -eq 1 ] && [ -n "${check_gate:-}" ]; then
  echo "== 门禁检查（$check_gate）=="
  "$check_docs" "$doc_root" --gate "$check_gate" --project-root "$project_root"
  echo "退出码：$?"
fi
