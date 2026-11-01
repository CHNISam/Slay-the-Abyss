# 战士力量、自损与回合能力

本片独立新增 `abyss_warrior_strength_cards.lua`、真实Core测试与本文。固定研究源为社区反编译镜像 `aeubanks/sts@319009d5df0a82d9fb0f23cc22322286c6a87ec0`，未认证正版二进制；下方逐文件SHA-256以下载字节计算。只记录规则与独立实现，没有复制Java方法体。

## 逐卡constructor/use/upgrade核对

| 牌 | 费用/类型/稀有度 | 基础→升级与源码顺序 | 本片 |
| --- | --- | --- | --- |
| Heavy Blade 重刃 | 2/Attack/Common | 14伤；力量乘3→5，先于Weak/Vulnerable等常规乘区；负力量同样乘倍数 | 新增 |
| Perfected Strike 完美打击 | 2/Attack/Common | 6基础；hand/draw/discard中每张STRIKE标签加2→3，含使用前自身，不含exhaust/使用中牌 | 新增 |
| Bloodletting 放血 | 0/Skill/Uncommon | LoseHP(self,self,3)，然后GainEnergy2→3 | 复用已有 |
| Hemokinesis 控血 | 1/Attack/Uncommon | LoseHP(self,self,2)，然后已捕获的NORMAL伤害15→20 | 复用已有 |
| Combust 自燃 | 1/Power/Uncommon | 能力damage5→7；每次施加独立增加1点回合末自损 | 新增 |
| Rupture 撕裂 | 1/Power/Uncommon | 自己作为来源且正数HP损失时，TOP获得力量1→2；不按生命损失量乘 | 新增 |
| Brutality 残暴 | 0/Power/Rare | postDraw先额外Draw1，再LoseHP1；升级只加Innate，不改自损/抽牌数 | 新增 |
| Berserk 狂暴 | 0/Power/Rare | 先自身Vulnerable2→1，再Berserk1；从后续玩家回合开始获得能量 | 新增 |
| Spot Weakness 观察弱点 | 1/Skill/Uncommon | 专用action检查target非nil且getIntentBaseDmg>=0，再BOTTOM施加Strength3→4 | 新增 |
| Pummel 连续拳 | 1/Attack/Uncommon | 2伤×4→5，消耗；前N−1次PummelDamageAction，最后一次DamageAction；每次都是NORMAL | 新增 |
| Power Through 硬撑 | 1/Skill/Uncommon | **先**MakeTempCardInHand(Wound,2)，再Block15→20；满手仅溢出部分进弃牌堆 | 新增 |
| Uppercut 上勾拳 | 2/Attack/Uncommon | NORMAL伤害13，再Weak1→2，再Vulnerable1→2 | 复用已有 |
| Seeing Red 眼红 | 1→0/Skill/Uncommon | GainEnergy2，消耗；升级改费而非获得3能量 | 复用已有 |
| Disarm 缴械 | 1/Skill/Uncommon | 对敌ApplyStrength−2→−3，消耗；受Artifact抵挡 | 复用已有 |
| Bludgeon 重击 | 3/Attack/Rare | NORMAL伤害32→42 | 复用已有 |

`withCards(data)`深拷贝，不重复添加六张已有牌；追加九张候选牌、Wound状态牌（缺失时）与四种能力。marker为experimentalWarriorStrength。新增构筑牌color=red、experimental=true，不修改默认JSON或自动开放角色。Wound是cost−2、无固有消耗/虚无的Status；不能拿Dazed代替，也不能把所有Wound直接放discard。

STRIKE按标签判断，不能匹配英文或中文名字。已逐一审计的现有strike、twin_strike、pommel_strike在独立数据副本补sourceTags={'STRIKE'}；新Perfected Strike也有此标签。其他角色/未来候选的标签需其模块提供明确sourceTags，本片不凭名称猜测。

## 动态伤害与快照契约

`adaptDefinition(state,instance,copiedDefinition)`只接收已经合并升级的独立副本，每次从catalog原定义重新适配，不能对已适配结果二次累加。

- Heavy Blade把 `(倍数−1)×当前有符号Strength` 加到基础伤害，再让公共NORMAL管线照常加一次Strength并处理Weak/Vulnerable/姿态。它不修改玩家Strength状态，不把结果伪装成fixed伤害。
- Perfected Strike在使用牌尚未移出hand时计算三堆标签总数，并把count×2/3加到基础。移出手牌后不能再实时重算而漏掉自身；Source不扫描exhaust或cardInUse。
- Hemokinesis的伤害在use之前已经计算。LoseHP触发Rupture，Strength虽TOP在本次攻击前兑现，也**不能**增大这一张Hemokinesis已经捕获的伤害。后续出牌才用新Strength。
- Pummel所有DamageInfo在use时取相同已计算伤害。中途Angry/Thorns/姿态等仍走NORMAL反应，但不能每hit根据后来Strength/Weak/Vulnerable重新算矩阵；最后一击与PummelDamageAction的视觉等待差异不影响数值规则。

