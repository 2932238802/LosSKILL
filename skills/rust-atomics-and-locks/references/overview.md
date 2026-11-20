# Rust Atomics and Locks — 整书理解 (阶段 0 产出)

> 本文档是 cangjie-skill 流水线的阶段 0 产出, 后续所有 extractor 和 skill 都以此为全局上下文。

## 基本信息

- **标题**: Rust Atomics and Locks: Low-Level Concurrency in Practice
- **作者**: Mara Bos（Rust 标准库团队成员，曾任 Rust 库团队负责人）
- **出版/发布时间**: O'Reilly, 2023（代码基于 Rust 1.66.0, 2022-12-15）
- **内容类型**: 书籍（技术实操手册 + 原理讲解）
- **版本来源**: 作者官方免费在线版 `http://mara.nl/atomics/`（原 PDF 已删除；逐章下载 12 个 HTML 并转为纯文本，存于 `text/`）
- **处理时间**: 2026-11-19

---

## 1. 结构 (Structural)

### 类型
低层并发实操手册：以"自己实现并发原语"为主线，穿插内存模型、处理器与操作系统原理。

### 一句话主旨
讲清原子操作、内存序、缓存/处理器行为与操作系统原语，使读者能亲手实现并安全封装锁、通道、引用计数等并发原语，并在安全性与性能之间做出有依据的取舍。

### 骨架 (主要论点及其关系)

1. **Rust 并发基础**：线程、作用域线程、共享所有权、借用与数据竞争、内部可变性、Send/Sync、Mutex/RwLock、park 与 Condvar。
2. **原子类型与操作**：load/store、fetch-and-modify、compare-and-exchange；许多真实场景只需 Relaxed。
3. **内存序**：happens-before、Relaxed、Release/Acquire、SeqCst、fence、consume、常见误区。
4. **用原子与类型系统实现原语**：自旋锁 → 一次性通道 → Arc/Weak，安全边界逐步收紧。
5. **处理器层**：x86-64 与 ARM64 指令、LL/SC、缓存一致性、伪共享、指令重排、内存屏障。
6. **操作系统原语**：pthread、Linux futex、macOS、Windows（SRWLock、WaitOnAddress）。
7. **组合实现锁**：Mutex、Condvar、RwLock 的从最小可用到逐步优化（少系统调用、自旋、避免惊群与写者饥饿）。
8. **延伸方向**：信号量、RCU、无锁链表、队列锁、parking lot、seqlock。

**论点之间的关系**：递进 + 理论/实践往返。第 1–3 章建立语言与内存模型；第 4–6 章用理论造原语；第 7–8 章下沉到硬件与内核；第 9 章再回到实现并做性能取舍；第 10 章外推。

### 作者要解决的核心问题
在不引入未定义行为的前提下，让多个线程安全地共享可变数据并通信；具体化为三个决策：**用哪种原子操作、用哪个内存序、什么时候必须求助内核**，以及如何把这些决定封装成难以误用的 Rust API。

---

## 2. 解释 (Interpretive)

### 关键术语 (作者本人的用法)

