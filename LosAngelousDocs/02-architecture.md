# 02 — 架构

> 维护者：Doc Agent ｜ 最近更新：2026-11-20 ｜ 状态：已确认（G1 2026-11-20；CR-001 G4 通过）

## 系统上下文

```
用户 / AI
  │  query / plan
  ▼
capability_index.py ──读──▶ skills/*/SKILL.md + references/*
  │                         │
  └──读写──▶ ~/.cache/capability-index/index.json
```

## 模块表

| 模块 / 函数 | 职责 | 边界（不负责） |
|---|---|---|
| `parse_frontmatter` | 解析 `SKILL.md` frontmatter 与正文 | 不校验 Skill 规范 |
| `discover_skill_files` | 遍历 roots，找 `SKILL.md` | 不解析内容 |
| `build_index` | 组装 name / description / tokens / 路径 | 不评分 |
| `tokenize` | 中英文分词、停用词过滤 | 不判断正负语义 |
| `score` | 覆盖率 + Jaccard + 命中量打分 | 不排序全局 |
| `cmd_query` / `cmd_plan` | 输出候选与计划 | 不执行 Skill |
| `stale` / `load_or_build` | 缓存复用与重建 | 不修正 roots 输入 |
| `scripts/validate.sh` | Skill 规范自检 | 不跑能力索引测试 |
| `scripts/selftest.sh` | 脚本文本回归（回填/幂等/时间/usage/relpath） | 不做端到端/网络测试 |
| `.github/workflows/validate.yml` | CI：validate + selftest | 不负责发布 |

## 关键数据流

1. `default_roots()` 或 `--roots` 得到 roots。
2. `discover_skill_files` 找到所有 `SKILL.md`。
3. `parse_frontmatter` 取出 name / description；`extra_text` 读取能力卡与 cheatsheet。
4. `tokenize` 生成 token 集合，写入 `index.json`。
5. `cmd_query` / `cmd_plan` 用 IDF 与 `score` 排序，输出候选。
6. 下一次运行 `load_or_build` 判断缓存是否过期。

## 外部依赖

| 依赖 | 用途 | 失败模式 | 处理 |
|---|---|---|---|
| Python 3 标准库 | 全部逻辑 | 版本过低可能语法不兼容 | 脚本无第三方包 |
| 本地文件系统 | 读 Skill、写缓存 | 权限/路径不存在 | 跳过不可读文件；roots 不存在时忽略 |
| 网络 | 无 | — | 脚本明确不联网 |

## 技术选型（现状）

- Python 标准库 + Bash；无第三方依赖。
- 缓存默认 `~/.cache/capability-index/index.json`，可用 `CAPABILITY_INDEX_OUT` / `CAPABILITY_INDEX_ROOTS` 覆盖。
- 选择理由：仓库自检与同步脚本已统一用 Bash/Python，避免引入运行时。
