# 第三幕 Shapes 独立切片

本片在 Orb Walker 基础上增加 Repulsor、Spiker、Exploder，以及原来源 `3 Shapes`、`4 Shapes`、`Sphere and 2 Shapes`。最后一种复用已核对的 Spheric Guardian，不拿球体替代 Shape。第三幕 16 种不同遭遇中已提供 4 种，另 12 种仍明确拒绝；母遭遇队列和权重未改。没有自然全幕通关、平台导入、实机或发布结论。

固定行为参考为第三方反编译镜像 `aeubanks/sts@319009d5df0a82d9fb0f23cc22322286c6a87ec0`。本轮只读本地固定 ZIP；[来源锁](../../tests/fixtures/act3-shapes-source-lock.json) 保存 ZIP 和 22 个原始成员的逐字节 SHA256、对应方法、独立模型与依赖。Java 原文未入产品库，未运行原作 PC 二进制。敌人使用固定源英文名称，未猜中文译名。

| 来源方法 | A0 行为 |
| --- | --- |
| `MonsterHelper.spawnShapes/getShape` | 原池顺序为 Repulsor 两项、Exploder 两项、Spiker 两项。每次 misc 抽当前索引、移除该项、立刻完整构造该怪，再抽下一个；3/4 怪分别消费 3/4 次 misc 和 HP。构造常量 superclass HP 不抽随机，实际 setHp 各抽一次；Exploder 的 30–30 也消费一次。所有构造完成才按组序初始化 AI。 |
| `MonsterHelper.getAncientShape/getEncounter` | Sphere 两次各自从 misc 0..2 独立选择 Spiker/Repulsor/Exploder，逐个立刻构造，然后构造 Spheric Guardian；不是六项池移除。Sphere 固定 HP20、不抽 HP，保留 Barricade、Artifact3、格挡40和原 AI。 |
| `Repulsor.getMove/takeTurn` | HP29–35；主 AI 小于20且上招非攻击时攻击11，否则双 Dazed。每次主选招都抽一次；允许连续 Daze，禁止连续攻击。 |
| `MakeTempCardInDrawPileAction.update`、ShowCard effect constructor、`CardGroup.addToRandomSpot` | 两张未升级 Dazed 为不同实例、顺序分配新战斗 UID、不带 deckUid。逐张放进抽牌堆：空堆不抽 cardRandom，非空抽 0..size-1，保留原顶牌；空堆创建两张因此只抽一次。放置不用 shuffleRng，随后真实补抽/空洗牌与 Ethereal 消耗复用原生命周期。 |
| `Spiker.usePreBattleAction/getMove/takeTurn` | HP42–56，初始 Thorns3，攻击7，强化 Thorns2。50 阈值且攻击不连发；`thornsCount > 5` 才锁攻击，所以最多强化6次，达到15棘刺。计数在强化招式执行时增长。 |
| `Exploder.getMove/takeTurn`、`ExplosivePower.duringTurn` | HP30，攻击9；前两次攻击，第3次 UNKNOWN 空招式，仍先消费 RollMove。开战 Explosive3，前两次行动后减至2/1；第3次队列为 RollMove→Suicide→30 THORNS Damage。 |
| `GameActionManager.getNextAction/clearPostCombatActions`、SuicideAction、DamageAction | `duringTurn` 在 takeTurn 入队后执行。自杀不是普通攻击/HP损失，不触发自身棘刺；其后 DAMAGE 即使是最后一只怪也保留。死亡源仍可造成这次30伤害；不使用力量/虚弱/易伤、不递归棘刺，消耗玩家格挡并受 Intangible 限制。玩家随爆死亡时判败北。提前被杀、行动前毒死或玩家先死亡则不补爆炸。 |

实现仅扩已有 Act3 模块与已登记的 Formation/Combat 边界，没有新增架构模块或循环豁免。Explosive 的窄 `afterTurn` 在既有 `afterAction` 选招之后、结局检查之前运行；自毁通知由 `Combat.suicideExploder` 保持在已有死亡账本边界，尾伤只调用公共 `Combat.retaliate`。未更改其它怪的通用 damage 清场规则。Act3 已有 Snapshot 包装覆盖这两种 endTurn 调度和新动作的失败回滚。

**组合依赖：Buffer 未在本片基线实现。** 固定 `BufferPower.onAttackedToChangeDamage` 已核读并锁 SHA；本片没有添加一次性 Buffer 检查或消费。父线程合入正式 Defect 公共 incoming 钩子后，须补公共 THORNS→Buffer 组合验证，不能把本片的格挡/Intangible 检查当作 Buffer 已过。Intangible 短测只注册源状态元数据来测试既有伤害算式，不宣称已实现其职业卡或完整状态周期。

`node --test --test-concurrency=1 tests/act3-shapes.test.mjs tests/act3-orb-walker.test.mjs tests/act2-enemies.test.mjs` 在原默认预算内定向验收；Shapes 包含17组，Orb12组、Act2 34组保持通过。已有 encounter_formations 7组、encounter_formation_combat 4组、queued_enemy_roll 21组和 combat 23组也串行通过。最小公开 Run 的初始红为 seed3 原首项 `3 Shapes` 返回 `act_content_unavailable`；Host 初始红为 Dazed 显示“意图：未知”。对应入口与描述修复后通过。完整检查及平台门禁未运行。

[独立 Python 模型](../../tools/oracles/sts1_shapes.py) 不导入生产 Lua 或游戏数据，使用已有独立64位 RNG 解读。`python tools/oracles/sts1_shapes.py --lua` 可重生 [9条完整向量](../../tests/fixtures/act3-shapes-vectors.lua)，测试逐项比对成员、HP、开招和 misc/HP/AI 的完整 words/counter，并检查实际 misc→HP 构造交错。运行向量按 LF 归一化锁定以支持 Windows checkout；原始 ZIP 成员的哈希不归一化。

三个公开入口分别从真实原队列定位 seed3/位置1、seed1/位置4、seed12/位置3，再调用 Run.startRoomCombat；跳过队列前缀仅是明确的章节/队列边界 fixture，没有伪造胜利或重抽遭遇。真实 Host 从 start 创建的同一 Run 执行 seed1 Shapes 四怪前三轮；来源模型给出每轮受伤9、16、48（其中爆炸30），核对倒计时、敌人名字/HP、UNKNOWN 图标和自毁后的活怪压缩槽。它没有注入 HP 来宣称自然通关。

17组还覆盖 Repulsor19/20、Spiker49/50与六次强化、多段真实打牌反伤、双 Dazed 的 UID/空堆/空洗牌/Ethereal、自爆最后一只/有队友/格挡/Intangible/无递归/同时死亡优先级、提前普通击杀/毒杀、第二张 Dazed 放置与自毁伤害后的双调度故障回滚、晚构造失败和大 UID 拒绝。Orb 的原“未实现来源”用例只将已开放的 Shapes 改为同一来源队列后面的 Spire Growth，保留正常/精英/Boss/第四幕拒绝及回滚断言。

UI 增量只有 `enemyDazedDraw` 的副图标分类和“双 Dazed 随机放入抽牌堆”详情。当前基线仍在 `abyss_battle_ui.lua`；父线程集成到新版 IntentView 时只移植这一 op，不回填旧 UI。固定 Luacheck 新核心改动为零诊断；历史 Effects/UI 告警按原文本和消息严格重定位，未改 baseline。
