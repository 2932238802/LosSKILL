#!/usr/bin/env python3
"""ci-artifacts core: repo detection, CI adapters, artifact download/sync.

Standard library only. Downloaded artifacts are treated as untrusted data:
they are only unzipped and copied, never executed or imported.
"""

from __future__ import annotations

import argparse
import fnmatch
import json
import os
import re
import shutil
import stat
import subprocess
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
import zipfile
from datetime import datetime, timezone
from pathlib import Path

VERSION = "0.1.0"

GITLAB_TERMINAL = {"success", "failed", "canceled", "skipped"}

DEFAULTS = {
    "docs_root": "LosAngelousDocs/ci",
    "sync_root": "LosAngelousDocs/reports/ci",
    "state_root": "LosAngelousDocs/ci/_state",
    "default_ref": "main",
    "poll_interval": 15,
    "wait_timeout": 1800,
    "http_timeout": 30,
    "max_extract_bytes": 2 * 1024 ** 3,
    "max_log_bytes": 200_000,
    "default_sync": [
        {"include": "**/*.md"},
        {"include": "**/*.json"},
        {"include": "**/*.html"},
    ],
    "tokens": {
        "github": ["GITHUB_TOKEN", "GH_TOKEN"],
        "gitlab": ["GITLAB_TOKEN", "CI_JOB_TOKEN"],
        "gitee": ["GITEE_TOKEN"],
    },
    "api_base": {"github": "", "gitlab": "", "gitee": "https://gitee.com/api/v5"},
}


class CiArtifactsError(RuntimeError):
    """User-facing error with a readable message."""


def utc_now() -> str:
    return datetime.now(timezone.utc).isoformat(timespec="seconds")


# --------------------------------------------------------------------------
# config
# --------------------------------------------------------------------------

def _deep_merge(base: dict, extra: dict) -> dict:
    for key, value in extra.items():
        if isinstance(value, dict) and isinstance(base.get(key), dict):
            _deep_merge(base[key], value)
        else:
            base[key] = value
    return base


def load_config(project_root=None, path=None) -> dict:
    cfg = json.loads(json.dumps(DEFAULTS))
    candidates = []
    if path:
        candidates.append(Path(path))
    env_path = os.environ.get("CI_ARTIFACTS_CONFIG")
    if env_path:
        candidates.append(Path(env_path))
    if project_root:
        candidates.append(Path(project_root) / ".ci-artifacts.json")
    candidates.append(Path(__file__).resolve().parent / "config.json")
    for candidate in candidates:
        if candidate and candidate.is_file():
            try:
                data = json.loads(candidate.read_text(encoding="utf-8"))
            except (OSError, ValueError) as exc:
                raise CiArtifactsError(f"invalid config {candidate}: {exc}") from None
            if not isinstance(data, dict):
                raise CiArtifactsError(f"invalid config {candidate}: expected a JSON object")
            _deep_merge(cfg, data)
    return cfg


def _first_token(names) -> str | None:
    for name in names or []:
        value = os.environ.get(name)
        if value:
            return value
    return None


# --------------------------------------------------------------------------
# repo detection
# --------------------------------------------------------------------------

_SCP_STYLE = re.compile(r"^(?:(?P<user>[^@/]+)@)?(?P<host>[^:/]+):(?P<path>.+)$")


def _platform_for(host: str) -> str:
    host = host.lower()
    if host == "github.com" or "github" in host:
        return "github"
    if host == "gitlab.com" or "gitlab" in host:
        return "gitlab"
    if host == "gitee.com" or "gitee" in host:
        return "gitee"
    return "unknown"


def parse_remote_url(url: str) -> dict:
    """Parse ssh/https git remotes into platform/owner/repo.

    Supports:
      git@github.com:owner/repo.git
      https://github.com/owner/repo.git
      ssh://git@gitlab.example.com:2222/group/sub/repo.git
      https://gitee.com/owner/repo
    """
    raw = (url or "").strip()
    if not raw:
        raise CiArtifactsError("empty remote url")

    if "://" in raw:
        parsed = urllib.parse.urlparse(raw)
        host = (parsed.hostname or "").lower()
        path = parsed.path.lstrip("/")
    else:
        match = _SCP_STYLE.match(raw)
        if not match:
            raise CiArtifactsError(f"cannot parse remote url: {raw}")
        host = match.group("host").lower()
        path = match.group("path")

    if not host:
        raise CiArtifactsError(f"cannot parse remote url: {raw}")

    path = urllib.parse.unquote(path).strip("/")
    if path.endswith(".git"):
        path = path[:-4]
    path = path.strip("/")
    parts = [p for p in path.split("/") if p]
    if len(parts) < 2:
        raise CiArtifactsError(f"remote path must be <owner>/<repo>: {raw}")

    owner = "/".join(parts[:-1])
    repo = parts[-1]
    return {
        "platform": _platform_for(host),
        "host": host,
        "owner": owner,
        "repo": repo,
        "project_path": "/".join(parts),
        "remote_url": raw,
        "web_url": f"https://{host}/{owner}/{repo}",
    }


