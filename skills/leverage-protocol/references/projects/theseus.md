# Theseus 项目适配

- 最后验证：2026-11-19（命令来源：README / `.github/workflows/ci.yml`；本次未执行完整构建，首次使用前先跑一遍）
- 栈：Rust（edition 2024，axum 0.8、sqlx 0.8、tokio、PostgreSQL、Redis）+ Vue 3 + TypeScript + Vite；Docker 判题运行镜像
- 入口：`backend-rust/`（API / Worker / anticheat / lsp）、`frontend-vue/`、`deploy/`

## 验证命令

| 改动 | 命令 | 最后验证 |
|---|---|---|
| 后端格式 | `cd backend-rust && cargo fmt --all --check` | 2026-11-19（未执行） |
| 后端静态检查 | `cd backend-rust && cargo clippy --all-targets -- -D warnings` | 2026-11-19（未执行） |
| 后端测试 | `cd backend-rust && cargo test --all-targets` | 2026-11-19（未执行） |
| 前端构建（含类型检查） | `cd frontend-vue && npm ci && npm run build` | 2026-11-19（未执行） |
| 本地全栈 | `./dev.sh` | 2026-11-19（未执行） |
| 完整 CI 等价 | 上述后端三条 + 前端 `npm ci && npm run build` | 2026-11-19（未执行） |
| 部署更新 | `./update.sh`（备份 → 迁移 → 配图补丁 → 面经导入 → 健康检查） | 2026-11-19（未执行） |
| 服务启动（部署目录） | `cd deploy && docker compose up -d` | 2026-11-19（未执行） |
| 冒烟脚本 | `backend-rust/scripts/smoke_*.sh`（auth/forum/submission/contest/realtime…） | 2026-11-19（未执行） |
| 依赖审计 | `cd backend-rust && cargo audit --ignore RUSTSEC-2023-0071` | 2026-11-19（未执行） |

> 规则：超过 90 天未复验的命令标"可能过期"；命令改名/删除时必须同步本文件。

## 项目专属信号

| 用户会说 | 实际涉及 |
|---|---|
| 判题 / 运行镜像 / 沙箱 | `backend-rust` Worker、Docker 运行镜像、`update.sh --skip-runners` |
| 题面 / 配图 / 题目导入 | `backend-rust/scripts/patch_problem_images.sql`、`doc/interview` 面经 |
| 提交 / 比赛 / 排行榜 | submission、contest、realtime 推送；注意 Redis 与广播 |
| 站内信 / 实时推送 | WebSocket/单例连接、进程内广播、票票据鉴权 |
| 论坛 / 面经 | forum、`import_interview.sh` |
| 权限 / 角色 | 认证授权、审计日志、`smoke_audit.sh` |
| 迁移 / 升级 | `backend-rust/migrations`、`update.sh`、`deploy/.env` |
| 设置 / 偏好 | 设置中心与偏好同步 |

## 雷区

- **迁移不要手工跳步**：`update.sh` 会先备份、用新 backend 应用增量迁移，再跑配图补丁与面经导入；直接 `sqlx migrate` 可能漏掉后置步骤。
- **`deploy/.env` 不会被脚本覆盖**：新增配置项先 `deploy/scripts/merge_env.sh --dry-run` 查看缺失项，确认后再追加。
- **前端没有测试框架**：`npm run build` 同时做 `vue-tsc` 类型检查；前端改动的验证底线就是它 + 手工检查。
- **Worker 需要 `/var/run/docker.sock`**：无 docker 组权限时 `dev.sh` 可能用 sudo；不要假设 CI 与本机行为一致。
- **题面配图是只读挂载**：`git pull` 后图片即时生效，不需要重建镜像。
- **CI 忽略 `RUSTSEC-2023-0071`**：这是已知项，不要因此认为审计全绿；新增依赖仍需看告警。
- **Rust edition 2024**：依赖版本（axum 0.8 / sqlx 0.8 / tokio 1）与旧示例可能不兼容，抄代码前先看本仓库用法。
- **日志在 `.dev-logs/`**：排障先看 `api.log` / `worker.log` / `anticheat.log` / `lsp.log` / `frontend.log`。

## 不要做

- 未经用户确认执行 `update.sh`（会改数据库、重启服务）。
- 直接改已应用的迁移文件；新增迁移。
- 把 `deploy/.env`、密钥、内网地址写进文档或提交。
- 在未跑后端测试的情况下声称"后端没问题"。
