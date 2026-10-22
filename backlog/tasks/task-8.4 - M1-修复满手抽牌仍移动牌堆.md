---
id: TASK-8.4
title: M1 修复满手抽牌仍移动牌堆
status: In Progress
assignee:
  - Furinya
created_date: '2026-10-22 22:41'
updated_date: '2026-10-22 22:45'
labels: []
milestone: m-2
dependencies: []
references:
  - 'https://store.steampowered.com/news/posts/?appids=646570&enddate=1542372031'
parent_task_id: TASK-8
priority: high
type: bug
ordinal: 37000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Executor: dot。原版满手应立即停抽且不触发洗牌，当前实现错误消耗抽牌堆并将溢出弃置。仅修复抽牌容量语义，不改变卡牌数值、Actor、Effects或UI。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 满手与抽满后不再移动牌堆或改变RNG/events；保留对象和UID
- [ ] #2 剩一格、跨洗牌、空堆、禁抽及出牌腾空位真实数据与Run回归通过
- [ ] #3 独立develop候选与PR37兼容增量分别验证；原过时契约明确修正，无平台通过声明
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. 在真实develop建立红测。2. 在draw循环最先检查容量并删除溢出路径。3. 修正契约并全回归。4. 对精确PR37 head制作最小兼容增量并记录证据。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
独立候选基于develop38edbccc；满手停抽7组原版偏差红测后修复，Combat仅修改draw。系统Lua5.4全161组通过，Python13通过。npm check真实执行JS123/130通过，7项因缺Fengari失败，无安装/绕过。PR37精确head18ecbf4的73个源码/数据/测试/脚本blob先逐一验证，组合增量仅draw与过时容量测试/README；系统Lua376组、Python13通过。所有生产JSON逐blob保持不变，README契约已纠正。等待父级独立审查与当前SHA正式CI，不标平台通过或Done。
<!-- SECTION:NOTES:END -->
