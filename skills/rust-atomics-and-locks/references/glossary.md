# Rust Atomics and Locks — 术语表

> 来源：Mara Bos《Rust Atomics and Locks》(2023)，按作者本人的用法整理。英文定义保留原文短语，中文为自译。

## atomic operation
*别名*：原子操作, atomic op, indivisible operation  
*出处*：第 2 章 Atomics

**作者定义**：作者从希腊语 ἄτομος（不可分割）引出定义：原子操作是 "an operation that is indivisible: it is either fully completed, or it didn’t happen yet." 它只保证这一次操作不可分割，并不表示性能更快，也不自动保证多个变量之间的顺序。作者同时强调它是所有并发原语的地基："All the other concurrency primitives, such as mutexes and condition variables, are implemented using atomic operations."

**关键区分**：≠ "快"或"高性能" — 原子操作可能比普通操作更慢 ≠ 自动保证跨变量顺序 — 那由内存序单独决定 = 单次读-改-写不可分割；Rust 中由 std::sync::atomic 类型提供

**为何重要**：下游 skill 若把"原子"理解成"快"或"线程安全"的万能标签，会建议用户在需要发布多个变量时仅用原子类型而不选内存序。必须澄清：原子性只解决"单变量不撕裂"，跨线程顺序和复合不变量需要 Release/Acquire、锁或专门协议。

**相关术语**：data race, Relaxed, Release and acquire ordering, total modification order

## data race
*别名*：数据竞争  
*出处*：第 1 章 Basics of Rust Concurrency

**作者定义**：作者定义为 "situations where one thread is mutating data while another is concurrently accessing it"，并指出 "Data races are generally undefined behavior"。在内存模型层面，并发的非原子写同一变量构成 data race；并发的原子写则被允许。作者不把它描述为"结果不确定但可能安全"的普通竞争。

**关键区分**：≠ 结果不确定但可能安全的普通竞态 — 那类情形可以安全 = 并发访问、至少一方写、且不是原子操作；一律 UB → 不是"概率性 bug"，而是编译器可以假设永不发生的规则违反

**为何重要**：下游 skill 审查并发代码时，不能只说"这里可能有竞争，加个锁试试"。必须区分：data race 是 UB，必须在类型/协议层面排除；普通逻辑竞争才谈"结果不确定"。作者的核心论证"借用规则 → data race → UB"依赖这一严格用法。

**相关术语**：undefined behavior, atomic operation, interior mutability, Send

## undefined behavior
*别名*：UB, 未定义行为  
*出处*：第 1 章 Basics of Rust Concurrency

**作者定义**：编译器被允许在不检查的情况下假定语言规则永不被破坏；一旦破坏就产生 undefined behavior。作者强调它不只影响出错处：'undefined behavior can even "travel back in time," causing problems in code that precedes it.' 同时区分 unsafe 与 UB："Unsafe" 只是编译器不再替你验证；真正违反规则叫 unsound。

**关键区分**：≠ "unsafe 代码就是 UB" — unsafe 只是把正确性责任交给调用者 ≠ 只污染出错的那一行 — 可向前后传播，使无关代码被错误优化 = 编译器可假定永不发生、从而可做任意变换的程序状态

**为何重要**：下游 skill 在讲 unsafe 封装时，不能把"用了 unsafe"等同于"危险/错误"，也不能承诺"只要不崩溃就没问题"。正确说法是：unsafe 块承担 safety requirements；违反即 UB，且可能表现为远处的错误优化。

**相关术语**：data race, UnsafeCell, MaybeUninit, NonNull

## happens-before
*别名*：HB, happens before, 先于发生关系  
*出处*：第 3 章 Memory Ordering

**作者定义**：内存模型用 happens-before 定义顺序："but instead only defines situations where one thing is guaranteed to happen before another thing, and leaves the order of everything else undefined." 同一线程内所有操作按程序顺序成立；跨线程只在少数情形出现，例如 spawn/join、解锁/加锁、以及非 Relaxed 的原子操作。作者特别指出：读到某个 store 写入的值，本身并不建立与那个 store 的 happens-before。

