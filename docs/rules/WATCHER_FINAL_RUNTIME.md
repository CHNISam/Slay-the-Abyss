# 观者剩余卡牌运行时接线

本轮沿用固定319009d5镜像事实与docs/drafts/class-final归档，只复用自行编写的定义/计划，不复制Java实现。20张差集和衍生定义已加载至显式Watcher Profile，但定义不等于已实现；未完成的操作/能力受Capability与canPlay双重拒绝，不过滤完整来源池或重抽。

首切片实际完成Swivel基本/升级：8/11格挡，下一张非purge攻击免费且只消耗一层；该能力跨回合保留。真实Combat缺定义红例修后小回归通过，另核未接候选仍明确拒绝，避免把75定义当75可执行。固定Luacheck1.2.0无新增诊断、111历史警告。Effects既有两条诊断仅同步行位移。

剩余牌的选择/自动出牌与回合时序仍在本任务实施，未宣称完成。来源资格/全池实际获取、75双版矩阵、合法混合、连续章节和平台验收仍须各自取得证据；本切片没有游戏/桌面操作。
# 伤害与生成切片

Alpha/Beta/Omega、ConjureBlade/Expunger、Judgment、SpiritShield、Ragnarok 已接真实 ActionQueue。
Ragnarok 每击选择当时活敌并重新算伤害；Expunger 保存生成时 X，使用新 UID；Judgment 绕过格挡和伤害修正但执行死亡回调；Omega 为无来源反伤类型。
`watcher_final_damage_generation.lua` 覆盖基本／升级、阈值、0X、反伤致死中断。其余 Final 候选仍以能力门禁拒绝，不计入完整75验收。

Conclude、Vault、Deva Form、Blasphemy、Deus Ex Machina、Foresight、Master Reality 已进入真实回合或抽牌路径。对应 `watcher_final_turn.lua` 与 `watcher_final_draw_powers.lua` 先红后绿，包含跳敌方／轮末、HP_LOSS虚无、Deva堆叠递增和回合开始Scry暂停续抽。

Wave of the Hand 按正float格挡回调（含999上限与floor前不足1）排虚弱；Establishment按源优先级25扫描当时保留手牌，再与化沙降费续队列组合。Meditate复用真实UID检索，auto-all满手溢出也标保留；Omniscience强制单牌也选择，原牌消耗、全字段statEquivalent副本purge。后者的遗物／自动use生命周期另依赖共享队列修复，完整组合回归未完成。

Wish三项基本／升级选择与Lesson真实永久UID升级已接。Lesson保留masterDeck顺序，用房间miscRng（单候选仍消费），不升级战斗副本；共用23863a9永久owner边界。Foreign使用固定106张全库非HEALING攻击（43/48/15），每尝试按cardRandom稀有度+shuffleLong、独立持久cardRng索引取样，重复源ID重走整段；不动rarityOffset，不复制Discovery第二组消费。

Foreign独立Python64源oracle两流seed1为Melter／Immolate／Compile Driver，cardRandom counter6、cardRng counter3；真实合并catalog组件测试与缺定义整次回滚已通过。普通Watcher Profile仍只有本职业定义，完整跨职业catalog由父TASK59统一组合；这里不能据此报告普通入口75齐备。Run成功命令提交持久流，发奖励前同步当前战斗流。

Master Reality按源生成入口调用升级，native手牌构造与ShowHand各一次、普通弃牌一次，检索不升级；SearingBlow重复升级短例先红后绿。Shiv旧断言迁移及75双版矩阵仍在推进。未进行实机／平台验收。
