---
id: TASK-68
title: 缩短工程回归等待并清理已确认债务
status: Done
assignee:
  - Furinya
created_date: '2026-10-26 08:10'
updated_date: '2026-10-26 12:52'
labels: []
dependencies: []
references:
  - docs/BACKLOG-AUDIT-20261026.md
priority: high
ordinal: 115000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
按用户限定范围修复Quality失败、分级测试与重复工作、依赖和历史告警。用户明确要求简化旧认领阻塞、使用官方Runner并完成合并。详情见docs/backlog-details/task-68.md。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 官方Runner通过当前SHA完整检查并记录655根因
- [x] #2 按模块依赖选择快速与相关集成测试，未知变更保守回退全量
- [x] #3 审查四个大模块及延迟依赖，保留行为与异常回滚
- [x] #4 缩减维护性告警并更新工程数据和证据策略
- [x] #5 记录前后验证数据并合并develop
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1.复用211/212已实现修复，核对655/659基础设施故障。2.使用官方Windows/Ubuntu Runner并简化过期认领阻塞，完整质量门禁不降级。3.增加依赖驱动快速/相关测试和安全回退，优化重复fixture准备。4.删除重复定义及无用局部，复核19延迟边，更新准确文档及证据策略。5.定向和完整回归，当前SHA CI成功后squash合并并清理。

2026-10-26收口：核对最新合入、既有交付和平台矩阵，复跑相关原回归；开发与整体验收责任明确分层，原失败记录保留。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
用户在解释后明确批准取消额外任务锁；保留Backlog/独立分支/PR/当前SHA完整Quality。PR216同步刚合入的PR215官方windows-2025与固定Actions，不覆盖其可信local-special诊断限制。静态125→116、延迟例外19→16；快速样本7文件16断言7.818秒；UI矩阵198组合原13.293秒→4.039秒，全部原断言保留。完整本地Lua阶段与当前head官方CI进行中，不计作最终通过。

2026-10-26全面复核：GitHub只读核实PR216已于2026-10-26T09:29:46Z合入4c75a31f；最终check/presentation/engineering-posix全SUCCESS，run40294540283。分级选择、重构、测量与告警改进详见原附件，旧待CI说明失效。
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
GitHub只读核实PR216已于2026-10-26T09:29:46Z合入4c75a31f；最终check/presentation/engineering-posix全SUCCESS，run40294540283。分级选择、重构、测量与告警改进详见原附件，旧待CI说明失效。 完整责任与证据见docs/BACKLOG-AUDIT-20261026.md
<!-- SECTION:FINAL_SUMMARY:END -->