| 术语 | 作者的定义 | 和常识用法的差异 |
|---|---|---|
| atomic operation | 不可分割：要么完整发生，要么尚未发生 | 不等于"快"，也不保证跨变量顺序 |
| data race vs race | data race = 并发非原子访问且至少一方写 → UB；race = 结果不确定但安全 | 日常说的"竞争"多半是后者；前者在 safe Rust 中不可能 |
| happens-before | 内存模型唯一定义的顺序关系；跨线程只在 spawn/join、解锁/加锁、acquire-release 配对、SeqCst 全序等情形出现 | 不是"时间上更早"，也不由"读到了某值"自动推出 |
| total modification order | 每个原子变量各自的修改全序，所有线程一致 | Relaxed 也保证；但不保证跨变量顺序 |
| Relaxed | 不建立跨线程 HB，只保证单变量一致性 | 不是"可能永远看不到"；与"延迟"无关 |
| Release / Acquire | store/load 配对；acquire 读到 release 存的值时建立 HB | 不是锁的专利；普通数据也可借此发布 |
| SeqCst | 所有 SeqCst 操作构成单一全局全序 | 作者视其为"警报信号"而非默认选项 |
| fence | 把内存序与具体原子操作解耦；可覆盖多变量或按条件生效 | 不能把 SeqCst 操作拆成 relaxed + fence |
| undefined behavior (UB) | 编译器可假设永不发生；可"倒流"影响之前的代码 | unsafe 不等于 UB；unsound 才是违反规则 |
| interior mutability | 通过共享引用修改，底层是 UnsafeCell | 只放宽共享借用，不放宽独占借用 |
| guard | 其存在即证明锁已被持有的类型；Deref/DerefMut + Drop | 不只是"RAII 包装"，还是安全证明载体 |
| spin lock | 忙等式互斥锁；用 spin_loop hint 提示处理器 | 不是"更快的 mutex"；只在极短持锁时有优势 |
| reference counting / weak | 共享所有权；Weak 不阻止对象销毁 | Arc 的递增可用 Relaxed，最后递减必须 Acquire |
| false sharing | 无关联变量落在同一 cache line 相互拖慢 | 与逻辑无关，纯物理布局问题 |
| futex / WaitOnAddress | 以地址为键的内核等待/唤醒，带期望值检查避免丢唤醒 | 快路径在用户态，内核只在真需要阻塞时介入 |
| writer starvation / thundering herd / priority inversion / ABA | 写者饿死 / 惊群 / 优先级反转 / CAS 的 ABA 问题 | 都是"正确但退化"或"看似正确实则错误"的典型 |

### 核心命题 (用自己的话)

1. 所有高层并发原语（Mutex、Condvar、Channel、Arc）都由原子操作搭建；理解原子操作就理解了它们的地基。
2. 绝大多数场景只需 Relaxed 或 Release/Acquire；SeqCst 几乎不必要，且会扩大代码审查的推理范围。
3. 正确性由 happens-before 定义，而不是由"多久能看到"或"是否立即可见"定义。
4. Rust 的类型系统可以把大量协议不变量前移到编译期（Send/Sync、生命周期、所有权、非 Copy 消费、借用拆分）。
5. 安全边界应尽量收缩到最小的 unsafe 核心，再用 guard、类型状态、PhantomData 等包装成安全接口。
6. 引用计数的递增可用 Relaxed；最后一次递减必须与之前所有递减同步（Release 递减 + 条件 Acquire fence）。
7. 性能主要由缓存一致性和系统调用决定，而非指令条数：避免伪共享、避免无谓唤醒、短暂自旋后再睡眠。
8. 内存序错误可能在 x86-64 上"侥幸正确"，在 ARM64 上暴露；需在弱序架构或 Miri 下验证。
9. 多个原子变量需要保持一致时，要么用锁（哪怕临时自旋锁），要么设计专门协议（如 Arc::get_mut 用锁位）。
10. 真正阻塞必须借助内核；futex 类原语让用户态承担快路径，内核只处理慢路径。

### 论证链
作者先建立"借用规则 → 数据竞争 → UB"的语言基础，再给出原子操作与内存序的抽象规则；随后每一章都按"最小实现 → 暴露不安全接口 → 运行时检查 → 类型级保证 → 性能优化"的路径实现一个原语，并用 happens-before 图证明并发访问不重叠；最后下沉到汇编、缓存协议与 OS 系统调用来解释性能差异，并用基准实验验证取舍。

---

## 3. 批判 (Critical) ★

### 作者的时代局限
- 代码基准为 Rust 1.66（2022），标准库内部实现（Mutex/RwLock 的平台细节）、Miri 能力、`atomic-wait` crate 版本都会演进；书中对 std 具体实现的描述是版本绑定的。
- 未覆盖 async/await、异步运行时、loom 等模型检查工具；对 ARMv9、RISC-V 等新架构着墨有限。
- 性能数字来自作者手头的几台机器，硬件代际差异会使结论变化。

