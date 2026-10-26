---
id: TASK-68
title: 缩短工程回归等待并清理已确认债务
status: In Progress
assignee:
  - Furinya
created_date: '2026-10-26 08:10'
updated_date: '2026-10-26 08:10'
labels: []
dependencies: []
priority: high
ordinal: 115000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
按用户限定范围修复Quality失败、分级测试与重复工作、依赖和历史告警。用户明确要求简化旧认领阻塞、使用官方Runner并完成合并。详情见docs/backlog-details/task-68.md。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 官方Runner通过当前SHA完整检查并记录655根因
- [ ] #2 按模块依赖选择快速与相关集成测试，未知变更保守回退全量
- [ ] #3 审查四个大模块及延迟依赖，保留行为与异常回滚
- [ ] #4 缩减维护性告警并更新工程数据和证据策略
- [ ] #5 记录前后验证数据并合并develop
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1.复用211/212已实现修复，核对655/659基础设施故障。2.使用官方Windows/Ubuntu Runner并简化过期认领阻塞，完整质量门禁不降级。3.增加依赖驱动快速/相关测试和安全回退，优化重复fixture准备。4.删除重复定义及无用局部，复核19延迟边，更新准确文档及证据策略。5.定向和完整回归，当前SHA CI成功后squash合并并清理。
<!-- SECTION:PLAN:END -->
