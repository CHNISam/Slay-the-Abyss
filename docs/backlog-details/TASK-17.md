# TASK-17 开发附件

任务首页只保留好理解的目标。下面保存原始技术要求、执行方案和已有证据；这些要求继续有效，开发时须一并遵守。


## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
限定为正常Boss胜利→独立Boss宝箱17→第一幕正式胜利，以及失败/重开的闭环实现。原规则数值AC1/4迁至TASK-17.2；原通关/重开实机AC2/3迁至TASK-17.3；历史描述、AC和证据存于迁移快照。父任务按本切片独立收口，不等待M3规则子项。共同约束：初代《杀戮尖塔》PC A0的规则、数值、概率、AI和结算顺序保持原版；不通过调值或低HP夹具制造通过。编译、写副本、官方导入和实机分别报告，保留SHA/hash、种子、截图和本轮日志。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 正常规则状态击败Boss后进入独立第17层Boss宝箱，实际执行其合法奖励事务并进入平台正式胜利结算；不得降级为普通宝箱或仅到达Boss。
- [ ] #2 失败、末敌击杀、Boss阶段中断及胜败信号只结算一次；游戏内新局/平台重新挑战正确清空旧资源、状态和随机计数，具有真实入口回归证据。
- [ ] #3 保留源SHA、本地预期测试、候选编译/写入/导入结果；完整正常游玩证据由TASK-17.3独立验收，Boss严格原版账本由TASK-17.2验收。
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
2026-10-23 离线补齐：使用客户端 update 的有效 dt 记录同局用时与完成战斗数，结算结果冻结，重新启程清零；以 GameUI 行为回归验证胜败结果及重开。不开游戏，不勾平台验收。

本轮整合17层结构时，对尚无Boss遗物池的boss_treasure入口原子拒绝，避免误走普通宝箱发错奖励；保留16层击败Boss结果页，明确完整17层流程未完成。离线代码通过评审与当前SHA CI后直接合并，不以平台待验阻断所有离线开发。

本轮Guardian离线切片：对照初代PC A0来源核实攻击/防守阶段及HP损失预算；新增独立Guardian状态机、变形立即格挡/意图中断/递增阈值，Attack卡动作后单次SharpHide结算；用独立预期轨迹和边界/死亡/回滚测试验证，不以循环代替阶段。保持所有平台及完整17层通关AC未勾，暂不开原神。

Guardian最终修订按固定镜像动作队列：普通HP损失包括Thorns；转形延至当前卡牌/敌方批次完成，双击剩余段先完成；Twin Slam先开壳，后排模式预算与Reset，小额反刺清除、足额可再转防守；保留尖刺甲壳按卡单次并在致死后执行。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
2026-10-23审计：PR29已有本地Boss节点/胜利页/重开处理器；game_ui测试15层使用低HP夹具，不是原数据完整第一幕通关。独立阶段意图、正式平台结算及完整原数据通关尚未证明，保持未完成。

P0正式结算已接线：结果双按钮、单次ABYSS_WIN/LOSE信号、服务器设置胜败后settleStage；v6图编译/写入通过。候选SHA CE9076F4295A7A9B415E9BB160E3FCFE1B552C72D71BF330F48B8ADB8FC2E752。用户真实第1层战败后点结束并结算，进入平台官方失败页（离开/重新挑战）；截图.artifacts/p0/defeat-result-v6.png、official-defeat-settlement-v6.png。Boss胜利/胜利正式结算及平台重新挑战后的资源重置未测，AC保持未完成。

2026-10-23：新AC替代未完成旧15层口径；历史P0失败/官方失败页证据全部保留，只不外推为原版17层胜利验收。新增规则工作不使P0停等。

保留本轮离线候选记录：
2026-10-23审计：PR29已有本地Boss节点/胜利页/重开处理器；game_ui测试15层使用低HP夹具，不是原数据完整第一幕通关。独立阶段意图、正式平台结算及完整原数据通关尚未证明，保持未完成。

P0正式结算已接线：结果双按钮、单次ABYSS_WIN/LOSE信号、服务器设置胜败后settleStage；v6图编译/写入通过。候选SHA CE9076F4295A7A9B415E9BB160E3FCFE1B552C72D71BF330F48B8ADB8FC2E752。用户真实第1层战败后点结束并结算，进入平台官方失败页（离开/重新挑战）；截图.artifacts/p0/defeat-result-v6.png、official-defeat-settlement-v6.png。Boss胜利/胜利正式结算及平台重新挑战后的资源重置未测，AC保持未完成。

