# 战士消耗流：源码顺序与独立接入契约

本轮只新增独立 dispatcher、组件测试与本文；未修改 Combat/Actor/Effects/HandChoice。这些测试证明组件可接入现有纯数据队列，**不代表腐化、无惧疼痛、黑暗之拥、燃烧契约已经可在运行牌库使用**。原版 PC A0 是目标；来源是固定社区反编译仓库，不冒称已验证某个官方发行二进制。规则用自然语言与原创伪代码描述，不复制原 Java 实现。

## 数值与生命周期

| 牌 | 费用：基础→升级 | 基础→升级效果 | 处理 |
| --- | --- | --- | --- |
| Corruption 腐化 | 3→2 | 技能零费、使用后消耗 | Power；已有同名能力时不重复施加；自身不是消耗事件 |
| Feel No Pain 无惧疼痛 | 1→1 | 每消耗一张牌固定获得3→4格挡 | Power；可叠加，忽略敏捷/脆弱 |
| Dark Embrace 黑暗之拥 | 2→1 | 每消耗一张牌抽1张 | Power；多份能力叠加抽牌数 |
| Burning Pact 燃烧契约 | 1→1 | 先选择消耗手牌1张，再抽2→3张 | Skill；自身无固有消耗，腐化下自身也消耗 |
| Sentinel 哨卫 | 1→1 | 获得5→8格挡；被消耗获得2→3能量 | Skill；未打出被消耗同样给能量 |

腐化能力原始 amount=-1 是无计数且不可叠加的表示。当前项目可用 presence=1 + stack=none；不要把-1塞进只接受非负状态的 Actor。它不能把诅咒/状态或 Power 变为技能；不能把不可打出的 Reflex/Tactician 从-2改为0。

### 腐化费用必须分为三个时间点

1. `ApplyPowerAction` **构造**腐化动作时，扫描当前 hand/draw/discard/exhaust 中的 Skill，执行 `modifyCostForCombat(-9)`。这是修改战斗内基础费用，不是每次展示时覆盖。已有腐化时 Corruption.use 不构造重复动作，因此不会重复这轮扫描。
2. 腐化生效后 `onCardDraw` 先对抽到的 Skill 执行 `setCostForTurn(-9)`，之后 `onCardDrawOrDiscard` 扫描手牌，只对当前turnCost不为0的Skill执行 `modifyCostForCombat(-9)`。正常新抽牌已被前者置0，所以通常只有临时改费。新生成到手牌的Skill在 `ShowCardAndAddToHandEffect` 中反过来先触发手牌扫描、再 `setCostForTurn(-9)`，因此通常先得到永久战斗费用降低；不能只调用一次临时归零而漏掉生成牌的手牌扫描。
3. `AbstractPlayer.useCard` 对腐化下的 Skill 省去普通正数费用的支付；`UseCardAction` **构造时**捕获 `exhaustCard=true`。不能到清理时才查看当前腐化，防止卡牌效果期间能力变化影响已捕获的清理决定。

实例需要独立保存 combatCost/costForTurn，不能污染 catalog 或奖励牌。源码并非任意费用直接赋0：

```text
modifyCostForCombat(-9):
  turnCost>0: turnCost=max(0,turnCost-9); combatCost=turnCost
  otherwise combatCost>=0: combatCost=max(0,combatCost-9); turnCost=0
  otherwise: preserve both negative sentinel costs
setCostForTurn(-9): only when turnCost>=0, set max(0,-9)
```

所以极高改费值不应被无条件清零。-1的 X 费 Skill 保留-1且其 X action 自行消费能量；-2仍不可打。回合末先对hand/draw/discard清除临时turnCost（exhaust不清），恢复时读combatCost。随后回合末DE抽到的新Skill获得turnCost=0，可以带入下一回合，因为源码没有玩家回合开始时再次统一清费。移除腐化不恢复旧combatCost；费用复制、费用修正遗物、X技能等组合开放前仍需分别补真实trace。

