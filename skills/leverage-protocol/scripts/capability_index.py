#!/usr/bin/env python3
"""Capability awareness helper (stdlib only).

Subcommands:
  build    Scan SKILL.md files under roots, write index.json + INDEX.md
  query    Match a task description against installed skills
  plan     Combine installed skills + latent capability domains + quality floor
  brief    Compact session-start summary (for hooks / quick context)
  audit    Find missing metadata, duplicate names, near-duplicate descriptions
  profile  Detect project stack and write .claude/capability-profile.json

No network. No third-party packages.
"""
from __future__ import annotations

import argparse
import json
import math
import os
import re
import sys
import time
from pathlib import Path

CACHE_DEFAULT = Path(os.environ.get("CAPABILITY_INDEX_OUT", "~/.cache/capability-index/index.json")).expanduser()
SKIP_DIRS = {"node_modules", "target", "dist", "build", ".git", ".hg", ".svn", "__pycache__", ".venv", "venv"}

STOP = set("""
a an the and or of to for in on at by with from as is are be been being this that these those it its
you your we our they their he she his her i me my not no do does did can could should would may might will
how what why when where which who whom whose please help need want make use using work works
用 于 的 了 和 与 或 在 是 有 不 我 你 他 她 它 们 这 那 等 及 一个 一些 可以 需要 使用 用于 进行 通过 以及 如果 就 也 都 而 但 并 对 从 到 为 让 把 被 给 着 过 很 更 最
帮我 看看 有没 没有 怎么 什么 这个 那个 一下 时候 现在 然后 因为 所以 但是 还是 已经 自己 我们 你们 他们
东西 问题 需要 可以 使用 进行 通过 以及 一个 一些 一种 只是 甚至 直接 自动 完整 具体 相关 内容 情况
方式 方法 目前 应该 可能 主要 部分 包括 提供 支持 这里 那里 是否 能否 如何 为什么 多少 哪些 哪个
实现 避免 竞争 系统 设计 方案 进行 处理 管理 相关 对应 具体 一般 通常
全部 所有 一切 考虑 需要 希望 想要 觉得 认为 看看
""".split())

FUNC = set("的了着过得地是在和与或有我你他她它们这那个些就也都而但并对从到为让把被给很更最不会能要可以及等")



def eprint(*a):
    print(*a, file=sys.stderr)


def default_roots() -> list[Path]:
    roots: list[Path] = []
    env = os.environ.get("CAPABILITY_INDEX_ROOTS")
    if env:
        roots += [Path(p).expanduser() for p in env.split(os.pathsep) if p.strip()]
    roots += [
        Path.home() / ".claude" / "skills",
        Path.cwd() / ".claude" / "skills",
        Path.cwd() / "skills",
    ]
    out, seen = [], set()
    for r in roots:
        try:
            rr = r.resolve()
        except OSError:
            continue
        if rr.is_dir() and str(rr) not in seen:
            seen.add(str(rr))
            out.append(rr)
    return out


def discover_skill_files(roots: list[Path]) -> list[Path]:
    found: list[Path] = []
    seen = set()
    for root in roots:
        for dirpath, dirnames, filenames in os.walk(root):
            dirnames[:] = [d for d in dirnames if d not in SKIP_DIRS and not d.startswith(".")]
            if "SKILL.md" in filenames:
                p = Path(dirpath) / "SKILL.md"
                rp = str(p.resolve())
                if rp not in seen:
                    seen.add(rp)
                    found.append(p)
    return found


def parse_frontmatter(path: Path) -> dict:
    text = path.read_text(encoding="utf-8", errors="replace")
    meta: dict[str, str] = {}
    body = text
    if text.startswith("---"):
        end = text.find("\n---", 3)
        if end != -1:
            fm = text[3:end]
            body = text[end + 4:]
            lines = fm.splitlines()
            key = None
            buf: list[str] = []
            for line in lines:
                m = re.match(r"^([A-Za-z0-9_.-]+):\s*(.*)$", line)
                if m and not line.startswith((" ", "\t")):
                    if key:
                        meta[key] = clean_scalar("\n".join(buf))
                    key = m.group(1)
                    val = m.group(2).strip()
                    buf = [] if val in ("|", ">", "|-", ">-", "") else [val]
                elif key is not None:
                    buf.append(line.strip())
            if key:
                meta[key] = clean_scalar("\n".join(buf))
    return {"meta": meta, "body": body.strip()}


def clean_scalar(s: str) -> str:
    s = " ".join(x.strip() for x in s.splitlines() if x.strip())
    if len(s) >= 2 and s[0] == s[-1] and s[0] in "\"'":
        s = s[1:-1]
    return s.strip()


