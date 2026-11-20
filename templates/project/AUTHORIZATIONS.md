# 授权台账 — {{PROJECT_NAME}}

> 协议见 `dev-workflow` 的 `references/06-authorization.md`。
> 用户在 G1 批准一次「范围信封」；A1 由 Review 记账，A2 由 Steward 记账，A3 只由用户确认。
> 本文件 append-only：不要删除或改写旧条目。

## 当前策略

```yaml
policy: CR-xxx
granted_by: user
granted_at: {{DATE}}
expires: 待填写
branch: 待填写
allowed_paths:
  - 待填写
allowed_commands:
  - 待填写
max_commits: 待填写
delegate_a2_to_review: false
forbidden:
  - deploy/
  - .env
escalate_when:
  - 新增依赖
  - 修改鉴权/权限
  - 改动数据模型
```

## 策略变更记录

| 时间 | 变更 | 批准人 |
|---|---|---|
| | | |

## 授权记录

<!-- 每次 A1/A2 追加一条，格式见协议第 4 节 -->