## 一次 moveToExhaustPile 的精确顺序

1. 按遗物持有顺序调用 `onExhaust(card)`。
2. 按能力列表顺序调用 `onExhaust(card)`。
3. 调用该卡自己的 `triggerOnExhaust`。
4. 从旧位置移出，放入 exhaustPile，再调用 `onCardDrawOrDiscard`。

hook多为**排入动作**，不是在上面每一步立即兑现。无惧疼痛向 BOTTOM 追加固定 GainBlock；黑暗之拥在还有存活怪物时向 BOTTOM 追加 Draw。两者默认 priority=5；能力列表使用稳定排序，同优先级保留先获得的顺序。因此先获得黑暗之拥时，抽牌在格挡前；不能固定“格挡然后抽牌”。叠加同名能力不改变先后位置；移除再获得时必须移除旧顺序记录再追加。

哨卫自己的 hook 向 TOP 插入能量动作，所以在当前动作返回后，先于已有队列尾以及 FNP/DE 尾执行。hook动作实际执行时，哨卫已进入消耗堆。如果同时有冥界之灰，灰先在遗物阶段 TOP 插伤害，但随后哨卫再次 TOP 插能量，因此能量仍在伤害前。枯木在遗物 hook 阶段选择随机牌并排入 BOTTOM 生成动作，时间点早于 FNP/DE；不应随便延迟随机选择到生成动作执行时。

两种消耗入口要统一，不能只修 True Grit：

- `ExhaustAction` / `ExhaustSpecificCardAction`：手牌选择完就移动并排入触发；True Grit 基础>=2张才掷独立 cardRandomRng，剩<=1张自动处理不掷。升级版>=2张暂停选1，空手不暂停。使用中的牌已不在手牌候选中。
- `UseCardAction`：先执行卡牌原生效果，随后才清理自己。Power 与 purge 优先离开战斗牌堆；不触发消耗。普通牌清理时，由已捕获的 exhaustCard 决定移动。勺子只在这条自消耗分支掷 cardRandomRng.randomBoolean，触发就丢弃且不触发消耗；指定消耗不掷勺子。其他重回手牌/洗回牌库等清理标志要在调用 dispatcher 前解决。

例：腐化下 True Grit，先格挡，再消耗所选手牌并追加第一批 hook；接着 UseCard 消耗 True Grit 并追加第二批 hook；然后第一批与第二批依次执行。第一批 DE 抽牌发生时，两张牌均已在消耗堆。

例：燃烧契约初始队列 `[ExhaustChoice, Draw2/3, UseCard]`。选中的牌触发追加于 UseCard 后面：`[Draw2/3, UseCard, FNP/DE...]`。原生抽牌不能抽到正在使用的燃烧契约；无腐化时 UseCard 把它丢弃后，后续 DE 抽牌可以洗回并抽到它。不能用永久排除当前 UID 的方案处理这一点。腐化下契约则在 UseCard 消耗自己，后续任何抽牌均不可从消耗堆回抽它。

## 终局、回合末与明确边界

