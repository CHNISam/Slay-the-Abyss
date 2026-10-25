# 出牌触发：余像、凌迟、涂毒、狂怒、散热片、雷暴

固定来源为社区解析镜像 `aeubanks/sts@319009d5df0a82d9fb0f23cc22322286c6a87ec0`，目标是初代 PC A0。以下实现独立编写；来源没有经过官方二进制认证，未把 Java 源文加入项目。

## 六张牌

| 牌 | 职业、稀有度、费用 | 基础 → 升级 |
| --- | --- | --- |
| After Image 余像 | 猎人、稀有、1 | 每牌1固定格挡；升级获得固有，数值不变 |
| A Thousand Cuts 凌迟 | 猎人、稀有、2 | 每牌对所有敌人1 → 2点纯 THORNS 伤害 |
| Envenom 涂毒 | 猎人、稀有、2 → 1 | 未被格挡的正数普通攻击伤害触发1层中毒，升级只降费 |
| Rage 狂怒 | 战士、罕见、0、技能 | 本回合每张攻击牌3 → 5固定格挡 |
| Heatsinks 散热片 | 机器人、罕见、1 | 每张能力牌抽1 → 2张 |
| Storm 雷暴 | 机器人、罕见、1 | 每张能力牌生成1个闪电球；升级获得固有 |

全部能力继承 `AbstractPower.priority=5`，没有覆盖优先级。ApplyPower 首次加入后使用稳定排序；同优先级保留获得顺序，叠加同名能力不改变位置。移除后再获得应占据新的位置。

`withCards(data, characterId)` 分组附加：`silent` 三张、`ironclad` 一张、`defect` 两张，卡与状态均复制；不会把全部职业池混在一起。六个内部 ID 为 `after_image`、`thousand_cuts`、`envenom`、`rage`、`heat_sinks`、`storm`。余像+与雷暴+的 `upgrade.innate=true` 必须由共享初始抽牌实现承担，不能只在说明里写“固有”。

## 不是一个统一的出牌后动作

原版 `AbstractPlayer.useCard` 先调用卡牌 `use`，让原生动作入队，然后构造 UseCardAction。构造函数依次调用：

1. 玩家能力的 `onUseCard`。
2. 玩家遗物的 `onUseCard`。
3. 手牌、弃牌堆、抽牌堆中卡牌的 `triggerOnCardPlayed`。
4. 怪物能力的 `onUseCard`。

构造结束后才把 UseCardAction 本身放到队尾。之后 `CardGroup.triggerOnOtherCardPlayed` 遍历其他手牌回调，再调用玩家能力 `onAfterCardPlayed`。所以六牌的队列位置不同：

| 能力 | 钩子及入队方式 | 必须执行的位置 |
| --- | --- | --- |
| 散热片 | `onUseCard`，TOP Draw | 当前能力牌的原生效果之前 |
| 余像 | `onUseCard`，BOT GainBlock | 原生效果之后、怪物 Sharp Hide 与 UseCard 清理之前 |
| 狂怒 | `onUseCard`，攻击牌才 BOT GainBlock | 同上，只对攻击牌 |
| 雷暴 | `onUseCard`，能力牌才逐个 BOT Channel | 原生效果之后、UseCard 清理之前 |
| 凌迟 | `onAfterCardPlayed`，BOT DamageAll | UseCard 清理之后 |
| 涂毒 | 普通攻击的 `onAttack`，TOP ApplyPower | 当前伤害批次结束后，按完整 TOP 反应顺序执行，早于后续原生动作 |

原版 SharpHidePower 也是 `onUseCard`，但属于怪物能力阶段，因此它的 BOT THORNS 伤害排在玩家余像／狂怒的 BOT 固定格挡之后。格挡能抵消**这一次**攻击引起的 Sharp Hide，而不是下一张牌才生效。遗物回调位于玩家能力与怪物能力之间；组件没有擅自挪动其位置，也没有声称已实现所有遗物钩子。

`dontTriggerOnUseCard=true` 会同时跳过 UseCard 构造中的这些钩子和后续玩家 `onAfterCardPlayed`。自动使用诅咒等特殊路径不能不加区分地当作玩家普通出牌。

能力数量要在构造这些动作时快照。新打出的余像、散热片、雷暴或凌迟不能追溯触发自己；已有一层、再打第二份时，只按旧的一层触发本次，随后才获得新的层数。

