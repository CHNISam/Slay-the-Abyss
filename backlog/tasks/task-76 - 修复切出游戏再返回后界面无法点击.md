---
id: TASK-76
title: 修复切出游戏再返回后界面无法点击
status: In Progress
assignee:
  - codex
created_date: '2026-10-28 09:38'
updated_date: '2026-10-28 09:56'
labels: []
dependencies: []
references:
  - docs/backlog-details/TASK-76.md
priority: high
type: bug
ordinal: 121000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
战后选牌切出窗口再返回偶发无法点击，Esc后继续可恢复。排查共享输入根因。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 根因定位并最小修复
- [ ] #2 跨界面切回正常交互且不误触
- [ ] #3 回归通过并经PR合入develop
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
追踪平台焦点与手势；最小实验验证；修复与回归；实机与PR集成。

新增丢失释放后再次点卡的真实处理器回归，并核对同指针恢复、多指归属与迟到事件不误出牌。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
本轮隔离工作树 .worktrees/ui-focus-return，基线 origin/develop d2e0baa3。已读入口 abyss_ui、共享 GameUI、Controller、BattleUI、ChoiceUI、NodeUI 及平台官方客户端 API。入口仅启动/逐帧更新；官方生命周期未列窗口焦点回调，不能直接套用 Unity OnApplicationFocus。UI 根 showCursor/blockKeys/blockCursor 恒为 true。战斗 down 在 self.gesture 存在时不清 suppressClick；dragLayer 在 moving gesture 存在时启用 hit 并拦截穿透。因此丢失 Up/EndDrag 后残留手势/遮挡为待验证假设，尚无本轮实机证据，不能定为实际根因。选牌、地图、节点、菜单已有不同的手势所有权防护，不能粗暴清空所有输入或刷新整界面。已请求本轮10分钟键鼠窗口，未获确认，未发送输入。尚未修改生产代码、运行修复回归或创建PR。

用户补充：不切出也会突然无法选牌，点击退出本局等按钮后恢复；不再以窗口失焦为必要触发条件。继续离线排查丢失释放事件后 self.gesture 永久拒绝新 Down 的路径。

已用真实UI处理器红绿复现缺失Up导致卡牌永久锁定；最小修复18行及针对性回归已实现。候选只替换PR290底图的BattleUI模块，实机待用户自行验证。详细边界、测试与失败记录见附件。
<!-- SECTION:NOTES:END -->