NEG_CLAUSE_RE = re.compile(r"(?:不适用于|不用于|不涉及|not\s+for)[^。；;\n]*", re.IGNORECASE)


def strip_negated(text: str) -> str:
    """Drop explicit negative-boundary clauses from index-side text only.

    Removes each marker and everything up to the next terminator (。；; or
    newline). The original description is kept for output/INDEX; this only
    shapes what reaches tokenize().
    """
    return NEG_CLAUSE_RE.sub("", text)


def tokenize(text: str) -> set[str]:
    text = text.lower()
    out: set[str] = set(re.findall(r"[a-z0-9][a-z0-9_+#.\-]*", text))
    for run in re.findall(r"[一-鿿]+", text):
        if len(run) <= 2:
            out.add(run)
        else:
            for i in range(len(run) - 1):
                bg = run[i:i + 2]
                if bg[0] in FUNC or bg[1] in FUNC:
                    continue
                out.add(bg)
            if len(run) <= 8:
                out.add(run)
    res: set[str] = set()
    for t in out:
        if t in STOP:
            continue
        if re.match(r"^[a-z0-9][a-z0-9_+#.\-]*$", t):
            res.add(t)
        elif len(t) >= 2:
            res.add(t)
    return res


def load_domains() -> list[dict]:
    p = Path(__file__).resolve().parent.parent / "references" / "domains.json"
    if not p.exists():
        return []
    return json.loads(p.read_text(encoding="utf-8")).get("domains", [])


def extra_text(skill_dir: Path) -> str:
    """Index internal capability cards so detailed queries can match the entry skill."""
    ref = skill_dir / "references"
    if not ref.is_dir():
        return ""
    chunks: list[str] = []
    for p in ref.rglob("*.md"):
        rel = p.relative_to(ref)
        stem = p.stem.replace("-", " ")
        if "capabilities" in rel.parts or p.name in ("cheatsheet.md", "capability-index.md"):
            try:
                text = p.read_text(encoding="utf-8", errors="replace")
            except OSError:
                continue
            heads = re.findall(r"^#\s+(.+)$", text, re.M)[:8]
            body = re.sub(r"\s+", " ", re.sub(r"^#.*$", "", text, flags=re.M))[:400]
            chunks.append(" ".join(heads) + " " + body)
        else:
            chunks.append(stem)
    return " ".join(chunks)[:5000]


def build_index(roots: list[Path]) -> dict:
    skills = []
    for path in discover_skill_files(roots):
        fm = parse_frontmatter(path)
        meta = fm["meta"]
        name = meta.get("name") or path.parent.name
        desc = meta.get("description") or first_para(fm["body"])
        skill_dir = path.parent
        is_router = (skill_dir / "references" / "capabilities").is_dir()
        all_text = name + " " + strip_negated(desc) + " " + extra_text(skill_dir)
        skills.append({
            "name": name,
            "description": desc,
            "path": str(path),
            "dir": str(skill_dir),
            "kind": "router+cards" if is_router else "skill",
            "has_description": bool(desc),
            "updated": int(path.stat().st_mtime),
            "tokens": sorted(tokenize(all_text)),
        })
    skills.sort(key=lambda x: x["name"].lower())
    return {
        "generated_at": int(time.time()),
        "roots": [str(r) for r in roots],
        "count": len(skills),
        "skills": skills,
    }


def first_para(body: str) -> str:
    for para in re.split(r"\n\s*\n", body):
        p = " ".join(x.strip() for x in para.splitlines() if x.strip())
        if p and not p.startswith("#"):
            return p[:500]
    return ""


