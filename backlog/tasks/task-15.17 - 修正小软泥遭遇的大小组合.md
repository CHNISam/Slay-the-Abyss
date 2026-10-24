---
id: TASK-15.17
title: 修正小软泥遭遇的大小组合
status: In Progress
assignee:
  - '@dot'
created_date: '2026-10-24 09:42'
due_date: '2026-10-28'
labels:
  - required
milestone: m-4
dependencies:
  - TASK-14
references:
  - docs/backlog-details/TASK-15.md
  - >-
    https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/helpers/MonsterHelper.java
parent_task_id: TASK-15
priority: high
type: bug
ordinal: 85000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
正常第一层就可能遇到两只小软泥；原版这一遭遇应是一小一中、酸液与棘刺各一只。修正实际开战编组，不改敌人本身的数值，也不借此重做整个遭遇池。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 每次只生成原版允许的两种一小一中组合，敌人顺序正确，不再出现两只小软泥。
- [ ] #2 相同开局和相同操作得到相同编组，随机选择只结算一次，不被进入房间的后续步骤覆盖。
- [ ] #3 从正常地图和未知房进入战斗都正确；开战失败不会改变地图进度、楼层或随机状态。
- [ ] #4 真实入口、两种组合、失败重试和既有遭遇回归通过独立审查与当前提交CI；完整遭遇分布和实机验证仍单独保留。
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
先用固定来源和正常seed1第一层入口证明旧两小组合错误，再在既有开战入口选择两种合法组合。统一地图进入与直接开战的随机状态提交，保留失败原子性；不修改medium_slimes、五小魔、地图遭遇分布或原作随机流整体对齐。与PR168最终合入代码接合，独立评审和当前CI通过后集成。
<!-- SECTION:PLAN:END -->