### 作者的立场盲点
- 视角是系统/底层工程师：假设读者会读汇编、写 unsafe、能为性能投入大量工程成本；对应用层开发者"直接用 std 就够"的现实关注不足。
- 主要讨论线程模型，未讨论 actor、 CSP 之外的并发范式，也未讨论分布式/跨进程一致性。
- 对"手写原语"的风险强调充分，但对"为什么大多数项目不该手写"的劝退力度不够。

### 未被证明的假设
- 假设读者能正确把 happens-before 推理落到代码上；实际这是最容易出错的一步。
- 假设基准测试结论可迁移到真实负载（作者自己多次承认"it depends"）。
- "SeqCst 是警报信号"在代码审查语境成立，但在正确性优先、性能不敏感的简单场景，SeqCst 反而可能是更稳妥的默认。
- 假设 unsafe 封装的收益大于维护成本；对长期维护与团队能力差异讨论不足。

### 最强反对意见
对绝大多数应用开发者，标准库的 `Mutex`、`RwLock`、`Arc`、通道已经正确且足够快；手写原语的主要产出往往是难以复现的竞态 bug。本书的最大价值是**理解与审查**（能读懂、能证明、能定位），而不是鼓励替换 std。此外，x86-64 上的性能直觉会系统性低估弱序架构的代价与错误概率。

> **以上批判会直接成为下游 skill 的 Boundary (B) 字段来源**

---

## 4. 应用潜力 (Applicability)

### 可 skill 化的内容
- [ ] 按使用场景选择原子操作与内存序（决策程序）
- [ ] 审查/证明并发代码的 happens-before（检查清单 + 反例）
- [ ] 实现自旋锁与锁守卫（SpinLock + Guard）
- [ ] 实现一次性通道并渐进收紧安全接口
- [ ] 实现 Arc/Weak（计数器、顺序、溢出、get_mut、ABA 防护）
- [ ] 诊断伪共享并正确基准测试原子操作
- [ ] 用 futex 类原语实现 Mutex/Condvar/RwLock（含优化路径）
- [ ] 设计安全并发 API（Send/Sync、PhantomData、guard、split borrow、消费 self）
- [ ] 把内存序映射到 x86-64/ARM64 指令并做可移植性排查
- [ ] OS 原语选型（pthread / futex / SRWLock / WaitOnAddress）

### 不适合 skill 化的内容
- 章节叙事与作者经历；第 10 章的延伸阅读书单（作为 references 保留）；逐条汇编列表（作为硬件排查 skill 的示例保留）。

### 预估 skill 数量
**约 8–10 个能力单元**（阶段 1.5 决定保留，阶段 1.6 与输出模式决定独立入口数量，不硬凑）。

### 原书关键任务清单（覆盖审计基准，不从旧 verified 反推）