**关键区分**：≠ 墙上时钟意义上的"更早" ≠ "读到了某值"就自动同步 — 值相同不代表同一个事件 = 可用于证明两个并发访问不重叠的形式关系

**为何重要**：这是全书正确性论证的核心工具。下游 skill 若把 happens-before 当成"时间先后"或"看到值就同步"，会给出错误的内存序审查结论。正确用法是画出 HB 边：只有 spawn/join、锁的释放/获取、acquire 读到 release 的值、SeqCst 全序等才连边。

**相关术语**：Release and acquire ordering, SeqCst, total modification order, fence

## total modification order
*别名*：modification order, 修改全序, 单变量修改顺序  
*出处*：第 3 章 Memory Ordering

**作者定义**：每个原子变量都有一条所有线程一致同意的修改顺序："all modifications of the same atomic variable happen in an order that is the same from the perspective of every single thread." 作者强调即使使用 Relaxed 也保证这一点，但只限单个变量，不保证不同变量之间的相对顺序。

**关键区分**：≠ 所有原子变量的全局顺序 — 跨变量没有这种保证 ≠ 只有 SeqCst 才有 — Relaxed 同样提供单变量修改全序 = 单变量层面的"时间线"，用来判断 acquire-load 究竟与哪个 release-store 同步

**为何重要**：下游 skill 常把"Relaxed 没有顺序保证"说成"完全乱序"。实际上 Relaxed 仍有单变量全序。审查时可用它排除"同一变量读到 0→5→0"这类不可能结果，同时不能用它推出跨变量顺序。

**相关术语**：Relaxed, happens-before, Release and acquire ordering, SeqCst

## Relaxed
*别名*：Ordering::Relaxed, relaxed ordering, 宽松序  
*出处*：第 3 章 Memory Ordering

**作者定义**："The simplest variant with the fewest guarantees is Relaxed. Relaxed still guarantees consistency on a single atomic variable, but does not promise anything about the relative order of operations between different variables." 它 "by itself, never results in any cross-thread happens-before relationships."

**关键区分**：≠ "可能永远看不到"或"延迟很久" — 作者说内存模型根本不谈时间 ≠ 毫无保证 — 仍保证单变量的修改全序与不撕裂读写 = 只需要单变量一致、不需要跨变量发布/接收时的选择

**为何重要**：常见误区是把 Relaxed 当成"不稳定/会丢更新"。下游 skill 若沿用这种直觉，会无谓升级到 SeqCst。正确用法：停止标志、统计计数、引用计数递增等只需单变量一致的场景可用 Relaxed；若需"数据先写好再置标志"，则必须 Release/Acquire。

**相关术语**：total modification order, Release and acquire ordering, SeqCst, atomic operation

## Release and acquire ordering
*别名*：Release, Acquire, AcqRel, release-acquire, Ordering::Release, Ordering::Acquire  
*出处*：第 3 章 Memory Ordering

**作者定义**："Release memory ordering applies to store operations, while Acquire memory ordering applies to load operations. A happens-before relationship is formed when an acquire-load operation observes the result of a release-store operation." 此时 release-store 及其之前的一切 happens-before acquire-load 及其之后的一切。AcqRel 表示读部分用 Acquire、写部分用 Release。

**关键区分**：≠ 锁的专利 — 任何"先写数据、再发布标志"的模式都可用 ≠ Release 可用于 load、Acquire 可用于 store — 方向固定 ≠ SeqCst — 不提供所有操作的单一全局全序 = 必须配对使用；acquire 必须真正读到 release 写入的那个值

**为何重要**：这是"发布数据/交接所有权"的默认工具，也是审查并发代码时最常画的一条 HB 边。下游 skill 需要强调配对与"读到同一事件"：仅在同一变量上分别写 Release/Acquire，但 acquire 读到的是更早或更晚的值时，同步关系可能不成立。

**相关术语**：happens-before, Relaxed, SeqCst, fence, guard

## SeqCst
*别名*：sequentially consistent, sequential consistency, Ordering::SeqCst, 顺序一致性  
*出处*：第 3 章 Memory Ordering

