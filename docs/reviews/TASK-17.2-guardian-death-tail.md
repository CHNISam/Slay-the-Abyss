# TASK-17.2 守卫首领的死亡中止边界

2026-10-24。基线 `6e8714f`，仅修复 The Guardian 双重打击导致玩家死亡后的排尾动作。未启动原神、沙箱或 MCP；没有平台编译、导出、导入或实玩证据。TASK-17.2 保持 In Progress，三项验收均未勾选。

## 发现与修复

原版 Twin Slam 先排打开壳，再排两段 8 点伤害，最后排移除 Sharp Hide；打开壳又把应用下一轮 Mode Shift、重置计数排到队尾。玩家任一段受击死亡后，死亡屏使动作管理器停止更新，后面的状态动作不会执行。

项目的效果解释器已经在玩家死亡后停止下一段伤害，但 `Guardian.afterEffects` 仍无条件完成上述状态尾部。结果为：已失败的战斗仍移除尖刺甲壳、把模式转换从 0 改成 40，并发出不应存在的状态事件。

修复仅在该 Boss 的 `afterEffects` 入口增加玩家死亡中止条件，不改变伤害、阈值、动作周期或随机调用。打开壳发生在伤害之前，因此死亡后的阶段仍为进攻；不倒退已经完成的动作。

## 固定来源与证据边界

通过 GitHub 只读接口重新读取 `aeubanks/sts@319009d5df0a82d9fb0f23cc22322286c6a87ec0`。镜像的 CardCrawlGame 自称 PC `[V2.3.4] (12-18-2022)` / `2022-12-18`；它是社区反编译镜像，未经正版 PC 二进制/hash 认证，不能视为官方开源或本轮原作实测。仅转述行为并独立实现，没有移植或提交其实现代码。

