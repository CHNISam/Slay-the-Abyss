# 跨牌堆检索与选择

本模块独立实现头槌、发掘、全息影像、搜寻的原对象检索。固定规则来源为社区反编译镜像 `aeubanks/sts@319009d5df0a82d9fb0f23cc22322286c6a87ec0`，目标为初代 PC A0；不是官方二进制认证。不加入下载的 Java 源文，不把组件测试等同于原生平台或自然构筑验证。

## 四张牌及升级

| 牌 | 基础 | 升级 | 选择来源与目的地 |
| --- | --- | --- | --- |
| 头槌 Headbutt | 1费攻击，9伤害 | 12伤害 | 弃牌堆选1张，放抽牌堆顶 |
| 发掘 Exhume | 1费技能，消耗 | 0费，仍消耗 | 消耗堆选1张非发掘，放入手牌 |
| 全息影像 Hologram | 1费技能，3格挡，消耗 | 5格挡，不再消耗 | 弃牌堆选1张，放入手牌 |
| 搜寻 Seek | 0费技能，消耗，检索1张 | 检索2张，仍消耗 | 抽牌堆选牌，放入手牌 |

`abyss_retrieval_cards.withCards(data, classId)` 返回独立复制的数据。`ironclad` 只增加头槌和发掘，`defect` 只增加全息影像和搜寻；其他职业、已有同 ID 或源数据重复 ID 均拒绝。卡牌定义不修改目录中的原对象。发掘的升级只降费用：原版使用 `ExhumeAction(false)`，不会升级取回的牌。

头槌先完成伤害，全息影像先取得格挡，再执行检索。当前打出的牌仍属于 `cardInUse`，在 UseCard 清理前不能从其目标牌堆取回自身。头槌伤害已结束战斗时，后续检索直接跳过。

## 空堆、自动取得与必选数量

四张牌的选择均为必选，没有伪造的取消或少选入口。空来源直接完成；搜寻／全息影像的通用入口数量为零也直接完成。搜寻+在候选足够时严格选2张；只剩1张时自动取得该张。

头槌的弃牌堆只有1张时自动置顶。全息影像和搜寻在来源牌数不超过请求数时，按来源数组原有顺序自动取得全部；不能借展示排序重排这一分支。手动搜寻使用临时候选列表，原抽牌堆不变。

发掘按**过滤前的消耗堆数量**分支：原堆只有1张且不是发掘，自动取得；原堆多于1张时，排除所有基础／升级发掘后，即使只剩1张合法牌，也仍进入手动选择。没有合法牌时直接完成。别把它简化成“过滤后仅1张一律自动”。

原版 ExhumeAction 在打开选择前暂时把所有发掘实例移入动作的局部排除列表，结束后再追加回消耗堆尾部。本纯数据实现暂停期间仍让它们留在真实消耗堆，用 `excludedUids` 排除候选，避免引入另一套无归属牌的临时容器；确认成功时把被排除实例按原相对顺序移到尾部，最终牌序与源动作一致。这个暂停期间的牌堆投影差异是明确限制，不宣称原生界面中间态完全相同。

## 原对象、手牌上限与钩子

检索始终移动原实例，保留 UID、升级、实例费用和其他元数据，不复制、不重新分配 UID。抽牌堆数组尾部是顶部，头槌将所选实例追加到尾部。

| 情况 | 来源行为 | 本组件行为 |
| --- | --- | --- |
| 发掘开始时已有10张手牌 | 动作直接结束 | 不建立 pending、不移动牌 |
| 全息影像取得时手牌已满 | 所选牌留在弃牌堆 | 保持原对象及原位置；仍完成选择 |
| 搜寻取得时手牌已满 | 所选牌从抽牌堆进入弃牌堆 | 按每张实际移动执行手牌 `onDrawOrDiscard` 钩子 |
| 搜寻+在9张手牌时选2张 | 第一张入手，第二张溢出弃牌 | 按用户选择顺序处理，顺序有实际意义 |

这些检索不是抽牌：不受 NoDraw 阻止，不触发 Void 抽牌失能、Eviscerate 抽到重置或普通 `onCardDraw`。从抽牌堆检索入手和从弃牌堆检索入手也不调用手牌通用抽／弃钩子。搜寻溢出到弃牌会调用该钩子，但不增加手动弃牌计数，不触发 Reflex／Tactician 的手动弃牌效果。

发掘有一个独立源规则：腐化存在时，对取回的技能执行 `setCostForTurn(-9)`。组件仅复用 `Corruption.onDraw` 的费用适配器完成非负技能本回合零费，不把它解释为真正抽牌事件，也不调用手牌扫描。基础战斗费用不因此永久变化。

选择本身不消耗战斗 RNG，不洗牌，不推进 `nextUid`。搜寻真正调用的是 `BetterDrawPileToHandAction`，不是旧的 `actions/defect/SeekAction`；不能从未使用的旧动作推导随机顺序。

手动搜寻的临时展示顺序按源 CardGroup 的稳定排序组合：STATUS 类型最后，其余按稀有度降序、名字升序，完全相同则保持来源顺序。诅咒不能被误作 STATUS。实现使用当前数据名字及升级后缀；未验证原始语言包的 Java `String.compareTo` 顺序，不能据此宣称跨语言排序完全相同。自动取得分支不使用此排序。

## 纯数据选择 API 与队列契约

