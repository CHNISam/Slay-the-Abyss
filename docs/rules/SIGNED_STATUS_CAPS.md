# 力量 / 敏捷边界切片

## 范围与证据

仅对 Strength / Dexterity 的最终叠加状态限制为 [-999, 999]；双方角色共用入口。未更改其他状态、地图、RNG、卡牌数值或表现。此为 TASK-16.1 的独立候选，不代表该任务或原版整体验收完成。

2026-10-23 读取以下固定版本反编译镜像，仅作只读规则资料；没有复制、安装或执行其代码。两仓库来源并非官方 MegaCrit 发布，也未证明来自独立原版 JAR。它们自报 V2.3.4，不等于已认证游戏版本。本地回归证明此切片符合这些已读取资料，不宣称官方游戏实测。

- https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/powers/StrengthPower.java ：构造、stackPower、reducePower 均限制上下界 999 / -999。
- https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/powers/DexterityPower.java ：相同边界。
- https://github.com/fadedwind/refgameSource/blob/462da73b934eaf8a833791f3cab74dc792fdeeb6/Slaythespire.src/com/megacrit/cardcrawl/powers/StrengthPower.java ：构造 L23–28、叠加 L52–57、扣减 L70–75。
- https://github.com/fadedwind/refgameSource/blob/462da73b934eaf8a833791f3cab74dc792fdeeb6/Slaythespire.src/com/megacrit/cardcrawl/powers/DexterityPower.java ：构造 L19–24、叠加 L45–50、扣减 L63–68。
- https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/cards/red/Flex.java ：分别排入所请求的力量与 LoseStrengthPower，普通 2 / 升级 4。
- https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/powers/LoseStrengthPower.java ：回合结束按自己的完整 amount 施加负力量，然后移除此 power。没有根据实际力量增幅降低扣减量。

因此 998 力量使用 Flex2 得到 999，临时扣减债务仍为 2，回合结束得到 997；Flex4 对应 995。不得为“恢复永久力量”擅自改成只扣实际增量。此次不实现其他尚未支持的 Artifact、Orange Pellets 等交互。

## 自动验证与边界

新增 signed_status_caps.lua：双方初始正负超限、从 ±998 叠加跨界、在 ±999 继续叠加、反向扣减、归零、真实事件 delta / 快照、攻击 / Frail 格挡修正、普通与升级 Flex 公共 API 和实际出牌 / 弃牌 / 能量 / 回合结束、其他状态不被普遍封顶。

原先极大数精度和非法状态回滚回归仍保留原断言；因公开入口不再产生超限力量 / 敏捷，两个测试夹具明确改为人工注入的 hostile arithmetic/state，不能再称作合法游戏状态。

仍保留既有有符号32位输入及累加溢出原子拒绝契约；不声称对人工极端整数输入复刻 Java 溢出。此切片不把 poison 等其他状态的未核实上限一起改变。

实际执行：系统 Lua 5.4 的12组新增用例、35组既有状态、16组既有 Flex。未修改 Actor 时新增11组失败、无关状态控制组通过；候选全部通过，6种 cap 负向变异全部检出。Fengari、完整 CI、千星平台编译及实机未在本切片通过。
