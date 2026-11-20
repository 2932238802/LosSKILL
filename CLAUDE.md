# CLAUDE.md

@AGENTS.md

## Claude Code 专属

- 项目 Skill 默认同步到 `~/.claude/skills`；用 `scripts/sync-skills.sh`，不要手工复制。
- 四个子代理由 `scripts/install-claude-config.sh` 从 `skills/dev-workflow/references/` 生成，不要手工维护副本。
- 本机配置备份在 `configs/claude/`；修改后跑 `./scripts/install-claude-config.sh --dry-run` 再部署。
