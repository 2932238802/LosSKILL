---
name: rust-atomics-and-locks
description: |
  基于 Mara Bos《Rust Atomics and Locks》的并发能力包：选择原子操作与内存序、审查并发/unsafe 代码、 设计安全并发 API、实现 Arc/Weak 与阻塞锁、诊断原子代码性能与跨架构可移植性。只覆盖线程 + 共享内存 + 原生平台；不涉及 async/await、分布式或跨进程一致性。
metadata:
  cangjie.generated-by: cangjie-tools v2.5.0
  cangjie.variant: single
  cangjie.bundle-id: bundle.rust-atomics-and-locks
  cangjie.capability-count: 9
  cangjie.entrypoint-count: 1
---
# Rust Atomics and Locks: Low-Level Concurrency in Practice — 全书能力入口

## 触发与不触发

**适用**：与本书能力域相关的咨询与任务（见下方路由表的意图列）。
**不适用**：
- async/await、异步运行时与 loom 模型检查。
- 分布式系统、跨进程一致性与网络并发。
- 其他语言（C/C++/Go 等）的并发原语实现。
- 完整无锁数据结构与 RCU 的生产级实现（第 10 章仅作参考）。

## 核心原则（常驻速览，概览类问题读到这里即可回答）

1. 先问"需不需要跨线程顺序"，再选最弱且仍正确的内存序；SeqCst 是警报而非默认。
2. 数据竞争是未定义行为；用 happens-before 证明并发访问不重叠，而不是靠"看起来有顺序"。
3. 把能静态排除的误用交给类型系统（guard、消费 self、PhantomData、split borrow），unsafe 只留最小核心。
4. 能用 std 或成熟 crate 就不要自造并发原语；本书能力主要用于理解、审查与特殊场景。
5. 性能由缓存一致性与系统调用决定；任何加速结论都必须在目标硬件上实测。
6. wait/wake 不承担内存安全，只避免忙等；锁的正确性来自状态机与内存序。

## 能力路由（先读本表，按意图加载 1 张能力卡）

| 用户意图 | 先读 | 补读/备注 |
|---|---|---|
| 为共享状态选择原子操作与内存序；判断 Relaxed 是否足够；证明一段并发代码的 happens-before；选择 fence 的位置与类型；处理原子计数溢出与 ABA | references/capabilities/atomic-ops-and-ordering.md | references/capabilities/concurrency-safety-review.md、references/capabilities/atomic-performance-and-portability.md、references/capabilities/build-arc-weak.md |
| 审查并发或 unsafe Rust 是否有 UB；排查偶发崩溃、死锁、丢唤醒；检查 Send/Sync 与 guard 生命周期；判断 SeqCst/compiler_fence 是否误用；区分 UB 与性能/公平性问题 | references/capabilities/concurrency-safety-review.md | references/capabilities/atomic-ops-and-ordering.md、references/capabilities/safe-concurrency-api-design.md、references/capabilities/build-blocking-locks.md |
| 设计难以误用的并发 API；决定用 guard、消费 self、PhantomData 还是运行时检查；正确实现 Send/Sync 与 Deref 语义；缩减 unsafe 面积 | references/capabilities/safe-concurrency-api-design.md | references/capabilities/build-spinlock-guard.md、references/capabilities/build-one-shot-channel.md、references/capabilities/concurrency-safety-review.md |
| 实现一个最小自旋锁；理解 guard 与 Deref/Drop 解锁；把裸 AtomicBool 锁封装成安全类型 | references/capabilities/build-spinlock-guard.md | references/capabilities/safe-concurrency-api-design.md、references/capabilities/build-blocking-locks.md |
| 实现或理解 Arc/Weak；解释引用计数的内存序；用 Weak 打破循环引用；实现唯一所有者修改（get_mut） | references/capabilities/build-arc-weak.md | references/capabilities/atomic-ops-and-ordering.md、references/capabilities/concurrency-safety-review.md |
| 实现可阻塞的 Mutex/Condvar/RwLock；解释或优化锁的系统调用；解决写者饥饿/写者忙等/丢唤醒；理解 futex 风格 wait/wake 协议 | references/capabilities/build-blocking-locks.md | references/capabilities/os-primitive-selection.md、references/capabilities/build-spinlock-guard.md、references/capabilities/concurrency-safety-review.md |
| 实现一次性通道；用类型状态防止重复 send/receive；实现无分配的 split-borrow 通道；处理未接收消息的析构 | references/capabilities/build-one-shot-channel.md | references/capabilities/safe-concurrency-api-design.md、references/capabilities/build-spinlock-guard.md |
| 诊断原子/并发代码变慢；排查伪共享与 cache line 对齐；写可信的原子操作基准；验证 x86→ARM 的内存序可移植性 | references/capabilities/atomic-performance-and-portability.md | references/capabilities/atomic-ops-and-ordering.md、references/capabilities/concurrency-safety-review.md、references/capabilities/build-blocking-locks.md |
| 选择跨平台等待/唤醒原语；包装 pthread/Windows 原语时的移动与销毁问题；需要优先级继承或跨进程同步 | references/capabilities/os-primitive-selection.md | references/capabilities/build-blocking-locks.md、references/capabilities/concurrency-safety-review.md |

**非能力类查询**：
- 书名/作者/章节/整书概览 → references/overview.md
- 术语解释 → references/glossary.md
- 决策规则速查（不需要原文依据时） → references/cheatsheet.md
- 完整意图与关键词索引（本表未覆盖的意图先查这里） → references/capability-index.md

## 加载规则

- 每次任务先读本文件，再按路由表加载 **1** 张能力卡；任务明确跨域时最多加载 2 张。
- 概览/书名类问题不加载能力卡，用「核心原则」与 overview.md 回答。
- 路由表与 capability-index.md 都无法命中的意图，明确告知超出本书范围，不要硬套。

## 边界与判停

- 缺少代码、线程访问序列或平台信息时，先追问，不凭变量名猜测。
- 用户只是需要生产级锁/通道/Arc 时，优先建议 std 或成熟 crate，不引导自造。
- 发现无法在不改变语义的前提下修复的 UB 时，报告问题与证据，不擅自重写。