**作者定义**："It includes all the guarantees of acquire ordering (for loads) and release ordering (for stores), and also guarantees a globally consistent order of operations." 每个 SeqCst 操作都属于所有线程一致同意的单一全序，并与各变量的修改全序相容。作者同时判断："SeqCst ordering is almost never necessary in practice."

**关键区分**：≠ 应当默认使用 — 作者把它视为 warning sign，看到就应额外审查 ≠ 能制造 acquire-store 或 release-load — 这两种操作不存在 ≠ 可以把 SeqCst 操作拆成 relaxed + SeqCst fence — 作者明确说不行 = 仅在需要所有线程对多个原子操作的顺序达成一致时使用

**为何重要**：下游 skill 若把 SeqCst 当"最安全默认"，会让代码审查范围扩大到全程序所有 SeqCst 操作，违背作者"最小推理范围"的主张。正确用法：先尝试 Relaxed 或 Release/Acquire；只有当算法确实依赖多个变量的全局顺序时才用 SeqCst，并说明依赖点。

**相关术语**：Release and acquire ordering, fence, happens-before, total modification order

## fence
*别名*：atomic fence, memory fence, 内存栅栏, 内存屏障, std::sync::atomic::fence  
*出处*：第 3 章 Memory Ordering

**作者定义**："An atomic fence allows you to separate the memory ordering from the atomic operation. This can be useful if you want to apply a memory ordering to multiple operations, or if you only want to apply it conditionally." release fence + relaxed store 可替代 release-store；relaxed load + acquire fence 可替代 acquire-load。

**关键区分**：≠ 绑定某个原子变量 — 一个 fence 可同时服务多个变量 ≠ 可把 SeqCst 操作拆成 relaxed + SeqCst fence — 作者明确禁止 ≠ compiler_fence — 后者只限制编译器，不限制处理器重排 = 把顺序要求与具体原子操作解耦、并可按条件执行的工具

**为何重要**：高性能数据结构常用"一次 acquire fence 服务多次 relaxed load"来省开销。下游 skill 必须同时讲清限制：fence 不能凭空建立 HB（仍需有 store/load 被观察到），也不能替代 SeqCst 操作的全局全序；否则会把优化建议写成错误保证。

**相关术语**：Release and acquire ordering, SeqCst, happens-before

## interior mutability
*别名*：内部可变性  
*出处*：第 1 章 Basics of Rust Concurrency

**作者定义**：'A data type with interior mutability slightly bends the borrowing rules. Under certain conditions, those types can allow mutation through an "immutable" reference.' 作者建议在涉及这类类型时改用更准确的 shared/exclusive 术语，因为 immutable/mutable 已不准确。

**关键区分**：≠ 放宽独占借用 — 只放宽共享借用 ≠ 任意共享可变都安全 — 必须由类型内部机制保证不产生 UB = Cell/RefCell/Mutex/原子类型等的共同能力，底层由 UnsafeCell 支撑

**为何重要**：下游 skill 在解释"为什么 Arc 能在共享引用下改计数器"或"为什么原子类型能跨线程改"时会反复用到。必须避免把它说成"绕过借用检查"，而应说明：它用内部 unsafe 把动态检查/原子性/锁协议封装成安全接口。

**相关术语**：UnsafeCell, data race, Send, Sync

## UnsafeCell
*别名*：std::cell::UnsafeCell, 内部可变性原语  
*出处*：第 1 章 Basics of Rust Concurrency

**作者定义**："An UnsafeCell is the primitive building block for interior mutability." 它 "wraps a T, but does not come with any conditions or restrictions to avoid undefined behavior"；get() 只返回裸指针，"which can only be meaningfully used in unsafe blocks"，正确性完全由用户保证。

**关键区分**：≠ 安全的内部可变性抽象 — 它本身不提供任何保护 = 所有内部可变性类型（Cell、Mutex、原子类型等）的底层原语 → 直接使用它意味着自己承担别名规则与数据竞争的正确性

**为何重要**：下游 skill 在实现 SpinLock、通道、Arc 时都会用到 UnsafeCell。需要明确：UnsafeCell 只是"允许通过共享引用拿到 *mut T"的许可，不是"可以随便改"的许可；配套的锁/标志/生命周期协议才是安全性的来源。