## 格挡、伤害与中毒

余像和狂怒直接创建 GainBlockAction，实际 `addBlock` 不经过卡牌的敏捷／脆弱公式，所以使用 `fixed=true`。这不代表“完全忽略所有获得格挡钩子”；例如未接入的 Juggernaut、遗物和怪物回调仍需各自实现。

凌迟使用 `DamageInfo.createDamageMatrix(amount, true)` 和 `DamageType.THORNS`，不受力量、虚弱、易伤、愤怒／神格倍率影响，但仍消耗敌人格挡。它不会触发普通攻击限定的涂毒、荆棘反伤、Curl Up 或 Angry。矩阵用构造时的数量和敌人 ID 快照，动作仍由真实 Combat 伤害接口执行。

原版终局清理保留 GainBlock、UseCard 和 DAMAGE 类动作。因此最后一只怪物被原生攻击击杀后，已经排队的余像格挡和凌迟伤害动作不能被统一丢弃；凌迟目标已死时不再造成伤害。玩家死亡则中止动作处理，格挡不能复活玩家。

涂毒不是 BOT。`EnvenomPower.onAttack` 明确向 **TOP** 排中毒。伤害参数是经过格挡、攻击方／受击方 `*ToChangeDamage` 钩子之后、目标 `onAttacked` 与最终扣血之前的正整数，不能无条件把它泛化为所有未来目标的实际失血量。当前 Core 捕获的是普通伤害快照或攻击修正值减去当前格挡；Actor 尚未实现 Buffer 或通用 `onAttackToChangeDamage`／`onAttackedToChangeDamage` 等改伤钩子。只有当前已支持集合中没有额外改伤钩子时，这个值才与原参数对应；上述未实现组合不能凭本批测试宣称兼容。

涂毒只接受玩家作为来源、非自己目标、NORMAL 类型、正数未格挡伤害。THORNS、HP_LOSS 和完全格挡不触发。计划只保存 `targetId` 和旧数量，执行时重新检查目标、玩家与战斗状态，再经过 Actor 的人工制品流程。目标已死、玩家已死或末敌已死的折叠无效动作不消耗人工制品。

当前共享核心把中毒与目标反伤放在**同一个折叠 TOP 反应批次**中，而不是先处理完全部反伤、再往主动作队列追加中毒。`Combat.damage` 捕获 `onAttack` 的纯数据中毒记录，交给 `Actor.damage`，在记录目标的 `onAttacked` 反伤之前加入本地批次。普通单次伤害立即逆序处理这份批次；群伤各目标共用批次，先完成所有目标伤害，再整体逆序处理。

例如，群伤命中两个目标，只有第一个带荆棘：入队调用记录为 `[poison1, thorns1, poison2]`，TOP 实际执行为 `[poison2, thorns1, poison1]`。即使 `thorns1` 随后击杀玩家，第二个目标也已合法得到中毒；第一份中毒则因玩家死亡停止。若等整个群伤的反伤先结束，再执行全部中毒，会错误丢掉前者。本地批次保留这个交错顺序，不改变模块返回动作的纯数据契约。

PoisonPower 构造时对新中毒能力最多9999，已有中毒的叠加使用动作原始数量，不把每次叠加都钳到9999。本模块对整数溢出明确拒绝，不模拟未经验证的 Java 整数回绕。Snake Skull、来源／受击方其他施加能力回调不属于本切片的已验证范围。

## 纯数据接口与历史

`state.cardTriggerPowerOrder` 是六个能力子集的获得记录：`{id, priority=5, order=serial}`。`state.cardTriggerPowerSerial` 单调递增。该表不是整个游戏的全量玩家 Power 列表；共享核心仍要在正确位置接入其它能力与遗物。历史只保存普通数据，不存函数。

