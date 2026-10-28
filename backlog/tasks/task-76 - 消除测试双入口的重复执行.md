---
id: TASK-76
title: 消除测试双入口的重复执行
status: In Progress
assignee:
  - Furinya
created_date: '2026-10-28 03:45'
updated_date: '2026-10-28 06:47'
labels: []
dependencies: []
priority: high
ordinal: 120000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
JS包装器与raw Lua入口重复执行相同场景，拖慢回归。只归并已证明输入、环境和参数相同的运行，保留所有原断言及有效覆盖。技术证据见docs/backlog-details/TASK-76.md。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 按实测耗时列出重复候选，并说明等价或保留原因
- [ ] #2 归并后所有原断言和不同参数角色种子覆盖保留
- [ ] #3 对照原场景、数量和结果证明没有漏测
- [ ] #4 报告真实执行耗时，并分开说明本地串行与CI墙钟
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. 记录最新develop双入口调用和耗时基线。2. 逐项审查同环境同输入同参数，迁移可证明等价的fixture到单一JS入口；其他保留。3. 增加覆盖清单校验并比较场景输出、数量和断言。4. 本地验证后按用户紧急授权走精确HEAD的PR-only合并并跟踪完整CI。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
独立worktree基于origin/develop 8fe1b9fabaf296903d199aaaf616d98557f72c6b；原974个raw入口、292个JS测试文件、59个共享Lua支持文件已冻结摘要。Node22基线中断且有原超时，不作成功证据；改用已有便携Node24.18.0串行记录。历史Quality40623057222的972个raw日志已完整取回，只作耗时参考，不冒充当前源码或墙钟改善。

与并行CI任务发生本地编号75碰撞，已通过原生demote/promote保留内容并迁移为TASK-76，未覆盖远端TASK-75。已快进257d9e0c；其Lua场景、生产输入及runLua函数体均未变。首轮Node24包装基线290项中289通过、1项intent_artifact_playback原30s超时，0skip，不记全通过；单独重测该原组，不提高预算。

用户要求停止并交接后，另行授权创建草稿PR供审查。当前候选未完成、复验失败，不合并、不勾验收；完整交接见HANDOFF-TEST-DEDUP-20261028.md。
<!-- SECTION:NOTES:END -->
