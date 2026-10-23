---
id: TASK-17
title: M3 Boss 战与结算流程 + 失败重开
status: In Progress
assignee:
  - '@Codex'
created_date: '2026-10-22 13:48'
updated_date: '2026-10-23 02:03'
due_date: '2026-10-28'
labels: []
milestone: m-4
dependencies:
  - TASK-15
  - TASK-16
  - TASK-12.3
priority: high
ordinal: 3
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
第一幕 Boss 战、通关结算界面与失败重开闭环。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Boss 有独立阶段与意图
- [ ] #2 击败 Boss 后正式结算（战绩/用时/卡组成果）
- [ ] #3 失败可重新开始，无残留状态
- [ ] #4 M1/M2关口通过后，同一原数据候选真实完成15层到Boss、正式结算和失败重开，记录战绩/用时/卡组、SHA、存档、日志/录像；不可用夹具降低HP冒充
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
2026-10-23 离线补齐：使用客户端 update 的有效 dt 记录同局用时与完成战斗数，结算结果冻结，重新启程清零；以 GameUI 行为回归验证胜败结果及重开。不开游戏，不勾平台验收。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
2026-10-23审计：PR29已有本地Boss节点/胜利页/重开处理器；game_ui测试15层使用低HP夹具，不是原数据完整第一幕通关。独立阶段意图、正式平台结算及完整原数据通关尚未证明，保持未完成。

P0正式结算已接线：结果双按钮、单次ABYSS_WIN/LOSE信号、服务器设置胜败后settleStage；v6图编译/写入通过。候选SHA CE9076F4295A7A9B415E9BB160E3FCFE1B552C72D71BF330F48B8ADB8FC2E752。用户真实第1层战败后点结束并结算，进入平台官方失败页（离开/重新挑战）；截图.artifacts/p0/defeat-result-v6.png、official-defeat-settlement-v6.png。Boss胜利/胜利正式结算及平台重新挑战后的资源重置未测，AC保持未完成。

本轮执行 Codex/root，隔离分支 feat/offline-sprint-review 从 origin/develop 083d780；用户明确暂不开原神，自主推进离线部分。

离线结算统计已实现：Run初始化用时/胜场，finishCombat胜利单次计数，GameUI只累计有效非负有限dt；菜单/胜败结果不计时，战败动画不延长结果，重新启程清零。先新增行为回归并在旧实现复现缺少统计失败，修后GameUI10组通过。结果摘要在原有四行内显示用时/胜场；官方结算与完整原数据通关AC继续未勾。

独立复核1a85289无阻塞问题，并复跑GameUI10组。完整npm run check退出0：JS194项（180通过、14个Windows软链接权限跳过）、Lua176组通过、Python13项（12通过、1同类跳过）。用时包含最终Boss演出和奖励选择，胜利菜单后冻结。TASK17维持In Progress且AC全部未勾，未运行原神/平台编译/导入。
<!-- SECTION:NOTES:END -->
