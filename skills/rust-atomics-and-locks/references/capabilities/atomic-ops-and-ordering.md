# 原子操作与内存序选型

## R — 原文

> "This chapter only covers situations where relaxed memory ordering suffices, which is the case more often than one might expect."
> — Chapter 2, Introduction

> "A happens-before relationship is formed when an acquire-load operation observes the result of a release-store operation."
> — Chapter 3, "Release and Acquire Ordering"

> "It is advisable to see SeqCst as a warning sign."
> — Chapter 3, "Common Misconceptions"

中文翻译（自译）：

> 本章只覆盖宽松内存序就足够的场景；这种情况比多数人想象的更常见。
>
> 当 acquire-load 观察到 release-store 的结果时，就形成了一条 happens-before 关系。
>
> 建议把 SeqCst 当作一个警告信号。

## I — 自述

这本书反复强调的是：**先问"需不需要跨线程顺序"，再问"需要多强"**，而不是默认 SeqCst。

- 原子性只保证单次操作不可分割；它不自动带来跨变量顺序。
- Relaxed 仍然保证每个原子变量的"修改全序"——所有线程看到的该变量修改顺序一致。只是它不建立跨变量的 happens-before。
- 因此，如果两个线程只通过一个原子变量交换信息（停止标志、进度计数、ID 分配），Relaxed 往往足够。
- 一旦"先准备数据、再通知对方"，就需要 Release-store 与 Acquire-load 配对；配对的条件是 acquire 读到了 release 写的那次修改。
- 多个变量需要一起可见时，要么把它们放进同一个锁保护，要么用 fence；fence 还能按条件放置。
- SeqCst 提供全局全序，但几乎总是超出需要，并且让审查者必须考虑程序里所有 SeqCst 操作。
- fetch_add/fetch_sub 会静默回绕；需要严格上限时，必须用 CAS 在"加之前"检查。

选型的本质是：**用最弱但仍能证明数据不被并发读写的顺序**。

## A1 — 应用示例（原书案例：c16）

场景：后台线程准备好 64 位数据 `DATA`，主线程轮询 `READY` 标志，看到后读取 `DATA`。

执行（Ch.3 "Release and Acquire Ordering"）：

```rust
static DATA: AtomicU64 = AtomicU64::new(0);
static READY: AtomicBool = AtomicBool::new(false);

// 后台线程
DATA.store(123, Relaxed);
READY.store(true, Release);      // 之前的一切，对读到 true 的一方可见

// 主线程
while !READY.load(Acquire) { /* sleep */ }
println!("{}", DATA.load(Relaxed)); // 必定是 123
```

结果：最后一行只可能打印 123。若全部使用 Relaxed，主线程可能看到 `READY=true` 却读到 `DATA=0`。

可迁移的教训：**发布数据用 Release/Acquire 配对；数据本身在 HB 建立后可以用 Relaxed 读。**

## A2 — 触发场景

1. 写了一段原子代码，不确定该用 `Relaxed`、`Acquire/Release` 还是 `SeqCst`。
   - 语言信号："这个 Ordering 选哪个"、"要不要 Release"、"Relaxed 够不够"、"why Acquire"、"memory ordering for..."
2. 代码在 x86 上正常，担心 ARM 上出问题。
   - 语言信号："x86 上没问题"、"换 M1 会不会挂"、"weakly ordered"。
3. 需要实现停止标志、进度上报、一次性初始化、ID 分配、计数器。
   - 语言信号："原子计数器"、"stop flag"、"lazy init"、"unique id"、"fetch_add 溢出"。
4. 审阅时看到大量 `SeqCst`，想知道能否降级。
   - 语言信号："SeqCst 能不能换成 Acquire"、"是不是过度同步"。
5. 多个原子变量需要一起可见，考虑要不要 fence。
   - 语言信号："fence 放哪"、"两个变量顺序"、"release fence / acquire fence"。

**与相邻能力区分**：
- 如果用户给的是**一段已写好的代码**并要求"找 bug / 有没有 UB"，用 `concurrency-safety-review`，不要用本能力做全面审查。
- 如果用户问的是**性能为什么慢**（伪共享、cache line、基准），用 `atomic-performance-and-portability`。
- 如果用户要**实现 Arc/锁/通道**，本能力只负责其中的顺序选择，具体实现见对应能力。

## E — 执行步骤

**输入契约**：至少给出（a）共享变量及其类型；（b）每个线程的访问序列；（c）想建立的保证（可见性/互斥/计数/初始化）。缺 (b) 时先追问访问顺序，不能猜。

1. **标注每个访问**：load / store / fetch_* / CAS；单变量还是多变量；是否读写"被发布的数据"。
   - 完成标准：得到一张"线程 × 操作 × 变量"的表。
2. **判断是否需要跨线程 HB**：
   - 不需要（只关心单个变量的最终计数/标志）→ `Relaxed`。
   - 需要（A 写的数据必须被 B 看到）→ 进入第 3 步。
3. **建立发布-订阅配对**：
   - 发布方：在写完数据后 `store(..., Release)`（或 CAS/fetch 的成功序用 Release）。
   - 订阅方：`load(..., Acquire)`；若失败路径也会读已发布数据，则 CAS 的 failure ordering 也必须是 `Acquire`。
   - 完成标准：能指出"哪次 store 与哪次 load 配对、读到哪个值才成立"。
4. **处理多变量/条件顺序**：
   - 多个变量必须一起可见 → 优先把数据放进同一个锁；不能用锁时用 `fence(Release)` / `fence(Acquire)`。
   - 只有某分支需要顺序 → 先 Relaxed load，再在分支内放 acquire fence。
5. **仅在确需全局全序时使用 SeqCst**：要求所有相关操作进入同一个全局顺序；HB 双方都必须是 SeqCst。
   - 判停：若无法说明"为什么非全局序不可"，改回 Release/Acquire。
6. **检查溢出与 ABA**：
   - `fetch_add/fetch_sub` 会回绕；需要上限时用 CAS 在加之前检查（或 abort / 回滚）。
   - 值从 A→B→A 的场景（尤其指针）要考虑 ABA。
7. **输出决策表**：每个操作一行：`操作 | Ordering | 与谁配对 | 证明了什么 | 残余风险`。
   - 完成标准：表中每个非 Relaxed 顺序都有明确配对对象；每个 Relaxed 都能说明"不需要跨变量顺序"。

**输出契约**：决策表 + 一段 happens-before 论证 + 需要补的测试（弱序设备/Miri）。

## B — 边界

- **不要**用于 async/await、分布式或跨进程一致性；本书模型只覆盖线程 + 共享内存。
- **不要**把 SeqCst 当"保险"：它不能修复本身错误的算法，还会扩大审查范围。
- **不要**因为"x86 上跑对了"就认为顺序正确；x86-64 强序会掩盖缺失的 HB。
- **不要**用 fence 替代锁来保护复合不变量；fence 只排序，不提供互斥。
- **不要**假设 Relaxed 是"延迟可见"；内存序不描述时间。
- 相邻易混：`concurrency-safety-review` 负责找已存在代码的缺陷；`atomic-performance-and-portability` 负责性能与跨架构验证。
- 作者盲点：书中默认读者能自行完成 HB 论证；实际应把论证写出来并请人复核。
