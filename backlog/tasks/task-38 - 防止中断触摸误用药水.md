---
id: TASK-38
title: 防止中断触摸误用药水
status: Done
assignee:
  - '@dot'
created_date: '2026-10-23 12:23'
updated_date: '2026-10-23 14:12'
labels: []
milestone: m-2
dependencies: []
references:
  - 'https://github.com/CHNISam/Slay-the-Abyss/pull/105'
  - docs/design/CARD_DRAG_PLATFORM.md
  - 'https://github.com/CHNISam/Slay-the-Abyss/pull/110'
priority: high
type: bug
ordinal: 50000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
药水按钮只校验当前槽位，不记录按下时的操作归属。旧触点经过牌库开关、出牌演出或换回合后松开，仍会消耗当前药水。仅修离线输入所有权，不改变药水数值、库存规则或原平台验收。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 牌库、演出、回合或战斗变化取消旧药水手势，其他触点不能复活旧输入或误用后来绑定的药水。
- [x] #2 新药水手势、稀疏槽位、目标选择、无指针点击宿主及现有卡牌操作保持可用。
- [x] #3 真实配对触点回归先红后绿，独立评审与最终SHA Quality通过；平台派发未验明确记录。
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. 固定a6d6718基线复现旧Down经过真实宿主状态变化后误用药水。2. 为药水按钮绑定按下时触点与运行上下文，取消或消费后不重放。3. 覆盖正常降级和卡牌兼容，独立复审、当前SHA CI后集成。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
基线配对触点审计6过7败；药水旧Down经过牌库开关、演出或换回合后仍消耗当前瓶。候选为药水独立保存touch/run/battle/turn/slot/id与库存表身份，取消及单次消费不复活；卡牌tokens不改，保留卡牌有指针而药水只Click的混合宿主。最终新增11+9+9组全过，精确最终测试回退原生产代码10过19败；独立27组基线8过、候选27全过。Native Lua75脚本、Python16过。局部快照遗漏输入用精确基线blob补齐；本地npm check轮询被权限审查拒绝，未重试或安装，不能声称本地全量PASS。实际平台事件派发/导入/试玩未验；待最终SHA Quality。

2026-10-23独立验收：固定15f62a6的62项回归通过，5项独立探针回退原生产blob全失败、恢复全通过；PR110最终head8a217974 Quality39954377275两作业SUCCESS，合入78cedba。根GUI为避免TASK38手机任务冲突将本项重编号为TASK41；本分支暂保留原编号直至GUI同步PR114集成，不新建重复项。平台实际派发和手机未验。
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
离线药水手势修复、红绿复证及独立62项回归完成，PR110最终SHA Quality全绿并合入develop。平台实机不计入本离线完成。
<!-- SECTION:FINAL_SUMMARY:END -->
