# 未知房与六事件受限池

2026-10-24，TASK-13.1.1（High + p0，M2）。用户提供执行包后，明确批准先交付六种完整事件的**受限事件池**，其余保留 P0：TASK-13.1.2。M1 实机关口和 TASK-12.3 平台验收均不因此关闭。

## 生产行为

正常 `rules.events.poolMode=restricted-six`，不再固定 Purifier。地图问号在入场时一次解析为战斗、商店、宝箱或事件；图标保持问号。实际房间复用现有战斗奖励、商店交易和宝箱领取处理器。第14层普通遭遇范围从13修到14，避免合法问号战斗无遭遇可用；精英及Boss范围未改。

`abyss_unknown` 保留原理想百分比审计接口；生产适配使用 binary32 累积及固定100桶，处理上一个实际房间为商店、概率超过100后的最后桶覆写、Tiny Chest / Juzu 接口。后两件遗物**未加入可玩遗物池**，只有适配器边界测试。

每局保存原始十进制 `eventSeed`、独立 `eventRng` / `miscRng`、当前/上次概率、三个剩余池和 `nodeFlow` 的事件参数/阶段。事件选择按镜像 `Random(seed,counter)` 从房间计数重建独立流，记录抽选后快照，**不把选择次数提交给房间流**。随机数复用既有 RandomXS128/STS 候选，原候选及来源向量保持不变；Shining Light 新增以一次 miscRng.randomLong 驱动的 Java48 洗牌，以独立 BigInt 解释器交叉验证。全局战斗/地图 RNG 没有被替换。

入场先暂存概率、池和随机流；事件池耗尽、未知内容或战斗创建失败均不提交地图/楼层/资产/随机状态。重复入场、view/render、选牌取消和重复领奖不重抽。Golden Wing 的7点伤害在确认献祭时先提交；选牌返回只能回到已支付后的阶段，不能退款、重付或改选金币。

| 原版 ID → 内部 ID | 可玩选项与边界 |
| --- | --- |
| The Cleric → cleric | 金币≥35才有资格；35金治疗 floor(maxHP×25%)、50金选UID删牌、离开。 |
| Purifier → purifier | 免费选UID删牌，或离开；不增加商店删牌次数。 |
| World of Goop → goop | 入场固定20–50金币损失且封顶当时金币；取75金并受11伤害，或损失预先展示的金币离开。 |
| Upgrade Shrine → upgrade_shrine | 免费升级一个永久UID，或离开；没有可升级牌时明确禁用。 |
| Golden Wing → golden_wing | 受7伤害后选牌移除；持有单次基础伤害≥10的攻击牌时可取50–80金；或离开。资格在入场固定，不以多段伤害合计满足。 |
| Shining Light → shining_light | 受 round(maxHP×20%) 伤害，随机升级最多两张不同永久UID；或离开。maxHP83损失17；空升级池禁用。 |

界面继续使用 PR19 的主题、事件三行选项和选牌组件，只发送核心命令。事件图板显示「受限事件池（6种）」；新事件选项来自核心状态，显示真实代价、条件和结果。未取得实机截图，不宣称 UI 验收通过。

## 生产范围与全池模型的区别

生产池为4个普通事件+2个神龛、0个一次性事件；EVENT 的二级选择仍以25%优先神龛，另一支普通池，空池回退，抽中后从对应池移除。**这改变了具体事件分布，是用户明确批准的内容裁剪，不是原版全池概率一致。** 不从完整池抽出未实现事件后反复重抽，也不恢复固定 Purifier。

完整审查模型 `EventPool.new('full', noteAvailable)` 保留11普通、6神龛、13个默认一次性事件，及可用时插入的 NoteForYourself。按即时金币/楼层/章节/诅咒/遗物/时间过滤资格，并测试来源池去重、跨幕仅重建普通/神龛、一次性池全局保留。它**没有接生产内容执行器**。

受限池可能在一局中用尽，或只剩不满足金币条件的 Cleric。此时入场原子拒绝，地图明确提示选择其他路线或重新启程；不伪造免费事件。若所有可达分支均受限，需重新启程，这是首批内容范围的真实限制，TASK-13.1.2 继续补全。原有「至少留一张卡牌」核心前提也保留，尚非原版空牌组行为。

## 来源与未核实项

输入包 SHA256：`93086309e19c92fcd939e2e00417d72ee3fc3dc2c2b6c03ba681830c021712b9`。包基线 cf5f030；实际从最新 develop 95ce2bd 隔离开发，保留其后地图/触摸/退出等集成变化。

固定镜像 `purewhitelove/ButterflyGame@fc379c875c11e008e9c10548ac8e394c301c532f`：EventHelper.roll、AbstractDungeon.generateEvent/getEvent/getShrine、Exordium 初始化、EventRoom.onPlayerEntry，以及四个新增事件方法。8个包内已固定 blob 均重新下载并匹配 Git blob SHA，见 [来源核验](evidence/unknown-events-p0/source-verification.json)。[完整来源账本](evidence/unknown-events-p0/source-ledger.json)与[原始目录快照](evidence/unknown-events-p0/original-catalog.csv)保留包的基线状态；上表才是本轮已交付范围。

Java48 与洗牌规则参照 [Java Random](https://docs.oracle.com/javase/8/docs/api/java/util/Random.html) 和 [Collections.shuffle](https://docs.oracle.com/javase/8/docs/api/java/util/Collections.html#shuffle-java.util.List-java.util.Random-)；以独立 BigInt 测试交叉核对。未复制游戏代码、文案或素材进仓库。

仍为 `STRICT_PC_PARITY_UNVERIFIED`：第三方反编译镜像没有正版目标 JAR hash；Scrap Ooze 的26/100与标称25%冲突、Duplicator第一幕资格冲突未解决。诅咒、专属遗物、变牌、记忆小游戏和事件战斗尚未补全。普通遭遇仍沿用当前候选的楼层合法池/LCG选择，非原版遭遇队列；商店/宝箱现有经济差异及地图拓扑/全局RNG也没有因本切片对齐。

## 验证入口

`npm run check`；`node --test tests/event-random.test.mjs tests/unknown-events-fixtures.test.mjs`；`node scripts/test-lua.mjs tests/lua/unknown_events.lua`。新增生产规则14组、事件UI4组、地图耗尽诊断1组；220个固定种子组件入口覆盖四类房间/六事件，一条真实地图控制器路线遇到 Cleric、Golden Wing、Shining Light 并抵达Boss。该路线将敌人HP设为1以隔离导航测试，**不是自然平衡通关或平台实测**。

构建与完整检查的最终固定SHA、GIL hash、模块/控件读回及 CI 见本目录后续候选证据和 PR。官方导入、原神实机、`verify:ui` 的同候选截图门禁尚未完成；不使用旧候选日志替代。
