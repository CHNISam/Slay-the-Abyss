---
id: TASK-89
title: 修复结束战斗后旅行者立绘高频退化为占位图
status: In Progress
assignee:
  - Furinya
created_date: '2026-10-30 21:58'
updated_date: '2026-10-30 22:46'
labels:
  - playtest-20261030
  - p0
  - gpt
milestone: m-5
dependencies: []
references:
  - docs/backlog-details/PLAYTEST-20261030.md
  - docs/backlog-details/MOBILE-QA-20261029.md
parent_task_id: TASK-25
priority: medium
type: bug
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Owner实机反馈：点击结束战斗后，原本正常显示的旅行者立绘以报告约90%以上、接近必现的频率变成黄色几何占位图；个别进入战斗时也出现占位。此为用户报告，当前候选SHA与技术根因待独立核查；不要把预加载/回收假设当结论。GROK仅协作可见结果。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 正确呈现岩系旅行者自制战斗形象；在战斗结束及紧接的状态/场景切换中不退化为黄色占位图。
- [ ] #2 保留用户所述触发路径及当前候选/设备复测证据，明确独立复现率和实际原因；非当前候选测试不得冒充验证。
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. 对照最新develop与396候选，追踪立绘装配、反馈逐帧与结束复位的所有权。2. 用真实Feedback夹具证明并修复常态色被岩元素色覆盖，验证动作和取消不改图像身份。3. 核对候选显式美术开关与资源绑定，独立评审和受影响CI并行；原90%实机原因与同候选复测证据未齐不勾验收。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
本轮离线复现：新增真实Feedback肖像中性色断言，在未修源码idle阶段失败。最小修复仅resetUnit与actor painter玩家基础色从geo改buttonPressedText，敌人及受击特效色不改。回归确认idle/attack/cancel/战斗退休/隐藏/下一战保持中性色及图像ID，原生位移、HUD、HP能量事件不变；现有actor_idle_feedback五组及actor_feedback_lifecycle通过。该缺陷只证明常态染色覆盖，未证明原报告90%资源退化原因；未官方导入、未本轮设备复测，AC保持未勾。
<!-- SECTION:NOTES:END -->
