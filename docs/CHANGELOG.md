# CHANGELOG

> 面向使用者的变更记录。格式：`## [未发布]` + 新增 / 变更 / 修复 / 移除。

## [未发布]

### 新增

- `scripts/selftest.sh` 与 CI `Run script selftest` 步骤（CR-002）
- `docs/` 四角色工作流文档、`PROJECT_BRAIN.md`、`review-index.md`（CR-001 / CR-002）

### 修复

- 能力索引：空查询崩溃、否定边界误匹配、缓存忽略 roots（CR-001）
- `finish-report`：带后缀标题回填静默失败、WORKLOG 重复（CR-002）
- 无 `python3` 时报告链接可能为绝对路径（CR-002）

### 变更

- 各脚本 `-h` 改为注释块提取，不再依赖固定行号（CR-002）
- `worklog --time` 统一为 `LOG-YYYYMMDD-HHMMSS`（CR-002）
