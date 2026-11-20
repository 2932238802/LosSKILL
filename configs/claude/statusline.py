#!/usr/bin/env python3
# Claude Code 状态栏：模型 · 目录 · git · 上下文 · 花费
import json, os, subprocess, sys, time

RESET = "\033[0m"
DIM = "\033[2m"

def fg(h):
    return "\033[38;2;%d;%d;%dm" % (int(h[1:3],16), int(h[3:5],16), int(h[5:7],16))

MAUVE, TEAL, PEACH = fg("#cba6f7"), fg("#94e2d5"), fg("#fab387")
GREEN, YELLOW, RED = fg("#a6e3a1"), fg("#f9e2af"), fg("#f38ba8")

def git_seg(cwd, sid):
    cache = "/tmp/claude-sl-%s" % sid
    try:
        if time.time() - os.path.getmtime(cache) < 5:
            with open(cache, encoding="utf-8") as f:
                return f.read().strip()
    except OSError:
        pass
    out = ""
    try:
        r = subprocess.run(["git","-C",cwd,"branch","--show-current"],
                           capture_output=True, text=True, timeout=2)
        branch = r.stdout.strip()
        if branch:
            d = subprocess.run(["git","-C",cwd,"status","--porcelain"],
                               capture_output=True, text=True, timeout=2)
            n = len([l for l in d.stdout.splitlines() if l.strip()])
            out = branch + (" \u00b1%d" % n if n else "")
    except Exception:
        out = ""
    try:
        with open(cache,"w",encoding="utf-8") as f:
            f.write(out)
    except OSError:
        pass
    return out

def main():
    try:
        data = json.load(sys.stdin)
    except Exception:
        print("")
        return
    model = str((data.get("model") or {}).get("display_name") or "?")[:18]
    ws = data.get("workspace") or {}
    cwd = ws.get("current_dir") or data.get("cwd") or os.getcwd()
    try:
        pct = int(float((data.get("context_window") or {}).get("used_percentage") or 0))
    except Exception:
        pct = 0
    try:
        cost = float((data.get("cost") or {}).get("total_cost_usd") or 0)
    except Exception:
        cost = 0.0
    sid = str(data.get("session_id") or os.getppid())
    seg = [MAUVE + model + RESET,
           TEAL + (os.path.basename(cwd.rstrip("/")) or cwd) + RESET]
    if os.path.isdir(cwd):
        g = git_seg(cwd, sid)
        if g:
            seg.append(PEACH + g + RESET)
    filled = max(0, min(10, pct // 10))
    color = RED if pct >= 85 else (YELLOW if pct >= 60 else GREEN)
    bar = "\u2588" * filled + "\u2591" * (10 - filled)
    seg.append(color + bar + RESET + DIM + " %d%%" % pct + RESET)
    if cost > 0:
        seg.append(DIM + "$%.2f" % cost + RESET)
    print(" ".join(seg))

if __name__ == "__main__":
    main()