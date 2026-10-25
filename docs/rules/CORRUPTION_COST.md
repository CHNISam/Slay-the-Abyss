# 腐化：战斗内费用与本回合费用

费用模块独立管理实例字段，核心负责把展示、可用性、支付、抽牌、生成、弃牌／消耗与回合末入口接起来。组件测试和后述共享核心集成测试分开记录，不把单独调用费用模块冒充真实出牌。

基线为社区反编译镜像 `aeubanks/sts@319009d5df0a82d9fb0f23cc22322286c6a87ec0`，目标为初代 PC A0。它不是官方二进制认证。实现与说明独立编写，不加入下载的 Java 源文。

## 两种实例费用

- `combatCost` 保存战斗内被修改的基础费用；不存在时读当前升级后的卡牌定义费用。
- `turnCost` 保存本回合费用；不存在时读 `combatCost` 或定义费用。

这些字段只存在于战斗卡牌实例，不修改目录、永久牌组或奖励。它们与保留标志、`storedDiscardCost`、`damageBonus`、`shivAccuracyBonus` 独立。`adaptDefinition` 对已经复制并合并升级的定义依次应用战斗费用、本回合费用，不调用 `Combat.cardDefinition`，避免递归。

源规则不是把所有数字直接赋零。一次 `modifyCostForCombat(-9)`：当前回合费用为正时，从该数减九、最低零，并把结果同时写入战斗费用；否则若战斗费用非负，从战斗费用减九、最低零，同时把回合费用置零。通常原版牌均归零，但组件用合成高费边界验证 `20→11`。负费用哨兵 `-1` 与 `-2` 不被改成零。

## 四个真实时点

1. **构造 ApplyPowerAction 时**扫描 hand、draw、discard、exhaust 中的全部技能，执行上述战斗降费。不是 `CorruptionPower` 自身构造器扫描。腐化牌发现已有同名能力时不会再构造这项动作，因此重复腐化不再次扫描。
2. **抽牌时**先移动到手牌，再触发 `Power.onCardDraw` 把该技能的非负回合费用置零，然后才调用玩家 `onCardDrawOrDiscard`。后者只扫描当前回合费用不等于零的手中技能，因此新抽到的牌通常只取得临时零费。
3. **生成到手牌时**，`ShowCardAndAddToHandEffect` 先入手，再调用玩家 `onCardDrawOrDiscard`，最后才对生成技能 `setCostForTurn(-9)`。所以新生成的正费技能通常先永久降费，再取得临时零费，不能与抽牌共用“仅临时置零”的简化。
4. **正常支付时**，`AbstractPlayer.useCard` 对腐化下的技能跳过普通正费支付；卡牌实际费用仍能是大于零的合成边界值。`AbstractCard.hasEnoughEnergy` 没有腐化特判，所以合法性仍按实际回合费用检查能量，不能用支付谓词放宽 canPlay。X 动作自身负责消耗能量，不能由本组件替代。技能使用后是否消耗由 UseCard 构造时捕获，交给独立 exhaust dispatcher。

玩家 `onCardDrawOrDiscard` 还发生在原生弃牌、消耗等路径；不能只在抽牌调用本组件，否则会漏掉手中后来获得的费用修改。

## 回合重置在回合末，只有三堆

`rooms/AbstractRoom.endTurn()` 在安排回合末弃牌动作后、那些队列动作执行前，立即对 **draw、discard、hand** 调用 `resetAttributes()`，把回合费用恢复到战斗费用。此时 retain／selfRetain 尚未移入临时保留区，所以保留牌也重置。**exhaust 不在这项遍历中**。

`RestoreRetainedCardsAction` 只把保留牌放回手牌，不另做费用重置。回合开始也没有对应的统一重置。若回合末黑暗之拥在第一次 reset 之后抽到一张技能，它新得到的临时零费会保持到下一回合；即使腐化随后被移除，也不能在下一回合开始把该临时费用清掉。

因此组件提供 `resetEndTurn(state)`；`beginTurn(state)` 明确为空操作，不能用“开始时清四堆”冒充原顺序。这里只管理该组件的费用字段，不代替所有 `resetAttributes` 数值、保留动作、遗物或回合末卡牌钩子。

## 接入 API

