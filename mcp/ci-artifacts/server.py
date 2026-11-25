#!/usr/bin/env python3
"""Minimal stdio MCP server for CI artifacts (no third-party dependencies).

Protocol: newline-delimited JSON-RPC 2.0 over stdin/stdout (MCP stdio transport).
Only stdout carries protocol messages; diagnostics go to stderr.
"""

from __future__ import annotations

import json
import sys
import traceback
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import core  # noqa: E402

SERVER_NAME = "ci-artifacts"
SUPPORTED_PROTOCOLS = {"2024-11-05", "2025-03-26", "2025-06-18"}
LATEST_PROTOCOL = "2025-06-18"

PROJECT_SCHEMA = {
    "type": "string",
    "description": "项目路径（默认当前工作目录）；会向上查找 git 根目录",
}
RUN_ID_SCHEMA = {
    "type": ["string", "integer"],
    "description": "CI 运行 id（GitHub run id / GitLab pipeline id）；省略则取最新一次",
}
REF_SCHEMA = {
    "type": "string",
    "description": "分支/ref，省略则用配置的 default_ref（默认 main）",
}

TOOLS = [
    {
        "name": "repo_info",
        "description": "识别项目属于哪个仓库平台（GitHub / GitLab），返回 host、owner、repo 与 web_url。",
        "inputSchema": {
            "type": "object",
            "properties": {
                "project_path": PROJECT_SCHEMA,
                "remote": {"type": "string", "description": "git remote 名，默认 origin"},
                "platform": {
                    "type": "string",
                    "enum": ["github", "gitlab"],
                    "description": "自建 GitLab 等域名无法判断时手动指定",
                },
            },
        },
    },
    {
        "name": "ci_workflow_summary",
        "description": "读取项目 CI 配置（.github/workflows/*.yml 或 .gitlab-ci.yml），列出任务与 artifacts 线索。",
        "inputSchema": {
            "type": "object",
            "properties": {"project_path": PROJECT_SCHEMA},
        },
    },
    {
        "name": "ci_list_runs",
        "description": "列出最近的 CI 运行（默认 10 条），用于选 run_id 或确认最新构建。",
        "inputSchema": {
            "type": "object",
            "properties": {
                "project_path": PROJECT_SCHEMA,
                "ref": REF_SCHEMA,
                "limit": {"type": "integer", "minimum": 1, "maximum": 100, "default": 10},
            },
        },
    },
    {
        "name": "ci_run_info",
        "description": "读取一次 CI 运行的结论、任务/步骤、失败任务日志摘要，并给出下一步建议。",
        "inputSchema": {
            "type": "object",
            "properties": {
                "project_path": PROJECT_SCHEMA,
                "run_id": RUN_ID_SCHEMA,
                "ref": REF_SCHEMA,
                "include_logs": {"type": "boolean", "default": True},
            },
        },
    },
    {
        "name": "ci_wait",
        "description": "非阻塞等待 CI 结束：立即返回 watcher_id，后台轮询；成功后自动下载 artifacts 并同步关键文件。",
        "inputSchema": {
            "type": "object",
            "properties": {
                "project_path": PROJECT_SCHEMA,
                "run_id": RUN_ID_SCHEMA,
                "ref": REF_SCHEMA,
                "interval": {"type": "integer", "minimum": 1, "description": "轮询秒数，默认 15"},
                "timeout": {"type": "integer", "minimum": 1, "description": "总超时秒数，默认 1800"},
                "auto_download": {"type": "boolean", "default": True},
                "sync": {"type": "boolean", "default": True},
            },
        },
    },
    {
        "name": "ci_wait_status",
        "description": "查询 ci_wait 启动的 watcher 状态；结束后包含下载/同步结果与下一步建议。",
        "inputSchema": {
            "type": "object",
            "properties": {
                "project_path": PROJECT_SCHEMA,
                "watcher_id": {"type": "string", "description": "ci_wait 返回的 watcher_id"},
                "status_file": {"type": "string", "description": "或直接给 ci_wait 返回的 status_file"},
            },
        },
    },
    {
        "name": "ci_download_artifacts",
        "description": "下载指定/最新运行的 artifacts，解压到 LosAngelousDocs/ci/<平台>/<owner>-<repo>/<run-id>/artifacts/（不污染其它目录）。",
        "inputSchema": {
            "type": "object",
            "properties": {
                "project_path": PROJECT_SCHEMA,
                "run_id": RUN_ID_SCHEMA,
                "ref": REF_SCHEMA,
                "dest": {"type": "string", "description": "自定义目标目录（默认落在项目 LosAngelousDocs/ci 下）"},
                "force": {"type": "boolean", "default": False},
            },
        },
    },
    {
        "name": "ci_sync_artifacts",
        "description": "把已下载 artifacts 中的关键文件（默认 *.md / *.json / *.html）同步到 LosAngelousDocs/reports/ci/<run-id>/，并写同步清单。",
        "inputSchema": {
            "type": "object",
            "properties": {
                "project_path": PROJECT_SCHEMA,
                "run_id": RUN_ID_SCHEMA,
                "ref": REF_SCHEMA,
                "include": {
                    "type": "array",
                    "items": {"type": "string"},
                    "description": "glob 列表，如 ['**/*.md']；省略则用配置 default_sync",
                },
                "to": {"type": "string", "description": "目标目录（相对项目根），支持 {run_id} 占位符"},
            },
        },
    },
]


