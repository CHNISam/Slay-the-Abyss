# TASK-16.1.2 · 末敌死亡后的已排队效果清理

## 有限问题与修复

基线 `a804e98af62f7f794cea0b1b67a73f798c52cce1` 的可玩卡牌在击败最后一个敌人后继续执行本应被清理的队尾动作：Pommel Strike 继续抽牌，Dropkick 继续返能和抽牌，Anger 继续生成副本，Rampage 继续增加本战伤害。抽牌还可能洗弃牌堆并消费共享随机状态，影响随后当前 Run 实现的奖励选择。

真实 `Run.play` 入口的受控末击夹具中，Pommel Strike / Dropkick 击杀前 combat seed 为 6182；旧实现因无意义的战后洗牌把它改成 16092。修复后 combat seed 保持 6182，然后 Run 正常执行三次既有奖励选择。此处只证明没有多余随机调用，**不认证当前共享 LCG、奖励算法或随机流为原版**。

生产改动仅在 `abyss_effects.lua`：当前效果列表执行 Damage / DamageAll / Block-based Damage / HP-loss 后，若全部敌人死亡且玩家存活，标记其余已排队动作已清理。用明确的已核实操作映射逐个跳过，不在死亡时直接 break 整个列表。标记仅是调用内局部变量，不写入战斗快照或污染后续指令。

| 当前操作 | 固定来源动作 | 末敌死亡后的处理 |
| --- | --- | --- |
| damage / damageAll / damageEqualToBlock | DAMAGE 类型动作 | 保留；仍经过既有目标/来源存活保护 |
| loseHp | LoseHPAction，DAMAGE 类型 | 保留，不把伤害类误当奖励类清理 |
| block | GainBlockAction 的具体实例 | 保留 |
| doubleBlock | DoubleYourBlockAction，仅 BLOCK 类型 | 清理；不能把全部 BLOCK 类型当成 GainBlockAction |
| draw / energy | DrawCardAction / GainEnergyAction | 清理 |
| gainStatus / applyStatus / applyStatusAll / gainTemporaryStrength / noDrawThisTurn | ApplyPowerAction 系列 | 清理，不消费 Artifact 或施加新状态 |
| addCardToDiscard / makeTempCardInDiscard / increaseDamageThisCombat | MakeTempCardInDiscardAction / ModifyDamageAction | 清理 |
| conditional | 当前只支持 Dropkick 的 energy/draw 尾部 | 清理这两个已排队动作，不泛化为任意条件队列 |

原 `Combat.resolvePlay` 仍完成卡牌离手后的去向及最终胜负事件；能力牌去向修复 PR128 不变。清理之前已经执行的效果不回滚。有任何活敌同伴时照常保留后续抽牌/返能/副本/增长。玩家因反伤死亡时保持现有 source-dead 停止约定，不借本切片放开新死者动作。

## 固定来源和认证边界

2026-10-23 UTC 只读取得社区反编译镜像 `aeubanks/sts@319009d5df0a82d9fb0f23cc22322286c6a87ec0`，不是先前能力牌去向账本使用的 `purewhitelove/ButterflyGame@fc379c8`。本镜像 `core/CardCrawlGame.java` 声明 `[V2.3.4] (12-18-2022)` / `2022-12-18`；没有正版 PC JAR 或构建 hash 认证，不是官方开源、原作观察或本轮实机证据。

方法链：DamageAction / DamageAllEnemiesAction 在伤害结算后检查全部怪物基本死亡，再调用 GameActionManager.clearPostCombatActions。后者只保留 HealAction、GainBlockAction、UseCardAction 具体类和 DAMAGE 类型；其它队列动作被删除。DropkickAction 先按目标的 Vulnerable 状态排入 Draw、Energy，再把 Damage 插到队首，因此实际执行顺序为 Damage → Energy → Draw，末敌死亡后两项被清理。Pommel Strike、Anger、Rampage 的 use 方法分别把 Draw、生成副本、伤害增长放在 Damage 之后，三个对应动作同样不在保留表。

