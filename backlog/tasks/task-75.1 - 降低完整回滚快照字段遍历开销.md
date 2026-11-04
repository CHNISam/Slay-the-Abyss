---
id: TASK-75.1
title: 降低完整回滚快照字段遍历开销
status: In Progress
assignee:
  - Furinya
created_date: '2026-11-04 15:44'
updated_date: '2026-11-04 15:50'
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
- [ ] #1 原完整图96样本及深链、表键、false、alias、owner和rollback行为保持，真实漏图变异继续被断言拒绝
- [ ] #2 同图交错样本和原Silent双回放记录真实前后耗时，原30秒预算与冻结fixture保持不变
- [ ] #3 独立复审及精确HEAD Full与合后push验证分别通过
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. 固定现有完整快照及Silent画像，单变量验证重复key类型判定局部缓存。2. 仅采用交错样本支持的候选，保留值遍历、完整saved图和owner语义，补回归及原负例。3. 原双回放、相关工程检查、独立审查及精确Full后记录验收。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
采用单次capture内key类型缓存；16对交错样本及两对原Silent顺/反序记录于附件，原完整图和目录均保留。主控新增+继承合同9/9通过，未改原Silent原30秒入口本机26637ms通过。原3漏图变异仍拒绝，完整工程通过；独立精确提交审查、托管Full及合后仍待。
<!-- SECTION:NOTES:END -->