def resolve_project_root(project_path=None) -> Path:
    raw = project_path or os.getcwd()
    path = Path(raw).expanduser()
    if path.is_file():
        path = path.parent
    path = path.resolve()
    if (path / ".git").exists():
        return path
    result = subprocess.run(
        ["git", "-C", str(path), "rev-parse", "--show-toplevel"],
        capture_output=True,
        text=True,
    )
    if result.returncode == 0 and result.stdout.strip():
        return Path(result.stdout.strip()).resolve()
    raise CiArtifactsError(f"not a git repository: {path}")


def git_remote_url(project_root: Path, remote: str = "origin") -> str:
    result = subprocess.run(
        ["git", "-C", str(project_root), "remote", "get-url", remote],
        capture_output=True,
        text=True,
    )
    if result.returncode != 0:
        raise CiArtifactsError(
            f"git remote '{remote}' not found in {project_root}"
        )
    return result.stdout.strip()


def detect_repo(project_path=None, remote: str = "origin", platform: str | None = None) -> dict:
    root = resolve_project_root(project_path)
    info = parse_remote_url(git_remote_url(root, remote))
    if platform:
        info["platform"] = platform
    info["project_root"] = str(root)
    info["remote"] = remote
    return info


def detect_repo_for(project_root, config: dict | None = None) -> dict:
    """Detect using project config overrides (remote / platform for self-hosted)."""
    config = config or {}
    return detect_repo(
        project_root,
        remote=config.get("remote") or "origin",
        platform=config.get("platform") or None,
    )


# --------------------------------------------------------------------------
# path helpers
# --------------------------------------------------------------------------

_INVALID_CHARS = re.compile(r"[^A-Za-z0-9._-]+")


def sanitize(value, max_len: int = 80) -> str:
    text = _INVALID_CHARS.sub("-", str(value)).strip("-.")
    return (text or "unnamed")[:max_len]


def sanitize_owner(owner: str) -> str:
    return sanitize(owner.replace("/", "-"), 120)


def safe_run_id(run_id) -> str:
    text = str(run_id)
    if not re.fullmatch(r"[0-9A-Za-z._-]{1,64}", text):
        raise CiArtifactsError(f"invalid run id: {text!r}")
    return text


def ensure_within(path: Path, root: Path) -> Path:
    path = Path(path).resolve()
    root = Path(root).resolve()
    try:
        path.relative_to(root)
    except ValueError:
        raise CiArtifactsError(f"path escapes project root: {path}") from None
    return path


def docs_root_dir(project_root, config: dict) -> Path:
    root = Path(project_root).resolve()
    return ensure_within(root / config["docs_root"], root)


def default_run_dir(project_root, repo: dict, run_id, config: dict) -> Path:
    docs_root = docs_root_dir(project_root, config)
    run_dir = (
        docs_root
        / repo["platform"]
        / f"{sanitize_owner(repo['owner'])}-{sanitize(repo['repo'])}"
        / safe_run_id(run_id)
    )
    return ensure_within(run_dir, docs_root)


def state_dir(project_root, config: dict) -> Path:
    root = Path(project_root).resolve()
    docs_root = docs_root_dir(project_root, config)
    path = root / config["state_root"]
    return ensure_within(path, docs_root)


def write_json(path: Path, data) -> None:
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_name(f".{path.name}.tmp.{os.getpid()}")
    tmp.write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")
    os.replace(tmp, path)


# --------------------------------------------------------------------------
# HTTP (stdlib only, redirect-safe)
# --------------------------------------------------------------------------

class _SafeRedirect(urllib.request.HTTPRedirectHandler):
    """Drop credentials when a redirect crosses hosts (e.g. GitHub -> S3)."""

    def redirect_request(self, req, fp, code, msg, headers, newurl):
        new = super().redirect_request(req, fp, code, msg, headers, newurl)
        if new is not None:
            old_host = urllib.parse.urlsplit(req.full_url).hostname
            new_host = urllib.parse.urlsplit(newurl).hostname
            if new_host != old_host:
                new.remove_header("Authorization")
                new.remove_header("PRIVATE-TOKEN")
        return new


_OPENER = urllib.request.build_opener(_SafeRedirect)


def _http_open(url: str, headers: dict | None = None, timeout: int = 30):
    request = urllib.request.Request(url, headers=headers or {}, method="GET")
    try:
        return _OPENER.open(request, timeout=timeout)
    except urllib.error.HTTPError as exc:
        body = ""
        try:
            body = exc.read(500).decode("utf-8", "replace").strip()
        except Exception:
            pass
        detail = f": {body}" if body else ""
        raise CiArtifactsError(f"HTTP {exc.code} for {url}{detail}") from None
    except urllib.error.URLError as exc:
        raise CiArtifactsError(f"network error for {url}: {exc.reason}") from None


# --------------------------------------------------------------------------
# adapters
# --------------------------------------------------------------------------

