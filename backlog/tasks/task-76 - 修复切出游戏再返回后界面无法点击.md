---
id: TASK-76
title: 排查手机战斗和奖励页面输入阻塞
status: In Progress
assignee:
  - Furinya
created_date: '2026-10-28 09:38'
updated_date: '2026-10-29 00:13'
labels: []
milestone: m-4
dependencies: []
references:
  - docs/backlog-details/TASK-76.md
  - 'https://github.com/CHNISam/Slay-the-Abyss/pull/304'
  - docs/backlog-details/MOBILE-QA-20261028.md
priority: high
type: bug
ordinal: 121000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
问题由手机实玩发现：拖牌后奖励或动作可能不能点击，关卡组后也曾无法操作。离线诊断复现混合Click抑制；卡组关闭后原生输入锁根因未确认。PC是否受影响待分别验证。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 根因定位并最小修复
- [ ] #2 跨界面切回正常交互且不误触
- [ ] #3 回归通过并经PR合入develop
- [ ] #4 真实拖牌后奖励、结束回合及纯点击入口继续可用，无需退出确认恢复。
- [ ] #5 卡组关闭后战斗、奖励和地图首个合法操作正常，手机留证。
- [ ] #6 分别记录手机触屏和PC鼠标的复现或未复现条件；不能以离线模拟代替真实设备。
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

2026-10-28队列复核（基线77c2d5e6）：中断按压修复已进入集成源码，但跨界面故障与同候选平台实测尚无完整验收；继续High/In Progress，原0/3验收保留。作为前两幕输入阻塞关联M4并列入排期，负责人统一Furinya，不把本地红绿或实验模块包当作用户故障已彻底解决。

2026-10-29 完整输入合同承接附件§2：真实拖牌及拖杀转奖励后，完整指针、混合Click动作和纯Click三种能力都能结束回合、领奖及跳过；迟到Click抑制只绑定原手势/有限消费，不泄漏后续动作，也不允许旧事件再次出牌。卡组关闭后战斗/奖励/地图首个合法操作可用，关闭不穿透、旧触点不复活；原生遮挡锁仍须真实命中控件与事件序列。奖励入口复现不能冒认录音Skip已复现；不每帧清标志或全局重建掩盖未知根因。
<!-- SECTION:NOTES:END -->
