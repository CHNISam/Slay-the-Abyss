# 机器人引擎牌：19张独立实现

本片新增 `abyss_defect_engine_cards.lua`、对应真实战斗测试和本文。`withCards` 独立追加19张普通职业牌，不改共享核心、旧职业helper或Profile；模块存在不能算作牌池、UI、自然构筑或75张全卡已经完成。当前基础Profile为35张，接入本片后理论为54张，仍缺21张；必须以真正启用的Profile和Capability重新对账，不能把阶段总数165或19张定义当作完整初代四职业完成。

## 固定事实来源

逐张核对社区反编译 [aeubanks/sts@319009d5df0a82d9fb0f23cc22322286c6a87ec0](https://github.com/aeubanks/sts/tree/319009d5df0a82d9fb0f23cc22322286c6a87ec0) 的constructor/use/upgrade以及对应action、helper、球方法。该来源标注V2.3.4 (12-18-2022)，没有正版PC二进制认证。事实独立整理，实现没有复制Java方法。压缩包SHA256为 `3f42bd7dde08126a9a8a02fc8eed8856c7b8b0dda551f50c62ced838e41ed458`，地址 `https://codeload.github.com/aeubanks/sts/zip/319009d5df0a82d9fb0f23cc22322286c6a87ec0`；下方逐文件SHA256可复核。

| 本地ID | SourceID | 稀有度 | 费用 | 基础→升级及动作顺序 |
|---|---|---|---|---|
| claw | Gash | common | 0 | 普通攻击3→5，然后所有未消耗利爪及本牌基础伤害+2 |
| stack | Stack | common | 1 | 格挡=出牌时弃牌堆张数→再+3；本牌尚未弃置 |
| steam_barrier | Steam | common | 0 | 格挡6→8，然后本实例基础格挡-1，本战持续 |
| streamline | Streamline | common | 2 | 伤害15→20，然后本实例战斗费用-1，最低0 |
| aggregate | Aggregate | uncommon | 1 | 动作执行时抽牌堆每4→3张获得1能量，向下取整 |
| auto_shields | Auto Shields | uncommon | 1 | use时格挡恰为0才排格挡11→15 |
| blizzard | Blizzard | uncommon | 1 | 本战累计成功生成冰霜数×2→3为基础群体普通攻击 |
| chaos | Chaos | uncommon | 1 | use时按cardRandomRng选1→2个球，再依次channel |
| chill | Chill | uncommon | 0 | use时每个存活且未逃跑敌人生成一个冰霜；消耗；升级先天 |
| doom_and_gloom | Doom and Gloom | uncommon | 2 | 群体伤害10→14，再生成一个黑暗 |
| lock_on | Lockon | uncommon | 1 | 普通伤害8→11，再施加锁定2→3回合 |
| melter | Melter | uncommon | 1 | 移除目标全部格挡，再普通伤害10→14 |
| rip_and_tear | Rip and Tear | uncommon | 1 | 随机普通攻击7→9，独立执行2次 |
| skim | Skim | uncommon | 1 | 抽3→4张 |
| sunder | Sunder | uncommon | 3 | 普通伤害24→32，杀死目标时BOT排获得3能量 |
| tempest | Tempest | uncommon | X | 原生动作执行时BOT排X→X+1个闪电，再消费当前能量；消耗 |
| meteor_strike | Meteor Strike | rare | 5 | 普通伤害24→30，然后依次生成3个等离子；含STRIKE标签 |
| multi_cast | Multi-Cast | rare | X | 有首球时BOT排X→X+1次唤起，仅最终一次移除；不消耗 |
| thunder_strike | Thunder Strike | rare | 3 | 本战累计成功生成闪电数次随机普通攻击7→9；含STRIKE标签 |

这19张稀有度为4 common、12 uncommon、3 rare。所有牌定义有独立中文name/text/upgradeText、真实sourceId和升级元数据；动态值的原生CardPreview/UI适配由root后续接入，未知op必须继续明确拒绝，不能借文案绕过Capability。

## 纯数据接口

`M.ops` 导出16个外部新op（含applyLockOn、removeBlock），供共享supported/requiresQueue/dispatcher使用，不含engine前缀内部descriptor。Host只按ops调用prepare；未知普通op返回原样深拷贝。

`withCards(data)` 深拷贝输入，拒绝任何重复牌ID和lock_on状态ID，追加中文锁定状态。状态 `decay='none'` 防止共享Actor重复削减，需显式接 `endRound`。

`adaptDefinition(state,instance,definition)` 不修改输入，对以下字段生成当前定义：利爪 `engineClawBonus`；堆栈当前弃牌数；蒸汽护壁 `engineBlockLoss`；暴风雪累计冰霜基伤；雷霆打击当前累计次数。Streamline沿用现有 `combatCost/turnCost` 适配接口，不重造第二套费用。

`prepareEffect(state,effect,target,context)` 返回 `preparedEffect, optionalRngAfter`，全程不写state。暴风雪捕获每个target.id对应NORMAL伤害；Sunder捕获NORMAL单体伤害；自动护盾捕获use时条件及卡牌格挡值；Chill捕获use时敌数；雷霆捕获use时闪电历史次数。Chaos在**克隆**cardRandomRng上按源选择全部1/2球并返回after，root须在原生use构造阶段提交该RNG，再执行任何已排伤害/球动作。

`planEffect(state,effect,context)` 不写state，已知动作返回：

```lua
{
  top = { effect1, effect2 },
  bottom = { effect3 },
  consumeAllEnergy = false,
  instanceChanges = {
    {uid = 123, changes = {engineClawBonus = 2}}
  },
  cardRandomRng = optionalAfter
}
```

数组是执行顺序，Host逆序pushTop、顺序pushBottom，包装为已有 `{kind='effect',effect=...}`。纯计划的所有验证完成后，Host再一次性提交实例写入、RNG和能量。实例记录无活对象引用，仅UID和变更字段；完整战斗事务必须恢复这些嵌套字段和原表引用。

context字段为 `target`（当前目标actor）、`instance`／`uid`（正在使用牌）、`energyOnUse`、可选 `freeToPlayOnce`、`chemicalX`。非零Chemical X明确拒绝；组件能表示freeToPlayOnce但共享入口未接前不能宣称支持该来源。未知op返回nil，非法参数抛错。

共享普通 `damage` 必须支持固定的 `normalAmount` 以及可选 `targetId` 覆盖（随机击不能偷用pendingPlay的人工目标）；`damageAll` 必须支持按id的 `normalAmounts`。普通伤害仍触发易伤/力量已经捕获的NORMAL数值、Thorns、Angry和死亡反应，不是固定球伤害。

## 延迟、多次与随机动作

- `growClaws` 只更新本牌、hand/draw/discard中的所有Claw；不改exhaust。Source GashAction直接改这些实例的baseDamage。普通最后一击clearPostCombatActions会取消后续Gash，不应在牌定义或付费时提前增长。
- `loseSteamBlock`／`reduceStreamlineCost` 在对应伤害/格挡之后执行，更新本实例UID。Source GetAllInBattleInstances按同UUID覆盖using/hand/draw/discard/exhaust/limbo；本项目当前UID表示独立实例，尚未表示共享原UUID的复制牌路径，不能宣称那类交互一致。
- 源ModifyBlockAction的异常分支检查 `baseDamage<0`，没有clamp baseBlock。因此蒸汽护壁基础格挡可负，必须先叠加敏捷、脆弱，再对最终格挡clamp0；例如基础-1、敏捷3应得2而非3。
- `aggregateEnergy` 在动作执行时读draw数量；`autoShields` 则在use时决定是否排动作，之后After Image获得的格挡不能反过来改变已构造的条件。
- Chaos原始候选数组是 **Dark,Frost,Lightning,Plasma**，每次调用 `cardRandomRng.random(3)`。即使球位为0，或首个满槽唤起杀末敌，两个随机选择也早已发生；不能把随机选择挪到各channel执行时。
- `engineRandomRounds{value=伤害基数,remaining=N}` 是惰性多击。每段纯计划克隆当前cardRandomRng，从当前存活/未逃跑/未halfDead/未dying列表重新抽目标（只有一个也抽一次），按该目标和当下玩家状态重算NORMAL伤害，TOP排damage，再TOP排下一段。source AttackDamageRandomEnemyAction的calculateCardDamage发生在随机选中后。反伤杀玩家或最后敌人死后，不得继续抽下一随机目标。
- `sunderDamage` TOP排NORMAL damage和 `engineSunderRefund`；检查真实目标死亡后把energy3放BOTTOM。杀非末敌可返能；杀最后敌人时源clearPostCombatActions清掉GainEnergy，不能误返。
- `engineChannelRounds{orb,remaining,value=1}`、`engineEvokeRounds{remaining,value=1}` 为惰性多次动作。Tempest/MultiCast原生动作把它们放BOTTOM，因此先完成原来已排的UseCard清理。原生动作当下消费**当前**能量；后来的等离子唤起获得能量不能被再次消费。MultiCast无首球时连能量也不消费；升级0X仍唤起一次。
- 多重唤起的非最终段输出 `evokeWithoutRemovingOrb`，最终段输出 `evokeOrb`；每次唤起重新构造暗球最低HP目标与闪电随机目标，保持同一个首球直到最后移除，不以预先一次damage乘X伪装。

### 末敌死亡后的预排最终移球

Source MulticastAction在原生动作执行时已把全部EvokeWithoutRemovingOrbAction和最终EvokeOrbAction排好，两类actionType均为DAMAGE。GameActionManager.clearPostCombatActions明确保留DAMAGE，因此首段闪电杀末敌后，后面的最终EvokeOrb仍会移除首球，即使其伤害不再找到目标。惰性descriptor代表**预先排好的动作**，Host要保留最终移除，不能用终局后禁止新构造的检查把它丢掉。现有Orbs.prepareEvoke要求running，此边界是本轮已发现、需要root共享修复的具体接入点；测试包含真实末敌反例，不假称已有支持。

## 成功channel历史与锁定hook

`initHistory(state)` 在每战初始只调用一次、在破损核心之前建立 `state.orbChannelCounts={lightning=0,frost=0,dark=0,plasma=0}`。`onChannel(state,kind)` 只在实际插入球后记录；球位0和满槽唤起已结束战斗未插新球不计。满槽成功插新球计一次，已经唤起的旧球历史不减少。Root应在真正插球前预检计数能否推进；整牌事务捕获该历史表，失败恢复原引用。`channelCount` 为只读，缺历史的老fixture按0兼容，不能把这当作真实计数已接入。

`applyLockOn(state,target,amount)` 对存活目标走共享tryBlockDebuff的Artifact事件路径，成功后用Actor.status施加duration，不再二次调用Actor.applyPower以免双扣Artifact。`endRound(state)` 每个活敌锁定减1、为0时删除；其中文status模板在withCards中注册。

`orbDamage(target,amount)` 只读，目标存在锁定Power（即使0层尚未移除）时按Java float32×1.5截断并饱和为int，复用已存在的 `abyss_sts_random.float32`。Root必须在每个真实球伤害目标选中后调用，影响闪电被动／唤起、黑暗唤起，含电动力AOE每个不同目标；不影响冰霜格挡、等离子能量、普通攻击、Thorns或Burn，也不能在选随机目标前把整个球值统一放大。

## 验证状态

定向命令：`node scripts/test-lua.mjs tests/lua/defect_engine_build.lua`。

当前已写63组：6组数据/组件、38组19牌基础升级真实play、19组边界。首轮6组件绿；首个Claw真实play明确红 `unsupported_effect:growClaws`，root尚未接入共享新动作，所以未宣称63组战斗通过。没有mock Combat、没有改共享文件，没有运行全量检查、提交、推送或Backlog写入。

待接入定向覆盖包括：利爪增长范围和末敌取消；堆栈排除当前牌；蒸汽负基值；精简费用持久；累计球历史与0槽/满槽；use时混沌RNG；Chill按敌数；暗球生成前群伤；锁定Artifact/实际球伤害/回合到期；移盾后普通伤害；随机每击重选/单存活仍花RNG/Thorns停止；Sunder末敌不返能；X=0/升级加1、等离子后返能、多重暗球重选和末敌最终移球；尾部异常时实例增长、历史、RNG及牌堆原引用回滚。

没有平台导入、Windows实机、原生UI、新Profile池概率或自然四房验证。Chemical X、共享UUID复制、signed32之外溢出行为未实现；工程ABI对溢出明确拒绝，不能伪称Java溢出一致。既有通用能量999上限差异仍见Utility文档。

## 源文件指纹

路径相对固定快照根目录；没有混入其他commit。

| 源路径 | SHA256 |
|---|---|
| `cards/blue/Claw.java` | `462c48a541aaa6a502caf9a607e055ee4ff99fc31d1dc01d7091019671bf9a70` |
| `cards/blue/Stack.java` | `8d6a1de538cd668e91c3f81d043af4b45127c1f4d27d672f7a499cc3352d788b` |
| `cards/blue/SteamBarrier.java` | `f4080ef89544f7a03903a9163593d87d244546b6386211bf9ee052737ea27b18` |
| `cards/blue/Streamline.java` | `f7acf237615bc5e11b1783508509d9fc3198149f784481cadccaebb0ce051526` |
| `cards/blue/Aggregate.java` | `cd53d175a27986892ff59c6aa07b713645f2c23d6cec059ba6a047d5044cc700` |
| `cards/blue/AutoShields.java` | `4a0d9d88963301d8612026e74036e99b8a9e40487f14a7f5b3d047052a7d8387` |
| `cards/blue/Blizzard.java` | `6013939181145a0e270c904800e2a82daaab5c54293b2bfa23dd740ce259d920` |
| `cards/blue/Chaos.java` | `b4f6c7356e7c4d99f8d5b353ed68f569917c5d5aaf539eb4de0fa762b3324fb9` |
| `cards/blue/Chill.java` | `0f8cc8f18072c0cd5c8c01d22a3f33324645106628fa6233205be4f07c1ae333` |
| `cards/blue/DoomAndGloom.java` | `60052ad84e4a27ce1180088b6e9a44ccd3f281a84602b99a5de7f5f69d850a89` |
| `cards/blue/LockOn.java` | `495cbdd652943a100c9c3e17f96441ff7a4def13abeea5536cb858315966458d` |
| `cards/blue/Melter.java` | `7e80acdd45e9b6b310c95dad3e735d68d0e23483112ab02798fe4dd23c6d40b9` |
| `cards/blue/RipAndTear.java` | `d8d757abf3b0e2f2132ff5c4bf65ee3aa63f61b2be35bb5da7c1c1cf2d579e3b` |
| `cards/blue/Skim.java` | `b75d0eb28937fef8744b0711b4e65e834a73fc821a3eab45b053ca50b97b41ec` |
| `cards/blue/Sunder.java` | `c6217c61982479c719d4c27d7d2c15a0043ec1f08d91931f0737f547e9e47aa7` |
| `cards/blue/Tempest.java` | `9feefd2651b5558aa8831a33f58e5716bf61ee963e447684a18133ad55f2e2b0` |
| `cards/blue/MeteorStrike.java` | `27aefecfe685501ea7f34b5147261d349cbfe53fabe62b837809001ebcd30f46` |
| `cards/blue/MultiCast.java` | `fae8c173f9e753ce26e725ebf329799bb04b274c013542e586f7499bb7bb53dc` |
| `cards/blue/ThunderStrike.java` | `22f887a7820be98c653144ce0803ddc07218e40e56b1ed4d4f2e251e9eea49d3` |
| `actions/defect/GashAction.java` | `4326cc1c87d846692d03da787728c0103ab56c4d67f1c6330d687aa3f70830bd` |
| `actions/common/ModifyBlockAction.java` | `481b76b9de97d90bdd242d2fc83474caff9c0a41b4e38abafe615a64e694e852` |
| `actions/common/ReduceCostAction.java` | `3d84b5855ff5358938888db1a798fdf6ceef960f18939e7bd53ff256a8c76b5c` |
| `actions/defect/AggregateEnergyAction.java` | `64add353b50a11a385d88ef383771e040745f4d0adf254f497b88689d3d3f1d4` |
| `actions/defect/NewRipAndTearAction.java` | `a539a437beb507edc2c6210da88d2f7e1c29150172583d8d61f526eb05d30d1d` |
| `actions/defect/NewThunderStrikeAction.java` | `df079f191d9ca8a54d42b6cc8c772effcb30fb741431e999038cc139e15f94d9` |
| `actions/defect/SunderAction.java` | `0158694cc6822d4f81541b71dff41d8e17f94a5b0b05ce0ffdf27d531ad443a0` |
| `powers/LockOnPower.java` | `ad0963620d07b9034346787772f1ddd638cc3943c25ea437fc54f65cda526d8b` |
| `actions/unique/TempestAction.java` | `47c3e0ff0f6e6ff4f9c6ff5f25a11b66c1bfed99a0eb45877f87774f4ac6d4a8` |
| `actions/unique/MulticastAction.java` | `6e53219784a134e2e40f92c1d09b9d68ed09598b8ddacca643b52cb816be7cac` |
| `orbs/AbstractOrb.java` | `958dcb8ffa9c66c506aff886a7969c8e22366c2764166052ed1f613227bc5168` |
| `helpers/GetAllInBattleInstances.java` | `056231bdf229b7b32ba5d62cf722c04155acd521206e6a5be72df7a03f791213` |
| `characters/AbstractPlayer.java` | `2720ba8dd7a216781a3b2fcb709f5ec67dc9b2559af25f7f6b89df1ef0947d95` |
| `actions/defect/ChannelAction.java` | `65f0d9de68e7b57158e2ee460375760854df1146447eee6083eb028bbd5e647d` |
| `actions/defect/EvokeOrbAction.java` | `770d50256208ad421c4c0503b27e0ca14335baa6a4347278f8ce6d448ca1d143` |
| `actions/defect/EvokeWithoutRemovingOrbAction.java` | `c2d5c295ab153451e2f90a2b8587217001bf822c1a3cff30354a3fe18a785470` |
| `actions/common/AttackDamageRandomEnemyAction.java` | `2d5dce7ccb54cf086c5001d689bf08c5550c456e29048e0987af16f3bdc33c36` |
| `monsters/MonsterGroup.java` | `535770201b8aa8de01b52b185979af537f11ad0862e7d3e71ebb20cc64234221` |
| `actions/GameActionManager.java` | `a47d1ee9c6b2e194b7d3ef311328f2a15e38f5630330689e438e46685b94d6c3` |
| `actions/common/RemoveAllBlockAction.java` | `e5651117f045c32b28d6da3d3bf3ba0df320dfc06d6495c0eae155b3eee6e7f8` |
| `cards/AbstractCard.java` | `bcd472ececfd8ce4150ccd4eb6dd07a2e2dc43e139196fe00de34705cf1a2a61` |