- `apply(state, id, amount)`：预检后使用真实 Actor ApplyPower 并登记获得顺序；状态定义由相应职业 `withCards` 注册。
- `recordApplied(state, id)`：供外层已经成功施加能力时登记。同名叠加不移位。不能对未施加的能力登记。
- `prepareUse(state, copiedCard)`：在原生效果执行之前返回 `{top={}, beforeUse={}, afterUse={}}`，数量均为旧状态快照。所有数组表示**源码入队调用顺序**；TOP 数组由调用方依次 `pushTop`，不是直接当成最终执行顺序。
- `expandStorm(state, effect)`：把紧凑 `cardTriggerStorm.remaining` 变成“先 TOP 下一段 descriptor，再 TOP 一个 ChannelAction”的两项计划；因此实际先生成当前球，再处理下一段。大层数不创建巨型数组。
- `onAttack(state, source, target, damageAmount, damageType)`：NORMAL 的合法正数伤害返回一个 `cardTriggerPoison` TOP 动作，否则返回 nil。共享 Core 把该记录放入当前伤害的本地 TOP 反应批次，不能把所有群伤毒记录延后到反伤批次之后。
- `resolveEnvenom(state, effect)`：重新检查存活、目标和人工制品后施加快照中毒。
- `resolveDamageAll(state, effect, Combat)`：用真实固定伤害执行快照矩阵，批次末处理目标死亡反应。
- `prepareEndTurn(state)`：返回狂怒的 `removeCardTriggerPower` 动作，不在构造时立即移除。
- `removePower(state, id)`：在实际 RemoveSpecificPowerAction 边界移除数值和获得记录；重获时获得新序号。外层移除这六个能力也必须走这条历史清理路径，不能只把 statuses 清零再沿用旧位置。
- `definition(id)`：中文 buff 元数据、强度叠加和实际 priority=5。

共享核心需要识别 `gainCardTriggerPower`、`cardTriggerStorm`、`cardTriggerPoison`、`cardTriggerDamageAll`、`removeCardTriggerPower`。支持数字预检、稠密列表、唯一目标、正确优先级与历史；未知有效能力缺历史时显式拒绝，不能凭状态表键排序猜获得先后。队列和共享操作意外抛错仍由完整对象图事务负责恢复。

## 验证分层

命令：`node scripts/test-lua.mjs tests/lua/card_triggers.lua`。

组件部分单独输出 `CARD_TRIGGERS_COMPONENT_PASS 28`。它使用真实 Actor、Combat 伤害／抽牌和 Queue 执行器，但部分队列宿主只验证本模块的接入契约，不能记成真实出牌通过。组件中手动调用 `onAttack` 的案例使用真实 Actor 伤害，避免已经接入自动涂毒的外层 Combat 再执行一次相同触发。

真实共享核心部分输出 `CARD_TRIGGERS_PLAY_PASS 21`：

- 六张牌基础和升级均通过真实 `Combat.play`，验证费用、数值、自身不追溯触发、能力离开牌堆和狂怒回合末移除。
- 散热片在当前能力效果前真实抽牌；叠加散热片、雷暴、余像均只触发旧数量。
- 余像／狂怒在同次 Sharp Hide 伤害前格挡。
- 凌迟在普通卡进入弃牌堆之后造成纯群伤，最后击杀后的动作保留；凌迟 THORNS 不额外触发涂毒。
- 涂毒与真实 Bane 顺序为首击→中毒→条件二击→中毒；人工制品挡住首层中毒时不发生条件二击。
- 两个故障注入均先执行原始规则函数再抛出非字符串错误，不返回虚构规则结果。一个在真实散热片洗牌、余像获得历史已写入后失败；另一个在真实雷暴唤起造成伤害、独立 RNG 已前进后失败。原获得历史表、卡牌 UID／牌堆、事件、能量、球原对象和 RNG 图均恢复，可真实重试。终局动作测试用包装器观察真实 resolver 被调用，不替代伤害结果。

测试精确布置真实生成的卡牌实例和必要边界状态，这是机制验证，不是自然获取、奖励概率、整局通关或平台验收。当前通用生成接口只有已接入者；不能因本批通过而声称全部生成牌、遗物、混合构筑、平台事件和实机视觉均完成。

主执行者另在 `tests/lua/phase_three_review.lua` 记录本轮独立审查的三个真实核心用例。其中群伤／荆棘用例直接验证第二目标中毒先于第一目标致死反伤，第一目标中毒留在死亡边界之后而被跳过。这是共享 Core 反应批次接点的补充证据，不修改或重算本模块的组件28组与真实出牌21组。

## 固定来源与 SHA-256