**相关术语**：interior mutability, undefined behavior, data race, guard

## Send
*别名*：std::marker::Send, 可发送  
*出处*：第 1 章 Basics of Rust Concurrency

**作者定义**："A type is Send if it can be sent to another thread. In other words, if ownership of a value of that type can be transferred to another thread." 例如 Arc<i32> 是 Send，Rc<i32> 不是。它是 auto trait；也可用 unsafe impl 手动承诺。

**关键区分**：≠ Sync — Send 管所有权转移，Sync 管共享引用 ≠ 对所有类型自动成立 — 含非 Send 字段（如 Rc）即不成立 = 编译器用来阻止把不安全值移动到其他线程的约束

**为何重要**：下游 skill 设计线程间 API 时，spawn 的闭包捕获、通道消息、Arc 的边界都依赖 Send。必须区分"能移动过去"与"能同时共享"；只加 Send 不能保证共享引用安全，反之亦然。

**相关术语**：Sync, reference counting (Arc/Weak), PhantomData, guard

## Sync
*别名*：std::marker::Sync, 可共享  
*出处*：第 1 章 Basics of Rust Concurrency

**作者定义**："A type is Sync if it can be shared with another thread. In other words, a type T is Sync if and only if a shared reference to that type, &T, is Send." 例如 i32 是 Sync，Cell<i32> 不是；但 Cell<i32> 是 Send。

**关键区分**：≠ Send — 共享引用安全不等于所有权可转移 ≠ 所有 Send 类型都 Sync — Cell 就是反例 = 决定 &T 能否跨线程共享；RwLock<T> 因此额外要求 T: Sync

**为何重要**：下游 skill 在解释 Mutex<T> 只要求 T: Send、RwLock<T> 要求 T: Send + Sync 时，必须用 Sync 的准确定义（&T 是 Send），否则会给出错误的 trait bound 推理。guard 的手动 Send/Sync 实现也依赖这一区分。

**相关术语**：Send, interior mutability, guard, reference counting (Arc/Weak)

## guard
*别名*：lock guard, 锁守卫, MutexGuard, Guard  
*出处*：第 4 章 Building Our Own Spin Lock

**作者定义**："Such a type is often called a guard, as it effectively guards the state of the lock, and stays responsible for that state until it is dropped." 在 Mutex 中，guard "represents the guarantee that we have locked the mutex"；解锁通过 Drop 完成，访问数据通过 Deref/DerefMut。

**关键区分**：≠ 只是 RAII 包装 — 它的存在本身就是"锁已被持有"的安全证明 ≠ 可随意复制或跨线程共享 — 需按 T 的 Send/Sync 约束手动实现 = Deref/DerefMut 提供访问 + Drop 释放锁的类型状态载体

**为何重要**：下游 skill 若把 guard 仅当"自动解锁的小工具"，会漏掉它最重要的设计：构造器私有，因此"拿到 Guard"可作为 unsafe 代码的安全前提。审查 unsafe impl Send/Sync 时也要看 guard 实际代表的是 T 还是锁。

**相关术语**：spin lock, UnsafeCell, Send, Sync

## spin lock
*别名*：SpinLock, 自旋锁  
*出处*：第 4 章 Building Our Own Spin Lock

**作者定义**："A spin lock is a mutex that does exactly that. Attempting to lock an already locked mutex will result in busy-looping or spinning: repeatedly trying over and over again until it finally succeeds." 作者指出它 "can waste processor cycles, but can sometimes result in lower latency when locking"。

**关键区分**：≠ "更快的 mutex" — 只在持锁极短、线程能真正并行时可能更优 ≠ 应无限忙等 — 真实实现常先短暂自旋再交给操作系统睡眠 = 用原子布尔 + Acquire/Release 实现的最小互斥锁

**为何重要**：下游 skill 不应把自旋锁推荐为通用锁替代品。正确边界：临界区极短、竞争低、可并行执行时考虑；持锁可能较久或线程数远超核心数时，自旋会浪费 CPU。它也是讲解 Acquire/Release 与 guard 的最小完整范例。

