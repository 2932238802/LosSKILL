# Arc / Weak 引用计数实现

## R — 原文

> "Incrementing the atomic reference counter can be done using a relaxed operation, but the final decrement must synchronize with all previous decrements."
> — Chapter 6, Summary

> "We'll need to use acquire memory ordering to make sure that threads that previously owned a clone of the Arc are no longer accessing the data. We need to establish a happens-before relationship with every single drop that led to the reference counter being one."
> — Chapter 6, "Mutation"

中文翻译（自译）：

> 递增原子引用计数可以用 Relaxed，但最后一次递减必须与之前所有递减同步。
>
> 我们需要 acquire 内存序，确保曾经持有 Arc 克隆的线程不再访问数据；必须与导致计数变为 1 的每一次 drop 建立 happens-before。

## I — 自述

自己实现 Arc，难点几乎全在**计数器的内存序与"最后一个"的判定**：

- 分配一块 `ArcData<T>`，包含计数器和 T；`Arc<T>` 只持有 `NonNull<ArcData<T>>`。
- `clone`：`fetch_add(1, Relaxed)`。因为克隆前已经能访问 T，克隆后仍然能访问，不需要额外顺序。
- `drop`：`fetch_sub(1, Release)`；若返回 1（说明自己是最后一个），再 `fence(Acquire)`，然后释放 T 与分配。
  - Release 保证"我之前对 T 的所有访问"对最后一个 drop 可见；Acquire fence 保证"其他所有递减"对当前线程可见。
- 溢出：`fetch_add` 返回值 > `usize::MAX/2` 时直接 `abort()`；因为 abort 不是瞬时的，阈值要留出其他线程继续递增的空间。
- Weak：需要两个计数器——`data_ref_count`（Arc 数）与 `alloc_ref_count`（Arc + Weak 数）。最后一个 Arc 负责 drop T；最后一个 Weak 负责释放分配。
- `get_mut`：只有确认没有其他 Arc、也没有 Weak 时才能给 `&mut T`；优化版用 `usize::MAX` 作为 `alloc_ref_count` 的临时"锁位"，用 Acquire/Release 配对协调 downgrade。
- `upgrade`：CAS 循环，仅当 `data_ref_count != 0` 时递增；否则返回 None。

## A1 — 应用示例（原书案例：c32/c36）

基础版的关键两段：

```rust
impl<T> Clone for Arc<T> {
    fn clone(&self) -> Self {
        if self.data().ref_count.fetch_add(1, Relaxed) > usize::MAX / 2 {
            std::process::abort();
        }
        Arc { ptr: self.ptr }
    }
}

impl<T> Drop for Arc<T> {
    fn drop(&mut self) {
        if self.data().ref_count.fetch_sub(1, Release) == 1 {
            fence(Acquire);
            unsafe { drop(Box::from_raw(self.ptr.as_ptr())); }
        }
    }
}
```

书中用 `DetectDrop` 验证：两个 Arc 时对象不 drop；最后一个 drop 后 `NUM_DROPS == 1`。Miri 可进一步检查数据竞争。

可迁移的教训：**"递增 Relaxed，最后一次递减 Release + Acquire fence"是引用计数的核心顺序模式。**

## A2 — 触发场景

1. 想理解 `Arc`/`Weak` 的工作原理，或自己实现一个。
   - 语言信号："实现 Arc"、"Arc 为什么用 Relaxed"、"引用计数内存序"。
2. 需要弱引用打破循环（树/图/观察者）。
   - 语言信号："Weak 怎么用"、"循环引用泄漏"、"upgrade 返回 None"。
3. 需要"唯一所有者时才能改"的 API。
   - 语言信号："get_mut 什么时候成功"、"Arc::make_mut"、"copy-on-write"。
4. 审查自研引用计数是否 sound。
   - 语言信号："计数溢出"、"最后一个 drop 顺序对吗"。

**与相邻能力区分**：
- 只问"该用 Rc 还是 Arc" → 不需要本能力，直接答。
- 要**审查已有 Arc 实现** → `concurrency-safety-review`。
- 要**选内存序**但非引用计数场景 → `atomic-ops-and-ordering`。

## E — 执行步骤

**输入契约**：T 的线程约束（Send/Sync）+ 是否需要 Weak + 是否允许分配。

1. **定义 `ArcData<T>`**：`data_ref_count: AtomicUsize`、`alloc_ref_count: AtomicUsize`（有 Weak 时）、数据字段。
2. **实现 `new`**：`Box::new` → `Box::leak` → `NonNull::from`；计数初始化为 1。
3. **实现 `Deref`**：`&self.data().data`；不实现 `DerefMut`。
4. **实现 `clone`**：`fetch_add(1, Relaxed)`；超过 `usize::MAX/2` 则 abort。
5. **实现 `drop`**：`fetch_sub(1, Release)`；返回 1 时 `fence(Acquire)`，再 drop 数据/释放分配。
6. **（可选）Weak**：增加 `alloc_ref_count`；Weak 的 clone/drop 操作它；最后一个 Arc drop 时手动释放"隐含 Weak"份额。
7. **（可选）`get_mut`/`upgrade`**：按"确认无其他 Arc/Weak"或"计数非零 CAS"实现；多计数器场景加锁位协议。
8. **验证**：DetectDrop 单元测试、多线程压力测试、Miri。
   - 完成标准：最后 drop 后数据恰好析构一次；Weak 在 Arc 全灭后 upgrade 返回 None。

**输出契约**：完整实现 + 每个原子操作的内存序理由 + 测试。

## B — 边界

- **不要**把最后一次递减写成 Relaxed；这是经典 UB。
- **不要**用两个独立计数器分别检查来判断独占（存在"隐身"竞态）；要么同锁保护，要么用锁位协议。
- **不要**忽略 `Weak` 对 `get_mut` 的影响：Weak 可随时 upgrade。
- **不要**在普通应用中自造 Arc；std 的实现经过充分验证。
- 相邻易混：`Rc` 是单线程版本，不涉及原子顺序。
- 作者盲点：书中实现接近 std 但不含所有平台优化；性能结论需实测。