| 方法 | 行为 |
| --- | --- |
| `prepare(state)` | 模拟 ApplyPowerAction 构造。未激活时扫描四堆，写纯数据 `state.corruptionPrepared=true`。每次实际调用仍各扫描一次；已有腐化则返回 false。 |
| `apply(state, 1)` | 未 prepare 时自行扫描；已 prepare 时消费标记而不重复扫描，再施加 presence=1、中文 buff 定义及状态事件。已激活则返回 false，不再扫描。 |
| `onDraw(state, instance, bareDefinition?)` | 对新抽入技能只置非负 `turnCost=0`，不替代后续玩家 hand-wide hook。 |
| `onDrawOrDiscard(state)` | 有腐化时扫描手中当前回合费用不为零的技能，永久降低其战斗费用。 |
| `created(state, instance, bareDefinition?)` | 要求实例已在手牌；先执行 hand-wide 扫描，再对生成技能置临时零费。攻击牌生成也会触发手牌扫描。溢出进入弃牌堆的生成物不要调用这个入手接口。 |
| `resetEndTurn(state)` | 预检后只清 hand／draw／discard 的 `turnCost`；保留 `combatCost` 和 exhaust 的 `turnCost`。 |
| `beginTurn(state)` | 预检后空操作，明确没有统一 start-turn reset。 |
| `remove(state)` | 移除 presence 并记录事件，不恢复已经改过的战斗费用，也不立即重置临时费用。 |
| `adaptDefinition(state, instance, copiedDefinition)` | 只读实例字段，覆盖传入复制定义的费用。拒绝把目录中的原始定义作为可写对象。可供没有 player 的牌组显示上下文调用。 |
| `freePayment(state, resolvedDefinition)` | 是否省去腐化技能的普通非负费用支付；不扣能量、不代替 X 动作，也不改变定义上的可见费用。 |
| `definition()` | 新的中文腐化状态定义，`kind=buff`、`stack=none`、`decay=none`。 |

可选 `bareDefinition` 必须是已处理合法升级及其他支持的费用变异、**尚未套用本组件实例覆盖**的定义。省略时直接从目录拷贝并合并升级字段。组件不把任何函数放入 state。

卡牌必须具有唯一 UID、有效升级标志、整数费用与稠密牌堆；不兼容状态定义、重复实例、稀疏牌堆、非整数／NaN 费用和把负哨兵改为正数的未支持组合，均在写入前拒绝。普通可预测预检失败不半写；外部事件 emitter 或队列意外抛错仍由共享完整对象图事务恢复，包括 `corruptionPrepared`。

`prepare` 必须在正确的动作构造时点放入外层事务。不能先改费用、再建立事务；否则后续失败可能保留构造阶段的降费。Power／purge 的清理优先级、腐化技能消耗捕获和 exhaust 钩子不由费用组件承担。

## 验证范围

`node scripts/test-lua.mjs tests/lua/corruption_cost.lua`：`CORRUPTION_COST_PASS 21`。

组件使用真实 Combat 状态和 Snapshot 回滚，但没有伪装成已接入的共享出牌流程。覆盖四堆及升级、0／X／不可打出、高费减九、构造与应用分离、重复能力与重复实际构造、正／零临时费用分支、抽入和生成的差异、生成其他牌触发手牌扫描、回合末三堆重置、保留牌、exhaust 不重置、回合末新抽牌跨到下一回合、显式移除、普通支付谓词、独立字段、原子拒绝和原引用事务恢复。

尚未验证费用修改遗物、升级过程中已有零费的差值规则、通用卡牌复制、移回手牌的全部路径、所有可能的 X 技能或平台显示。真实出牌与选择恢复的完整证据由共享集成任务另外记录，不能把这 21 组组件测试计作完成原版全卡池。

### 移动路径的集成回归

新增 `tests/lua/corruption_cost_integration.lua`，通过真实 `Combat.play`、`HandChoice`、`Discard` 与 `Combat.endTurn` 执行，不替换规则处理函数。它给临时数据增加一张费用20、普通 `block1` 效果的技能探针，使“多一次／少一次降九”变成可见差异；普通原版技能早已为零时，这类移动钩子错误常被幂等性掩盖。

命令 `node scripts/test-lua.mjs tests/lua/corruption_cost_integration.lua` 已得到 `CORRUPTION_COST_INTEGRATION_PASS 9`；旧的组件21组原样保留并复跑通过。

来源要求每种移动各自承担钩子，不能在统一 UseCard 尾部再调用一次：

| 路径 | 本次移动的手牌降费钩子 |
| --- | --- |
| Power 的 `empower` 清理 | 不调用；原版提前 return，也不追加 HandCheck |
| 普通卡进入弃牌堆 | 一次；即时普通攻击路径同样要调用 |
| 普通卡进入消耗堆 | 一次；使用牌自身消耗后不能再扫第二次 |
| 手中牌放到抽牌堆顶 | 不调用；`moveToDeck` 与选牌界面均不触发该钩子 |
| 手动弃置多张 | 每张移出手牌后各调用一次，不能批次结束只调用一次 |
| 回合末普通全弃 | 按手牌顶部逐张移出后调用；已离开手牌的牌不能继续被后续手牌扫描修改 |