- DE 在 hook 创建时检查怪物是否基本死亡，已全死不排抽牌。FNP 无这项检查，仍排格挡。
- 源码 `clearPostCombatActions` 在调用当时过滤队列，保留 Heal/GainBlock/UseCard/伤害动作。它不是永恒的“胜利后每个非保留动作都丢掉”规则；保留 UseCard 随后产生的新动作是否执行还受房间 COMBAT 生命周期影响。现有 Core 的逐动作终局策略不能由此证明与所有未来遗物组合等价。
- GainBlockAction 有 target.isDying/isDead 防护。独立 dispatcher 为适配当前 Core 明确拒绝 hp<=0的新移动；未证明原版所有死亡/复活窗口的动作队列完全等价。Charon's Ashes/Juggernaut等会在触发中杀怪或杀玩家的链开放前，需要额外终局 trace。
- Ethereal 同样是消耗，应走 dispatcher。原版 DiscardAtEndOfTurnAction 先隔离 retain/selfRetain，再设置普通丢弃动作，再打乱剩余手牌遍历其回合末 hook；Ethereal hook用 TOP 的 ExhaustSpecificCardAction。并非现在 Core 的按固定手牌顺序直接批量移动。这里的 shuffle 没有显式传 STS Random，不可编造独立 cardRandomRng 调用。
- DrawCardAction 没有 turnHasEnded 短路；DE 的回合末抽牌不能仅凭 phase或turnHasEnded取消。NoDraw、满手、空堆与洗牌规则仍适用。retain、Runic Pyramid、Equilibrium、回合末伤害牌混排需单独接入，组件未声称完成。
- Dead Branch、Charon's Ashes、Necronomicurse 自身 hook、Strange Spoon 的 UseCard 掷骰、其他非空自定义 exhaust hook未实现。接入方必须枚举并拒绝，不能不传上下文后假称兼容。当前 `onCardDrawOrDiscard` 有规则钩子的能力/遗物也不能静默省略。

## 可直接接入的纯数据 API

新增 `src/lua/abyss_exhaust.lua`：

- `rememberPower(state,id)`：首次成功获得 feel_no_pain/dark_embrace 后记录相对顺序；再次叠加不移动。记录保存在普通数组 `state.exhaustPowerOrder`。移除能力由调用方删除记录，重获重新登记。已有激活能力缺记录时显式报错。
- `plan(state,instance,options) -> {top={},bottom={}}`：验证后返回纯数据；snapshot当前 FNP/DE量，按获取顺序组装。`options.onExhaustRelics` 必须由 caller 枚举全部 onExhaust遗物；非空目前拒绝。未知自身hook拒绝。
- `move(state,instance,'hand'|'using',Queue,options)`：先预检完整牌堆 UID、当前实例引用、触发支持与队列存在；排入计划并移动同一实例，清除对应 cardInUse，发出 `exhaust {uid,cardId,origin}`。事件画面已能看到真实消耗堆。TOP列表表示源码的插队调用顺序。调用方负责事务：队列方法或事件发生意外错误必须恢复整个图，不能只截短数组。
- `shouldExhaust(state,resolvedDefinition,{purge=true|false})`：Power/purge优先，其他返回固有exhaust或腐化Skill。调用方必须在创建 UseCard 时调用并持久保存结果；此函数不处理费用、勺子、returnToHand等。

计划动作保持现有 `{kind='effect',effect={op=...,value=...}}`，附纯字符串 `exhaustSource` 供追踪。FNP带 fixed=true；DE是draw；哨卫是energy。没有函数入 state，不引入新 action kind。`Events.emit` 只是可见事件，不能反过来充当规则总线。

```text
play:
  start transaction; validate complete supported hook/relic surface
  capture cost/energy and shouldExhaust into pendingPlay before effects
  detach used card into cardInUse
  create queue(nativeEffects + UseCard)
  run queue

handChoice/exhaust:
  move(selected,'hand',Queue,ownedHookContext)

UseCard:
  resolve Power/purge/StrangeSpoon/other disposal flags first
  if captured exhaust: move(cardInUse,'using',Queue,ownedHookContext)
  else: clear cardInUse and move to correct non-exhaust destination

choice command:
  snapshot current paused graph (including pending selection and current action)
  move selected instance; clear choice; resume queue
  on failure restore that graph; earlier draw/block must not repeat
```

Core最小改动还需：统一现有 resolvePlay/queued useCard/Ethereal三个移动入口；FNP/DE在gainStatus首次真正生效时登记；替换 HandChoice 的旧硬拒绝；卡牌带触发或腐化时强制走队列；把费用实例元数据接入 canPlay/cardDefinition、抽牌、生成牌与回合恢复；把 owned relic hook上下文带入战斗。未完成上述项目时不得开放运行牌。

## 验证范围与下一组真实集成验收