def _call_tool(name: str, args: dict) -> dict:
    handlers = {
        "repo_info": lambda: core.detect_repo(
            args.get("project_path"), args.get("remote") or "origin", args.get("platform")
        ),
        "ci_workflow_summary": lambda: core.workflow_summary(args.get("project_path")),
        "ci_list_runs": _list_runs,
        "ci_run_info": lambda: core.run_info(
            args.get("project_path"),
            args.get("run_id"),
            args.get("ref"),
            include_logs=bool(args.get("include_logs", True)),
        ),
        "ci_wait": lambda: core.start_watcher(
            args.get("project_path"),
            args.get("run_id"),
            args.get("ref"),
            args.get("interval"),
            args.get("timeout"),
            auto_download=bool(args.get("auto_download", True)),
            do_sync=bool(args.get("sync", True)),
        ),
        "ci_wait_status": lambda: core.wait_status(
            args.get("project_path"),
            args.get("watcher_id"),
            args.get("status_file"),
        ),
        "ci_download_artifacts": lambda: core.download_artifacts(
            args.get("project_path"),
            args.get("run_id"),
            args.get("ref"),
            args.get("dest"),
            bool(args.get("force", False)),
        ),
        "ci_sync_artifacts": lambda: core.sync_artifacts(
            args.get("project_path"),
            args.get("run_id"),
            args.get("ref"),
            args.get("include"),
            args.get("to"),
        ),
    }
    handler = handlers.get(name)
    if handler is None:
        raise core.CiArtifactsError(f"unknown tool: {name}")
    return handler()


def _list_runs(args: dict) -> dict:
    project_root = core.resolve_project_root(args.get("project_path"))
    config = core.load_config(project_root)
    repo = core.detect_repo_for(project_root, config)
    adapter = core.make_adapter(repo, config)
    ref = args.get("ref") or config.get("default_ref")
    limit = int(args.get("limit") or 10)
    runs = adapter.list_runs(ref, limit)
    return {
        "ok": True,
        "repo": repo,
        "runs": [core.normalize_run(repo["platform"], run) for run in runs],
        "checked_at": core.utc_now(),
    }


def _result(payload) -> dict:
    return {
        "content": [
            {
                "type": "text",
                "text": json.dumps(payload, ensure_ascii=False, indent=2),
            }
        ],
        "isError": False,
    }


def _error(message: str) -> dict:
    return {
        "content": [{"type": "text", "text": message}],
        "isError": True,
    }


def _send(message: dict) -> None:
    sys.stdout.write(json.dumps(message, ensure_ascii=False, separators=(",", ":")) + "\n")
    sys.stdout.flush()


def _handle(msg: dict) -> None:
    msg_id = msg.get("id")
    method = msg.get("method")
    if msg_id is None:
        return  # notification, no response
    try:
        if method == "initialize":
            params = msg.get("params") or {}
            requested = params.get("protocolVersion")
            protocol = requested if requested in SUPPORTED_PROTOCOLS else LATEST_PROTOCOL
            _send(
                {
                    "jsonrpc": "2.0",
                    "id": msg_id,
                    "result": {
                        "protocolVersion": protocol,
                        "capabilities": {"tools": {"listChanged": False}},
                        "serverInfo": {"name": SERVER_NAME, "version": core.VERSION},
                        "instructions": (
                            "CI artifacts 工作流：repo_info 识别平台；ci_run_info 读结果与下一步；"
                            "ci_wait 非阻塞等待并在成功后自动下载+同步（落地 LosAngelousDocs/ci/<平台>/<owner>-<repo>/<run-id>/）。"
                        ),
                    },
                }
            )
        elif method == "ping":
            _send({"jsonrpc": "2.0", "id": msg_id, "result": {}})
        elif method == "tools/list":
            _send({"jsonrpc": "2.0", "id": msg_id, "result": {"tools": TOOLS}})
        elif method == "tools/call":
            params = msg.get("params") or {}
            name = params.get("name")
            arguments = params.get("arguments") or {}
            try:
                payload = _call_tool(name, arguments)
                _send({"jsonrpc": "2.0", "id": msg_id, "result": _result(payload)})
            except core.CiArtifactsError as exc:
                _send({"jsonrpc": "2.0", "id": msg_id, "result": _error(str(exc))})
        else:
            _send(
                {
                    "jsonrpc": "2.0",
                    "id": msg_id,
                    "error": {"code": -32601, "message": f"method not found: {method}"},
                }
            )
    except Exception as exc:  # never leak a traceback to the client
        print(traceback.format_exc(), file=sys.stderr)
        _send(
            {
                "jsonrpc": "2.0",
                "id": msg_id,
                "error": {"code": -32603, "message": str(exc)},
            }
        )


def main() -> int:
    if hasattr(sys.stdin, "reconfigure"):
        sys.stdin.reconfigure(encoding="utf-8")
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8", newline="\n")
    for line in sys.stdin:
        line = line.strip()
        if not line:
            continue
        try:
            msg = json.loads(line)
        except ValueError:
            continue
        if isinstance(msg, dict):
            _handle(msg)
    return 0


if __name__ == "__main__":
    sys.exit(main())
