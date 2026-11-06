---
id: TASK-81.2
title: 让安全Fast PR进入完整合并队列
status: To Do
assignee:
  - Furinya
created_date: '2026-11-06 15:41'
updated_date: '2026-11-06 15:41'
labels: []
milestone: m-7
dependencies: []
parent_task_id: TASK-81
priority: medium
type: enhancement
ordinal: 162000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
TASK-81已有按影响选测，但当前develop Ruleset 25870651强制full-quality，原生自动合并入口也要求PR Full，导致安全Fast不能真正缩短PR入队等待。复用现有选测与Merge Queue，打通PR Fast→队列Full，不另建测试平台、不重复PR525/527的超时修复。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 核对当前真实Ruleset、影响选测、Full发布器、auto-merge/交付验证器与既有PR，形成最小一致变更；不得把Fast冒充Full、丢弃失败或伪造旧收据
- [ ] #2 已完整映射且低风险的PR在双平台Fast及独立审查通过后可正常进入原生Merge Queue；核心/未知/删除/超预算仍走PR Full，取消/失败/缺片/旧SHA一律拒绝
- [ ] #3 原生队列必须在真实组合SHA完成原Full全量及全部必要校验后才能squash；合后develop push继续Full，原有保护、来源与可恢复性保留
- [ ] #4 用真实安全Fast PR和故障负例验收入队、组合失败阻断、成功合并及合后收据；报告PR/队列/push耗时和重复Full成本，未实测不宣称达成TASK-81性能目标
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
先复核PR307/502/508/525/527与TASK-81，确认没有现有同功能PR；以当前Ruleset读回为准，将CI Required状态、原生自动合并准入、交付证据及队列Full同步设计和最小修改，先在隔离候选验证反例，再独审并按原生队列正常集成。不可仅从Ruleset删除full-quality或改写其语义来绕过门禁；保留高风险PR Full和队列/推送完整检查。此子任务只处理Fast合并准入，不扩展为Harness重构。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
2026-11-06只读审计：TASK-81仍In Progress；PR307已提供Fast选择但原Ruleset六项Required含full-quality；scripts/publish-full-quality.mjs拒绝Fast发布Full成功，scripts/arm-auto-merge.mjs只接受Full入队。PR525已合入并发优化，PR527在做Sapphire超时；本任务不重复两者。开发、规则变更及真实Fast样本均未执行，验收保持未勾。
<!-- SECTION:NOTES:END -->
