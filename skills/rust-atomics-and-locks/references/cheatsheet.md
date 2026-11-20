# 决策规则速查 — Rust Atomics and Locks: Low-Level Concurrency in Practice

| 能力 | 一句话规则 |
|---|---|
| 原子操作与内存序选型 | 先问需不需要跨线程顺序，再用 Release/Acquire 建立配对；只在确需全局序时用 SeqCst。 |
| 并发与 unsafe 代码安全审查 | 按访问表 → HB → 同步原语 → 不变量 → 活性/性能的顺序审查，并标明问题类别。 |
| 安全并发 API 设计 | 先列误用，再按 unsafe→运行时检查→类型级逐档升级，只把不可静态排除的条件留给 unsafe。 |
| 自旋锁与守卫实现 | AtomicBool + UnsafeCell + guard：Acquire 加锁、Release 解锁、Drop 自动释放。 |
| Arc / Weak 引用计数实现 | clone 用 Relaxed，最后 drop 用 Release + Acquire fence；Weak 用双计数器，get_mut 必须排除 Weak。 |
| 阻塞锁实现：Mutex / Condvar / RwLock | 三态状态机 + futex 风格 wait/wake：快路径零系统调用，解锁仅在有等待者时唤醒。 |
| 一次性通道实现 | MaybeUninit + 状态原子；用消费 self 的 Sender/Receiver 把重复调用变成编译错误。 |
| 原子代码性能诊断与可移植性 | 先用正确性排除 UB，再查伪共享/系统调用，并在目标硬件与弱序架构上验证。 |
| 操作系统并发原语选型 | 按平台选最小可移动原语：Linux futex、Windows WaitOnAddress/SRWLOCK、macOS os_unfair_lock/libc++ wait。 |

> 速查只给结论；需要原文依据、案例或反例时读对应能力卡。