| 文件 | SHA-256 |
| --- | --- |
| [AfterImage.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/cards/green/AfterImage.java) | `050570eea6d24855f8791580dd5bc821c4e7bdbfda8c514bc85d4c7826b25040` |
| [AThousandCuts.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/cards/green/AThousandCuts.java) | `ec162da24a33885fd3b9cf7cefa6c192c5bb11db7d7b1c1b78cd870881c9e087` |
| [Envenom.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/cards/green/Envenom.java) | `cb860b5daee3c13a327daed611393491d92f5c366aeabc6df37be0335482ff8e` |
| [Rage.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/cards/red/Rage.java) | `02d88c0697db90b001d5596e743a3f6a5d293ae79e767b25b22ffb8cbbdaf171` |
| [Heatsinks.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/cards/blue/Heatsinks.java) | `5e968839daea7f356e6aa17fe38c8c91751b1ea5cbbda9af40266c1b6bcd0415` |
| [Storm.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/cards/blue/Storm.java) | `a2ffdbb8a43aa17f8aadcc92e57e732efcd9504cc00c3ebac0df906d71a1a279` |
| [AfterImagePower.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/powers/AfterImagePower.java) | `b4272c5ea776c3866df5678c2fb58960bf27adf6fdb21706f2ad4e9d9829fea9` |
| [ThousandCutsPower.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/powers/ThousandCutsPower.java) | `107dbdfca291749696cfdf8e4e852074aeeff50016b2e93727f48c32a0dc4098` |
| [EnvenomPower.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/powers/EnvenomPower.java) | `f5624c590e288208e5517a0c02e586593bd9e7a9962134c53059e35fb42a534e` |
| [RagePower.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/powers/RagePower.java) | `4c69b58639aeba38c8464e417890354cd5c1fdfe0ec3bb44d30ec2aab9048765` |
| [HeatsinkPower.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/powers/HeatsinkPower.java) | `94344d386dfb38bfb71477bbf4eb71b13c4f2bdcb10988720a461e851c440abd` |
| [StormPower.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/powers/StormPower.java) | `295d6951e4fa1fd948770f6c426e87daefe75064c30a3e71e108d3a0ac37df0c` |
| [AbstractPower.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/powers/AbstractPower.java) | `37a6e97bc1a7a3d0cbfe93fd07e9f809690f7c02f24fd45ec34892466b6e0f9f` |
| [ApplyPowerAction.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/actions/common/ApplyPowerAction.java) | `f64ce8511f961a1990f1909e2c55654fa6dbf1dc2f4f1f3d3a7156c2ec2a9d47` |
| [AbstractPlayer.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/characters/AbstractPlayer.java) | `2720ba8dd7a216781a3b2fcb709f5ec67dc9b2559af25f7f6b89df1ef0947d95` |
| [UseCardAction.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/actions/utility/UseCardAction.java) | `90213939af6d7ec83dea01bb2feef4ba762a93400dc1535732e2eebcdb6cab0f` |
| [CardGroup.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/cards/CardGroup.java) | `03de4e22ab22bedf1d90df72bdc83f033ff6aa776ad9d8f7259e1ee9293f7fa8` |
| [SharpHidePower.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/powers/SharpHidePower.java) | `a7cf449a907ca34569059aca1310619deb597d32cdd84201815d024614ff576a` |
| [GainBlockAction.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/actions/common/GainBlockAction.java) | `e48f437c06b42dda312446a4b536aca54570d637e53087ac16f736d84bb5df4f` |
| [AbstractCreature.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/core/AbstractCreature.java) | `3db6e08c6bd033192aa368e29ad53f4614194898ccf0f525480fe20cb8799f2b` |
| [DamageInfo.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/cards/DamageInfo.java) | `cc16469d78473a1d37bf18a152014d9d1625859a5a7bd0923387f4ee8d942a5a` |
| [DamageAllEnemiesAction.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/actions/common/DamageAllEnemiesAction.java) | `3562ea16a19d0951b36198a4191fd48358c7cb408595ef2c503fc4b7763ec123` |
| [AbstractMonster.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/monsters/AbstractMonster.java) | `f95baba14b00bffeb6a93e9fcf04cedad2a42a803c4b4342c1e017535acc601f` |
| [GameActionManager.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/actions/GameActionManager.java) | `a47d1ee9c6b2e194b7d3ef311328f2a15e38f5630330689e438e46685b94d6c3` |
