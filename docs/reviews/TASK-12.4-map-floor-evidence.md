# TASK-12.4：第一幕计层与强制节点核对

核对日期：2026-10-23。项目基线：`2eaf30fd89c68f7321d30f9827ccd8043b67acc6`。本文供 TASK-12.4 实现者复用，不修改任务状态，不构成原版一致性或平台验收通过。

## 结论及来源边界

适用范围：普通第一幕 A0，非无尽、非每日挑战、无自定义修正，不使用调试捷径，且不是读档转换。A0 本身并不排除这些模式或修正。

读取到的 Java 反编译镜像支持：**15 行生成地图 + 第16层 Boss 房间 + 第17层 Boss 宝箱房间**。不能把当前生成循环的15直接改为17，更不能把第17层做成普通可选地图行。

来源为第三方仓库 `purewhitelove/ButterflyGame`，固定提交 `fc379c875c11e008e9c10548ac8e394c301c532f`。文件头声明 Jad 反编译；[版本字段](https://github.com/purewhitelove/ButterflyGame/blob/fc379c875c11e008e9c10548ac8e394c301c532f/杀戮尖塔原码/core/CardCrawlGame.java#L1403-L1404)声明 V2.3.4 / 2022-12-18。**这不是官方开源代码，也未经正版 PC 二进制 hash 核验**，不能把镜像版本字符串当作真实性证明。本次只读行为并转述，没有复制实现、运行镜像或进行原作实测。

## 计层证据链

1. [AbstractDungeon.generateMap，594–624行](https://github.com/purewhitelove/ButterflyGame/blob/fc379c875c11e008e9c10548ac8e394c301c532f/杀戮尖塔原码/dungeons/AbstractDungeon.java#L594-L624)：生成15行、7列、6次路径生成；零基行0设普通战斗、行8设宝箱、末行14设营地。无尽模式特定灾厄会替换宝箱行，不属于普通第一幕 A0 基线。
2. [DungeonMap.update，60–87行](https://github.com/purewhitelove/ButterflyGame/blob/fc379c875c11e008e9c10548ac8e394c301c532f/杀戮尖塔原码/map/DungeonMap.java#L60-L87)：完成行14房间后，点击 Boss 创建独立 Boss 房间并进入下一房间事务。
3. [ProceedButton，93–107行](https://github.com/purewhitelove/ButterflyGame/blob/fc379c875c11e008e9c10548ac8e394c301c532f/杀戮尖塔原码/ui/buttons/ProceedButton.java#L93-L107)及[196–205行](https://github.com/purewhitelove/ButterflyGame/blob/fc379c875c11e008e9c10548ac8e394c301c532f/杀戮尖塔原码/ui/buttons/ProceedButton.java#L196-L205)：第一幕 Boss 战斗奖励后继续，创建独立 Boss 宝箱房间，不再选择一行生成地图。Boss 与宝箱内部坐标均可为 y=15，**坐标不等于计层数字**。
4. [AbstractDungeon.nextRoomTransition，2372–2384行](https://github.com/purewhitelove/ButterflyGame/blob/fc379c875c11e008e9c10548ac8e394c301c532f/杀戮尖塔原码/dungeons/AbstractDungeon.java#L2372-L2384)：非读档的正常房间转换递增 floorNum。因此从15行依次进入 Boss、宝箱得到16、17层。这是镜像调用链推导，不冒充原作录像验证。

## 当前15层与目标边界

当前事实见[项目强制节点表](https://github.com/CHNISam/Slay-the-Abyss/blob/2eaf30fd89c68f7321d30f9827ccd8043b67acc6/src/lua/abyss_map.lua#L6-L7)及[生成循环](https://github.com/CHNISam/Slay-the-Abyss/blob/2eaf30fd89c68f7321d30f9827ccd8043b67acc6/src/lua/abyss_map.lua#L74-L107)；目标依据上方证据链。

| 计层位置 | 镜像支持的目标 | 当前实现 |
|---|---|---|
| 1 | 强制普通战斗 | 相同强制类型 |
| 2–8 | 按生成约束分配，无统一强制商店/精英/事件层 | 3宝箱、5商店、6精英、8事件被强制 |
| 9 | 强制普通宝箱 | 非强制 |
| 10–13 | 按生成约束分配 | 非强制，但算法不同 |
| 14 | 非强制类型，随机分配禁止营地 | 强制营地 |
| 15 | 强制营地，生成地图末行 | 强制 Boss |
| 16 | 独立 Boss 房间 | 缺少该计层阶段 |
| 17 | Boss 战后独立宝箱房间 | 缺少该计层阶段 |

“非强制”不代表等概率或无约束。[RoomTypeAssigner，114–140行](https://github.com/purewhitelove/ButterflyGame/blob/fc379c875c11e008e9c10548ac8e394c301c532f/杀戮尖塔原码/map/RoomTypeAssigner.java#L114-L140)排除第1–5层随机营地/精英，排除第14层随机营地；第15层营地已在分配前强制设置。当前仅限制早期精英，仍允许早期营地。

语义迁移是旧宝箱3→9、旧营地14→15、旧 Boss15→16，新增 Boss 宝箱17，**不存在统一楼层偏移**。旧“每条路线必经七类节点”不能作为新算法预期。

## 实现与验证落点

- 区分地图行、Boss 阶段和计层；固定测试覆盖营地15→Boss16→战后宝箱17，不能把抵达 Boss 当胜利，或把宝箱画成第17行普通地图节点。
- 地图强制节点/早期限制按上述边界写独立预期；随机流、路径和遭遇池另按 TASK-12.4 核实，不能沿用三列同列链或等概率抽取。
- 当前快照签名 `map-v1:15:15:14`、路径上限15及旧坐标须随算法明确版本策略；同局状态要求不等于必须兼容旧版退出续局。UI 的三列及节点/边容量也不能只随一个层数常量调整。
- 原版 PC 版本真实性、固定种子输出、HUD 第15/16/17层转换仍需独立核验；本文没有补齐这些证据。后续由现有 TASK-12.4 承接，不新增平行任务。

交叉线索：[sts_map_oracle 固定提交的生成代码](https://github.com/Ru5ty0ne/sts_map_oracle/blob/ea5200f21fa566de77ec14b6155b3bf3756dccbf/src/lib.rs#L582-L616)及[行限制](https://github.com/Ru5ty0ne/sts_map_oracle/blob/ea5200f21fa566de77ec14b6155b3bf3756dccbf/src/lib.rs#L433-L441)与强制行/早期限制一致；它同样是社区逆向实现，不是官方认证或独立原作实测。

## 2026-10-23 离线实现切片

`rules.map`区分`generatedRows=15`、`bossFloor=16`、`bossTreasureFloor=17`与`floors=17`。生成行强制类型为1普通战斗、9普通宝箱、15营地；取消旧3宝箱/5商店/6精英/8事件/14营地强制，前5层禁随机营地/精英、14层禁随机营地。Boss16和Boss宝箱17各为一个独立房间；后者`type=treasure, roomKind=boss_treasure`，不显示为第17行可选地图节点。地图快照升为v2，明确拒绝v1，避免把旧Boss15重解释为营地。

| 验收输入 | 当前预期 | 边界 |
|---|---|---|
| seeds 0..127 | 每图1/9/15强制类型与早期排除成立；15营地→Boss16→独立宝箱17 | 只测已核对约束，不证明概率/原版路径 |
| 每图导航17步及快照恢复 | 最终floor17、path17、恢复为独立相同状态 | Map层可达，不等于节点奖励已实现 |
| 旧version1快照 | 拒绝恢复 | 不要求退出后续局兼容 |
| 原生控件树遍历和Lua地图UI测试 |15行与Boss16均可显示；独立宝箱17和其连线隐藏 | 保留批准稿主题、视窗与滚动；非实机截图证据 |

仍未通过的内容：原版7列/6路径生成、交叉与邻接限制、节点权重与父子重复限制、早晚普通遭遇池及重复限制、独立随机流/初始化/调用顺序、Boss遗物池/17层宝箱奖励事务、正版PC固定种子与HUD实测。现有宿主仍在Boss16后显示结果，不能宣称完整17层闭环。第17层入口必须由专用事务接续，禁止沿用普通宝箱抽取奖励。TASK-12.4所有覆盖完整一致性的AC及TASK-12.3平台AC保持未勾选。

### 遭遇永不可达回归及分流

删除旧伪强制节点后，未修改的`tests/lua/encounter_coverage.lua`在seeds 1..256中发现`blue_slaver_solo`完全缺失。原因可由现有LCG直接推导：六类可抽房间中combat位于首项，房间抽中它要求随机状态为偶数；下一次LCG状态必为奇数，14项普通遭遇池便只能得到偶数位置。旧强制战斗层绕开了房间抽取，掩盖此关联。

本切片将遭遇选择与房间类型/拓扑各使用独立`Random.new(seed)`对象，不加入任意种子偏移或补抽。依据为原作研究者2020-07-24的[原始分析文章](https://forgottenarbiter.github.io/Correlated-Randomness/)第“The random number generators of Slay the Spire”与“Predicting mystery rooms using combat encounters”节（本次读取2026-10-23）：原作多个职责流以同一局种子初始化，普通遭遇列表由`monsterRng`负责。该文章是研究者一手分析，但不替代PC2.3.4二进制核验。

修复后保留原有全遭遇覆盖断言：18遭遇均在256种子样本出现，188组遭遇回归通过。样本只证明候选内容可达，**不证明原版概率**。现有16位LCG、逐节点等概率选择、池的楼层范围和原版64位种子、加权遭遇列表、重复限制仍有差异；当前只修复合流导致的不可达，严格随机算法/调用顺序AC仍未通过。
