---
id: TASK-54
title: 修复任务重号并补齐检查
status: Done
assignee:
  - '@Furinya'
created_date: '2026-10-24 16:49'
updated_date: '2026-10-27 15:04'
due_date: '2026-10-28'
labels:
  - required
milestone: m-5
dependencies: []
references:
  - docs/DELIVERY-CLOSEOUT.md
  - scripts/verify-backlog-roadmap.mjs
  - docs/reviews/TASK-54-backlog-id-integrity.md
priority: medium
type: bug
ordinal: 92000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
并行分支分别创建了TASK-52.1，合入后两项不同工作重号，原生CLI会阻止按ID操作。修复已发生的冲突，并让现有检查报出重号，不再静默覆盖其中一项。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 两项工作各有唯一编号，负责人、范围、状态、验收及历史正文保持不变。
- [x] #2 只核对冲突对应引用，诊断任务52.1的正确引用保留，不做全局替换。
- [x] #3 现有检查能报出活动或已完成任务中的重复编号及具体文件，真实重号负例先失败后被检出。
- [x] #4 原生doctor、相关回归和独立检查通过；不新增管理系统、不改变游戏行为。
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
以最新695d94d完整152个Backlog blob为基线。先用原生doctor预览并原子修复：保留较早诊断52.1，将HUD任务只改ID/路径为52.2，逐byte确认其他内容不变。人工核对ambiguous引用。随后最小补现有verify-backlog-roadmap的重复ID检查及测试，覆盖Done与active/completed，沿用原生身份语义、不新增标题格式规则。所有仓内改动走同一PR与精确头CI。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
真实695d94d的双Done52.1在旧检查exit0、原生doctor exit1。原生doctor修复仅HUD的ID与文件名为52.2，其他正文逐byte不变，诊断52.1引用保留。新校验器21项回归通过；移除身份保护/忽略completed负变异分别7/4项失败。root复跑新门禁及doctor均exit0。独立复审及最终SHA CI尚待，不计已合并交付。

独立复核绑定脚本74c197e/测试9222d29：25组身份对照与原生doctor一致，真实152个源blob复核，4种负变异均失败（7/4/1/1项）。completed祖先推导保留，HUD仅ID/路径改变。此Done表示本任务有限离线实现与审查完成；PR192尚未合入，最终SHA完整CI仍作为合并门禁。

负责人字段规范化：原记录 @dot 作为历史执行者信息保留；任务负责人为 Furinya。
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
已用原生doctor消除52.1重号，HUD任务改为52.2且原内容不变；既有门禁新增全目录身份检查，21项回归及独立负例验证通过。交付证据见PR192与TASK-54审查页；合并前须最终SHA CI通过。
<!-- SECTION:FINAL_SUMMARY:END -->