class _Adapter:
    platform = ""

    def __init__(self, repo: dict, config: dict):
        self.repo = repo
        self.config = config
        self.timeout = int(config.get("http_timeout", 30))
        self.token = _first_token(config.get("tokens", {}).get(self.platform, []))

    def headers(self, accept: str = "application/json") -> dict:
        headers = {"Accept": accept, "User-Agent": f"losskill-ci-artifacts/{VERSION}"}
        if self.token:
            headers["Authorization"] = f"Bearer {self.token}"
        return headers

    def _json(self, url: str, headers: dict | None = None):
        with _http_open(url, headers or self.headers(), self.timeout) as resp:
            payload = resp.read()
        try:
            return json.loads(payload.decode("utf-8"))
        except ValueError:
            raise CiArtifactsError(f"invalid JSON from {url}") from None

    def _text(self, url: str, headers: dict | None = None, max_bytes: int | None = None) -> str:
        limit = int(max_bytes or self.config.get("max_log_bytes", 200_000))
        with _http_open(url, headers or self.headers("text/plain"), self.timeout) as resp:
            if getattr(resp, "status", 200) == 202:
                return "(log is still being archived)"
            data = resp.read(limit + 1)
        text = data.decode("utf-8", "replace")
        if len(text) > limit:
            text = "...(truncated)...\n" + text[-limit:]
        return text

    def _download(self, url: str, dest: Path, headers: dict | None = None) -> None:
        dest = Path(dest)
        dest.parent.mkdir(parents=True, exist_ok=True)
        tmp = dest.with_name(dest.name + ".part")
        with _http_open(url, headers or self.headers(), max(self.timeout, 120)) as resp:
            with open(tmp, "wb") as out:
                shutil.copyfileobj(resp, out, 256 * 1024)
        os.replace(tmp, dest)

    # -- interface ---------------------------------------------------------
    def latest_run(self, ref: str | None = None):
        raise NotImplementedError

    def list_runs(self, ref: str | None = None, limit: int = 10):
        raise NotImplementedError

    def get_run(self, run_id):
        raise NotImplementedError

    def list_jobs(self, run_id):
        raise NotImplementedError

    def job_log(self, job_id) -> str:
        raise NotImplementedError

    def list_artifacts(self, run_id):
        raise NotImplementedError

    def download_artifact(self, artifact: dict, dest: Path) -> None:
        raise NotImplementedError


class GitHubAdapter(_Adapter):
    platform = "github"

    def __init__(self, repo: dict, config: dict):
        super().__init__(repo, config)
        base = config.get("api_base", {}).get("github") or ""
        if not base:
            base = (
                "https://api.github.com"
                if repo.get("host") == "github.com"
                else f"https://{repo['host']}/api/v3"
            )
        self.base = base.rstrip("/")
        owner = urllib.parse.quote(repo["owner"], safe="")
        name = urllib.parse.quote(repo["repo"], safe="")
        self.repo_path = f"repos/{owner}/{name}"

    def headers(self, accept: str = "application/vnd.github+json") -> dict:
        headers = {
            "Accept": accept,
            "User-Agent": f"losskill-ci-artifacts/{VERSION}",
            "X-GitHub-Api-Version": "2022-11-28",
        }
        if self.token:
            headers["Authorization"] = f"Bearer {self.token}"
        return headers

    def latest_run(self, ref: str | None = None):
        query = {"per_page": 1}
        if ref:
            query["branch"] = ref
        data = self._json(
            f"{self.base}/{self.repo_path}/actions/runs?{urllib.parse.urlencode(query)}"
        )
        runs = data.get("workflow_runs") or []
        return runs[0] if runs else None

    def list_runs(self, ref: str | None = None, limit: int = 10):
        query = {"per_page": max(1, min(int(limit), 100))}
        if ref:
            query["branch"] = ref
        data = self._json(
            f"{self.base}/{self.repo_path}/actions/runs?{urllib.parse.urlencode(query)}"
        )
        return data.get("workflow_runs") or []

    def get_run(self, run_id):
        return self._json(f"{self.base}/{self.repo_path}/actions/runs/{safe_run_id(run_id)}")

    def list_jobs(self, run_id):
        data = self._json(
            f"{self.base}/{self.repo_path}/actions/runs/{safe_run_id(run_id)}/jobs?per_page=100"
        )
        return data.get("jobs") or []

    def job_log(self, job_id) -> str:
        return self._text(
            f"{self.base}/{self.repo_path}/actions/jobs/{safe_run_id(job_id)}/logs",
            self.headers("text/plain"),
        )

    def list_artifacts(self, run_id):
        data = self._json(
            f"{self.base}/{self.repo_path}/actions/runs/{safe_run_id(run_id)}/artifacts?per_page=100"
        )
        return data.get("artifacts") or []

    def download_artifact(self, artifact: dict, dest: Path) -> None:
        url = artifact.get("archive_download_url")
        if not url:
            raise CiArtifactsError(f"artifact {artifact.get('name')!r} has no download url")
        if not self.token:
            raise CiArtifactsError(
                "GitHub artifact download requires GITHUB_TOKEN (or GH_TOKEN) in the environment"
            )
        self._download(url, dest, self.headers())


