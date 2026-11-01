# TASK-16.1：隔离的 RandomXS128 原语候选

2026-10-23；核对 develop `cd8ceae705a688361ff0404e6c7abb4da0c723ba`。只新增候选、测试、固定向量与本文，不修改生产 `abyss_random`、W1/地图/问号 reducer、商店、任务元数据或负责人。TASK-12.4 / @codex-map17 仍负责地图流程；TASK-16.1 的完整原版验收不因本切片完成。

## 来源与结论边界

已全文只读核对 [libGDX RandomXS128 固定源文件](https://github.com/libgdx/libgdx/blob/3b1fda1fc2e1f6b3c74851471870062d871ed16f/gdx/src/com/badlogic/gdx/math/RandomXS128.java)（Git blob `a6a0b38676f11d54d01a4fdeb056c42f003c6820`）：双64位状态、23/17/26移位、模2^64加法、MurmurHash3种子展开、零种子替换、上24位float网格及bounded拒绝采样。本文日期是资料核对日期，不是原作观察日期。

上游署名 Copyright 2011 See AUTHORS，作者 Inferno、davebaol；[Apache License 2.0](https://github.com/libgdx/libgdx/blob/3b1fda1fc2e1f6b3c74851471870062d871ed16f/LICENSE)。本候选为独立编写的Lua四肢算术，Java核对器也是独立编写的BigInteger数学解释，没有复制/编译/执行下载的上游类，没有运行反编译镜像、原作或社区地图二进制。

**向量只证明两种独立实现对同一来源解释一致，不是官方库执行结果，更不是经认证的原版游戏Oracle。** 固定libGDX版本是否等于目标PC构建依赖仍未认证。原作Random包装器、计数器、流初始化、调用顺序与完整恢复尚未实现；不能宣称原版种子一致、W1通过或平台通过。

## 精确接口

`tools/candidates/libgdx_randomxs128.lua` 不自动加载到生产系统。

- `fromSeed(seed)`：仅规范十进制字符串，范围 -9223372036854775808..9223372036854775807；拒绝数值、前导零、正号、空白、-0和越界。零按来源规则映射至最小signed64后散列。
- `next64Hex(state)`：推进一次，返回16位小写十六进制，保留全部位；不是Lua number。
- `nextUint24(state)` / `nextFloat(state)`：各推进一次，分别返回上24位整数 / 除2^24。网格为0..1−2^-24，不含1。
- `nextInt(state,bound)`：bound为整数1..2147483647，结果0..bound−1；拒绝分支会多次推进，bound=1也消耗一次。不是游戏的闭区间接口，不提供64位bound。
- `snapshot(state)` / `restore(snapshot)`：快照仅两个16位小写hex字符串，复制隔离；接受来源允许的全零状态（其后保持零），不把它错误标为非法。仅原语状态，不是游戏存档。
- 状态内部为a/b两组四个低位在前的16位肢；每次调用验证普通表、字段、肢范围。错误bound在推进前拒绝。调用方不应直接改内部表。

每个64位数由四个16位肢承载；乘法显式浮点，最大中间量小于2^35，远小于binary64精确整数上限。加法带进位、移位和XOR不依赖64位整数或位运算库。拒绝条件用无溢出的肢比较表达Java signed-overflow语义。没有安装库。Fengari [官方整数说明](https://github.com/fengari-lua/fengari/blob/v0.1.4/README.md#integers)为32位整数/double浮点，这只是设计依据，不替代执行验证。

## 可复现测试与实际结果

固定JSON含独立Java生成器全文 `generatorJava` 和其SHA256。取出该字段保存为Oracle.java，用已安装Java21的源码运行模式执行，输出与固定seeded/rawCases/bounded字段完全一致。常规测试只读固定向量，不执行Java、不联网、不下载。

正式命令：`node --test tests/sts1-rng-lua-candidate.test.mjs`，复用既有runLua/Fengari及15秒超时。当前云环境没有fengari-node-cli，该正式命令因MODULE_NOT_FOUND失败，未安装绕过。完整npm run check在隔离部分材料工作目录因缺少check-syntax.mjs而停止；没有完整聚合绿灯结论。

系统liblua5.4经ctypes实际执行同一测试生成的Lua，替换的仅为本地测试执行器：**8/8组通过**。覆盖10个signed64种子×128次原始输出（含2780424839485660359和signed极值）、6组高位/进位/零状态×32次输出、8个bound×16个结果、快照连续恢复、非法输入原子性，以及0和最大uint24端点。bounded向量专门逆构首个raw为ffffffffffffffff的状态，实测拒绝分支的结果及消耗后态，不靠随机命中稀有分支。

TDD先观测缺原语的3组失败，再实现seed/raw/state；新增float/bounded测试失败后才实现对应API。七种负对照均被检出：丢进位、模拟signed32乘积溢出、跳过拒绝、移位17改18、零种子替换错误、丢种子高32位、float使用低位。还原后8组再次通过。原生Lua结果不冒充Fengari或千星平台结果。

独立复审和当前提交Fengari CI通过后才能考虑接收这个候选；任何生产接线、原作版本认证、地图/商店调用轨迹及游戏资源账本属于后续明确任务，不由本候选隐式完成。
