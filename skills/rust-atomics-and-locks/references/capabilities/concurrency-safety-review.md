# 并发与 unsafe 代码安全审查

## R — 原文

> "These two concepts together fully prevent data races: situations where one thread is mutating data while another is concurrently accessing it. Data races are generally undefined behavior, which means the compiler does not need to take these situations into account."
> — Chapter 1, "Borrowing and Data Races"

> "This means that in our example above it's important that we only park the thread if we've seen the queue is empty, rather than park it after every processed item."
> — Chapter 1, "Thread Parking"

> "We can make sure an object stays on the same thread by making sure its type does not implement Send, which can be achieved with the PhantomData marker type."
> — Chapter 5, "Blocking"

中文翻译（自译）：

> 这两条规则合起来完全防止数据竞争：一个线程在改数据、另一个线程同时在访问。数据竞争通常是未定义行为，编译器无需考虑这种情况。
>
> 因此上面的例子中，重要的是只在确认队列为空时才 park，而不是每处理完一项就 park。
>
> 可以通过让类型不实现 Send 来保证对象留在同一线程，这可以用 PhantomData 标记类型实现。

## I — 自述

审查并发代码不是"看到共享变量就加锁"，而是按固定顺序排除几类不同的错误：

1. **数据竞争（UB）**：同一时刻存在一个写与任意其他访问，且两者之间没有 happens-before 边。
2. **同步缺失（UB）**：代码"看起来"有顺序，但实际没有建立 HB（典型：用 Relaxed 解锁、用 compiler fence 代替原子 fence、在 x86 上侥幸通过）。
3. **不变量被破坏（UB 或逻辑错误）**：guard 生命周期、重复 send/receive、Arc::get_mut 忽略 Weak、failed CAS 的 failure ordering、Drop 依赖。
4. **活性/公平性缺陷（不是 UB）**：丢唤醒、错误 park、写者饥饿、惊群、通知被后来者抢走。
5. **性能退化（不是 UB）**：持锁睡眠、临时 guard 延长临界区、伪共享、无谓 wake。

关键区分：**UB 必须从类型/协议层面排除；性能与公平性问题可以权衡。** 审查报告的每一条都要标明属于哪一类，避免把"慢"说成"错"，也避免把 UB 当"概率问题"。

## A1 — 应用示例（原书案例：x33 + c05）

场景：

```rust
if let Some(item) = list.lock().unwrap().pop() {
    process_item(item);
}
```

审查结论（Ch.1 "Lifetime of the MutexGuard"）：
- `lock()` 返回的临时 `MutexGuard` 会活到整个 `if let` 语句结束，因此 `process_item(item)` 执行期间仍然持锁。
- 这不是 UB，但会把临界区扩大到不需要的范围，高竞争时显著退化。

修正：

```rust
let item = list.lock().unwrap().pop();
if let Some(item) = item {
    process_item(item);
}
```

可迁移的教训：**先判断"这是不是 UB"，再判断"这是不是不必要地持锁"。**

## A2 — 触发场景

1. 用户贴出一段并发/unsafe Rust，问"有没有问题 / 会不会 UB / 帮我 review"。
   - 语言信号："有没有 data race"、"这段 unsafe 安全吗"、"review 一下并发代码"、"is this sound"。
2. 代码在 x86 正常、在 ARM 或 CI 偶发失败。
   - 语言信号："本地没问题，线上偶发"、"换个机器就挂"、"rare crash"。
3. 出现死锁、线程永久挂起、唤醒丢失。
   - 语言信号："卡死"、"线程不醒"、"deadlock"、"lost wakeup"、"hang"。
4. 使用 Mutex/Condvar/park/Arc 的组合，想确认协议正确。
   - 语言信号："Condvar 用法对吗"、"notify 丢了"、"Arc::get_mut 能用吗"。
5. 写了一个锁/通道/引用计数，想要第二双眼睛。
   - 语言信号："我实现了个 lock"、"custom Arc"、"one-shot channel"。

**与相邻能力区分**：
- 若用户问"**该选哪个 Ordering**"而不是"现有代码对不对"，用 `atomic-ops-and-ordering`。
- 若用户问"**为什么慢**"且代码正确，用 `atomic-performance-and-portability`。
- 若用户要"**从零实现** Mutex/Arc/通道"，先走对应构建能力；本能力只在实现完成后做审查。

## E — 执行步骤

**输入契约**：完整代码片段 + 运行平台 + 症状（若有）。缺少"哪些变量被哪些线程访问"时先追问，不能凭变量名猜。

1. **建立访问表**：线程 × 变量 × 操作（读/写/原子操作/加锁） × 顺序。
   - 完成标准：能指出每一对并发访问。
2. **查数据竞争**：对每对"至少一方写"的非原子访问，检查它们之间是否存在 HB 边（同线程顺序、spawn/join、lock/unlock、acquire-release 配对、SeqCst 全序）。
   - 无 → 标为 UB，给出需要的同步。
3. **查同步原语用法**：
   - Release 只用于 store，Acquire 只用于 load；CAS 的 failure ordering 在失败路径读数据时必须 Acquire。
   - 原子 fence 不能被 compiler fence 替代（除信号处理/同核中断等特例）。
   - 解锁是否与下一次加锁配对；是否有"解锁后再唤醒"的顺序。
4. **查不变量与类型约束**：
   - guard 是否可能被提前 drop / 延长寿命；是否存在 `forget(guard)` 后仍 drop 锁。
   - `unsafe impl Send/Sync` 的约束是否正确（独占锁 T: Send；共享读锁 T: Send + Sync）。
   - `PhantomData` 是否正确阻止跨线程；`Deref` 的自定义是否让自动 trait 推导失真。
   - 是否依赖 `Drop` 保证安全（泄漏即可绕过）。
5. **查活性/公平性**：wait 是否循环重查条件；是否只在条件不满足时 park；notify 是否可能丢；是否所有唤醒都指向正确对象；写者是否可能饥饿。
6. **查性能（可选）**：临界区是否包含 I/O/睡眠；是否无谓 wake；是否有伪共享。
7. **输出报告**：每条 = 严重级别（UB / 逻辑 / 活性 / 性能） + 位置 + 机理 + 修复 + 验证方法。
   - 完成标准：每条 UB 都能写出"哪两个访问、缺哪条 HB"；不能只写"建议加锁"。

**输出契约**：问题清单（按严重级别排序）+ 最小修复 + 验证建议（Miri、压力测试、弱序设备）。

## B — 边界

- **不要**在没有完整访问序列时下"安全"结论；只看了片段就宣称 sound 是不负责任的。
- **不要**把"能编译/能跑"当作正确性证据；safe Rust 也不能证明并发协议正确。
- **不要**把性能问题标成 UB，或反之；混淆会让修复方向错误。
- **不要**建议用 SeqCst"一键修复"；先定位缺失的 HB。
- 相邻易混：`atomic-ops-and-ordering` 是"选型"，本能力是"审查"。
- 作者盲点：书中案例多为教学代码；真实项目还要考虑 poisoning、取消、panic 安全、长期维护。
- 版本边界：std 内部实现随版本变化，审查应以目标工具链文档为准。
