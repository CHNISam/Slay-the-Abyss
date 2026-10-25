# 初代四职业完整卡牌覆盖账本

审计输入：2026-10-25 `/workspace/sts-flow` 当前 phase4＋检索实验Profile开发快照，基于远端 `877c4af`；并非该commit本身已含238张。本轮仅只读导出并复算Capability，不运行全量、不改runtime。当前树专项与旧165冻结树完整检查分别记录，不能互相冒充。未接入Profile的phase5/ClassFinal候选不计入覆盖。

## 来源与验证

固定社区反编译来源 [aeubanks/sts@319009d5df0a82d9fb0f23cc22322286c6a87ec0](https://github.com/aeubanks/sts/tree/319009d5df0a82d9fb0f23cc22322286c6a87ec0)，版本字段 `[V2.3.4] (12-18-2022)`。未经正版PC二进制认证，不能称官方开源或原版实测。

沿用锁定的370条注册元数据；本轮从本地固定ZIP重新读取并核验全部370个逐卡文件SHA256、CardLibrary SHA256与ZIP SHA256，保留源300张职业母表。导出通过Fengari加载当前同树模块，基本/升级两版均实际调用Capability；仅解析元数据与行为事实，不复制Java实现。

- 源ZIP SHA256：`3f42bd7dde08126a9a8a02fc8eed8856c7b8b0dda551f50c62ced838e41ed458`。
- CardLibrary.java SHA256：`ac123d5376862fb1d1d382284e14a9dc0e955395f415265ae29f9aa8a2b6237a`。
- 完整逐卡 sourcePath、SHA256、注册序号与直接衍生依赖：`data/reference/sts1-card-pools/registration.json`。
- 导出前后对全部src/lua/*.lua、data/cards.json及build/lua/abyss_data.lua共101个输入做SHA256一致性检查；采样期间无变化。下表仅标识此快照，不是最终发布冻结值。
- 目录母集来自CardLibrary.addRed/Green/Blue/PurpleCards的实际注册调用，不从旧文档的75倒推，也不把特殊/无色/状态牌塞入常规职业池。

## 阶段定义

- **D/P/U**：默认数据可执行且有既有真实Combat.play/生命周期回归；开发显示适配可绘制。不是本轮正式实机认证。
- **E/P/U**：只在显式实验Profile定义，Capability基本版和升级版均返回true；有对应切片真实play/生命周期回归，开发显示适配已覆盖。默认发布仍不开启。
- **E/C/U**：实验Profile存在且基本/升级版Capability均接受；显示适配已有父线程实跑，但真实play专项尚未有相同输入树的通过证据时使用；不能从C推定P。当前238快照的已接受牌依父线程已执行专项标P。
- **E/T/U**：源规定不能主动打出，只有弃牌/生成生命周期测试；不能把Capability true写成可主动打出。
- **N**：当前Profile无定义，未进入此树卡池；列出的动作/能力是来源依赖，不表示已经实现。
- **G**：默认JSON有定义但Capability拒绝；若实验Profile已替换可用，在行中额外标G，不能据默认“有牌表”宣称通过。
- **M**：只有机制模块存在或其他私树成果，尚未成为本次输入树的完整卡定义/获取/显示闭环。

P的依据为当前树既有定向测试与父线程本轮执行报告，并非本账本重跑所有测试。C只证明解释器接受操作，不等于自然获取或完整机制验收。按职业证据入口：

- ironclad：`tests/lua/card_pool.lua / warrior_cards.lua / warrior_choices.lua / warrior_exhaust_cards.lua / corruption_cost.lua / warrior_exhaust_endturn.lua / warrior_strength_build.lua / warrior_status_build.lua / retrieval_cards.lua`（其中斜线分隔列出的同目录文件分别阅读）。
- silent：`tests/lua/silent_cards.lua / silent_expansion.lua / silent_poison_build.lua / silent_shivs.lua / silent_discard_build.lua / silent_attack_build.lua / silent_tactics_build.lua`（其中斜线分隔列出的同目录文件分别阅读）。
- defect：`tests/lua/defect_cards.lua / defect_expansion.lua / defect_focus_build.lua / defect_orb_powers.lua / defect_utility_build.lua / defect_engine_build.lua / retrieval_cards.lua`（其中斜线分隔列出的同目录文件分别阅读）。
- watcher：`tests/lua/watcher_cards.lua / watcher_powers.lua / watcher_scry.lua / watcher_mantra.lua / watcher_retain_build.lua / watcher_attack_build.lua / watcher_flow_build.lua`（其中斜线分隔列出的同目录文件分别阅读）。
- U由character_presentation.lua的真实BattleUI/DeckUI控制器绘制检查支撑；尚未接入/验收的原生职业选择、额外资源条、球/姿态帮助与Windows实机不能因有卡牌文字自动勾选。

## 数量对账

| 职业 | 源基础 | 源普通 | 源罕见 | 源稀有 | 注册合计 | 非基础常规池 | 当前源职业卡可执行 | 缺失 | 默认可执行 |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| ironclad | 3 | 20 | 36 | 16 | 75 | 72 | 66 | 9 | 30 |
| silent | 4 | 19 | 33 | 19 | 75 | 71 | 61 | 14 | 0 |
| defect | 4 | 18 | 36 | 17 | 75 | 71 | 56 | 19 | 0 |
| watcher | 4 | 19 | 35 | 17 | 75 | 71 | 55 | 20 | 0 |

源职业卡共300张；当前实验Profile基本与升级两版Capability都接受238张，缺62张，较旧165冻结树增加73张（四family69＋检索4）。238含15张职业基础定义，不含Shiv/Miracle/Insight等衍生及状态。默认数据仍仅战士30张可执行；另7张默认gated、仅实验Profile替换启用。Tactician/Reflex的计入表示弃牌生命周期支持，不表示可主动打出。未挂Profile的phase5/ClassFinal模块即使存在于开发目录也不计数。

### 按稀有度的双版Capability核对

| 职业 | 基础已支持/源 | 普通已支持/源 | 罕见已支持/源 | 稀有已支持/源 |
| --- | --- | --- | --- | --- |
| ironclad | 3/3 | 17/20 | 33/36 | 13/16 |
| silent | 4/4 | 19/19 | 28/33 | 10/19 |
| defect | 4/4 | 16/18 | 27/36 | 9/17 |
| watcher | 4/4 | 19/19 | 29/35 | 3/17 |

## 输入指纹：当前开发采样，非旧165冻结哈希

全部101输入按 `path<TAB>sha256<LF>` 排序汇总的SHA256：`80476d14c868e38060babec00ff4bbd7daed3846c99bc84d0b3b0e1d7b2e4489`。导出前后逐文件一致，后续root继续编辑时须重新采样；不称发布冻结或当前238树全量通过。

| 文件 | SHA256 |
| --- | --- |
| `data/cards.json` | `82b62ec0a06f8e1a4ad3fbb6015e4138cc505f06c016133d3f98bb7e125dad1a` |
| `src/lua/abyss_card_capability.lua` | `1ee83ded1e00d8304846706eb05f375c35ce5e02d7388ee43e4903abf11bc30d` |
| `src/lua/abyss_combat.lua` | `39ecc7ef8e576627f3608ce8c80d597e9560b0aec4851bf4849e6d202b439d80` |
| `src/lua/abyss_effects.lua` | `7d0b9d422062c6234055c30ef5161ed95b48eec446848904ff8396ea12863db3` |
| `src/lua/abyss_character_profiles.lua` | `370a0e905d6d8373f73034a8890c023175b1466d4a5ec1db18314b4a4a6c9772` |
| `src/lua/abyss_silent.lua` | `0d07f271188fd00da9a753ee74e4b7c6fe04d32d044ccfe65081654b89655903` |
| `src/lua/abyss_defect_cards.lua` | `7844025e58ffcf345243d29a8e24b21268f728e833456389acbd764bcbb8d6a3` |
| `src/lua/abyss_watcher_cards.lua` | `c93259044790a3e3d6d257d21355707c5879417ea65cc833bfd17ee6f6f5ad3c` |
| `src/lua/abyss_warrior_cards.lua` | `4f56541dc0c3139d548851e3c546405a6b434ec10ed3e473b78395006a0cf872` |
| `src/lua/abyss_shivs.lua` | `ac2488896dbe5011919f200fab032264abf9193e9e2b99372e1f999c04429427` |
| `src/lua/abyss_mantra.lua` | `434d2ddb3793ed9dfd85dbe66ff7f4b113811e022948463c10a51e63dcf32693` |
| `src/lua/abyss_warrior_exhaust_cards.lua` | `608866619ef39321559aab2ee2a4d4c130993426fc8ba98d9e069dd785f10806` |
| `src/lua/abyss_exhaust.lua` | `45c876d6762e2f1b62c8a7462bcb09036b345398b3a969ee92275c97afc4286a` |
| `src/lua/abyss_corruption.lua` | `f0daa0f3b9856157ba4045388cb0852562e6322ff287b821ca1d545a18c6e8ab` |
| `src/lua/abyss_silent_discard_cards.lua` | `fb8fc04666191f323ab9504ba732caed467d922806ce69962ff8e7989307bf9b` |
| `src/lua/abyss_orb_powers.lua` | `0905213561ddaf1a29764375bde4d150dedfc8884582e4f4e00411fcbdf8187f` |
| `src/lua/abyss_retained_cards.lua` | `aeb19b48f3213ff0e094e50718be049f0179b636ca6756c7ad4e084298eb46fe` |
| `src/lua/abyss_warrior_strength_cards.lua` | `a2cb29c6fa863c7aca6cb9698b3c1d3b8555796d0e2e54ee5c20f6e17290af36` |
| `src/lua/abyss_silent_attack_cards.lua` | `46af8ddc3446c35c4cecb57a8be16b6b687debb243c9a453d063584dcda70b21` |
| `src/lua/abyss_defect_utility_cards.lua` | `715f66ed0adba0c5da4f8702dd42b88d35da04daad8d9d6a35c9013bf9b2dc09` |
| `src/lua/abyss_watcher_attack_cards.lua` | `c6adcaf2a4c88988e7e957104a4812c9cefcd67a9740a2290cd73b9e3aa2d38e` |
| `src/lua/abyss_card_triggers.lua` | `84259d4025e21ac1d1734400d4034dad683942107efbc2392e2fdba7d1e57737` |
| `src/lua/abyss_character_presentation.lua` | `55fd7ff8f46853a15a5cdb7d3c6d08c2e2b7dfbafb7cba83d67b7c7132b5ba33` |
| `build/lua/abyss_data.lua` | `f33b413efe8deb93e52fd78f30db2d27424d313d30b59b3e401599c7213a6ece` |
| `src/lua/abyss_turn_powers.lua` | `e5c7183a772693629a7b132befd08c21d1703e5b5e24757c6f74bfe060d58c61` |
| `src/lua/abyss_power_schedule.lua` | `0db98f89dc333549726ea12f8441696773891da6c0ff403f317a10385696b7ea` |
| `src/lua/abyss_pile_choice.lua` | `4527339b830c627865e670a130f616811c37eee98515dd30478036c227a47532` |
| `src/lua/abyss_retrieval_cards.lua` | `352d25a7adbacb79a8f1f262d0a055cffa77676e389abfd3036fb184ef24e307` |
| `src/lua/abyss_flow_actions.lua` | `e671739e16c0ef0849660ddda01a7393305ca4a3b2752c725882541595c14047` |
| `src/lua/abyss_warrior_status_cards.lua` | `ead3f17b1ce9a7768c6351716a44629a24f5078a03481d4fe37d1609d2882f91` |
| `src/lua/abyss_defect_engine_cards.lua` | `232148a9e27de46ec26de0f57bd4dd66e52a2db0544825ced0150e6d9666f3e4` |
| `src/lua/abyss_silent_tactics_cards.lua` | `a9f739b6f64e9c653da935587d3a2774c9176d39c3cfbc89d742a8e2d93309e6` |
| `src/lua/abyss_watcher_flow_cards.lua` | `e8d0785239150c1ca364fc2f9901ba2c2cda0ead31fb709ea713a71979dd1c82` |

## ironclad：完整RED注册清单

| 源Java类 | SourceID | 稀有度 | 当前本地ID | 阶段 | 主要机制／源依赖 |
| --- | --- | --- | --- | --- | --- |
| `Bash` | `Bash` | BASIC | `bash` | D/P/U | damage / applyStatus:vulnerable |
| `Defend_Red` | `Defend_R` | BASIC | `defend` | D/P/U | block |
| `Strike_Red` | `Strike_R` | BASIC | `strike` | D/P/U | damage |
| `Anger` | `Anger` | COMMON | `anger` | D/P/U | damage / addCardToDiscard |
| `Armaments` | `Armaments` | COMMON | — | N | ArmamentsAction / GainBlockAction |
| `BodySlam` | `Body Slam` | COMMON | `body_slam` | D/P/U | damageEqualToBlock |
| `Clash` | `Clash` | COMMON | `clash` | E/P/U；G(默认) | damage |
| `Cleave` | `Cleave` | COMMON | `cleave` | D/P/U | damageAll |
| `Clothesline` | `Clothesline` | COMMON | `clothesline` | D/P/U | damage / applyStatus:weak |
| `Flex` | `Flex` | COMMON | `flex` | D/P/U | gainTemporaryStrength:strength |
| `Havoc` | `Havoc` | COMMON | — | N | PlayTopCardAction |
| `Headbutt` | `Headbutt` | COMMON | `headbutt` | E/P/U | damage / pileChoice:headbutt；源依赖 DamageAction / DiscardPileToTopOfDeckAction |
| `HeavyBlade` | `Heavy Blade` | COMMON | `heavy_blade` | E/P/U | damage；源依赖 力量系数攻击（非普通+1倍率） |
| `IronWave` | `Iron Wave` | COMMON | `iron_wave` | D/P/U | block / damage |
| `PerfectedStrike` | `Perfected Strike` | COMMON | `perfected_strike` | E/P/U | damage；源依赖 DamageAction |
| `PommelStrike` | `Pommel Strike` | COMMON | `pommel_strike` | D/P/U | damage / draw |
| `ShrugItOff` | `Shrug It Off` | COMMON | `shrug_it_off` | D/P/U | block / draw |
| `SwordBoomerang` | `Sword Boomerang` | COMMON | — | N | AttackDamageRandomEnemyAction |
| `ThunderClap` | `Thunderclap` | COMMON | `thunderclap` | D/P/U | damageAll / applyStatusAll:vulnerable |
| `TrueGrit` | `True Grit` | COMMON | `true_grit` | E/P/U；G(默认) | block / handChoice:exhaust_random |
| `TwinStrike` | `Twin Strike` | COMMON | `twin_strike` | D/P/U | damage |
| `Warcry` | `Warcry` | COMMON | `warcry` | E/P/U；G(默认) | draw / handChoice:put_on_deck |
| `WildStrike` | `Wild Strike` | COMMON | `wild_strike` | E/P/U | damage / makeTempCard；源依赖 DamageAction / MakeTempCardInDrawPileAction；衍生 Wound |
| `BattleTrance` | `Battle Trance` | UNCOMMON | `battle_trance` | D/P/U | draw / noDrawThisTurn |
| `BloodForBlood` | `Blood for Blood` | UNCOMMON | `blood_for_blood` | E/P/U | damage；源依赖 DamageAction |
| `Bloodletting` | `Bloodletting` | UNCOMMON | `bloodletting` | D/P/U | loseHp / energy |
| `BurningPact` | `Burning Pact` | UNCOMMON | `burning_pact` | E/P/U | 选择并消耗1张手牌后抽2/3，连续动作不可提前抽牌；ABI handChoice:exhaust_choose / draw |
| `Carnage` | `Carnage` | UNCOMMON | `carnage` | D/P/U | damage |
| `Combust` | `Combust` | UNCOMMON | `combust` | E/P/U | gainStrengthPower:combust；源依赖 CombustPower / ApplyPowerAction |
| `DarkEmbrace` | `Dark Embrace` | UNCOMMON | `dark_embrace` | E/P/U | 每消耗一张牌触发抽牌；满手/战斗结束/队列；ABI gainExhaustPower:dark_embrace |
| `Disarm` | `Disarm` | UNCOMMON | `disarm` | D/P/U | applyStatus:strength |
| `Dropkick` | `Dropkick` | UNCOMMON | `dropkick` | D/P/U | damage / conditional |
| `DualWield` | `Dual Wield` | UNCOMMON | — | N | DualWieldAction |
| `Entrench` | `Entrench` | UNCOMMON | `entrench` | D/P/U | doubleBlock |
| `Evolve` | `Evolve` | UNCOMMON | `evolve` | E/P/U | gainStatusPower:evolve；源依赖 EvolvePower / ApplyPowerAction |
| `FeelNoPain` | `Feel No Pain` | UNCOMMON | `feel_no_pain` | E/P/U | 每消耗一张牌触发固定格挡；多重消耗与顺序；ABI gainExhaustPower:feel_no_pain |
| `FireBreathing` | `Fire Breathing` | UNCOMMON | `fire_breathing` | E/P/U | gainStatusPower:fire_breathing；源依赖 FireBreathingPower / ApplyPowerAction |
| `FlameBarrier` | `Flame Barrier` | UNCOMMON | `flame_barrier` | E/P/U | block / gainStatusPower:flame_barrier；源依赖 FlameBarrierPower / ApplyPowerAction / GainBlockAction |
| `GhostlyArmor` | `Ghostly Armor` | UNCOMMON | `ghostly_armor` | D/P/U | block |
| `Hemokinesis` | `Hemokinesis` | UNCOMMON | `hemokinesis` | D/P/U | loseHp / damage |
| `InfernalBlade` | `Infernal Blade` | UNCOMMON | — | N | MakeTempCardInHandAction |
| `Inflame` | `Inflame` | UNCOMMON | `inflame` | D/P/U | gainStatus:strength |
| `Intimidate` | `Intimidate` | UNCOMMON | `intimidate` | E/P/U | applyStatusAll:weak；源依赖 WeakPower / ApplyPowerAction |
| `Metallicize` | `Metallicize` | UNCOMMON | `metallicize` | E/P/U；G(默认) | gainStatus:metallicize |
| `PowerThrough` | `Power Through` | UNCOMMON | `power_through` | E/P/U | makeTempCardInHand / block；源依赖 GainBlockAction / MakeTempCardInHandAction；衍生 Wound |
| `Pummel` | `Pummel` | UNCOMMON | `pummel` | E/P/U | damage；源依赖 DamageAction / PummelDamageAction |
| `Rage` | `Rage` | UNCOMMON | `rage` | E/P/U | gainCardTriggerPower:rage；源依赖 RagePower / ApplyPowerAction |
| `Rampage` | `Rampage` | UNCOMMON | `rampage` | D/P/U | damage / increaseDamageThisCombat |
| `RecklessCharge` | `Reckless Charge` | UNCOMMON | `reckless_charge` | E/P/U | damage / makeTempCard；源依赖 DamageAction / MakeTempCardInDrawPileAction；衍生 Dazed |
| `Rupture` | `Rupture` | UNCOMMON | `rupture` | E/P/U | gainStrengthPower:rupture；源依赖 自身卡牌伤害后增力量；不能混同普通受击 |
| `SearingBlow` | `Searing Blow` | UNCOMMON | — | N | DamageAction |
| `SecondWind` | `Second Wind` | UNCOMMON | `second_wind` | E/P/U | secondWind；源依赖 消耗所有非攻击手牌并按张数格挡 |
| `SeeingRed` | `Seeing Red` | UNCOMMON | `seeing_red` | D/P/U | energy |
| `Sentinel` | `Sentinel` | UNCOMMON | `sentinel` | E/P/U | 普通格挡5/8；自身被消耗返2/3能量；ABI block |
| `SeverSoul` | `Sever Soul` | UNCOMMON | `sever_soul` | E/P/U | exhaustNonAttacks / damage；源依赖 DamageAction / ExhaustAllNonAttackAction |
| `Shockwave` | `Shockwave` | UNCOMMON | `shockwave` | D/P/U | applyStatusAll:weak / applyStatusAll:vulnerable |
| `SpotWeakness` | `Spot Weakness` | UNCOMMON | `spot_weakness` | E/P/U | spotWeakness；源依赖 敌人当前意图攻击条件下加力量 |
| `Uppercut` | `Uppercut` | UNCOMMON | `uppercut` | D/P/U | damage / applyStatus:weak / applyStatus:vulnerable |
| `Whirlwind` | `Whirlwind` | UNCOMMON | `whirlwind` | E/P/U；G(默认) | whirlwind |
| `Barricade` | `Barricade` | RARE | `barricade` | D/P/U | gainStatus:barricade |
| `Berserk` | `Berserk` | RARE | `berserk` | E/P/U | gainStatus:vulnerable / gainStrengthPower:berserk；源依赖 BerserkPower / VulnerablePower / ApplyPowerAction |
| `Bludgeon` | `Bludgeon` | RARE | `bludgeon` | D/P/U | damage |
| `Brutality` | `Brutality` | RARE | `brutality` | E/P/U | gainStrengthPower:brutality；源依赖 BrutalityPower / ApplyPowerAction |
| `Corruption` | `Corruption` | RARE | `corruption` | E/P/U | 技能变0费并在打出后消耗；与消耗触发队列组合；ABI gainExhaustPower:corruption |
| `DemonForm` | `Demon Form` | RARE | `demon_form` | E/P/U；G(默认) | gainStatus:demon_form |
| `DoubleTap` | `Double Tap` | RARE | — | N | DoubleTapPower / ApplyPowerAction |
| `Exhume` | `Exhume` | RARE | `exhume` | E/P/U | pileChoice:exhume；源依赖 选择消耗堆卡牌回手；排除本牌实例与选牌 |
| `Feed` | `Feed` | RARE | — | N | FeedAction |
| `FiendFire` | `Fiend Fire` | RARE | `fiend_fire` | E/P/U | fiendFire；源依赖 消耗整手并按数量多段攻击；消耗触发顺序 |
| `Immolate` | `Immolate` | RARE | `immolate` | E/P/U | damageAll / makeTempCardInDiscard；源依赖 DamageAllEnemiesAction / MakeTempCardInDiscardAction；衍生 Burn |
| `Impervious` | `Impervious` | RARE | `impervious` | D/P/U | block |
| `Juggernaut` | `Juggernaut` | RARE | — | N | 每次获得格挡后随机伤害；独立随机流 |
| `LimitBreak` | `Limit Break` | RARE | `limit_break` | E/P/U | limitBreak；源依赖 力量翻倍；升级取消消耗 |
| `Offering` | `Offering` | RARE | `offering` | D/P/U | loseHp / energy / draw |
| `Reaper` | `Reaper` | RARE | `reaper` | E/P/U；G(默认) | reaperDamage |

## silent：完整GREEN注册清单

| 源Java类 | SourceID | 稀有度 | 当前本地ID | 阶段 | 主要机制／源依赖 |
| --- | --- | --- | --- | --- | --- |
| `Defend_Green` | `Defend_G` | BASIC | `defend_green` | E/P/U | block |
| `Neutralize` | `Neutralize` | BASIC | `neutralize` | E/P/U | damage / applyStatus:weak |
| `Strike_Green` | `Strike_G` | BASIC | `strike_green` | E/P/U | damage |
| `Survivor` | `Survivor` | BASIC | `survivor` | E/P/U | block / requestDiscard |
| `Acrobatics` | `Acrobatics` | COMMON | `acrobatics` | E/P/U | draw / requestDiscard |
| `Backflip` | `Backflip` | COMMON | `backflip` | E/P/U | block / draw |
| `Bane` | `Bane` | COMMON | `bane` | E/P/U | damage / conditional；源依赖 BaneAction / DamageAction |
| `BladeDance` | `Blade Dance` | COMMON | `blade_dance` | E/P/U | generateShivs |
| `CloakAndDagger` | `Cloak And Dagger` | COMMON | `cloak_and_dagger` | E/P/U | block / generateShivs |
| `DaggerSpray` | `Dagger Spray` | COMMON | `dagger_spray` | E/P/U | damageAll |
| `DaggerThrow` | `Dagger Throw` | COMMON | `dagger_throw` | E/P/U | damage / draw / requestDiscard |
| `DeadlyPoison` | `Deadly Poison` | COMMON | `deadly_poison` | E/P/U | applyStatus:poison |
| `Deflect` | `Deflect` | COMMON | `deflect` | E/P/U | block；源依赖 GainBlockAction |
| `DodgeAndRoll` | `Dodge and Roll` | COMMON | `dodge_and_roll` | E/P/U | block / nextBlock；源依赖 NextTurnBlockPower / ApplyPowerAction / GainBlockAction |
| `FlyingKnee` | `Flying Knee` | COMMON | `flying_knee` | E/P/U | damage / nextEnergy；源依赖 EnergizedPower / ApplyPowerAction / DamageAction |
| `Outmaneuver` | `Outmaneuver` | COMMON | `outmaneuver` | E/P/U | nextEnergy；源依赖 EnergizedPower / ApplyPowerAction |
| `PiercingWail` | `PiercingWail` | COMMON | `piercing_wail` | E/P/U | piercingWail；源依赖 GainStrengthPower / StrengthPower / ApplyPowerAction |
| `PoisonedStab` | `Poisoned Stab` | COMMON | `poisoned_stab` | E/P/U | damage / applyStatus:poison；源依赖 PoisonPower / ApplyPowerAction / DamageAction |
| `Prepared` | `Prepared` | COMMON | `prepared` | E/P/U | draw / requestDiscard |
| `QuickSlash` | `Quick Slash` | COMMON | `quick_slash` | E/P/U | damage / draw |
| `Slice` | `Slice` | COMMON | `slice` | E/P/U | damage；源依赖 DamageAction |
| `SuckerPunch` | `Sucker Punch` | COMMON | `sucker_punch` | E/P/U | damage / applyStatus:weak；源依赖 WeakPower / ApplyPowerAction / DamageAction |
| `SneakyStrike` | `Underhanded Strike` | COMMON | `sneaky_strike` | E/P/U | damage / gainEnergyIfDiscard |
| `Accuracy` | `Accuracy` | UNCOMMON | `accuracy` | E/P/U | gainStatus:accuracy |
| `AllOutAttack` | `All Out Attack` | UNCOMMON | `all_out_attack` | E/P/U | damageAll / allOutDiscard；源依赖 DamageAllEnemiesAction / DiscardAction |
| `Backstab` | `Backstab` | UNCOMMON | `backstab` | E/P/U | damage；源依赖 DamageAction |
| `Blur` | `Blur` | UNCOMMON | `blur` | E/P/U | block / gainStatus:blur；源依赖 BlurPower / ApplyPowerAction / GainBlockAction |
| `BouncingFlask` | `Bouncing Flask` | UNCOMMON | `bouncing_flask` | E/P/U | bouncingPoison |
| `CalculatedGamble` | `Calculated Gamble` | UNCOMMON | `calculated_gamble` | E/P/U | 弃整手后等量抽牌；弃牌收益与完整队列；ABI calculatedGamble |
| `Caltrops` | `Caltrops` | UNCOMMON | `caltrops` | E/P/U | gainStatus:thorns；源依赖 ThornsPower / ApplyPowerAction |
| `Catalyst` | `Catalyst` | UNCOMMON | `catalyst` | E/P/U | multiplyPoison |
| `Choke` | `Choke` | UNCOMMON | `choke` | E/P/U | damage / applyStatus:choked；源依赖 ChokePower / ApplyPowerAction / DamageAction |
| `Concentrate` | `Concentrate` | UNCOMMON | `concentrate` | E/P/U | concentrateDiscard；源依赖 选弃多张手牌后获得能量；选择不足边界 |
| `CripplingPoison` | `Crippling Poison` | UNCOMMON | `crippling_poison` | E/P/U | cripplingPoison；源依赖 PoisonPower / WeakPower / ApplyPowerAction |
| `Dash` | `Dash` | UNCOMMON | `dash` | E/P/U | block / damage；源依赖 DamageAction / GainBlockAction |
| `Distraction` | `Distraction` | UNCOMMON | — | N | MakeTempCardInHandAction |
| `EndlessAgony` | `Endless Agony` | UNCOMMON | — | N | DamageAction / MakeTempCardInHandAction |
| `EscapePlan` | `Escape Plan` | UNCOMMON | `escape_plan` | E/P/U | escapePlan；源依赖 DrawCardAction / EscapePlanAction |
| `Eviscerate` | `Eviscerate` | UNCOMMON | `eviscerate` | E/P/U | 随本回合弃牌次数动态减费，多段攻击；ABI damage |
| `Expertise` | `Expertise` | UNCOMMON | `expertise` | E/P/U | expertise；源依赖 ExpertiseAction |
| `Finisher` | `Finisher` | UNCOMMON | `finisher` | E/P/U | finisherDamage；源依赖 DamagePerAttackPlayedAction |
| `Flechettes` | `Flechettes` | UNCOMMON | `flechettes` | E/P/U | flechettesDamage；源依赖 FlechetteAction |
| `Footwork` | `Footwork` | UNCOMMON | `footwork` | E/P/U | gainStatus:dexterity |
| `HeelHook` | `Heel Hook` | UNCOMMON | `heel_hook` | E/P/U | heelHook；源依赖 HeelHookAction |
| `InfiniteBlades` | `Infinite Blades` | UNCOMMON | `infinite_blades` | E/P/U | Profile已激活；从下回合起每回合生成1Shiv，升级Innate；ABI gainStatus:infinite_blades |
| `LegSweep` | `Leg Sweep` | UNCOMMON | `leg_sweep` | E/P/U | applyStatus:weak / block；源依赖 WeakPower / ApplyPowerAction / GainBlockAction |
| `MasterfulStab` | `Masterful Stab` | UNCOMMON | — | N | DamageAction |
| `NoxiousFumes` | `Noxious Fumes` | UNCOMMON | `noxious_fumes` | E/P/U | gainStatus:noxious_fumes |
| `Predator` | `Predator` | UNCOMMON | `predator` | E/P/U | damage / gainStatus:draw_next_turn；源依赖 DrawCardNextTurnPower / ApplyPowerAction / DamageAction |
| `Reflex` | `Reflex` | UNCOMMON | `reflex` | E/T/U | 主动弃牌收益（不能打出） |
| `RiddleWithHoles` | `Riddle With Holes` | UNCOMMON | `riddle_with_holes` | E/P/U | damage；源依赖 DamageAction |
| `Setup` | `Setup` | UNCOMMON | — | N | SetupAction |
| `Skewer` | `Skewer` | UNCOMMON | `skewer` | E/P/U | skewer；源依赖 SkewerAction |
| `Tactician` | `Tactician` | UNCOMMON | `tactician` | E/T/U | 主动弃牌收益（不能打出） |
| `Terror` | `Terror` | UNCOMMON | `terror` | E/P/U | applyStatus:vulnerable；源依赖 VulnerablePower / ApplyPowerAction |
| `WellLaidPlans` | `Well Laid Plans` | UNCOMMON | — | N | 回合结束选择保留；升级选择数量 |
| `AThousandCuts` | `A Thousand Cuts` | RARE | `thousand_cuts` | E/P/U | gainCardTriggerPower:thousand_cuts；源依赖 每打出一牌对全敌伤害 |
| `Adrenaline` | `Adrenaline` | RARE | `adrenaline` | E/P/U | energy / draw；源依赖 DrawCardAction / GainEnergyAction |
| `AfterImage` | `After Image` | RARE | `after_image` | E/P/U | gainCardTriggerPower:after_image；源依赖 每打出一牌触发格挡；排队优先级 |
| `BulletTime` | `Bullet Time` | RARE | — | N | NoDrawPower / ApplyBulletTimeAction / ApplyPowerAction |
| `Burst` | `Burst` | RARE | — | N | 复制后续技能；选择/资源/触发边界 |
| `CorpseExplosion` | `Corpse Explosion` | RARE | — | N | CorpseExplosionPower / PoisonPower / ApplyPowerAction |
| `DieDieDie` | `Die Die Die` | RARE | `die_die_die` | E/P/U | damageAll；源依赖 DamageAllEnemiesAction / ShakeScreenAction |
| `Doppelganger` | `Doppelganger` | RARE | — | N | DoppelgangerAction |
| `Envenom` | `Envenom` | RARE | `envenom` | E/P/U | gainCardTriggerPower:envenom；源依赖 普通攻击实际HP伤害触发中毒 |
| `GlassKnife` | `Glass Knife` | RARE | `glass_knife` | E/P/U | glassKnife；源依赖 DamageAction / ModifyDamageAction |
| `GrandFinale` | `Grand Finale` | RARE | `grand_finale` | E/P/U | damageAll；源依赖 抽牌堆为空的严格可打条件 |
| `Malaise` | `Malaise` | RARE | `malaise` | E/P/U | malaise；源依赖 MalaiseAction |
| `Nightmare` | `Night Terror` | RARE | — | N | NightmareAction |
| `PhantasmalKiller` | `Phantasmal Killer` | RARE | — | N | 下一回合攻击翻倍 |
| `StormOfSteel` | `Storm of Steel` | RARE | `storm_of_steel` | E/P/U | stormOfSteel；源依赖 BladeFuryAction；衍生 Shiv |
| `ToolsOfTheTrade` | `Tools of the Trade` | RARE | — | N | 每回合抽牌后弃牌选择与触发 |
| `Unload` | `Unload` | RARE | `unload` | E/P/U | damage / unload；源依赖 DamageAction / UnloadAction |
| `Alchemize` | `Venomology` | RARE | — | N | ObtainPotionAction |
| `WraithForm` | `Wraith Form v2` | RARE | — | N | 无形与每回合损失敏捷；Artifact入站判断 |

## defect：完整BLUE注册清单

| 源Java类 | SourceID | 稀有度 | 当前本地ID | 阶段 | 主要机制／源依赖 |
| --- | --- | --- | --- | --- | --- |
| `Defend_Blue` | `Defend_B` | BASIC | `defend_blue` | E/P/U | block |
| `Dualcast` | `Dualcast` | BASIC | `dualcast` | E/P/U | dualcastOrb |
| `Strike_Blue` | `Strike_B` | BASIC | `strike_blue` | E/P/U | damage |
| `Zap` | `Zap` | BASIC | `zap` | E/P/U | channelOrb |
| `BallLightning` | `Ball Lightning` | COMMON | `ball_lightning` | E/P/U | damage / channelOrb |
| `Barrage` | `Barrage` | COMMON | `barrage` | E/P/U | barrageDamage；源依赖 BarrageAction |
| `BeamCell` | `Beam Cell` | COMMON | `beam_cell` | E/P/U | damage / applyStatus:vulnerable |
| `ColdSnap` | `Cold Snap` | COMMON | `cold_snap` | E/P/U | damage / channelOrb |
| `CompileDriver` | `Compile Driver` | COMMON | `compile_driver` | E/P/U | damage / compileDriverDraw；源依赖 CompileDriverAction / DamageAction |
| `ConserveBattery` | `Conserve Battery` | COMMON | `charge_battery` | E/P/U | block / nextEnergy；源依赖 EnergizedBluePower / ApplyPowerAction / GainBlockAction |
| `Coolheaded` | `Coolheaded` | COMMON | `coolheaded` | E/P/U | channelOrb / draw |
| `Claw` | `Gash` | COMMON | `claw` | E/P/U | damage / growClaws；源依赖 DamageAction / GashAction |
| `GoForTheEyes` | `Go for the Eyes` | COMMON | `go_for_the_eyes` | E/P/U | damage / weakIfAttacking；源依赖 DamageAction / ForTheEyesAction |
| `Hologram` | `Hologram` | COMMON | `hologram` | E/P/U | block / pileChoice:hologram；源依赖 从弃牌堆选择回手；升级取消消耗 |
| `Leap` | `Leap` | COMMON | `leap` | E/P/U | block |
| `Rebound` | `Rebound` | COMMON | — | N | ReboundPower / ApplyPowerAction / DamageAction |
| `Recursion` | `Redo` | COMMON | — | N | RedoAction |
| `Stack` | `Stack` | COMMON | `stack` | E/P/U | stackBlock；源依赖 GainBlockAction |
| `SteamBarrier` | `Steam` | COMMON | `steam_barrier` | E/P/U | block / loseSteamBlock；源依赖 GainBlockAction / ModifyBlockAction |
| `Streamline` | `Streamline` | COMMON | `streamline` | E/P/U | damage / reduceStreamlineCost；源依赖 DamageAction / ReduceCostAction |
| `SweepingBeam` | `Sweeping Beam` | COMMON | `sweeping_beam` | E/P/U | damageAll / draw |
| `Turbo` | `Turbo` | COMMON | `turbo` | E/P/U | energy / makeTempCardInDiscard；源依赖 GainEnergyAction / MakeTempCardInDiscardAction；衍生 Void |
| `Aggregate` | `Aggregate` | UNCOMMON | `aggregate` | E/P/U | aggregateEnergy；源依赖 AggregateEnergyAction |
| `AutoShields` | `Auto Shields` | UNCOMMON | `auto_shields` | E/P/U | autoShields；源依赖 GainBlockAction |
| `Blizzard` | `Blizzard` | UNCOMMON | `blizzard` | E/P/U | blizzardDamage；源依赖 DamageAllEnemiesAction |
| `BootSequence` | `BootSequence` | UNCOMMON | `boot_sequence` | E/P/U | block；源依赖 GainBlockAction |
| `Capacitor` | `Capacitor` | UNCOMMON | `capacitor` | E/P/U | gainOrbSlots |
| `Chaos` | `Chaos` | UNCOMMON | `chaos` | E/P/U | chaosOrbs；源依赖 ChannelAction |
| `Chill` | `Chill` | UNCOMMON | `chill` | E/P/U | chillOrbs；源依赖 ChannelAction |
| `Consume` | `Consume` | UNCOMMON | `consume` | E/P/U | gainFocus / loseOrbSlots |
| `Darkness` | `Darkness` | UNCOMMON | `darkness` | E/P/U | channelOrb |
| `Defragment` | `Defragment` | UNCOMMON | `defragment` | E/P/U | gainFocus |
| `DoomAndGloom` | `Doom and Gloom` | UNCOMMON | `doom_and_gloom` | E/P/U | damageAll / channelOrb；源依赖 ChannelAction / DamageAllEnemiesAction |
| `DoubleEnergy` | `Double Energy` | UNCOMMON | `double_energy` | E/P/U | doubleEnergy；源依赖 DoubleEnergyAction |
| `FTL` | `FTL` | UNCOMMON | `ftl` | E/P/U | ftlDamage；源依赖 FTLAction |
| `ForceField` | `Force Field` | UNCOMMON | — | N | GainBlockAction |
| `Fusion` | `Fusion` | UNCOMMON | `fusion` | E/P/U | channelOrb |
| `GeneticAlgorithm` | `Genetic Algorithm` | UNCOMMON | — | N | GainBlockAction / IncreaseMiscAction |
| `Glacier` | `Glacier` | UNCOMMON | `glacier` | E/P/U | block / channelOrb / channelOrb；源依赖 ChannelAction / GainBlockAction |
| `Heatsinks` | `Heatsinks` | UNCOMMON | `heat_sinks` | E/P/U | gainCardTriggerPower:heat_sinks；源依赖 打出能力后抽牌；能力与费用/弃置顺序 |
| `HelloWorld` | `Hello World` | UNCOMMON | — | N | HelloPower / ApplyPowerAction |
| `LockOn` | `Lockon` | UNCOMMON | `lock_on` | E/P/U | damage / applyLockOn；源依赖 目标LockOn对球伤害加成与取整 |
| `Loop` | `Loop` | UNCOMMON | `loop` | E/P/U | 每回合开始额外触发首球被动；与Bias排队次序；ABI gainOrbPower:loop |
| `Melter` | `Melter` | UNCOMMON | `melter` | E/P/U | removeBlock / damage；源依赖 DamageAction / RemoveAllBlockAction |
| `Recycle` | `Recycle` | UNCOMMON | — | N | RecycleAction |
| `ReinforcedBody` | `Reinforced Body` | UNCOMMON | `reinforced_body` | E/P/U | xBlock；源依赖 ReinforcedBodyAction |
| `Reprogram` | `Reprogram` | UNCOMMON | `reprogram` | E/P/U | gainFocus / gainStatus:strength / gainStatus:dexterity |
| `RipAndTear` | `Rip and Tear` | UNCOMMON | `rip_and_tear` | E/P/U | randomEngineAttack；源依赖 NewRipAndTearAction |
| `Scrape` | `Scrape` | UNCOMMON | — | N | DamageAction / DrawCardAction / ScrapeFollowUpAction |
| `SelfRepair` | `Self Repair` | UNCOMMON | — | N | RepairPower / ApplyPowerAction |
| `Skim` | `Skim` | UNCOMMON | `skim` | E/P/U | draw；源依赖 DrawCardAction |
| `StaticDischarge` | `Static Discharge` | UNCOMMON | — | N | StaticDischargePower / ApplyPowerAction |
| `Overclock` | `Steam Power` | UNCOMMON | `overclock` | E/P/U | draw / makeTempCardInDiscard；源依赖 DrawCardAction / MakeTempCardInDiscardAction；衍生 Burn |
| `Storm` | `Storm` | UNCOMMON | `storm` | E/P/U | gainCardTriggerPower:storm；源依赖 打出能力后生成闪电；开战先天与排队 |
| `Sunder` | `Sunder` | UNCOMMON | `sunder` | E/P/U | sunderDamage；源依赖 SunderAction |
| `Tempest` | `Tempest` | UNCOMMON | `tempest` | E/P/U | tempestOrbs；源依赖 TempestAction |
| `Equilibrium` | `Undo` | UNCOMMON | — | N | 本回合全手牌保留与回合结束 |
| `WhiteNoise` | `White Noise` | UNCOMMON | — | N | MakeTempCardInHandAction |
| `AllForOne` | `All For One` | RARE | — | N | 回收弃牌堆0费牌；临时费用与多实例 |
| `Amplify` | `Amplify` | RARE | — | N | AmplifyPower / ApplyPowerAction |
| `BiasedCognition` | `Biased Cognition` | RARE | `biased_cognition` | E/P/U | gainFocus / applyBias |
| `Buffer` | `Buffer` | RARE | — | N | BufferPower / ApplyPowerAction |
| `CoreSurge` | `Core Surge` | RARE | `core_surge` | E/P/U | damage / gainStatus:artifact；源依赖 ArtifactPower / ApplyPowerAction / DamageAction |
| `CreativeAI` | `Creative AI` | RARE | — | N | 每回合随机生成能力牌；完整蓝能力池 |
| `EchoForm` | `Echo Form` | RARE | — | N | 首牌复制与使用卡队列/费用/目标 |
| `Electrodynamics` | `Electrodynamics` | RARE | `electrodynamics` | E/P/U | 闪电被动/唤起全敌，先获得Power再生成2/3球；LockOn联动仍未实现；ABI gainOrbPower:electrodynamics / channelOrb / channelOrb |
| `Fission` | `Fission` | RARE | — | N | 移除全部球/升级唤起；逐球资源与队列 |
| `Hyperbeam` | `Hyperbeam` | RARE | `hyperbeam` | E/P/U | damageAll / gainFocus；源依赖 FocusPower / ApplyPowerAction / DamageAllEnemiesAction |
| `MachineLearning` | `Machine Learning` | RARE | — | N | DrawPower / ApplyPowerAction |
| `MeteorStrike` | `Meteor Strike` | RARE | `meteor_strike` | E/P/U | damage / channelOrb / channelOrb / channelOrb；源依赖 ChannelAction / DamageAction |
| `MultiCast` | `Multi-Cast` | RARE | `multi_cast` | E/P/U | multiCastOrb；源依赖 X费多次唤起同球/升级增加次数 |
| `Rainbow` | `Rainbow` | RARE | `rainbow` | E/P/U | channelOrb / channelOrb / channelOrb；源依赖 ChannelAction |
| `Reboot` | `Reboot` | RARE | — | N | DrawCardAction / ShuffleAction / ShuffleAllAction |
| `Seek` | `Seek` | RARE | `seek` | E/P/U | pileChoice:seek；源依赖 BetterDrawPileToHandAction |
| `ThunderStrike` | `Thunder Strike` | RARE | `thunder_strike` | E/P/U | thunderStrike；源依赖 NewThunderStrikeAction |

## watcher：完整PURPLE注册清单

| 源Java类 | SourceID | 稀有度 | 当前本地ID | 阶段 | 主要机制／源依赖 |
| --- | --- | --- | --- | --- | --- |
| `Defend_Watcher` | `Defend_P` | BASIC | `defend_purple` | E/P/U | block |
| `Eruption` | `Eruption` | BASIC | `eruption` | E/P/U | damage / changeStance |
| `Strike_Purple` | `Strike_P` | BASIC | `strike_purple` | E/P/U | damage |
| `Vigilance` | `Vigilance` | BASIC | `vigilance` | E/P/U | block / changeStance |
| `BowlingBash` | `BowlingBash` | COMMON | `bowling_bash` | E/P/U | bowlingBash；源依赖 DamageAction |
| `Tranquility` | `ClearTheMind` | COMMON | `tranquility` | E/P/U | changeStance |
| `Consecrate` | `Consecrate` | COMMON | `consecrate` | E/P/U | damageAll；源依赖 DamageAllEnemiesAction |
| `Crescendo` | `Crescendo` | COMMON | `crescendo` | E/P/U | changeStance |
| `CrushJoints` | `CrushJoints` | COMMON | `crush_joints` | E/P/U | damage / previousCardType；源依赖 CrushJointsAction / DamageAction |
| `CutThroughFate` | `CutThroughFate` | COMMON | `cut_through_fate` | E/P/U | damage / scry / draw |
| `EmptyBody` | `EmptyBody` | COMMON | `empty_body` | E/P/U | block / changeStance |
| `EmptyFist` | `EmptyFist` | COMMON | `empty_fist` | E/P/U | damage / changeStance |
| `Evaluate` | `Evaluate` | COMMON | `evaluate` | E/P/U | block / makeTempCard；源依赖 GainBlockAction / MakeTempCardInDrawPileAction；衍生 Insight |
| `FlurryOfBlows` | `FlurryOfBlows` | COMMON | `flurry_of_blows` | E/P/U | flowDamage；源依赖 DamageAction / DiscardToHandAction |
| `FlyingSleeves` | `FlyingSleeves` | COMMON | `flying_sleeves` | E/P/U | damage；源依赖 DamageAction |
| `FollowUp` | `FollowUp` | COMMON | `follow_up` | E/P/U | damage / previousCardType；源依赖 DamageAction / FollowUpAction |
| `Halt` | `Halt` | COMMON | `halt` | E/P/U | halt；源依赖 HaltAction |
| `JustLucky` | `JustLucky` | COMMON | `just_lucky` | E/P/U | scry / block / damage |
| `PressurePoints` | `PathToVictory` | COMMON | `pressure_points` | E/P/U | applyWatcherFlowPower:mark / triggerMarks；源依赖 MarkPower / ApplyPowerAction / TriggerMarksAction |
| `Prostrate` | `Prostrate` | COMMON | `prostrate` | E/P/U | gainMantra / block |
| `Protect` | `Protect` | COMMON | `protect` | E/P/U | block |
| `SashWhip` | `SashWhip` | COMMON | `sash_whip` | E/P/U | damage / previousCardType；源依赖 DamageAction / HeadStompAction |
| `ThirdEye` | `ThirdEye` | COMMON | `third_eye` | E/P/U | block / scry |
| `Rushdown` | `Adaptation` | UNCOMMON | `rushdown` | E/P/U | gainStancePower:rushdown |
| `BattleHymn` | `BattleHymn` | UNCOMMON | `battle_hymn` | E/P/U | gainWatcherFlowPower:battle_hymn；源依赖 每回合生成Smite；完整衍生牌；衍生 Smite |
| `CarveReality` | `CarveReality` | UNCOMMON | `carve_reality` | E/P/U | damage / makeTempCard；源依赖 DamageAction / MakeTempCardInHandAction；衍生 Smite |
| `Collect` | `Collect` | UNCOMMON | `collect` | E/P/U | collect；源依赖 CollectAction；衍生 Miracle |
| `Conclude` | `Conclude` | UNCOMMON | — | N | DamageAllEnemiesAction / PressEndTurnButtonAction |
| `DeceiveReality` | `DeceiveReality` | UNCOMMON | `deceive_reality` | E/P/U | block / makeTempCard；源依赖 GainBlockAction / MakeTempCardInHandAction；衍生 Safety |
| `EmptyMind` | `EmptyMind` | UNCOMMON | `empty_mind` | E/P/U | draw / changeStance；源依赖 ChangeStanceAction / DrawCardAction / NotStanceCheckAction |
| `Fasting` | `Fasting2` | UNCOMMON | `fasting` | E/P/U | gainStatus:strength / gainStatus:dexterity / gainWatcherFlowPower:energy_down；源依赖 DexterityPower / EnergyDownPower / StrengthPower / ApplyPowerAction |
| `FearNoEvil` | `FearNoEvil` | UNCOMMON | `fear_no_evil` | E/P/U | fearNoEvil；源依赖 FearNoEvilAction |
| `ForeignInfluence` | `ForeignInfluence` | UNCOMMON | — | N | ForeignInfluenceAction |
| `Indignation` | `Indignation` | UNCOMMON | `indignation` | E/P/U | indignation；源依赖 IndignationAction |
| `InnerPeace` | `InnerPeace` | UNCOMMON | `inner_peace` | E/P/U | innerPeace |
| `LikeWater` | `LikeWater` | UNCOMMON | `like_water` | E/P/U | gainWatcherFlowPower:like_water；源依赖 LikeWaterPower / ApplyPowerAction |
| `Meditate` | `Meditate` | UNCOMMON | — | N | 从弃牌堆选牌回手并保留，之后结束回合 |
| `MentalFortress` | `MentalFortress` | UNCOMMON | `mental_fortress` | E/P/U | gainStancePower:mental_fortress |
| `Nirvana` | `Nirvana` | UNCOMMON | `nirvana` | E/P/U | gainStatus:nirvana |
| `Perseverance` | `Perseverance` | UNCOMMON | `perseverance` | E/P/U | 单实例保留格挡成长，基本+2/升级+3；ABI block |
| `Pray` | `Pray` | UNCOMMON | `pray` | E/P/U | gainMantra / makeTempCard；源依赖 MantraPower / ApplyPowerAction / MakeTempCardInDrawPileAction；衍生 Insight |
| `ReachHeaven` | `ReachHeaven` | UNCOMMON | `reach_heaven` | E/P/U | damage / makeTempCard；源依赖 DamageAction / MakeTempCardInDrawPileAction；衍生 ThroughViolence |
| `Sanctity` | `Sanctity` | UNCOMMON | `sanctity` | E/P/U | block / previousCardType；源依赖 GainBlockAction / SanctityAction |
| `SandsOfTime` | `SandsOfTime` | UNCOMMON | `sands_of_time` | E/P/U | 单实例保留减费/临时费用历史覆盖，最低0；ABI damage |
| `SignatureMove` | `SignatureMove` | UNCOMMON | `signature_move` | E/P/U | damage；源依赖 DamageAction |
| `Study` | `Study` | UNCOMMON | `study` | E/P/U | gainWatcherFlowPower:study；源依赖 StudyPower / ApplyPowerAction；衍生 Insight |
| `Swivel` | `Swivel` | UNCOMMON | — | N | FreeAttackPower / ApplyPowerAction / GainBlockAction |
| `TalkToTheHand` | `TalkToTheHand` | UNCOMMON | `talk_to_the_hand` | E/P/U | damage / applyWatcherFlowPower:block_return；源依赖 BlockReturnPower / ApplyPowerAction / DamageAction |
| `Tantrum` | `Tantrum` | UNCOMMON | `tantrum` | E/P/U | flowDamage / changeStance；源依赖 ChangeStanceAction / DamageAction |
| `SimmeringFury` | `Vengeance` | UNCOMMON | `simmering_fury` | E/P/U | gainWatcherFlowPower:wrath_next_turn / gainWatcherFlowPower:draw_card_next_turn；源依赖 DrawCardNextTurnPower / WrathNextTurnPower / ApplyPowerAction |
| `Wallop` | `Wallop` | UNCOMMON | `wallop` | E/P/U | wallop；源依赖 WallopAction |
| `WaveOfTheHand` | `WaveOfTheHand` | UNCOMMON | — | N | WaveOfTheHandPower / ApplyPowerAction |
| `Weave` | `Weave` | UNCOMMON | `weave` | E/P/U | flowDamage；源依赖 DamageAction / DiscardToHandAction |
| `WheelKick` | `WheelKick` | UNCOMMON | `wheel_kick` | E/P/U | damage / draw；源依赖 DamageAction / DrawCardAction |
| `WindmillStrike` | `WindmillStrike` | UNCOMMON | `windmill_strike` | E/P/U | 单实例保留攻击成长，基本+4/升级+5；ABI damage |
| `Foresight` | `Wireheading` | UNCOMMON | — | N | 每回合开始占卜；交互与后续队列 |
| `Worship` | `Worship` | UNCOMMON | `worship` | E/P/U | gainMantra |
| `WreathOfFlame` | `WreathOfFlame` | UNCOMMON | `wreath_of_flame` | E/P/U | gainWatcherFlowPower:vigor；源依赖 VigorPower / ApplyPowerAction |
| `Alpha` | `Alpha` | RARE | — | N | Alpha→Beta→Omega链与全敌持续伤害；衍生 Beta |
| `Blasphemy` | `Blasphemy` | RARE | — | N | 神格与下一回合死亡；不能普通DEBUFF清除 |
| `Brilliance` | `Brilliance` | RARE | `brilliance` | E/P/U | damage；源依赖 DamageAction |
| `ConjureBlade` | `ConjureBlade` | RARE | — | N | X费生成Expunger多段攻击；衍生 Expunger |
| `DeusExMachina` | `DeusExMachina` | RARE | — | N | ExhaustSpecificCardAction / MakeTempCardInHandAction；衍生 Miracle |
| `DevaForm` | `DevaForm` | RARE | — | N | 逐回合能量增长能力 |
| `Devotion` | `Devotion` | RARE | `devotion` | E/P/U | gainDevotion |
| `Establishment` | `Establishment` | RARE | — | N | 保留后减费；临时成本与永久升级区别 |
| `Judgement` | `Judgement` | RARE | — | N | JudgementAction |
| `LessonLearned` | `LessonLearned` | RARE | — | N | 致死后永久升级；战后与随机流 |
| `MasterReality` | `MasterReality` | RARE | — | N | 本场生成卡升级与不同生成路径 |
| `Omniscience` | `Omniscience` | RARE | — | N | 牌堆选择并两次执行再消耗；排队与目标 |
| `Ragnarok` | `Ragnarok` | RARE | — | N | AttackDamageRandomEnemyAction |
| `Scrawl` | `Scrawl` | RARE | `scrawl` | E/P/U | drawToHandSize；源依赖 ExpertiseAction |
| `SpiritShield` | `SpiritShield` | RARE | — | N | GainBlockAction |
| `Vault` | `Vault` | RARE | — | N | 额外玩家回合；敌方不推进 |
| `Wish` | `Wish` | RARE | — | N | 三选一衍生能力/金币；保留完整选择；衍生 BecomeAlmighty, FameAndFortune, LiveForever |

## 衍生／特殊／状态依赖（不计入300张常规职业注册）

以下是四职业直接生成依赖及其传递闭包。它们按源COLORLESS/SPECIAL或状态归类，不因可生成就混入奖励/商店常规池。

| SourceID | 源类型/稀有度 | 生成职业/来源 | 本地阶段 | 主要依赖 |
| --- | --- | --- | --- | --- |
| `BecomeAlmighty` | POWER/SPECIAL | PURPLE | N，未定义/未获取/未显示 | StrengthPower / ApplyPowerAction |
| `Beta` | SKILL/SPECIAL | PURPLE | N，未定义/未获取/未显示 | MakeTempCardInDrawPileAction；衍生 Omega |
| `Burn` | STATUS/COMMON | RED, BLUE | ironclad:burn 生命周期/显示；defect:burn 生命周期/显示 | 回合末生命周期；源依赖 DamageAction |
| `Dazed` | STATUS/COMMON | RED | ironclad:dazed 生命周期/显示；silent:dazed 生命周期/显示；defect:dazed 生命周期/显示；watcher:dazed 生命周期/显示 | 源规定空操作/生命周期 |
| `Expunger` | ATTACK/SPECIAL | PURPLE | N，未定义/未获取/未显示 | DamageAction / ExpungeVFXAction |
| `FameAndFortune` | SKILL/SPECIAL | PURPLE | N，未定义/未获取/未显示 | GainGoldAction |
| `Insight` | SKILL/SPECIAL | PURPLE | watcher:insight 生命周期/显示 | draw |
| `LiveForever` | POWER/SPECIAL | PURPLE | N，未定义/未获取/未显示 | PlatedArmorPower / ApplyPowerAction |
| `Miracle` | SKILL/SPECIAL | PURPLE | watcher:miracle 生命周期/显示 | energy |
| `Omega` | POWER/SPECIAL | 特殊牌链 | N，未定义/未获取/未显示 | OmegaPower / ApplyPowerAction |
| `Safety` | SKILL/SPECIAL | PURPLE | watcher:safety 生命周期/显示 | block |
| `Shiv` | ATTACK/SPECIAL | GREEN | silent:shiv 生命周期/显示 | damage |
| `Smite` | ATTACK/SPECIAL | PURPLE | watcher:smite 生命周期/显示 | damage |
| `ThroughViolence` | ATTACK/SPECIAL | PURPLE | watcher:through_violence 生命周期/显示 | damage |
| `Void` | STATUS/COMMON | BLUE | defect:void 生命周期/显示 | 抽到时生命周期；源依赖 LoseEnergyAction |
| `Wound` | STATUS/COMMON | RED | ironclad:wound 生命周期/显示 | 源规定空操作/生命周期 |



源中另有事件SPECIAL：Ghostly(Apparition)、Bite、J.A.X.、RitualDagger，未因跨色/事件合法性而静默排除；它们不属于上述职业直接生成闭包。当前各Profile均无这四项本地定义，完整事件/跨色获取仍欠实现。无色普通/罕见/稀有共享池、全部诅咒/遗物/药水另有总目录，不计作四职业常规75牌。

## 本轮证据分层与未完成检查

本表引用父线程当前执行报告与既有测试入口；本账本只实际执行双版Capability导出与源hash核验，没有重跑测试套件。组件数、真实core数、显示变体数与独立牌数分别记账，不能相加倒推覆盖。

| 专项 | 当前报告 | 可证明的范围 | 证据入口 |
| --- | --- | --- | --- |
| 战士状态/消耗扩展 | root Core定向29组通过 | Evolve/Fire Breathing/伤害与消耗计划等真实入口；不推出最后9张也实现 | tests/lua/warrior_status_build.lua |
| 机器人工程牌 | root Core定向63组通过 | 逐球、X费、Claw等当前已接片；不能将未接Buffer/最终候选也计入 | tests/lua/defect_engine_build.lua |
| 猎人策略牌 | root Core定向60组通过 | 当前弃牌、费用、Choke/相关阶段真实Core | tests/lua/silent_tactics_build.lua |
| 观者流转牌 | root Core定向27组通过 | stance、衍生牌与回合Power当前片 | tests/lua/watcher_flow_build.lua |
| 四张检索 | root报告检索6＋13组通过，组件29组通过 | 真Core与组件分层；UID、选择、恢复/代次及不触发draw的边界 | tests/lua/retrieval_cards.lua、pile_choice.lua |
| phase4显示 | root报告21组／512变体通过 | 真BattleUI/DeckUI适配；512含基本升级/状态/特殊项，不是256张职业牌 | tests/lua/phase_four_presentation.lua |
| 旧165冻结树整体 | JS1349、Lua262、Python22全部通过，597文件hash冻结 | 仅证明旧165输入；不能替代当前238开发树整体check | 父线程旧sts-triggers冻结验收记录 |
| 当前238开发树整体 | 尚在修旧UI弃牌顺序测试；Profile duplicate Miracle已修 | 专项通过保持有效；当前fullcheck与平台实机仍未认证 | 父线程sts-flow当前报告 |

此前165账本的待收尾C项已由旧165冻结树的专项与完整检查补足；本238账本仍不把未接的phase5候选认定为可执行。当前完整自然流派、源奖励/商店概率、原生UI/平台实机没有因卡牌数量提高而自动通过。旧自然seed路线只对各自冻结卡池有效，238池不继承相同奖励、地图路径或掉落概率。

## 主要缺口与交付边界

1. ironclad 66/75：仍缺 Armaments, Double Tap, Dual Wield, Feed, Havoc, Infernal Blade, Juggernaut, Searing Blow, Sword Boomerang。这些ID继续在完整母表标N；若有phase5候选模块，也未因此计数。
2. silent 61/75：仍缺 Venomology, Bullet Time, Burst, Corpse Explosion, Distraction, Doppelganger, Endless Agony, Masterful Stab, Night Terror, Phantasmal Killer, Setup, Tools of the Trade, Well Laid Plans, Wraith Form v2。这些ID继续在完整母表标N；若有phase5候选模块，也未因此计数。
3. defect 56/75：仍缺 All For One, Amplify, Buffer, Creative AI, Echo Form, Fission, Force Field, Genetic Algorithm, Hello World, Machine Learning, Reboot, Rebound, Redo, Recycle, Scrape, Self Repair, Static Discharge, Undo, White Noise。这些ID继续在完整母表标N；若有phase5候选模块，也未因此计数。
4. watcher 55/75：仍缺 Alpha, Blasphemy, Conclude, ConjureBlade, DeusExMachina, DevaForm, Establishment, ForeignInfluence, Wireheading, Judgement, LessonLearned, MasterReality, Meditate, Omniscience, Ragnarok, SpiritShield, Swivel, Vault, WaveOfTheHand, Wish。这些ID继续在完整母表标N；若有phase5候选模块，也未因此计数。
5. 共238/300，剩62张；另有特殊/状态/事件跨色生成依赖。完整母表不缩小目标，Capability不证明全部流派或自然成型。源卡池顺序研究已提供完整候选与JRE假设，但本地奖励仍受限，部分获取、稀有度、商店及完整遗物/药水联动概率未按原版认证。
6. 检索modal、代次、共享回合顺序、对象引用回滚和终态边界须保留独立真实Core证据；显示可绘制也不等于原生输入/Windows/手机实机已完成。当前内容仍为未发布实验Profile。

## 重复生成方法

1. 在目标输入树运行 `python tools/oracles/sts1_card_catalog_extract.py --output /tmp/sts-coverage-registration.json`；与保存的registration.json逐对象比较，核ZIP/CardLibrary/逐卡SHA。不要修改锁定来源。
2. 用Fengari加载同树abyss_data、CharacterProfiles.prepare与Capability.isImplemented，分别枚举default/ironclad/silent/defect/watcher，输出每个card.id/sourceId/sts_name/type/rarity/color，以及合并upgrade后的双版Capability。只读返回副本，不改数据文件。
3. 以explicit sourceId优先，其次源ID=sts_name、源Java类转snake_case或源ID小写匹配；基础红Strike/Defend显式映射Strike_R/Defend_R。限制在当前职业色及已知COLORLESS/CURSE内，拒绝零匹配/多匹配；不能靠目录数量填空。
可重复本地导出：在目标树将下面Lua作为Fengari的`-e`输入或临时文件运行，stdout保存TSV；它只prepare数据副本并读取Capability：

```lua
package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local P=require('abyss_character_profiles');local C=require('abyss_card_capability');local D=require('abyss_data');local Copy=require('abyss_combat').copy
local function ops(card)local a={};for _,e in ipairs(card.effects or {}) do a[#a+1]=e.op..(e.status and ':'..e.status or '')..(e.mode and ':'..e.mode or '')end;return table.concat(a,',')end
for _,p in ipairs({'default','ironclad','silent','defect','watcher'})do
 local d=p=='default' and D or P.prepare(D,p)
 for _,c in ipairs(d.cards.cards)do local u=Copy(c);for k,v in pairs(c.upgrade or {})do u[k]=v end
 print(table.concat({p,c.id,c.sourceId or '',c.sts_name or '',c.type,c.rarity,c.color or '',tostring(C.isImplemented(c)),tostring(C.isImplemented(u)),ops(c),ops(u)},'\t'))end
end
```

4. 源四组按registrationGroup/color和rarity分别计数；SPECIAL及其directCardDependencies传递闭包独立统计。当前源母集可用下面的复算片段验证：

```python
import json, collections
r = json.load(open('/tmp/sts-coverage-registration.json'))['registration']
for color in ('RED','GREEN','BLUE','PURPLE'):
    cards = [c for c in r if c['color'] == color]
    print(color, len(cards), dict(collections.Counter(c['rarity'] for c in cards)))
assert sum(c['color'] in ('RED','GREEN','BLUE','PURPLE') for c in r) == 300
```

5. 对“P/U/自然获取/实机”等阶段只能读取对应测试与本轮日志证据，不可由Capability boolean自动升级为通过。此账本的依赖动作名称仅从锁定源构造引用提取为事实，未把原始方法体复制到仓库。
