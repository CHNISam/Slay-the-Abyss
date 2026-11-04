---
id: TASK-75.1
title: 降低完整回滚快照字段遍历开销
status: Done
assignee:
  - Furinya
created_date: '2026-11-04 15:44'
updated_date: '2026-11-04 20:29'
labels: []
milestone: m-7
dependencies: []
documentation:
  - docs/backlog-details/TASK-75.1.md
parent_task_id: TASK-75
priority: medium
type: bug
ordinal: 144000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
同一Silent四房双回放在多轮hosted Full触及原30秒预算。本轮画像142次完整快照占71.4%；只优化完整图复制成本，不省略目录或改变事务边界。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 原完整图96样本及深链、表键、false、alias、owner和rollback行为保持，真实漏图变异继续被断言拒绝
- [x] #2 同图交错样本和原Silent双回放记录真实前后耗时，原30秒预算与冻结fixture保持不变
- [x] #3 独立复审及精确HEAD Full与合后push验证分别通过
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. 固定现有完整快照及Silent画像，单变量验证重复key类型判定局部缓存。2. 仅采用交错样本支持的候选，保留值遍历、完整saved图和owner语义，补回归及原负例。3. 原双回放、相关工程检查、独立审查及精确Full后记录验收。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
采用单次capture内key类型缓存；16对交错样本及两对原Silent顺/反序记录于附件，原完整图和目录均保留。主控新增+继承合同9/9通过，未改原Silent原30秒入口本机26637ms通过。原3漏图变异仍拒绝，完整工程通过；独立精确提交审查、托管Full及合后仍待。

精确7ae源码Full41883245183及独审通过；原生组合41895552479成功并squash到a308edbf。行为与复杂度/依赖两项有本轮证据；合后41900003124仍待，AC3与任务状态保留未完成。

PR513实际a308合后Full41900003124 attempt1成功，原验证器22932b37给出merged_passed。源码41883245183、失败队列41889284736、成功队列41895552479及全部成本分别保留；见docs/evidence/m7-runtime-delivery-20261105.json。父74/75、M7整体及官方/设备未验边界不变。
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
完整快照采用单次key类型缓存，不排除目录或字段；最终组合受控Silent两对均值20.892→19.646秒，完整交付通过，设备性能仍未验。
<!-- SECTION:FINAL_SUMMARY:END -->
