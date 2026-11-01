# 猎人战术牌与动作队列切片

独立卡定义与纯动作计划；共享Combat负责真正执行、选择暂停、触发、原引用事务和胜负清理。没有建立第二套战斗状态机。本批20张均未在原基础/前一批定义中注册。中文name为项目可读标签，不声称已认证原版简体中文文本。

## 固定来源

公开社区反编译镜像 [aeubanks/sts@319009d5df0a82d9fb0f23cc22322286c6a87ec0](https://github.com/aeubanks/sts/tree/319009d5df0a82d9fb0f23cc22322286c6a87ec0)，声明 V2.3.4 / 2022-12-18。非官方源码，非已认证PC二进制；只核规则事实并独立实现，不复制方法体。下方SHA-256对应固定源文件原字节；zip缓存提交注释亦为此SHA。

## 数值与顺序

| source class | 稀有度 | 费用 | 基础 → 升级 | 执行顺序与标记 |
|---|---|---|---|---|
| PiercingWail | common | 1 | -6 → -8力量 | 全敌先全部降低力量，再全部排恢复Power；消耗 |
| AllOutAttack | uncommon | 1 | 10 → 14伤害 | 全体攻击后随机弃1；算手动弃牌 |
| Blur | uncommon | 1 | 5 → 8格挡 | 格挡后Blur1；升级不改层数 |
| Choke | uncommon | 2 | 12伤害；3 → 5失去生命 | 先伤害，再Choked；后续出牌触发 |
| Concentrate | uncommon | 0 | 弃3 → 弃2 | 选择结束后获得2能量；手不足自动全弃 |
| CripplingPoison | uncommon | 2 | 4 → 7毒 | 逐敌先毒再Weak2；消耗 |
| Dash | uncommon | 2 | 10 → 13格挡及伤害 | 格挡先于伤害 |
| EscapePlan | uncommon | 0 | 条件格挡3 → 5 | 抽1；实际抽到Skill时固定格挡 |
| Expertise | uncommon | 1 | 手牌补至6 → 7 | action执行时读手牌数；使用牌已离手 |
| Finisher | uncommon | 1 | 每次6 → 8伤害 | action执行时读本回合攻击历史，减自身 |
| Flechettes | uncommon | 1 | 每次4 → 6伤害 | action执行时读手中Skill数量；不能打的Skill亦计 |
| LegSweep | uncommon | 2 | Weak2/格挡11 → Weak3/格挡14 | 先Weak，再格挡 |
| Predator | uncommon | 2 | 15 → 20伤害 | 再加下回合抽2；升级不加抽牌量 |
| Skewer | uncommon | X | 每次7 → 10伤害 | X次NORMAL；新增伤害排BOTTOM |
| Terror | uncommon | 1 → 0 | Vulnerable99 | 消耗 |
| DieDieDie | rare | 1 | 13 → 17全体伤害 | 消耗 |
| GlassKnife | rare | 1 | 每次8 → 12伤害 | 连击2次后，自己此战基础伤害减2，下限0 |
| Malaise | rare | X | X → X+1 | 永久降力量后Weak相同量；消耗；动作BOTTOM |
| Unload | rare | 1 | 14 → 18伤害 | 再弃所有非Attack牌；每张是真手动弃牌 |
| StormOfSteel | rare | 1 | 弃手牌并生成普通 → 升级Shiv | 不消耗；生成数在动作执行时冻结 |

## 动作ABI与共享接入

`withCardDefinitions(data)`拷贝并注册，重复card id拒绝；`M.ops`仅列13个公开新op。所有状态存于真实Actor，牌实例/piles存于真实Combat。

`prepareEffect(state,effect,target)`在原牌use/建动作时调用：冻结Finisher/Flechettes/Skewer/GlassKnife的NORMAL伤害（Strength/Weak/Vulnerable/stance），冻结EscapePlan已经Dex/Frail修改的格挡。PiercingWail此时记录每个活敌id与是否无Artifact；原use有两次遍历，先为所有敌人排力量降低，再为满足条件的敌人排恢复，不能交错。不能推迟到失去力量已消耗Artifact之后再判恢复。

`planEffect(state,effect,context)`不修改状态、队列或RNG，返回`{top={},bottom={},consumeAllEnergy=false}`。数组为**执行顺序**；host逆序pushTop、顺序pushBottom。context可携带call-local `cardDefinition(state,instance)`，不保存函数进state。context还含target、instance、energyOnUse、freeToPlayOnce；Chemical X必须明确拒绝，不能静默忽略。所有effect纯数据，可包含targetId，host需把作用目标设为该Actor。`normalAmount`是NORMAL伤害快照，不是无视格挡/力量的特殊伤害。

- `concentrateDiscard`生成TOP `requestDiscard(N),energy(2)`。新牌自身只公开专用op，不能放宽旧卡公开requestDiscard必须尾置的校验；内部typedplan允许中途选择。真实pending/token验证成功后继续原队列。选择失败不动任何实例/引用；Tactician TOP插入获得能量动作之前，Reflex BOTTOM仍保留其原队尾。
- `stormOfSteel`执行时冻结手牌N，TOP `requestDiscard(N),generateShivs(N,upgraded)`。DiscardAction在手牌<=N时从hand尾连续自动全弃，不开虚假选择。Tactician TOP先结算，Shiv在Reflex BOTTOM抽牌之前生成；满手后Reflex只能补到10。Shiv使用真实生成器，保持Accuracy stamp、升级加2和UID安全；没有另造临时牌引擎。
- `allOutDiscard`TOP `randomManualDiscard(1)`。host执行该action时调用`randomDiscardUid(state)`：空手返回nil；单张自动全弃不调用RNG；至少2张恰好调用cardRandomRng.randomInt(size-1)一次。随后走真实手动弃牌入口。不得在prepare或纯plan时提前消耗随机流。
- `unload`读取当时hand非Attack（含Skill/Power/Status/Curse），TOP按hand尾至头列`discardSpecific(uid,incrementFirst=true)`。源forEach加TOP会逆序。每张先incrementDiscard(false)，后triggerOnManualDiscard；这与普通DiscardAction先trigger再increment不同。后者现有模块不能无声套用前者，host需支持明确顺序参数。已不在hand的指定牌跳过。
- `escapePlan`TOP `drawWithFollowup(1,blockAmount,skillOnly=true)`。必须依据**本次DrawCardAction实际drawnCards**，不能比较hand差集、继承上次抽牌记录或看到手牌有Skill就算。NoDraw、满手、空抽牌/弃牌堆亦执行followup但列表为空，不给格挡；洗牌拆分仍属于同一次draw历史。Skill实际入手后才将冻结blockAmount作为fixedBlock执行，避免再算Dex/Frail。
- `expertise`执行时用max(0,N-handSize)发TOP draw，遵守NoDraw与满手限制。
- `finisherDamage`执行时读cardsPlayedThisTurn中Attack个数再减1（当前Finisher已入历史），`flechettesDamage`执行时读手牌Skill。它们的命中量在prepare已冻结，多次TOP逐次NORMAL伤害，保留Thorns/Angry/Envenom等真实触发。
- `skewer`X取energyOnUse，-1/nil才读当前energy；>0时BOTTOM `skewerHits(value,normalAmount,remaining)`，非free清空当前剩余能量。host逐次循环action，不能一次乘法合并。原source Chemical X+2尚未支持，不伪造完整遗物兼容。
- `malaise`同X快照，升级+1；>0时BOTTOM Strength(-N)、Weak(N)，非free消耗所有当前energy。两次独立ApplyPower：Artifact1只挡Strength，Weak仍能生效；基础0X不创建任何power，升级0X有各1。合法999能量升级后effect1000：Strength最终cap±999，Weak仍1000；已有Strength500叠raw-1000应-500，不能将原raw stackAmount先截999。
- `glassKnife`TOP两次NORMAL伤害，然后`reduceGlassKnife(2,uid)`；需context.instance为真实用牌实例。`reduceGlassKnife`覆盖cardInUse、limbo、四堆内同UID实例且同对象去重，字段`glassKnifeReduction`只保存本牌损耗。`adaptDefinition`在upgrade后、通用bonus前用它减少base，下限0；不能重复累计。损耗cap当时基础8/12，保留基础耗至0后升级+4的含义。不同UID不受影响。跨战斗Run deck不继承该字段。特殊复制共UUID、其他永久改baseDamage机制未宣称完整兼容。

## Power时序

`planHook(state,id,hook,owner)`返回普通effect数组，host按本来的队列位置加入；`planChokeOnUse(state)`返回纯BOTTOM effects。

- `choked`是Artifact可阻止的DEBUFF。UseCardAction构造时遍历敌人onUseCard并把LoseHP(null source)加BOTTOM，因当前Choke的ApplyPower尚未执行，不触发自己；已有Choke会触发再次打Choke。LoseHP无视格挡、不触发攻击伤害/Envenom/Thorns。在敌人atStartOfTurn移除（owner_turn_start），不是玩家开局移除。LoseHP后敌人死亡遵循原host清理。
- `shackled`（原ID Shackled/GainStrengthPower）也是DEBUFF；apply/stack各-999..999截断，独立Artifact可挡。owner_turn_end排恢复Strength(+层数)及移除，不能按玩家回合末提前恢复。PiercingWail建动作时有Artifact则根本不创建恢复，即使失去力量后来消耗掉Artifact也不恢复。
- `blur`叠层，每round_end减1，最后1层移除。原GameActionManager先让MonsterGroup排Blur减层action，再同步检查hasPower(Blur)保留Block，后面的action才真的减/移除。host必须先冻结本次保留判断，不能同步移除再检查；检查存在性，不是>0。不能挡住本回合敌方攻击耗掉的格挡。
- `draw_next_turn`定义显式`priority=20`，对应原DrawCardNextTurnPower，atStartOfTurnPostDraw排Draw(N)再Remove；与Fumes等普通priority5的源排序有关。不是改常规drawPerTurn，也不是当前回合立刻补牌。NoDraw阻止draw但仍移除该power。

## 验证与范围

定向命令：`node scripts/test-lua.mjs tests/lua/silent_tactics_build.lua`。首轮旧core诚实结果：首批52例14/52通过，38例红，主要`unsupported_effect:<new op>`以及未接Power生命周期；没有mock或临时猴子补丁把拒绝改为成功。构造单元夹具可设定牌堆与耐久目标，只用于机制断言，不属于自然Run/Map/原版概率或平台实机证据。新共享接入后须逐例实际出牌并补齐真实选择/事务/回合测试，未通过前不能声称20卡可玩。

测试目前包含基础/升级真实费用/伤害/生命周期、Artifact、NoDraw、手牌不足、空X、Tactician/Reflex、Storm满手与Accuracy、异常随机流原引用回滚；独立纯plan例与真实Combat例分开标明。未跑全量套件，未提交/推送。

## 源文件字节摘要

| 固定源文件 | SHA-256 |
|---|---|
| [actions/GameActionManager.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/actions/GameActionManager.java) | `a47d1ee9c6b2e194b7d3ef311328f2a15e38f5630330689e438e46685b94d6c3` |
| [actions/common/ApplyPowerAction.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/actions/common/ApplyPowerAction.java) | `f64ce8511f961a1990f1909e2c55654fa6dbf1dc2f4f1f3d3a7156c2ec2a9d47` |
| [actions/common/DiscardAction.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/actions/common/DiscardAction.java) | `8c711be291822386b64fe0a6c9bc55b920b7a09122fb55f09184b6ca96063c10` |
| [actions/common/DiscardAtEndOfTurnAction.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/actions/common/DiscardAtEndOfTurnAction.java) | `d80e3ae091de4bc4e74879f195b5ec2d1bb7e7c7e92eac636bf452d61e4bebf0` |
| [actions/common/DiscardSpecificCardAction.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/actions/common/DiscardSpecificCardAction.java) | `f6911920aec29ae720d4a73fa5320dcf3e314a31103aa1ba56499da763af5335` |
| [actions/common/DrawCardAction.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/actions/common/DrawCardAction.java) | `67d02ba84c1d7e60fbb2a4a83f2b2d3ebbd81a84d29c16ccb98ecc9dd1a17e18` |
| [actions/common/ModifyDamageAction.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/actions/common/ModifyDamageAction.java) | `dc031490874c3f33dc34291283df57e6fed15fab5f38a3e5a76bd9c173a8085f` |
| [actions/common/ReducePowerAction.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/actions/common/ReducePowerAction.java) | `c38b05e84a781f97d4f87fa8bf374ef145a7c72137e16f8a388f7a612f9425a8` |
| [actions/unique/BladeFuryAction.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/actions/unique/BladeFuryAction.java) | `6593db02be176f93b9cbd4585ec210391c0b6daac9970cb9216da8b374ad3061` |
| [actions/unique/DamagePerAttackPlayedAction.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/actions/unique/DamagePerAttackPlayedAction.java) | `65c4b470aa4e45bb8db8ca5c56b3ebe45cf826309c77a6fb09c1798255657245` |
| [actions/unique/EscapePlanAction.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/actions/unique/EscapePlanAction.java) | `fffc66a2e1b700a6ee30d52e3d0c52a519856d96d0ecf37f2e98e6c75fe3294f` |
| [actions/unique/ExpertiseAction.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/actions/unique/ExpertiseAction.java) | `94569a706f2df629630c22626fb142ab2f3d7c828cc982201ed96256733fa879` |
| [actions/unique/FlechetteAction.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/actions/unique/FlechetteAction.java) | `a23ddc4092aae1d031c24e7596e2f92ba9ea7be9257f5f75c492a23f3836ee62` |
| [actions/unique/MalaiseAction.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/actions/unique/MalaiseAction.java) | `f130500f4a7ac8b574f16332897c4b8863332820c0eb4ec135c8f58efdcb617f` |
| [actions/unique/SkewerAction.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/actions/unique/SkewerAction.java) | `405f39d9e54a90beddb3559a2db3548b21b2526aacb0eddf8e4ad645dba86501` |
| [actions/unique/UnloadAction.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/actions/unique/UnloadAction.java) | `fa4498f08a222e0b3ebabd39ce7fbe2acdd79fe95331947e13775fea088161a2` |
| [actions/utility/DiscardToHandAction.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/actions/utility/DiscardToHandAction.java) | `b0747e280d603d8748cdaf30c91402017991a89d4039d254e940f63529a01adf` |
| [actions/utility/ScryAction.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/actions/utility/ScryAction.java) | `a22d8875a9ac3a4b6c445abad65a6ca4defa8fb309d1f6a6e51506a8e3b55147` |
| [actions/utility/UseCardAction.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/actions/utility/UseCardAction.java) | `90213939af6d7ec83dea01bb2feef4ba762a93400dc1535732e2eebcdb6cab0f` |
| [cards/AbstractCard.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/cards/AbstractCard.java) | `bcd472ececfd8ce4150ccd4eb6dd07a2e2dc43e139196fe00de34705cf1a2a61` |
| [cards/CardGroup.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/cards/CardGroup.java) | `03de4e22ab22bedf1d90df72bdc83f033ff6aa776ad9d8f7259e1ee9293f7fa8` |
| [cards/green/AllOutAttack.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/cards/green/AllOutAttack.java) | `873887ce9bb0864ccb5a450692f7e31efcf76fea78309e20e34ea761e1ab92f7` |
| [cards/green/Blur.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/cards/green/Blur.java) | `aeaa5a83c079f1e9724c4f868d9ad363b3b5f99f47734f9f3f412d829254357b` |
| [cards/green/Choke.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/cards/green/Choke.java) | `7eb777f9b42c2f2f0caea5ca6292b9d32e49da764668382040a442b8bb77d06b` |
| [cards/green/Concentrate.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/cards/green/Concentrate.java) | `2944a2d1819ce175859b36a5a1855f999b18379d850e45ed199ba2073107a950` |
| [cards/green/CripplingPoison.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/cards/green/CripplingPoison.java) | `259e92705fec47cdc644308a63c82d88468b501c9a2bd872e53629b26ec817a1` |
| [cards/green/Dash.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/cards/green/Dash.java) | `449afdb38000f155d5cca2e92b5ae1eafe7ca43133c3162bf4e880340d94158e` |
| [cards/green/DieDieDie.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/cards/green/DieDieDie.java) | `c74f8894af985aa18014c7a80aa5ca307ffabd7cc03a4c7d549e4fe9042442ba` |
| [cards/green/EscapePlan.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/cards/green/EscapePlan.java) | `a69b2f9f630297e10fc2f9e6ef6f8b45acf44d5abb87845f94f5e8fb9abf1ebd` |
| [cards/green/Expertise.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/cards/green/Expertise.java) | `a0ba23abdc76d920e9cd2c02f6ed68500184b3cf61497fffb6fec462be387c0b` |
| [cards/green/Finisher.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/cards/green/Finisher.java) | `004e882e04ac36ad39663904a22a87af19a5a2e5ae46ef71b31c4a996e2b8d47` |
| [cards/green/Flechettes.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/cards/green/Flechettes.java) | `11ae9e5e875416912ccba3b00d993b44cf49da8f8b6a7f7445c117b7855088a8` |
| [cards/green/GlassKnife.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/cards/green/GlassKnife.java) | `f7828b6b2f3ee1875fe917da86980d9c0cfa9276ea8f83e28c907299d8393b91` |
| [cards/green/LegSweep.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/cards/green/LegSweep.java) | `05ce2a9a5517dcc99c30ed853b9f46248e77daabb4f12dcef69dcea6a90d87f3` |
| [cards/green/Malaise.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/cards/green/Malaise.java) | `b2a16209d5f64dd3bdf44b217a396ea88f19cbd818809c35637e286327d0ef41` |
| [cards/green/PiercingWail.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/cards/green/PiercingWail.java) | `3787b95d6557aea38a728fef0d02ff6fcdfd5ef23cf46007df29fc39b46cfa1f` |
| [cards/green/Predator.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/cards/green/Predator.java) | `67bb24be13d218ee4f09016a5fb078dc424a034befdefd7de125bf58949252f7` |
| [cards/green/Skewer.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/cards/green/Skewer.java) | `fa27444260699440c3ba6d1263a0411e3be8ce9b23d6aa6efb4e365da74bf8bc` |
| [cards/green/StormOfSteel.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/cards/green/StormOfSteel.java) | `4ceb8f93158f6938f92e03dd2c0027577546a2f30bb2900ffa6ecc0028da4467` |
| [cards/green/Terror.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/cards/green/Terror.java) | `852d0bc60770330dd4f237ed45f91433d0bd940ffe3136df05d392383f645dcc` |
| [cards/green/Unload.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/cards/green/Unload.java) | `985aa6c26f5c1ac987d77196cbbbb8c777c33510433a46452e6b2579a07a4f8c` |
| [characters/AbstractPlayer.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/characters/AbstractPlayer.java) | `2720ba8dd7a216781a3b2fcb709f5ec67dc9b2559af25f7f6b89df1ef0947d95` |
| [core/AbstractCreature.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/core/AbstractCreature.java) | `3db6e08c6bd033192aa368e29ad53f4614194898ccf0f525480fe20cb8799f2b` |
| [helpers/GetAllInBattleInstances.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/helpers/GetAllInBattleInstances.java) | `056231bdf229b7b32ba5d62cf722c04155acd521206e6a5be72df7a03f791213` |
| [monsters/MonsterGroup.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/monsters/MonsterGroup.java) | `535770201b8aa8de01b52b185979af537f11ad0862e7d3e71ebb20cc64234221` |
| [powers/BlurPower.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/powers/BlurPower.java) | `63605da52ce9df2a5c89b209cdc9a7cc38f3fc32a373072b8008a5feb30e5efb` |
| [powers/ChokePower.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/powers/ChokePower.java) | `e5562a249ab3e44ad11e5d4bb02090f37d85881f9993c8dd1b1fc01859b4d9c7` |
| [powers/DrawCardNextTurnPower.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/powers/DrawCardNextTurnPower.java) | `7f43052db3e11d82b83b24753cac3eedd81a162eedf20465288a16bda2118407` |
| [powers/GainStrengthPower.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/powers/GainStrengthPower.java) | `06258d050cb0120eee8812124f59f59c1e541ac705781c8c73b82501632e1799` |
| [powers/StrengthPower.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/powers/StrengthPower.java) | `20b05040efe9d6ad693dd763a658c86df9db1b1ac365351c4c8d81c7f6ca08c9` |
