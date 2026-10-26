---
id: TASK-68
title: 接通官方运行器与原创角色合并前置
status: In Progress
assignee:
  - Furinya
created_date: '2026-10-26 08:12'
labels: []
dependencies: []
ordinal: 115000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
将用户指定的GitHub官方托管运行器、原创角色有界执行登记和既有遭遇回归夹具合并为一个受控前置候选。技术说明见 docs/backlog-details/task-68.md。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 全部质量作业使用GitHub官方托管运行器并保留检查
- [ ] #2 前置修复保持精确范围和旧执行者隔离
- [ ] #3 当前SHA所有检查通过并受控合入develop
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
承接已发布并释放的55与67，校验当前候选，官方托管CI全绿后受控合并并释放。
<!-- SECTION:PLAN:END -->