Core须在cardPreview和真实play的同一入口调用adapter，并在detach前捕获相关NORMAL伤害；本模块不覆写公共Combat/Actor。

## Rupture的精确生命损失回调

RupturePower.wasHPLost只有两个条件：`damageAmount>0`，并且 `DamageInfo.owner == power.owner`。没有读取“来自卡牌”的标记或当前正在使用的牌。因此Bloodletting、Hemokinesis、Brutality、Combust、自损Regret均可触发；敌人伤害、owner为敌人的Thorns、owner=null的伤害不能触发。不能把同一自损量3误算成触发3次。

AbstractPlayer.damage在完成onLoseHp修正后、扣除currentHealth之前调用wasHPLost；传入的是该阶段damageAmount，而不是过杀截断后的lastDamageTaken。Rupture向TOP排ApplyStrength。若当前自损致死，这个动作虽曾被创建，死亡屏幕会阻止其执行；不能在扣血方法里立即加Strength并因此让死人先吃到buff。

新增 `planHpLost(state,owner,damageAmount) -> {top,bottom}` 只产生纯数据TOP Strength计划。owner传真实actor引用；所有队列记录仍只有纯字符串/数值/表，不把引用参数变成回调存进state。Core在**所有**玩家HP损失入口带上来源信息，并在当前伤害action完成后执行计划。不能仅在卡牌loseHp op内侦测，也不能把HP_LOSS类型等同于self owner。

## 三种回合能力的计划

`applyPower(state,id,value)`调用真实Actor.applyPower。Combust另保存 `state.player.combustHpLoss`：首次1，每次同名施加再+1；damage强度照常加5/7。每回合叠加两份5和7意味着自损2、伤害12，不是只自损1或自损12。调用方仍拥有事务与能力获得顺序。

`planHook(state,id,phase) -> {top={},bottom={}}`：

| 能力 | source hook / phase | 排入BOTTOM的纯数据动作 |
| --- | --- | --- |
| Berserk | atStartOfTurn / turn_start | energy(能力总量) |
| Brutality | atStartOfTurnPostDraw / turn_start_post_draw | draw(总量)，然后loseHp(总量，self owner) |
| Combust | atEndOfTurn / turn_end | 怪物未全死时，loseHp(combustHpLoss,self owner)，然后combustDamage(总伤害) |

Combust后段是nullOwner的THORNS类型DamageAll，使用 `DamageInfo.createDamageMatrix(amount,true)`：不经过常规攻击修正，不触发NORMAL Thorns/CurlUp，不把Rupture新获得力量加进伤害。自损先于群伤；自损致死必须停止后段。源码Combust.atEndOfTurn没有单独检查isPlayer参数，但拥有者在本片仅玩家。

Brutality的真实action顺序是**抽牌在先，扣血在后**，与常见自然语言描述顺序可能不同；NoDraw或满手只取消额外抽牌，不取消后续自损。升级只是固有。阶段入口和不同能力之间的获取顺序由Core统一调度，不能按statusId字母排序代替源码Power列表。

专用效果ABI：gainStrengthPower(status,value)、spotWeakness(value)、makeTempCardInHand(card='wound',value=2)，以及内部combustDamage。Berserk的selfVulnerable用普通gainStatus，Artifact可抵挡它而不抵挡随后Berserk能力。Spot Weakness需要活目标的canPlay预检，意图判定含0伤攻击；不能只检测kind字符串，更不能看目标有无Vulnerable。

### Power优先级、阶段与获得顺序

Metallicize、Combust、Berserk、Brutality、DemonForm五种Power的constructor均没有改写priority，继承AbstractPower的priority=5。ApplyPowerAction对首次加入的Power调用稳定Collections.sort；AbstractPower.compareTo只返回priority之差，因此同优先级保留第一次获得的顺序，叠加不重排。不能按ID字母排序，也不能固定先执行DemonForm。Rupture的isPostActionPower=true不等于设了另一priority。

