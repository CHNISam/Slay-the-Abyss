---
id: TASK-81
title: 按改动运行快速检查并保留完整回归
status: In Progress
assignee:
  - Codex
created_date: '2026-10-28 15:30'
updated_date: '2026-10-28 16:03'
labels: []
dependencies: []
priority: medium
ordinal: 125000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
方案与真实Runner证据见docs/CI-FAST.md。普通PR消除重复回归，保留高风险完整检查。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 普通PR按影响选测；高风险及develop和发版完整回归
- [ ] #2 保留断言与Required Checks；失败取消缺失均拒绝
- [ ] #3 真实Runner Fast P50≤5分钟、P90≤10分钟；Full≤30分钟
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
采集基准与保护；实现影响计划和稳定汇总；负例与真实Runner验收。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
PR307；固定Node24.18.0专项32项通过，后续手动诊断输入与门禁9项通过。YAML/Bash语法通过；规则集证据已保存，无保护修改。当前远端Quality40716938768仍排队，未完成Full/Fast性能验收。创建时发现未合入审计工作树已占TASK80，改用TASK81；误建草稿6/7未提交。

PR307头11ff8b98真实Windows8片失败：原ci-downloads负例将第一个npm安装重试改99，但检查器只审旧rules作业，新增impact未纳入。最小修复将npm限制扫描扩展到整个Quality工作流，并逐安装步骤变异拒绝99重试。原失败与新负例本地Node24.18.0均通过，不删除原断言，不提高预算。

7058fb85真实Win4暴露原pr-history顺序断言失败：impact安装先于旧rules历史检查。将历史API检查前移到impact首次npm之前，移除rules和metadata重复调用；原顺序断言保留，调用计数加强为全文精确一次。全部CI合同（含Git真实下载/分片/冻结工作流/历史/快反馈）38/38通过0skip，Node24.18.0耗时42.3秒。两份原始失败日志已保存根.artifacts/ci-fast-pr307，不追认旧运行。
<!-- SECTION:NOTES:END -->
