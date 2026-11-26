# AGENTS.md — LosSKILL 常驻工作规则

## 工程任务：按 leverage-protocol 执行

**先分级**：S 小改（单文件/无接口变更）→ 读相关文件 → 改 → 跑最近验证。
M 功能（跨文件/新接口）→ 先写 1 页方案与验收 → 实现 → 正常+边界验证。
L 重活（跨模块/数据/权限/发布）→ 先出 2–3 方案与回滚 → 确认 → 分步实现。
不确定按 M；涉及跨模块、数据迁移、权限/安全、发布，自动升 L。

**交付前必须回答**（答不出就标"未验证草稿"，不许说"应该可以"）：
1. 验证命令跑了吗？结果是什么？
2. 结论引用证据了吗？（文件:行 / 日志 / 测试名）
3. 改动涉及的文件读全了吗？没读的说明原因。

**协议全文与项目命令**：加载 `leverage-protocol` Skill；项目专属见其 `references/projects/`。

## 本项目是什么

个人开发环境备份 + AI Skill 收藏库。`skills/` 下的内容首先是给 AI 读的触发器与操作指令，不是给人看的教程。

## 改动规则

- 交付前跑 `./scripts/validate.sh`，要求 0 ERROR；WARN 需要说明原因。
- 新增或改名 Skill：复制 `_template/`，目录名与 frontmatter `name` 一致（kebab-case），description 必须含「不用于 / 不适用 / 不涉及」边界，并在 `SKILLS.md` 登记。
- 目标项目的文档根目录默认 `LosAngelousDocs/`，不使用 `docs/`；先 `init-docs.sh` 铺骨架，G1 前用 `check-docs.sh --gate g1` 校验，未登记路径不得创建。
- 不提交本地产物：`books/`、`dist/`、`scripts/vesta-e2e/`、`*.lnk`、`*.pyc`、`*.losskill.bak`（`.gitignore` 已覆盖）。
- 不提交密钥、token、真实邮箱或私钥；身份信息用环境变量。
- 保护所有 `LOS:` 手动注释：不修改、不删除、不移动；必须改动时先说明位置与原因。
- 角色提示词只有一份正文：共享约定在 `skills/dev-workflow/references/_shared-conventions.md`，四份角色文件由 `scripts/render-dev-workflow.sh` 渲染；`prompts/` 由同一脚本同步，`~/.claude/agents/` 由 `install-claude-config.sh` 生成。不要手工改 01–04 标记内的共享块。

## 提交与分支

- **单分支开发**：一律在 `main` 提交；**不新建** `feat/`、`fix/`、`chore/` 等长期分支（只有一个人开发，分支只增加合并成本）。
- 需要隔离试验时用未提交工作区或 `git stash`，不要留在仓库里；误建的分支在合入 `main` 后立即删除。
- 提交信息用 `feat(scope):` / `fix(scope):` / `chore(scope):` / `docs:`，正文用中文，写清「改了什么 + 为什么」。
- 每个提交结尾保留：`Co-Authored-By: Claude Code <noreply@anthropic.com>`。
- 不主动 push；用户明确要求才推送。远端也只保留 `main`，旧的 feature 分支在确认已合入后删除。

## 常用命令

```bash
./scripts/validate.sh                         # Skill 自检（0 ERROR 才交付）
./scripts/new-skill.sh my-skill --desc "……"   # 新建 Skill + 索引登记
./scripts/install-git-hooks.sh                # 启用 pre-commit 自检
./scripts/bootstrap-project.sh <项目路径>      # 接入 AGENTS/CLAUDE + L2 项目卡
./scripts/bootstrap-project.sh <项目路径> --docs LosAngelousDocs --init-docs  # 接入并铺文档树骨架
./scripts/init-docs.sh <项目>/LosAngelousDocs # 只初始化文档树骨架（非破坏）
./scripts/check-docs.sh <项目>/LosAngelousDocs --gate g1  # 文档树 + G1 门禁检查（g1–g4、g2.5/g3.5）
./scripts/workflow-status.sh <项目>/LosAngelousDocs --project-root <项目> --check  # 当前门禁与下一步
./scripts/finish-report.sh --report <报告> --project-root <项目>  # 解析报告头，写 WORKLOG + AUTH(A1c/A2)；--backfill 回填 commit
./scripts/render-dev-workflow.sh --check       # 校验共享块渲染与 prompts 副本
./scripts/sync-skills.sh --dry-run            # 预览同步
./scripts/sync-skills.sh --link --force       # 软链接到 ~/.claude/skills
./scripts/sync-skills.sh --copy --force       # 覆盖复制
./scripts/install-claude-config.sh --dry-run  # 预览 Claude 配置部署
./scripts/install-vscode-config.sh --dry-run  # 预览 VS Code 配置部署
bash ./mcp/ci-artifacts/selftest.sh           # CI artifacts MCP 自检（离线）
```

## 指针

- Skill 索引与触发边界：`SKILLS.md`
- Skill 写作规范：`_template/GUIDE.md`
- 四角色开发流程：`skills/dev-workflow/SKILL.md`
- 满力协议与项目适配：`skills/leverage-protocol/SKILL.md`
- CI 产物 MCP（非阻塞下载/同步）：`mcp/ci-artifacts/README.md`、`LosAngelousDocs/ci/README.md`
