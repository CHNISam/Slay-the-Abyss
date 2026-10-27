# 第三幕精英：沉思巨像（Giant Head）

依据固定社区反编译镜像 `aeubanks/sts@319009d5df0a82d9fb0f23cc22322286c6a87ec0` 的 GiantHead、SlowPower、UseCardAction、ApplyPowerAction、AbstractMonster、伤害和遭遇方法，独立实现 A0 行为。不是官方开放源码，也不是正版 PC 二进制或本轮平台实测。18 份原文件的 Git blob、完整字节 SHA256、长度和固定链接见 `tests/fixtures/giant-head-source-lock.json`；不把第三方 Java 方法体或素材分发进产品。

- 正常第三幕精英队列 `Giant Head` 绑定单个 `GiantHead`；500 生命，固定范围仍消费一次 `monsterHpRng`。不改三种精英的等权、队列或重复排除；另外两种仍明确不可用。
- 初始 countdown=5；开场 getMove 后为4。前四次行动是各50%的凝视（1虚弱）或倒数（13普通伤害），相同招式最多连续两次。第五次开始攻击30、35、40、45、50、55，之后持续60。每次 getMove，包括强制换招和封顶阶段，仍消费一次0–99 `aiRng`。
- 预战施加0层缓慢，零层也是实际存在、可展示的减益对象。每张成功使用的牌（含技能、能力及自动副本）在 `UseCardAction.update` 的 `onAfterUseCard` 时排入底部 `ApplyPowerAction(+1)`；不是开打前、不是每段命中，也不要求以巨像为目标。读取实际卡牌实例此时的 `dontTriggerOnUseCard`，显式false可覆盖旧捕获值；true不触发。普通牌移动/消耗后才重置已有实例标记，能力与purge分支保留；不替旧无标记实例添加字段。牌自身所有攻击先使用旧层数，随后底部动作按顺序结算；耗牌触发也沿现有动作队列。
- 仅 `NORMAL` 伤害乘以 `1.0f + amount * 0.1f`。缓慢和易伤按同优先级的获得顺序、Java binary32 各步计算，最后才向下取整；伤害预览和实际攻击共用 Actor 算术；独立浮点向量同时覆盖力量、虚弱、双倍伤害、神格与易伤顺序，无缓慢目标仍保持既有算术。反伤、固定伤害、中毒不放大。减益施加受 Artifact/死亡取消约束。
- 缓慢在全部敌人行动后的 `atEndOfRound` 归零，而不是持有者回合末移除。保留零层对象及原获得位置，之后叠加不重排。

`tools/oracles/sts1_giant_head.py` 独立生成两种种子的完整12回合 AI/生命/RNG 向量与80组浮点伤害向量；不调用产品 Lua。`tests/lua/giant_head_ai.lua` 和 `giant_head_slow.lua` 覆盖动作、普通/自动/中断出牌、正常精英入口/奖励、失败后原图及对象引用恢复。长回合算术夹具使用1000玩家生命；领奖夹具用受控伤害到濒死后由真实初始牌击杀。这些是公开接口边界测试，不是自然取得或三幕通关证明。

本切片不包含 Nemesis、Reptomancer、整幕验收、官方导入、实机、GIL或发布；不据此关闭 TASK-62/M3。
