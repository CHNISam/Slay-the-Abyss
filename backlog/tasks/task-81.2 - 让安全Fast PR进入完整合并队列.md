---
id: TASK-81.2
title: 让安全Fast PR进入完整合并队列
status: In Progress
assignee:
  - Furinya
created_date: '2026-11-06 15:41'
updated_date: '2026-11-07 02:44'
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
接续#529；实现精确Fast收据与PR准入，保留高风险Full、队列完整Full及合后Full；独审和当前SHA CI通过后切换Ruleset，真实安全PR验证入队、squash与合后验收。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
2026-11-06只读审计：TASK-81仍In Progress；PR307已提供Fast选择但原Ruleset六项Required含full-quality；scripts/publish-full-quality.mjs拒绝Fast发布Full成功，scripts/arm-auto-merge.mjs只接受Full入队。PR525已合入并发优化，PR527在做Sapphire超时；本任务不重复两者。开发、规则变更及真实Fast样本均未执行，验收保持未勾。

已接续#529任务定义，实现pr-quality、双平台Fast不可变收据、schema6/7/8与原生队列Full/合后Full验证。固定Node24相关合同129/129及Fast组合回归29/29通过；远端Ruleset尚未切换，真实Fast链路尚待。技术证据docs/backlog-details/TASK-81.2.md，AC保持未勾。

2026-11-07已读回远端pr-quality/Strict/空bypass/SQUASH ALLGREEN队列。#538正常queue Full42323846768通过并实际合为2c85bc61，合后Full42327242610验收发现slice3超时。#539从该真实base直接Ready且精确独审，正常Quality42327477690实际Fast；尚待完整自动链路。Free计划与20个Full活跃槽已读回，资源排队和真实执行分开；未取消必要验证或改保护/预算。技术证据追加TASK-81.2附件，AC保持未勾。

#539旧c7 Fast已完成8项合同，13分11秒，双平台执行33/27秒，原入口dry-run eligible。但#538合后Full Win1真实失败后没有发布授权、没有入队；将已审M7成果与阶段诊断正常追加539，新HEAD必须新独审/Full，旧Fast不冒充新组合或完整链路通过。
<!-- SECTION:NOTES:END -->