所有下列本地原始响应按准确 UTF-8 内容重算 Git blob，并与 GitHub 返回 SHA 一致。初次临时证据文件因文本写入多一个换行导致 hash 不匹配，已从保存的原始响应重写并重新核对；不是换用镜像。下列是纠正后的准确身份。未将上游代码搬入游戏运行时或编译运行上游程序。

| 固定文件 | Git blob SHA | UTF-8 SHA256 |
| --- | --- | --- |
| [`actions/GameActionManager.java`](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/actions/GameActionManager.java) | `1662da8de2aeb42044b385f03d0c801750904b13` | `a47d1ee9c6b2e194b7d3ef311328f2a15e38f5630330689e438e46685b94d6c3` |
| [`actions/common/DamageAction.java`](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/actions/common/DamageAction.java) | `ea89aeab60af8a7c297495de3cd8eb82d7130232` | `c5649fc04cbcadffa617e5c52f1a6f879f88cb1a90a543d5a0a05ebf950578ec` |
| [`actions/common/DamageAllEnemiesAction.java`](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/actions/common/DamageAllEnemiesAction.java) | `13cc91e59ae21b8173468c4235849c6677ea3f55` | `3562ea16a19d0951b36198a4191fd48358c7cb408595ef2c503fc4b7763ec123` |
| [`actions/common/DrawCardAction.java`](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/actions/common/DrawCardAction.java) | `8f6ada68af6cce8c3acc5b7a397830b19c564633` | `67d02ba84c1d7e60fbb2a4a83f2b2d3ebbd81a84d29c16ccb98ecc9dd1a17e18` |
| [`actions/common/GainEnergyAction.java`](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/actions/common/GainEnergyAction.java) | `641242daa9eca4620cd005e6b52ebb2a8370a5cc` | `d370759b93d7211ac1888865db1624344c953864728fcc741d385a139cf0028d` |
| [`actions/common/MakeTempCardInDiscardAction.java`](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/actions/common/MakeTempCardInDiscardAction.java) | `f4f3cc0d88d8c4124ef070ccb9e0852c3cfc83f7` | `78eeca2eeeaf22de9146148cdcb015b7bdd335f0529a6f62fdadba3dd4d28efd` |
| [`actions/common/ModifyDamageAction.java`](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/actions/common/ModifyDamageAction.java) | `0112ebd19f2805bbc0eabf35c355a090b1122297` | `dc031490874c3f33dc34291283df57e6fed15fab5f38a3e5a76bd9c173a8085f` |
| [`actions/common/ApplyPowerAction.java`](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/actions/common/ApplyPowerAction.java) | `1a6af352c02e06ecec4db87dd5e2f57d43d35b91` | `f64ce8511f961a1990f1909e2c55654fa6dbf1dc2f4f1f3d3a7156c2ec2a9d47` |
| [`actions/common/GainBlockAction.java`](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/actions/common/GainBlockAction.java) | `ce4c481797045d55a17b133289e2e070431eacdf` | `e48f437c06b42dda312446a4b536aca54570d637e53087ac16f736d84bb5df4f` |
| [`actions/common/LoseHPAction.java`](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/actions/common/LoseHPAction.java) | `1a6426c1aa36b349f5fd24aa003f9ebb6eb2ead0` | `50c9ea9f1aef4a02ff9177d59517f61b03941e9770a23bc50bed8e3d60d69670` |
| [`actions/unique/DoubleYourBlockAction.java`](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/actions/unique/DoubleYourBlockAction.java) | `f2b72a847c197463fc44368869e9b0ce2f4f4180` | `09de35c50696a2cd855f44598d5497d2ca89a06c57711535eb23eff836f24d48` |
| [`actions/unique/DropkickAction.java`](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/actions/unique/DropkickAction.java) | `aedd14828436d553e4d309447586d6b70b0e597f` | `0dd2eef42bcfadbdf85dc6598e479c197a3a2b2681ac5f419e855b3bb364f9d3` |
| [`cards/red/PommelStrike.java`](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/cards/red/PommelStrike.java) | `bc7cbe855174bef589ff480a2aaac7f0ddbe7ebb` | `5317b772701a863ae0a6c263e49543be3cf2878d0e9ab71de4cfb5bce3024292` |
| [`cards/red/Anger.java`](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/cards/red/Anger.java) | `85beb12789071bf3f6b21b94746330364d60b311` | `64ae2f4354990d5c5e2fcf9d4a0ed8917dca539f76832c64766802aa1ca330bb` |
| [`cards/red/Rampage.java`](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/cards/red/Rampage.java) | `d38e1659c2c804c7078ca0d49a363ca2f73bc770` | `228e8877d220914f90967f730194656abdc8c1440a6784f7d704cbaad10877d8` |
| [`cards/red/Entrench.java`](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/cards/red/Entrench.java) | `6c735fe6175e33c38d51513e122ebb7b1c130f18` | `ed5d9518e44f2538f3d899a8beecde7a3c7e24eaa971f3ecd76a825a5d5edd6d` |
| [`core/CardCrawlGame.java`](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/core/CardCrawlGame.java) | `6f15eb15977a40bcb6e95598513a3073310eacd3` | `ad06c2d2f13ad66843b5304b6c05fb6019ddc7e92359e95302f35ee540317846` |

