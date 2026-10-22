# v0.1.0 内容基线

数据检查、平台编译、导入副本和真机试玩分别验收；本目录当前仅有数据，尚无可玩运行时。

| 文件 | 基线 |
|---|---|
| cards.json | 首轮37张战士运行卡池；初始 5 打击 + 4 防御 + 1 痛击 |
| reference/warrior75.json | 另一会话75卡及3状态牌原表，原样存证；含待核对数据，不能直接导入运行时 |
| enemies.json | 19 普通变体 / 3 精英类型 / 1 Boss；14 普通、3 精英、1 Boss 遭遇 |
| statuses.json | 9 状态 |
| relics.json / potions.json | 7 遗物 / 7 药水 |
| rules.json | 角色、地图、营地、商店及奖励常数 |

75 张为完整对标规模，本 Sprint 首轮保留 30+。完整参考表原样保留，首轮37张从中规范化op、保留数值，含X费用以costMode表达。参考表有28种尚未纳入运行契约的op及triggers，不能据此声称75张可玩。来源及有意适配见 SOURCES.md。

## 效果契约

upgrade 为浅覆盖：未写字段继承基础版，effects 整体替换。id 为稳定引用，卡牌实例另有独立实例 id。

攻击依次计算基础伤害加力量、虚弱乘 0.75、易伤乘 1.5，最终向下取整且至少 0，再扣格挡与生命。多段独立计算。格挡增加敏捷，再乘脆弱 0.75 并向下取整。中毒/失血/荆棘不是攻击，不吃力量/易伤，也不被格挡抵消。

damage 对所选敌人（敌方行动则对玩家），damageAll 对全部存活敌人。block/draw/energy/heal 对拥有者。applyStatus/applyStatusAll 对敌人，gainStatus 对自己。力量/敏捷允许有符号增量，其余状态不得负数。gainTemporaryStrength 的增量在自己回合结束移除。

damageEqualToBlock 使用当前格挡作为基础伤害，doubleBlock 翻倍当前格挡。discardRandom 随机弃手牌；exhaustRandom/exhaustChoose 消耗其他手牌；putOnDrawPile 选其他手牌置于抽堆顶。无可选牌时跳过。addCardToDiscard/addCardPerTurn 生成指定 id 的独立牌实例，升级愤怒生成副本继承升级。

conditional 在 if=target_vulnerable 时执行 then；noDrawThisTurn 阻止后续抽牌。blockPerTurn 在拥有者回合结束生效，gainStatusPerTurn/addCardPerTurn 在拥有者回合开始生效。increaseDamageThisCombat 只修改本牌实例，战斗结束复原。healEqualToDamageDealt 回复本次出牌实际扣除敌方生命的总和，不能回复被格挡吸收部分。

exhaust=true 出牌后消耗；ethereal=true 仅在回合结束还留手时消耗，不代表出牌消耗。能力牌出牌后移出本场牌堆。condition=only_attacks_in_hand 要求手牌全为攻击牌。costMode=all_energy 消耗全部剩余能量并按消耗点数重复 effects；0 能量产生 0 次。

## 回合、遭遇和经济

抽堆空时仅将弃堆种子洗入。角色在自己回合开始清空旧格挡（壁垒例外），结算中毒，若存活再结算回合开始效果。玩家刷新能量、抽牌后行动，弃牌/虚无处理后敌人按已显示意图行动；完成才推进索引，不能执行时重掷。易伤/虚弱/脆弱在拥有者回合结束减 1；再生在拥有者回合结束先回复后减 1。每次伤害后检查胜败，死亡敌人不行动。格挡保留至自己下回合开始才能吸收敌方攻击。

敌人按 intents 从 0 开始确定循环，tier 和层数过滤遭遇。精英从第 6 层起，14 层营地，15 层 Boss。这里只定义内容，不意味行为已在运行时实现。

遗物 combat_start 在基础能量刷新/抽牌之后各执行一次，避免灯笼被刷新覆盖；combat_end 只在胜利后触发。药水仅玩家战斗回合可用，成功后消耗槽位。营地回血与升级二选一；交易先验证金币/库存/目标，再原子提交。血量不超过上限。

## 容量、效果来源与跨节点边界

addCardPerTurn 生成的牌加入手牌；addCardToDiscard 加入弃牌堆。生成手牌若超过 maxHand=10，该牌进入弃牌堆。抽牌动作每次先检查手牌容量；达到 maxHand=10 立即停止，不移动抽牌堆/弃牌堆，也不因此洗牌。只有尚有手牌空位且抽牌堆为空时才将弃牌堆洗入。依据：[初代杀戮尖塔官方 Weekly Patch 47](https://store.steampowered.com/news/posts/?appids=646570&enddate=1542372031)。战斗结束删除所有战斗生成牌，仅保留局内永久卡组及其升级等级。

攻击牌和敌人意图中的攻击应用上述攻击修正；技能/能力提供的 block 应用敏捷和脆弱。本项目药水的 damage/block 为固定点数，忽略力量、虚弱、易伤、敏捷和脆弱（火焰药水仍被格挡吸收）；此为显式简化。遗物提供的 block 使用固定点数。blockPerTurn 属于卡牌持续效果，其格挡应用敏捷和脆弱。UI 文案按实际效果来源显示。

每场战斗建立独立战斗态：全部状态（含力量、敏捷、壁垒、中毒）、临时力量、格挡、能量、持续能力、禁止抽牌、牌实例伤害增长、消耗堆均不跨战斗保留。局内只持久化当前/最大生命、金币、永久卡组及升级、遗物清单、药水槽位、地图与路线进度及随机种子。胜利后先结算 combat_end 遗物回血，再清理战斗态，发奖励；失败跳过遗物回血并进入失败结算。
