---
id: TASK-40
title: 以后再做手柄支持
status: To Do
assignee:
  - '@Furinya'
created_date: '2026-10-23 12:24'
updated_date: '2026-10-28 14:46'
labels: []
dependencies: []
references:
  - TASK-4
  - docs/design/UI_DESIGN.md
  - docs/backlog-details/TASK-40.md
priority: low
type: feature
ordinal: 41000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
目前没有手柄可测，先保留这个任务。等找到设备或测试人员，再确认平台能力并安排，不挡手机和电脑首发。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 确认平台支持哪些手柄操作，约定按键、焦点切换和提示。
- [ ] #2 手柄能完成出牌、选目标、确认取消、结束回合、地图和各类房间，不会卡住焦点。
- [ ] #3 用真实手柄完整玩过；没有设备时明确写未验证，不能说已经支持。
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
2026-10-27：将现有PR229手柄离线实现按真实共同祖先对照当前M3与卡牌输入源码逐项迁移；保留当前启动、卡牌UID/目标所有权和地图无绑定模式，再接入章节安全补丁。静态、布局与相关Lua通过后，原样运行26项第四阶段呈现测试和30秒预算；真实手柄与平台实测仍未验证，不修改验收项或任务状态。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
2026-10-27：现有PR229手柄实现已在独立副本按当前M3、卡牌输入与章节地图安全源码逐项整合；初轮28个离线阶段通过，原始21项呈现文件保持原断言与30秒预算，替身导航方法改为共享原型后28.004秒通过。来源与本轮边界补入docs/backlog-details/TASK-40.md。没有改任务状态、优先级、负责人或验收项；真实手柄、官方导入和实机UI仍未验证，远端新HEAD完整Quality尚未运行。

2026-10-27队列复核：补齐有效负责人Furinya；Low候选仍不占当前冲刺，不因指定负责人自动启动新功能。

工程健康清理保留 fix/pr260-room-fixtures（646d7e13）独立商品手柄Focus只读说明及6组Host回归，尚未吸收；原.worktrees/pr260-room-fixtures与已verify恢复bundle完整保留。该成果为未来手柄候选，先核对当前inspectable/purchasable再择取，不覆盖当前主线。
<!-- SECTION:NOTES:END -->