**相关术语**：guard, Release and acquire ordering, atomic operation

## compare-and-exchange
*别名*：CAS, compare_exchange, compare_exchange_weak, 比较并交换  
*出处*：第 2 章 Atomics

**作者定义**："This operation checks if the atomic value is equal to a given value, and only if that is the case does it replace it with a new value, all atomically as a single operation. It will return the previous value and tell us whether it replaced it or not." weak 版本可能在实际相等时仍虚假失败。

**关键区分**：≠ 仅用于"比较相等" — 它是实现任意原子读-改-写循环的通用原语 ≠ weak 与 strong 等价 — weak 可虚假失败，适合放在重试循环中 = CAS 循环的基础；需配合 ABA 防护

**为何重要**：下游 skill 在实现无溢出计数、一次性初始化、Arc 等场景会反复使用 CAS。必须讲清 weak/strong 的选择与失败语义：weak 失败不代表值变了，循环必须重新读取；strong 失败才意味着不匹配。还要提醒 CAS"成功"也可能基于已被改回的值（ABA）。

**相关术语**：atomic operation, ABA problem, Relaxed

## ABA problem
*别名*：ABA, ABA 问题  
*出处*：第 2 章 Atomics

**作者定义**："If the atomic variable changes from some value A to B and then back to A after the load operation, but before the compare_exchange operation, it would still succeed, even though the atomic variable was changed (and changed back) in the meantime." 作者称 "This is known as the ABA problem."

**关键区分**：≠ 普通的 CAS 失败 — CAS 会"成功"，但依据的旧值已被替换过 ≠ 所有 CAS 场景都要防 — 计数器递增通常无害；原子指针/无锁结构才危险 = "值相等"不等于"期间未被修改过"的经典陷阱

**为何重要**：下游 skill 在审查无锁栈/队列/空闲列表时必须主动检查 ABA。仅说"用 compare_exchange 重试"不够：若指针从 A 变 B 再变回 A，CAS 可能错误成功并导致节点复用/内存破坏。需要标签指针、版本计数或 Hazard Pointer 等方案。

**相关术语**：compare-and-exchange, atomic operation

## reference counting (Arc/Weak)
*别名*：Arc, Weak, 引用计数, atomically reference counted, weak pointer  
*出处*：第 6 章 Building Our Own "Arc"

**作者定义**：Arc 的名字来自 "atomically reference counted"：克隆递增计数器，最后一个 drop 把计数降到零并释放数据。Weak "does not prevent an object from getting dropped"，可通过 upgrade() 尝试升级为 Arc。作者给出的关键顺序是：递增可用 Relaxed；每次递减用 Release，观察到 1→0 后再执行 Acquire fence。

**关键区分**：≠ 普通 Rc — 计数器修改必须是原子操作 ≠ Weak 不需要同步 — Weak 的计数与 upgrade 同样有内存序要求 ≠ 每次递减都要 Acquire — 只有归零那次需要与之前所有递减同步 = 共享所有权 + 用 Weak 打破循环引用的机制

**为何重要**：下游 skill 解释 Arc 的内存序时，必须避免两个常见错误："所有操作都用 SeqCst"和"递增递减都用 Relaxed"。正确结论是递增 Relaxed、递减 Release + 条件 Acquire fence；同时 get_mut 必须检查所有 Arc 和 Weak，不能忽略 Weak 可用于 upgrade。

**相关术语**：Relaxed, Release and acquire ordering, fence, NonNull, ManuallyDrop, Send, Sync

## MaybeUninit
*别名*：std::mem::MaybeUninit, 未初始化存储  
*出处*：第 5 章 Building Our Own Channels

**作者定义**："essentially the bare-bones unsafe version of Option<T>: it requires its user to manually keep track of whether it has been initialized or not, and almost its entire interface is unsafe, as it can’t perform its own checks." 它不会自动 drop 已初始化的内容。

**关键区分**：≠ Option<T> — 不记录初始化状态，也不自动析构 ≠ 初始化后即可安全读取 — assume_init_read 等仍需 unsafe 保证不重复消费非 Copy 值 = 通道等场景中"用外部标志记录是否已初始化"的底层存储

