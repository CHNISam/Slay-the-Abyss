---
id: TASK-37
title: 防止中断触摸误出牌或领奖
status: Done
assignee:
  - '@dot'
created_date: '2026-10-23 10:40'
updated_date: '2026-10-23 11:40'
labels:
  - ui
  - combat
  - interaction
milestone: m-2
dependencies: []
references:
  - docs/design/CARD_DRAG_PLATFORM.md
  - 'https://github.com/CHNISam/Slay-the-Abyss/pull/103'
  - 'https://github.com/CHNISam/Slay-the-Abyss/pull/68#issuecomment-6363058359'
  - 'https://github.com/CHNISam/Slay-the-Abyss/pull/105'
priority: high
type: bug
ordinal: 48000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
已取消的卡牌按下手势会被其他触点按下或牌库关闭重新放行；晚到点击可确认新选中的卡牌，甚至执行换回合后同槽的另一 UID。本任务仅修离线输入所有权，不改数值或布局，不认领 TASK-30 的平台操作验收。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 缩放、牌库开关、回合或战斗变化后的旧卡牌 Up/Click 不选择或打出当前卡牌，其他触点不能复活它。
- [x] #2 新手势、普通点选、拖放、目标选择与从未收到指针事件的点击宿主保持可用，消费后的点击不得重放。
- [x] #3 新增回归先红后绿，现有相关套件通过；报告全量检查与平台未验证边界，不改变 TASK-30 负责人或平台 AC。
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. 复核最新任务与 PR，记录固定源码和红例。2. 为卡牌点击保留触点、run、battle、turn 和 UID 所有权，取消后不得由其他 Down 或牌库关闭复活。3. 覆盖消费重放、无事件降级和真实回合/牌库路径；跑相关与全量离线检查，交独立复审。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
离线候选已完成：控制器见过 Down 后，卡牌须持有自身有效的 touch/run/phase/battle/turn/UID 或奖励身份，Up 后的许可单次消费，缩放与失活取消后不由其他 Down 或牌库关闭复活。新增22组最终全过；回退原生产代码负控8过14败。原 BattleUI43、拖牌边界7、GameUI15、牌库6均过；Native Lua5.4全68文件通过。无坐标/无touchId完整点选与从未收到Down的点击宿主保留。仅离线代码，不代表平台事件派发、编译、导入、鼠标/手机验收；TASK-30未改。等待独立复审与最终SHA Quality，保持In Progress及AC未勾。

22组按原断言精确拆为11+11，共享测试setup，不提高15秒预算。部分源码快照首轮npm check额外发现缺基线审计脚本；只从固定67c839a补齐并核对Git blob后，最终645项605过40败，40失败逐一确认为缺Fengari。Python16通过；相关Native Lua成功不替代正式Fengari/当前SHA Quality，未安装依赖。

2026-10-23：PR105 已合入 develop c3c909db7a9b58150667ad8616d02c117be51a33。冻结9文件逐 Git blob 与合并树一致；PR head 5e5321159f330fb06dabdec1dd90447652c58e0b 的 Windows check 120376150896 及 presentation 均 success，合并后两项 Quality 亦 success。新增11+11回归和独立12+4+6组验证离线输入所有权与兼容；原生产代码负控8过14败。此前本地缺Fengari不再作为正式CI阻塞。分支已自动删除。仅完成离线输入切片，真实平台事件派发/官方导入/手机鼠标操作仍由TASK30承接，不改其归属及AC。
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
PR105 修复旧触点跨缩放、牌库、换回合/换局误出牌或领奖；保留新手势、拖放与无指针点击降级。22组先红后绿回归、独立复审及当前head/合并后Quality通过。平台实机未验。
<!-- SECTION:FINAL_SUMMARY:END -->