class GitLabAdapter(_Adapter):
    platform = "gitlab"

    def __init__(self, repo: dict, config: dict):
        super().__init__(repo, config)
        base = config.get("api_base", {}).get("gitlab") or ""
        if not base:
            base = f"https://{repo['host']}/api/v4"
        self.base = base.rstrip("/")
        self.project = urllib.parse.quote(f"{repo['owner']}/{repo['repo']}", safe="")

    def headers(self, accept: str = "application/json") -> dict:
        headers = {"Accept": accept, "User-Agent": f"losskill-ci-artifacts/{VERSION}"}
        if self.token:
            headers["PRIVATE-TOKEN"] = self.token
        return headers

    def latest_run(self, ref: str | None = None):
        query = {"per_page": 1, "order_by": "id", "sort": "desc"}
        if ref:
            query["ref"] = ref
        data = self._json(
            f"{self.base}/projects/{self.project}/pipelines?{urllib.parse.urlencode(query)}"
        )
        return data[0] if data else None

    def list_runs(self, ref: str | None = None, limit: int = 10):
        query = {"per_page": max(1, min(int(limit), 100)), "order_by": "id", "sort": "desc"}
        if ref:
            query["ref"] = ref
        data = self._json(
            f"{self.base}/projects/{self.project}/pipelines?{urllib.parse.urlencode(query)}"
        )
        return data or []

    def get_run(self, run_id):
        return self._json(
            f"{self.base}/projects/{self.project}/pipelines/{safe_run_id(run_id)}"
        )

    def list_jobs(self, run_id):
        data = self._json(
            f"{self.base}/projects/{self.project}/pipelines/{safe_run_id(run_id)}/jobs?per_page=100"
        )
        return data or []

    def job_log(self, job_id) -> str:
        return self._text(
            f"{self.base}/projects/{self.project}/jobs/{safe_run_id(job_id)}/trace",
            self.headers("text/plain"),
        )

    def list_artifacts(self, run_id):
        artifacts = []
        for job in self.list_jobs(run_id):
            meta = job.get("artifacts_file") or job.get("artifacts")
            if not meta:
                continue
            artifacts.append(
                {
                    "name": job.get("name") or f"job-{job.get('id')}",
                    "job_id": job.get("id"),
                    "size_in_bytes": (meta or {}).get("size") if isinstance(meta, dict) else None,
                    "expire_at": job.get("artifacts_expire_at"),
                }
            )
        return artifacts

    def download_artifact(self, artifact: dict, dest: Path) -> None:
        job_id = artifact.get("job_id")
        if not job_id:
            raise CiArtifactsError(f"artifact {artifact.get('name')!r} has no job_id")
        self._download(
            f"{self.base}/projects/{self.project}/jobs/{safe_run_id(job_id)}/artifacts",
            dest,
            self.headers("application/zip"),
        )


def make_adapter(repo: dict, config: dict) -> _Adapter:
    platform = repo.get("platform")
    if platform == "github":
        return GitHubAdapter(repo, config)
    if platform == "gitlab":
        return GitLabAdapter(repo, config)
    if platform == "gitee":
        raise CiArtifactsError(
            "Gitee is detected but not implemented yet (GitHub/GitLab first)"
        )
    raise CiArtifactsError(
        f"unsupported platform {platform!r}; pass platform='github' or 'gitlab' for self-hosted hosts"
    )


# --------------------------------------------------------------------------
# run normalization
# --------------------------------------------------------------------------

def normalize_run(platform: str, run: dict) -> dict:
    if platform == "github":
        return {
            "id": str(run.get("id")),
            "name": run.get("name"),
            "status": run.get("status"),
            "conclusion": run.get("conclusion"),
            "ref": run.get("head_branch"),
            "sha": run.get("head_sha"),
            "event": run.get("event"),
            "web_url": run.get("html_url"),
            "created_at": run.get("created_at"),
            "updated_at": run.get("updated_at"),
        }
    return {
        "id": str(run.get("id")),
        "name": run.get("name") or f"pipeline {run.get('id')}",
        "status": run.get("status"),
        "conclusion": run.get("status"),
        "ref": run.get("ref"),
        "sha": run.get("sha"),
        "event": run.get("source"),
        "web_url": run.get("web_url"),
        "created_at": run.get("created_at"),
        "updated_at": run.get("updated_at"),
    }


def is_terminal(platform: str, run: dict) -> bool:
    status = run.get("status") or ""
    if platform == "github":
        return status == "completed"
    return status in GITLAB_TERMINAL


def run_conclusion(platform: str, run: dict) -> str:
    if platform == "github":
        if run.get("status") != "completed":
            return run.get("status") or "unknown"
        return run.get("conclusion") or "unknown"
    return run.get("status") or "unknown"


def _failed(job: dict) -> bool:
    conclusion = job.get("conclusion")
    status = job.get("status")
    return conclusion in {"failure", "failed", "canceled", "timed_out"} or status == "failed"


