---
id: TASK-3
title: M1 真实平台完整战斗闭环
status: To Do
assignee: []
created_date: '2026-10-22 13:32'
updated_date: '2026-10-22 22:21'
due_date: '2026-10-24'
labels: []
milestone: m-2
dependencies:
  - TASK-3.2
  - TASK-11.1
priority: high
ordinal: 3000
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
<!-- SECTION:NOTES:END -->
