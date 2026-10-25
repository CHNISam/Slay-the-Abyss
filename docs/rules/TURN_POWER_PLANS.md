# 多阶段回合 Power 计划

## 独立交付边界

2026-10-25 phase4 私树组件；读取 `/workspace/sts-flow` 的共享 Core 与 family 模块，不改 Combat、Actor、Orbs 或默认卡池。新增 `abyss_turn_powers.lua` 和 `tests/lua/turn_power_plans.lua`，并从 `abyss_orb_powers.lua` 抽出 `prepareStart`；旧 `startTurnPower` 保留执行与事件接口。本文不宣称新阶段计划已经接入共享 Core。

固定资料为 [aeubanks/sts@319009d5df0a82d9fb0f23cc22322286c6a87ec0](https://github.com/aeubanks/sts/tree/319009d5df0a82d9fb0f23cc22322286c6a87ec0)。只读本地已校验归档，SHA-256 `3f42bd7dde08126a9a8a02fc8eed8856c7b8b0dda551f50c62ced838e41ed458`；没有复制 Java 实现。镜像声称 V2.3.4，未经官方 JAR 认证，不是原版客户端或平台实测。

排序与 recharge 的构造边界见 [POWER_SCHEDULE.md](POWER_SCHEDULE.md)：默认 priority=5，同优先级保留获得序；DrawCardNextTurnPower 为20。GAM350 普通 Draw 构造函数同步引发基础补能和 onEnergyRecharge，之后才真正加入普通 Draw，随后构造 post-draw hooks。已有 pre-draw 动作尚未执行；不能把每个阶段分开运行、清空队列后再进入下一阶段。

## API 与宿主接线

`abyss_turn_powers` 公开三个阶段过滤集 `phases.turn_start`、`phases.energy_recharge`、`phases.turn_start_post_draw`，以及它们的并集 `scheduledIds`（18个本地 ID）。枚举使用 `PowerSchedule.list(state, phaseFilter)`，不会因无此 hook 的手设 Strength/Weak/Artifact 猜测获得序。

- `prepareStart(state)`：按 Power priority/获得序构造开回合动作，最后附加普通球的 start hooks。计划不执行 Focus、格挡、补能或生成；Loop 调用 Dark.onEndOfTurn 所对应的 stored 增长按源码同步发生，仍处于构造阶段。
- `onEnergyRecharge(state)`：宿主已完成基础补能后调用。Energized 两种数量立即增加到 energy；返回的移除与 Collect 生成/减量尾部仍须入队。不会提前移除 Power。
- `preparePostDraw(state)`：普通 Draw 条目加入队列后、真正抽牌之前调用。Devotion 的 `Mantra.prepareGain` 此时递增 mantraGained，实际 Mantra/姿态动作随后执行。

返回数组均为 `{kind='effect', effect={...}, turnPower=id}`，不含 actor、函数、闭包或队列对象。family 的 `planHook` 用于已支持的正数业务；新增 adapter 明确保留 family 原先跳过的零成员分支，没有声称 family 自身已支持这些分支。宿主应按下列构造顺序组装**同一个**队列并运行：

```text
prepareStart 构造（包含 Dark 同步增长）
基础 energy.recharge；onEnergyRecharge 即时补能并构造尾部
依次加入 pre actions、recharge tail、普通 Draw 条目
preparePostDraw 构造并追加 post actions（此时 Mantra 构造计数已变化）
最后才开始运行队列
```

宿主负责每个新 action 的终态保留/清理、死亡停止、完整事件与事务。三个构造步骤内可能已有 Dark stored、事件、即时能量与 mantraGained 改变；后续错误必须由外层快照统一回滚，不能只撤销返回的数组。组件不在内部建立第二套事务或执行队列。

真正成功的 Actor/特殊 Apply 必须调用 `PowerSchedule.recordApplied(state, actor, id, beforeRawAmount)`；失败 Artifact 应用不登记，叠层保留旧 slot。实际移除时调用 scheduler.remove；Focus 精确零移除、Devotion/Corruption 等特殊路径也由宿主接线。不得把计划构造、计划中的 Remove 或数值变成零直接当作成员已经移除。

## 已构造的动作

| 阶段 | 本地成员 | 构造或即时行为 | 固定来源行号 |
| --- | --- | --- | --- |
| pre | berserk | BOT energy(amount)，包括0 | BerserkPower:39–41 |
| pre | infinite_blades | makeTempCard Shiv，未升级，数量快照；实际生成时处理 Accuracy/满手 | InfiniteBladesPower:30–34 |
| pre | bias | gainStatus Focus(-amount)，包括0；应用仍经过 Artifact | BiasPower:31–33 |
| pre | loop | 按次数构造首球 start/end，被动数值保存旧 Focus；Dark stored 同步增长 | LoopPower:29–35；Dark:56–63 |
| pre，所有Power之后 | 普通Plasma | 每个 Plasma 排一次被动 energy；普通球不是Power成员 | Plasma:57–59 |
| pre | flame_barrier | removeStatusPower；0仍排移除 | FlameBarrierPower:56–57 |
| pre | next_turn_block | 固定 block(amount)，再removeStatus；0也保留两个动作 | NextTurnBlockPower:42–46 |
| pre | battle_hymn | makeTempCard Smite，未升级，数量快照 | watcher/BattleHymnPower:30–34 |
| pre | energy_down | loseEnergy(amount)，包括0 | watcher/EnergyDownPower:52–54 |
| pre | wrath_next_turn | 存在即ChangeStance Wrath，然后removeFlowPower | watcher/WrathNextTurnPower:32–34 |
| recharge | energized / energized_blue | 同步加能，BOT removeStatus | EnergizedPower:46–49；EnergizedBluePower:46–49 |
| recharge | collect | 生成1张Miracle+；amount<=1排移除，>1排减1 | CollectPower:50–58 |
| post | demon_form | gainStatus Strength(amount)，包括0 | DemonFormPower:33–35 |
| post | noxious_fumes | 对构造时存活敌人的ID逐一排turnPoison；数量与新Power上限快照 | NoxiousFumesPower:32–38 |
| post | devotion | 无Mantra且amount>=10只构造Divinity；否则Mantra.prepareGain | watcher/DevotionPower:35–40 |
| post | brutality | draw(amount)，loseHp(amount)，0也保留 | BrutalityPower:35–38 |
| post | draw_next_turn / draw_card_next_turn | draw(amount)后移除，priority20；0也保留 | DrawCardNextTurnPower:27、36–39 |

SourceZero 由成员存在判断，adapter 不以 amount>0 统一筛选。Collect 0 在固定源码中也先构造一次 Miracle+，再走 `amount<=1` 的移除分支，不能无条件跳过。Noxious 0 仍构造 PoisonPower/ApplyPower，因此可消耗目标 Artifact；Demon Form 0 的 Strength 应用同样仍走对应 Power 类型规则。Loop 0 的 for 循环没有被动，属于该 hook 自己的语义。

WrathNextTurn 的源对象使用负数哨兵；本树 Watcher flow 的 typed application 将它转换为成员 marker=1。adapter 接受本地非负成员（包括受控0 fixture），不会把 -1 当作普通层数；所有未转换负值均拒绝。其他本切片 Power 也只接受已核查的非负本地数量。

`draw_next_turn` 与 `draw_card_next_turn` 是当前两个 family 对同一个源 DrawCardNextTurnPower 的本地别名，不是两个不同源 Power。本组件分别处理现有职业池的本地 ID；跨色同时获得时应统一 source ID/叠层归属，尚未完成，不能因组件中可枚举两个键而声称原作支持两个独立实例。priority20 必须由真实 status definition 提供，计划模块不静默改定义。

## 新 action 与旧球接口

宿主需解码两个新 op：

- `orbStart`：`effect.action` 保存球 kind、amount、hitAll，以及必要时的 targetId。执行前由宿主将 ID 找回当前 actor，再调用真实 Orbs.resolve；队列中始终不保存 actor。Lightning 选目标仍在 resolve 使用独立 cardRandomRng；Electrodynamics 的 hitAll 模式按构造时状态冻结。
- `turnPoison`：`{targetId, value, newPowerAmount=min(9999,value)}`，外层 `triggerPower='noxious_fumes'`。执行时检查目标/终态、Artifact；已有 Poison 成员按 raw value 叠层，新成员用构造好的 newPowerAmount。允许0；没有放宽 Envenom 的 cardTriggerPoison 合法正量边界，也不需要 Envenom 存在。

其余动作使用已有或 family 的 `energy`、`gainStatus`、`block`、`draw`、`loseHp`、`makeTempCard`、`loseEnergy`、`changeStance`、`applyMantra`、`removeStatus`、`removeStatusPower`、`removeFlowPower`、`reduceFlowPower`；宿主应复用共享执行器。生成动作在执行时调用真实卡牌创建流程，处理 Master Reality 尚未支持的拒绝边界、Accuracy、UID、满手溢出等，不能在计划构造时提前塞牌。

球模块新增 `OrbPowers.prepareStart(state, slot?)`。slot 为 `loop`、`bias` 或 `orbs`，供全局 Power 获得序交错调用；nil 用旧 Loop/Bias 顺序构造完整兼容计划。原 `startTurnPower(state, api)` 仍准备全部动作再执行，保留 `orb_start_turn_powers` 事件与旧调用者行为。

新通用获得序完备时优先使用其源排序。旧人工 fixture 若只有 Loop/Bias 相关 pre members、没有相关通用记录且已有完整 `orbPowerOrder`，复用这个已记录顺序，不修改它；不能由该二元顺序推导另一个 Berserk/BattleHymn 的位置。没有已知相对顺序的多个相关成员立即拒绝。旧通用单 Power 夹具 fallback 仍由 PowerSchedule 提供。未认证存档迁移、旧数组与新通用数组的任意混合修复或所有未来同优先级 Power。

## 验证与限制

实际执行 `tests/lua/turn_power_plans.lua` 得 `TURN_POWER_PLANS_PASS 25`；旧 `tests/lua/defect_orb_powers.lua` 得 `DEFECT_ORB_POWERS_PASS 27`。定向测试宿主使用真实 Actor、Combat.applyEffects、Build.makeCard、Orb、Mantra 与 Queue，显式实现尚未挂 Core 的 data-action dispatch，没有替换这些业务函数。测试覆盖 pre获得序、旧集中快照、Dark构造期增长、旧orb顺序拒绝边界、生成与Accuracy/满手、补能即时与尾部、Collect/普通Draw、Devotion计数、Noxious快照/Artifact/新旧Poison上限、两种priority20本地别名、死亡停止、零成员和合并单队列。

当前 silent family 的旧 draw_next_turn 定义尚未提供 priority20，本组件测试仅在 detached 夹具中显式标注已核固定源的20，不修改该仓库文件；其 owner 的真实定义修正与root集成需另验。测试手设数量/位置用于受控边界，不能证明自然获取、原作概率或跨色双别名合法性。测试宿主的死亡门槛也不能代替共享 Core 的完整战后选择性清理验收。

本轮没有修改共享 core、登记Backlog、提交或运行全量检查；真实 startPlayerTurn/endTurn 集成、独立RNG/对象引用回滚、全量回归及平台实机由主线程后续验证。

## 源文件 SHA-256

下表路径相对固定提交根目录，可用 GitHub固定提交链接逐文件复核；行号对应这些字节。

| 文件 | SHA-256 |
| --- | --- |
| powers/BerserkPower.java | `01ba3b8328aa0b0586267dc1103c0125f5878088467f4960828acd1e0571f1d8` |
| powers/InfiniteBladesPower.java | `44c1d371d62143fc1da3f88cbf59f9c8f0a7461372f5c0a3f2c96d3e70165e9c` |
| powers/BiasPower.java | `35a183a0b16abc9c95d135fa4873d74ee9fdb7395b16ea57da06caaf399abc6a` |
| powers/LoopPower.java | `58349487043b3185404e90282437d4ea7e1e2712b3a83b6285a7728bb26c5b8a` |
| powers/FlameBarrierPower.java | `2d428558a399d7bde4026092db001037a5bc73748fed25f9d4db40ef39e684bd` |
| powers/NextTurnBlockPower.java | `4e7e395a226e445681515dd3c69e612886f39d7d7acba7c4632dfcbcc9a51e49` |
| powers/watcher/BattleHymnPower.java | `c80a6d1b5821fee7aae75c268dc7423c8a0b099bfce129d89944e50fa23e1707` |
| powers/watcher/EnergyDownPower.java | `c8c9f2ee50fa43235155ece95fb4ad0b942d6dddf659824e3b69c79258ddb054` |
| powers/watcher/WrathNextTurnPower.java | `87e8452fefb0ea8d4a16d0128d9282795105aa88902f0dc452de39a606291258` |
| powers/DemonFormPower.java | `f33afd9cca41bba6824f42115b4b0110ed9856cf2ce825f4bc57461151d8ee65` |
| powers/NoxiousFumesPower.java | `add060dc8068d0b706b5503f52f72b73be92a70870e38d3587a98eabd7403559` |
| powers/watcher/DevotionPower.java | `310834768f7cb09fe0bd59826a1074ddc1871910c634bc8ee68135841853dc1d` |
| powers/BrutalityPower.java | `8a0021cd149d8ed520ed3cc4a52ae06932775b7591ab687ac26aa32edff35c48` |
| powers/EnergizedPower.java | `e827aec6f7a1561fa4c595d289713251f1e0f4e29d798d0b203c2e1b887859d0` |
| powers/EnergizedBluePower.java | `2b9e5cfc9c7e3155d5059f74142b6accf4cdad28904cf21c7a23ecfbe8e181d3` |
| powers/CollectPower.java | `deff9876018816d1043bbf4de3eed9aa3ac2d4c246624029c5411a11dae5a877` |
| powers/DrawCardNextTurnPower.java | `7f43052db3e11d82b83b24753cac3eedd81a162eedf20465288a16bda2118407` |
| powers/watcher/MantraPower.java | `a28abb19643bcce1c9899e1ac72f0f8bf966da4b2644de1c130e32c8986fa5af` |
| orbs/Plasma.java | `3758d5402fd24491fae363bf64fc4e871e917f5f89d44d2265840c96db648cce` |
| orbs/Dark.java | `610fccbaf45b74bf4c151982e07c599f940a295027271e478a4e8b3e46def373` |
