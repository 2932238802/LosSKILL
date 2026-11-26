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
  - LosAngelousDocs/
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
  - LosAngelousDocs/
  - setup.sh
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
- 2026-11-20：CR-002 信封扩展 `allowed_paths` 增加 `setup.sh`（T-005 P2 返工，用户批准）。

## 范围信封（CR-007）

```yaml
policy: POLICY-CR-007
granted_by: user
granted_at: 2026-11-26
expires: 2026-12-03
branch: main
allowed_paths:
  - LosAngelousDocs/
  - scripts/check-docs.sh
  - scripts/selftest.sh
allowed_commands:
  - ./scripts/validate.sh
  - ./scripts/check-docs.sh
  - ./scripts/render-dev-workflow.sh --check
  - ./scripts/finish-report.sh
  - git status
  - git diff
  - git add
  - git commit
max_commits: 1
max_parallel: 1
delegate_a2_to_review: false
forbidden:
  - .github/
  - push
  - deploy/
  - .env
escalate_when:
  - 修改 allowed_paths 以外的脚本
  - 修改 skills/
  - 跨模块
```

- 2026-11-26：用户批准 CR-007 范围信封（G1，retro 补记）。
- 2026-11-26：CR-007 信封扩展 `allowed_paths` 增加 `scripts/check-docs.sh`（G1 发现加粗字段不兼容，用户批准）。
- 2026-11-26：CR-007 信封扩展 `allowed_paths` 增加 `scripts/selftest.sh`（G4 返工要求补 `current_cr` 回归用例，用户批准）。

## AUTH 记录

<!-- auth:rows -->

## AUTH-20261126-001

- 时间：2026-11-26 17:48:57 +0800
- CR/T：CR-007 / T-008
- 动作：提交 CR-007 文档与 check-docs 加粗兼容修复
- 级别：A1c
- 策略条款：POLICY-CR-007
- 证据：validate 0 ERROR/0 WARN exit0；render-dev-workflow --check exit0；check-docs --gate g1 0 ERROR/3 legacy WARN exit0；加粗正则对 **G1 已确认**：是 等变体 MATCH、对「：否」不 MATCH；11 个非 red-tie-xhs SKILL.md 均含不用于/Not for；red-tie-xhs 无 C:\ / E:\；template.py:51-62 读 RED_TIE_FONT_DIR；git diff 范围全在 POLICY-CR-007 allowed_paths
- 批准：review-agent
- 范围：branch=main, commit=待生成
- 有效期：随 CR 结束
- 撤销：否
- 幂等键：CR-007:T-008:提交 docs:A1c
- 补充：G4 P1 返工（`current_cr` `\3`→`\2` + selftest 回归）已由 Review r2 复核通过，见 `reports/review-2026-11-26-T-008-r2.md`（2026-11-26）。


## AUTH-20261120-006

- 时间：2026-11-20 15:51:25 +0800
- CR/T：CR-002 / T-006
- 动作：批准 T-006 的 selftest 与 CI
- 级别：A1
- 策略条款：POLICY-CR-002（allowed_paths、max_commits）
- 证据：AC-008-1～5 + 回归 + validate.sh + scope diff
- 批准：review-agent
- 范围：scripts/selftest.sh、.github/workflows/validate.yml（commit 待生成）
- 有效期：随 CR 结束
- 撤销：否
- 幂等键：CR-002:T-006:批准 selftest 与 CI:A1


## AUTH-20261120-005

- 时间：2026-11-20 15:27:48 +0800
- CR/T：CR-002 / T-005
- 动作：批准 T-005 的脚本小修
- 级别：A1
- 策略条款：POLICY-CR-002（allowed_paths、max_commits）
- 证据：AC-005～007 + 回归 + validate.sh + scope diff
- 批准：review-agent
- 范围：scripts/worklog.sh、scripts/finish-report.sh、scripts/bootstrap-project.sh、scripts/new-skill.sh、scripts/sync-skills.sh（commit 待生成）
- 有效期：随 CR 结束
- 撤销：否
- 幂等键：CR-002:T-005:批准脚本小修:A1


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


## 更正记录

- 2026-11-20：AUTH-20261120-006 原记 A1；按 `06-authorization.md` §1.1，`.github/workflows/validate.yml` 属构建/CI 配置（A2）。Meta/Steward 在 G4 复核后追认 A2，授权链以 `LosAngelousDocs/reports/meta-2026-11-20-CR-002.md` 为准；不改旧条。
- 2026-11-20：AUTH-20261120-005 的 scope 未列 T-005 r2 新增的 4 个脚本；该 4 文件在 POLICY-CR-002 `allowed_paths` 内，由 r2 A1 结论与 G4 报告交叉覆盖；不改旧条。
