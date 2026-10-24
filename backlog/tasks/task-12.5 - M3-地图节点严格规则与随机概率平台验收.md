---
id: TASK-12.5
title: M3 地图节点严格规则与随机概率平台验收
status: To Do
assignee: []
created_date: '2026-10-24 02:01'
due_date: '2026-10-28'
labels: []
milestone: m-4
dependencies:
  - TASK-12.3
  - TASK-12.4
  - TASK-13.1
parent_task_id: TASK-12
priority: high
type: task
ordinal: 78000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
从TASK-12.3分离严格地图、节点经济与随机概率验收；基本七节点可玩不再等待整份审计。复用12.4/13.1既有账本，不重复实现。共同约束：初代《杀戮尖塔》PC A0的规则、数值、概率、AI和结算顺序保持原版；不通过调值或低HP夹具制造通过。编译、写副本、官方导入和实机分别报告，保留SHA/hash、种子、截图和本轮日志。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 对照TASK-12.4/13.1已核实预期，核验地图拓扑、强制节点、遭遇分布、价格范围、奖励和动态概率计数的固定输入与边界；统计有样本和阈值依据。
- [ ] #2 同候选实机交易、节点产出及资源账本符合对照；覆盖重复领取/非法推进/失败原子性，随机种子与调用顺序可追溯，不用一次出现证明概率正确。
- [ ] #3 PASS、差异、待核实、平台限制分列；未修复的原版实质差异继续阻塞相关严格验收，不能因M2可通关自动通过。
<!-- AC:END -->