**为何重要**：下游 skill 在实现一次性通道/槽位时，会用"原子布尔 + MaybeUninit"表达"有值/无值"。必须同时处理：发送后未接收时的 Drop、重复读取非 Copy 值、以及初始化与可见性的内存序。把 MaybeUninit 当成 Option 会直接写出 UB 或泄漏。

**相关术语**：UnsafeCell, ManuallyDrop, undefined behavior

## NonNull
*别名*：std::ptr::NonNull, 非空指针  
*出处*：第 6 章 Building Our Own "Arc"

**作者定义**："represents a pointer to T that is never null. That way, an Option<Arc<T>> will be the same size as an Arc<T>, using the null pointer representation for None." 作者同时提醒：使用裸指针或 NonNull 时，编译器会保守地假定类型既不 Send 也不 Sync，除非显式实现。

**关键区分**：≠ 普通引用 — 不携带生命周期/别名保证，有效性需 unsafe 维护 ≠ 自动实现 Send/Sync — 必须手动 unsafe impl = 利用空指针 niche 优化 Option 大小的非空指针

**为何重要**：下游 skill 在实现 Arc 时用 NonNull 既是为了省空间，也是为了表达"始终有效"的不变量。需要强调：NonNull 只保证非空，不保证指向有效内存、不保证别名规则；Send/Sync 必须根据 T 的约束手动实现，否则会意外放行不安全共享。

**相关术语**：reference counting (Arc/Weak), Send, Sync, undefined behavior

## ManuallyDrop
*别名*：std::mem::ManuallyDrop, 手动析构  
*出处*：第 6 章 Building Our Own "Arc"

**作者定义**："A ManuallyDrop<T> takes the exact same amount of space as a T, but allows us to manually drop it at any point by using an unsafe call to ManuallyDrop::drop()" 作者在优化 Arc 时用它替代 Option<T>，因为 Arc 的存在与否已足以表示数据是否还在。

**关键区分**：≠ MaybeUninit — 它持有已初始化的 T，只是禁止自动 drop ≠ 忘记 drop 就是 UB — 忘记最多泄漏，而泄漏在 Rust 中是安全的 = 需要精确控制析构时机、且不需要额外状态位的场景

**为何重要**：下游 skill 在讲"用类型系统缩小 unsafe 核心"时，ManuallyDrop 是常见手段：去掉 Option 的状态位，由外部不变量（如引用计数归零）决定何时 drop。必须说明正确性依赖该不变量，且 Drop 路径不能遗漏。

**相关术语**：MaybeUninit, reference counting (Arc/Weak), unsafe-building-block

## cache line
*别名*：cacheline, 缓存行  
*出处*：第 7 章 Understanding the Processor

**作者定义**："In most processor architectures, the cache reads and writes memory in blocks of 64 bytes, even if only a single byte was requested. These blocks are often called cache lines." 缓存一致性协议以 cache line 为单位工作，而不是按单个变量或字节。

**关键区分**：≠ 单个变量 — 相邻且无关的变量也可能共享同一 cache line ≠ 64 字节是规范保证 — 作者称 64 字节是 "a reasonable guess" = 解释伪共享与原子操作性能的物理单位

**为何重要**：下游 skill 诊断性能问题时，不能只按变量逻辑关系分析。两个线程分别访问不同变量仍可能因同一 cache line 而互相拖慢；反之，同一变量被多线程频繁写也会因独占权转移而变慢。缓存行是连接"代码逻辑"与"硬件性能"的关键层级。

**相关术语**：MESI cache coherence, false sharing, atomic operation

## MESI cache coherence
*别名*：MESI, cache coherence protocol, 缓存一致性协议, MOESI, MESIF  
*出处*：第 7 章 Understanding the Processor

**作者定义**："The MESI cache coherence protocol is named after the four possible states it defines for a cache line: modified, exclusive, shared and invalid." 写操作需要独占 cache line；其他核心的共享副本会转为 invalid。作者还讨论了 write-through、MOESI、MESIF 等变体。