`node scripts/test-lua.mjs tests/lua/warrior_exhaust.lua`：12组通过，使用真实 Combat 状态、现有 Queue、真实 block/draw/energy执行；清理 handler 是组件宿主契约演示，没有声称 C.play已会这些新牌。覆盖顺序与叠加、Dex/Frail固定格挡、哨卫基础/升级、原生draw不能回抽使用牌而DE清理后可回抽、双批消耗、胜利hook、回合末允许排draw、Corruption Skill判定、未支持hook拒绝、UID及死亡防御、原引用事务恢复。

集成后最低限度补 C.play/C.chooseHand真实测试：

1. 两种获取顺序各跑升级True Grit；选择暂停前仅原生格挡，恢复后每次消耗按正确顺序生效，故障回滚不重复前段格挡。
2. 燃烧契约原生2/3抽牌发生在自身清理前，DE抽牌在清理后；无腐化可回抽契约，有腐化不能；满手、NoDraw、空堆及洗牌RNG计数准确。
3. 腐化基础/升级、重复打出、激活时四堆费用、下回合、抽入和生成牌、0/-1/-2费用；Power不消耗；勺子self路径一次掷骰，指定路径零次。
4. 哨卫基本/升级被选中时先获得能量，再执行原生抽牌和FNP/DE；自己在腐化下打出时先格挡，再清理能量。
5. Ethereal回合末DE抽牌顺序与保留牌隔离；死亡、最后怪物死亡、触发内死亡，各拿到源码相同时间点的trace后再开放相关组合。

## 固定来源与逐文件 SHA-256

提交 `319009d5df0a82d9fb0f23cc22322286c6a87ec0`；下表所有内容均从此提交原始文件下载并计算SHA-256。下载原文仅用于研究，未加入项目。文件路径链接固定到该提交。