| 方法 | 返回与职责 |
| --- | --- |
| `begin(state, mode, count, generation)` | `mode` 为 `headbutt/exhume/hologram/seek`；完成、自动取得或跳过返回 `true`，需要选择返回 `"pause"`。generation 必须显式提供合法非负整数。 |
| `choose(state, orderedUids, token, generation)` | 精确数量且无重复的 UID 数组，按数组顺序移动原对象；成功清除 pending 并返回 `true`。非法或过期返回 `false, reason`，不半写。 |
| `view(state)` | 返回独立复制的候选、来源／目的地、数量、token、generation；没有 pending 返回 nil；过期则返回 `nil, reason`。 |
| `active(state)` | 是否存在 `pendingPileChoice`。 |

`pendingPileChoice` 只保存 mode、牌堆名、数量、UID、token、generation、turn 和四牌堆／`cardInUse` 的 UID／cardId／升级快照；没有闭包、Actor 引用或选择回调。候选数量没有10张分页上限，组件用17候选验证，UI应自行分页。

四牌堆必须为稠密数组，实例 UID 全局唯一且为正整数，定义已存在，升级标志合法，手牌不超过10张。新的选择必须与已有 discard／scry／hand／pile pending 互斥。确认再次校验 token、generation、回合、四牌堆顺序与身份事实、候选及排除列表；错误 UID、重复、数量不足／过多、失去或新获得对象、升级状态变化均原子拒绝。序列化后的同一纯数据状态可独立恢复，不要求原宿主对象地址。

根核心应在执行 `pileChoice` 效果时调用 `begin`，遇 `"pause"` 停住真实 action queue。确认入口先在整图事务内调用 `choose`，成功后再恢复队列，不能重播已发生的头槌伤害／全息影像格挡或再次支付费用。组件不自行调用 `Queue.resume`。组件内部事务覆盖本次选择与移动钩子意外异常；**后续队列、敌人反应、奖励等失败必须由根核心外层事务恢复到确认前的暂停状态**。

Combat／Run 还负责真实战斗 generation 关联、所有普通行动的 pending gate、切战斗清理和 UI 生命周期。仅传回旧 pending 的 generation 并不能替代 Run 对当前战斗身份的验证。建议外层入口为 `Combat.choosePile(state, uids, token, generation)` 及对应 Run API。

## 定向证据与当前接入状态

`node scripts/test-lua.mjs tests/lua/pile_choice.lua`：`PILE_CHOICE_COMPONENT_PASS 29`（4181ms，exit 0）。使用真实 Combat 对象、真实牌堆和真实 Queue；覆盖自动／空堆、过滤前数量、排除尾部恢复、手牌10上限差异、选择顺序、原对象元数据、无 RNG／新 UID、非抽牌钩子、腐化费用、过期／非法拒绝、17候选、序列化恢复及移动钩子抛错整图回滚。实际 Queue 暂停与后续 block 动作用来验证继续执行边界，不替代共享出牌流程。

`tests/lua/retrieval_cards.lua` 的定义验证6组已通过。另写13组真实 Combat.play 集成场景，涵盖四牌基础／升级、致死跳过、不能取回正在使用的自身、发掘尾部恢复、错误确认不重播及继续执行故障回滚。当前私树共享核心尚未注册 `pileChoice`，运行在第一组头槌得到 `unsupported_effect:pileChoice`（624ms，exit 1），因此这些真实出牌场景**尚未通过**。未替换规则执行函数来制造通过结果，待根核心接入后定向复跑并更新本段。

夹具为机制测试入口，可以指定永久牌组及当前牌堆的精确顺序；不代表自然取得概率、完整卡池、原生导入或实际平台试玩。

## 固定来源与 SHA-256

所有链接固定到 `319009d5df0a82d9fb0f23cc22322286c6a87ec0`。

| 文件 | SHA-256 |
| --- | --- |
| [Headbutt.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/cards/red/Headbutt.java) | `7b4cee9978e86478796f12c468faedb136251df15aa0bb1d5883cad58af99dc6` |
| [Exhume.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/cards/red/Exhume.java) | `6590c320a5b8a4ae4edf5bd0d622edf93fc90a8c2a9a885d18a542211e51e0ad` |
| [Hologram.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/cards/blue/Hologram.java) | `4feff49f7e785f1ba87faa346241b07b716cf9578beca7c498bb215d49c6dad7` |
| [Seek.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/cards/blue/Seek.java) | `d6334ead219d1ed3295df90b208238d06689eeb317a250a9478c09de5f590098` |
| [DiscardPileToTopOfDeckAction.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/actions/unique/DiscardPileToTopOfDeckAction.java) | `0669f20c080ddbea086374407a7bd3d8f78b265824433d01099357ce5569f6d3` |
| [ExhumeAction.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/actions/unique/ExhumeAction.java) | `cdbe92c37397e792cc4e15a959fde444fb5d0b3e9e2822fddc93b2c3928b39af` |
| [BetterDiscardPileToHandAction.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/actions/common/BetterDiscardPileToHandAction.java) | `afc312c09430196e1cccf584ad27c918cb0321282b5e29f1d1d9279c9d49adb1` |
| [BetterDrawPileToHandAction.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/actions/common/BetterDrawPileToHandAction.java) | `1c785bd1d9a161fcc6a9b16c7a13a27c96e862b8e5b642aa43ebaba80cae0852` |
| [CardGroup.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/cards/CardGroup.java) | `03de4e22ab22bedf1d90df72bdc83f033ff6aa776ad9d8f7259e1ee9293f7fa8` |
| [GridCardSelectScreen.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/screens/select/GridCardSelectScreen.java) | `1793bb4449bc7046d3e5477d1fdd4ad39f0a4d3d9582309ceb59595be8b130bc` |
