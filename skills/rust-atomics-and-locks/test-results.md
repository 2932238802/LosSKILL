# 阶段 4 测试结果 (rust-atomics-and-locks)

测试对象：Capability Bundle 的 9 个 active 能力（6 promoted + 3 router）。
测试方式：
- **触发精度**：独立 sub-agent 盲测（只给 9 个 name+description 与用户 prompt，不给预期答案）。
- **实际输出**：独立执行者只读能力卡与任务，不看断言；产出写入 `/tmp/ratl-eval/<case>/answer.md`，由主流程核对。

## 一、触发精度（盲测）

首轮 20 条（`eval-suite.json`）：18/20 一致。
两处偏差与处理：

| case | prompt 摘要 | 预期 | 首轮结果 | 处理 |
|---|---|---|---|---|
| t14 | Linux 上用 futex 实现等待/唤醒 | os-primitive-selection | build-blocking-locks | 收紧两卡 description：os-primitive 明确"直接问 futex 怎么用"；build-blocking 排除"直接讲解 syscall 签名与语义" |
| t19 | Ordering::Acquire 是什么意思 | none（纯名词解释） | atomic-ops-and-ordering | atomic-ops description 增加"不用于纯概念/名词解释" |

修订后**新开独立 sub-agent 复测**（未参与首轮）：
- a（原 t14）→ `os-primitive-selection` ✓
- b（原 t19）→ `none` ✓

**最终触发结果：20/20。**
跨 skill 混淆测试：t12/t13/t14 分别正确路由到 spinlock / one-shot-channel / os-primitive；
t03 vs t07（审查已有 Arc vs 实现 Arc）正确分开；t08 vs t14（实现锁 vs 直接用 futex）修订后分开。
诱饵（t15–t18）全部 none。

## 二、实际输出评测

代表任务（promoted 与 router 均覆盖正常 + 边界）：

| case | 能力 | 类型 | 任务 | 结果 |
|---|---|---|---|---|
| E1 | atomic-ops-and-ordering | 正常 | 多字段 Config 发布 + 计数器，选 Ordering 并证明 HB | 见下 |
| E2 | atomic-ops-and-ordering | 边界 | "全 SeqCst 能否全改 Relaxed" | 见下 |
| E3 | build-blocking-locks | 正常 | 三态 Mutex 核心 + 零 syscall 快路径 | 见下 |
| E4 | build-blocking-locks | 边界 | RwLock 写者饥饿修复 | 见下 |
| E5 | atomic-performance-and-portability | 正常 | 相邻原子变量慢 10 倍的诊断与修复 | 见下 |
| E6 | atomic-performance-and-portability | 边界 | x86 正常/M1 异常，无目标硬件 | 见下 |
| E7 | build-arc-weak | 正常 | 简化 Arc 的 clone/drop 顺序与溢出 | 见下 |
| E8 | build-arc-weak | 边界 | 带 Weak 的 get_mut 检查与竞态 | 见下 |

> 输出评测结果与断言核对记录补充于本节末尾（执行完成后填写）。

### 输出核对结果

| case | 核对点 | 结果 |
|---|---|---|
| E1 | READY 用 Release/Acquire、计数用 Relaxed；给出完整 sequenced-before → synchronizes-with → HB 链；说明"发布后不可再写"的残余风险 | 通过 |
| E2 | 拒绝"全改 Relaxed"与"全 SeqCst"；给出逐操作判定与降级对照表；正确保留 Dekker 类 SeqCst；给出 loom/Miri/弱序验证 | 通过 |
| E3 | 0/1/2 三态；快路径一次 CAS；仅前值 2 才 wake；论证 wait/wake 不承担内存安全；给出不漏唤醒的三种时序 | 通过（`Send` 手写实现略冗余，不影响正确性） |
| E4 | 改为"读者数×2 + 等待位"；读/写/释放四处改动；保留值冲突与读者上限说明；有界等待论证与代价 | 通过 |
| E5 | 判定伪共享；align(64)/128；black_box 与 perf c2c；明确拒绝固定加速比 | 通过 |
| E6 | 主假设为 lock/unlock 缺 Acquire/Release；给出静态检查、汇编、loom、ARM runner 方案；明确无 M1 不能确认根因、不编造数据 | 通过 |
| E7 | clone=Relaxed；末次 fetch_sub(Release)+fence(Acquire)；usize::MAX/2 abort；release sequence 与 AcqRel 取舍解释 | 通过 |
| E8 | 必须同时检查强计数与无 Weak；解释两计数器分别检查的竞态；usize::MAX 锁位与 downgrade 哨兵；内存序表 | 通过 |

**实际输出评测：8/8 通过。**
未做 old_skill / without_skill 对照（首次蒸馏无旧版；本次为单版本验证），故不宣称相对基线的提升，只声明"在给定能力卡下可完成任务且无已知错误"。

### 已知限制
- E3/E7/E8 的代码未在本机编译运行；核对为语义与顺序审查，不是可执行测试结果。
- E6 无 ARM64 硬件，验证方案未实际执行。
- 这些限制已写入 `needs-review.md`，不把静态核对当作实测。
