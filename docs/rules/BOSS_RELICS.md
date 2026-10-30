# 首领遗物补齐

规则依据为 STS1 源码镜像固定提交 `319009d5df0a82d9fb0f23cc22322286c6a87ec0` 的对应 `relics/*.java`，以及 `AbstractDungeon`、`PotionHelper`、`CombatRewardScreen`。不得根据可实现性筛选遗物或卡牌随机池。

`abyss_boss_relics` 提供15件新增首领遗物的独立规则。Cursed Key 的宝箱诅咒与 Ectoplasm 的金币限制复用原有真实入口。七件能量遗物调整战斗能量上限；Snecko Eye 在首抽前施加混乱，职业规则副本的每回合抽牌数增加2。Runic Dome 的隐藏仅影响表现，不能删除真实意图；Runic Pyramid 跳过常规弃手，但不能把所有手牌标为保留来触发 Establishment。

Runic Dome 的可见性边界覆盖主界面意图图标、数字与命中区、敌人详情，以及不带遗物快照的回放帧。隐藏时不调用数值意图投影，显示说明文字；真实敌人选招与结算保持原核心入口。`boss_relics_dome.lua` 用真实取得验证这些入口，并对照非圆顶角色的两回合实际敌人伤害。

Philosopher's Stone 给初始敌人和后来生成的敌人直接增加1力量。Mark of Pain 在有序开局抽牌之后，将两个临时 Wound 随机插入抽牌堆；调用原生 MakeTempCard helper，使用战斗 cardRandomRng。Runic Cube 在实际正生命损失时排入TOP抽牌动作；挡住的伤害不触发。

开局顺序的固定源码证据：`rooms/AbstractRoom.java:230` 起先排 GainEnergy，调用 `applyStartOfCombatPreDrawLogic`，排初始 DrawCardAction 与 EnableEndTurnButton，随后调用 `applyStartOfCombatLogic`；`characters/AbstractPlayer.java:1874` 起后者遍历遗物 `atBattleStart`。因此 MarkOfPain 在 `atBattleStart` 中的 BOTTOM MakeTempCardInDrawPileAction 位于初始抽牌之后。抽牌先后已用真实战斗手牌与全牌堆数量验证，未宣称独立Java RNG向量比对。

复杂取得必须经过 Run 的完整事务：

- Empty Cage 与 Astrolabe 记录 `pendingBossRelic.kind='cards'`，包含合法UID集合、选中UID与所需数量。`select(run,uid)` 拒绝重复、过期或非候选卡；选满后才执行删除/变换。牌数不足时立即处理全部可移除牌，零张时立即结束。
- Astrolabe 按选择顺序逐张移除、以 miscRng 变换并升级，再经永久取得入口加入牌组。完整原版池选到不支持的牌时，整个选择事务拒绝，不能重抽。
- Pandora's Box 先移除全部初始 Strike/Defend，再使用 cardRng 从职业完整普通、罕见、稀有池等概率有放回抽取。每张替换牌经过永久取得hooks，保留UID与蛋类升级等真实语义。
- Calling Bell 经永久取得入口获得不可移除的 CurseOfTheBell，再从完整遗物池各取一个普通、罕见、稀有的screenless候选。三个候选独立领取。
- Tiny House 随机升级一张可升级牌（即使候选为空仍消耗一次misc randomLong洗牌）、增加5生命上限并普通回复5生命。50金币、药水与普通卡牌奖励分别领取。药水是职业完整池均匀抽取，消耗一次miscRng，不做稀有度重抽。TreasureRoom/RestRoom不生成卡奖；BossTreasureRoom仍生成。

奖励记录 `pendingBossRelic.kind='rewards'`；`claim(run,kind,choice)` 支持 `gold`、`potion`、`card`（0跳过）、`relic`（1起始索引）、`done`（明确离开奖励并放弃剩余）。取得药水因容量不足拒绝时，奖励继续存在。每项领取均为独立事务，重复领取不重复授予。父级UI必须保留原房间/纳奥/商店的返回路径，pending未处理前不能直接推进原房间。

普通战斗的 Prayer Wheel 用 `abyss_relic_card_rewards` 保存两份独立 CARD RewardItem。第二组顺接第一组的卡牌RNG与稀有度偏移，不增加药水掉落roll。精英、首领与事件战斗不额外生成组。Singing Bowl 在每组提供独立增加2生命上限的替代选项，并经过普通治疗规则；绽放印记阻止治疗，仍增加上限。原 `Run.claimCardReward(0)` 是显式放弃当前组；实际UI“返回奖励列表”只关闭modal，不消费任何组。卡牌、颂钵和关闭命令均须匹配当前modal的源owner；一次成功后旧token失效。Sensory Stone 每组同样有颂钵选项，Question Card 与 Crown 分别调整各组候选数。

离线回归入口：`node --test tests/boss-relics-missing.test.mjs`。覆盖真实Run取得、能量、首抽混乱、力量、伤口、生命损失抽牌、两次选牌、升级变换、潘多拉永久取得hooks、小屋独立奖励、颈圈第七张拒绝、金字塔真实结束回合、钟独立领取、失败回滚，以及完整原版队列中15个指定身份的标准首领宝箱创建、打开和领取。宝箱用受控队首，不宣称自然种子覆盖。此证据不替代平台导入、键鼠试玩或实机验收。