| 来源（固定提交） | 核对位置与事实 | Git blob |
| --- | --- | --- |
| [TheGuardian](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/monsters/exordium/TheGuardian.java#L186-L193) | useTwinSmash、changeState（246–264）：伤害与状态尾部的入队顺序 | `fb8e25d4ba5b1c0c0bade62022c4ff6f6d995a99` |
| [AbstractPlayer](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/characters/AbstractPlayer.java#L1482-L1484) | damage：没有复活效果时，致死伤害设置死亡并创建死亡屏 | `dc0f077c70ff36bad5d602f2128be1db1a0ee5b7` |
| [DeathScreen](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/screens/DeathScreen.java#L66-L85) | 构造函数开启屏幕状态 | `310e687d4b63406d405db6019b6dde9a59244120` |
| [AbstractRoom](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/rooms/AbstractRoom.java#L254-L259) | 正常战斗帧仅在没有屏幕覆盖时更新动作管理器 | `c2a1a029a9f59b1b94026dff46d4155824b85f86` |
| [DamageAction](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/actions/common/DamageAction.java) | update：伤害动作完成后再推进队列；反伤类型可在拥有者死亡后执行 | `ea89aeab60af8a7c297495de3cd8eb82d7130232` |
| [GameActionManager](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/actions/GameActionManager.java) | addToBottom、clearPostCombatActions、update：排尾及末敌死亡清理边界 | `1662da8de2aeb42044b385f03d0c801750904b13` |
| [ModeShiftPower](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/powers/ModeShiftPower.java) | 计数展示；转换判断在 Guardian 的实际失血回调 | `5049b21004cc5aa048050a3a7d241ff31268d4b4` |
| [SharpHidePower](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/powers/SharpHidePower.java) | onUseCard：按攻击牌排一次反伤，非按命中次数 | `fab4d7d513629270c27320dda2d42701af2e24ee` |
| [CardCrawlGame](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/core/CardCrawlGame.java) | 版本自述 | `6f15eb15977a40bcb6e95598513a3073310eacd3` |

以上为 API 返回的固定 blob 身份。另以 base64 原始字节重算并匹配了 Guardian、ModeShiftPower、SharpHidePower、DamageAction、GameActionManager 的 Git blob；未声称其余四个文件也做过本地逐字节验证。Guardian 原始 SHA256 为 `40571fa4c941d70c1814b0c0ff5cffa7d8933e24b49d95f2b531a3dc05598d56`，与 TASK-17.1 相同。

## 逐项审计与独立预期

这里的本地通过仅指对上述固定来源的行为回归；不提高来源等级，不代替正版 PC 或千星实玩。

| 项目 | A0 原版预期 / 当前证据 | 状态 |
| --- | --- | --- |
| 血量与开场 | 固定 240 HP、30 初始预算、Charge Up；来源构造/预战方法，guardian_ai 开场组 | 本地通过；正版版本认证待补 |
| 进攻招式 | Charge Up 9 格挡 → Fierce Bash 32 → Vent Steam 虚弱 2 再易伤 2 → Whirlwind 5×4 | 本地通过，guardian_ai 第 2 组 |
| 变形与阈值 | 实际失血累计，格挡不计；存活且到 30 时排转形，20 格挡；下次 40、50；同卡后续命中先完成 | 本地通过，guardian_ai 第 3–9 组 |
| 防守招式 | Close Up 才获得 Sharp Hide 3 → Roll Attack 9 → Twin Slam 8×2；再回 Whirlwind | 本地通过，guardian_ai 第 5–7 组 |
| Twin Slam 反伤 | 开壳后的少量反伤被尾部重置；到新预算可再排防守 | 本地通过，guardian_ai 第 10–11 组；完整通用队列未复刻 |
| 被打断 | 毒跨阈值改为 Close Up；受击跨阈值覆盖后续意图，不误推进 | 本地通过，guardian_ai 第 4、12 组及 guardian_vulnerable_transition |
| 尖刺甲壳 | 每张攻击牌一次，牌效果后结算；多段/群攻/零伤触发，技能/能力/药水不触发；格挡先吸收 | 本地通过，guardian_ai 第 13–20 组 |
| 死亡顺序 | 致死不为死者变形；已排定尖刺甲壳仍可导致同时死亡并判失败一次 | 本地通过，guardian_ai 第 21–23 组；无本轮 PC/平台录像 |
| 玩家被 Twin Slam 击杀 | 死亡后不移除 Sharp Hide、不应用下一轮 Mode Shift、不发尾部状态事件 | 本次修复，本地 5 组通过 |
| 随机边界 | 仅继承开场一次 0–99；后续确定转移不再抽样 | 已合 TASK-17.1，本轮 14 组回归；不重复实现 |
| 回滚 | 失败出牌恢复意图、预算、格挡、随机状态及表引用 | 本地通过，guardian_ai 第 24 组与 opening_roll |
| 未核实项 | 正版 PC 构建认证、原作种子独立随机流映射、完整动作队列、平台逐阶段与死亡实玩 | UNVERIFIED；不计整项验收通过 |

## 红绿证据与验证

新 `tests/lua/guardian_death_tail.lua` 从真实 240 HP Boss 和正常 Bludgeon 32 伤害进入防守，再执行 Close Up、Roll Attack。通过合法起始生命 10、17、18、25、26，使 Twin Slam 开始时生命分别为 1、8、9、16、17。没有降低 Boss 生命或替换其招式。

前四组覆盖第一段和第二段的致死边界：保留 Sharp Hide 3、Mode Shift 0；仅执行实际所需的 1 或 2 次伤害，失败只发一次，后续结束回合被拒绝。17 HP 对照组承受两段后剩 1 HP，正常移除甲壳、恢复预算 40、进入 Whirlwind。

- 修改生产代码前：1 过、4 败，四个失败均为死亡后 Sharp Hide 错误变成 0。
- 最小修复后：5/5 通过。
- Fengari 定向回归：guardian_ai 24、guardian_opening_roll 14、guardian_vulnerable_transition 1、thunderclap_order 27、post_combat_actions 35、combat 23，共 124 组通过；含新组共 129 组。
- JSON→Lua 构建与 `git diff --check` 通过；测试文件由现有全量 Lua runner 自动发现，不改 package。
- `node scripts/check-syntax.mjs` 在本沙箱因子进程 `spawnSync ... EPERM` 未完成；没有将其记为通过。完整检查由集成工作树统一运行。

剩余动作：集成当前 SHA 的完整检查/CI，再用同一候选补各阶段、反伤、死亡和一次性胜负结算的千星实玩证据。该离线切片不使 TASK-17.2 或 M3 自动完成。
