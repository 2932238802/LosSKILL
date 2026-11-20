# 操作系统并发原语选型

## R — 原文

> "This is what makes futex-based synchronization primitives so fast: since we manage the state ourselves, we don't need to rely on the kernel, except when we actually need to block."
> — Chapter 8, "Futex"

> "The pthread types we discussed do not guarantee they are movable, which becomes quite a problem in Rust. Even a simple idiomatic Mutex::new() function is a problem: it would return a mutex object, which would move it into a new place in memory."
> — Chapter 8, "Wrapping in Rust"

中文翻译（自译）：

> 这正是基于 futex 的同步原语如此之快的原因：状态由我们自己管理，只有真正需要阻塞时才依赖内核。
>
> 我们讨论的 pthread 类型并不保证可移动，这在 Rust 里是个大问题。即使一个简单的惯用 `Mutex::new()` 也有问题：它返回的互斥锁对象会被移动到新的内存位置。

## I — 自述

当需要"让线程睡下、再被唤醒"时，必须借助内核。各平台的入口不同，选型的核心是**快路径能否留在用户态**：

- **POSIX / pthread**：`pthread_mutex_t`、`pthread_rwlock_t`、`pthread_cond_t`。注意：默认递归加锁是 UB；类型不保证可移动，Rust 封装通常要 `Box`/`Pin`；锁着销毁也是 UB。
- **Linux futex**：`SYS_futex`，对 32 位原子变量做 `FUTEX_WAIT`（带期望值，避免丢唤醒）/ `FUTEX_WAKE`；还有 BITSET、REQUEUE、CMP_REQUEUE、WAKE_OP、PI 系列。`FUTEX_PRIVATE_FLAG` 可优化同进程场景。新内核有 `futex_waitv`。
- **macOS**：内核接口不稳定，只能走系统库；pthread 锁默认公平、较慢；`os_unfair_lock` 轻量但无 Condvar/RwLock 变体；futex 风格能力可通过 libc++ 的 atomic wait 获得。
- **Windows**：重量级内核对象（Mutex/Event/WaitableTimer）可跨进程；轻量有 `CRITICAL_SECTION`（可重入，不能直接映射为 `&mut T`）与 `SRWLOCK` + `CONDITION_VARIABLE`（可移动、无分配）；`WaitOnAddress`/`WakeByAddress` 提供 futex 风格等待。
- **可移植抽象**：`atomic-wait` crate 只暴露 `wait(&AtomicU32, u32)`、`wake_one`、`wake_all`，覆盖主要平台。

选型顺序：**先问平台 → 再问是否需要跨进程 → 再问是否需要 PI/公平性 → 最后选最小可移动原语**。

## A1 — 应用示例（原书案例：c43）

Linux 上最小 futex 等待：

```rust
pub fn wait(a: &AtomicU32, expected: u32) {
    unsafe {
        libc::syscall(
            libc::SYS_futex,
            a as *const AtomicU32,
            libc::FUTEX_WAIT,
            expected,
            std::ptr::null::<libc::timespec>(),
        );
    }
}

pub fn wake_one(a: &AtomicU32) {
    unsafe { libc::syscall(libc::SYS_futex, a as *const AtomicU32, libc::FUTEX_WAKE, 1); }
}
```

用法：等待方 `while a.load(Relaxed) == 0 { wait(&a, 0); }`；通知方先 `a.store(1, Relaxed)` 再 `wake_one(&a)`。因为 `FUTEX_WAIT` 会在睡眠前核对期望值，通知不会在"检查"与"睡眠"之间丢失。

可迁移的教训：**先改状态，再唤醒；等待必须带期望值并循环重查。**

## A2 — 触发场景

1. 要写跨平台同步原语，不知道各平台该用什么。
   - 语言信号："futex 怎么用"、"WaitOnAddress"、"跨平台锁"。
2. 把 pthread/Windows 原语包装成 Rust 类型时遇到移动/销毁问题。
   - 语言信号："pthread_mutex_t 能移动吗"、"CRITICAL_SECTION 包装"、"Box 包一层"。
3. 需要优先级继承、健壮互斥锁、跨进程同步。
   - 语言信号："priority inversion"、"robust mutex"、"cross-process"。
4. 想用最小依赖实现 wait/wake。
   - 语言信号："atomic-wait"、"wait/wake 原语"。

**与相邻能力区分**：
- 要**实现完整的 Mutex/Condvar/RwLock** → `build-blocking-locks`（本能力只负责底层原语选择）。
- 要**审查锁的 UB** → `concurrency-safety-review`。
- 本能力不讨论内存序语义；那属于 `atomic-ops-and-ordering`。

## E — 执行步骤

**输入契约**：目标平台列表 + 是否跨进程 + 是否需要公平性/PI + 是否允许额外依赖。缺平台列表时先问。

1. **列平台**：Linux / macOS / Windows / 其他（FreeBSD、嵌入式）。
2. **选等待机制**：
   - Linux → futex（`FUTEX_WAIT/WAKE`，同进程加 `FUTEX_PRIVATE_FLAG`）。
   - Windows → `WaitOnAddress`/`WakeByAddress`；需要跨进程时用内核 Mutex/Event。
   - macOS → `os_unfair_lock`（仅互斥）或 libc++ atomic wait；不要直接调不稳定 syscall。
   - 通用 → `atomic-wait` crate。
3. **检查类型可移动性**：pthread 类型不可移动 → `Box`/`Pin`；SRWLOCK/CONDITION_VARIABLE 可移动（未使用时）。
4. **检查语义差异**：递归加锁默认 UB；CRITICAL_SECTION 可重入；SRW 共享锁不可重入；Condvar 需与同一 Mutex 配对。
5. **确定唤醒协议**：等待带期望值并循环；先改状态再 wake；notify_one/notify_all 按需求选择。
6. **输出选型表**：平台 | 原语 | 可移动 | 可跨进程 | 备注 | 依赖。
   - 完成标准：每个目标平台都有可编译的最小示例或 crate 方案。

**输出契约**：选型表 + 平台注意事项 + 最小代码骨架。

## B — 边界

- **不要**直接调用不稳定的内核接口（尤其 macOS）；走系统库或成熟 crate。
- **不要**假设 pthread 类型可移动；也不要假设其销毁总能安全。
- **不要**把 CRITICAL_SECTION 的可重入性包装成 `&mut T`。
- **不要**在没有实测的情况下假设 futex 在所有内核/容器环境可用。
- 相邻易混：本能力是"选原语"，`build-blocking-locks` 是"用原语造锁"。
- 作者盲点：平台细节随 OS 版本变化；书中的 syscall 签名需以当前 man page 为准。