| Power | 源码hook | 与其他阶段的关系 |
| --- | --- | --- |
| Metallicize | atEndOfTurnPreEndTurnCards | 在回合末自动牌及Combust的atEndOfTurn阶段之前，获得顺序不使它晚于Combust |
| Combust | atEndOfTurn | 在其当前阶段按Power顺序排LoseHP→pure Damage；自损触发的Rupture是TOP，插在其群伤之前 |
| Berserk | atStartOfTurn | 在正常Draw及postDraw能力之前排能量，不能被后续energy reset覆盖 |
| Brutality | atStartOfTurnPostDraw | 与DemonForm同阶段按获得顺序排Draw→LoseHP |
| DemonForm | atStartOfTurnPostDraw | 与Brutality同阶段按获得顺序排Strength |

例如DemonForm先获得、Brutality后获得，则postDraw队列为Strength→Draw→LoseHP；反过来则Draw→LoseHP→Strength。hp=1时，后一种次序的致死Brutality必须阻止还未执行的DemonForm Strength，而前一种已经生效的Strength应保留。这是具有实际差异的获取序回归，不能只比较两能力最终可交换的数值之和。

## 当前验证证据

`tests/lua/warrior_strength_build.lua`先执行组件，再执行真实Combat出牌；没有替换生产规则模块。

- 组件6组通过：独立追加与复用、Heavy Blade正负Strength与乘区、Perfected Strike三堆与标签、Combust双计数、Rupture来源门槛、Brutality/Berserk阶段计划和纯数据Queue。
- 复用的六张牌真实基础/升级出牌均通过。
- 首轮尚未接动态adapter时，第13组真实Heavy Blade预览失败：17不等于23。这是接入前的历史红例。
- 随后单向同步sts-triggers核心，组件与真实出牌第1–20组通过，包含伤害adapter、手牌Wound/满手溢出、Spot Weakness、Rupture与Hemokinesis已捕获伤害。第21组Combust回合末尚未接hook，当前HP80而预期78，整文件exit1；不修改源码预期来迁就未接线行为。
- 追加5组真实phase/获取序回归，目前全文件计划30组：Brutality/DemonForm两种获取序下的致死窗口、Metallicize/Combust两种获取序但阶段固定先盾、Berserk能量先于Brutality扣血。待公共阶段接线后整体重跑，不能预先标记30组通过。

后续真实回归包括伤口进手与满手溢出、Spot Weakness切换攻击意图、Rupture×Bloodletting/Hemokinesis/Combust、Brutality抽后扣血、Berserk次回合能量与Artifact、致死自损停止能量/力量/群伤且保留使用牌。所有候选升级数值来自上表固定源码，不能为变绿改成当前错误行为。

没有运行fullsuite、提交推送、平台导入或实机验证。Wound处理、所有回合Power顺序、HP-loss来源与NORMAL快照需root完成共享接线后才可认定运行可用。

## 固定来源SHA-256

