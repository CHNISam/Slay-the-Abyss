---
id: TASK-14
title: M2 跨节点状态持久化：血量/金币/卡组/遗物/药水
status: To Do
assignee: []
created_date: '2026-10-22 13:47'
updated_date: '2026-10-23 01:52'
due_date: '2026-10-26'
labels: []
milestone: m-3
dependencies:
  - TASK-12
  - TASK-13
ordinal: 14000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
跨节点存档状态：血量、金币、卡组、遗物、药水，以及死亡重开重置。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 血量、金币、卡组、遗物、药水跨节点保留
- [ ] #2 遗物效果在后续战斗真正生效
- [ ] #3 死亡后重开，状态正确重置
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
执行身份 /root/inventory（2026-10-23）：在现有 feat/task-14-inventory 独立工作树审查并保留遗留未提交实现；核验跨节点资源、7 遗物/7 药水及死亡重开。补齐实质缺口和离线回归测试；不启动原神、不操作 live MCP，平台及实机验收保留。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
本轮执行身份 /root/inventory；原负责人不变。TASK-12/13 仍未全部验收，仅推进现有分支可执行的离线部分，暂不宣告依赖满足。
<!-- SECTION:NOTES:END -->
