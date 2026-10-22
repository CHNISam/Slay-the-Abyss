---
id: TASK-7.2
title: 旅行者卡牌名称与效果文案
status: Done
assignee:
  - Furinya
created_date: '2026-10-22 14:34'
updated_date: '2026-10-22 14:44'
labels: []
dependencies: []
references:
  - 'https://github.com/CHNISam/Slay-the-Abyss/pull/2'
parent_task_id: TASK-7
priority: high
ordinal: 23000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Owner 要求复用成熟数值，但玩家看到的主角、技能名和文案不能照搬原作。新增旅行者表现资源，不覆盖原作者的数值基线。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 首轮卡牌按稳定ID具有旅行者名称与基础/升级效果说明，玩家输出无原作专名
- [x] #2 不修改源ID、费用、数值、效果或逻辑名称；缺失/不匹配输入明确失败
- [x] #3 渲染与数据校验可复跑并通过独立评审，明确尚未游戏内验收
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. 核对已合并首轮37张卡池及原认领。2. 独立实现中文显示模板与标准库渲染工具，不改源数值表。3. 运行正负例和37张整合验证，独立评审，通过PR集成。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Executor: dot。独立表现资源与工具，不修改 TASK-7 的数值数据或原认领。基线 develop 481b926，首轮37张。默认 unittest 10/10（0跳过），CLI渲染37张/74模板；独立评审核对文案、X费、升级继承及失败负例。已知 op/条件/消耗标记变化仍需人工语义差异审阅；不是游戏运行验证。
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
交付旅行者37张中文表现模板、只读渲染器和10项测试；数值从原表读取，未改机制数据。独立评审通过当前37张；尚未接入游戏或真机验收。
<!-- SECTION:FINAL_SUMMARY:END -->