| 固定来源 | SHA-256 |
| --- | --- |
| [actions/common/ApplyPowerAction.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/actions/common/ApplyPowerAction.java) | `f64ce8511f961a1990f1909e2c55654fa6dbf1dc2f4f1f3d3a7156c2ec2a9d47` |
| [actions/common/DamageAction.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/actions/common/DamageAction.java) | `c5649fc04cbcadffa617e5c52f1a6f879f88cb1a90a543d5a0a05ebf950578ec` |
| [actions/common/LoseHPAction.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/actions/common/LoseHPAction.java) | `50c9ea9f1aef4a02ff9177d59517f61b03941e9770a23bc50bed8e3d60d69670` |
| [actions/common/MakeTempCardInHandAction.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/actions/common/MakeTempCardInHandAction.java) | `b089bb6fd688ffdd48ae9def57751f972429cad63f85ec80ee3f90593d5bbe25` |
| [actions/common/PummelDamageAction.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/actions/common/PummelDamageAction.java) | `4acf744c3beb8854595fc39f89e157b8908955986c3992cad1b3ec89d251ec2a` |
| [actions/unique/SpotWeaknessAction.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/actions/unique/SpotWeaknessAction.java) | `7c988e56c8af631a5d1478a6f2091793f12681b213c658efe3302bb1ad7ecfab` |
| [cards/DamageInfo.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/cards/DamageInfo.java) | `cc16469d78473a1d37bf18a152014d9d1625859a5a7bd0923387f4ee8d942a5a` |
| [cards/red/Berserk.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/cards/red/Berserk.java) | `b82a9072d3b8c03fddb503cd5f665f0c7f0a96cf096e69b2547c7c72f3993153` |
| [cards/red/Bloodletting.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/cards/red/Bloodletting.java) | `8af1b938ea918e3d2c8cc99d104b8259ae71c310cc6534a583269523915b485e` |
| [cards/red/Bludgeon.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/cards/red/Bludgeon.java) | `c056710affefba665c41a77dd95b8ec937632b5026a55374a5077676bd5a1915` |
| [cards/red/Brutality.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/cards/red/Brutality.java) | `64cdd6916a38ef38a118bd928654a36ce006273883c9579764385d0c40814270` |
| [cards/red/Combust.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/cards/red/Combust.java) | `10dc8f46a4e3685c06f69f4155893d5ce5b116ef35fb60bc0a7180692c597e86` |
| [cards/red/Disarm.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/cards/red/Disarm.java) | `671450a8945fea404bd2a37c3f31c0b41f048e2c3ac887dd810fff41139d3545` |
| [cards/red/HeavyBlade.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/cards/red/HeavyBlade.java) | `1766205c2af02008a6899a5020094b8190efd8975c7e4621745d45494a46a5dd` |
| [cards/red/Hemokinesis.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/cards/red/Hemokinesis.java) | `28729f7bc1e2d48d7cbdc45336126a93d454d9350d8c2f17eef42c5d6349b6c7` |
| [cards/red/PerfectedStrike.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/cards/red/PerfectedStrike.java) | `d17c8faddcd205d2ac1bbbbca120d1ca4b09ee705d0bd9643a6c28642ee2819d` |
| [cards/red/PommelStrike.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/cards/red/PommelStrike.java) | `5317b772701a863ae0a6c263e49543be3cf2878d0e9ab71de4cfb5bce3024292` |
| [cards/red/PowerThrough.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/cards/red/PowerThrough.java) | `127572d1e82ee84127e82a81039840c33a7e291851e028d2323bbf3193fd02c5` |
| [cards/red/Pummel.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/cards/red/Pummel.java) | `f1517fa1f3a79bde87806915e2bbeba0a0225acef6aa2c598431a90de995e61d` |
| [cards/red/Rupture.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/cards/red/Rupture.java) | `661b30952923b5c512fa8715e37d5e4306d7632f689f0f4bcd4efd71b7d5403b` |
| [cards/red/SeeingRed.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/cards/red/SeeingRed.java) | `9724bcc4482ff84a8f996ab7be8c27c584ff82902e89c6acd4309824c64b4463` |
| [cards/red/SpotWeakness.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/cards/red/SpotWeakness.java) | `5eda16a355a7087e86f7469314676031edd8845386b85182fc25245fa49e539a` |
| [cards/red/Strike_Red.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/cards/red/Strike_Red.java) | `e419fefb5b1bcc34175570fbafb8b68cc2a014ec4e7d974674586057dd22d37b` |
| [cards/red/TwinStrike.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/cards/red/TwinStrike.java) | `6b24b7ebd2752cc24c1a81aa1971b9a15a9ae5648fc049cfa17b746f330813ac` |
| [cards/red/Uppercut.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/cards/red/Uppercut.java) | `e38038424de7d590dad3a02b004e1c1d3893ff1d4aef8f23bd70f3496a9c0fc0` |
| [cards/status/Wound.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/cards/status/Wound.java) | `0ed169278ebdbf8364ac2411968654e15f14d3f1754598274509ab15c8e2f1ec` |
| [characters/AbstractPlayer.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/characters/AbstractPlayer.java) | `2720ba8dd7a216781a3b2fcb709f5ec67dc9b2559af25f7f6b89df1ef0947d95` |
| [powers/AbstractPower.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/powers/AbstractPower.java) | `37a6e97bc1a7a3d0cbfe93fd07e9f809690f7c02f24fd45ec34892466b6e0f9f` |
| [powers/BerserkPower.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/powers/BerserkPower.java) | `01ba3b8328aa0b0586267dc1103c0125f5878088467f4960828acd1e0571f1d8` |
| [powers/BrutalityPower.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/powers/BrutalityPower.java) | `8a0021cd149d8ed520ed3cc4a52ae06932775b7591ab687ac26aa32edff35c48` |
| [powers/CombustPower.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/powers/CombustPower.java) | `83204dd6f5f2fdbc8100c6288885dabd733c2cb225069bbd4b7ff4c3d53114ca` |
| [powers/DemonFormPower.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/powers/DemonFormPower.java) | `f33afd9cca41bba6824f42115b4b0110ed9856cf2ce825f4bc57461151d8ee65` |
| [powers/MetallicizePower.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/powers/MetallicizePower.java) | `6f35d8908bde5eb6f470845d27dd6e739fe76fb7c3c5d6d83ff48d7864c9e30f` |
| [powers/RupturePower.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/powers/RupturePower.java) | `0c8cb85d7c71cee10603f4d10bba6d5e26bca44858cf4f0b6b50757cc64151e8` |
| [powers/StrengthPower.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/powers/StrengthPower.java) | `20b05040efe9d6ad693dd763a658c86df9db1b1ac365351c4c8d81c7f6ca08c9` |
