# 自旋锁与守卫实现

## R — 原文

> "To be able to provide a fully safe interface, we need to tie the unlocking operation to the end of the &mut T. We can do that by wrapping this reference in our own type that behaves like a reference, but also implements the Drop trait to do something when it is dropped."
> — Chapter 4, "A Safe Interface Using a Lock Guard"

> "We use acquire and release memory ordering to make sure that every unlock() call establishes a happens-before relationship with the lock() calls that follow."
> — Chapter 4, "A Minimal Implementation"

中文翻译（自译）：

> 要提供完全安全的接口，需要把解锁绑定到 &mut T 的生命周期结束；做法是把该引用包进一个自身行为像引用、但实现 Drop 的类型。
>
> 我们使用 acquire/release 内存序，确保每次 unlock() 都与随后的 lock() 建立 happens-before 关系。

## I — 自述

自旋锁是"忙等版互斥锁"：拿不到锁就反复重试，而不是睡眠。它的价值不在性能（多数场景反而浪费 CPU），而在**用最小代码完整演示锁的协议**：

- 一个 `AtomicBool` 表示锁定状态；
- `lock()` 用 `swap(true, Acquire)` 尝试获取，失败则 `spin_loop()` 后重试；
- `unlock()` 用 `store(false, Release)` 释放；
- Acquire/Release 保证"上一次持锁期间的写"对"下一次持锁者"可见。

要把它变成安全接口，需要三步：
1. 用 `UnsafeCell<T>` 存放受保护数据（内部可变性）；
2. `unsafe impl Sync for SpinLock<T> where T: Send`（独占访问只需 T: Send）；
3. `lock()` 返回 Guard，Guard 通过 `Deref/DerefMut` 暴露 `&T/&mut T`，`Drop` 时解锁。

Guard 的存在本身就是"已持锁"的证明——字段私有、无公开构造，外部无法伪造。

## A1 — 应用示例（原书案例：c24）

```rust
pub struct SpinLock<T> {
    locked: AtomicBool,
    value: UnsafeCell<T>,
}

unsafe impl<T> Sync for SpinLock<T> where T: Send {}

impl<T> SpinLock<T> {
    pub const fn new(value: T) -> Self {
        Self { locked: AtomicBool::new(false), value: UnsafeCell::new(value) }
    }
    pub fn lock(&self) -> Guard<T> {
        while self.locked.swap(true, Acquire) {
            std::hint::spin_loop();
        }
        Guard { lock: self }
    }
}

pub struct Guard<'a, T> { lock: &'a SpinLock<T> }

impl<T> Deref for Guard<'_, T> {
    type Target = T;
    fn deref(&self) -> &T { unsafe { &*self.lock.value.get() } }
}
impl<T> DerefMut for Guard<'_, T> {
    fn deref_mut(&mut self) -> &mut T { unsafe { &mut *self.lock.value.get() } }
}
impl<T> Drop for Guard<'_, T> {
    fn drop(&mut self) { self.lock.locked.store(false, Release); }
}
```

书中用它保护 `Vec`，多线程 push 后断言元素集合正确。结果：无需手写 unlock，提前 `drop(g)` 后再用 `g` 会编译失败。

## A2 — 触发场景

1. 想理解/实现一个最小的锁，用于教学或嵌入式无 OS 环境。
   - 语言信号："实现 spin lock"、"自旋锁怎么写"、"atomic bool 做锁"。
2. 需要把"持锁才能访问数据"编码进类型。
   - 语言信号："guard 怎么写"、"MutexGuard 原理"、"Deref/DerefMut 锁"。
3. 已有裸 `AtomicBool` 锁，想消除 `unsafe unlock` 的误用。
   - 语言信号："unlock 太容易忘"、"能不能自动解锁"。
4. 极短临界区、可接受忙等（如内核/实时场景）。
   - 语言信号："spin 还是 sleep"、"低延迟锁"。

**与相邻能力区分**：
- 要**可阻塞的生产级 Mutex/Condvar/RwLock** → `build-blocking-locks`。
- 要**设计整体 API 的安全边界**（Send/Sync、类型状态）→ `safe-concurrency-api-design`。
- 只是问"该用哪种锁" → `build-blocking-locks` 的选型部分。

## E — 执行步骤

**输入契约**：受保护数据类型 T + 是否允许忙等 + 目标平台。若用于生产，先确认"std::sync::Mutex 是否已足够"。

1. **定义结构**：`AtomicBool` + `UnsafeCell<T>`。
2. **实现 `new`**：`const fn`，状态 false。
3. **实现 `lock`**：`while swap(true, Acquire) { spin_loop() }`；返回 Guard。
4. **实现 Guard**：持有 `&'a SpinLock<T>`；`Deref`/`DerefMut` 在 unsafe 中取 `&*value.get()`。
5. **补 trait 约束**：`unsafe impl<T: Send> Sync for SpinLock<T>`；按需为 Guard 手写 `Send/Sync` 或加 `PhantomData<&mut T>`。
6. **实现 `Drop`**：`store(false, Release)`。
7. **验证**：多线程竞争测试；用 Miri 检查 UB；确认提前 drop 后使用会编译失败。
   - 完成标准：无手动 unlock；Guard 不能伪造；竞争下计数/集合正确。

**输出契约**：完整类型 + 一份"为什么 Acquire/Release 足够"的说明 + 测试。

## B — 边界

- **不要**把自旋锁当"更快的 Mutex"用于可能长时间持锁的场景；会烧 CPU 且拖慢同核线程。
- **不要**在单核/超额订阅环境大量自旋。
- **不要**用 Relaxed 实现 lock/unlock；会丢失 HB。
- **不要**忘记 `spin_loop()` 提示；也不要假设它会让出 CPU。
- 相邻易混：本能力是教学级最小实现；生产锁需要 wait/wake、公平性与平台优化。
- 作者盲点：书中明确说自旋收益"it depends"；不要从示例推断通用性能结论。
