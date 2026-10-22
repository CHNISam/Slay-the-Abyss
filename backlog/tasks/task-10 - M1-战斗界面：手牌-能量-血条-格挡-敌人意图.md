---
id: TASK-10
title: M1 战斗界面：手牌/能量/血条/格挡/敌人意图
status: In Progress
assignee:
  - '@Codex'
created_date: '2026-10-22 13:47'
updated_date: '2026-10-22 16:05'
due_date: '2026-10-24'
labels: []
milestone: m-2
dependencies:
  - TASK-8
ordinal: 10000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
用客户端 Lua 或节点图实现战斗界面，保证信息可读。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 手牌可见可选，出牌后即时刷新
- [ ] #2 能量、血量、格挡、敌人意图显示正确
- [ ] #3 手机画布下 UI 不出屏
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. 接续已有原生战斗界面与旅行者显示构建，连接真实Run/Combat。2. 核验点击刷新、状态与修改后的敌人意图，补回归并接入统一构建门禁。3. 记录布局自动验证和未完成的平台多设备/存档/实机验证，不越级勾选。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
2026-10-23 接续执行/root；干净集成分支feat/backlog-sprint，worktree .worktrees/runtime-integration，保留旧battle-ui工作树未提交文件；各subagent负责独立模块。
<!-- SECTION:NOTES:END -->
