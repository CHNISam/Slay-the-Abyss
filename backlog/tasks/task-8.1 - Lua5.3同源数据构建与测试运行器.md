---
id: TASK-8.1
title: Lua5.3同源数据构建与测试运行器
status: To Do
assignee:
  - Furinya
created_date: '2026-10-22 14:33'
labels: []
dependencies: []
parent_task_id: TASK-8
ordinal: 23000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
战斗核心直接使用平台Lua53，离线验证必须执行同一源码，避免JS和Lua双份规则漂移。只做数据转码与测试运行，不实现战斗规则。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 JSON六表确定性生成Lua模块，失败输入不可构建
- [ ] #2 使用成熟Lua5.3运行器执行真实生产Lua模块的测试并接入有限时CI
<!-- AC:END -->
