# 原子代码性能诊断与可移植性

## R — 原文

> "We can avoid this by spacing the atomic variables further apart, so they each get their own cache line."
> — Chapter 7, "Impact on Performance"

> "As mentioned before, 64 bytes is a reasonable guess for the size of a cache line, so let's try wrapping our atomics in a 64-byte aligned struct, as follows:"
> — Chapter 7, "Impact on Performance"

中文翻译（自译）：

> 可以通过把原子变量间隔开、让它们各自独占一条缓存行来避免这个问题。
>
> 如前所述，64 字节是缓存行大小的合理猜测，所以可以试着把原子包进一个 64 字节对齐的结构体。

## I — 自述

原子代码的性能很少由"指令条数"决定，主要由两件事决定：**缓存一致性**与**系统调用**。

- **伪共享（false sharing）**：两个无关变量落在同一条 cache line；一个核心写，会让另一个核心的读反复失效。修复：`#[repr(align(64))]` 填充或调整布局。
- **失败的 CAS 也不便宜**：`compare_exchange` 无论成败都可能申请独占 cache line。自旋等待时先 `load` 检查，再 CAS。
- **缓存行大小**：通常 64 字节，但某些平台需 128 字节；必须实测。
- **基准方法**：用 `std::hint::black_box` 防止循环被优化掉；把变量引用传给 `black_box`，让编译器不敢假设"没有其他线程"；必须在 release 模式、真实硬件上测。
- **跨架构**：x86-64 强序，acquire/release 与 relaxed 指令相同，SeqCst 只有 store 需要 `xchg`；ARM64 弱序，acquire/release 用 `ldar/stlr`，与 SeqCst 同价。**在 x86 上"跑对"不能证明顺序正确**；用 `compiler_fence` 故意制造错误，可以在 M1 等弱序机器上复现丢失更新。
- **验证手段**：弱序设备、交叉编译、Miri、压力测试。

## A1 — 应用示例（原书案例：c38）

```rust
#[repr(align(64))]
struct Aligned(AtomicU64);

static A: [Aligned; 3] = [
    Aligned(AtomicU64::new(0)),
    Aligned(AtomicU64::new(0)),
    Aligned(AtomicU64::new(0)),
];
```

书中实验：主线程反复读 `A[1]`，后台线程写 `A[0]`/`A[2]`。未对齐时，因三者共享 cache line，读耗时从约 300ms 涨到数秒；对齐后恢复到约 300ms。

另一实验（c40）：把自旋锁的 Acquire/Release 换成 Relaxed + `compiler_fence`，x86 与部分 ARM 设备仍输出 4000000，而 Apple M1 输出约 3988255——错误只在弱序架构暴露。

## A2 — 触发场景

1. 原子/并发代码比预期慢，怀疑伪共享。
   - 语言信号："性能上不去"、"多线程反而更慢"、"false sharing"、"cache line"。
2. 想写一个可信的原子操作基准。
   - 语言信号："基准怎么写"、"循环被优化掉了"、"black_box"。
3. 代码在 x86 正常、ARM/CI 偶发失败。
   - 语言信号："x86 没问题 M1 挂"、"weak memory"、"cross-arch"。
4. 想知道某种 Ordering 在目标架构上的成本。
   - 语言信号："Acquire 贵不贵"、"SeqCst 开销"、"x86 vs ARM"。

**与相邻能力区分**：
- 要**决定用哪个 Ordering** → `atomic-ops-and-ordering`。
- 要**审查正确性/UB** → `concurrency-safety-review`。
- 本能力只在"已知正确、但慢或跨平台可疑"时使用。

## E — 执行步骤

**输入契约**：代码 + 目标硬件/架构 + 观测到的现象（延迟、吞吐、平台差异）+ 基准方法。缺硬件信息时先问。

1. **先确认正确性**：用 `concurrency-safety-review` 排除 UB；性能优化不能建立在错误代码上。
2. **定位热点**：区分 syscall（strace/perf）、缓存失效（perf c2c）、伪共享（布局检查）。
3. **写可信基准**：release 模式；`black_box(&var)` + `black_box(result)`；固定线程数与亲和性；重复多次取中位数。
4. **验证伪共享**：把疑似变量用 `#[repr(align(64))]` 隔离；对比前后；若平台需要，试 128 字节。
5. **减少独占申请**：自旋先用 `load`，失败再 CAS；避免在循环里反复 `compare_exchange`/`swap`。
6. **跨架构验证**：用 `--target aarch64-...` 看汇编；在弱序设备或模拟器上跑压力测试；必要时用 Miri。
7. **输出报告**：现象 → 证据（基准/汇编/perf）→ 修改 → 修改后数据 → 适用边界。
   - 完成标准：每个结论都有目标硬件上的数据；明确"结论不保证迁移"。

**输出契约**：诊断结论 + 可复现基准 + 修复补丁 + 平台边界说明。

## B — 边界

- **不要**在没有目标硬件数据时给"固定加速比"或"固定阈值"。
- **不要**用 debug 构建验证内存序问题；优化会改变指令窗口。
- **不要**把伪共享修复当成万能：相关变量放在一起有时反而更好。
- **不要**在 x86 上通过就宣布可移植；必须弱序验证。
- **不要**为微基准优化牺牲真实负载表现。
- 相邻易混：`atomic-ops-and-ordering` 负责"是否合法"，本能力负责"是否快/是否可移植"。
- 作者盲点：基准数字来自作者机器；新一代 CPU 的 cache/预取行为可能不同。
