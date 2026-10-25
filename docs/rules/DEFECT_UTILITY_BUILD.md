# 机器人充能球以外的工具牌

本切片独立实现牌定义，不自动修改职业牌池。共享动作由 Combat/Effects 接入；模块存在不代表自然奖励、中文展示或平台实机已通过。

## 固定来源

本轮逐张读取公开社区反编译快照 [319009d5df0a82d9fb0f23cc22322286c6a87ec0](https://github.com/aeubanks/sts/tree/319009d5df0a82d9fb0f23cc22322286c6a87ec0) 中 constructor、use、upgrade，以及对应 action/power 的执行方法，独立整理事实及实现，未复制 Java 实现。该项目标注 V2.3.4 (12-18-2022)，没有取得正版 PC 二进制认证，不把社区快照表述为已经认证的原作二进制。

压缩包 `https://codeload.github.com/aeubanks/sts/zip/319009d5df0a82d9fb0f23cc22322286c6a87ec0` SHA256：`3f42bd7dde08126a9a8a02fc8eed8856c7b8b0dda551f50c62ced838e41ed458`。逐文件路径相对 `com/megacrit/cardcrawl/`。重新下载后校验压缩包，再读取各文件可复核下表。

## 牌定义

费用写为基础→升级，仅有变化时分两项；数值同理。COMMON/UNCOMMON/RARE 分别对应普通/罕见/稀有。

| 本地 ID | SourceID / 类名例外 | 稀有度 | 费用 | 基础→升级行为 |
|---|---|---|---|---|
| barrage | Barrage | common | 1 | 每个已填球普通伤害 4→6；空槽不计 |
| compile_driver | Compile Driver | common | 1 | 伤害 7→10，随后按不同球类型数抽牌 |
| go_for_the_eyes | Go for the Eyes | common | 0 | 伤害 3→4，若目标意图基础伤害≥0，再施加虚弱 1→2 |
| boot_sequence | BootSequence | uncommon | 0 | 先天；格挡 10→13；消耗 |
| charge_battery | Conserve Battery / ConserveBattery.java | common | 1 | 格挡 7→10；下次恢复能量额外+1 |
| glacier | Glacier | uncommon | 2 | 格挡 7→10，再依次生成两个冰霜 |
| overclock | Steam Power / Overclock.java | uncommon | 0 | 抽 2→3，再放一张灼伤进弃牌堆 |
| turbo | Turbo | common | 0 | 能量 +2→3，再放一张虚空进弃牌堆 |
| core_surge | Core Surge | rare | 1 | 伤害 11→15，再获得人工制品1；消耗 |
| rainbow | Rainbow | rare | 2 | 顺序闪电、冰霜、黑暗各1；基础消耗，升级不消耗 |
| hyperbeam | Hyperbeam | rare | 2 | 群伤 26→34，再失去集中3（可被人工制品挡） |
| reinforced_body | Reinforced Body | uncommon | X | 单次格挡 7→9，重复X次；按单次值分别计算敏捷/脆弱 |
| double_energy | Double Energy | uncommon | 1→0 | 将付费后的当前能量翻倍；消耗 |
| ftl | FTL | uncommon | 0 | 伤害 5→6；此前打牌数少于3→4则抽1；动作顺序见下 |

新增中文 `name/text/upgradeText` 和 `sourceId` 都是牌定义元数据；`CharacterPresentation` 仍须显式支持新动作，不能绕过未知动作拒绝保护。升级后费用由 `Combat.cardDefinition` 决定。

## 共享动作约定与队列时点

`withCards(data)` 深拷贝输入、追加14张常规牌和虚空/灼伤状态牌，并注册 `energized_blue` 中文状态。重复 ID 明确拒绝，无静默覆盖。

- `barrageDamage(value=4/6)`：动作执行时遍历已有球，向 TOP 排相应次数普通攻击。球伤害不受力量影响的规则不能套到此牌；本牌每击都受力量、虚弱、目标易伤及普通攻击反击影响。
- `compileDriverDraw(value=1)`：前一个伤害之后，动作执行时排除空槽按唯一球 ID 数量计数，抽牌动作置 TOP。不能以出牌前静态球数预览替代执行语义。
- `weakIfAttacking(value=1/2)`：伤害之后检查目标 `getIntentBaseDmg() >= 0`。零伤害攻击仍满足，单纯防御/强化不满足。
- `nextEnergy(value=1)`：获得 EnergizedBlue 状态；首次和叠层上限999。源在 `onEnergyRecharge` 直接加能量，再 BOT 排移除状态；本轮作用于下次玩家基础能量恢复后、抽牌前。
- `doubleEnergy(value=1)`：执行时加上当前能量，不是出牌前能量。基础3能量付1后变4；升级付0变6。
- `xBlock(value=7/9)`：X次独立格挡动作在源 ReinforcedBodyAction 中追加 BOTTOM；采用单个惰性 `xBlockRounds` 描述，不构造X大小数组，Host从该动作开始逐段TOP续排。消费能量在最初X动作发生，格挡在已经排队的 UseCard 之后。X采用牌动作保存的 energyOnUse，实际当前能量在执行时消费。组件接受 freeToPlayOnce 布尔和显式 energyOnUse，0X无消费；非零 Chemical X 明确拒绝。Host尚未提供的调用路径不可宣称集成支持。
- `ftlDamage(value=5/6,threshold=3/4)`：FTLAction 先 BOT 加普通伤害，若 `cardsPlayedThisTurn.size()-1 < threshold` 则 TOP 加抽1；因此**抽牌在伤害之前**，伤害可能在已经排入的 UseCard 清理之后。历史包含当前牌，由减1排除自身；计数每回合重置。
- 多次球生成使用独立 `channelOrb`，复用现有满槽唤起/死亡取消规则。临时状态牌复用 `makeTempCardInDiscard`，不是手牌生成或立刻抽牌。

`prepareEffect(state,effect,target)` 返回深拷贝 effect，捕获 Barrage/FTL 的 `normalAmount` 和X格挡的 `blockAmount`。`planEffect(state,effect,context)` 不改变state、事件或RNG；已知动作返回 `{top={effect...},bottom={effect...},consumeAllEnergy=boolean}`，未知动作返回nil，非法参数抛错。context包含目标actor `target`、此前打牌数 `cardsPlayedBefore`、X快照 `energyOnUse`、可选 `freeToPlayOnce`。Host逆序pushTop、顺序pushBottom；`xBlockRounds` 记录为 `{op='xBlockRounds',value=捕获值,remaining=X,fixed=true}`。

额外核查 EnergyPanel.addEnergy 对总能量上限999，AbstractPlayer.gainEnergy调用该路径，LoseEnergy下限0。当前共享能量operation并未统一复刻999上限；本切片不扩大修改共享能量边界，DoubleEnergy高能量上限交互是明确待接差异，不能据普通3能量测试宣称无差异。

## 虚空、灼伤与边界

虚空源是 STATUS/COMMON/COLORLESS/NONE、费用-2、`isEthereal=true`。空 use/upgrade，**没有 exhaust=true**；抽到排 LoseEnergyAction(1)，保留在手中，未离手则轮末虚无消耗。手牌已满而未实际进入手中是否触发必须由共享抽牌入口按源处理，不能将生成进弃牌堆误当抽到。

灼伤源是 STATUS/COMMON/COLORLESS/NONE、费用-2，基础2、升级4，无虚无。轮末通过卡队列触发，造成 **THORNS** 类型伤害，消耗格挡，忽略普通攻击增伤/虚弱/易伤；不是 loseHp。`burnDamage` 是本地元数据，不是可主动打出的 effect。下一轮没有自动消耗。

伤害杀死最后敌人时取消后续抽牌、集中损失、人工制品和新球生成。已排队冰霜格挡的末敌保留例外沿用既有 Orbs 规则；玩家死亡必须停止。Barrage 后续普通攻击须在反伤杀死玩家后停止。出牌中的运行时错误须回滚能量、牌堆、球及 cardRandomRng，并恢复原表引用。

## 验证状态

定向命令：`node scripts/test-lua.mjs tests/lua/defect_utility_build.lua`。

以 `/workspace/sts-triggers` 本轮共享核心为只读基线同步到私有树后，定向测试 **52组全部通过**，输出 `DEFECT_UTILITY_BUILD_PASS 52`（约2秒）。其中5组数据/schema/纯队列组件，47组真实 Combat 入口场景。最初新动作未接时曾明确红 `unsupported_effect:barrageDamage`；共享动作接入后该红已解决。没有 mock Combat，没有修改共享核心，没有运行全量检查。

测试覆盖14牌基础/升级的真实 play；充电真实 endTurn；0X和分段格挡；Barrage空槽/普通攻击反伤；CompileDriver末敌取消；GoForTheEyes零伤害攻击与非攻击、人工制品；冰川满槽；彩虹顺序/升级不耗；Hyperbeam集中损失及末敌取消；FTL先抽牌再末敌伤害及历史阈值重置；虚空抽到掉能量/虚无；灼伤轮末吃盾和升级；尾动作抛错后的整牌原引用与历史记录回滚。

新增顺序证据：普通强化机体每段格挡的事件帧均已包含被弃置的本牌且能量0；腐化强化机体先发生本牌exhaust，随后3次7格挡，最后后排无惧疼痛3格挡，共24。FTL基础第4次/升级第5次不抽，先前技能计入历史，被拒绝的invalid-target尝试不计入，下回合重置。灼伤单元场景为排除敌方伤害使用单一无伤意图循环，并先关闭Jaw Worm专用AI，避免破坏其真实AI注册意图约束；该fixture不作为Jaw Worm自然对局证据。

未验证自然奖励路线、原生 UI 完整显示、平台导入与 Windows 实机，也不把此独立 helper 测试当作 Profile 已激活或全卡池已经支持。

## 源文件指纹

| 源路径 | SHA256 |
|---|---|
| `cards/blue/Barrage.java` | `3627d631ec64c587f2b27a95a05d878a63719f6d928863ccc4e173a237ba4e2b` |
| `cards/blue/CompileDriver.java` | `0fc319452e6e4105d160436fa8bb185b950e934b694ad0318c7f5aaa1902df6b` |
| `cards/blue/GoForTheEyes.java` | `df707b2efd263307c67cb1cd5884fdaf8c1d63fee759bb1260cd9d2c44472d26` |
| `cards/blue/BootSequence.java` | `51f3d56cff80acfb4111b098041ce631e872cdfb456758deea18ea2c94bacb57` |
| `cards/blue/ConserveBattery.java` | `f355132b5d0cd2ee2658a65e0d3e1a3eeec6ca33d87e81786ea878b7f92c6ece` |
| `cards/blue/Glacier.java` | `947157738bdf8790ba19a72123d70434943142f9bbdcb27db307025ff74783f3` |
| `cards/blue/Overclock.java` | `4282d7ddaf4b332a1612113584d01883d3f292ef5eccfebba52502f7af4cb6a5` |
| `cards/blue/Turbo.java` | `ecacb175e55441fc1b4eac0b95242a854894531d378ea905de68df13120d5fe1` |
| `cards/blue/CoreSurge.java` | `3a192a177d25997205d581b905d1bac60d6a0cbb499c54928798a5627713cf27` |
| `cards/blue/Rainbow.java` | `2e5b1f48d0fa294ac36cee48ebfb08a80f742585c55260a4b52bac503b771db4` |
| `cards/blue/Hyperbeam.java` | `a0dc667cd6cba52e41407a9e7b31537529b35e30778af44eed6f13f257bdfa15` |
| `cards/blue/ReinforcedBody.java` | `5dfb7be216cbee36dede3385a6521d8b4845869832e2ff74bb439767ba293a29` |
| `cards/blue/DoubleEnergy.java` | `0930094941d467d78032b4cfa151443fb4196edb0e64b3e3a8db1ec1a1863985` |
| `cards/blue/FTL.java` | `5d54dcbcb040688b0182bb5df6af6ecffa2160330210fdbc66fd90ac6f7a617b` |
| `cards/status/VoidCard.java` | `653163beb2f36e1d48e178a87f6b5aa283adff67d957ef4f779bd3b389041e03` |
| `cards/status/Burn.java` | `a065c155ce2efb9b7a968bfe55e68d5290d02ddabcf6becd4ca43db80a30dc12` |
| `actions/defect/BarrageAction.java` | `b8a842b45ca8fee18daad81758ad218c6d337646ef80ccd2aceb74ce4f0923fe` |
| `actions/defect/CompileDriverAction.java` | `45b89b8a1d33fe39a3a56923f3690e85bac2b95a78b42c37694ef9e93ad2ab7c` |
| `actions/defect/ForTheEyesAction.java` | `a5734491da85e83ce0a235bdb0e73189baa4947207eeca98a6c4a2edba7dc1aa` |
| `actions/defect/FTLAction.java` | `79b720f12d15e35567f7e74e49a0d2df5a3857d63a95b657788792a6032ad8c4` |
| `actions/defect/ReinforcedBodyAction.java` | `6da3ab4472c38fdab52112d36ab21b4b004f8ded11a7da9497f40e56368f3a6f` |
| `actions/defect/DoubleEnergyAction.java` | `240ba4b46bbbbbde3f7f9e7d7a415303a99b3af1f631900a3ca44edf4559baaf` |
| `powers/EnergizedBluePower.java` | `2b9e5cfc9c7e3155d5059f74142b6accf4cdad28904cf21c7a23ecfbe8e181d3` |
| `ui/panels/EnergyPanel.java` | `2ac120229360f1a905704b31a903c596d95f71e97e7beb149f90135a5a03bd5a` |
| `characters/AbstractPlayer.java` | `2720ba8dd7a216781a3b2fcb709f5ec67dc9b2559af25f7f6b89df1ef0947d95` |
