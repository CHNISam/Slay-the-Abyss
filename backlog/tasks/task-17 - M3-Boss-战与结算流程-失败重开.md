---
id: TASK-17
title: M3 原版Boss阶段、完整第一幕与正式结算
status: In Progress
assignee:
  - '@Codex'
created_date: '2026-10-22 13:48'
updated_date: '2026-10-23 03:04'
due_date: '2026-10-28'
labels: []
milestone: m-4
dependencies:
  - TASK-15
  - TASK-16
  - TASK-12.3
  - TASK-14.1
  - TASK-16.1
priority: high
ordinal: 3
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
用户2026-10-23决定：首发纳入内容严格对齐初代Slay the Spire PC正式版Ascension 0数值/机制/算法/概率/结算顺序，仅名称/背景/元素表现可包装，禁止自创或凭感觉调平衡。M1唯一主冲刺，后续规则工作排队不打断P0。PR51仍OPEN，仅待审提案；用户指令为本次依据。10/30内部准备、11/02比赛截止不变。 保留既有P0原15层到Boss战败及官方失败结算有效证据；现有固定Boss循环不代表原版阶段。M3新增验收必须为核实的17层完整第一幕，Boss后原版奖励/宝箱按计层对照处理；本作首幕结束不强制增加第二幕。P0支持可沿旧候选继续，不等待规则规划。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 首发选定Boss的HP范围、行动概率/限制、阶段切换条件、阈值、变形、状态和中断/死亡结算顺序逐项有准确原版来源与可控输入轨迹测试，禁止固定循环替代状态机。
- [ ] #2 同一原版数值候选真实从开局走完核实的17层口径、Boss及Boss后奖励/宝箱与正式胜利结算，记录逐层资源/种子/卡组/战绩/用时/SHA/hash/日志录像；低HP夹具和旧15层失败不当通关。
- [ ] #3 失败后游戏内新局及平台重新挑战均无旧卡组/状态/随机计数/资产残留；正常死亡、末敌击杀、Boss阶段边界、胜败信号均只结算一次。
- [ ] #4 逐项记录原版PC版本、可复核来源URL/章节/观察日期、准确数值/算法/概率/结算顺序、现实现位置、差异与验收输入输出；不足标待核实，禁止猜测；未核实或未修正不计一致性通过。
- [ ] #5 数据完成、独立原版预期自动测试、平台编译/副本导出、官方导入和千星实机分层报告，附SHA/hash/种子/日志和截图录像，不能互相替代。
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
2026-10-23 离线补齐：使用客户端 update 的有效 dt 记录同局用时与完成战斗数，结算结果冻结，重新启程清零；以 GameUI 行为回归验证胜败结果及重开。不开游戏，不勾平台验收。

本轮整合17层结构时，对尚无Boss遗物池的boss_treasure入口原子拒绝，避免误走普通宝箱发错奖励；保留16层击败Boss结果页，明确完整17层流程未完成。离线代码通过评审与当前SHA CI后直接合并，不以平台待验阻断所有离线开发。

本轮Guardian离线切片：对照初代PC A0来源核实攻击/防守阶段及HP损失预算；新增独立Guardian状态机、变形立即格挡/意图中断/递增阈值，Attack卡动作后单次SharpHide结算；用独立预期轨迹和边界/死亡/回滚测试验证，不以循环代替阶段。保持所有平台及完整17层通关AC未勾，暂不开原神。
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
<!-- SECTION:NOTES:END -->
