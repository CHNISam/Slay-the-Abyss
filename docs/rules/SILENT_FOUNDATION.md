# Silent 基础切片

本模块是待共享职业入口接入的基础能力，不代表 Silent 已可独立开局、自然获取或实机通过。主生产入口没有导入它，也没有改变战士奖励池。

## 固定来源

核对公开社区反编译镜像 [aeubanks/sts@319009d5](https://github.com/aeubanks/sts/tree/319009d5df0a82d9fb0f23cc22322286c6a87ec0)，仓库登记版本 V2.3.4 / 2022-12-18。不是官方开源或已认证正版 PC 二进制。仅据事实独立实现，不存储方法体。

- `cards/green/DeadlyPoison.java`：1 能量施加5毒，升级7毒。
- `cards/tempCards/Shiv.java`：0 能量、4伤害、消耗，升级6伤害。
- `actions/common/MakeTempCardInHandAction.java`：生成的牌最多填满10张手牌，其余进入弃牌堆，使用独立实例。
- `powers/PoisonPower.java` 与 `actions/unique/PoisonLoseHpAction.java`：回合开始HP损失，然后毒减1，末敌死亡清理后续动作。

## 接口及验证

`withFoundationCards(data)` 返回独立数据副本，供真实 `Combat.new` 创建战斗；从 `deadly_poison` 和 `shiv` 两个定义开始扩展基础绿牌。牌的费用、目标、状态、伤害、升级和消耗全部由既有 `Combat.play` 处理，毒的时点和 Artifact 由既有 Actor 处理。

`generateShivs(state, count, upgraded)` 是待动作调度器调用的生成动作，接受0到10张，返回UID列表，使用真实战斗牌堆与UID。它不支付费用，不等同于打出 Blade Dance；不会加入永久卡组。拒绝已结束战斗、冲突UID、错误输入以及尚未实现的 Accuracy/Master Reality 状态。

运行：`npm ci --ignore-scripts --cache /workspace/.npm-cache`，`npm run build:data`，`node scripts/test-lua.mjs tests/lua/silent_foundation.lua`。

测试覆盖真实出牌的毒量/升级/费用/人工制品/毒杀，真实Shiv伤害/升级/消耗/旧UID拒绝，满手溢出及输入预检。未运行游戏或完整套件。

## 保留缺口

没有职业选择、Silent初始牌组、奖励/商店池或完整飞刀能力体系。Actor现有毒伤来源归属与原版毒层上限仍需共享任务核对。本切片不认证所有毒交互。

## 最终弃牌动作模块

`abyss_discard` 增加真实战斗手牌选择：`begin(state,count)` 成功时返回 `true,token`，手牌不多于所需张数时按手牌尾到头自动全弃并返回 `true,nil`。空手或0张不等待输入。`choose(state,uids,token,api)` 检查数量、重复UID、整手牌快照和回合后确认。`manualDiscard(state,uid,api)` 是动作适配器使用的明确手动弃牌入口，不是供UI绕过选牌token使用的命令。`active(state)` 告知共享Combat是否应阻止其他出牌及结束回合。

`state.pendingDiscard` 保存可序列化的token、serial、turn、count和handUids；`state.discardSerial` 递增。外层UI还须绑定当前战斗对象或战斗generation，不能将另一场战斗中相同数值的token转交本场。

明确弃牌后，Tactician的1/2能量按队头LIFO顺序先结算，Reflex的2/3抽牌按队尾FIFO顺序结算；抽牌调用传入的 `api.draw(state,count)`，默认使用真实 `Combat.draw`，所以满手、NoDraw和洗牌规则复用现有引擎。回合末弃牌不经过本入口，不触发这两个收益。所有卡牌都先移入真实弃牌堆，再执行触发。自动全弃的方向还核对了固定源 `cards/CardGroup.java` 的getTopCard行为。

选择和自动全弃使用原引用图事务：任何抽牌回调抛错会恢复原手牌、弃牌、卡实例、事件、pending对象、状态和嵌套随机流的引用及内容，原错误值保持不变。无效输入和能量溢出在移动前拒绝。自定义抽牌回调必须以抛错报告执行失败，不允许错误返回值或外部副作用；外部IO不能由状态快照撤销。

仅支持整牌最后的弃牌动作，首批接入Survivor/Acrobatics及Tactician/Reflex。没有通用动作队列、随机弃牌、不定量弃牌、其他弃牌遗物/能力钩子或UI；不得把它用于还有未执行尾部动作的牌。共享入口负责锁定pending操作。

自动全弃时，若 `state.resolvingCard` 为真，Tactician能量立即按队头顺序结算，Reflex的 `{uid,amount}` 尾部动作依FIFO保存到 `state.pendingDiscardDraws`。共享Combat必须在把使用牌移至正确牌堆后调用 `flushDraws(state,api)`，并将新增队列纳入整牌事务。非出牌结算内的选择确认仍直接抽牌。flush先清队列再调用真实draw，战斗结束或玩家死亡时取消，抛错则原引用回滚并保留队列供重试。

这点依据固定源 `characters/AbstractPlayer.java` 的 `useCard`：先调用卡牌use排入效果，再排 `actions/utility/UseCardAction.java`；弃掉Reflex时的addToBot抽牌落在UseCardAction之后。Survivor与Reflex仅两张、抽牌堆空时，需先弃Survivor再由Reflex抽回两张，不能在自动全弃内部提前抽牌。

定向验证：`node scripts/test-lua.mjs tests/lua/silent_discard.lua`。使用真实Combat状态与抽牌，覆盖自动不足、选牌验证、能量/抽牌顺序、回合末排除、满手、NoDraw、能量/token溢出及抛错原引用回滚。

## 七张基础绿牌扩展

逐张从上述固定提交的 `cards/green/<Class>.java` 核对费用、基本/升级值与动作顺序。只使用现有共享操作，不新增复杂触发，也未接入自然奖励/商店池或正式客户端。全部数值均是规则事实，未搬运源方法体。

| 类名／运行ID | 基本版 | 升级版 |
| --- | --- | --- |
| Footwork / footwork | 1费能力，获得敏捷2 | 敏捷3 |
| Backflip / backflip | 1费，先格挡5，再抽2 | 格挡8，仍抽2 |
| DaggerThrow / dagger_throw | 1费，先伤害9，再抽1，再选弃1 | 伤害12，其余不变 |
| DaggerSpray / dagger_spray | 1费，对全体每轮4伤害，共2轮 | 每轮6伤害，共2轮 |
| CloakAndDagger / cloak_and_dagger | 1费，先格挡6，再生成1张基本Shiv | 格挡仍6，生成2张基本Shiv |
| Prepared / prepared | 0费，先抽1再选弃1 | 先抽2再选弃2 |
| QuickSlash / quick_slash | 1费，先伤害8，再抽1 | 伤害12，仍抽1 |

下表SHA256来自本轮HTTPS只读抓取的完整原文件字节，未保存源代码；固定版本身份仍仅是社区镜像证据，不等于PC认证。

| 固定源类名 | SHA256 |
| --- | --- |
| Footwork | `3a22042c886811da75cafc1cafdcde2930f1c5fe43596ba949016baacddb0ffe` |
| Backflip | `0b6f508623fef35612ff2b4788429750f16d14153837392e4ed39d4e2037d8ff` |
| DaggerThrow | `0ca70937cccdc12ef9ee1af73d3ad0571d998edd003d46a2001e864973cb34d4` |
| DaggerSpray | `1f1d74bc6e703483ea64678f2547e6044c4c6aae489326b82f4fc5c64d9e2284` |
| CloakAndDagger | `c2e0197229c352fe91cbfab79c0a417c16575bd2406164b1a8dc591e958e7c68` |
| Prepared | `e5a8007904dfd4ec6fe574b0b0f41bdf18664030333e7b644b88d753425169a6` |
| QuickSlash | `0b2e7328545ec6ce52d911c69096e7653d3093389ae307d78d11e48914c9f9d0` |

`node scripts/test-lua.mjs tests/lua/silent_expansion.lua` 通过20组真实Combat.play回归：七张基础/升级、能力退出牌堆和敏捷影响后续防御、格挡先于抽牌、抽牌后可选弃刚抽到的牌、群攻逐轮目标顺序、升级不传给生成Shiv、最后一敌死亡后取消抽牌/弃牌尾、满手生成/抽牌、NoDraw仍弃牌，以及非法目标/费用不足无副作用。

主线程已将Survivor/Acrobatics接入真实出牌入口。requestDiscard被限制为整牌最后动作；失败返回必须进入整牌回滚。自动Reflex触发经`pendingDiscardDraws`延迟到使用牌入弃后，避免两牌空抽牌堆时少抽回Survivor。Run选择命令另验证combatGeneration；UI入口尚未交付。
