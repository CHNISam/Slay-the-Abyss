# 出牌历史、FTL 与 Follow-Up 时序审计

## 固定资料与范围

2026-10-25 只读核查 `aeubanks/sts@319009d5df0a82d9fb0f23cc22322286c6a87ec0`。这是声称 V2.3.4 的社区反编译镜像，未认证官方 JAR，也没有原版客户端实测。本文件记录资料中的行为与行号，不复制实现，不证明当前核心已经符合这些规则。

本地缓存 `/tmp/sts-exhaust-audit` 的 AbstractPlayer、GameActionManager、UseCardAction、AbstractCard 已逐字节比对固定 ZIP 成员相同；其余文件直接读取同一 ZIP，读取时由 zipfile 校验成员 CRC。ZIP SHA-256 为 `3f42bd7dde08126a9a8a02fc8eed8856c7b8b0dda551f50c62ced838e41ed458`。

## 一张合法卡的同步时序

[GameActionManager.java:203–237](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/actions/GameActionManager.java#L203-L237) 与 [AbstractPlayer.java:1340–1361](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/characters/AbstractPlayer.java#L1340-L1361) 确定以下顺序：

1. `canUse` 成功（或 `dontTriggerOnUseCard` 特殊分支）后，若没有 `dontTriggerOnUseCard`，同步执行 `onPlayCard`：玩家 powers → 敌方 powers → 玩家 relics → stance → blights → 手牌 → 弃牌堆 → 抽牌堆。此时历史尚未加入当前卡。
2. 玩家整数 `cardsPlayedThisTurn` 加一；GAM 的 `cardsPlayedThisTurn`、`cardsPlayedThisCombat` 依次加入当前卡引用（235–237）。没有按 UID 去重，同一实例再次合法打出也增加记录。
3. 经过敌人目标是否仍有效的检查（253–271）才进入 `AbstractPlayer.useCard`。因此历史写入不等于一定调用了 `card.use`：通过前述门槛后、目标已死或缺失的特殊 cardQueue 项可能写入历史而跳过 use。单纯 `canUse` 失败不写历史。
4. `calculateCardDamage(monster)`（1344），随后 X 费参数调整，再执行 `card.use`（1351），构造并排入该卡原生动作。
5. 执行 `new UseCardAction(card, target)` 的构造函数，随后才将这个 UseCardAction 加到队尾（1352）。Java 参数求值发生在 addToBottom 调用之前；构造函数排入的动作可位于 UseCardAction 之前。
6. 手牌 `triggerOnOtherCardPlayed(card)`（1353–1354），然后才移出当前卡（1356）、设置 `cardInUse`（1357）及支付普通正费用（1360–1361）。

`card.use`、UseCardAction 构造函数和 `triggerOnOtherCardPlayed` 都已能看到包含当前卡的两个 GAM 历史列表。它们同步调用期间当前卡仍在手牌；后续队列动作执行时已移出手牌。

[UseCardAction.java:29–63](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/actions/utility/UseCardAction.java#L29-L63) 构造期间顺序为：记录 exhaust 状态 → 玩家 powers.onUseCard → relics.onUseCard → 手牌/弃牌堆/抽牌堆的 triggerOnCardPlayed → 敌方 powers.onUseCard。相关回调受 `dontTriggerOnUseCard` 约束。手牌 triggerOnCardPlayed 循环没有排除正在使用的卡。

[CardGroup.java:977–984](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/cards/CardGroup.java#L977-L984) 的 `triggerOnOtherCardPlayed` 则先对其他手牌回调（明确排除当前卡），再调用玩家 powers.onAfterCardPlayed。[UseCardAction.java:71–81](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/actions/utility/UseCardAction.java#L71-L81) 的 powers.onAfterUseCard 在 UseCardAction 首次 update 时才发生，与上述同步回调并非同一个时点。

普通 autoplay 并不统一排除历史；门槛是 `dontTriggerOnUseCard`。失败 autoplay 的特殊清理分支（GAM 288–290）不能按正常合法出牌累计。不要把不同来源的“出牌”“清理卡牌”和“动作成功”合并成一个无条件计数入口。

## 回合与战斗重置

[GameActionManager.java:318–352](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/actions/GameActionManager.java#L318-L352) 的新回合阶段先于 start-of-turn hooks 将玩家整数计数归零（322）；按 relics、pre-draw cards、cards、powers、orbs 顺序同步调用开回合 hooks（331–335），再清空 GAM 的回合历史（340），最后构造普通抽牌与 post-draw hooks（349–352）。因此同步构造开回合效果期间，整数计数和 GAM 回合列表存在不同清空时点；已排队的普通抽牌执行时回合列表已清空。

GAM 的战斗历史在回合交界处保留。[GAM.clear:403–410](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/actions/GameActionManager.java#L403-L410) 同时清空两份列表；[AbstractPlayer.preBattlePrep:1546–1553](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/characters/AbstractPlayer.java#L1546-L1553) 调用 clear 并重置玩家整数。实现 Watcher 的上一张牌类型时，应在战斗初始化重置，在普通回合开始保留。

## FTL：阈值与真实队列位置

[FTL.java:20–28、55–59](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/cards/blue/FTL.java#L20-L28)：费用 0、伤害 5、阈值 3；升级伤害增加 1、阈值增加 1。它先排一个 FTLAction，并在 card.use 时构造 DamageInfo。

[FTLAction.java:19–31](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/actions/defect/FTLAction.java#L19-L31)：FTLAction update 先把 DamageAction 加到队尾，再读取 `cardsPlayedThisTurn.size() - 1 < cardPlayCount`，成功则将抽 1 张加到队首。这里读取的是动作执行时的列表，减一排除已经入列的当前 FTL。

| 出牌前本回合已打张数 | 基础 FTL 抽牌 | 升级 FTL 抽牌 |
| --- | --- | --- |
| 0、1、2 | 是 | 是 |
| 3 | 否 | 是 |
| 4 及以上 | 否 | 否 |

[GAM.getNextAction:174–183](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/actions/GameActionManager.java#L174-L183) 先取普通 action，再取 pre-turn action，最后才取 cardQueue。无其他 hooks 时，初始队列为 `[FTLAction, UseCardAction]`；FTLAction 已被取出执行后变为 `[Draw1, UseCardAction, DamageAction]`。所以抽牌早于 FTL 自身移入弃牌/消耗堆，也早于其伤害与最终击杀。不能沿用“普通伤害后抽牌”模板，也不能抽回这张尚在使用中的同一实例。

若构造期间已有 onUseCard 等尾部动作，它们保留原有顺序，位于 Draw1 之后、FTL 的 DamageAction 之前。没有达到抽牌条件时，仅省去 Draw1。`addToTop` hooks 的相互顺序仍应按实际动作处理，不能把此简化示例当作所有 hooks 的完整固定队列。

## Follow-Up：上一张牌跨回合，返能排在伤害后

[FollowUp.java:22–36](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/cards/purple/FollowUp.java#L22-L36) 是费用 1、伤害 7 的 Attack（升级增加 4），use 先排 DamageAction 再排 FollowUpAction；手牌发光检查使用战斗历史的最后一张牌。

[FollowUpAction.java:18–27](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/actions/watcher/FollowUpAction.java#L18-L27) 在执行时检查战斗历史至少 2 张，且倒数第二张为 Attack，成功才将 GainEnergyAction(1) 加到队首。当前 Follow-Up 此时已是最后一张记录。因此：

- 新回合第一张 Follow-Up 可以接上回合最后一张 Attack 返能；上一张 Skill/Power/Status 等会中断 Attack 条件。
- 回合结束、喝药等没有向出牌列表插入卡的动作不会自行覆盖上一张牌类型。
- `previousCardType` 若用简化字段实现，应保留追加当前卡之前的历史值用于判定，并在本次合法出牌之后更新。不能到返能动作里读取“当前最新类型”而把 Follow-Up 自身当作上一张 Attack。
- Follow-Up 的返能动作晚于原生伤害。最终敌人被伤害击杀时，[DamageAction.java:83–85](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/actions/common/DamageAction.java#L83-L85) 调用清理；[GAM.clearPostCombatActions:119–125](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/actions/GameActionManager.java#L119-L125) 不保留 FollowUpAction，故其不会再构造返能。这与 FTL 的击杀前抽牌顺序不同。

## 普通伤害与格挡的数值构造边界

`AbstractPlayer.useCard:1344` 在 `card.use` 和 UseCardAction 构造回调之前调用 calculateCardDamage；[AbstractCard.java:2298–2330](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/cards/AbstractCard.java#L2298-L2330) 同时先算 block，再算单体伤害的 powers、stance、目标 powers 与最终修正，最后取整。多目标对应分支位于 2331–2377。

- [Strike_Red.java:44](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/cards/red/Strike_Red.java#L44) 在 card.use 时把已算好的 `this.damage` 传入新 DamageInfo。[DamageInfo.java:20–25](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/cards/DamageInfo.java#L20-L25) 仅保存 owner、type、base、output；不会自动重算 powers。FTL 的 DamageInfo 同样在 card.use 时构造，随后 FTLAction 保留该对象。
- [DamageAction.java:26–31、60–85](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/actions/common/DamageAction.java#L26-L31) 保存传入的 info，执行时才检查目标/来源有效性并调用 target.damage(info)。保留 NORMAL 类型及实际执行时的伤害接收、格挡等处理；“构造时保存伤害数值”不等于绕过伤害管线的纯扣血。不要在动作执行时再次对已计算的值套用力量、虚弱、易伤或姿态，也不要因为后续 onUseCard 改变这些状态就重算之前已构造的普通伤害。
- [AbstractCard.applyPowersToBlock:2276–2291](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/cards/AbstractCard.java#L2276-L2291) 从 baseBlock 经玩家 powers.modifyBlock、modifyBlockLast、非负处理及取整，写入 this.block。[Defend_Red.java:31](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/cards/red/Defend_Red.java#L31) 在 card.use 时把这个数值传入 GainBlockAction。
- [GainBlockAction.java:17–29、47–53](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/actions/common/GainBlockAction.java#L17-L29) 保存 amount，执行时调用 target.addBlock(amount)，不会重新应用敏捷/脆弱。[AbstractCreature.addBlock:412–433](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/core/AbstractCreature.java#L412-L433) 仍会执行获得格挡时 relic/power 回调，最后才增加 currentBlock。固定格挡奖励直接传 amount，不能错误套入普通卡牌 baseBlock 修正。

这些是已读普通动作与示例卡的构造边界；具有专门 action 的卡仍须独立核查是否故意在更晚的时点读取状态。此次未修改核心、卡池、随机数或测试，未运行全量检查。

## 源文件 SHA-256

路径均相对固定提交根目录；链接中的行号按这些字节计数。

| 文件 | SHA-256 |
| --- | --- |
| characters/AbstractPlayer.java | `2720ba8dd7a216781a3b2fcb709f5ec67dc9b2559af25f7f6b89df1ef0947d95` |
| actions/GameActionManager.java | `a47d1ee9c6b2e194b7d3ef311328f2a15e38f5630330689e438e46685b94d6c3` |
| actions/utility/UseCardAction.java | `90213939af6d7ec83dea01bb2feef4ba762a93400dc1535732e2eebcdb6cab0f` |
| cards/AbstractCard.java | `bcd472ececfd8ce4150ccd4eb6dd07a2e2dc43e139196fe00de34705cf1a2a61` |
| cards/CardGroup.java | `03de4e22ab22bedf1d90df72bdc83f033ff6aa776ad9d8f7259e1ee9293f7fa8` |
| cards/blue/FTL.java | `5d54dcbcb040688b0182bb5df6af6ecffa2160330210fdbc66fd90ac6f7a617b` |
| actions/defect/FTLAction.java | `79b720f12d15e35567f7e74e49a0d2df5a3857d63a95b657788792a6032ad8c4` |
| cards/purple/FollowUp.java | `fb070528971876dcb2309b003d8b7b04b818d95c754156c00af419c0a4f30247` |
| actions/watcher/FollowUpAction.java | `c4bdfea34fb8ed2c1177ad2e9a59a539177843d1a61e8348c66f4b1c30f3a88a` |
| cards/DamageInfo.java | `cc16469d78473a1d37bf18a152014d9d1625859a5a7bd0923387f4ee8d942a5a` |
| cards/red/Strike_Red.java | `e419fefb5b1bcc34175570fbafb8b68cc2a014ec4e7d974674586057dd22d37b` |
| cards/red/Defend_Red.java | `4be83355fcb0d81f5bb5497f5e36c49e33f726fe3c2cd71fc5ec425650262d30` |
| actions/common/DamageAction.java | `c5649fc04cbcadffa617e5c52f1a6f879f88cb1a90a543d5a0a05ebf950578ec` |
| actions/common/GainBlockAction.java | `e48f437c06b42dda312446a4b536aca54570d637e53087ac16f736d84bb5df4f` |
| core/AbstractCreature.java | `3db6e08c6bd033192aa368e29ad53f4614194898ccf0f525480fe20cb8799f2b` |
