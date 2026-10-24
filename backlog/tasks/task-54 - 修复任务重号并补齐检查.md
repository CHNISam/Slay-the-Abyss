---
id: TASK-54
title: 修复任务重号并补齐检查
status: In Progress
assignee:
  - '@dot'
created_date: '2026-10-24 16:49'
due_date: '2026-10-28'
labels:
  - required
milestone: m-5
dependencies: []
references:
  - docs/DELIVERY-CLOSEOUT.md
  - scripts/verify-backlog-roadmap.mjs
priority: high
type: bug
ordinal: 92000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
并行分支分别创建了TASK-52.1，合入后两项不同工作重号，原生CLI会阻止按ID操作。修复已发生的冲突，并让现有检查报出重号，不再静默覆盖其中一项。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 两项工作各有唯一编号，负责人、范围、状态、验收及历史正文保持不变。
- [ ] #2 只核对冲突对应引用，诊断任务52.1的正确引用保留，不做全局替换。
- [ ] #3 现有检查能报出活动或已完成任务中的重复编号及具体文件，真实重号负例先失败后被检出。
- [ ] #4 原生doctor、相关回归和独立检查通过；不新增管理系统、不改变游戏行为。
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
以最新695d94d完整152个Backlog blob为基线。先用原生doctor预览并原子修复：保留较早诊断52.1，将HUD任务只改ID/路径为52.2，逐byte确认其他内容不变。人工核对ambiguous引用。随后最小补现有verify-backlog-roadmap的重复ID检查及测试，覆盖Done与active/completed，沿用原生身份语义、不新增标题格式规则。所有仓内改动走同一PR与精确头CI。
<!-- SECTION:PLAN:END -->
