---
id: TASK-62
title: 导入原创四角色冻结卡表并验证完整性
status: In Progress
assignee:
  - Furinya
created_date: '2026-10-26 05:23'
updated_date: '2026-10-26 05:52'
due_date: '2026-10-28'
labels: []
milestone: m-4
dependencies: []
priority: high
type: feature
ordinal: 109000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
附件数值必须原样进入同源Lua构建，不能丢牌或重复扣雷电格挡。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 300稳定ID及600基础升级完整；冻结输入hash匹配；未知DSL与输出覆盖拒绝
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
独立工作树实现严格加载/生成与数据回归；仅4文件，核心接入由TASK61负责。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
独立Executor codex-v4-data/session4c1500c6，source ab95633。4文件精确scope，canonical字节未变；数据定向28过及600定义真实Lua读回通过。独立lease已释放交统一集成，未计玩法或实机。
<!-- SECTION:NOTES:END -->
