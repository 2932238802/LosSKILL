#!/usr/bin/env python3
"""Detached CI watcher: poll a run, then download + sync without blocking the agent.

Started by core.start_watcher(); writes an atomic JSON status file on every tick.
"""

from __future__ import annotations

import argparse
import sys
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import core  # noqa: E402


def _write(status_path: Path, state: dict) -> None:
    state["updated_at"] = core.utc_now()
    core.write_json(status_path, state)


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(prog="ci-artifacts-watcher")
    parser.add_argument("--project", required=True)
    parser.add_argument("--run-id", required=True)
    parser.add_argument("--ref", default=None)
    parser.add_argument("--status-file", required=True)
    parser.add_argument("--interval", type=int, default=None)
    parser.add_argument("--timeout", type=int, default=None)
    parser.add_argument("--auto-download", action="store_true")
    parser.add_argument("--sync", action="store_true")
    args = parser.parse_args(argv)

    project = Path(args.project).resolve()
    status_path = Path(args.status_file).resolve()
    config = core.load_config(project)
    interval = max(1, int(args.interval or config["poll_interval"]))
    timeout = max(interval, int(args.timeout or config["wait_timeout"]))

    repo = core.detect_repo_for(project, config)
    state = {
        "watcher_id": status_path.stem.removeprefix("wait-"),
        "phase": "waiting",
        "project_root": str(project),
        "repo": repo,
        "run_id": args.run_id,
        "auto_download": args.auto_download,
        "sync": args.sync,
        "started_at": core.utc_now(),
        "updated_at": core.utc_now(),
        "polls": 0,
    }
    deadline = time.time() + timeout
    last_error = None

    while True:
        state["polls"] += 1
        try:
            info = core.run_info(
                project, args.run_id, args.ref, include_logs=False, config=config, repo=repo
            )
            if not info.get("ok"):
                raise core.CiArtifactsError(info.get("error") or "run not found")
            run = info["run"]
            state["run"] = run
            state["conclusion"] = info.get("conclusion")
            state["last_error"] = None

            if core.is_terminal(repo["platform"], run):
                if info.get("conclusion") == "success":
                    state["phase"] = "success"
                    if args.auto_download:
                        try:
                            state["download"] = core.download_artifacts(
                                project, args.run_id, args.ref, config=config, repo=repo
                            )
                            if args.sync:
                                try:
                                    state["sync"] = core.sync_artifacts(
                                        project, args.run_id, args.ref,
                                        config=config, repo=repo,
                                    )
                                except core.CiArtifactsError as exc:
                                    state["sync_error"] = str(exc)
                        except core.CiArtifactsError as exc:
                            state["download_error"] = str(exc)
                    state["next_steps"] = core.build_next_steps(
                        repo["platform"], run, [], info.get("artifact_count", 0)
                    )
                else:
                    state["phase"] = "failed"
                    state["failed_jobs"] = info.get("failed_jobs") or []
                    try:
                        detailed = core.run_info(
                            project, args.run_id, args.ref,
                            include_logs=True, config=config, repo=repo,
                        )
                        state["failed_jobs"] = detailed.get("failed_jobs") or state["failed_jobs"]
                        state["log_excerpt"] = detailed.get("log_excerpt")
                    except core.CiArtifactsError as exc:
                        state["log_error"] = str(exc)
                    state["next_steps"] = core.build_next_steps(
                        repo["platform"], run, state.get("failed_jobs") or [], 0
                    )
                _write(status_path, state)
                return 0

            state["phase"] = "waiting"
            state["next_steps"] = [
                "CI 仍在运行；无需阻塞，继续其它任务",
                "稍后用 ci_wait_status 查询本 watcher 的状态",
            ]
        except core.CiArtifactsError as exc:
            last_error = str(exc)
            state["last_error"] = last_error
            state["phase"] = "waiting"

        if time.time() >= deadline:
            state["phase"] = "timeout"
            state["next_steps"] = [
                f"等待超时（{timeout}s）：CI 仍未结束",
                "可再次调用 ci_wait 继续等待，或用 ci_run_info 查看当前状态",
            ]
            _write(status_path, state)
            return 0

        _write(status_path, state)
        time.sleep(interval)


if __name__ == "__main__":
    sys.exit(main())
