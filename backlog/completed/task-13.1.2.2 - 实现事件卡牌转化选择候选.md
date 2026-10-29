---
id: TASK-13.1.2.2
title: 实现事件卡牌转化选择候选
status: Done
assignee:
  - '@Furinya'
created_date: '2026-10-23 17:50'
updated_date: '2026-10-27 15:04'
labels: []
dependencies: []
references:
  - 'https://github.com/CHNISam/Slay-the-Abyss/pull/127'
parent_task_id: TASK-13.1.2
priority: medium
type: feature
ordinal: 56000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
为移除或转化卡牌事件补充隔离的选择逻辑候选。按固定来源核对普通、无色与诅咒牌池，排除原牌与特殊诅咒，并验证随机消费。暂不接入生产事件、永久库存或界面，不宣称完整卡池及平台验收。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 固定来源与候选接口可追溯，池顺序、重复项及过滤规则有证据
- [x] #2 普通、无色及诅咒转化的选择和随机调用通过独立测试与负例验证
- [x] #3 不修改生产事件池、库存或界面；限制与后续接入条件明确记录
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
核对来源与所有权；测试先失败；实现隔离候选；独立评审；当前提交CI后正常PR集成。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
负责人字段规范化：原记录 @dot 作为历史执行者信息保留；任务负责人为 Furinya。
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
PR127 / f175aca 已合并。20专项、独立1500差分用例及负控通过；合后CI40000372880成功。仅转化选择候选完成，完整牌池/库存事务/可玩事件仍在父任务。
<!-- SECTION:FINAL_SUMMARY:END -->
