# LosAngelousDocs/ci — CI 产物落地目录

由 `mcp/ci-artifacts` 维护。**该 MCP 只写这里（以及 `LosAngelousDocs/reports/ci/`），不碰其它目录。**

> 目录名固定用 `LosAngelousDocs/`，不使用 `docs/`，避免与项目自带的 `docs/` 重名。

## 目录契约

```text
LosAngelousDocs/
  ci/
    <platform>/                 # github | gitlab
      <owner>-<repo>/
        <run-id>/
          zips/                 # 原始压缩包（不入库）
          artifacts/            # 解压内容（不入库）
          run.json              # 本次下载清单（仓库信息 / 运行 / 文件数）
          sync.json             # 同步清单（来源 → 目标）
    _state/
      wait-<watcher-id>.json    # ci_wait 的非阻塞状态（不入库）

  reports/
    ci/<run-id>/                # 同步出的关键文件（默认 *.md / *.json / *.html，入库）
      _sync-manifest.json
```

`<owner>-<repo>` 中的 `/` 会被替换成 `-`（如 GitLab 嵌套组 `group/sub` → `group-sub`）。
`run-id` 会做白名单校验，非法 id（如 `../x`）直接拒绝。

## 什么不入库

`.gitignore` 已覆盖：

- `LosAngelousDocs/ci/_state/`
- `LosAngelousDocs/ci/**/zips/`
- `LosAngelousDocs/ci/**/artifacts/`
- `LosAngelousDocs/ci/**/*.zip`

`run.json` / `sync.json` / `LosAngelousDocs/reports/ci/` 的体积通常很小，默认入库，便于追溯。

## 清理

产物目录没有自动清理。确认不再需要后手动删除对应 `run-id` 目录即可，
删除前可用 `run.json` 核对来源仓库与运行号。
