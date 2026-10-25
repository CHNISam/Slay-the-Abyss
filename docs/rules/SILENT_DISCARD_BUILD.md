# 猎人弃牌流：条件退能量、连击降费与全手换牌

此切片仅提供独立牌定义、弃牌历史/费用状态与纯数据动作展开。共享Combat、Discard和队列由主线程接入；没有用mock补齐缺失核心，也没有声明完整弃牌卡池或实机通过。

## 固定来源

公开社区反编译镜像 [aeubanks/sts@319009d5df0a82d9fb0f23cc22322286c6a87ec0](https://github.com/aeubanks/sts/tree/319009d5df0a82d9fb0f23cc22322286c6a87ec0)，声明V2.3.4 / 2022-12-18；未认证正版PC二进制。仅读取事实并独立实现，不保存原方法体。

| 路径 | SHA256 |
| --- | --- |
| cards/green/SneakyStrike.java | `f18c8405234d07c4c6916bfff8335a42ce1f024c7eb25864e5653a06cfd72257` |
| actions/unique/GainEnergyIfDiscardAction.java | `cba57d46a5a4c23f09317a0f4557760715a3f1775ea85c5774fffdb640585e2d` |
| cards/green/Eviscerate.java | `08f626ea6aaf40782569eec37a7255898b2567b31b54c4ed9bed81e53ba65d0c` |
| cards/green/CalculatedGamble.java | `cf391cdd213e65ce788684ed814e5990a23ad1fd55258a84d79e0c236296c9a2` |
| actions/unique/CalculatedGambleAction.java | `2b2272c2f5ea8d6cbf2660c898305302d623c502f7a5c1e900580221a30d7fe4` |
| actions/GameActionManager.java | `a47d1ee9c6b2e194b7d3ef311328f2a15e38f5630330689e438e46685b94d6c3` |
| characters/AbstractPlayer.java | `2720ba8dd7a216781a3b2fcb709f5ec67dc9b2559af25f7f6b89df1ef0947d95` |
| cards/AbstractCard.java | `bcd472ececfd8ce4150ccd4eb6dd07a2e2dc43e139196fe00de34705cf1a2a61` |
| cards/CardGroup.java | `03de4e22ab22bedf1d90df72bdc83f033ff6aa776ad9d8f7259e1ee9293f7fa8` |

卡牌使用固定源英文ID说明，显示名称由项目的中文表现层另行维护。

## 三张牌的规则

Sneaky Strike源ID仍为 `Underhanded Strike`，2费普通攻击，基本12伤害、升级16，有STRIKE标签。先排伤害，再排GainEnergyIfDiscardAction(2)。该动作**执行时**检查本回合总弃牌大于0才回复2能量，不是在出牌前缓存条件。仍须先付2费；不是“满足弃牌就把费用显示成0”。最后一个敌人死亡会清理此非DAMAGE后续动作，不能在胜利后退款。其他triggerOnGainEnergy手牌钩子不在本片的已支持范围。

Eviscerate为3费、每次7伤害连续3次，升级每次9。费用不是每次读牌时统一 `3-totalHistory`：

- 新构造实例仍是3费；尚未真正抽入手的新生成实例不能自动获得旧弃牌历史折扣。
- `didDiscard()`减当前costForTurn1，最低0。
- `AbstractPlayer.updateCardsOnDiscard()`遍历手牌、弃牌堆、抽牌堆，不遍历消耗堆；被弃的Eviscerate已进入弃牌堆，所以该次也获得折扣。
- `triggerWhenDrawn()`在真实抽牌时重新设为本牌基础cost减本回合总弃牌，最低0。
- `atTurnStart()`重置属性。`applyStartOfTurnCards()`作用于抽牌、手牌、弃牌三堆，不包括消耗堆。
- 源makeCopy包含对this而非新tmp的费用操作；本片不将这一社区镜像边界推断为已实现的所有生成/复制规则。

Calculated Gamble为0费罕见技能。基本消耗，升级仅去消耗；卡牌use无论升级与否都构造 `CalculatedGambleAction(false)`，因此不能把该动作另一个未被此卡使用的升级分支“多抽1”套到升级卡上。

Gamble动作首次执行时读取当前手牌数量N，此时使用牌已经离开手牌。N=0不产生弃牌或抽牌动作。否则全弃再抽N。虽然内部DiscardAction传random=true，但因所需数量等于手牌数量，走自动全弃分支，从手牌尾到头，不消耗随机弃牌RNG。

## 精确动作顺序

初始排队：GambleAction → UseCard清理。

GambleAction在自身执行时把弃牌和抽牌压到队头，因此变成：

1. 全手牌弃掉，每张触发手动弃牌、更新历史和各Eviscerate费用。
2. Tactician加入TOP的能量，按加入的逆序执行。
3. Gamble自己的Draw(N)。使用牌此时还未归入弃牌/消耗堆，不能被自己的普通抽牌抽回。
4. UseCard清理：基本Gamble进入消耗堆，升级Gamble进入弃牌堆。
5. Reflex加入BOTTOM的抽牌，按加入顺序执行。升级Gamble此时可以被Reflex洗回抽到，基本Gamble不行。

不能调用旧的“弃尽后立刻把全部Reflex抽牌一起执行”快捷路径替代这一顺序。NoDraw仍要弃牌、增加历史、触发Tactician，但普通和Reflex抽牌都应由真实DrawCardAction/Combat.draw跳过。满手时Gamble本体先离手，最多弃其余9张；普通抽牌最多填满容量，后续Reflex仍服从10张上限。

## 模块接口及共享接入

`withCardDefinitions(data)`独立追加三张定义，不隐式修改Silent helper或自然池。op约定：`gainEnergyIfDiscard`带value2，`calculatedGamble`不需要value，Eviscerate沿用damage times3。

实例费用字段使用 `storedDiscardCost`；全战斗唯一历史为 `state.discardedThisTurn`：

- `created(instance)`设置新Eviscerate为3，不读旧历史。
- `costAdapter(state,instance,detachedDefinition)`只读取已存费用，不副作用累计，也不代替真实onDraw。
- `onDraw(state,instance)`真实抽入手后重算折扣。
- `rememberDiscard(state,endTurn)`由共享Discard在每张已经进入弃牌堆后调用。endTurn=true仍增加总数，但不对三堆执行didDiscard，也不触发Tactician/Reflex。
- `beginTurn(state)`重置计数，并仅重置三堆Eviscerate费用，须在常规抽牌前调用。
- `gainEnergyIfDiscard(state,2)`执行退款动作；不承担卡费支付或伤害结算。
- `gambleActions(state)`在Gamble动作真正执行时读取当前手牌，返回纯数据requestDiscard(N)和draw(N)两动作。调用方将其按上述顺序插到现有UseCard前；不是在初次建牌队列、使用牌还在手牌时预读数量。

root必须让Gamble、后续抽牌和UseCard走同一纯数据队列，并将Reflex tail推BOTTOM，不能把函数存入state；计数、所有实例费用、牌堆和随机流须纳入事务原引用回滚。

目前费用实现仅验证未被其他牌改变基本cost的Eviscerate。Madness、Snecko类通用combatCost/turnCost与本牌折扣的覆盖顺序须另做固定源测试，不能据本片宣称全交互。非负安全32位范围外明确拒绝，不猜Java整数溢出。

## 验证边界

定向命令：`node scripts/test-lua.mjs tests/lua/silent_discard_build.lua`。

首次未集成基线运行前6个helper通过，第7个真实Sneaky Strike出牌因缺少共享op明确失败，退出码1；没有mock或跳过。主线程接好共享后重新执行，当前25个检查全部通过，退出码0。真实开局抽牌已初始化Eviscerate的storedDiscardCost为3；原两个nil前置断言修正为3，并保留“消耗堆不被didDiscard更新”和“溢出拒绝不改变费用”的原场景。

当前真实回归涵盖基础/升级出牌，退款、末敌取消、Eviscerate真支付/三段、抽入手历史及下一回合复位、Gamble基本/升级消耗、自身抽牌与Reflex清理时序、零手、NoDraw、费用归零，以及满10张手牌时除自身外弃9抽9且不消耗随机弃牌cardRandomRng。
