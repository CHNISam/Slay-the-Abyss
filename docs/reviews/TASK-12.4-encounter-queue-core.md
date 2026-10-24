# 第一幕遭遇队列核心与内容接线门槛

2026-10-24，基线 `76bbefade36b66c21c3c50964c8f28d8da9169a5`。本片交付可运行的 `src/lua/abyss_encounter_queue.lua`，**尚未接入 Run/Nodes，实际游戏仍使用旧遭遇选择**。正常新局种子已由先前修复处理，本片不重复它。

## 原始方法与证据

复用并重新读取上轮保存的固定原始文本，没有运行或复制第三方游戏实现：

| 来源 | SHA256 | 本片使用的方法 |
| --- | --- | --- |
| [Exordium](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/dungeons/Exordium.java) | `93808b9da69b76da6b8f0471cc3533fa113fa28298939bbc48eb55566a976c08` | 108..183：3弱敌、首强敌+12强敌、10精英、首强排除 |
| [AbstractDungeon](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/dungeons/AbstractDungeon.java) | `8fa0712818487a360c72950d053fe77e1a35efa967080723d15c69037092fd26` | 378..391：独立monsterRng；1037..1075：拒绝与重复消费；1674..1687、1826..1841：队首获取、移除与补充 |
| [MonsterInfo](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/monsters/MonsterInfo.java) | `7dc947c8de9d0c0d4addcf7aa676ad177ffb5527c85ed4988501ccc76a842d25` | 23..50：按权重稳定排序、float归一化、逐项float累加、严格小于 |
| [MonsterHelper](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/helpers/MonsterHelper.java) | `e6a60cdfa7af881d5f128a9532664ea33f32e71239cda49f3983fceac95a10e1` | 403..428、700..829：组名到编组和杂项随机消费 |

这些仍是社区反编译镜像，未经正版PC二进制认证。新的固定向量是独立 Python 整数和 IEEE754 对原文的解释，不称为官方/PC实测 golden；现有地图 golden 完全未改。

## 已实现的核心

- 初始化按原顺序先生成3个弱敌，再额外生成首个强敌及后续12个强敌，最后10个精英；普通与精英共用同一个 `monsterRng`，独立于其他类别流。
- 弱池4组等权；强池完整10组保留原权重，总权重16；精英3组等权。Lua稳定插入排序保留同权重声明顺序，调用现有 `abyss_sts_random.float32` 处理归一化和累加，不使用整数取模代替原float抽取。
- 普通队列拒绝最近两组同名，精英拒绝前一组同名，每次拒绝继续消费monsterRng；首强敌另按Exordium边界排除抽取，不静默删项或重分概率。
- `new(rawSeed)` 只接收规范signed64十进制字符串，直接交给既有生产STS RNG。包括 `2780424839485660359` 和signed64两端，不经 `tonumber` 或16位截断。
- `peek(state,tier)` 不修改输入；`consume(state,tier)` 返回 `name,nextState`，输入的全部嵌套表保持不变。未来调用者应在实际房间开战成功后才提交nextState，失败直接丢弃它。
- `snapshot/restore/clone` 保存版本、原始种子、剩余普通/精英队列及完整RNG双word/counter，隔离所有表。恢复拒绝多余字段、非法种子、稀疏数组、错池身份、弱强位置错误、重复窗口、可见首强排除错误、非法RNG及全零原语状态。它验证结构和规则约束，不是存档真实性签名；不宣称任意合法word都可通过seed重放认证。

API示例（仅说明未来接线，当前Run不调用）：

```lua
local sourceName, nextQueue, reason = Queue.consume(run.encounters, "normal")
-- 解析合法编组并在暂存Run中开战。
-- 全部步骤成功后才将nextQueue提交给正式Run。
```

原文 `getMonsterForRoomCreation` 的空普通队列路径会调用 `generateStrongEnemies`，但Exordium的 `generateExclusions` 又无保护读取空队尾；不能替它猜一个补充规则。正常第一幕最多13个可变战斗房间而预备普通队列有16项，本片将超范围耗尽明确拒绝为 `normal_queue_exhausted`。精英空队列补10个有明确方法依据，使用同一monsterRng继续抽；补充批次第一项没有已经移出列表的前批尾部历史。`peek`在精英耗尽时仅用私有副本计算补充，不推进持久状态；失败/丢弃的consume也不推进它。

