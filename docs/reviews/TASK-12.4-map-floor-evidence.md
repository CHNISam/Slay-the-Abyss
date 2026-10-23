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

