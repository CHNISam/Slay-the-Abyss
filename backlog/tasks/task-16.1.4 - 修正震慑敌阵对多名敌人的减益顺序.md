---
id: TASK-16.1.4
title: 修正震慑敌阵对多名敌人的减益顺序
status: In Progress
assignee:
  - '@dot'
created_date: '2026-10-24 13:04'
updated_date: '2026-10-24 13:22'
due_date: '2026-10-28'
labels:
  - required
milestone: m-4
dependencies:
  - TASK-16.1.3
references:
  - docs/backlog-details/TASK-16.1.md
  - docs/reviews/TASK-16-m3-card-audit.md
  - docs/reviews/TASK-16.1.4-shockwave-order.md
parent_task_id: TASK-16.1
priority: high
type: bug
ordinal: 88000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
目前先对所有敌人施加虚弱，再对所有敌人施加易伤；应按敌人顺序逐个施加两种减益。最终层数相同也不能代替正确的中间状态与反馈顺序。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 基础和升级牌都按敌人顺序先虚弱后易伤，费用、层数、消耗与原表现不变。
- [ ] #2 免疫逐次正确消耗，死亡或逃跑目标跳过；事件快照与实际状态一致。
- [ ] #3 旧无标记群体效果保持原顺序，坏分组在本次效果副作用前拒绝，合法出牌失败完整回滚。
- [ ] #4 固定来源、真实入口、状态帧、文案与详情回归通过独立评审及当前CI；平台实测单独记录。
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
已用30真实入口复现22多活敌顺序/快照负例并核固定来源。保留两条平铺applyStatusAll与现有表现索引，用受限显式targetGroup=weak_then_vulnerable两项组实现逐敌执行，schema与supported校验局部组，apply仅预检新标记而不改变无标记旧错误时机。保持共享Actor、Run、RNG及现有死敌/源死亡/末敌清理和出牌事务。先红后绿，独立评审后按当前CI交付。

全量构建实证发现Python表现生成器也严格校验effect字段：在tools/render_traveler_cards.py仅补同一受限targetGroup协议，保留其他字段门禁与全部模板/索引，新增Python正负例。重新build-ui并用新产物复验文案/详情/群体反馈，不能复用旧生成文件冒充新数据通过。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
1313首候选30真实入口顺序/帧已过，但build-ui因Python unknown fields targetGroup失败，4个Node构建链回归同因失败；另3个wrapper缺Fengari不计通过。已限定新增第4生产路径为现有表现验证器并补先红后绿，未改UI设计、数值或预算。

1320候选已补Python生成链并将新标记发现改为显式工作栈，修复独立评审实证的1万层无标记RangeError回归。正式data/UI/theme构建、171原生Lua、1085纯Node、22Python与9个负变异通过；独立141运行、59schema、深树/DAG及整份表现输出全等通过。旧1313/1317失败记录保留；仍待当前提交CI与合并，无Fengari本地或平台验收声明。
<!-- SECTION:NOTES:END -->
