---
id: TASK-14.1.2
title: 选药水后拒绝旧松手和旧回合操作
status: In Progress
assignee:
  - '@Furinya'
created_date: '2026-10-24 19:17'
due_date: '2026-10-28'
labels: []
milestone: m-4
dependencies:
  - TASK-14.1.1
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
- [ ] #1 没有对应按下的敌人松手事件不得确认并消耗药水
- [ ] #2 进入药水瞄准前的结束回合手势不得推进回合
- [ ] #3 新手势、纯点击兼容和现有取消方式保持有效
- [ ] #4 最小回归先红后绿并经独立评审；最终提交通过仓库CI，实机结果另记
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. 在最新develop复现两处问题并保留原日志。2. 仅补两个输入失效边界和独立回归。3. 独立评审与最终SHA CI通过后正常合并；不接管父任务或其他在途UI。
<!-- SECTION:PLAN:END -->
