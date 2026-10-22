---
id: TASK-3
title: M1 真实平台完整战斗闭环
status: In Progress
assignee:
  - '@Codex'
created_date: '2026-10-22 13:32'
updated_date: '2026-10-22 23:24'
due_date: '2026-10-24'
labels: []
milestone: m-2
dependencies:
  - TASK-3.2
  - TASK-11.1
priority: high
ordinal: 1
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
对已完成的战斗系统做三层分离验证：编译通过、写进存档、游戏里真的能打。三件事分开报告，不得互相冒充。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 同一候选在真实游戏完成至少一场完整战斗：抽牌/出牌/能量/目标/结束回合/敌人行动/胜利奖励，日志和截图可复核
- [ ] #2 真实画面中手牌、血量/格挡/能量/敌人意图及中文可读可操作；与核心状态一致
- [ ] #3 记录候选SHA、导入存档与runId；失败和脚本错误如实列出，CI/替身控件不能代替
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
原AC1构建/写副本拆至TASK-3.1，原AC2导入拆至TASK-3.2；实战仍M1必要关口。本轮主存档无战斗脚本/UI，未运行战斗，不勾选。

P0用户优先级覆盖既定串行排期，沿用任务避免重复建项。v4完整候选实机完成菜单→地图→出牌/敌人行动→胜利奖励/跳过→回图→商店离开并推进至15层Boss失败；v5用户确认HP/MaxHP、意图与受伤更新正常。原始截图/候选SHA及故障修复在docs/P0-SMOKE.md。本轮新日志仍缺，九状态未逐项实测，AC保持未完成。
<!-- SECTION:NOTES:END -->
