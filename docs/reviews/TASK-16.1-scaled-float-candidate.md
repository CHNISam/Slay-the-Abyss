# TASK-16.1：Random 缩放 float 的隔离候选

2026-10-23，基线 `94c1045`。扩展 `tools/candidates/sts_random.lua`，不改变 RandomXS128 原语，不接入生产 RNG、地图、商店、EnemyAI 或任何存档。继续采用显式 Lua 方法名，不根据参数数量或 Lua number 猜 Java 重载。

## 固定来源及证据等级

- [STS Random.java，84–96](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/random/Random.java#L84-L96)，Git blob `c4b71d5645688f6e764c46c593223eb91a5249bc`：三个 float 重载各先增加 counter，随后使用一次 `nextFloat`；范围重载按乘法、区间重载按减法再乘法再加法计算。
- [官方 libGDX RandomXS128.nextFloat，132–134](https://github.com/libgdx/libgdx/blob/3b1fda1fc2e1f6b3c74851471870062d871ed16f/gdx/src/com/badlogic/gdx/math/RandomXS128.java#L132-L134)，Git blob `a6a0b38676f11d54d01a4fdeb056c42f003c6820`：一次 nextLong 的高 24 位乘 2^-24。该网格可被 binary32 精确表示。
- [Java SE 17 JLS §4.2.3–4.2.4](https://docs.oracle.com/javase/specs/jls/se17/html/jls-4.html#jls-4.2.3) 与 [§15.4](https://docs.oracle.com/javase/specs/jls/se17/html/jls-15.html#jls-15.4)：float 对应 binary32，运算使用最近偶数舍入，保留次正规值和正负零；本轮独立表达式向量在已安装的 Java 17 上执行。

STS 文件是社区反编译镜像，不是官方公开源码或认证的正版 PC 构建。固定官方 libGDX 提交是否匹配该游戏依赖仍未认证。本日期是只读核对日期，没有原作观察日期。未运行、复制粘贴或编译下载的上游类。

## 新增 ABI 和准确公式

`randomFloat(state)` 原接口保留，高 24 位产生 `u ∈ {0, 1/2^24, …, 1−1/2^24}`，仍拒绝额外参数。新增：

| 接口 | 公式（f32 表示每一步最近偶数舍入） | 支持输入 |
|---|---|---|
| `randomFloatRange(state, range)` | `f32(u × range)` | 恰好可表示的有限 binary32，包括负值、次正规数、±0 |
| `randomFloatBetween(state, start, finish)` | `span=f32(finish−start)`；`scaled=f32(u×span)`；`f32(start+scaled)` | 两端均为上述有限 binary32，且舍入后的 span 有限；允许反向或相等端点 |

每个成功调用 counter 增加一次、消耗一次 raw，零范围、相等端点也不提前返回；signed32 counter 继续在最大值后回绕。恢复、快照和原语拒绝抽样规则不变。额外参数（包括显式 nil）、普通 double 0.9 / 1.1、不能精确表示的值、NaN / infinity、类型错误、坏状态和无限 span 均在改变 counter 或原语状态前拒绝。

**这是收窄 ABI，不是 Java 全部输入的错误语义复刻。** Java float 可以接收 NaN / infinity，有限端点相减也可能溢出；候选明确不支持这些请求，不在抽样后才偷偷修正结果。与旧概率 ABI 一样，传入 double 不会隐式舍入成 float。

缩放结果不能统一标成半开区间。即使 u 不含 1，舍入仍可能命中 finish：`start=1`、`finish=1+2^-23`、`u=1−2^-24` 时返回 finish。`range=2^-149` 也可能舍入为 range。测试按准确公式验证，不按半开区间误判这些端点。

## Lua 承载方式

私有 `float32` 用精确的二次幂缩放、24 位有效数及最近偶数舍入。normal 与 2^-149 subnormal 网格分别处理；负值独立保留符号，零用 1/value 的符号验证。没有依赖 string.pack、64 位 Lua 整数、log 或宿主 float cast。

有限 binary32 值均可由 Lua 的 binary64 精确承载。两个 binary32 有效数相乘最多 48 位，落在 binary64 精确范围内；单个 binary32 加减也可先用 binary64 再舍入回 binary32：指数接近时可精确承载决定舍入的位，指数相差很大时小操作数不足以跨过 binary32 半 ULP。这里只把单次运算舍入回 binary32，不能将整个区间公式合成一次 double 表达式或融合乘加。`finish−start` 显式转为浮点，避开 Fengari signed32 的中间整数回绕。

## 固定向量与红绿证据

`tests/fixtures/sts-random-scaled-float-vectors.json` 包含独立手写 `generatorJava` 全文、SHA256、固定源提交与 132 行结果。Java 仅计算简单 float 表达式，不导入官方 RNG 或反编译类；raw 状态沿用先前独立数学解释的固定向量。因此它是独立语言对同一来源解释的交叉检查，**不是官方 libGDX 或原版游戏执行 Oracle**。JavaScript 只读取固定结果并传给 Lua，不用 JS 自算结果当原作预期。

覆盖高 24 位 0、1/2、最大值和三个中间点；两种都产生 u=0 的不同低位 raw；9 种 range 与 13 种区间，包括正负 normal、最大有限 float、最小 normal、最小 subnormal、半单位及 1.5 单位的 ties-to-even、非精确 span、相等／反向区间及 ±0。每次独立核对结果、零符号、counter 和完整双状态字。

新增专项 7 组，修正测试生成 Lua 的一处括号错误后，在未实现接口时得到 1 通过 / 6 失败（均为缺失 ABI），之后才实现候选。实现后连同原包装器 10 组、原语 8 组，共 25 组通过。十个隔离副本负变异均检出：省略 range／span／product／sum 舍入、ties 改为向上、丢零符号、接受非 binary32 double、漏计数、漏 span 溢出保护、漏额外参数拒绝；去掉无限 span 保护的变异由有限测试超时检出，其余为断言失败。真实候选文件未为变异而修改。

复现专项：

```powershell
node --test tests/sts1-random-scaled-float-candidate.test.mjs tests/sts1-random-wrapper-candidate.test.mjs tests/sts1-rng-lua-candidate.test.mjs
```

复现向量：提取 fixture 的 `generatorJava` 为 `FloatVectors.java`，执行 `java FloatVectors.java`，其 JSON 输出应逐字段等于 fixture.rows。日常测试不启动 Java、不联网或安装依赖。

完整检查由主代理整合后统一执行；本片未跑全量，未进行平台编译、存档副本导出、官方导入或原神／千星实机。不推测独立流、初始化种子、调用次序或保存格式，不将现有 LCG 可复现写成原版 RNG 一致。long/double 重载、原版全局 copy 副作用、seed+counter / setCounter 和实际调用方接线仍未实现；TASK-16.1 全部严格 AC 保持未勾。