**关键区分**：≠ 影响程序正确性 — 作者说一致性缓存只造成时序差异，不改变单线程可见结果 ≠ 唯一的缓存一致性协议 — 不同架构/处理器/层级使用不同变体 = 解释"一次写为何拖慢其他核心读"的抽象模型

**为何重要**：下游 skill 解释原子操作性能、伪共享、自旋锁退避时，需要这一模型说明"写要拿独占权、会让别人副本失效"。但必须同时强调：缓存一致性不替程序员解决内存序问题，指令重排等仍可能破坏正确性。

**相关术语**：cache line, false sharing, atomic operation

## false sharing
*别名*：伪共享  
*出处*：第 7 章 Understanding the Processor

**作者定义**：当无关变量落在同一 cache line 时，作者描述：'The processor core running the background thread repeatedly claims exclusive access to the cache line(s) containing A[0] and A[2], which also contains A[1], slowing down "unrelated" operations on A[1].' 并明确 "This effect is called false sharing."

**关键区分**：≠ 逻辑上的数据共享 — 变量彼此独立，纯物理布局问题 ≠ 只发生在同一变量上 — 相邻变量同样会互相拖慢 = 用 #[repr(align(64))]/padding 让变量各占 cache line 可缓解

**为何重要**：下游 skill 做性能排查时，若只看"两个线程是否访问同一变量"，会漏掉伪共享。需要检查数据结构布局：高频写的计数器/标志是否与只读数据相邻；基准测试中是否因对齐而意外共享 cache line。

**相关术语**：cache line, MESI cache coherence, atomic operation

## LL/SC
*别名*：load-linked/store-conditional, ldxr/stxr, 链接加载/条件存储  
*出处*：第 7 章 Understanding the Processor

**作者定义**："a load-linked/store-conditional (LL/SC) loop"；其中 "the store is conditional: it refuses to store to memory if any other thread has overwritten that memory since the load-linked instruction." RISC 架构用它实现原子读-改-写，失败则重试。

**关键区分**：≠ x86 的 lock 前缀/CAS 指令 — 是另一套硬件机制 ≠ 只能实现 add — 两指令之间可放任意操作 ≠ 总能一次成功 — 循环可能反复失败；ARMv8.1 起有 LSE 单指令替代部分操作 = ARM64 等 RISC 架构上实现 fetch_add/CAS 的底层模式

**为何重要**：下游 skill 做跨架构性能/正确性排查时，需要知道同一 Rust 原子操作在 x86-64 与 ARM64 上映射不同：ARM 上 CAS 常表现为 LL/SC 重试循环，失败率与两指令之间的工作量有关。这解释了"x86 上正常、ARM 上偶发"的部分现象。

**相关术语**：compare-and-exchange, atomic operation, cache line

## futex
*别名*：fast user-space mutex, FUTEX_WAIT, FUTEX_WAKE, SYS_futex  
*出处*：第 8 章 Operating System Primitives

**作者定义**：名称来自 "fast user-space mutex"。核心操作是 FUTEX_WAIT / FUTEX_WAKE：等待操作带一个期望值，"will refuse to block if it doesn’t match"，且检查与睡眠相对于 wake 是原子的，因此不会丢唤醒。内核只记录哪些线程在哪个地址等待，不在原子变量里存状态。

**关键区分**：≠ 一把内核实现的互斥锁 — 它只是以地址为键的等待/唤醒机制 ≠ 每次加锁都进内核 — 快路径在用户态，只有真正需要阻塞时才调用 ≠ 会把状态写进原子变量 — 状态由用户态协议维护 = Linux 上构建 Mutex/Condvar/RwLock 的底层原语

**为何重要**：下游 skill 解释"为什么 Mutex 快路径不慢"时必须用 futex 的模型：用户态 CAS 尝试，失败才进入内核等待。审查 wait/wake 代码时要检查"改状态再 wake"的顺序与期望值参数，否则会丢唤醒或永久睡眠。

**相关术语**：WaitOnAddress, condition variable, spin lock, priority inversion

