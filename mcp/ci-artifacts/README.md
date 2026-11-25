# ci-artifacts MCP

给 Agent 用的 CI 产物工具：**识别仓库 → 读 CI → 非阻塞等待 → 自动下载 artifacts → 同步关键文件到 docs**。
纯标准库 Python（3.9+），无第三方依赖，stdio JSON-RPC 实现，不执行下载内容。

## 工具

| 工具 | 作用 |
|---|---|
| `repo_info` | 从 `git remote` 识别 GitHub/GitLab，返回 host / owner / repo |
| `ci_workflow_summary` | 读 `.github/workflows/*.yml` 或 `.gitlab-ci.yml`，列任务与 artifacts 线索 |
| `ci_list_runs` | 列最近运行，用于选 `run_id` |
| `ci_run_info` | 运行结论、任务/步骤、失败日志摘要、下一步建议 |
| `ci_wait` | **立即返回** watcher_id；后台轮询，成功后自动下载+同步 |
| `ci_wait_status` | 查 watcher 状态；完成后带下载/同步结果与下一步建议 |
| `ci_download_artifacts` | 下载并解压到 `LosAngelousDocs/ci/<平台>/<owner>-<repo>/<run-id>/` |
| `ci_sync_artifacts` | 把关键文件同步到 `LosAngelousDocs/reports/ci/<run-id>/` |

## 非阻塞流程（推荐）

```text
repo_info             # 1. 确认平台与仓库
ci_run_info           # 2. CI 还在跑？看 next_steps
ci_wait               # 3. 立即返回，不阻塞；继续干别的活
...继续其它任务...
ci_wait_status        # 4. 回来查：phase=success/failed/timeout，含下载与同步结果
```

`ci_wait` 的 watcher 是独立进程，状态写在 `LosAngelousDocs/ci/_state/wait-<id>.json`，
主会话不需要等待。CI 成功后自动下载 artifacts 并按 `default_sync` 同步。

## 安装 / 启用

1. 仓库根已有 `.mcp.json` 注册本服务器；**重启 Claude Code** 后生效（首次会请求项目 MCP 授权）。
2. 设置 token（只从环境变量读，不写入仓库）：

```bash
export GITHUB_TOKEN=...    # 需 actions:read；私有仓库还需 repo 读权限
export GITLAB_TOKEN=...    # 需 read_api（读取 pipeline/job artifacts）
```

3. 自检（离线，不需要 token）：

```bash
bash ./mcp/ci-artifacts/selftest.sh
```

Windows 若没有 `bash`，把 `.mcp.json` 改为：

```json
{ "command": "py", "args": ["-3", "mcp/ci-artifacts/server.py"] }
```

本机 `python3` 可能是 Microsoft Store 的坏 shim；`run.sh` 会先探测，再退回 `py -3`。

## 配置

优先级：`CI_ARTIFACTS_CONFIG` 环境变量 → 项目根 `.ci-artifacts.json` → 本目录 `config.json` → 内置默认。
`config.json` 已 gitignore；需要全局改默认值时复制 `config.example.json`。

项目级 `.ci-artifacts.json` 示例：

```json
{
  "platform": "gitlab",
  "remote": "origin",
  "default_ref": "develop",
  "default_sync": [
    { "include": "**/*.md" },
    { "include": "**/summary.json" }
  ],
  "sync_root": "LosAngelousDocs/reports/ci"
}
```

- `platform`：自建 GitLab 域名不含 `gitlab` 时手动指定（`github` / `gitlab`）。
- `remote`：非 `origin` 时指定。
- `sync_root` 支持 `{run_id}` 占位符。

## 安全边界

- 下载物只解压/复制，**绝不执行、不 import**。
- 解压拒绝绝对路径、`..` 穿越、符号链接，并有解压总大小上限（默认 2 GiB）。
- 同步目标必须落在项目根内，`to=../../x` 会被拒绝。
- token 只进请求头；跨主机重定向（如 GitHub → S3）时自动丢弃凭证。
- 错误信息不回显 token。

## 手动 / 排障

```bash
py -3 -E -s mcp/ci-artifacts/core.py detect
py -3 -E -s mcp/ci-artifacts/core.py workflow
py -3 -E -s mcp/ci-artifacts/core.py status --ref main
py -3 -E -s mcp/ci-artifacts/core.py wait --ref main --interval 15 --timeout 1800
py -3 -E -s mcp/ci-artifacts/core.py wait-status --watcher-id <id>
```

已知限制：Gitee 仅识别未实现；GitLab artifacts 依赖 job 返回 `artifacts_file` 元数据；
CI 配置摘要为轻量文本解析，不是完整 YAML 解析。
