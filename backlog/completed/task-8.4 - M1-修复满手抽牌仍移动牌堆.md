---
id: TASK-8.4
title: 修复手牌已满时仍抽牌并丢弃
status: Done
assignee:
  - Furinya
created_date: '2026-10-22 22:41'
updated_date: '2026-10-22 23:00'
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
- [x] #1 满手与抽满后不再移动牌堆或改变RNG/events；保留对象和UID
- [x] #2 剩一格、跨洗牌、空堆、禁抽及出牌腾空位真实数据与Run回归通过
- [x] #3 独立develop候选与PR37兼容增量分别验证；原过时契约明确修正，无平台通过声明
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. 基于真实 develop 建立容量红测。
2. 抽牌前检查容量，满手立即停止且不洗牌。
3. 修正过时契约，验证对象、UID、RNG、events 与 Run 路径。
4. 验证 PR37 兼容增量并经独立审查、当前 SHA CI 后合并。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- 原实现7组容量红测，修复后核心23组通过；独立候选系统Lua161、组合376、Python各13通过，独立审查无阻断。
- PR45 head 2be653c6ecbe75a00be1737fd39db24cc15fb794 正式CI双success：Windows JS124通过/0失败/6跳过，Fengari161（含核心23、原子性14）。https://github.com/CHNISam/Slay-the-Abyss/actions/runs/39867634290
- 父级UI加抽牌组合复验：系统Lua387、Python16通过；9个生产JSON逐blob未变，仅纠正README抽牌契约。
- 本地npm缺Fengari的7项失败由上述正式CI补证，不混同系统Lua。未平台编译、导入或实机验收。
- 保持In Progress；元数据提交后重跑当前head CI，实际合并后再Done。

PR45 已合并：1217abb22ded7b2bd8195e21f7dfdc9efa44181e；最终head 366753f6957980237a8a652923de11fb6ab83541 的CI 39868328456两项成功。https://github.com/CHNISam/Slay-the-Abyss/actions/runs/39868328456 。本任务本地规则修复已真实收口，平台编译、导入及实机验收不在本任务通过结论内。
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
满手抽牌立即停止且不移动牌堆、不额外洗牌；保留出牌腾出的手牌空间。容量、对象身份、UID、RNG/events及真实Run路径回归通过，PR37兼容增量独立审查无阻断。PR45最终head366753f经CI39868328456双成功后合并为1217abb；生产JSON未变，旧README契约已纠正。
<!-- SECTION:FINAL_SUMMARY:END -->
