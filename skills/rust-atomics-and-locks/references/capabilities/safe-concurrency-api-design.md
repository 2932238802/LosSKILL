# 安全并发 API 设计

## R — 原文

> "Starting with a very minimal but entirely unsafe version, we’ll work our way through several ways to design a safe interface, while considering design decisions and their consequences."
> — Preface / Chapters 4–6

> "Taking a non-Copy object by value can be used to prevent something from being done more than once."
> — Chapter 5, Summary

> "To be able to provide a fully safe interface, we need to tie the unlocking operation to the end of the &mut T. We can do that by wrapping this reference in our own type that behaves like a reference, but also implements the Drop trait to do something when it is dropped."
> — Chapter 4, "A Safe Interface Using a Lock Guard"

中文翻译（自译）：

> 从一个最小但完全不安全的版本开始，我们会逐步尝试多种安全接口设计，并考虑每种决策及其后果。
>
> 用按值消费一个非 Copy 对象，可以阻止某件事被做两次。
>
> 要提供完全安全的接口，需要把解锁绑定到 &mut T 的生命周期结束；做法是把该引用包进一个自身行为像引用、但实现 Drop 的类型。

## I — 自述

这本书的接口设计有一条清晰的"演进阶梯"，每一步都在把举证责任从"调用者"移向"编译器"：

1. **最小实现**：先让协议跑通，可以全是 unsafe。
2. **unsafe fn + Safety 文档**：无法静态表达的前置条件，明确交给调用者。
3. **运行时检查**：用 panic 把误用挡在 UB 之前（宁可 panic，不可 UB）。
4. **类型级保证**：用所有权、生命周期、非 Copy、私有构造、借用拆分、`PhantomData` 让误用无法编译。
5. **性能优化**：在安全边界不后退的前提下，减少原子操作、系统调用与分配。

核心手段：
- **guard**：类型的"存在"即证明锁已持有；`Deref/DerefMut` 提供访问，`Drop` 自动释放。
- **消费 self**：`fn send(self, ...)` 让"只能调用一次"成为编译期事实。
- **split borrow**：`&mut self` 拆成两个共享借用，静态保证单发送者/单接收者。
- **`PhantomData<*const ()>`**：让类型 `!Send`，把对象钉在创建线程。
- **私有字段 + 唯一构造路径**：外部无法伪造"已加锁"状态。

选择哪种手段，取决于"这个误用能否在不增加太多运行期成本的前提下静态排除"。

## A1 — 应用示例（原书案例：c29 + c30）

目标：一次性通道，要求重复 `send` 在编译期报错，且不分配内存。

演进（Ch.5）：
- v1：`unsafe fn send(&self, ...)`，调用者负责只调用一次。
- v2：`AtomicBool in_use`，重复 send 运行期 panic。
- v3：拆成 `Sender<T>` / `Receiver<T>`，`send(self)` 消费；用 `Arc` 共享内部通道（有分配）。
- v4：`Sender<'a,T>` / `Receiver<'a,T>` 借用 `Channel`，`Channel::split(&mut self)` 拆分独占借用——无分配，且借用检查器阻止重复 split。

结果：重复 `sender.send(...)` 直接编译错误（use of moved value）；`split()` 在 Sender/Receiver 存活期间无法再次调用。

可迁移的教训：**先枚举误用，再问"哪一种能变成类型错误"；剩下的才用运行时检查。**

## A2 — 触发场景

1. 设计一个并发原语/库 API，想让误用"编译不过"而不是"运行崩"。
   - 语言信号："API 怎么设计才安全"、"能不能编译期防住"、"make illegal states unrepresentable"。
2. 纠结"该返回 guard 还是 &mut T / 该不该 unsafe fn"。
   - 语言信号："guard 模式"、"要不要标 unsafe"、"调用者保证什么"。
3. 需要让某个对象只能使用一次 / 只能留在一个线程。
   - 语言信号："只能 send 一次"、"不能跨线程"、"PhantomData 怎么用"。
4. `unsafe impl Send/Sync` 拿不准约束。
   - 语言信号："这样 impl Sync 对吗"、"T: Send 还是 Send + Sync"。
5. 手里有一个 unsafe 实现，想把它包装成安全接口。
   - 语言信号："怎么封装成 safe"、"减少 unsafe 面积"。

**与相邻能力区分**：
- 若要**实现具体原语**（锁/Arc/通道），用对应构建能力；本能力关注"接口形状与安全边界"。
- 若要**审查已有代码**，用 `concurrency-safety-review`。
- 本能力不负责内存序选型；顺序问题交给 `atomic-ops-and-ordering`。

## E — 执行步骤

**输入契约**：原语的功能目标 + 已知误用清单 + 可接受的运行期成本（是否允许分配/panic）。缺少误用清单时，先与用户一起列。

1. **列出不变量与误用**：哪些状态必须同时成立；调用者可能怎样破坏它们。
   - 完成标准：至少列出"重复调用、跨线程、提前释放、忘记解锁、悬垂引用"五类中相关的项。
2. **画演进阶梯**：为每个误用标注"最小实现 / unsafe fn / 运行时检查 / 类型级"四档中最右可达的一档。
3. **优先类型级**：
   - 只能执行一次 → 非 Copy 参数按值消费。
   - 只能单发送/单接收 → 拆分 `&mut` 为两个借用（split）。
   - 必须留在某线程 → `PhantomData<*const ()>` 等 `!Send` 标记。
   - 必须持锁才能访问 → guard + 私有构造 + `Deref/DerefMut` + `Drop`。
4. **剩余前置条件用 unsafe fn + `# Safety` 文档**；文档必须写"调用者要保证什么、违反会怎样"。
5. **在 unsafe 与 UB 之间加运行时检查**（panic 优于 UB），但不要用它替代可静态排除的约束。
6. **校准 auto trait**：手写 `Send/Sync` 时给出约束理由；检查 `Deref` 是否让自动推导与真实语义不一致（必要时手动 impl 或加 `PhantomData`）。
7. **输出 API 设计说明**：类型签名 + 每个 trait impl 的理由 + 仍存在的 unsafe 前置条件 + 误用示例（应编译失败/panic）。
   - 完成标准：每个原本的误用，要么编译失败，要么 panic，要么有书面 Safety 契约。

**输出契约**：API 草案（签名 + 关键 impl）+ 误用矩阵（误用 → 被什么挡住）+ 残余 unsafe 清单。

## B — 边界

- **不要**为了"零 unsafe"而引入巨大运行期开销或复杂类型体操；按使用场景取舍。
- **不要**让安全接口依赖 `Drop` 一定执行——对象可以被泄漏（Leakpocalypse）。
- **不要**在没有说明约束的情况下 `unsafe impl Send/Sync`；这是对编译器的承诺。
- **不要**用 panic 代替可静态排除的误用；panic 是兜底，不是设计目标。
- 相邻易混：`concurrency-safety-review` 审查已有实现；`build-*` 能力给具体实现模板。
- 作者盲点：书中偏重库作者视角；应用开发者应优先使用 std 的成熟 API，而不是自造轮子。
