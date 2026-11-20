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
- 不提交本地产物：`books/`、`dist/`、`scripts/vesta-e2e/`、`*.lnk`、`*.pyc`、`*.losskill.bak`（`.gitignore` 已覆盖）。
- 不提交密钥、token、真实邮箱或私钥；身份信息用环境变量。
- 保护所有 `LOS:` 手动注释：不修改、不删除、不移动；必须改动时先说明位置与原因。
- 角色提示词只有一份正文：`skills/dev-workflow/references/01–04-*.md`；`prompts/` 与 `~/.claude/agents/` 都从它同步或生成。

## 提交与分支

- 小改直接在 `main` 提交；跨多个模块或需要评审的改动开 `feat/<主题>` 分支。
- 提交信息用 `feat(scope):` / `fix(scope):` / `chore(scope):` / `docs:`，正文用中文，写清「改了什么 + 为什么」。
- 每个提交结尾保留：`Co-Authored-By: Claude Code <noreply@anthropic.com>`。
- 不主动 push；用户明确要求才推送。

## 常用命令

```bash
./scripts/validate.sh                         # Skill 自检（0 ERROR 才交付）
./scripts/new-skill.sh my-skill --desc "……"   # 新建 Skill + 索引登记
./scripts/install-git-hooks.sh                # 启用 pre-commit 自检
./scripts/sync-skills.sh --dry-run            # 预览同步
./scripts/sync-skills.sh --link --force       # 软链接到 ~/.claude/skills
./scripts/sync-skills.sh --copy --force       # 覆盖复制
./scripts/install-claude-config.sh --dry-run  # 预览 Claude 配置部署
```

## 指针

- Skill 索引与触发边界：`SKILLS.md`
- Skill 写作规范：`_template/GUIDE.md`
- 四角色开发流程：`skills/dev-workflow/SKILL.md`
- 满力协议与项目适配：`skills/leverage-protocol/SKILL.md`
