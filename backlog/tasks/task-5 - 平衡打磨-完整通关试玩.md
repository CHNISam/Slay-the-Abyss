---
id: TASK-5
title: M4 平衡打磨与完整通关试玩
status: In Progress
assignee:
  - '@Codex'
created_date: '2026-10-22 13:32'
updated_date: '2026-10-22 23:00'
due_date: '2026-10-29'
labels: []
milestone: m-5
dependencies:
  - TASK-17
  - TASK-4
priority: high
ordinal: 2
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
按基准数值表核对平衡，并真机从第 1 层打到 Boss 完成一次完整通关。缺口如实记录。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 从第 1 层到 Boss 完整通关一遍，日志无异常、无卡死
- [ ] #2 失败可重新开始，跨层状态（血量/金币/卡组/遗物/药水）正确
- [ ] #3 数值对照基准表核对，记录偏差与未完成项
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
复用TASK-3真实最小闭环。第四版已人工从第1层打到第15层Boss并失败结算，保存截图及按会话归档日志；核验失败重开。修复重大HP显示/意图截断/商店层级后重验，再以原数值击败Boss完成真正15层通关；逐项记录节点与跨层状态，不以到达Boss替代通关。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
2026-10-23 用户指定 P0：TASK-3 最小闭环后执行真实15层通关、Boss、结算及失败重开回归；暂停非必要功能、美术扩量与技术研究。

最小闭环尚未通过：首版实际菜单启程无响应，TASK-3正在修复并重新导入。不将本地15层降低敌人HP测试计作真实通关。执行与证据账本见独立修复树docs/P0-SMOKE.md。

第四版真实人工回归：用户确认已打到最终关卡后失败，期间奖励入组/跳过、商店离开等可推进，未发现其他明显流程阻断；截图floor15-defeat-v4.png显示抵达15/15、HP0/80、金币4、卡组14、遗物4。真实15层到Boss失败摘要已证实，Boss击败/正式结算/重开尚未验。已知P0缺陷为单位HP数字未显示、意图文字截断；商店密集文字观感差。正在读取本轮日志。

用户继续实机确认第四版失败摘要点重新启程可以正常进入新局地图，已结束试玩。失败重开路径功能通过；资源彻底重置的逐字段截图/日志核对尚未补齐。
<!-- SECTION:NOTES:END -->
