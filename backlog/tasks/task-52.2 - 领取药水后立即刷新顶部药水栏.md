---
id: TASK-52.2
title: 领取药水后立即刷新顶部药水栏
status: Done
assignee:
  - '@Furinya'
created_date: '2026-10-24 15:55'
updated_date: '2026-10-27 15:04'
labels: []
milestone: m-4
dependencies: []
parent_task_id: TASK-52
priority: medium
type: bug
ordinal: 91000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
战后领取药水后顶部数量仍旧，返回地图才更新。本切片修复同步通知并做生成UI回归，平台复测保留父任务。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 领取后顶部数量立即更新
- [x] #2 满槽丢弃后领取与放弃的显示符合库存，失败及重复输入不增加库存。
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
追踪刷新通知；先补生成UI红测试，再修复通知并验证药水与宿主回归；当前SHA的CI全绿后合并develop。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
已证实根因：processPotionReward调用refresh()仅重绘战斗面板，未触发宿主onChange；改用refresh(ok)。新增真实生成树测试在旧实现失败：0/3不变为1/3，2/3不变为3/3；修复后丢弃UI10组、药水奖励3组、独立领取2组及宿主/布局JS7项全过。覆盖四种按钮状态、满槽拒绝、丢弃后补领、放弃与重复输入。复审确认仅成功事务通知宿主，失败仍局部重绘，保留原输入归属保护。Codex直接处理这一跨控制器关键通知修复，无外部委派或模型费用；额度节省未知。未构建gil、未导入或实机复测，父任务平台验收仍保留。

负责人字段规范化：原记录 @Codex 作为历史执行者信息保留；任务负责人为 Furinya。
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
已修复奖励页领取药水后顶部数量延迟更新；真实生成UI的红绿回归及相关22组检查通过。本任务仅验收本地同步修复；完整检查和当前SHA CI是PR合并门禁，平台复测仍在TASK-52。
<!-- SECTION:FINAL_SUMMARY:END -->
