from __future__ import annotations

import json
import os
import stat
import sys
import tempfile
import unittest
import zipfile
from pathlib import Path
from unittest import mock

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

import core  # noqa: E402

REPO_ROOT = ROOT.parents[1]


class RemoteParseTests(unittest.TestCase):
    def test_github_scp_style(self):
        info = core.parse_remote_url("git@github.com:2932238802/LosSKILL.git")
        self.assertEqual(info["platform"], "github")
        self.assertEqual(info["owner"], "2932238802")
        self.assertEqual(info["repo"], "LosSKILL")
        self.assertEqual(info["host"], "github.com")

    def test_github_https(self):
        info = core.parse_remote_url("https://github.com/owner/repo.git")
        self.assertEqual((info["platform"], info["owner"], info["repo"]), ("github", "owner", "repo"))

    def test_gitlab_nested_group_with_port(self):
        info = core.parse_remote_url("ssh://git@gitlab.example.com:2222/group/sub/repo.git")
        self.assertEqual(info["platform"], "gitlab")
        self.assertEqual(info["owner"], "group/sub")
        self.assertEqual(info["repo"], "repo")
        self.assertEqual(info["host"], "gitlab.example.com")

    def test_gitee_https(self):
        info = core.parse_remote_url("https://gitee.com/owner/repo")
        self.assertEqual(info["platform"], "gitee")

    def test_unknown_host_parses(self):
        info = core.parse_remote_url("git@bitbucket.org:owner/repo.git")
        self.assertEqual(info["platform"], "unknown")
        self.assertEqual((info["owner"], info["repo"]), ("owner", "repo"))

    def test_invalid_remote_raises(self):
        with self.assertRaises(core.CiArtifactsError):
            core.parse_remote_url("not-a-remote")


class PathTests(unittest.TestCase):
    def test_default_run_dir_layout(self):
        repo = {"platform": "gitlab", "owner": "group/sub", "repo": "my repo"}
        with tempfile.TemporaryDirectory() as tmp:
            run_dir = core.default_run_dir(tmp, repo, 12345, core.DEFAULTS)
            rel = run_dir.relative_to(Path(tmp).resolve()).as_posix()
            self.assertEqual(rel, "LosAngelousDocs/ci/gitlab/group-sub-my-repo/12345")

    def test_invalid_run_id_rejected(self):
        with self.assertRaises(core.CiArtifactsError):
            core.safe_run_id("../../etc")

    def test_glob_match(self):
        self.assertTrue(core.glob_match("pack/report.md", "**/*.md"))
        self.assertTrue(core.glob_match("report.md", "**/*.md"))
        self.assertFalse(core.glob_match("pack/report.txt", "**/*.md"))

    def test_docs_root_cannot_escape_project(self):
        cfg = dict(core.DEFAULTS, docs_root="../outside")
        repo = {"platform": "github", "owner": "o", "repo": "r"}
        with tempfile.TemporaryDirectory() as tmp:
            with self.assertRaises(core.CiArtifactsError):
                core.default_run_dir(tmp, repo, "1", cfg)