def build_next_steps(platform: str, run: dict, failed_jobs: list, artifact_count: int) -> list:
    if not is_terminal(platform, run):
        return [
            "CI 仍在运行：调用 ci_wait 启动非阻塞等待（auto_download=true）",
            "等待期间继续其它任务，稍后用 ci_wait_status 查询",
            "CI 成功后产物会自动下载到 LosAngelousDocs/ci/<平台>/<owner>-<repo>/<run-id>/",
        ]
    conclusion = run_conclusion(platform, run)
    if conclusion != "success":
        names = ", ".join(j.get("name") or str(j.get("id")) for j in failed_jobs[:5]) or "未知"
        return [
            f"本次运行结论为 {conclusion}，不要基于失败产物继续",
            f"先读失败任务日志（failed_jobs / log_excerpt），失败任务：{names}",
            "修复后重跑；重跑成功再走下载/同步流程",
        ]
    steps = [
        "产物目录：LosAngelousDocs/ci/<平台>/<owner>-<repo>/<run-id>/artifacts/",
    ]
    if artifact_count:
        steps.append("调用 ci_sync_artifacts 把关键文件同步到 LosAngelousDocs/reports/ci/<run-id>/")
    else:
        steps.append("本次运行没有 artifacts：检查 CI 配置里的 artifacts / upload-artifact 段")
    steps.append("阅读同步后的报告或产物，再进入评审/下一步流程")
    return steps


# --------------------------------------------------------------------------
# status / run info
# --------------------------------------------------------------------------

def _resolve_run(project_root, run_id, ref, config, repo):
    if repo is None:
        repo = detect_repo_for(project_root, config)
    adapter = make_adapter(repo, config)
    ref = ref or config.get("default_ref")
    run = adapter.get_run(run_id) if run_id else adapter.latest_run(ref)
    return repo, adapter, run


def _job_summary(platform: str, job: dict) -> dict:
    item = {
        "id": job.get("id"),
        "name": job.get("name") or job.get("stage"),
        "status": job.get("status"),
        "conclusion": job.get("conclusion") or job.get("status"),
        "web_url": job.get("html_url") or job.get("web_url"),
        "failed_steps": [],
    }
    if platform == "github":
        steps = []
        for step in job.get("steps") or []:
            steps.append(
                {
                    "name": step.get("name"),
                    "status": step.get("status"),
                    "conclusion": step.get("conclusion"),
                }
            )
            if step.get("conclusion") in {"failure", "canceled", "timed_out"}:
                item["failed_steps"].append(step.get("name"))
        item["steps"] = steps
    return item


def run_info(project_root=None, run_id=None, ref=None, include_logs: bool = True,
             config: dict | None = None, repo: dict | None = None) -> dict:
    project_root = resolve_project_root(project_root)
    config = config or load_config(project_root)
    repo, adapter, run = _resolve_run(project_root, run_id, ref, config, repo)
    if not run:
        return {
            "ok": False,
            "error": f"no CI run found for {repo['owner']}/{repo['repo']} (ref={ref or config.get('default_ref')})",
            "repo": repo,
            "checked_at": utc_now(),
        }

    platform = repo["platform"]
    normalized = normalize_run(platform, run)
    rid = normalized["id"]
    jobs = [_job_summary(platform, job) for job in adapter.list_jobs(rid)]
    failed_jobs = [job for job in jobs if _failed(job)]

    artifact_count = 0
    if is_terminal(platform, normalized) and run_conclusion(platform, normalized) == "success":
        try:
            artifact_count = len(adapter.list_artifacts(rid))
        except CiArtifactsError:
            artifact_count = 0

    log_excerpt = None
    if include_logs and failed_jobs:
        try:
            log_excerpt = adapter.job_log(failed_jobs[0]["id"])
        except CiArtifactsError as exc:
            log_excerpt = f"(log unavailable: {exc})"

    return {
        "ok": True,
        "repo": repo,
        "run": normalized,
        "conclusion": run_conclusion(platform, normalized),
        "terminal": is_terminal(platform, normalized),
        "jobs": jobs,
        "failed_jobs": failed_jobs,
        "artifact_count": artifact_count,
        "log_excerpt": log_excerpt,
        "next_steps": build_next_steps(platform, normalized, failed_jobs, artifact_count),
        "checked_at": utc_now(),
    }


# --------------------------------------------------------------------------
# safe extraction
# --------------------------------------------------------------------------

def safe_extract(zip_path, dest_dir, max_bytes: int | None = None) -> int:
    """Extract a zip without allowing path traversal, symlinks, or zip bombs."""
    zip_path = Path(zip_path)
    dest = Path(dest_dir).resolve()
    dest.mkdir(parents=True, exist_ok=True)
    limit = int(max_bytes or DEFAULTS["max_extract_bytes"])
    total = 0
    count = 0
    with zipfile.ZipFile(zip_path) as archive:
        for info in archive.infolist():
            if info.is_dir():
                continue
            name = info.filename.replace("\\", "/")
            if (
                name.startswith("/")
                or re.match(r"^[A-Za-z]:", name)
                or ".." in Path(name).parts
            ):
                raise CiArtifactsError(f"refusing unsafe zip entry: {info.filename!r}")
            mode = (info.external_attr >> 16) & 0xFFFF
            if stat.S_ISLNK(mode):
                continue
            total += info.file_size
            if total > limit:
                raise CiArtifactsError(
                    f"zip expands past limit ({limit} bytes): {zip_path.name}"
                )
            target = (dest / name).resolve()
            ensure_within(target, dest)
            target.parent.mkdir(parents=True, exist_ok=True)
            with archive.open(info) as src, open(target, "wb") as out:
                shutil.copyfileobj(src, out, 256 * 1024)
            count += 1
    return count


