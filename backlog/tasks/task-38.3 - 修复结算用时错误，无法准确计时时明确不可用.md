---
id: TASK-38.3
title: 修复结算用时错误，无法准确计时时明确不可用
status: To Do
assignee:
  - '@Furinya'
created_date: '2026-11-01 02:05'
labels:
  - release-qa-20261101
  - release-blocker
milestone: m-5
dependencies: []
references:
  - docs/backlog-details/MOBILE-RELEASE-QA-20261101.md
  - src/lua/abyss_game_ui_menu_view.lua
parent_task_id: TASK-38
priority: high
type: bug
ordinal: 135000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
2026-11-01移动端上线前验收：IMG_1255.png的失败结算页“用时”显示3074457345。用户明确要求上线前紧急处理；暂时无法保证准确时可隐藏该项或显示N/A、暂不可用，不能向玩家显示错误时间。截图候选版本尚未关联，不据此猜测计时根因。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 可靠计时时显示正确且可读的本局用时；不可用、非法或无法保证准确时隐藏该项或显示N/A／暂不可用，不展示3074457345等异常数值，也不用伪造0时长冒充真实数据。
- [ ] #2 沿实际共用用时路径定向复验失败、胜利、退出结算和重新启程；旧局时间不污染新局，降级显示不阻断重新启程或结束并结算。
- [ ] #3 保留异常计时输入与正常计时的回归，并在同一候选实体手机结算页取证；记录源码、候选和设备，未实测不得勾手机验收。
<!-- AC:END -->