class SafeExtractTests(unittest.TestCase):
    def _zip(self, tmp, entries):
        path = Path(tmp) / "a.zip"
        with zipfile.ZipFile(path, "w") as archive:
            for name, data in entries:
                info = zipfile.ZipInfo(name)
                archive.writestr(info, data)
        return path

    def test_extracts_nested_file(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = self._zip(tmp, [("sub/report.md", "hello")])
            dest = Path(tmp) / "out"
            count = core.safe_extract(path, dest)
            self.assertEqual(count, 1)
            self.assertEqual((dest / "sub" / "report.md").read_text(encoding="utf-8"), "hello")

    def test_rejects_parent_traversal(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = self._zip(tmp, [("../evil.txt", "x")])
            with self.assertRaises(core.CiArtifactsError):
                core.safe_extract(path, Path(tmp) / "out")

    def test_rejects_absolute_path(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = self._zip(tmp, [("/abs/evil.txt", "x")])
            with self.assertRaises(core.CiArtifactsError):
                core.safe_extract(path, Path(tmp) / "out")

    def test_skips_symlink_entries(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "sym.zip"
            with zipfile.ZipFile(path, "w") as archive:
                info = zipfile.ZipInfo("link")
                info.external_attr = (stat.S_IFLNK | 0o777) << 16
                archive.writestr(info, "target")
            count = core.safe_extract(path, Path(tmp) / "out")
            self.assertEqual(count, 0)

    def test_zip_bomb_limit(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "bomb.zip"
            with zipfile.ZipFile(path, "w") as archive:
                archive.writestr("big.bin", b"0" * 4096)
            with self.assertRaises(core.CiArtifactsError):
                core.safe_extract(path, Path(tmp) / "out", max_bytes=1024)


class SyncTests(unittest.TestCase):
    def _repo(self):
        return {"platform": "github", "owner": "o", "repo": "r", "host": "github.com"}

    def _seed(self, project: Path, rid: str = "42") -> Path:
        run_dir = core.default_run_dir(project, self._repo(), rid, core.DEFAULTS)
        artifacts = run_dir / "artifacts" / "pack"
        artifacts.mkdir(parents=True)
        (artifacts / "report.md").write_text("# report", encoding="utf-8")
        (artifacts / "data.json").write_text("{}", encoding="utf-8")
        (artifacts / "skip.txt").write_text("no", encoding="utf-8")
        return run_dir

    def test_sync_copies_matching_files(self):
        with tempfile.TemporaryDirectory() as tmp:
            project = Path(tmp).resolve()
            run_dir = self._seed(project)
            result = core.sync_tree(project, self._repo(), "42", core.DEFAULTS)
            dest = project / "LosAngelousDocs/reports/ci/42/pack"
            self.assertTrue((dest / "report.md").is_file())
            self.assertTrue((dest / "data.json").is_file())
            self.assertFalse((dest / "skip.txt").exists())
            self.assertEqual(len(result["copied"]), 2)
            self.assertTrue((run_dir / "sync.json").is_file())
            self.assertTrue((project / "LosAngelousDocs/reports/ci/42/_sync-manifest.json").is_file())

            again = core.sync_tree(project, self._repo(), "42", core.DEFAULTS)
            self.assertEqual(len(again["copied"]), 0)
            self.assertEqual(again["skipped"], 2)

    def test_sync_rejects_escape(self):
        with tempfile.TemporaryDirectory() as tmp:
            project = Path(tmp).resolve()
            self._seed(project)
            with self.assertRaises(core.CiArtifactsError):
                core.sync_tree(project, self._repo(), "42", core.DEFAULTS, to="../../evil")

    def test_sync_requires_download(self):
        with tempfile.TemporaryDirectory() as tmp:
            with self.assertRaises(core.CiArtifactsError):
                core.sync_tree(Path(tmp).resolve(), self._repo(), "99", core.DEFAULTS)


class ConfigTests(unittest.TestCase):
    def test_merges_project_config_over_defaults(self):
        with tempfile.TemporaryDirectory() as tmp:
            project = Path(tmp)
            (project / ".ci-artifacts.json").write_text(
                json.dumps({"default_ref": "develop", "default_sync": [{"include": "**/*.txt"}]}),
                encoding="utf-8",
            )
            cfg = core.load_config(project)
            self.assertEqual(cfg["default_ref"], "develop")
            self.assertEqual(cfg["default_sync"], [{"include": "**/*.txt"}])
            self.assertEqual(cfg["docs_root"], "LosAngelousDocs/ci")
            self.assertIn("github", cfg["tokens"])

    def test_invalid_config_rejected(self):
        with tempfile.TemporaryDirectory() as tmp:
            bad = Path(tmp) / "bad.json"
            bad.write_text("{not json", encoding="utf-8")
            with self.assertRaises(core.CiArtifactsError):
                core.load_config(tmp, path=bad)


class AdapterTests(unittest.TestCase):
    def _repo(self, host="github.com", platform="github", owner="o", repo="r"):
        return {"host": host, "platform": platform, "owner": owner, "repo": repo}

    def test_github_headers_and_base(self):
        with mock.patch.dict(os.environ, {"GITHUB_TOKEN": "secret"}, clear=False):
            adapter = core.GitHubAdapter(self._repo(), core.DEFAULTS)
        self.assertEqual(adapter.base, "https://api.github.com")
        self.assertEqual(adapter.repo_path, "repos/o/r")
        self.assertEqual(adapter.headers()["Authorization"], "Bearer secret")

    def test_github_enterprise_base(self):
        adapter = core.GitHubAdapter(self._repo(host="ghe.example.com"), core.DEFAULTS)
        self.assertEqual(adapter.base, "https://ghe.example.com/api/v3")

    def test_gitlab_nested_project_encoding(self):
        adapter = core.GitLabAdapter(
            self._repo(host="gitlab.example.com", platform="gitlab", owner="group/sub"),
            core.DEFAULTS,
        )
        self.assertEqual(adapter.base, "https://gitlab.example.com/api/v4")
        self.assertEqual(adapter.project, "group%2Fsub%2Fr")

    def test_gitee_not_implemented(self):
        with self.assertRaises(core.CiArtifactsError):
            core.make_adapter(self._repo(platform="gitee"), core.DEFAULTS)

    def test_unknown_platform_hint(self):
        with self.assertRaises(core.CiArtifactsError) as ctx:
            core.make_adapter(self._repo(platform="unknown"), core.DEFAULTS)
        self.assertIn("platform", str(ctx.exception))


class RunStateTests(unittest.TestCase):
    def test_github_running_next_steps_are_non_blocking(self):
        run = {"id": "1", "status": "in_progress", "conclusion": None}
        self.assertFalse(core.is_terminal("github", run))
        steps = core.build_next_steps("github", run, [], 0)
        self.assertTrue(any("ci_wait" in step for step in steps))
        self.assertTrue(any("不阻塞" in step or "继续其它任务" in step for step in steps))

    def test_github_success_terminal(self):
        run = {"id": "1", "status": "completed", "conclusion": "success"}
        self.assertTrue(core.is_terminal("github", run))
        steps = core.build_next_steps("github", run, [], 0)
        self.assertTrue(any("artifacts" in step for step in steps))

    def test_gitlab_failed_terminal(self):
        run = {"id": "9", "status": "failed"}
        self.assertTrue(core.is_terminal("gitlab", run))
        self.assertEqual(core.run_conclusion("gitlab", run), "failed")
        steps = core.build_next_steps("gitlab", run, [{"id": 9, "name": "build"}], 0)
        self.assertTrue(any("不要基于失败产物" in step for step in steps))

    def test_wait_status_rejects_bad_id(self):
        with tempfile.TemporaryDirectory() as tmp:
            with self.assertRaises(core.CiArtifactsError):
                core.wait_status(tmp, "../../etc/passwd")

    def test_wait_status_missing(self):
        with tempfile.TemporaryDirectory() as tmp:
            with self.assertRaises(core.CiArtifactsError):
                core.wait_status(tmp, "20260101-000000-abcdef")


class RepoDetectionTests(unittest.TestCase):
    def test_detects_this_repo(self):
        info = core.detect_repo(REPO_ROOT)
        self.assertEqual(info["platform"], "github")
        self.assertEqual(info["repo"], "LosSKILL")

    def test_workflow_summary_reads_validate_yml(self):
        summary = core.workflow_summary(REPO_ROOT)
        self.assertTrue(summary["ok"])
        names = [Path(item["path"]).name for item in summary["files"]]
        self.assertIn("validate.yml", names)
        validate = next(item for item in summary["files"] if item["path"].endswith("validate.yml"))
        self.assertEqual(validate["name"], "validate")
        self.assertIn("skills", validate["jobs"])


if __name__ == "__main__":
    unittest.main()
