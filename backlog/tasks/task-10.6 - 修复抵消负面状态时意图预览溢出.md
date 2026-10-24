---
id: TASK-10.6
title: 修复负面状态被抵消时的意图显示报错
status: Done
assignee:
  - '@dot'
created_date: '2026-10-24 02:42'
updated_date: '2026-10-24 05:31'
labels: []
milestone: m-2
dependencies:
  - TASK-10.5
references:
  - docs/backlog-details/TASK-10.6.md
parent_task_id: TASK-10
priority: medium
type: bug
ordinal: 75000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
状态层数极大、又能抵消负面效果时，敌人意图预览会报错。修好显示，不改变实际战斗结果。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 能被抵消的负面状态，即使层数很大，也不会让意图预览报错。
- [x] #2 显示按实际战斗规则处理，不能改本局结果，也不能把真正非法的数值错误藏起来。
- [x] #3 正常意图、状态详情和卡牌预览仍正常；先复现问题，再确认修好。
- [x] #4 相关检查和审查通过，不改战斗数值、已批准布局或其他任务的状态。
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
在最新7e1123b上独立复跑Artifact预览与播放15组、正常预览及真实宿主反馈专项；核验PR152最终head与Quality双作业，再按原本地AC收口，不替代平台验收。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
2026-10-24 M1收口复核：TASK-10.6原开发附件明确为本地只读预览修复，不含实机AC。PR152已合入d7af871，最终head73a1c305；独立连接GitHub核实Quality40057518426 success，待本轮最新基线专项复跑。

2026-10-24当前7e1123b复跑：intent-artifact-preview.test.mjs驱动真实GameUI Artifact预览12组与播放3组均过，连同布局/主题共13个Node测试全过；battle_ui 52/52过。上界抵消/无Artifact非法溢出/真实状态和RNG不变/未行动敌人动态更新及取消换局均覆盖。PR152最终head73a1c305的Quality40057518426 check120763673014、presentation120763672871独立API复核success；已有作者与独立评审红绿/突变证据见docs/testing/task10-6-artifact-intent-preview.md。仅关闭本地修复切片；九状态、完整UI和平台任务不变。
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
复用真实核心Artifact门控修正只读意图预览，并防止演出完成后的意图重复预演。原版红绿/突变证据、PR152精确head双绿CI及最新7e1123b上的15组Artifact/52组战斗UI复跑充分，按原本地AC完成；不认证实机性能或UI门禁。
<!-- SECTION:FINAL_SUMMARY:END -->
