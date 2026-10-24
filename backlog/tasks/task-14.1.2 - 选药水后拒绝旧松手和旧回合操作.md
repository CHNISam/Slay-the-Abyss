---
id: TASK-14.1.2
title: 选药水后拒绝旧松手和旧回合操作
status: Done
assignee:
  - '@Furinya'
created_date: '2026-10-24 19:17'
updated_date: '2026-10-24 19:31'
due_date: '2026-10-28'
labels: []
milestone: m-4
dependencies:
  - TASK-14.1.1
references:
  - 'https://github.com/CHNISam/Slay-the-Abyss/pull/195'
parent_task_id: TASK-14.1
priority: high
type: bug
ordinal: 93000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
药水瞄准已上线，但延迟松手可能误耗药水，之前的结束回合点击也可能穿过新瞄准。仅修这两处输入归属，不调整规则、文案和布局。执行者：dot。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 没有对应按下的敌人松手事件不得确认并消耗药水
- [x] #2 进入药水瞄准前的结束回合手势不得推进回合
- [x] #3 新手势、纯点击兼容和现有取消方式保持有效
- [x] #4 最小回归先红后绿并经独立评审；最终提交通过仓库CI，实机结果另记
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. 在最新develop复现两处问题并保留原日志。2. 仅补两个输入失效边界和独立回归。3. 独立评审与最终SHA CI通过后正常合并；不接管父任务或其他在途UI。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
基于f6712d0，UI仅新增两行；新回归3过4败到7/7，两个单行mutation各准确5过2败。独立评审5639593331另验251组原生Lua与16组Node，包含PR194卡面和药水说明共存。实现提交7a0340e08d84e35aad420fe18c67e7e9de611ca3的CI40124881177两作业success。此次仅收口任务文字，生产与测试不变；收口提交仍须当前SHA CI通过才合并。Done限定离线修复切片，父任务和平台/手机验收不关闭。
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
已修复孤立松手误耗药水和旧结束回合穿过新瞄准。红绿回归、独立评审、实现提交CI均通过；最终合并以PR195当前SHA门禁为准。未官方导入或实机验收。
<!-- SECTION:FINAL_SUMMARY:END -->
