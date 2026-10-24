---
id: TASK-16.1.1
title: 修复能力牌打出后误入消耗堆
status: Done
assignee:
  - '@dot'
created_date: '2026-10-23 18:13'
updated_date: '2026-10-23 19:34'
labels: []
dependencies: []
references:
  - 'https://github.com/CHNISam/Slay-the-Abyss/pull/128'
parent_task_id: TASK-16.1
priority: high
type: bug
ordinal: 57000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
已可用的能力牌打出后错误计入消耗堆。仅核对并修正能力牌离手后的去向，保留效果、能量与异常回滚，不接管父任务其他共享算法工作。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 固定来源证明能力牌打出后不进入弃牌或消耗堆，保留普通攻击和显式消耗规则
- [x] #2 真实出牌入口先复现失败，再验证基本与升级能力牌、重复使用与异常回滚边界
- [x] #3 独立评审与当前提交CI通过；平台未验及完整规则差异明确保留
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
核对来源及其他分支修改范围；建立真实入口负例；最小修改能力牌去向并修正错误旧预期；独立评审后正常PR集成。
<!-- SECTION:PLAN:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
PR128 / a804e98 已合并。19专项、95原生Lua文件及独立10负控通过；合后CI40003011666成功。能力牌去向修复完成，完整hooks/平台与父任务未完成。
<!-- SECTION:FINAL_SUMMARY:END -->
