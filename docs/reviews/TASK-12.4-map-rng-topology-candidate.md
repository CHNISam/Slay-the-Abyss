# TASK-12.4：Act1 原始种子与七列拓扑候选

2026-10-23；基线 `1cfaba22cc81b7919b5b2634ff3b7cfd71abac48`。本片新增隔离候选，**没有接入生产 Map/RNG/UI**。独立验收仅比较生成行的连接坐标和每条边，不比较房型、不完成 W1 或目标 PC 认证。证据：[w1-map-topology-candidate.json](../rules/evidence/w1-map-topology-candidate.json)。

## 已核实的初始化与消费链

实际只读核对固定游戏反编译镜像 `319009d5df0a82d9fb0f23cc22322286c6a87ec0`：

- [AbstractDungeon](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/dungeons/AbstractDungeon.java) 的 `actNum` 初值/重置为 0；新幕 super 构造先调用 `dungeonTransitionSetup` 加 1。[Exordium](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/dungeons/Exordium.java) 随后以 `Settings.seed + actNum` 新建 `mapRng`，立即生成地图。因此普通新第一幕使用 **raw signed64 局种子 + 1，按 Java long 回绕**，没有预热抽样。
- [MapGenerator](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/map/MapGenerator.java) 顺序执行 6 条路径。第二条起点与第一条相同时重抽；后续起点允许重复。每一步用闭区间整数，祖先间隔分支会额外重抽，夹限/去重不抽样。固定源 `getCommonAncestor` 比较 `node1.x < node2.y`，不能自作主张改为 x 与 x 比较；深度循环含两端。首行删冗余边不删除目标的父引用，重复边去重也不去重父引用。
- MapRoomNode 的视觉 jitter、MapEdge 点线细节使用全局 MathUtils，不消费这个 mapRng。候选只实现逻辑拓扑，未实现这些视觉随机。
- [RoomTypeAssigner](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/map/RoomTypeAssigner.java) 在路径完成后直接 `Collections.shuffle(roomList, rng.random)`。[OpenJDK 8u412-b08](https://github.com/openjdk/jdk8u/blob/jdk8u412-b08/jdk/src/share/classes/java/util/Collections.java#L456-L460) 对 ArrayList 倒序调用底层 `nextInt(i)`。这推进同一 RandomXS128 状态，**不增加 STS Random 包装器 counter**，也不是先取 randomLong 再播种 java.util.Random。

golden 的 [CLI](https://github.com/Ru5ty0ne/sts_map_oracle/blob/ea5200f21fa566de77ec14b6155b3bf3756dccbf/src/main.rs) 按 i64 解析十进制 seed，并固定 15×7/6 paths；其 [generate_maps](https://github.com/Ru5ty0ne/sts_map_oracle/blob/ea5200f21fa566de77ec14b6155b3bf3756dccbf/src/lib.rs#L582-L588) 内部为第一幕加 1。因此原有 12 输入是 **raw 局种子**，不是已经加偏移的 mapRng 种子。[SeedHelper](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/helpers/SeedHelper.java) 的游戏显示/输入码另用不含 O 的 35 字符表，不能把显示码当成十进制原始 seed。本片不实现显示码转换或续局构造。

全部原文的 Git blob、内容 SHA256 和 URL 收录于证据；原始响应保留根 `.artifacts/map-rng-source-1cfaba2`。游戏源是未经目标正版 PC 二进制认证的第三方 CFR 镜像；官方 libGDX/OpenJDK 源也尚未与实际游戏依赖版本认证。不执行或复制下载的上游实现，不将反编译镜像当作官方开源/原作观察。

## 隔离接口与实际结果

`tools/candidates/sts1_map_topology.lua` 复用原有 `libgdx_randomxs128.lua` 与 `sts_random.lua`，二者文件未改。不自动加载进游戏。

- `seedForActOne(rawRunSeed)`：只接受原语支持的规范 signed64 十进制字符串，精确加 1；最大正数回绕为最小负数，`-1→0` 后仍由原语保留零种子替换规则。拒绝数值、前导零、空白、额外参数及越界，不经 Lua number 转换整条种子。
- `generate(rawRunSeed)`：固定七列、15 行、6 次路径，返回 `runSeed/mapSeed`、行优先的连接坐标 `nodes`、排序的生成行内部 `edges`、完整 `grid` 以及路径结束的 `randomState={words,counter}`。顶行在 grid 中保留源绘图 anchor `(3,height+1)`，但它不进入生成行节点/边的 golden 投影，也不是新增房间。
- `grid` 保留全部坐标格、重复父引用及被首行过滤后遗留的父引用，供下一片精确房型分配使用；不能提前删除“当前不显示”的格子。返回对象属于调用者，不宣称外部修改后的恢复格式。
- `generateDungeon(height,width,density,closedDraw)` 是仅供独立边界向量的显式注入入口，支持本片所需的有限尺寸（height2–15、width2–7、density1–6）；注入器必须返回闭区间整数。`commonAncestor` 暴露相同理由。它们不是完整生产/原生 API，也不承诺错误回调的事务回滚或任意 Java 输入兼容。

专项命令：`node --test --experimental-test-isolation=none tests/sts1-map-topology-candidate.test.mjs`。

新增测试首先 **0/15**（候选缺失），实现后 **15/15**。其中 **12/12 未修改的真实捕获 golden** 对每一个连接坐标及每一条边完全匹配，包括 `2780424839485660359→2780424839485660360`；fixture hash/原始进程状态/A0 flags/版本信息同时核对。其余测试用独立手写边界覆盖 signed64 回绕、第二起点重抽、左右夹限、重复父引用、首行删边保留父引用、祖先轴判定/含端点深度和短合流条件重抽。不是用候选同 seed 重放证明原版一致。

每个输入实际结果、双状态/counter 和原始 runner 响应已保留根 `.artifacts/map-rng-source-1cfaba2/candidate-<seed>.*`，可复跑的导出脚本为 `verify-candidate.mjs`。当前样本最多 64 个连接节点、73 条内部边；这些是样本统计，不是容量上界。另实际执行生产完整地图 golden，仍 **FAIL 0/12**（11 差异、1 完整 seed 不支持）；完整报告独立保留为 `production-full-map-diff.json`。

## oracle 的已知稀有边界

固定 oracle 使用 unsigned `bits+n >= value+1` 判定，与 [官方 libGDX](https://github.com/libgdx/libgdx/blob/3b1fda1fc2e1f6b3c74851471870062d871ed16f/gdx/src/com/badlogic/gdx/math/RandomXS128.java) 的 signed 拒绝条件不等价。以 raw=`ffffffffffffffff`、bound=3 为例，bits=9223372036854775807、余数1，Java signed 表达式回绕为 -9223372036854775808，应拒绝；oracle unsigned 表达式仍判接受。证据中的反例是原文公式的独立 BigInt 算术解释，不冒充执行官方库或原作。

本片保持已有正确拒绝采样，不为匹配有限样本改错实现。12 次拓扑匹配是独立样本证据，不是全状态 RNG 证书，更不等于真实 PC 版本认证。

## 下一步生产迁移与验收门槛

1. **先补房型并通过完整 12 golden。** 在同一个路径后状态上，按 Exordium A0 常量、Java float32 舍入/Math.round 生成 Shop→Rest→Elite→Event 清单；固定0/8/14行，补 combat 到实际未分配连接节点数，再直接对同一底层原语执行倒序洗牌。保留 wrapper counter 的区别、行优先遍历、父/兄弟约束与最终 combat fallback。加入独立配额半整数/父列表/洗牌边界向量，完整比较坐标、边、房型；不把当前 topology-only 的 PASS 接到完整检查上。
2. **再将验证过的模块提升到 src。** 用独立模块名和 require 取代候选 dofile，加入实际部署清单；不全局替换当前战斗/事件的 LCG。Map 的 immutable rawRunSeed 为规范 signed64 字符串，派生 mapSeed 与路径/房型双状态必须精确保留。现 host 以小整数 seed 递增、Run.seed 又是可变16位流，需建立显式适配：默认小整数可安全转为规范字符串；完整 raw seed 必须独立携带、禁止 tonumber/模65536后再传 Map。遭遇身份仍属于独立 monster 流工作，不能复用 mapRng 或把目前旧遭遇流当成已对齐。
3. **Map/restore 使用明确新版本。** 将坐标映射为 lane=x+1/floor=y+1，仅部署连接格；Boss16/箱17各为独立居中 lane4 房间，所有末行营地连 Boss，Boss 只连箱。sourceSignature 标识完整新算法与相关数据；新快照记录 raw seed、派生种子、两个64位状态字及计数，按源重新生成后重放合法路径严格比较。明确拒绝旧 v2 三列快照，不静默换图。原 `available/choose` 的非法/跳层原子性、17步导航、快照深层篡改拒绝均保留。生产 exporter 只有在 Map 真支持字符串后才移除 Number-safe 过滤/tonumber，使所有12输入实际执行。
4. **同步七列 UI 与原生构建。** 主题已配置 columns=7、columnGap=112、node=56；七列连外圈宽728，小于900px视口，可保留批准主题。当前 mapGeometry 硬编码 lanes3/maxNodes47 须迁移，节点池按6条路径×15行+2终端的保守上界92分配；内部边至多6×14=84，加最多6条营地→Boss和1条Boss→箱，合计至多91，现 maxEdges126 足够。保留50子项分组、裁剪/滚动/三设备安全区和箱17隐藏规则，新增完整七列输入命中/各路线导航/容量测试。之后做离线模块/UI/图审计与新候选编译，平台真实视觉和交互仍单独 NOT_TESTED。

目标是按这些门槛接入生产七列生成器；本候选不是长期替代实现。当前没有修改 src/地图宿主/UI、数据/golden、依赖或 CI，没有运行全量、Miliastra、导入或游戏。TASK-12.4/W1 的广义一致性和平台 AC 保持未勾。
