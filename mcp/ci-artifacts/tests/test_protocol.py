from __future__ import annotations

import json
import queue
import subprocess
import sys
import threading
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SERVER = ROOT / "server.py"
REPO_ROOT = ROOT.parents[1]


class McpProtocolTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.proc = subprocess.Popen(
            [sys.executable, "-E", "-s", str(SERVER)],
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            encoding="utf-8",
            cwd=str(REPO_ROOT),
        )
        cls.queue: queue.Queue[str] = queue.Queue()
        cls.stderr_lines: list[str] = []

        def _read_stdout():
            for line in cls.proc.stdout:
                cls.queue.put(line)

        def _read_stderr():
            for line in cls.proc.stderr:
                cls.stderr_lines.append(line)

        threading.Thread(target=_read_stdout, daemon=True).start()
        threading.Thread(target=_read_stderr, daemon=True).start()

    @classmethod
    def tearDownClass(cls):
        try:
            cls.proc.stdin.close()
        except Exception:
            pass
        cls.proc.terminate()
        try:
            cls.proc.wait(timeout=5)
        except subprocess.TimeoutExpired:
            cls.proc.kill()

    def rpc(self, message: dict, timeout: float = 10.0) -> dict:
        self.proc.stdin.write(json.dumps(message) + "\n")
        self.proc.stdin.flush()
        try:
            line = self.queue.get(timeout=timeout)
        except queue.Empty:
            raise AssertionError(
                f"MCP server produced no response; stderr:\n{''.join(self.stderr_lines)}"
            )
        return json.loads(line)

    def test_1_initialize(self):
        response = self.rpc(
            {
                "jsonrpc": "2.0",
                "id": 1,
                "method": "initialize",
                "params": {
                    "protocolVersion": "2024-11-05",
                    "capabilities": {},
                    "clientInfo": {"name": "test", "version": "1"},
                },
            }
        )
        result = response["result"]
        self.assertEqual(result["protocolVersion"], "2024-11-05")
        self.assertEqual(result["serverInfo"]["name"], "ci-artifacts")
        self.assertIn("tools", result["capabilities"])

    def test_2_tools_list(self):
        response = self.rpc({"jsonrpc": "2.0", "id": 2, "method": "tools/list"})
        names = {tool["name"] for tool in response["result"]["tools"]}
        expected = {
            "repo_info",
            "ci_workflow_summary",
            "ci_list_runs",
            "ci_run_info",
            "ci_wait",
            "ci_wait_status",
            "ci_download_artifacts",
            "ci_sync_artifacts",
        }
        self.assertEqual(names, expected)

    def test_3_repo_info_tool(self):
        response = self.rpc(
            {
                "jsonrpc": "2.0",
                "id": 3,
                "method": "tools/call",
                "params": {"name": "repo_info", "arguments": {"project_path": str(REPO_ROOT)}},
            }
        )
        result = response["result"]
        self.assertFalse(result["isError"])
        payload = json.loads(result["content"][0]["text"])
        self.assertEqual(payload["platform"], "github")
        self.assertEqual(payload["repo"], "LosSKILL")

    def test_4_tool_error_is_reported(self):
        response = self.rpc(
            {
                "jsonrpc": "2.0",
                "id": 4,
                "method": "tools/call",
                "params": {
                    "name": "ci_wait_status",
                    "arguments": {"project_path": str(REPO_ROOT), "watcher_id": "../../evil"},
                },
            }
        )
        result = response["result"]
        self.assertTrue(result["isError"])
        self.assertIn("invalid watcher id", result["content"][0]["text"])

    def test_5_unknown_method(self):
        response = self.rpc({"jsonrpc": "2.0", "id": 5, "method": "no/such"})
        self.assertEqual(response["error"]["code"], -32601)


if __name__ == "__main__":
    unittest.main()
