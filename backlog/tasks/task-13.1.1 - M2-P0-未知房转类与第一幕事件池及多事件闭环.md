---
id: TASK-13.1.1
title: M2 P0 未知房转类与第一幕事件池及多事件闭环
status: In Progress
assignee:
  - codex
created_date: '2026-10-23 15:54'
updated_date: '2026-10-23 16:40'
due_date: '2026-10-26'
labels:
  - p0
  - required
  - rule-parity
milestone: m-3
dependencies: []
parent_task_id: TASK-13.1
priority: high
ordinal: 53000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
用户已确认首批交付六种完整事件的明确受限池；完整目录和抽选模型另测，其余事件依赖继续P0，不改变M1主冲刺。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 四类真实路由及独立持久随机流，拒绝重复不消费状态
- [x] #2 原版完整目录与三池资格抽选及去重可测试；六种生产受限范围明确
- [ ] #3 六事件完整选项及UI事务通过全量check并CI成功后合入develop
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
核对来源，先红后绿；复用随机候选接真实入场与三池模型；实现六事件与UI；完整检查、候选构建、复核及CI后合并；实机和严格PC缺口独立留证。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
用户已明确批准受限六事件首批；已实现真实四类路由，保留完整目录模型。来源8个blob已匹配；规则14组、UI29组、地图19组专项通过。全量首次失败为第14层遭遇数据缺口，已红绿修复；地图新增用例计数旧断言亦已更新。完整最终检查/构建/CI进行中，不勾平台或PC严格一致性。

最终本地npm run check exit0：JS747/629pass118skip，Lua91文件全过，Python17/16pass1skip。候选固定96b80a7，GIL 74e4da99bad6f1fe3c7dd699790c48ac7c1ede88d32b7d32d4631c8bc618ad96；35模块源码同源（1仅换行），1695控件max51，22节点完整载荷通过，static0error16warning。PR123当前CI排队等待在线busy runner，尚未合并；官方导入/平台/UI门禁未验。
<!-- SECTION:NOTES:END -->