| 固定源文件 | SHA-256 |
| --- | --- |
| [actions/GameActionManager.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/actions/GameActionManager.java) | `a47d1ee9c6b2e194b7d3ef311328f2a15e38f5630330689e438e46685b94d6c3` |
| [actions/common/ApplyPowerAction.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/actions/common/ApplyPowerAction.java) | `f64ce8511f961a1990f1909e2c55654fa6dbf1dc2f4f1f3d3a7156c2ec2a9d47` |
| [actions/common/DiscardAtEndOfTurnAction.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/actions/common/DiscardAtEndOfTurnAction.java) | `d80e3ae091de4bc4e74879f195b5ec2d1bb7e7c7e92eac636bf452d61e4bebf0` |
| [actions/common/DrawCardAction.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/actions/common/DrawCardAction.java) | `67d02ba84c1d7e60fbb2a4a83f2b2d3ebbd81a84d29c16ccb98ecc9dd1a17e18` |
| [actions/common/ExhaustAction.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/actions/common/ExhaustAction.java) | `10fd566a420d2549c3705a564ca6274da189eacad7df1872ddf2867af936f510` |
| [actions/common/ExhaustSpecificCardAction.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/actions/common/ExhaustSpecificCardAction.java) | `86224fd382a494afef43efac62f33f92a08e5a4562be1a03409cb071eb1080b3` |
| [actions/common/GainBlockAction.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/actions/common/GainBlockAction.java) | `e48f437c06b42dda312446a4b536aca54570d637e53087ac16f736d84bb5df4f` |
| [actions/common/GainEnergyAction.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/actions/common/GainEnergyAction.java) | `d370759b93d7211ac1888865db1624344c953864728fcc741d385a139cf0028d` |
| [actions/utility/UseCardAction.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/actions/utility/UseCardAction.java) | `90213939af6d7ec83dea01bb2feef4ba762a93400dc1535732e2eebcdb6cab0f` |
| [cards/AbstractCard.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/cards/AbstractCard.java) | `bcd472ececfd8ce4150ccd4eb6dd07a2e2dc43e139196fe00de34705cf1a2a61` |
| [cards/CardGroup.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/cards/CardGroup.java) | `03de4e22ab22bedf1d90df72bdc83f033ff6aa776ad9d8f7259e1ee9293f7fa8` |
| [cards/curses/Necronomicurse.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/cards/curses/Necronomicurse.java) | `139c427e7ad4e98113024a9909a1479025e3625c71f9236e6ae0a0f02c239f2f` |
| [cards/red/BurningPact.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/cards/red/BurningPact.java) | `f8fe5ea1415f7767d85f6e197bcd296b97ed071d717b70f373f75e87f68d7612` |
| [cards/red/Corruption.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/cards/red/Corruption.java) | `081129a985afff15a7f0ab84ecab77e97902fbb2bcfdba6870104e6929d5c1d9` |
| [cards/red/DarkEmbrace.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/cards/red/DarkEmbrace.java) | `eb99b09303f4a54c90ab72d8640bc878f5c55e878e0263d46f2d4bf14a49916b` |
| [cards/red/FeelNoPain.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/cards/red/FeelNoPain.java) | `ed77fe5d9db2d290fdc5e34d2bd8305c4b0c9e6b1301893a41e39831e00758d0` |
| [cards/red/Sentinel.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/cards/red/Sentinel.java) | `e0abf389c04b8eb80c0549125706cfffae8cb3434512a25767f45690f72e9f0b` |
| [characters/AbstractPlayer.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/characters/AbstractPlayer.java) | `2720ba8dd7a216781a3b2fcb709f5ec67dc9b2559af25f7f6b89df1ef0947d95` |
| [powers/AbstractPower.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/powers/AbstractPower.java) | `37a6e97bc1a7a3d0cbfe93fd07e9f809690f7c02f24fd45ec34892466b6e0f9f` |
| [powers/CorruptionPower.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/powers/CorruptionPower.java) | `d1aa54c286ac8b9a02a467abe5bd7aac3dfa7c831c77b4872607316f220f067b` |
| [powers/DarkEmbracePower.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/powers/DarkEmbracePower.java) | `4b6292679fe2980af63124e0d8e86c63b311bedb380f4d47619c92c1aab1bc3c` |
| [powers/FeelNoPainPower.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/powers/FeelNoPainPower.java) | `2d367aa74b13a2081e8d1ba7599c3fc0d05ec2a9b0721dc59173d8fe798889c7` |
| [relics/CharonsAshes.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/relics/CharonsAshes.java) | `0cafa20d8db7b9b786dd7bddf0dc8611bb39829a19aaaebf4bc8412c318b4135` |
| [relics/DeadBranch.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/relics/DeadBranch.java) | `dbace8181345b67bb9c704b83dea61c9754c3268fc5d93c192f1bd47908c2d6f` |
| [relics/StrangeSpoon.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/relics/StrangeSpoon.java) | `e319dca794cae7abfa9ecc18cedd3cb32ac6fd041d4c947e6ad012d03246526d` |
| [vfx/cardManip/ShowCardAndAddToHandEffect.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/vfx/cardManip/ShowCardAndAddToHandEffect.java) | `e0ac9f16f627a985920857080a2a9e2ef903e7f0db0741b57709de99b52202ef` |

## 五牌定义接入切片

新增 `abyss_warrior_exhaust_cards.withCards(data)`，可独立调用，也可接在 `abyss_warrior_cards.withFoundationCards(data)` 后；不修改旧helper。深拷贝保留所有原卡/状态，追加5卡与3能力，重复ID或重复marker显式拒绝。追加牌统一 color=red、experimental=true；marker为 `experimentalWarriorExhaust`。没有自动修改默认JSON或实验角色选择，不代表默认牌库自动启用。

