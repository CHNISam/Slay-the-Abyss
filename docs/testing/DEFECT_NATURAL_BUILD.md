# 机器人56牌池的自然构筑与四房连续战斗

当前 `tests/lua/defect_natural_build.lua` 适配 `/workspace/sts-flow` 的56张常规蓝牌Profile（含4张基础牌，Engine19及真实Hologram/Seek已启用），脚本对56作精确断言。最后19张Final模块在本任务中冻结，未修改、未激活，也不宣称75张全量完成。

## 真实入口及范围

每例从 `Run.new(data, seed, {experimental=true,character='defect'})` 的75HP、10张初始牌、破损核心和3球位出发。核对4打击、4防御、引雷、双重释放。全部使用真实 `startRoomCombat/play/endTurn/rewardOptions/claimCardReward/claimGoldReward/leaveCombatRewards`。

不写HP、能量、敌人、牌组、能力、球或RNG，不替换核心函数，不塞奖励。每次真实完成奖励后的 `run.floor=run.floor+1` 是唯一入口捷径。证明房间入口及自然领取／连续实战，**不证明完整地图导航、首幕通关、PC掉落概率或Windows／平台实机**。奖励来自本应用已实现子集的受限池，不是完整原版概率轨迹。

策略固定、非最优：最低HP合法目标、脚本优先级打真实手牌，无可用牌才endTurn。新Engine牌采用固定优先级，并跳过无冰霜历史的Blizzard、已有格挡的AutoShields、抽牌堆不足4的Aggregate；Sunder目标HP>24时降低优先级。本轮路线没有领取Hologram/Seek，不把其候选出现当作自然使用证据。所有选择都是读取状态，没有改变概率或算法。