# --------------------------------------------------------------------------
# download
# --------------------------------------------------------------------------

def _artifact_dir_name(name: str, used: set) -> str:
    base = sanitize(name, 60)
    candidate = base
    index = 2
    while candidate in used:
        candidate = f"{base}-{index}"
        index += 1
    used.add(candidate)
    return candidate


def download_artifacts(project_root=None, run_id=None, ref=None, dest=None,
                       force: bool = False, config: dict | None = None,
                       repo: dict | None = None) -> dict:
    project_root = resolve_project_root(project_root)
    config = config or load_config(project_root)
    repo, adapter, run = _resolve_run(project_root, run_id, ref, config, repo)
    if not run:
        raise CiArtifactsError(
            f"no CI run found for {repo['owner']}/{repo['repo']} (ref={ref or config.get('default_ref')})"
        )

    platform = repo["platform"]
    normalized = normalize_run(platform, run)
    rid = normalized["id"]
    out_dir = Path(dest) if dest else default_run_dir(project_root, repo, rid, config)
    if not out_dir.is_absolute():
        out_dir = Path(project_root) / out_dir
    out_dir = Path(out_dir).resolve()

    artifacts = adapter.list_artifacts(rid)
    zip_dir = out_dir / "zips"
    unpack_dir = out_dir / "artifacts"
    downloaded = []
    used = set()

    for artifact in artifacts:
        name = _artifact_dir_name(artifact.get("name") or f"artifact-{len(used) + 1}", used)
        zip_path = zip_dir / f"{name}.zip"
        if force or not zip_path.exists():
            adapter.download_artifact(artifact, zip_path)
        target = unpack_dir / name
        if target.exists():
            shutil.rmtree(target)
        tmp = unpack_dir / f".extract-{os.urandom(4).hex()}"
        try:
            files = safe_extract(zip_path, tmp, config.get("max_extract_bytes"))
            tmp.replace(target)
        finally:
            if tmp.exists():
                shutil.rmtree(tmp, ignore_errors=True)
        downloaded.append(
            {
                "name": artifact.get("name"),
                "size_in_bytes": artifact.get("size_in_bytes"),
                "zip": str(zip_path),
                "extracted_to": str(target),
                "files": files,
            }
        )

    manifest = {
        "ok": True,
        "repo": repo,
        "run": normalized,
        "run_dir": str(out_dir),
        "artifacts": downloaded,
        "generated_at": utc_now(),
    }
    write_json(out_dir / "run.json", manifest)
    return manifest


# --------------------------------------------------------------------------
# sync
# --------------------------------------------------------------------------

def glob_match(rel_path: str, pattern: str) -> bool:
    rel_path = rel_path.replace("\\", "/")
    pattern = pattern.replace("\\", "/")
    if fnmatch.fnmatchcase(rel_path, pattern):
        return True
    if pattern.startswith("**/"):
        return fnmatch.fnmatchcase(rel_path, pattern[3:])
    return False


def sync_tree(project_root, repo: dict, run_id, config: dict,
              include=None, to=None) -> dict:
    project_root = Path(project_root).resolve()
    rid = safe_run_id(run_id)
    run_dir = default_run_dir(project_root, repo, rid, config)
    artifacts_dir = run_dir / "artifacts"
    if not artifacts_dir.is_dir():
        raise CiArtifactsError(
            f"no downloaded artifacts at {artifacts_dir}; call ci_download_artifacts first"
        )

    if include:
        patterns = include if isinstance(include, (list, tuple)) else [include]
        rules = [{"include": pattern} for pattern in patterns]
    else:
        rules = config.get("default_sync") or []

    dest_base = (to or config["sync_root"]).format(run_id=rid)
    dest_dir = ensure_within(
        project_root / dest_base / rid,
        project_root,
    )

    copied = []
    skipped = 0
    for path in sorted(artifacts_dir.rglob("*")):
        if not path.is_file() or path.is_symlink():
            continue
        rel = path.relative_to(artifacts_dir).as_posix()
        if not any(glob_match(rel, rule.get("include", "")) for rule in rules):
            continue
        target = ensure_within(dest_dir / rel, project_root)
        target.parent.mkdir(parents=True, exist_ok=True)
        if target.exists() and target.stat().st_size == path.stat().st_size:
            skipped += 1
            continue
        shutil.copyfile(path, target)
        copied.append(
            {
                "source": rel,
                "target": str(target),
            }
        )

    manifest = {
        "ok": True,
        "repo": repo,
        "run_id": rid,
        "run_dir": str(run_dir),
        "dest_dir": str(dest_dir),
        "patterns": rules,
        "copied": copied,
        "skipped": skipped,
        "synced_at": utc_now(),
    }
    write_json(run_dir / "sync.json", manifest)
    write_json(dest_dir / "_sync-manifest.json", manifest)
    return manifest