| task_id | 读者任务 | 原文位置/图表 | 预期交付物 | 重要性及依据 | 尚缺条件 |
|---|---|---|---|---|---|
| T01 | 为停止标志/进度上报等简单共享状态选用 load/store 与 Relaxed | Ch.2 "Atomic Load and Store Operations" | 可编译的原子类型与操作选择 | 最常见场景，选错要么过度同步要么不安全 | 无 |
| T02 | 用 fetch_add/fetch_max 汇总多线程统计并处理溢出 | Ch.2 "Fetch-and-Modify Operations" / "ID Allocation" | 计数器实现 + 溢出策略 | 统计与 ID 分配极常见，溢出是真实缺陷 | 无 |
| T03 | 用 compare_exchange 实现无溢出的原子更新 / 一次性初始化 | Ch.2 "Compare-and-Exchange" / "Lazy One-Time Initialization" | CAS 循环或 fetch_update | CAS 是通用原语，ABA 与 weak 版本需辨析 | 无 |
| T04 | 判断何时必须用 Release/Acquire 而非 Relaxed | Ch.3 "Release and Acquire Ordering" | 内存序选择及 happens-before 论证 | 发布数据/锁的核心，错误仅在弱序架构暴露 | 无 |
| T05 | 用 fence 合并多个操作的顺序或做条件排序 | Ch.3 "Fences" | fence 放置方案与正确性说明 | 高性能数据结构常用；SeqCst 不能拆分 | 无 |
| T06 | 审查一段并发代码的内存序并指出错误 | Ch.3 "Common Misconceptions" + Ch.7 "An Experiment" | 问题清单 + 修正方案 | 代码审查是最高频真实任务 | 需读者代码输入 |
| T07 | 实现 SpinLock<T> 并提供安全 guard 接口 | Ch.4 全章 | SpinLock + Guard + Drop/Deref 实现 | 最小完整锁示例，串起 Ch.2–3 全部概念 | 无 |
| T08 | 实现一次性通道并逐步消除 unsafe | Ch.5 全章 | Channel/Sender/Receiver 实现 | 展示"运行时检查→类型检查"的完整演进 | 无 |
| T09 | 实现 Arc/Weak 并解释每个内存序选择 | Ch.6 全章 | Arc/Weak 实现 + 测试 | 最难的顺序推理；接近 std 实现 | 无 |
| T10 | 诊断伪共享并设计基准测试 | Ch.7 "Caching" / "Impact on Performance" | 基准代码 + 对齐方案 + 数据 | 性能问题高频且难自查 | 需目标硬件 |
| T11 | 把内存序映射到 x86-64/ARM64 并排查可移植性 | Ch.7 "Memory Ordering" / "An Experiment" | 指令对照表 + 验证方案 | 解释"为何本机没事、上线出事" | 需交叉编译/设备 |
| T12 | 用 wait/wake 实现 Mutex 并逐步优化 | Ch.9 "Mutex" | Mutex + 状态机 + 优化说明 | 真实锁实现；涉及系统调用与自旋取舍 | 需 atomic-wait/futex |
| T13 | 实现 Condvar 并处理丢唤醒/惊群 | Ch.9 "Condition Variable" | Condvar 实现 + 测试 | 条件变量是最易写错的同步原语之一 | 无 |
| T14 | 实现 RwLock 并避免写者饥饿 | Ch.9 "Reader-Writer Lock" | RwLock + 状态编码 + 优化 | 读多写少场景常见，饥饿是隐蔽缺陷 | 无 |
| T15 | 设计安全并发 API（Send/Sync/PhantomData/guard/split） | Ch.1 "Thread Safety" / Ch.4–5 | API 设计与 trait 约束说明 | 把协议不变量前移到编译期 | 无 |
| T16 | 选择 OS 原语并解释跨平台差异 | Ch.8 全章 | 选型表 + 平台注意事项 | 跨平台实现碰到的第一道坎 | 需目标平台 |

### 优先级排序 (按"最能赋能普通人"的角度)
1. T04/T06 内存序选择与审查（最高频、最易错、收益最大）
2. T15 安全并发 API 设计（把错误挡在编译期）
3. T09 Arc/Weak（共享所有权无处不在，顺序推理最难）
4. T07 自旋锁与 guard（最小完整范例）
5. T12–T14 锁/条件变量/RwLock（理解 std 行为与性能取舍）
6. T08 通道（类型状态设计范式）
7. T10–T11 伪共享与硬件映射（性能排查）
8. T01–T03 原子操作基础（构成上述能力的前置）
9. T16 OS 原语选型（参考性）

---

## ✅ 质量门检查

- [x] 主旨能用一句话说清
- [x] 骨架列出 3–7 个一级论点（合并为 8 个阶段，可按需归并）
- [x] 术语按实际内容列出，不凑数量
- [x] 已检查作者局限/假设；无依据时标待核查，不编造
- [x] 原书关键任务有来源、交付物与重要性依据
- [ ] 已向用户展示并得到确认

**用户确认时间**: 待确认
