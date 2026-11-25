from __future__ import annotations

import json
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

import watcher  # noqa: E402

REPO_ROOT = ROOT.parents[1]


class WatcherTests(unittest.TestCase):
    def _run(self, payloads, extra_args=()):
        with tempfile.TemporaryDirectory() as tmp:
            status = Path(tmp) / "wait-test.json"
            args = [
                "--project", str(REPO_ROOT),
                "--run-id", "123",
                "--status-file", str(status),
                "--interval", "1",
                "--timeout", "5",
                *extra_args,
            ]
            with mock.patch.object(watcher.core, "run_info", side_effect=payloads), \
                 mock.patch.object(watcher.core, "download_artifacts", return_value={"ok": True}), \
                 mock.patch.object(watcher.core, "sync_artifacts", return_value={"ok": True}), \
                 mock.patch.object(watcher.time, "sleep", return_value=None):
                rc = watcher.main(args)
            return rc, json.loads(status.read_text(encoding="utf-8"))

    def test_success_downloads_and_syncs(self):
        run = {"id": "123", "status": "completed", "conclusion": "success"}
        info = {
            "ok": True,
            "run": run,
            "conclusion": "success",
            "artifact_count": 1,
            "failed_jobs": [],
        }
        rc, state = self._run([info], ["--auto-download", "--sync"])
        self.assertEqual(rc, 0)
        self.assertEqual(state["phase"], "success")
        self.assertIn("download", state)
        self.assertIn("sync", state)
        self.assertTrue(state["next_steps"])

    def test_failure_reads_logs_and_stops(self):
        run = {"id": "123", "status": "completed", "conclusion": "failure"}
        waiting = {"ok": True, "run": run, "conclusion": "failure",
                   "artifact_count": 0, "failed_jobs": []}
        detailed = dict(waiting, log_excerpt="boom: test failed",
                        failed_jobs=[{"id": "7", "name": "build"}])
        rc, state = self._run([waiting, detailed])
        self.assertEqual(rc, 0)
        self.assertEqual(state["phase"], "failed")
        self.assertEqual(state["log_excerpt"], "boom: test failed")
        self.assertTrue(any("不要基于失败产物" in step for step in state["next_steps"]))

    def test_timeout_does_not_block_forever(self):
        run = {"id": "123", "status": "in_progress", "conclusion": None}
        info = {"ok": True, "run": run, "conclusion": "in_progress",
                "artifact_count": 0, "failed_jobs": []}
        with mock.patch.object(watcher.core, "run_info", return_value=info), \
             mock.patch.object(watcher.time, "sleep", return_value=None):
            with tempfile.TemporaryDirectory() as tmp:
                status = Path(tmp) / "wait-timeout.json"
                rc = watcher.main([
                    "--project", str(REPO_ROOT),
                    "--run-id", "123",
                    "--status-file", str(status),
                    "--interval", "1",
                    "--timeout", "1",
                ])
                state = json.loads(status.read_text(encoding="utf-8"))
        self.assertEqual(rc, 0)
        self.assertEqual(state["phase"], "timeout")
        self.assertGreaterEqual(state["polls"], 1)


if __name__ == "__main__":
    unittest.main()