def sync_artifacts(project_root=None, run_id=None, ref=None, include=None, to=None,
                   config: dict | None = None, repo: dict | None = None) -> dict:
    project_root = resolve_project_root(project_root)
    config = config or load_config(project_root)
    if repo is None:
        repo = detect_repo_for(project_root, config)
    if not run_id:
        _, adapter, run = _resolve_run(project_root, None, ref, config, repo)
        if not run:
            raise CiArtifactsError("no CI run found")
        run_id = run.get("id")
    return sync_tree(project_root, repo, run_id, config, include=include, to=to)


# --------------------------------------------------------------------------
# CI config reading
# --------------------------------------------------------------------------

def _parse_workflow_text(path: Path, text: str) -> dict:
    name = None
    jobs = []
    artifact_hints = []
    in_jobs = False
    for raw_line in text.splitlines():
        line = raw_line.rstrip()
        if not line or line.lstrip().startswith("#"):
            continue
        if name is None:
            match = re.match(r"^name:\s*(.+?)\s*$", line)
            if match:
                name = match.group(1).strip("'\"")
        if re.match(r"^jobs:\s*$", line):
            in_jobs = True
            continue
        if in_jobs:
            match = re.match(r"^ {2}([A-Za-z0-9_.-]+):\s*$", line)
            if match:
                jobs.append(match.group(1))
            elif line and not line.startswith(" "):
                in_jobs = False
        lowered = line.lower()
        if any(key in lowered for key in ("upload-artifact", "artifacts:", "artifacts_path", "paths:")):
            stripped = line.strip()
            if stripped not in artifact_hints:
                artifact_hints.append(stripped)
    return {
        "path": str(path),
        "name": name or path.stem,
        "jobs": jobs,
        "artifact_hints": artifact_hints[:20],
    }


def workflow_summary(project_root=None, config: dict | None = None) -> dict:
    project_root = resolve_project_root(project_root)
    config = config or load_config(project_root)
    candidates = []
    candidates.extend(sorted((project_root / ".github" / "workflows").glob("*.yml")))
    candidates.extend(sorted((project_root / ".github" / "workflows").glob("*.yaml")))
    gitlab_ci = project_root / ".gitlab-ci.yml"
    if gitlab_ci.is_file():
        candidates.append(gitlab_ci)

    if not candidates:
        return {
            "ok": False,
            "error": "no CI config found (.github/workflows/*.yml or .gitlab-ci.yml)",
            "project_root": str(project_root),
        }

    files = []
    for path in candidates:
        try:
            text = path.read_text(encoding="utf-8", errors="replace")[:512_000]
        except OSError as exc:
            files.append({"path": str(path), "error": str(exc)})
            continue
        files.append(_parse_workflow_text(path, text))

    has_artifacts = any(item.get("artifact_hints") for item in files)
    next_steps = (
        ["CI 已声明 artifacts，运行成功后可用 ci_download_artifacts 拉取"]
        if has_artifacts
        else ["CI 配置里没有明显的 artifacts 段落；需要先让 CI 产出 artifacts 才能下载"]
    )
    return {
        "ok": True,
        "project_root": str(project_root),
        "files": files,
        "has_artifacts": has_artifacts,
        "next_steps": next_steps,
    }


# --------------------------------------------------------------------------
# non-blocking watcher control
# --------------------------------------------------------------------------

def start_watcher(project_root=None, run_id=None, ref=None, interval=None,
                  timeout=None, auto_download: bool = True, do_sync: bool = True,
                  config: dict | None = None, repo: dict | None = None) -> dict:
    project_root = resolve_project_root(project_root)
    config = config or load_config(project_root)
    repo = repo or detect_repo_for(project_root, config)
    _, adapter, run = _resolve_run(project_root, run_id, ref, config, repo)
    if not run:
        raise CiArtifactsError(
            f"no CI run found for {repo['owner']}/{repo['repo']} (ref={ref or config.get('default_ref')})"
        )
    normalized = normalize_run(repo["platform"], run)
    rid = normalized["id"]

    watcher_id = datetime.now().strftime("%Y%m%d-%H%M%S") + "-" + os.urandom(3).hex()
    status_path = state_dir(project_root, config) / f"wait-{watcher_id}.json"
    write_json(
        status_path,
        {
            "watcher_id": watcher_id,
            "phase": "starting",
            "project_root": str(project_root),
            "repo": repo,
            "run": normalized,
            "auto_download": auto_download,
            "sync": do_sync,
            "started_at": utc_now(),
            "updated_at": utc_now(),
        },
    )

    cmd = [
        sys.executable,
        "-E",
        "-s",
        str(Path(__file__).resolve().parent / "watcher.py"),
        "--project", str(project_root),
        "--run-id", rid,
        "--status-file", str(status_path),
        "--interval", str(int(interval or config["poll_interval"])),
        "--timeout", str(int(timeout or config["wait_timeout"])),
    ]
    if ref or config.get("default_ref"):
        cmd.extend(["--ref", ref or config["default_ref"]])
    if auto_download:
        cmd.append("--auto-download")
    if do_sync:
        cmd.append("--sync")

    kwargs = {}
    if os.name == "nt":
        flags = subprocess.CREATE_NEW_PROCESS_GROUP
        flags |= getattr(subprocess, "DETACHED_PROCESS", 0)
        kwargs["creationflags"] = flags
    else:
        kwargs["start_new_session"] = True
    subprocess.Popen(
        cmd,
        stdin=subprocess.DEVNULL,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        close_fds=True,
        cwd=str(project_root),
        **kwargs,
    )

    return {
        "ok": True,
        "watcher_id": watcher_id,
        "status_file": str(status_path),
        "run_id": rid,
        "phase": "starting",
        "message": "非阻塞等待已启动；继续其它工作，稍后用 ci_wait_status 查询",
        "checked_at": utc_now(),
    }