本轮执行 Codex/root，隔离分支 feat/offline-sprint-review 从 origin/develop 083d780；用户明确暂不开原神，自主推进离线部分。

离线结算统计已实现：Run初始化用时/胜场，finishCombat胜利单次计数，GameUI只累计有效非负有限dt；菜单/胜败结果不计时，战败动画不延长结果，重新启程清零。先新增行为回归并在旧实现复现缺少统计失败，修后GameUI10组通过。结果摘要在原有四行内显示用时/胜场；官方结算与完整原数据通关AC继续未勾。

独立复核1a85289无阻塞问题，并复跑GameUI10组。完整npm run check退出0：JS194项（180通过、14个Windows软链接权限跳过）、Lua176组通过、Python13项（12通过、1同类跳过）。用时包含最终Boss演出和奖励选择，胜利菜单后冻结。TASK17维持In Progress且AC全部未勾，未运行原神/平台编译/导入。

已同步2eaf30f新的原版一致性验收范围和依赖；本轮离线实现/诊断不替代原版来源核实、平台或完整通关验收。所有新AC保留未勾。

2026-10-23 /root/enemy_ai 在feat/task-17-guardian-ai推进Guardian真实阶段，未改actor/effects。先新增原版独立预期测试确认旧循环缺少初始Mode Shift而失败；实现后19组Guardian轨迹及35组状态通过。首次全套检查在既有statuses测试依赖前九项数组序号处失败，已将新增两状态追加到末尾保持旧序，定点复验通过。现普通合入be5093f最新develop并保留17层地图、Cleric/Purifier、库存零伤反刺修复，随后做最终组合检查。来源可信级别、原版构建未锁与死亡边界依据见docs/reviews/TASK-17-guardian-ai.md；全部AC仍未勾。

2026-10-23 最终Guardian离线切片（基线已普通合入be5093f）：新增独立攻守状态机、数据化30/40/50预算及20格挡、完整A0动作顺序、真实Attack卡后SharpHide一次反伤。只读获取purewhitelove/ButterflyGame@fc379c875c11e008e9c10548ac8e394c301c532f实际方法体，声明V2.3.4/2022-12-18但未经正版hash核验。依据具体队列纠正wiki概述不足：TwinStrike两段后才加转形格挡；Thorns可消耗打开壳时预算；Twin Slam先开壳但预算应用/Reset排在两段之后，小额反刺被清，足额可再转形。独立红测分别复现27!=30、40!=34和CloseUp误推进到Roll后修正；24组Guardian轨迹、12组schema、真实控件预算/状态/意图通过。最后固定代码完整npm run check退出0：JS224（210通过、14既有Windows软链权限skip），Lua全套通过含Guardian24/UI38，Python16（1既有skip）。保留17层地图、Cleric/Purifier和库存零伤Thorns，不改actor/effects；applyEffects批次标记异常复原通过copied_attack34组原子性回归。来源hash、路径行号和候选边界见docs/reviews/TASK-17-guardian-ai.md，日志build/guardian-ai-check.log。五个AC全部未勾；无原神/MCP/图编译/写档/实机或原版二进制验证。

本批代码已合develop fac093c（药水PR78），实际离线构建源022f22cf；git diff确认src/data/scripts与合入代码完全一致。完整check及各PR当前SHA Quality全绿，实际gil独立核实24模块源文、1220控件/六列模板/22节点启用结算图，客户端静态0error/15条已定位自定义方法warning；内存重注入与候选字节相同。候选SHA256 a6d839d45753af0e536142bba7a3cd2322155dda38a67cbcc220bce7b6c8e114，正式底图hash前后相同且liveWrite=0。证据docs/evidence/offline-candidate-022f22c.json及P0-SMOKE。未开原神、未官方导入/实机，所有剩余平台/全项AC保留原状态。

PR83固定3cf2890独立复审保留全部128种子、双独立Run、唯一稀有/领取/冻结正常精英输出断言，测试拆分保持15秒预算，四脚本各2–3秒；当前CI双项SUCCESS后已合develop91f50d1。Boss卡牌奖励限当前实际支持的4张rare，不等于完整原版稀有池/重抽RNG/第17层Boss遗物箱/正式胜利实机完成。
<!-- SECTION:NOTES:END -->
