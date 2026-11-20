# 阻塞锁实现：Mutex / Condvar / RwLock

## R — 原文

> "/// 0: unlocked
> /// 1: locked, no other threads waiting
> /// 2: locked, other threads waiting"
> — Chapter 9, "Avoiding Syscalls"

> "To do this, we need to keep track of whether there are any waiting writers. To make space for this information in the state variable, we can multiply the reader count by 2, and add 1 for situations where there is a writer waiting."
> — Chapter 9, "Avoiding Writer Starvation"

中文翻译（自译）：

> 0：未锁；1：已锁且没有其他等待者；2：已锁且有等待者。
>
> 为此需要记录是否有等待的写者。为了在状态变量里腾出空间，可以把读者计数乘以 2，并在有写者等待时加 1。

## I — 自述

真正的锁必须在拿不到时**睡眠**，而睡眠需要内核；但快路径应完全留在用户态。这本书用 `wait(&AtomicU32, expected)` / `wake_one` / `wake_all` 这组 futex 风格原语实现：

**Mutex**
- 状态机：`0` 未锁、`1` 已锁无等待者、`2` 已锁有等待者。
- 加锁：先 `compare_exchange(0, 1, Acquire, Relaxed)`；失败则自旋约 100 次（只 `load`，避免 CAS 抢 cache line）；仍未拿到则循环 `swap(2, Acquire)` + `wait(state, 2)`。
- 解锁：`swap(0, Release)`；只有前值为 `2` 才 `wake_one`。
- 关键：wait/wake 不承担内存安全，只避免忙等；即使全部去掉，仍是正确的自旋锁。

**Condvar**
- 一个通知计数器 `counter`：每次 notify 递增，再 wake。
- `wait(guard)`：先读 counter，drop guard（解锁），再 `wait(&counter, 读到的值)`，最后重新加锁。
- 优化：`num_waiters` 计数，没人等待时 notify 直接返回；用 `AtomicUsize` 避免溢出。
- 陷阱：notify 配额可能被"尚未 wait 的新线程"抢走；避免惊群需要更复杂的分组/requeue。

**RwLock**
- 状态：读者数；写锁用 `u32::MAX`。
- 读者：CAS 递增；写者：CAS `0 → u32::MAX`。
- 写者用独立 `writer_wake_counter` 避免读者频繁变动导致的忙等。
- 写者饥饿：状态改为"读者数 × 2 + 等待写者位"；奇数表示有写者等待，新读者必须阻塞。

## A1 — 应用示例（原书案例：c48）

```rust
pub fn lock(&self) -> MutexGuard<T> {
    if self.state.compare_exchange(0, 1, Acquire, Relaxed).is_err() {
        while self.state.swap(2, Acquire) != 0 {
            wait(&self.state, 2);
        }
    }
    MutexGuard { mutex: self }
}

impl<T> Drop for MutexGuard<'_, T> {
    fn drop(&mut self) {
        if self.mutex.state.swap(0, Release) == 2 {
            wake_one(&self.mutex.state);
        }
    }
}
```

书中基准（作者硬件）：无竞争 500 万次加解锁，两态约 400ms/1800ms，三态约 40ms/60ms——三态消除了无谓 `wake_one` 系统调用。但 macOS 两者都约 50ms，说明平台实现已自带类似优化。

可迁移的教训：**先保证无竞争路径零系统调用，再谈自旋与公平性。**

## A2 — 触发场景

1. 想理解 std 的 Mutex 为什么快，或自己实现一个锁。
   - 语言信号："实现 mutex"、"futex 怎么用"、"为什么解锁要 wake"。
2. 需要条件变量正确用法。
   - 语言信号："Condvar 丢通知"、"为什么要 while 循环"、"notify_one 还是 notify_all"。
3. RwLock 出现写者饥饿或写者忙等。
   - 语言信号："写线程饿死"、"RwLock 写锁拿不到"、"读者太多"。
4. 评估"自旋 vs 睡眠"的取舍。
   - 语言信号："spin 多少"、"系统调用太多"、"锁竞争优化"。

**与相邻能力区分**：
- 要**最小教学版自旋锁** → `build-spinlock-guard`。
- 要**跨平台等待原语的接口细节** → `os-primitive-selection`。
- 要**审查锁实现是否有 UB** → `concurrency-safety-review`。

## E — 执行步骤

**输入契约**：锁类型（Mutex/Condvar/RwLock）+ 目标平台 + 读/写比例 + 是否可依赖 `atomic-wait`/futex。缺平台信息时先问。

1. **选原语**：确认目标平台有 futex 风格 wait/wake；没有则用 `atomic-wait` crate 或退化为自旋 + 文档说明。
2. **定义状态字**：Mutex 用 0/1/2；RwLock 用读者数/`u32::MAX`（需要防饥饿时用 ×2+1 编码）。
3. **实现快路径**：CAS 从"未锁"到"锁"; 失败才进入慢路径。
4. **实现慢路径**：短暂自旋（仅 load）→ `swap` 标记有等待者 → `wait(expected)` 循环。
5. **实现解锁**：`swap(0, Release)`；按前值决定是否 `wake_one`；RwLock 写解锁要 wake 写者并 `wake_all` 读者。
6. **Condvar**：notify 递增 counter 后 wake；wait 先读 counter、解锁、wait、重锁；可选 `num_waiters` 优化。
7. **验证**：无竞争基准（确认零 syscall）、高竞争基准、丢唤醒测试、Miri/压力测试。
   - 完成标准：无竞争路径无 wait/wake；唤醒不丢；写者最终能获得锁。

**输出契约**：状态机说明 + 完整实现 + 基准数据（注明硬件）+ 已知取舍。

## B — 边界

- **不要**在普通应用中替换 std 锁；本能力主要用于理解、教学与特殊平台。
- **不要**忘记"解锁后再 wake"的顺序；先改状态再唤醒。
- **不要**用 `notify_all` 作为默认；优先 `notify_one`，除非确实需要广播。
- **不要**假设自旋一定更快；作者基准显示不同 CPU 结论相反。
- **不要**让 `wait` 只调用一次而不循环重查条件（虚假唤醒）。
- 相邻易混：本能力是阻塞锁；`build-spinlock-guard` 是忙等锁。
- 作者盲点：基准数字绑定硬件；std 实现随版本变化。