def wait_status(project_root=None, watcher_id=None, status_file=None,
                config: dict | None = None) -> dict:
    project_root = resolve_project_root(project_root)
    config = config or load_config(project_root)
    if status_file:
        path = Path(status_file)
        if not path.is_absolute():
            path = project_root / path
        path = ensure_within(path, state_dir(project_root, config))
    elif watcher_id:
        if not re.fullmatch(r"[0-9A-Za-z._-]{1,80}", watcher_id):
            raise CiArtifactsError(f"invalid watcher id: {watcher_id!r}")
        path = state_dir(project_root, config) / f"wait-{watcher_id}.json"
    else:
        raise CiArtifactsError("watcher_id or status_file is required")

    if not path.is_file():
        available = [p.name for p in state_dir(project_root, config).glob("wait-*.json")]
        raise CiArtifactsError(
            f"status file not found: {path}; available: {available or 'none'}"
        )
    data = json.loads(path.read_text(encoding="utf-8"))
    data["ok"] = True
    return data


# --------------------------------------------------------------------------
# CLI
# --------------------------------------------------------------------------

def _build_cli() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(prog="ci-artifacts")
    parser.add_argument("--version", action="version", version=VERSION)
    sub = parser.add_subparsers(dest="command", required=True)

    def project_arg(p):
        p.add_argument("--project", default=None, help="项目路径，默认当前目录")
        p.add_argument("--remote", default="origin")

    p = sub.add_parser("detect", help="识别仓库平台与 owner/repo")
    project_arg(p)
    p.add_argument("--platform", default=None)

    p = sub.add_parser("workflow", help="读取 CI 配置摘要")
    project_arg(p)

    p = sub.add_parser("status", help="读取最近一次/指定 CI 运行")
    project_arg(p)
    p.add_argument("--run-id", default=None)
    p.add_argument("--ref", default=None)
    p.add_argument("--no-logs", action="store_true")

    p = sub.add_parser("download", help="下载 artifacts 到 LosAngelousDocs/ci/...")
    project_arg(p)
    p.add_argument("--run-id", default=None)
    p.add_argument("--ref", default=None)
    p.add_argument("--dest", default=None)
    p.add_argument("--force", action="store_true")

    p = sub.add_parser("sync", help="同步关键文件到 docs")
    project_arg(p)
    p.add_argument("--run-id", default=None)
    p.add_argument("--ref", default=None)
    p.add_argument("--include", action="append", default=None)
    p.add_argument("--to", default=None)

    p = sub.add_parser("wait", help="启动非阻塞等待")
    project_arg(p)
    p.add_argument("--run-id", default=None)
    p.add_argument("--ref", default=None)
    p.add_argument("--interval", type=int, default=None)
    p.add_argument("--timeout", type=int, default=None)
    p.add_argument("--no-download", action="store_true")
    p.add_argument("--no-sync", action="store_true")

    p = sub.add_parser("wait-status", help="查询等待状态")
    project_arg(p)
    p.add_argument("--watcher-id", default=None)
    p.add_argument("--status-file", default=None)
    return parser


def main(argv=None) -> int:
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8")
    args = _build_cli().parse_args(argv)
    try:
        if args.command == "detect":
            out = detect_repo(args.project, args.remote, args.platform)
        elif args.command == "workflow":
            out = workflow_summary(args.project)
        elif args.command == "status":
            out = run_info(args.project, args.run_id, args.ref,
                           include_logs=not args.no_logs)
        elif args.command == "download":
            out = download_artifacts(args.project, args.run_id, args.ref,
                                     args.dest, args.force)
        elif args.command == "sync":
            out = sync_artifacts(args.project, args.run_id, args.ref,
                                 args.include, args.to)
        elif args.command == "wait":
            out = start_watcher(args.project, args.run_id, args.ref,
                                args.interval, args.timeout,
                                auto_download=not args.no_download,
                                do_sync=not args.no_sync)
        elif args.command == "wait-status":
            out = wait_status(args.project, args.watcher_id, args.status_file)
        else:  # pragma: no cover
            raise CiArtifactsError(f"unknown command {args.command}")
        print(json.dumps(out, ensure_ascii=False, indent=2))
        return 0 if out.get("ok", True) else 1
    except CiArtifactsError as exc:
        print(json.dumps({"ok": False, "error": str(exc)}, ensure_ascii=False, indent=2))
        return 1


if __name__ == "__main__":
    sys.exit(main())
