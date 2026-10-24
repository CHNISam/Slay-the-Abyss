---
id: TASK-13.1
title: 核对事件、商店价格和奖励规则
status: In Progress
assignee:
  - '--plan'
created_date: '2026-10-23 01:56'
updated_date: '2026-10-24 03:10'
due_date: '2026-10-28'
labels:
  - required
  - rule-parity
milestone: m-4
dependencies:
  - TASK-13
  - TASK-14
references:
  - data/SOURCES.md
  - src/lua/abyss_nodes.lua
  - src/lua/abyss_run.lua
  - docs/backlog-details/TASK-13.1.md
parent_task_id: TASK-13
priority: high
type: enhancement
ordinal: 41000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
把首发里会出现的事件、商店和奖励按原版逐项检查，修掉固定价格或错误概率等问题。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 每项规则都有原版依据，未查清的地方明确列出。
- [ ] #2 事件选项、未知房间变化、营地回血和升级、宝箱产出与原版一致。
- [ ] #3 商店卖什么、价格变化、打折和删牌涨价都按原版。
- [ ] #4 金币、卡牌、药水和遗物的掉落、稀有度与领取顺序都按原版。
- [ ] #5 测试价格和概率的极端情况，不能重复领奖，操作失败时不能丢资源。
<!-- AC:END -->
