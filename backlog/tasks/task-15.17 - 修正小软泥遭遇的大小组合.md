---
id: TASK-15.17
title: 修正小软泥遭遇的大小组合
status: Done
assignee:
  - '@Furinya'
created_date: '2026-10-24 09:42'
updated_date: '2026-10-27 15:04'
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
  - docs/reviews/TASK-15.17-small-slimes.md
parent_task_id: TASK-15
priority: medium
type: bug
ordinal: 85000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
正常第一层就可能遇到两只小软泥；原版这一遭遇应是一小一中、酸液与棘刺各一只。修正实际开战编组，不改敌人本身的数值，也不借此重做整个遭遇池。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 每次只生成原版允许的两种一小一中组合，敌人顺序正确，不再出现两只小软泥。
- [x] #2 相同开局和相同操作得到相同编组，随机选择只结算一次，不被进入房间的后续步骤覆盖。
- [x] #3 从正常地图和未知房进入战斗都正确；开战失败不会改变地图进度、楼层或随机状态。
- [x] #4 真实入口、两种组合、失败重试和既有遭遇回归通过独立审查与当前提交CI；完整遭遇分布和实机验证仍单独保留。
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
先用固定来源和正常seed1第一层入口证明旧两小组合错误，再在既有开战入口选择两种合法组合。统一地图进入与直接开战的随机状态提交，保留失败原子性；不修改medium_slimes、五小魔、地图遭遇分布或原作随机流整体对齐。与PR168最终合入代码接合，独立评审和当前CI通过后集成。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
两种一小一中组合、槽序和开战随机提交已交付。PR174以最终231dd0ff通过Quality40085439301后合入b757705e；合后Quality40086468750也通过。固定旧策略的真实败局及新seed7离线胜利均见专项报告；旧实机证据不用于认证此组合。

负责人字段规范化：原记录 @dot 作为历史执行者信息保留；任务负责人为 Furinya。
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
PR174已合入develop b757705e，最终提交与合后Quality均成功，功能分支已自动清理。独立核对11拥有文件与冻结源码一致，并保留并行合入的173/175/172成果。真实入口、失败重试、36项独立预期和其他17遭遇回归通过；本片组合为160份native Lua、1008所选Node、17Python。完整遭遇分布、原PC随机流和新组合官方导入/实机仍未验证。
<!-- SECTION:FINAL_SUMMARY:END -->
