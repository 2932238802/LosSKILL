# 一次性通道实现

## R — 原文

> "Taking a non-Copy object by value can be used to prevent something from being done more than once."
> — Chapter 5, Summary

> "We can make sure an object stays on the same thread by making sure its type does not implement Send, which can be achieved with the PhantomData marker type."
> — Chapter 5, "Blocking"

中文翻译（自译）：

> 用按值消费一个非 Copy 对象，可以阻止某件事被做两次。
>
> 可以通过让类型不实现 Send 来保证对象留在同一线程，这可以用 PhantomData 标记类型实现。

## I — 自述

一次性通道（one-shot channel）只传一条消息，是练习"原子状态机 + 类型级约束"的最小载体。书中按四条路线演进：

1. **Mutex + Condvar + VecDeque**：最简单、通用，但每次收发都要抢锁，且队列无界。
2. **裸 unsafe**：`UnsafeCell<MaybeUninit<T>>` + `AtomicBool ready`；`send` 写槽后 Release 置位；`receive` Acquire 读位后 `assume_init_read`。误用方式很多（重复 send/receive、未初始化读、泄漏）。
3. **运行时检查**：`in_use` 防止重复 send；`receive` 用 `swap(false, Acquire)` 防重复接收；`Drop` 里用 `get_mut()` 清理未接收消息。误用变成 panic，而不是 UB。
4. **类型级**：
   - `Sender<T>` / `Receiver<T>`，`send(self)`、`receive(self)` 消费对象 → 编译期只能调用一次；
   - 用 `Arc<Channel<T>>` 共享（有分配），或 `Channel::split(&mut self)` 拆借（无分配）；
   - `Receiver` 加 `PhantomData<*const ()>` 使其 `!Send`，保证 unpark 的是正确线程。

核心原则：**能用类型排除的，不要留给运行时；能 panic 的，不要留给 UB。**

## A1 — 应用示例（原书案例：c29）

```rust
pub fn channel<T>() -> (Sender<T>, Receiver<T>) { ... }

impl<T> Sender<T> {
    pub fn send(self, message: T) { ... }   // self by value
}
impl<T> Receiver<T> {
    pub fn receive(self) -> T { ... }       // self by value
}
```

结果：第二次 `sender.send(...)` 报 `use of moved value`；`in_use` 标志与相应运行期检查可以删除。

书中进一步用 `Channel::split(&mut self)` 返回两个借用对象，避免 Arc 分配；再给 `Receiver` 加 `PhantomData<*const ()>`，把接收端钉在创建线程，并在 `send` 里 `receiving_thread.unpark()`。

## A2 — 触发场景

1. 想实现线程间传一条消息的通道，或理解 std `mpsc` 的简化版。
   - 语言信号："one-shot channel"、"send once"、"线程间传值"。
2. 想练习"把运行期检查升级为编译期保证"。
   - 语言信号："怎么让重复调用编译失败"、"类型状态"、"typestate"。
3. 自研通道出现重复发送/接收、消息泄漏、unpark 错线程。
   - 语言信号："消息丢了"、"泄漏"、"receiver 移线程后不醒"。
4. 需要无分配的通道。
   - 语言信号："channel 能不能不 allocate"、"split borrow"。

**与相邻能力区分**：
- 要**通用多生产者/多消费者通道** → 本能力只覆盖一次性；建议直接用 std 或成熟 crate。
- 要**设计安全 API 的通用方法** → `safe-concurrency-api-design`。
- 要**审查已有通道实现** → `concurrency-safety-review`。

## E — 执行步骤

**输入契约**：消息类型 T + 是否允许分配 + 接收端是否必须留在创建线程 + 是否需要阻塞接收。

1. **选基线**：先写 `Mutex<Option<T>> + Condvar` 版本，确认语义与测试。
2. **换原子实现**：`UnsafeCell<MaybeUninit<T>>` + 状态原子（bool 或单 `AtomicU8` 四状态）。
3. **定协议**：send 写槽 → Release 置 ready；receive Acquire 读/swap ready → `assume_init_read`。
4. **加运行期检查**：重复 send/receive → panic；`Drop` 清理未接收消息（`get_mut` 无需原子）。
5. **升级类型级**：拆 `Sender`/`Receiver`，方法消费 `self`；私有构造，外部无法伪造。
6. **去分配**：提供 `Channel::split(&mut self)` 借用版本；`split` 中重置状态并触发旧消息的 Drop。
7. **阻塞接收**：`Sender` 保存接收线程 `Thread`，send 后 `unpark`；`Receiver` 加 `PhantomData<*const ()>` 禁止跨线程；`receive` 循环 `park` + 重查。
8. **验证**：重复 send 编译失败；未接收消息在 drop 时析构；多线程压力测试。
   - 完成标准：每种误用分别被"编译错误 / panic / Drop 清理"覆盖。

**输出契约**：通道 API + 误用矩阵 + 消息所有权/析构说明。

## B — 边界

- **不要**用它替代通用 mpsc；一次性语义不适用于持续消息流。
- **不要**忘记 `Drop`：`MaybeUninit` 不会自动析构，未接收消息会泄漏。
- **不要**在 `send` 中先置 ready 再写数据；顺序必须相反。
- **不要**让 `Receiver` 可跨线程却仍用旧的 `Thread` 句柄 unpark。
- 相邻易混：`safe-concurrency-api-design` 讲通用手段；本能力是具体实现。
- 作者盲点：类型级设计会增加 API 复杂度与分配取舍；不是所有场景都值得。