## WaitOnAddress
*别名*：WakeByAddressSingle, WakeByAddressAll, 地址等待  
*出处*：第 8 章 Operating System Primitives

**作者定义**：Windows 的地址等待机制："compares the value of the atomic variable with the expected value, and goes to sleep if they match, waiting for a corresponding wake operation. The check and sleep operation happens atomically with respect to wake operations, meaning no wake signal can get lost in between." 唤醒用 WakeByAddressSingle / WakeByAddressAll。

**关键区分**：≠ 仅支持 32 位 — 支持 8/16/32/64 位原子变量 ≠ 一把现成的锁 — 是构建自定义原语的通用等待/唤醒积木 = Windows 上对应 Linux futex 角色的机制

**为何重要**：下游 skill 做跨平台并发实现时，不能把 futex 当成唯一抽象。需要知道 Windows 用 WaitOnAddress 家族提供同等的"带期望值检查的等待 + 按地址唤醒"，从而设计可移植的等待/唤醒封装，而不是在各平台重复实现不同协议。

**相关术语**：futex, condition variable, release and acquire ordering

## priority inversion
*别名*：优先级反转, priority inheritance  
*出处*：第 8 章 Operating System Primitives

**作者定义**：'Priority inversion is a problem that occurs when a high-priority thread is blocked on a lock held by a low-priority thread. The high-priority thread effectively has its priority "inverted," since it now has to wait for the low-priority thread to release the lock before it can make progress.' 解决方式是优先级继承：持锁线程临时继承最高等待者的优先级。

**关键区分**：≠ 普通锁竞争 — 问题是优先级语义被反转，高优先级任务可能被中优先级任务间接无限期拖延 ≠ 纯用户态就能普遍解决 — 通常需要内核/调度器配合（如 PI futex） = 实时系统中"逻辑正确但违反调度保证"的典型退化

**为何重要**：下游 skill 若面向实时/嵌入式场景，不能只检查数据竞争与死锁。优先级反转会让高优先级线程错过截止时间；需要识别 PI mutex、优先级继承协议，或在设计上避免跨优先级共享锁。

**相关术语**：futex, spin lock, writer starvation

## thundering herd
*别名*：惊群, thundering herd problem  
*出处*：第 9 章 Building Our Own Locks

**作者定义**："after waking up, all those threads will immediately try to lock the same mutex. Most likely, only one thread will succeed, and all the others will have to go back to sleep. This resource-wasting problem of many threads all rushing to claim the same resource is referred to as the thundering herd problem."

**关键区分**：≠ 唤醒丢失或正确性 bug — 它是性能退化 ≠ notify_all 永远错误 — 但在"只有一个线程能继续"的场景常是反模式 = 可用 FUTEX_REQUEUE 把等待者转移到互斥锁上，避免无效唤醒

**为何重要**：下游 skill 优化 Condvar/等待队列时，不能只追求"唤醒所有等待者"的简单实现。需要区分 notify_one/notify_all 的语义与惊群代价；在支持 requeue 的平台可把等待者直接转到锁上，减少"醒来又睡下"的浪费。

**相关术语**：condition variable, futex, writer starvation

## writer starvation
*别名*：写者饥饿, writer starvation  
*出处*：第 9 章 Building Our Own Locks

**作者定义**："a situation where the writer(s) never get a chance to lock the RwLock because there are always readers around to keep the RwLock read-locked." 作者给出的修复是：有写者等待时阻止新读者获取锁，即使当前仍处于读锁状态；实现上需要额外状态位来记录「有写者等待」。

**关键区分**：≠ 死锁 — 系统仍在推进，只是写者永远轮不到 ≠ 靠"读者优先"能避免 — 恰恰是读者优先导致 = 需要额外状态（如 reader count ×2 + waiting 位）来优先等待中的写者

**为何重要**：下游 skill 审查 RwLock 实现时，不能只验证"读读可并发、读写互斥"。读多写少场景下，读者持续到来会让写者永远饥饿；需要检查实现是否在新读者到达时查看等待写者，并正确编码状态位，避免把"正确但饿死"当成通过。

**相关术语**：condition variable, thundering herd, priority inversion

