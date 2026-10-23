---
id: TASK-17
title: M3 原版Boss阶段、完整第一幕与正式结算
status: In Progress
assignee:
  - '@Codex'
created_date: '2026-10-22 13:48'
updated_date: '2026-10-23 01:58'
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

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
2026-10-23审计：PR29已有本地Boss节点/胜利页/重开处理器；game_ui测试15层使用低HP夹具，不是原数据完整第一幕通关。独立阶段意图、正式平台结算及完整原数据通关尚未证明，保持未完成。

P0正式结算已接线：结果双按钮、单次ABYSS_WIN/LOSE信号、服务器设置胜败后settleStage；v6图编译/写入通过。候选SHA CE9076F4295A7A9B415E9BB160E3FCFE1B552C72D71BF330F48B8ADB8FC2E752。用户真实第1层战败后点结束并结算，进入平台官方失败页（离开/重新挑战）；截图.artifacts/p0/defeat-result-v6.png、official-defeat-settlement-v6.png。Boss胜利/胜利正式结算及平台重新挑战后的资源重置未测，AC保持未完成。

2026-10-23：新AC替代未完成旧15层口径；历史P0失败/官方失败页证据全部保留，只不外推为原版17层胜利验收。新增规则工作不使P0停等。
<!-- SECTION:NOTES:END -->