| 新牌 | 基础 effect | 升级覆盖 |
| --- | --- | --- |
| 腐化 | `gainExhaustPower(corruption,1)` | cost=2，其余继承 |
| 无惧疼痛 | `gainExhaustPower(feel_no_pain,3)` | amount=4 |
| 黑暗之拥 | `gainExhaustPower(dark_embrace,1)` | cost=1，抽牌层数不变 |
| 哨卫 | 普通block=5 | block=8；dispatcher按cardId和实例upgraded识别2/3能量，不向实例塞回调 |
| 燃烧契约 | handChoice(exhaust_choose,1)，然后draw=2 | draw=3，顺序不变；没有固有exhaust |

`gainExhaustPower`是新专用op，必须同时接入 Effects.supported/requiresQueue 与 queuedHandlers；不能只用原gainStatus绕过腐化费用和能力顺序。`corruption`状态stack=none，另外两个stack=intensity，三者decay=none；中文名称与描述随helper提供。能力获取顺序只在首次真正施加成功后登记，叠加不重排。

新增 `tests/lua/warrior_exhaust_cards.lua` 计划25组，全部使用真实 `Combat.new/play/chooseHand/endTurn`；夹具只重排Combat创建的原实例，不替换Core模块或规则函数。覆盖基础/升级数值与费用、燃烧契约先强制选牌后抽牌、腐化四堆改费与跨回合、重复腐化、哨卫自消耗与能量、固定FNP、DE抽牌与契约合法回抽、两种能力获取顺序、NoDraw与叠加。

当前证据：在尚未接 `gainExhaustPower` 的 sts-builds 核心快照中，前5组通过，第6组在真实打出腐化时返回 `unsupported_effect:gainExhaustPower`，整文件exit1。后续Core接入后必须重跑全25组，不能把此红例标记为五牌已可玩。上表原版费用、升级和自带效果已重新逐一核对固定来源；SHA-256沿用本文件的5份cards/red文件与对应3份Power文件，没有更换版本。

## Core接入后的回合末验证

后续 `sts-builds` 核心已接专用能力队列、腐化费用、实例适配、手牌消耗、自消耗、Ethereal与保留恢复。上述五牌测试在该核心私有副本重新执行，25组通过；早期红例保留为接入前的历史证据，不再代表当前运行结果。

新增 `tests/lua/warrior_exhaust_endturn.lua` 11组真实Core测试，使用Combat-created UID与真实出牌/回合结算。需要一个晚于腐化激活的新技能时，通过真实 `makeTempCardInDiscard` 效果建立夹具，不替换费用、抽牌或消耗规则。覆盖：

- Dazed和Carnage每张均触发FNP/DE；不规定两张虚无牌的相对顺序。单虚无牌分别检验两种能力获取顺序。
- 保留牌恢复先于DE抽牌；Sands of Time在恢复时排入的减费尾晚于已经在队列中的DE尾。9张真实Windmill Strike保留后，DE层数2只补进剩余1槽，总手牌保持10。
- 真正打出的Battle Trance在当前玩家回合产生NoDraw；存活完成回合末自动牌后，NoDraw先移除，随后两张虚无牌各触发FNP和允许抽牌的DE。若Regret自动牌先致死，后续移除和虚无清理均停止，原Regret实例保留在cardInUse且NoDraw保持生效。
- 腐化回合末reset后，DE抽到的新技能只获得临时turnCost=0，未被错误写入combatCost；该0费跨越下一次回合开始。移除腐化后仍暂为0，直到再下一次endTurn reset恢复原费。旧技能的combatCost=0在移除后保持且不再被强制消耗。
- 合法的正数实例turnCost=2仍要求至少2能量才能使用；腐化下实际Skill支付为0。测试直接调用canPlay/play，验证门槛与支付不能合并成同一条跳过规则。
- 故障仪器先调用真实事件函数，在真实DE洗牌、FNP和保留减费已执行后抛错。检查全图每个原表的内容及引用、卡实例、费用、保留元数据、牌堆、事件、RNG及primitive均恢复，然后真实重试只结算一次。

