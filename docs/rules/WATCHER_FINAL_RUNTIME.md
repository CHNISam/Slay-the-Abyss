# 观者剩余卡牌运行时接线

本轮沿用固定319009d5镜像事实与docs/drafts/class-final归档，只复用自行编写的定义/计划，不复制Java实现。20张差集和衍生定义已加载至显式Watcher Profile，但定义不等于已实现；未完成的操作/能力受Capability与canPlay双重拒绝，不过滤完整来源池或重抽。

首切片实际完成Swivel基本/升级：8/11格挡，下一张非purge攻击免费且只消耗一层；该能力跨回合保留。真实Combat缺定义红例修后小回归通过，另核未接Alpha仍明确拒绝，避免把75定义当75可执行。架构133模块667边通过，固定Luacheck1.2.0无新增诊断、111历史警告。Effects既有两条诊断仅同步行位移。

其余19张的能力、生成、选择/自动出牌与回合时序仍在本任务实施，未宣称完成。来源资格/全池实际获取、75双版矩阵、合法混合、连续章节和平台验收仍须各自取得证据；本切片没有游戏/桌面操作。
# 伤害与生成切片

Alpha/Beta/Omega、ConjureBlade/Expunger、Judgment、SpiritShield、Ragnarok 已接真实 ActionQueue。
Ragnarok 每击选择当时活敌并重新算伤害；Expunger 保存生成时 X，使用新 UID；Judgment 绕过格挡和伤害修正但执行死亡回调；Omega 为无来源反伤类型。
`watcher_final_damage_generation.lua` 覆盖基本／升级、阈值、0X、反伤致死中断。其余 Final 候选仍以能力门禁拒绝，不计入完整75验收。

