# 授权台账

## 范围信封

```yaml
policy: POLICY-CR-001
granted_by: user
granted_at: 2026-11-20
expires: 2026-11-27
branch: main
allowed_paths:
  - skills/leverage-protocol/scripts/
  - docs/
allowed_commands:
  - ./scripts/validate.sh
  - python3 skills/leverage-protocol/scripts/capability_index.py ...
  - bash -n scripts/*.sh setup.sh
  - git status
  - git diff
  - git add
  - git commit
max_commits: 3
delegate_a2_to_review: false
forbidden:
  - push
  - deploy/
  - .env
  - books/
  - dist/
  - scripts/vesta-e2e/
escalate_when:
  - 新增依赖
  - 修改鉴权/权限
  - 改动数据模型
  - 跨模块
```

## 策略变更记录

- 2026-11-20：用户批准 CR-001 范围信封（G1）。

## AUTH 记录

<!-- auth:rows -->

## AUTH-20261120-001

- 时间：2026-11-20 13:50:13 +0800
- CR/T：CR-001 / T-001
- 动作：批准 T-001 的 cmd_query 空结果修复
- 级别：A1
- 策略条款：POLICY-CR-001（allowed_paths、max_commits）
- 证据：AC 命令与输出 + validate.sh + scope diff
- 批准：review-agent
- 范围：skills/leverage-protocol/scripts/capability_index.py（commit 待生成）
- 有效期：随 CR 结束
- 撤销：否
- 幂等键：CR-001:T-001:批准空查询修复:A1

