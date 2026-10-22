---
id: TASK-8.2
title: 独立审查 TASK-8 战斗核心与同源Lua工具
status: To Do
assignee:
  - Furinya
created_date: '2026-10-22 14:43'
labels: []
dependencies: []
parent_task_id: TASK-8
ordinal: 24000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
由未参与核心实现的Agent审查核心状态机及同源工具，重点检查抽弃牌、格挡时序、意图一致性和命令原子性。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 独立运行核心行为与失败路径测试，报告并复验阻断问题
- [ ] #2 确认平台Lua53兼容性、数据单源和未实现范围，避免将离线测试冒充游戏验收
<!-- AC:END -->
