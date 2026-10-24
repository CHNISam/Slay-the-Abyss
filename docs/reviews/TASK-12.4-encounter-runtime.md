# 实际房间接入原版遭遇队列

2026-10-25，复用 TASK-12.4 / TASK-15。基线 `e2eefaa`，按顺序接入原地图测试、完整 Map v3、六组动态编组；本片让这些离线模块成为正式 Run/Nodes 的实际路径。没有改地图算法、既有地图 golden、敌人数值或奖励界面。

## 实际行为与接口

`Run.new` 保存 raw signed64 `runSeed` 和完整 `encounters`；后者包含同一个 monsterRng 生成的 16 项普通、10 项精英队列。`Run.startRoomCombat(run,tier)` 是正式入口：克隆/暂存消费、装配敌人、创建战斗、完成前后开场遗物后才一次提交。普通房与问号变成的战斗都传 `normal`，精英传 `elite`。失败、非法 tier、外来 seed、错误队列、无合法目的地不会提交队列、原对象或地图进度。

`abyss_room_encounters` 明确绑定全部 17 个源组名。六个曾阻塞的动态编组实际使用 `Combat.new(sourceEncounter=...,roomStreams=...)`；Small Slimes 与 Gremlin Gang 也改为构造回调立即组装。Lots/Thugs/统一大型软泥的运行时身份分别是 `lots_of_slimes`、`exordium_thugs`、`large_slime`。历史 `data.enemies.encounters` 的显式 ID 示例仍可由 `Run.startCombat` 用于定向回归；它们不再决定地图房间的生产池。`medium_slimes` 没有进入源池，也没有冒充 Lots；两个大型示例不是两个独立抽奖项。完整绑定见[机器记录](../rules/evidence/sts1-encounter-runtime.json)。

Map 只生成拓扑、房型与导航，不再按每个地图节点均匀预抽 encounterId，也没有旧 encounterSeed / encounterRandomSeed。相同 12 份完整 golden 不变。Map v3 的 sourceSignature 改为 `run-source-queue-v1`，旧预抽格式的快照明确不兼容；恢复不会重选敌人或消费 Run 队列。Nodes 在成功开战后把实际 encounterId / encounterSource 放入 nodeFlow。初次进入也校验 Run 与 Map 的 raw seed 所有权。

`Run.snapshotEncounters/restoreEncounters` 是队列检查点边界，保存 raw seed、floor 与 Queue 快照；校验完再替换。它不是整局退出续存，不保存地图、牌组、战斗或账户解锁，也不是防篡改签名。活动房间、外来 seed、不同 floor、非法嵌套状态均拒绝。全局存档仍按既有范围延后。

独立复审发现的同层旧检查点漏洞已另片修复：新局与首房完成后的 `floor` 都是1，旧版只检查楼层会把已消费的队列15项回退为16项。检查点现为 v2，绑定 `roomGeneration`；仅成功接受房间才推进，失败不推进，战斗暂存到 Nodes 提交时才公开。恢复还核对当前普通/精英剩余项数，不能仅改版本标签就回退消费。真实初始数值出牌获胜→Proceed→完成首房的红绿回归、合法同边界恢复及旧表引用原子性见[补充证据](../rules/evidence/sts1-encounter-checkpoint.json)。v1检查点明确拒绝；不把该接口扩成整局续存或防篡改签名。

## 固定来源与初始化顺序

固定社区反编译镜像 `aeubanks/sts@319009d5df0a82d9fb0f23cc22322286c6a87ec0`；不是官方开源、正版 PC 二进制认证或 PC 实测。方法体在本轮重新读取，字节 hash 见机器记录；仅解释方法与独立实现，没有部署其代码。

