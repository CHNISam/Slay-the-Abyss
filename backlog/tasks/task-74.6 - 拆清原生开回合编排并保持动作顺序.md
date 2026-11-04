---
id: TASK-74.6
title: 拆清原生开回合编排并保持动作顺序
status: Done
assignee:
  - Furinya
created_date: '2026-11-04 14:50'
updated_date: '2026-11-04 20:29'
labels: []
milestone: m-7
dependencies: []
references:
  - docs/plans/2026-11-03-m7-engineering-foundation.md
documentation:
  - docs/backlog-details/TASK-74.6.md
parent_task_id: TASK-74
priority: medium
type: task
ordinal: 143000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
最新develop的原生开回合入口仍混合临时能力清理、能力入队和抽牌编排；已合入的选择协议与反应入队切片未覆盖此入口。本切片仅治理同模块职责，不改实验协议或玩法。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 固定旧源码与新实现的回合状态、队列、RNG、事件、别名及失败边界差分通过，真实错误变异被行为断言拒绝
- [x] #2 入口及全部新增helper纳入现有复杂度门禁，公布前后绝对值与依赖变化
- [x] #3 相关回归、独立审查及精确HEAD完整CI通过；合后验证单独记录
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. 固定b4ac6314旧源与相关回归，记录开回合状态/队列/RNG/事件边界。2. 在原模块拆分清理、开回合能力及抽牌编排，原调度顺序不变；纳入全部helper复杂度门禁。3. 旧新差分及错误变异、相关工程检查、独立复审通过后提交PR，Full与合后验收分别记录。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
本轮同模块四职责切片完成；固定旧源12场景差分与5真实变异、17项定向合同、五个既有Lua入口通过。入口CC22→12，helper2/4/5/3；全库>15为282→281，最大82及SCC104成员保留。工程/原四变异/原生合同通过。独立dirty树预审无问题，最终SHA独审、Full及合后验证另验，AC不提前勾选。

本轮Full41853028063 rules4原Silent双回放30058ms超时；独立日志核查未发现本切片断言失败。已用merge:auto --pause读回paused，新增独立TASK75.1修完整快照瓶颈；完整CI及合后AC保持未完成。

精确7ae源码Full41883245183及独审通过；原生组合41895552479成功并squash到a308edbf。行为与复杂度/依赖两项有本轮证据；合后41900003124仍待，AC3与任务状态保留未完成。

PR513实际a308合后Full41900003124 attempt1成功，原验证器22932b37给出merged_passed。源码41883245183、失败队列41889284736、成功队列41895552479及全部成本分别保留；见docs/evidence/m7-runtime-delivery-20261105.json。父74/75、M7整体及官方/设备未验边界不变。
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
原生开回合CC22→12，清理、能力和抽牌职责分开；旧新差分、真实变异、精确独审及完整交付终验通过。
<!-- SECTION:FINAL_SUMMARY:END -->
