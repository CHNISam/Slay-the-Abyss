# TASK-12.4：第一幕完整房型候选与生产迁移门槛

2026-10-24，基线 `6e8714f0b3fe3f7e57a4e5bcff4a003a99e1cb40`。本片把既有七列拓扑候选补成完整的 **15行生成图**：连接坐标、每条边、每个房型与12个未修改的捕获golden全部相同。候选仍在 `tools/candidates/`，没有进入生产，也没有实现Boss16/箱17、遭遇队列或UI。生产同一批完整图比较仍 **FAIL 0/12**，不能称TASK-12.4或M3完成。

## 来源与规则账本

实际重读根 `.artifacts/map-rng-source-1cfaba2/` 保存的固定原文响应；本次重新计算四份内容hash，与已入库证据相同。URL、Git blob和SHA256见 [结构化证据](../rules/evidence/w1-map-room-candidate.json)。未执行或复制上游实现；Lua为按下述行为独立编写。

| 项目 | 已核行为与候选实现 | 原文依据 |
| --- | --- | --- |
| 配额基数 | 统计有出边的格子，唯独排除y=13；**不是**先删固定1/9/15层再算百分比。`generate`的`quotaCount`保留这个数。 | 固定镜像 [AbstractDungeon.generateMap](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/dungeons/AbstractDungeon.java) |
| A0配额 | shop=.05f、camp=.12f、elite=.08f、event=.22f；先以binary32乘法舍入，再按Java `Math.round(float)`取整。随机清单依次Shop→Rest→Elite→Event，没有随机treasure。`quotas`仅支持本图0..105基数，不外推任意Java输入。 | [Exordium.initializeLevelSpecificChances](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/dungeons/Exordium.java)、AbstractDungeon.generateRoomTypes |
| 固定行 | y=14全行Rest、y=0全行Monster、y=8全行Treasure，连未显示格子也赋值；随后只统计仍未赋房型且有出边的格子，给清单补combat。清单过大不截断。 | AbstractDungeon.generateMap、[RoomTypeAssigner](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/map/RoomTypeAssigner.java) |
| 洗牌 | 从**拓扑结束的同一mapRng状态**继续，长度n至2倒序调用底层`nextInt(i)`，原语state推进，STS wrapper counter不增。不重置种子、不经randomLong转播Java RNG。 | RoomTypeAssigner.distributeRoomsAcrossMap、[OpenJDK Collections.shuffle](https://github.com/openjdk/jdk8u/blob/jdk8u412-b08/jdk/src/share/classes/java/util/Collections.java) |
| 分配顺序 | 行优先、列优先遍历；每格取清单里第一个合法房型，移除此项，不为失败候选抽随机。既有重复/遗留父引用保持。 | RoomTypeAssigner.assignRoomsToNodes/getNextRoomTypeAccordingToRules |
| 行限制 | y≤4不分配Rest/Elite；y≥13不分配Rest。y=14预设Rest不受随机分配限制。 | RoomTypeAssigner.ruleAssignableToRow |
| 父限制 | Rest/Treasure/Shop/Elite不得与任一父房型相同，Monster/Event可以。 | RoomTypeAssigner.ruleParentMatches |
| 兄弟限制 | 从每个保留父节点的当前出边取其他子节点；已赋值兄弟的Rest/Monster/Event/Elite/Shop会阻止同型，Treasure不受限制。y=0仅忽略父/兄弟匹配，仍先过行限制。 | RoomTypeAssigner.getSiblings/ruleSiblingMatches |
| 回退 | 整张图第一次分配结束后，剩余有出边空格变combat；不消费被拒清单，不再按兄弟限制重分配。未用房型保留。 | RoomTypeAssigner.lastMinuteNodeChecker |

游戏代码来源是第三方CFR镜像，尚未与目标正版PC二进制及依赖版本认证。golden是固定第三方oracle黑盒捕获，不是原作实机。原先已知oracle稀有signed拒绝采样差异继续保留；未改原语迎合oracle。终局钥匙精英、Endless、Ascension≥1、mod均未实现。本片`randomState`是房型分配后的状态，**不声称**包含随后条件性的`setEmeraldElite`消费。

## 接口和实际验证

`tools/candidates/sts1_map_rooms.lua`导入既有拓扑、包装器和原语候选，三者文件未改。`generate(rawSigned64String)`保留拓扑grid/parents/edges，返回完整`nodes[].type`、`topologyState`与分配后`randomState`，以及配额、洗牌前后清单、未用清单和fallback数量。`quotas`、`shuffle`、`selectRoom`、`assign`是独立边界测试入口，不是生产API或恢复格式。

- 新15项先红 **0/15**（缺完整房型模块），再绿 **15/15**。首次普通权限运行遭`spawnSync EPERM`，没有把它算功能红例；提升执行后的真实缺模块红日志保留。
- 12/12固定golden完整比较坐标、边、房型；未改任何fixture、manifest、输入seed、已有向量或阈值，含完整`2780424839485660359`。每份fixture hash/捕获进程状态/--a0参数同时核对。
- 独立边界：JS `Math.fround`给出0..105全部106种配额预期，含50×.05f与25×.22f半整数；手写raw洗牌顺序/独立BigInt递推state，验证不推进wrapper counter；逐条父/兄弟/行限制和combat fallback。每个golden还单独核对拓扑结束态未被覆盖。
- 旧拓扑和RNG四套专项 **40/40**；新增候选0..127结构回归 **128/128**，0执行错误。结构绿不代替严格golden或目标PC证明。
- 本轮实际生产完整比较 **FAIL 0/12**：11图差异，1完整64位seed仍不支持。这份差分与候选结果分开保存。

复跑（需根依赖可解析，并允许Fengari子进程）：

```powershell
npm run build:data
node --test --experimental-test-isolation=none tests/sts1-map-room-candidate.test.mjs
node scripts/sts1-map-room-candidate-evidence.mjs build/sts1/room-candidate
```

脚本保留每个seed的实际图、洗牌前后清单、双state与独立生产差分。本轮原始产物/红绿/回归日志在根 `.artifacts/m3-map-room-6e8714f/`；入库结构证据保存文件hash、每个输入的双state、配额和完整golden差分。本片没有跑full check、MCP、编译副本、官方导入或游戏。

## 下一生产切片：具体文件和验收门槛

先由主线程复核此候选，再实施下列**同一套迁移**，避免只接七列算法却留三列控件或16位种子。此清单尚未实施。

1. **部署模块**：分别将`libgdx_randomxs128.lua`、`sts_random.lua`、`sts1_map_topology.lua`、`sts1_map_rooms.lua`提升为`src/lua/abyss_randomxs128.lua`、`abyss_sts_random.lua`、`abyss_map_topology.lua`、`abyss_map_rooms.lua`，替换内部`dofile`为`require`。`scripts/native-candidate-scripts.mjs`会自动纳入src Lua，但须用其部署测试证明四个名字唯一、依赖齐全、没有tools路径。保留现有`abyss_random`给其他生产子系统，不把全局RNG替换混入本片。
2. **Map v3**：改`src/lua/abyss_map.lua`，映射lane=x+1/floor=y+1，只部署有连接格；保留每格的原生type，所有末行camp连lane4的Boss16，Boss仅连lane4的独立箱17。新快照使用`version=3`及新的sourceSignature，保存immutable `runSeed`规范signed64字符串、`mapSeed`、拓扑结束与分配后双64位state/counter、独立遭遇流状态和合法path。`restore`按raw seed重建后重放path，深比较全部状态；v2明确拒绝，不静默换图。`available/choose`非法/跳层的原子性、17步终局和深层篡改拒绝继续验。
3. **种子宿主与遭遇边界**：`src/lua/abyss_game_ui.lua`初始化/`start()`目前用`self.seed=1`并`%65536`递增；`src/lua/abyss_run.lua`的`run.seed`又是战斗会变的16位流。Map入口可以兼容精确小整数→规范十进制字符串，完整输入必须独立`rawRunSeed`字段传递，不能把完整字符串经`tonumber`或`%65536`。不得将可变`Run.seed`回灌地图。保留旧遭遇流可作为明确未对齐切片，但需要签名/快照隔离；普通早晚队列、加权抽样、重复限制、monsterRng种子及消费顺序仍是TASK-12.4必要缺口，不因完整地图golden通过而宣布完成。
4. **七列容量与UI**：按批准主题保留node56/columnGap112；`scripts/map-ui-layout.mjs`将`lanes3/maxNodes47`改为`lanes7/maxNodes92`（6路径×15行+2终端的保守上界），`maxEdges126`已覆盖84内部边+最多6条camp→Boss+1条Boss→箱的91上界。当前独立地图树605控件/5组，增加45个节点×9控件和1个分组后预计1011控件/6组，分组50直接子控件保持。`src/lua/abyss_map_ui.lua`坐标已读取Layout.lanes，但要用七列真实图验证所有节点命中、裁剪/滚动/安全区和箱17隐藏。本片未做UI变更；实施前仍须读UI_DESIGN、PLATFORM_PARITY并协调主线程。
5. **必须保持与迁移的回归**：`tests/lua/map.lua`目前硬断47格、固定lane路径与旧state，需以严格golden和等价导航断言迁移，不能删验收；`map_floor_boundaries.lua`、`map_treasure_placement.lua`、`map_ui.lua`、`game_ui.lua`、`inventory.lua`、`encounter_coverage.lua`等固定seed路线可能改变，应重新找合法路线保留资源/获取/17层全部行为断言。`tests/map-ui-layout.test.mjs`、`map-gesture-ownership.test.mjs`、`map-no-crossings.test.mjs`、`validate-map-contract.test.mjs`和原生部署审计必须覆盖新容量。`scripts/sts1-map-evidence.mjs`只有Map真正支持字符串后才移除safe-number过滤和`tonumber`，并让全部12输入经过真实生产接口，而非候选接口。
6. **下一gate**：真实生产完整12/12、至少10000seed性质检查（仍用分批/超时，不删断言）、新旧快照边界、全组合离线check、同一固定源副本编译/逐模块读回/UI容量审计；再官方导入并按`npm run verify:ui -- <候选.gil>`及地图/正常17层实机收集新证据。旧M2通关证据保留为旧候选，不自动覆盖本次地图改动。目标PC认证与遭遇队列仍独立留账。