原版 `HandCheckAction` 只更新牌面力量与发光，不调用 `onCardDrawOrDiscard`。回合末 `DiscardAction` 的自动全弃从 `getTopCard` 取牌，既有数组约定中顶部是尾部。测试把同一个探针分别放在底部和顶部：探针最后弃时先经历两张打击的钩子，费用 `11→2→0`；探针先弃时已离手，应保留战斗费用11。

另以初始能量规则13／14的独立场景验证大正费门槛：打出3费腐化后分别剩10／11，探针回合费用11。剩10时 `canPlay` 和 `play` 均原子拒绝；剩11时允许真实打出，但腐化令实际支付为零，技能真实获得1格挡并消耗。命令执行期间不改写能量。

这些是机制边界夹具。费用20的探针、控制牌堆顺序、初始13／14能量均不代表原版可获取卡牌、原始职业属性、自然构筑或来源概率。固定原版普通牌及费用组件21组测试保留。

## 固定来源和 SHA-256

全部链接固定到 `319009d5df0a82d9fb0f23cc22322286c6a87ec0`。

| 文件 | SHA-256 |
| --- | --- |
| [ApplyPowerAction.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/actions/common/ApplyPowerAction.java) | `f64ce8511f961a1990f1909e2c55654fa6dbf1dc2f4f1f3d3a7156c2ec2a9d47` |
| [CorruptionPower.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/powers/CorruptionPower.java) | `d1aa54c286ac8b9a02a467abe5bd7aac3dfa7c831c77b4872607316f220f067b` |
| [Corruption.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/cards/red/Corruption.java) | `081129a985afff15a7f0ab84ecab77e97902fbb2bcfdba6870104e6929d5c1d9` |
| [AbstractCard.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/cards/AbstractCard.java) | `bcd472ececfd8ce4150ccd4eb6dd07a2e2dc43e139196fe00de34705cf1a2a61` |
| [AbstractPlayer.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/characters/AbstractPlayer.java) | `2720ba8dd7a216781a3b2fcb709f5ec67dc9b2559af25f7f6b89df1ef0947d95` |
| [ShowCardAndAddToHandEffect.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/vfx/cardManip/ShowCardAndAddToHandEffect.java) | `e0ac9f16f627a985920857080a2a9e2ef903e7f0db0741b57709de99b52202ef` |
| [AbstractRoom.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/rooms/AbstractRoom.java) | `020f4a0fc3a564f6e45604e5dba582a773a5b9fdb471f8488a2bf8c2354d3a05` |
| [DiscardAtEndOfTurnAction.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/actions/common/DiscardAtEndOfTurnAction.java) | `d80e3ae091de4bc4e74879f195b5ec2d1bb7e7c7e92eac636bf452d61e4bebf0` |
| [RestoreRetainedCardsAction.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/actions/unique/RestoreRetainedCardsAction.java) | `8bed1c15e51dac6ce10baf7cfd50a51220552274f620adeb8eeef5e7667e3adc` |
| [CardGroup.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/cards/CardGroup.java) | `03de4e22ab22bedf1d90df72bdc83f033ff6aa776ad9d8f7259e1ee9293f7fa8` |
| [DrawCardAction.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/actions/common/DrawCardAction.java) | `67d02ba84c1d7e60fbb2a4a83f2b2d3ebbd81a84d29c16ccb98ecc9dd1a17e18` |
| [UseCardAction.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/actions/utility/UseCardAction.java) | `90213939af6d7ec83dea01bb2feef4ba762a93400dc1535732e2eebcdb6cab0f` |
| [HandCheckAction.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/actions/utility/HandCheckAction.java) | `c65177be59879e01897b9689d724151f7889c0864e4dee04ecccdf7110c3fa39` |
| [DiscardAction.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/actions/common/DiscardAction.java) | `8c711be291822386b64fe0a6c9bc55b920b7a09122fb55f09184b6ca96063c10` |
| [PutOnDeckAction.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/actions/common/PutOnDeckAction.java) | `16f2ab8615f93267325ea98a9d1ea6e38b79e79c4aa72c4284efbb1ec4c567af` |
| [HandCardSelectScreen.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/screens/select/HandCardSelectScreen.java) | `7fce4c5b474fd46d6d0a3375f78b971e59daa972dd1ac096a0fa395837124059` |
