---
id: TASK-12.5
title: 实测地图、价格和掉落概率是否正确
status: To Do
assignee:
  - '@Furinya'
created_date: '2026-10-24 02:01'
updated_date: '2026-10-28 01:36'
due_date: '2026-10-28'
labels: []
milestone: m-4
dependencies:
  - TASK-12.3
  - TASK-12.4
  - TASK-13.1
references:
  - docs/backlog-details/TASK-12.5.md
  - docs/DELIVERY-CLOSEOUT.md
  - docs/M3-STATUS-20261028.md
parent_task_id: TASK-12
priority: medium
type: task
ordinal: 78000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
前面的规则做好后，再到游戏里核对地图、商店和奖励的实际结果。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 按原版依据检查路线、房间、敌人分布、价格范围和掉落概率；用足够多的测试确认。
- [ ] #2 在同一个版本实际交易和领奖，金币、物品和概率计数都正确；不能重复领或走非法路线。
- [ ] #3 哪些通过、哪些有差异、哪些还没查清分别写明；能通关不等于这些都通过了。
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
负责人字段规范化：原记录 @Codex 作为历史执行者信息保留；任务负责人为 Furinya。

2026-10-28接续核对：当前主线b7dffdeb已包含PR238/250/252/259/262，第四幕及真结局接线不再待合并。M3当前32/46 Done，14项未完成。最新整合、遗留工作树与具体证据边界见docs/M3-STATUS-20261028.md；旧PR待合/冲突备注仅属历史。本次不新增自然获取、四职业四幕、平台导入或实机通过，不修改既有AC。
<!-- SECTION:NOTES:END -->
