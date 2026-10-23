---
id: TASK-13
title: M2 7 类节点：战斗/精英/营地/商店/事件/宝箱/Boss
status: In Progress
assignee: []
created_date: '2026-10-22 13:47'
updated_date: '2026-10-23 01:52'
due_date: '2026-10-26'
labels: []
milestone: m-3
dependencies:
  - TASK-12
ordinal: 13000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
七类节点各自流程：营地回血或升级卡牌，商店购买与删除卡牌，事件与宝箱产出真正生效。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 7 类节点均可进入并各有独立流程
- [ ] #2 营地可回血或升级卡牌
- [ ] #3 商店可购买卡牌/遗物并删除卡牌
- [ ] #4 宝箱与未知事件产出真正生效
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Codex node_flows 执行离线节点流程：审查并复用前轮未提交节点代码，隔离分支实现。2. 验证七类进入、营地、商店、宝箱、事件及奖励锁定的 Lua 回归与全量门禁。3. 记录接口、测试证据和未实机范围，AC 保留待平台验证。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
2026-10-23：Codex node_flows 领取离线执行；TASK-12 地图纯 Lua 已合入，平台验收仍待实机。本轮不打开原神、不调用 live MCP，保留原负责人。
<!-- SECTION:NOTES:END -->
