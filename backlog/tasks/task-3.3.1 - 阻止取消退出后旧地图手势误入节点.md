---
id: TASK-3.3.1
title: 阻止取消退出后旧地图手势误入节点
status: In Progress
assignee:
  - '@dot'
created_date: '2026-10-24 01:50'
updated_date: '2026-10-24 02:16'
due_date: '2026-10-26'
labels: []
milestone: m-3
dependencies: []
references:
  - 'https://github.com/CHNISam/Slay-the-Abyss/pull/150'
parent_task_id: TASK-3.3
priority: high
type: bug
ordinal: 74000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
最新 develop 7bf237af 真实 GameUI 复现：地图按下后打开并取消退出，再开始新触摸，旧触点松开可把原局从地图推进到战斗。仅修地图输入归属，父任务负责人、平台验收与玩法规则不变。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 取消退出后旧地图触点不能进入节点或推进本局
- [ ] #2 第二触点及旧本局回调不能夺取当前地图手势；合法新点击与拖动仍正常
- [ ] #3 真实生成界面与宿主流程回归及独立负例验证通过
- [ ] #4 保留原地图生成、事件规则与视觉布局，区分本地测试和未执行的手机实测
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
保留当前真实宿主红例；在 map_ui 内实现最小手势身份与失效边界；补旧触点/多触点/换局与正常操作回归；独立评审后走原 PR 和 CI。
<!-- SECTION:PLAN:END -->