## 测试、红绿和已有断言修正

`tests/lua/post_combat_actions.lua` 35 组真实 Combat/Run 检查：

- 四张已支持卡牌的基本/升级、末敌/活同伴矩阵；直接抽牌与空抽牌堆洗牌两条路径。
- Dropkick 目标仍有 Vulnerable 也不能在战后返能/抽牌；未击杀、全格挡和同伴存活时仍正常触发。
- Anger 不再额外分配 UID；Rampage 不再追加增长，但此前已有增长保持。
- 受控混合动作证明保留 GainBlock 和 HP-loss、跳过能量/Power/DoubleYourBlock/生成/抽牌，且前置效果不被追溯取消。
- DamageAll 和 damageEqualToBlock 触发同样清理；反伤使玩家死亡的原保护不变。
- 保留的战后 Block 发生受控错误时，原子回滚仍恢复伤害、牌堆/actor/event 原引用、能量和 RNG；清理之后未知 op 仍报错，不借过滤吞掉非法操作。
- 两个真实 Run 入口检查没有多余洗牌、奖励照常出现、跳过奖励回图与永久牌组不变。

新测试先于生产修改：最初 33 组对旧实现为 17 失败；补上两组既有 Rampage 增长保护后，在独立旧源码副本重跑为 **35 组中 19 失败**。最终实现 35 组全过。`vulnerable_combo.lua`、`copied_attack.lua`、`growing_attack.lua` 三条错误“末敌死亡仍执行尾部”断言分别先红后绿；其余共 122 组全部通过。两个原 Rampage 极端数值保护例改为有活同伴，仍验证真实可执行增长的 int32 交界与无法前进值原子拒绝，不用战后已取消的动作冒充该错误路径。

本地原生 Lua 5.4 全部 **96 个测试文件通过**，包含原子性、敌人死后排队状态/roll、开战遗物、药水、全部卡池和原生 UI 控制器。首轮自备 runner 忘记提供项目 LUA_PATH，10 个依赖 runner 路径的文件报 module-not-found；原日志保留，补上正常模块路径后全量重新执行通过，未改这些测试源码。复用已有生成夹具，未重新构建 UI/data。

未安装依赖、未运行完整 `npm run check` 或本地 Fengari；远端当前提交的 Quality 和独立评审以最终 PR 为准。未做平台构建/副本导出、官方导入或千星实机，不能据此关闭父任务 TASK-16.1、M1 或 UI 门禁。

## 明确保留的范围

这不是完整 action manager：没有实现通用 pre-turn 队列、回调插队、halfDead/escaping 等状态、药水 onUse 回调或所有卡/遗物钩子。HealAction 是原版保留项，但本项目 Effects 没有合法 heal 操作，本切片继续拒绝，不顺手扩充卡池。玩家死亡时其余动作的全原版语义仍待独立核验。本切片不改卡牌费用/数值、RNG 算法、数据目录、UI 布局或平台配置。