定向命令 `node scripts/test-lua.mjs tests/lua/warrior_exhaust_endturn.lua`：修正后的 `WARRIOR_EXHAUST_ENDTURN_PASS11`，exit0，约1.2秒。仅离线核心证据，未运行fullsuite、平台导入或实机验收。

**随机顺序边界仍保留**：源码DiscardAtEndOfTurnAction的外部 `Collections.shuffle` 顺序没有在本片复现。以上双虚无测试只校验不受该顺序影响的结算性质，不能据当前固定遍历顺序宣称源码随机轨迹一致。Corruption与保留Skill组合仍由retained模块显式拒绝；本片混合测试只使用保留Attack，不绕过该门禁。

### NoDraw旧错误结论撤回与固定源码复核

早期第6组把当前Core的旧flag生命周期当作源码事实，错误断言“Battle Trance的NoDraw持续到下一回合，因此阻止回合末Ethereal→DE抽牌”。旧10组通过只证明了当时实现，不能作为该顺序的source验收；该断言及对应文档结论明确撤回。固定源码复核后，核心与第6组均已修正，并新增第7组Regret致死窗口。

固定提交仍是 `319009d5df0a82d9fb0f23cc22322286c6a87ec0`。方法级顺序为：

1. `AbstractRoom.endTurn` 第384行先调用 `player.applyEndOfTurnTriggers()`；实际继承自 `AbstractCreature.applyEndOfTurnTriggers` 第536–542行，逐能力调用 `atEndOfTurn(true)`。
2. `NoDrawPower.atEndOfTurn` 第30–32行向BOTTOM排 `RemoveSpecificPowerAction`。该类没有覆盖onInitialApplication、onRemove或atStartOfTurn；它们继承AbstractPower空实现，不存在“nextStart移除”的源码hook。
3. `AbstractRoom.endTurn` 第385–386行随后才向BOTTOM排ClearCardQueue与DiscardAtEndOfTurnAction。因此NoDraw的Remove动作先执行，RemoveSpecificPowerAction从powers列表移除该能力。
4. DiscardAtEndOfTurnAction再通过Ethereal hook排ExhaustSpecificCardAction，DE消耗hook才向BOTTOM排Draw。DrawCardAction第64行在执行时检查的是当前 `hasPower("No Draw")`，此时已无该能力，故允许抽牌。

Regret等回合末自动使用牌属于更早的cardQueue阶段；AbstractPlayer第849–851行须等cardQueue为空且无控制动作才置isEndingTurn，房间才进入上述endTurn。因此致死Regret应阻止后续NoDraw移除，不能在自动牌之前提前清flag。

| 本次新增固定源文件 | SHA-256 |
| --- | --- |
| [powers/NoDrawPower.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/powers/NoDrawPower.java) | `3206760968d070de2705010d8fd2718641d674b7571602e00c0d27933382d83a` |
| [rooms/AbstractRoom.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/rooms/AbstractRoom.java) | `020f4a0fc3a564f6e45604e5dba582a773a5b9fdb471f8488a2bf8c2354d3a05` |
| [core/AbstractCreature.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/core/AbstractCreature.java) | `3db6e08c6bd033192aa368e29ad53f4614194898ccf0f525480fe20cb8799f2b` |
| [actions/common/RemoveSpecificPowerAction.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/actions/common/RemoveSpecificPowerAction.java) | `c6262b3ce8528f75045f9610026d524a8ae63c526547593e4549f7c5a01a1ad8` |

重现夹具为FNP、DE、Battle Trance、Dazed、Carnage，先真实打出前三张再endTurn。旧Core在enemy_turn事件中仍是noDraw=true、hand=0、discard=1；修正后先出现no_draw_removed，再出现两次exhaust，enemy_turn已hand=1、discard=0，手中Battle Trance由DE在敌行动前洗回抽到。最终下一玩家回合两版本都可能hand=1，因此测试必须核中间事件时点。这里源码结论来自固定方法的静态队列追踪；离线Lua复跑结果单独报告，不冒充正版客户端运行取证。
