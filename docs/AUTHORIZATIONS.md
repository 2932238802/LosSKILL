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

## 范围信封（CR-002）

```yaml
policy: POLICY-CR-002
granted_by: user
granted_at: 2026-11-20
expires: 2026-11-27
branch: main
allowed_paths:
  - scripts/
  - .github/workflows/
  - docs/
allowed_commands:
  - ./scripts/validate.sh
  - ./scripts/selftest.sh
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

- 2026-11-20：用户批准 CR-002 范围信封（G1）。

## AUTH 记录

<!-- auth:rows -->

## AUTH-20261120-004

- 时间：2026-11-20 15:13:15 +0800
- CR/T：CR-002 / T-004
- 动作：批准 T-004 的回填与幂等（返工后）
- 级别：A1
- 策略条款：POLICY-CR-002（allowed_paths、max_commits）
- 证据：AC-004-1～4 + R-1/R-2 + 回归 + validate.sh + scope diff
- 批准：review-agent
- 范围：scripts/finish-report.sh、scripts/worklog.sh（commit 待生成）
- 有效期：随 CR 结束
- 撤销：否
- 幂等键：CR-002:T-004:批准回填与幂等:A1


## AUTH-20261120-003

- 时间：2026-11-20 14:39:12 +0800
- CR/T：CR-001 / T-003
- 动作：批准 T-003 的 roots 缓存感知
- 级别：A1
- 策略条款：POLICY-CR-001（allowed_paths、max_commits）
- 证据：AC-003-1～3 + 回归 + validate.sh + scope diff
- 批准：review-agent
- 范围：skills/leverage-protocol/scripts/capability_index.py（commit 待生成）
- 有效期：随 CR 结束
- 撤销：否
- 幂等键：CR-001:T-003:批准 roots 缓存感知:A1


## AUTH-20261120-002

- 时间：2026-11-20 14:01:37 +0800
- CR/T：CR-001 / T-002
- 动作：批准 T-002 的否定边界剥离
- 级别：A1
- 策略条款：POLICY-CR-001（allowed_paths、max_commits）
- 证据：AC-002-1～4 + 回归 + validate.sh + scope diff
- 批准：review-agent
- 范围：skills/leverage-protocol/scripts/capability_index.py（commit 待生成）
- 有效期：随 CR 结束
- 撤销：否
- 幂等键：CR-001:T-002:批准否定从句剥离:A1


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

