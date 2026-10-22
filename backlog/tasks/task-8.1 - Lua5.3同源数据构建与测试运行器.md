---
id: TASK-8.1
title: Lua5.3同源数据构建与测试运行器
status: In Progress
assignee:
  - Furinya
created_date: '2026-10-22 14:33'
updated_date: '2026-10-22 14:37'
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

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. 六表先经validateContent校验再确定性转码Lua模块。2. Fengari成熟Lua53运行器执行同源生产模块与有限超时，补转义/负例/roundtrip测试。3. 与质量门禁集成、独立PR待主Agent审查。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
CLAIM 子Agent quality-gates；负责人Furinya；分支feat/task-8-1-lua-harness；worktree .worktrees/lua-harness；修改仅构建/运行器/对应JS测试/package/CI/gitignore，不修改src/lua和tests/lua/combat.lua。

已实现构建器、Lua运行器及JS测试初稿；node --check三份源码通过。尚未安装依赖或宣称测试通过，等待PR1进入develop后合入最终package配置。
<!-- SECTION:NOTES:END -->