来源继续固定 [319009d5df0a82d9fb0f23cc22322286c6a87ec0](https://github.com/aeubanks/sts/tree/319009d5df0a82d9fb0f23cc22322286c6a87ec0)，社区声明V2.3.4而未做原版二进制认证。卡牌／球和生命周期证据见 [DEFECT_ENGINE_BUILD.md](../rules/DEFECT_ENGINE_BUILD.md)、[DEFECT_ORB_POWERS.md](../rules/DEFECT_ORB_POWERS.md)，不把本地黄金值称为PC实机黄金轨迹。

## seed5：寒击、循环与凝神的连续构筑

| 房间 | 遭遇 | 胜后HP | 回合 | 正常领取 | card RNG | shuffle RNG | ai RNG |
|---|---|---:|---:|---|---:|---:|---:|
| 1 | Jaw Worm | 62 | 3 | Cold Snap | 5 | 2 | 4 |
| 2 | Cultist | 58 | 3 | Loop | 5 | 2 | 3 |
| 3 | Small Slimes | 50 | 3 | Defragment | 2 | 2 | 5 |
| 4 | Gremlin Gang | 33 | 4 | Stack | 9 | 2 | 6 |

完整候选序列逐房精确断言：`consume,cold_snap,reinforced_body`；`loop,rainbow,glacier`；`defragment,chill,charge_battery`；`meteor_strike,capacitor,stack`。每场真实领取一张，永久牌组10→14。

实际自然打出Cold Snap4次、Loop2次、Defragment1次。最后领取的Stack没有在这四场用出，未据此声称其实战完成。

第4场第2回合自然打出Loop与Defragment。第3回合开始，循环的首闪电被动名义值4，实际击杀仅剩3HP的Wizard Gremlin，失血3；第4回合开始，首闪电实际失血4。两次均在普通抽牌前，事件帧手牌为空，首球与实际被动的lightning类型一致，且正数实际敌方失血有精确断言。不是拿普通回合末闪电冒充Loop。

第4场第3回合，观察到集中1时冰霜被动实际格挡3，严格对应相邻真实block事件，并精确断言房间／回合／集中／格挡值。Loop新回合事件共2组、集中冰球事件共1条，均锁数量。

四胜后只进入第5场开局：HP33连续传入，上一场非零Loop／Focus清空，3球位和核心首个闪电重建，channel历史重置。没有第5胜声明。

## seed53：电动力学、冰寒与多目标闪电

| 房间 | 遭遇 | 胜后HP | 回合 | 正常领取 | card RNG | shuffle RNG | ai RNG |
|---|---|---:|---:|---|---:|---:|---:|
| 1 | Small Slimes | 58 | 3 | Electrodynamics | 5 | 2 | 5 |
| 2 | 2 Louse | 58 | 1 | Chill | 0 | 1 | 2 |
| 3 | Jaw Worm | 47 | 2 | Doom and Gloom | 0 | 1 | 2 |
| 4 | Exordium Wildlife | 47 | 2 | Streamline | 0 | 1 | 4 |

完整候选序列：`electrodynamics,streamline,go_for_the_eyes`；`blizzard,boot_sequence,chill`；`doom_and_gloom,meteor_strike,multi_cast`；`seek,streamline,auto_shields`。仍真实领取至14牌，不能把选项中的Seek当作已获得或使用。

Electrodynamics真实打出3次、Chill2次。共9条真实命令观察到电动力的闪电结算，其中4条命令有单次闪电对多个目标造成实际HP伤害；这些命令逐条核对cardRandomRng.counter及legacy seed不推进，新增牌的其它随机调用没有被当成闪电额外耗RNG。这里是**命令数**，与探索脚本数出的15条球事件／8条多目标球事件不同，不混用。

第2场仅一回合结束，第3/4场均两回合结束，具体HP、回合和三随机流黄金值不能被“仍胜利”代替。四胜后第5场仅检查开局HP47、电动力清空、核心闪电和各历史重建；没有执行或声称第5场胜利。

## 保留严格断言并适配来源变化

每场核连续HP与新战斗对象；Focus/Bias/Loop/Electrodynamics/EnergizedBlue/HeatSinks/Storm为空；3球位与唯一Lightning；新战斗channel历史lightning=1，其余=0；开局cardRandom计数0和打牌历史空。各场胜后精确核HP、回合、card/shuffle/ai计数、完整三个候选的次序、永久牌组增加及真实使用／机制事件数量。

较新共享核心采用通用PowerSchedule构造turn-start队列，不再通过旧兼容wrapper发 `orb_start_turn_powers` 聚合marker。原扫描器的loop_hooks=0因此不能说明无Loop。本轮不补造聚合事件，改以**新回合pre-draw真实orb_effect、首球、层数、相邻实际伤害／格挡和正数HP损失**验证并锁定两条精确Loop记录，机制断言没有降成只检查status存在。此Loop路线没有Plasma，普通球开始阶段不会冒充这些额外闪电。

先原样运行35池旧测试，明确失败 `56 ~= 35`。随后仅在临时探针将数量检查改成56以到达原seed15/45，其原完整候选断言仍明确失败：seed15首房实际 `biased_cognition,heat_sinks,double_energy`，旧期望 `ftl,charge_battery,boot_sequence`；seed45实际 `turbo,consume,multi_cast`，旧期望 `darkness,electrodynamics,turbo`。没有跳过旧HP／回合／候选断言造绿，旧35／19版完整文档和数值保留在下方历史区。

有界探索仅种子1..64，分1..32与33..64两批（约22.4秒＋22.2秒），均使用真实Run命令、相同状态只读策略和floor边界捷径，没有改生成器或估计概率。最终测试只跑固定seed5/53，不扫描或重抽。探索临时脚本的统计只用于选输入，最终PASS以正式严格断言为准。

## 当前验证与快照

```sh
node scripts/test-lua.mjs tests/lua/defect_natural_build.lua
```

真实输出 `DEFECT_NATURAL_BUILD_PASS 2 restricted_pool=true profile_cards=56 run_entry_harness=true`，退出0，约2.04秒。两个独立新局各四胜，另各看一次第5房开局。最终运行前后104个私有Lua／构建数据／基础数据／本测试文件SHA256一致。仅改本测试及本文；未动Final／Engine模块、共享root、Backlog，没有全量检查、提交或推送。

下表是**本次56池私有执行快照**，root仍在开发，不代表后续集成树最终冻结指纹：

| 输入 | SHA256 |
|---|---|
| `src/lua/abyss_character_profiles.lua` | `370a0e905d6d8373f73034a8890c023175b1466d4a5ec1db18314b4a4a6c9772` |
| `src/lua/abyss_defect_engine_cards.lua` | `232148a9e27de46ec26de0f57bd4dd66e52a2db0544825ced0150e6d9666f3e4` |
| `src/lua/abyss_retrieval_cards.lua` | `352d25a7adbacb79a8f1f262d0a055cffa77676e389abfd3036fb184ef24e307` |
| `src/lua/abyss_combat.lua` | `39ecc7ef8e576627f3608ce8c80d597e9560b0aec4851bf4849e6d202b439d80` |
| `src/lua/abyss_actor.lua` | `4ebc0ad541f8e9c47f441fd22524b93f4339922efb615d72bd82b898e63ac275` |
| `src/lua/abyss_turn_powers.lua` | `e5c7183a772693629a7b132befd08c21d1703e5b5e24757c6f74bfe060d58c61` |
| `tests/lua/defect_natural_build.lua` | `f2c4db1285805a6da811eddff4f9fec04e4064f6363f2bb586ac70ba3db731ce` |

## 历史35池及更早版本：完整保留

以下“当前／本轮”均属于各历史版本，不是56池本轮结果；原数值、来源声明和失败历史仍保留。56池本轮只以前述seed5/53为准。

### 机器人自然获取与四房连续战斗：35张职业牌

本轮适配 `tests/lua/defect_natural_build.lua`，以 `/workspace/sts-triggers` 共享核心和职业模块的私有快照运行。当前实验 Defect Profile 的常规职业牌共35张（含4张基础牌；状态、诅咒不计），脚本对此数量作精确断言。此处不是完整75张蓝牌验收。

#### 入口、来源和边界

全部场景从 `Run.new(data, seed, {experimental=true, character='defect'})` 的75生命、10张初始牌、破损核心和3球位开始。核对初始4打击、4防御、引雷、双重释放。真实调用 `Run.startRoomCombat`、`Run.play`、`Run.endTurn`、`Run.rewardOptions`、`Run.claimCardReward`、`Run.claimGoldReward`、`Run.leaveCombatRewards`。

不改写生命、能量、敌人、牌组、球、增益或随机流，不替换核心函数，不塞奖励。每次真实完成奖励后唯一进度捷径是 `run.floor = run.floor + 1`；因此证明房间入口与自然构筑衔接，**不是地图导航、第一幕通关、原版概率或平台实机验收**。本应用目前从已实现子集的受限奖励池提供牌，未复刻完整PC掉落分布。

规则来源继续固定社区反编译 [319009d5df0a82d9fb0f23cc22322286c6a87ec0](https://github.com/aeubanks/sts/tree/319009d5df0a82d9fb0f23cc22322286c6a87ec0)，来源宣称V2.3.4 (12-18-2022)，没有正版PC二进制认证。具体牌与球来源指纹见 [DEFECT_UTILITY_BUILD.md](../rules/DEFECT_UTILITY_BUILD.md)、[DEFECT_ORB_POWERS.md](../rules/DEFECT_ORB_POWERS.md)。这些输入没有把当前种子伪装成PC黄金轨迹。

策略固定：选择最低生命合法目标，以脚本固定优先级打出真实手牌；没有可出牌才结束回合。奖励仅领取表中的精确候选，候选缺失即失败，并且现在连完整三个候选的次序都逐房精确断言，不重抽或替换。

#### seed15：自然FTL、凝神和冰川

| 房间 | 遭遇 | 胜后HP | 回合 | 正常领取 | card RNG | shuffle RNG | ai RNG |
|---|---|---:|---:|---|---:|---:|---:|
| 1 | 2 Louse | 74 | 2 | FTL | 2 | 1 | 3 |
| 2 | Small Slimes | 62 | 3 | Defragment | 3 | 2 | 4 |
| 3 | Jaw Worm | 51 | 2 | Glacier | 3 | 1 | 3 |
| 4 | Looter | 47 | 3 | Cold Snap | 3 | 2 | 3 |

对应完整候选依次为 `ftl,charge_battery,boot_sequence`；`compile_driver,defragment,barrage`；`charge_battery,glacier,ball_lightning`；`beam_cell,coolheaded,cold_snap`。永久牌组10→14张。

凝神在第3场第2回合、第4场第2回合各自然打出一次，冰川在第4场自然打出一次，FTL共自然打出3次。第4场观察到4条集中1下冰霜实际格挡3的 `orb_effect`，各自与相邻真实 `block` 事件金额一致。末次领取的Cold Snap用于证明真实奖励写入，不声称已经在这四场用出；集中冰球实战证据由已经用出的Glacier提供。

结束四场后仅正常进入第5场开局：HP47继承，上一场非零集中清空，所有相关能力为空，3球位和核心首个闪电重建。没有执行或声称第5场胜利。

#### seed45：自然电动力学和循环叠加

| 房间 | 遭遇 | 胜后HP | 回合 | 正常领取 | card RNG | shuffle RNG | ai RNG |
|---|---|---:|---:|---|---:|---:|---:|
| 1 | Cultist | 75 | 2 | Electrodynamics | 5 | 1 | 2 |
| 2 | Small Slimes | 75 | 3 | Loop | 1 | 2 | 5 |
| 3 | 2 Louse | 63 | 2 | Loop | 0 | 1 | 4 |
| 4 | Blue Slaver | 44 | 3 | Barrage | 2 | 2 | 3 |

对应完整候选依次为 `darkness,electrodynamics,turbo`；`darkness,loop,turbo`；`heat_sinks,capacitor,loop`；`biased_cognition,barrage,reprogram`。永久牌组10→14张。电动力学实际自然打出3次、循环3次；最后领取的Barrage未声称已在四场用出。

- 第3场第2回合，循环1产生1次额外首球闪电被动，实际总生命伤害5（只记录真实失血，不把被格挡部分算失血）。
- 第4场第3回合，循环2产生2次额外首球闪电被动，实际生命伤害6。两条钩子事件均在普通抽牌前，事件帧手牌为空；该例没有获取等离子且所有球均为闪电，不能用普通等离子被动冒充循环。
- 共7条实际命令观察到电动力闪电结算，均逐命令核对独立卡牌随机计数与legacy seed未被闪电目标选择推进；其中2条命令有单次闪电真实伤害命中多个目标。这里统计的是命令，不是15条球事件或5次多目标球事件，避免混淆计数。
- 完成四场后正常进入第5场开局：HP44继承，上一场非零循环和电动力清空，集中／偏差为空，3球位、核心闪电重建；没有第5场胜利声明。

#### 严格断言与旧失败的处理

每场都验证生命从上一场实际结算连续传入；战斗对象重新构造；集中、偏差、循环、电动力、充电、散热片、雷暴没有跨战继承；开局card RNG为0、当回合打牌历史为空；3球位、唯一核心闪电正确。胜后HP、回合、三个随机流计数、完整候选次序、奖励落入永久牌组、实际能力使用次数和机制事件次数都有精确黄金值，脚本不会扫描种子。

本轮先原样运行19张版本的最新测试：seed2首房明确失败 `fixed naturally offered card missing: cold_snap`；随后独立运行保留seed32原断言的临时副本，首房明确失败 `fixed naturally offered card missing: loop`。未跳过或放宽这些断言，也没有改奖励算法硬过旧结果。牌池从19扩至35后，旧固定奖励轨迹不再是当前池的有效输入；旧数值和证据在下方历史存档保留，不能冒充本轮通过。

随后只做固定策略、有界种子1..64的离线探索（约29.4秒），选出seed15与45。探索也只调用真实Run入口及奖励命令、同一floor边界捷径，无状态改写，没有估计概率。最终测试只执行这两个固定新局，不再搜索种子。新案例既保留精确生命／回合／奖励失败保护，还增加完整候选、三随机流、实际使用／事件数量的精确断言。

#### 当前验证

```sh
node scripts/test-lua.mjs tests/lua/defect_natural_build.lua
```

输出 `DEFECT_NATURAL_BUILD_PASS 2 restricted_pool=true profile_cards=35 run_entry_harness=true`，退出0，约1.45秒。两个独立新局各4胜；每例额外只查看第5场开局。最终定向执行前后91个私有快照Lua／构建数据／基础卡牌与规则文件SHA256一致。没有运行全量检查、改共享核心、提交或推送。

以下是**本次测试私有快照**的输入指纹，供复核本次证据；root仍在开发，不表示最终冻结集成树的指纹：

| 输入 | SHA256 |
|---|---|
| `src/lua/abyss_character_profiles.lua` | `531923d5d2e7a5e2ac4ea6ea678745a3659ccbeacac4077a043642369a4980d6` |
| `src/lua/abyss_defect_utility_cards.lua` | `715f66ed0adba0c5da4f8702dd42b88d35da04daad8d9d6a35c9013bf9b2dc09` |
| `src/lua/abyss_card_triggers.lua` | `c5fd1f88b144075ec61bf682e938bcc0c13c8d78277c74f8c5dcee05567403bb` |
| `src/lua/abyss_combat.lua` | `80a9a40f8ce57bd3ec4b1c830b96faf277f54ac7b6db3872e637968cce746629` |
| `src/lua/abyss_run.lua` | `d582b3609f438a3e314dd7fd53a5d4115b1ddbd4bff50034c086741275a03506` |
| `src/lua/abyss_orb_powers.lua` | `a8da0da9e160a29297f21132d405dcdda62df8a40b74e51d9bb15de9f47164d4` |
| `src/lua/abyss_orbs.lua` | `9d99b666f727483f10c1bb0d8c879d10b0813d90804af7ee1a9e00a55532208f` |

#### 历史19张版本存档

以下完整保留前轮文档。其中“本轮”均指19张版本那一轮，seed2/32及其数值不适用于当前35张版本；对应冻结树未被本任务写入。本轮适配结果仅以前述seed15/45为准。

##### 机器人自然获取与连续战斗

本轮测试位于 `tests/lua/defect_natural_build.lua`。输入为基于 develop `877c4af` 的未发布实验实现，机器人 Profile 当前有19张常规职业牌，包含新增 Loop（循环）和 Electrodynamics（电动力学）。默认发布范围和完整75张卡池未据此验收。

###### 测试入口与约束

每例都从 `Run.new(data, seed, {experimental=true, character='defect'})` 创建原版75生命、10张初始牌、3球位和破损核心的新局，随后使用实际 `Run.startRoomCombat`、`Run.play`、`Run.endTurn`、领取卡牌／金币和离开奖励命令。

测试没有改写生命、能量、敌人、初始／永久牌组、增益或随机流。唯一进度捷径是完成每场奖励后 `run.floor = run.floor + 1`，因此它证明房间入口、自然领取与连续战斗；不是地图导航、第一幕通关或平台实机证据。当前奖励来自应用实现子集，不能把这些种子称为原版PC掉落概率或黄金随机轨迹。

出牌策略固定：选择最低生命的合法敌人；按卡牌优先级从当前真实手牌选出可以使用的牌，没有可用牌才结束回合。不注入牌、不保证最优决策。奖励按已记录的固定候选领取，候选不存在就失败，不重抽或替换奖励。

###### 固定案例

###### seed 2：集中冰球与电动力

| 已完成房间 | 来源遭遇 | 胜后生命 | 回合数 | 正常领取 |
| --- | --- | ---: | ---: | --- |
| 1 | Cultist | 69 | 3 | Cold Snap |
| 2 | Jaw Worm | 56 | 3 | Electrodynamics |
| 3 | Small Slimes | 49 | 2 | Defragment |
| 4 | Blue Slaver | 37 | 3 | Biased Cognition |

永久牌组10→14张。自然取得的 Cold Snap 实际打出2次、Electrodynamics 2次、Defragment 1次。

- 第三场真实 Dualcast 的闪电唤起伤害命中多个敌人，独立 `cardRandomRng.counter` 为 `0→0`。
- 第四场集中1时观察到固定冰霜被动格挡3，以及唤起格挡6；各自与相邻真实 `block` 事件一致。
- 共4条包含电动力闪电结算的实际命令，卡牌随机计数与 legacy seed 均未被闪电目标选择推进。
- 完成四场后，仅正常进入第五场开局，验证此前非零集中与电动力不继承、偏差为空等战斗状态重建，生命37正确继承、3球位和核心首个闪电正确。**没有执行或声称第五场胜利。**

###### seed 32：循环叠加与多目标闪电

| 已完成房间 | 来源遭遇 | 胜后生命 | 回合数 | 正常领取 |
| --- | --- | ---: | ---: | --- |
| 1 | Jaw Worm | 64 | 2 | Loop |
| 2 | 2 Louse | 64 | 2 | Electrodynamics |
| 3 | Cultist | 58 | 3 | Loop |
| 4 | Large Slime | 51 | 4 | Biased Cognition |

永久牌组10→14张。自然取得的 Loop 实际打出4次、Electrodynamics 2次。

- 第四场真实回合开始分别触发1次、2次首球额外被动，共3次额外闪电被动；两次开始阶段分别造成6、12点实际总生命损失。事件帧中手牌仍为空，确认发生于正常抽牌前。
- 该牌组没有取得等离子牌；测试同时核对球均为闪电，因此开始阶段的额外效果没有被普通等离子被动冒充。
- 4条包含电动力闪电的实际命令均保持独立卡牌随机计数；其中3条命令观察到单个闪电结算命中多个敌人的实际生命伤害。
- 各场开局都验证循环、电动力、集中和偏差不跨战继承，保留3球位与核心初始闪电。

###### 种子与历史证据

较早17张常规蓝牌的冻结 `/workspace/sts-ui` 使用 seed1 获得 Cold Snap／Defragment／Defragment／Coolheaded。本轮先原样运行，确认加入 Loop／Electrodynamics 后首战已经不提供 Cold Snap，旧测试以“固定自然候选缺失”失败，未改奖励硬过。旧冻结树没有改动。

为选择可重复案例，离线固定策略有界扫描1至64。扫描只选择再现输入，没有估计原版概率，也没有修改任何生成算法；固定测试不执行扫描。最后保留 seed2 和 seed32，分别覆盖集中冰球、电动力与循环的实际自然使用，而没有为了把所有证据塞进一例而捏造牌组。

###### 普通回合末弃牌顺序修正

同步最新共享核心后，先保留旧黄金值实际运行：seed2全部断言通过；seed32第四场仍四回合胜利、循环额外伤害6／12和卡牌随机计数2→2均保持，但生命为51，旧56断言明确失败。原因是固定来源普通回合末全弃应按 `getTopCard` 从手牌尾部逐张移出；修复前的向前批量弃牌改变了后续洗牌前的牌堆顺序。

本次只把seed32第四场精确生命黄金值更新为51；前3场生命、所有回合数、奖励、真实效果、抽牌前时点和独立随机流断言均未放宽，也未重新扫描种子。共享修复同时按虚无→普通弃牌→恢复保留牌处理，本测试没有把外部 `Collections.shuffle` 轨迹称为已认证。旧56保留为本段历史记录，不再冒充当前核心结果。

###### 验证

```sh
npm run build:data
node scripts/test-lua.mjs tests/lua/defect_natural_build.lua
```

本轮定向结果：`DEFECT_NATURAL_BUILD_PASS 2`，退出码0，1176ms；两个独立新局各四场胜利。最终执行前后84个Lua源码／基础卡牌与规则数据输入SHA256一致，`git diff --check`通过；未运行完整套件。该脚本使用真实核心，没有替换出牌、敌方行动、随机、抽牌、奖励或球结算函数。