向量的初始化终点是 `generateMonsters` 返回处。原始 `initializeBoss` 随后可能因解锁状态而消费同一个monsterRng来洗Boss列表；本片没有实现Boss解锁/洗牌，不能将这里的流末态冒充任意PC存档完整初始化末态。未来接线若实现该消费者，必须共享队列持有的同一monsterRng；本片精英补充向量只认证给定输入状态下的方法语义。

## 完整映射审计与阻塞

机器清单：[全部17项源池绑定](../rules/evidence/sts1-encounter-bindings.json)。11项“bound”仅表示当前组身份/成员装配可对应，并不认证其HP/AI/牌序/房间reseed。六项仍明确阻塞：

| 原始池项 | 当前差距 |
| --- | --- |
| 2 Louse、3 Louse | 当前固定颜色；原方法每个槽位各用一次misc Boolean选择颜色。 |
| Large Slime | 原版是一个队列组再用misc Boolean分大型酸液/棘刺；当前地图把两个ID各当独立遭遇。 |
| Lots of Slimes | 缺独立五槽组：3只小棘刺+2只小酸液按源池逐次无放回排列；`medium_slimes`两只中型并非合法替代。 |
| Exordium Thugs | 缺弱野生敌人+强人形敌人动态组。 |
| Exordium Wildlife | 当前jaw+green louse只是一种合法结果，缺Fungi/Jaw与随机Louse/SpikeM/AcidM的完整分支。 |

特别注意MonsterHelper的wildlife/thugs辅助方法：随机X/Y偏移也消费misc；部分方法先构造全部候选（含getLouse/getSlaver随机分支和各候选HP），最后才抽实际出场项。不能只抽一个已有ID，就把未出场候选的原始消费抹掉后宣称同seed一致。

因此**不按现有受限内容删除Lots/Thugs再归一化，也不把medium_slimes偷偷改名，不接Run/Nodes**。未来生产接线至少还需：

1. 补六项源组绑定、独立槽序/分支及完整流消费向量；处理无原版映射的medium_slimes和既有存档/清单。
2. Run持有raw seed与队列状态；真正普通/精英房成功进入时事务提交，问号转战斗复用相同普通队列。既有min/maxFloor只是当前候选条件，尤其Gremlin/Wildlife的minFloor5会错误拒绝原版第4场位于4层的合法结果，不能继续用楼层代替遭遇计数。
3. Map的旧预抽encounterId不能覆盖队列选择，显示、flow、版本与恢复必须一致；此处不改地图拓扑或七列UI迁移。
4. 全组合检查、同源候选编译/读回、实际普通战顺序与问号/恢复实机取证。整体TASK-12.4和首发遭遇验收仍未完成。

## 回归

- 首次真实红例：模块不存在导致固定向量测试失败，保留 `.artifacts/sts1-encounter-queue/red-vectors.log`。
- 独立 `tools/oracles/sts1_encounter_queue.py` 保留生成器hash，9个种子逐次float值、每次后置双word/counter、16个普通源名、10个精英源名及精英补充全部匹配。
- 核心12组：弱/强全部阈值、稳定同权重次序、最近两组拒重及消费、两类首强边界、精英前一项拒重、binary32、非变异consume、混合恢复、正常耗尽、失败注入、非法快照和池描述隔离。
- 审查另发现旧恢复校验会接受弱敌落入强队列或重复项；先存真实红例 `red-restore-integrity.log`，补结构约束后同组测试变绿。
- 机器映射测试核对源池17项无遗漏、6项blocked显式保留及11项当前成员形状；正常部署清单含新模块。最终定向检查与日志hash见Backlog备注/主线程集成证据；本片不跑完整check。

本轮无外发委派、无GUI/MCP写入、无候选构建/导入/实机，无push/merge。
