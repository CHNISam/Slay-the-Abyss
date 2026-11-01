# TASK-12.4：第一幕完整地图接入生产

2026-10-24，基线 `b91a461bb759ff71fa66a6368ffe0289c36641f2`。把已独立验证的七列拓扑与完整房型候选提升为生产模块；真实 `Map.generate` 的连接坐标、每条边、房型在全部 **12/12 未修改 golden** 上一致，包含 `2780424839485660359`。这是一份离线生产接线证据，不是平台导入或原作 PC 认证，也不完成 TASK-12.4 的所有验收项。

## 来源及迁移

固定来源与行为账本沿用 [拓扑候选](TASK-12.4-map-rng-topology-candidate.md)、[房型候选](TASK-12.4-map-room-candidate.md) 及对应结构化来源 hash。游戏镜像固定为 `aeubanks/sts@319009d5df0a82d9fb0f23cc22322286c6a87ec0`，golden 为既有固定第三方黑盒捕获，未改 manifest、输入、阈值或任何捕获文件。

- `abyss_map_topology`、`abyss_map_rooms` 由既有独立候选提升，只改模块引用与说明。复用生产 `abyss_sts_random` / `abyss_randomxs128`，房型洗牌仍直接调用底层 `nextInt`，不调用事件用途的 `shuffle`，不推进 wrapper counter。
- `Map` v3 只部署有连接的格子，`floor=y+1`、`lane=x+1`；保留全部原房型与边。第 15 层营地连中列 Boss16，Boss 连独立箱17。ID 用整数格式化，避免 Fengari 整数值浮点坐标产生 `f2_l1.0` 悬空引用。
- `runSeed` 是规范 signed64 十进制字符串，`mapSeed` 为带 signed64 回绕的 raw+1；同时保存拓扑结束态与房型结束态。`seed` 兼容 Nodes 的地图身份接口，值同 raw `runSeed`。恢复按 raw 重新生成、重放最多17步合法路径并深比较整个状态，明确拒绝 v2、额外字段、深层篡改及非法路径。
- 宿主一次规范化输入后分别传给 Run/Map；Run 的不可变 `runSeed` 与仍会推进的旧 `run.seed` 分开，后者不回灌地图。完整 raw 字符串不经 `tonumber`。显式数值 `ui.seed` 保留旧测试的模65536递增；显式字符串精确递增，max signed64 后回绕 min signed64。正常新局仍使用此前已集成的时钟采样16位供应器，本片没有扩大其取值域，随机碰撞仍可能。
- 保留旧 **16位 LCG uniform 遭遇预抽**，单独保存 `encounterSeed`/末态，签名明确标记。它尚不是原版 monsterRng/弱强队列；本片不接遭遇队列、动态编组或 Nodes 战斗入口。

原房型会在第14层生成精英（golden 1/42/600 均有），而旧三个精英条目资格上限13会令合法地图生成失败。按固定 `RoomTypeAssigner.ruleAssignableToRow` 的原文，随机 Elite 只受前5层禁止，14层并未禁止；只把这三个条目的 `maxFloor` 扩到14。未改敌人数值、权重、AI或队列。新增真实 Nodes 入口测试沿合法图定位14层精英，证明 Run 资格检查可通过；该夹具没有冒称已打完前13场。

## UI 与验证

布局改为7列、92节点池（6路径×15行+2终端），保留批准主题 node56、columnGap112、滚动/焦点与 C 点选。既有126边池足够，分组仍不超过50直接子控件。没有改战斗 UI 或视觉方向；原生控件模拟的全节点点击、可见性、滚动、安全区、旧手势拒绝通过，尚无本候选平台截图。

真实红例为生产旧图 **0/12**、缺 Map v3 raw 字段、3列容量；修复后生产专项4/4，相关 Node 专项49/49。Lua 保留三套各128种子边界/不交叉/固定箱及恢复检查；Map10、MapUI27、手势35、Host种子7、序章10、正常17层宿主15通过。为保留 Fengari limb RNG 下的全部128/256输入，仅提高这些明确有界性质夹具的超时，不删种子或断言。

地图变更使旧固定左路不再保证遇到商店，已把测试夹具改成真实可达路线，保留原事务、资源、UID、回滚和流状态断言：库存11、恢复5（8种快照拒绝）、节点21、卡牌93、商店旧回调15、Small Slimes18、Gremlin29（1680选择路径）、遭遇覆盖55组及全部18遭遇通过。Small Slimes 自然两房路线改为 seed7/f1_l4→f2_l4，记录完整原数据战斗后的 HP72；不再套用旧地图 seed23 的 HP66。无生产奖励生命周期改动。

机器证据与每份日志 SHA256 见 [map-production.json](../rules/evidence/map-production.json)。原始日志位于此工作树 `.artifacts/sts1-map-production/`。复跑入口：

```powershell
npm run build:data
node scripts/map-ui-layout.mjs
node --test --experimental-test-isolation=none tests/map-production.test.mjs tests/sts1-map-evidence.test.mjs tests/map-ui-layout.test.mjs tests/map-no-crossings.test.mjs tests/map-gesture-ownership.test.mjs tests/validate-map-contract.test.mjs tests/native-candidate-scripts.test.mjs
node scripts/test-lua.mjs tests/lua/map_floor_boundaries.lua
node scripts/test-lua.mjs tests/lua/map_treasure_placement.lua
```

## 保留关口

10000种子性质运行已中断，日志仅有最后进度1050/10000，没有完整结果，不能计通过或挪用旧地图的10000证据。全组合 check 由主线程集成后执行。本片未运行 MCP、编译、存档写入、官方导入、游戏或 UI 验收；新源副本编译/读回、正式客户端地图命中与17层正常通关、`verify:ui` 都仍待验证。原作 PC 二进制/libGDX 版本认证及极少见拒绝采样的已知 oracle 差异也未消除，不改原语迎合第三方 golden。