- [AbstractDungeon:267–270](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/dungeons/AbstractDungeon.java#L267)：transition setup → generateMonsters → initializeBoss → setBoss。队列先全部生成，普通/精英共享 monsterRng；没有按走过的地图节点逐个抽组。
- [Exordium:108–183](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/dungeons/Exordium.java#L108)：前三弱敌、首强排除、12 强敌、10 精英。沿用已有独立队列向量及权重/拒重实现，未删池或重分概率。
- [Exordium:186–220](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/dungeons/Exordium.java#L186)：Guardian 未见分支直接放入 Guardian，再复制成双项，没有 randomLong；Daily/all-unlocked 分支才用 monsterRng.randomLong 播种 Java 洗 Boss 列表。本片**明确只提供 `guardian-unseen` 首发 profile**；未实现账户解锁、Daily 或 all-unlocked，非该 profile 的 Boss 入口拒绝，不能把未消费的一次源抽样说成全解锁原版初始化。
- [AbstractDungeon:1667–1731、1826–1841](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/dungeons/AbstractDungeon.java#L1667)：原方法在离开旧战斗时移除旧队首，并在新层创建前按 `Settings.seed+floorNum` 重建 HP/AI/shuffle/card/misc。项目在成功接受入口时移除该项，并将活动源名保存在 Run/nodeFlow；下一房间所见队首相同，失败不移除，活动战斗不通过 peek 重建。
- [MonsterHelper:403–428、700–829](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/helpers/MonsterHelper.java#L403)：按顺序选择颜色/成员并立即构造，Thugs/Wildlife 的弃选候选已经构造，仍消耗 HP/Bite。X/Y 偏移是 MathUtils，绝不记为 misc。
- [AbstractMonster:751–765](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/monsters/AbstractMonster.java#L751)：`setHp(hp)` 委托 `setHp(hp,hp)`，因此 Guardian 固定 240 仍有一次 HP 随机调用。[Guardian 构造](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/monsters/exordium/TheGuardian.java#L75)已另取原字节重核，hash 与旧账本相同。
- [MonsterGroup:57–74](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/monsters/MonsterGroup.java#L57)及[AbstractPlayer:1546–1584](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/characters/AbstractPlayer.java#L1546)：先构造全组，再依序 init/AI；牌组初始化后才逐敌 preBattle。Louse 构造 HP→Bite，选中的 Louse 稍后再抽 CurlUp；弃选 Louse 不进入 init 或 preBattle。

## 随机流的本次边界

raw seed 加楼层用十进制有符号 64 位加法并保留 Java long 溢出，不经 tonumber 或 16 位截断。正式战斗的 monsterHpRng 与 aiRng 是独立 STS RandomXS128 状态；HP、Bite、CurlUp 用 HP 流，主 roll、Acid S 的 Boolean、条件 Boolean/float 用 AI 流。之后敌方行动与分裂子怪初始化也保持同一 AI 流。旧显式数组测试保留其 LCG 注入，不把该入口的自重放当源流证明。

misc 在每次新房间按 raw+floor 重建，独立负责颜色/成员/索引。Thugs/Wildlife 的 visualFloat 回调使用单独的 cosmetic 状态，偏移范围和 binary32 加法对应源方法，**没有重放全局 libGDX MathUtils 的动画/视觉熵轨迹**；现有平台布局也不以这些坐标重排敌人。视觉状态不影响任何游戏随机流。

**必要缺口仍在**：牌组 shuffle/cardRandom 的所有实际消费者、战后卡牌/金币/遗物与其他奖励流尚未整体迁移，仍有 legacy seed 消费。Combat 暴露了 raw roomSeed 与单独 shuffleRng/cardRandomRng 作为后续可调用边界，它们当前不宣称已按原版消费；126 份构造向量显式排除这些流。不能据此声称整局同 seed PC 重播、所有随机流或 TASK-16.1 完成。

## 验证与后续门禁

首个真实红例是篡改旧地图预抽 ID 后仍走 `medium_slimes`，在 `wrong_floor` 失败；修复后同例实际消费源队列 Cultist。独立 Python 整数 oracle 不读取项目 JSON、不调用 Lua，覆盖 7 组 raw seed/floor（含 room seed 0、超 16 位、大整数、signed64 两端溢出）×18 组（17 队列组+Guardian）=126 个构造。

每项核对所选身份、HP、Bite、CurlUp、开场意图、每次 HP/AI/misc 调用交错、后置双 word/counter；包含 Thugs/Wildlife 弃选候选。运行时 10 组检查队列 owner、tier 共享、前三弱敌跨层、第四场第4层强敌、raw/legacy 隔离、后续 AI 流、失败/非法/恢复原子性、耗尽与 Boss profile 拒绝。既有 Small Slimes18、Gremlin29（含1680路径）、Nodes21、Map10、restore5 及 256 seed 全17组覆盖等定向回归按机器记录保存。未改12图 golden。

完整 check、组合审查由主线程统一；本片没有运行完整 check、GUI、MCP 写入、候选编译、官方导入、千星实机、push 或 merge。TASK-12.4/15 的平台与广义 AC 保留。新的运行时 ID 与旧明细清单须由主线程在 TASK-47 冻结记录中对齐后再做同源候选验收。

本片是高耦合生产接线，由 Codex 直接处理，未向外部模型发送源码、未使用收费模型回退；未估算额度节省。