def write_index(index: dict, out: Path) -> None:
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(index, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    lines = ["# Capability Index", "", f"生成时间：{time.strftime('%Y-%m-%d %H:%M:%S', time.localtime(index['generated_at']))}", f"根目录：{', '.join(index['roots'])}", f"技能数：{index['count']}", ""]
    lines += ["| Skill | 类型 | 描述 | 路径 |", "|---|---|---|---|"]
    for s in index["skills"]:
        desc = s["description"].replace("|", "\\|")[:160]
        lines.append(f"| `{s['name']}` | {s['kind']} | {desc} | `{s['dir']}` |")
    (out.parent / "INDEX.md").write_text("\n".join(lines) + "\n", encoding="utf-8")


def stale(index: dict, roots: list[Path]) -> bool:
    if not index.get("skills"):
        return True
    newest = max((p.stat().st_mtime for p in discover_skill_files(roots)), default=0)
    return newest > index.get("generated_at", 0)


def load_or_build(roots: list[Path], out: Path, refresh: bool = False) -> dict:
    if not refresh and out.exists():
        try:
            idx = json.loads(out.read_text(encoding="utf-8"))
            if not stale(idx, roots):
                return idx
        except (json.JSONDecodeError, OSError):
            pass
    idx = build_index(roots)
    write_index(idx, out)
    return idx


def idf_table(skills: list[dict]) -> dict[str, float]:
    df: dict[str, int] = {}
    for s in skills:
        for t in set(s.get("tokens", [])):
            df[t] = df.get(t, 0) + 1
    n = max(1, len(skills))
    return {t: math.log((n + 1) / (c + 1)) + 1.0 for t, c in df.items()}


def term_weight(t: str, idf: dict[str, float]) -> float:
    base = idf.get(t, 1.0)
    if re.match(r"^[a-z0-9][a-z0-9_+#.\-]*$", t) and len(t) >= 3:
        return base * 1.5
    if len(t) >= 3:
        return base * 1.4
    return base


def score(query: str, item_tokens: set[str], idf: dict[str, float] | None = None) -> tuple[float, set[str]]:
    q = tokenize(query)
    if not q:
        return 0.0, set()
    idf = idf or {}
    known = {t: idf[t] for t in q if t in idf}
    if not known:
        return 0.0, set()
    inter = q & item_tokens & set(known)
    wq = sum(term_weight(t, idf) for t in known)
    wi = sum(term_weight(t, idf) for t in inter)
    union = set(known) | (item_tokens & set(idf))
    wu = sum(term_weight(t, idf) for t in union)
    coverage = wi / wq if wq else 0.0
    jaccard = wi / wu if wu else 0.0
    return 0.7 * coverage + 0.2 * jaccard + 0.1 * min(1.0, wi / 8.0), inter


def cmd_build(args) -> int:
    roots = [Path(r).expanduser() for r in args.roots] if args.roots else default_roots()
    idx = load_or_build(roots, Path(args.out).expanduser(), refresh=True)
    print(f"indexed {idx['count']} skills -> {Path(args.out).expanduser()}")
    print(f"human index -> {Path(args.out).expanduser().parent / 'INDEX.md'}")
    return 0


def cmd_query(args) -> int:
    roots = [Path(r).expanduser() for r in args.roots] if args.roots else default_roots()
    out = Path(args.out).expanduser()
    idx = load_or_build(roots, out, refresh=args.refresh)
    idf = idf_table(idx["skills"])
    rows = []
    for s in idx["skills"]:
        sc, inter = score(args.text, set(s["tokens"]), idf)
        if sc > 0:
            rows.append((sc, s, sorted(inter)[:8]))
    rows.sort(key=lambda x: -x[0])
    top = rows[: args.limit]
    q_len = len(tokenize(args.text))
    confident = False
    if top:
        sc, s, inter = top[0]
        strong = any(
            idf.get(t, 0) >= 3.5 and (len(t) >= 4 or (len(t) >= 3 and not re.match(r"^[a-z0-9]", t)))
            for t in inter
        )
        confident = sc >= args.min_score and (len(inter) >= 2 or strong or (q_len <= 3 and len(inter) >= 1))
    if args.json:
        print(json.dumps({
            "query": args.text,
            "confident": confident,
            "matches": [{"name": s["name"], "score": round(sc, 3), "path": s["path"], "matched": inter} for sc, s, inter in top],
        }, ensure_ascii=False, indent=2))
        return 0 if confident or args.allow_empty else 1
    if not confident:
        if not top:
            print("没有匹配的已装 Skill。不要硬套；先说明将直接处理。")
        elif top[0][0] >= args.min_score:
            print("分数过线但证据不足（只命中一个泛词，或缺少第二个区分性词）。不要仅凭它硬套；先说明将直接处理。")
        else:
            print(f"没有足够匹配的已装 Skill（最高分 {top[0][0]:.2f} < {args.min_score}）。不要硬套；先说明将直接处理。")
        if top:
            print("最接近的候选（仅供参考）：")
    for sc, s, inter in top:
        print(f"- [{sc:.2f}] {s['name']}  ({s['kind']})  {s['dir']}")
        if inter:
            print(f"    命中：{', '.join(inter)}")
    return 0 if confident or args.allow_empty else 1


def cmd_plan(args) -> int:
    roots = [Path(r).expanduser() for r in args.roots] if args.roots else default_roots()
    out = Path(args.out).expanduser()
    idx = load_or_build(roots, out, refresh=args.refresh)
    idf = idf_table(idx["skills"])
    skill_rows = []
    q_tokens = tokenize(args.task)
    for s in idx["skills"]:
        sc, inter = score(args.task, set(s["tokens"]), idf)
        if s["name"] == "leverage-protocol" and not re.search(r"满力|leverage|协议", args.task, re.I):
            sc *= 0.45
        if sc >= 0.12:
            skill_rows.append((sc, s, sorted(inter)[:6]))
    skill_rows.sort(key=lambda x: -x[0])
    dom_rows = []
    task_l = args.task.lower()
    for d in load_domains():
        signals = d.get("signals", [])
        hit = [sig for sig in signals if len(sig) >= 2 and sig.lower() in task_l]
        sig_score = min(1.0, sum(max(1.0, len(x) / 4) for x in hit) / 3.0)
        sc, inter = score(args.task, tokenize(d["name"] + " " + " ".join(signals)))
        sc = 0.6 * sig_score + 0.4 * sc
        if sc >= 0.10:
            dom_rows.append((sc, d, hit[:6] or sorted(inter)[:6]))
    dom_rows.sort(key=lambda x: -x[0])

    print("# 能力激活计划")
    print(f"\n任务：{args.task.strip()[:300]}")
    print("\n## 1. 已装 Skill（最多 3 个）")
    if skill_rows:
        for sc, s, inter in skill_rows[:3]:
            print(f"- [{sc:.2f}] `{s['name']}` — {s['description'][:120]}")
            print(f"  路径：`{s['path']}`；命中：{', '.join(inter) or '—'}")
    else:
        print("- 无匹配。直接处理，并明确说明没有套用现成技能。")

    print("\n## 2. 潜在能力（AI 已知但用户没提，先自查再决定是否提出）")
    if dom_rows:
        for sc, d, inter in dom_rows[:3]:
            print(f"- [{sc:.2f}] **{d['name']}**：{d['prompt']}")
            for c in d.get("checks", [])[:4]:
                print(f"  - 检查：{c}")
    else:
        print("- 未识别到特定能力域。仍执行通用质量底线。")

    print("\n## 3. 质量底线（交付前逐项确认）")
    print("- [ ] 已阅读相关代码/文档与约束，而不是凭印象作答")
    print("- [ ] 已写出关键假设、取舍与未做的部分")
    print("- [ ] 已运行可用的验证（编译/测试/复现/样例）")
    print("- [ ] 没有为了省 token 跳过边界条件、错误路径或验证")
    print("\n规则：最多主动提出 3 项；每项一行；若会改变范围或成本，先问一句再动。")
    return 0


def cmd_brief(args) -> int:
    roots = [Path(r).expanduser() for r in args.roots] if args.roots else default_roots()
    out = Path(args.out).expanduser()
    idx = load_or_build(roots, out, refresh=False)
    prof = detect_profile(Path(args.cwd or os.getcwd()))
    print("# Capability Brief")
    print(f"- 已装 Skill：{idx['count']} 个（{len(idx['roots'])} 个根目录）")
    if prof["stack"]:
        print(f"- 本项目栈：{', '.join(prof['stack'])}" + (f"；检测到：{', '.join(prof['signals'][:6])}" if prof["signals"] else ""))
    print("- 提醒：先跑 `capability_index.py query/plan` 查已有能力；不要凭记忆声称某技能存在。")
    print("- 交付前跑质量底线：读代码 → 写假设 → 验证 → 不省边界。")
    if args.domains:
        doms = load_domains()[:5]
        print("- 潜在能力域示例：" + "、".join(d["name"] for d in doms))
    return 0


def detect_profile(cwd: Path) -> dict:
    stack, signals = [], []
    checks = {
        "Cargo.toml": "Rust", "package.json": "Node/TS", "pyproject.toml": "Python",
        "requirements.txt": "Python", "go.mod": "Go", "pom.xml": "Java",
        "build.gradle": "Java/Kotlin", "CMakeLists.txt": "C/C++", "Gemfile": "Ruby",
    }
    for manifest, name in checks.items():
        if (cwd / manifest).exists():
            stack.append(name)
            signals.append(manifest)
            continue
        for sub in cwd.iterdir() if cwd.is_dir() else []:
            if sub.is_dir() and sub.name not in SKIP_DIRS and not sub.name.startswith(".") and (sub / manifest).exists():
                stack.append(f"{name} ({sub.name})")
                signals.append(f"{sub.name}/{manifest}")
                break
    exts = {".rs": "Rust source", ".ts": "TypeScript", ".tsx": "React", ".py": "Python source", ".go": "Go source", ".sql": "SQL"}
    seen = set()
    for dirpath, dirnames, filenames in os.walk(cwd):
        rel = Path(dirpath).relative_to(cwd)
        if len(rel.parts) >= 3:
            dirnames[:] = []
        dirnames[:] = [d for d in dirnames if d not in SKIP_DIRS and not d.startswith(".")]
        for f in filenames:
            ext = Path(f).suffix
            if ext in exts and exts[ext] not in seen:
                seen.add(exts[ext])
                signals.append(exts[ext])
    for d in ["tests", "test", "__tests__", "spec"]:
        if (cwd / d).is_dir():
            signals.append(f"{d}/")
    for d in [".github/workflows", ".gitlab-ci.yml", "Dockerfile", "docker-compose.yml", "deploy/docker-compose.yml"]:
        if (cwd / d).exists():
            signals.append(d)
    return {"cwd": str(cwd), "stack": sorted(set(stack)), "signals": sorted(set(signals))}


def cmd_profile(args) -> int:
    cwd = Path(args.cwd or os.getcwd())
    prof = detect_profile(cwd)
    target = cwd / ".claude" / "capability-profile.json"
    if not args.dry_run:
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(json.dumps(prof, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        print(f"profile -> {target}")
    print(json.dumps(prof, ensure_ascii=False, indent=2))
    return 0


def cmd_audit(args) -> int:
    roots = [Path(r).expanduser() for r in args.roots] if args.roots else default_roots()
    out = Path(args.out).expanduser()
    idx = load_or_build(roots, out, refresh=True)
    skills = idx["skills"]
    problems = []
    names = {}
    for s in skills:
        if not s["has_description"]:
            problems.append(f"缺少 description：`{s['path']}`")
        names.setdefault(s["name"], []).append(s)
    for name, items in names.items():
        if len(items) > 1:
            problems.append("重名 `%s`：%s" % (name, ", ".join(i["path"] for i in items)))
    pairs = []
    for i, a in enumerate(skills):
        ta = set(a["tokens"])
        for b in skills[i + 1:]:
            tb = set(b["tokens"])
            if not ta or not tb:
                continue
            jac = len(ta & tb) / len(ta | tb)
            if jac >= args.threshold and a["name"] != b["name"]:
                pairs.append((jac, a["name"], b["name"]))
    pairs.sort(reverse=True)
    print(f"# 技能库体检\n\n- 技能数：{len(skills)}\n- 根目录：{', '.join(idx['roots'])}\n")
    if problems:
        print("## 元数据问题")
        for p in problems:
            print(f"- {p}")
    else:
        print("## 元数据问题\n- 无")
    print("\n## 描述高度相似（可能抢触发，建议人工合并或加负例）")
    if pairs:
        for jac, a, b in pairs[:15]:
            print(f"- {jac:.2f}  `{a}` ↔ `{b}`")
    else:
        print("- 无")
    print("\n## 覆盖概览")
    for root in idx["roots"]:
        n = sum(1 for s in skills if s["dir"].startswith(root))
        print(f"- {root}: {n}")
    return 0


def main() -> int:
    ap = argparse.ArgumentParser(description="Capability awareness helper")
    sub = ap.add_subparsers(dest="cmd", required=True)

    def common(p):
        p.add_argument("--roots", action="append", help="skill root (repeatable)")
        p.add_argument("--out", default=str(CACHE_DEFAULT), help="index.json path")

    b = sub.add_parser("build"); common(b); b.set_defaults(func=cmd_build)
    q = sub.add_parser("query"); common(q); q.add_argument("text"); q.add_argument("--limit", type=int, default=5); q.add_argument("--min-score", type=float, default=0.22); q.add_argument("--json", action="store_true"); q.add_argument("--refresh", action="store_true"); q.add_argument("--allow-empty", action="store_true"); q.set_defaults(func=cmd_query)
    p = sub.add_parser("plan"); common(p); p.add_argument("task"); p.add_argument("--refresh", action="store_true"); p.set_defaults(func=cmd_plan)
    br = sub.add_parser("brief"); common(br); br.add_argument("--cwd"); br.add_argument("--domains", action="store_true"); br.set_defaults(func=cmd_brief)
    pr = sub.add_parser("profile"); pr.add_argument("--cwd"); pr.add_argument("--dry-run", action="store_true"); pr.set_defaults(func=cmd_profile)
    a = sub.add_parser("audit"); common(a); a.add_argument("--threshold", type=float, default=0.55); a.set_defaults(func=cmd_audit)

    args = ap.parse_args()
    return args.func(args)


if __name__ == "__main__":
    sys.exit(main())
