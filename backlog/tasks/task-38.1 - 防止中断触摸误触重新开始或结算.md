---
id: TASK-38.1
title: 防止中断触摸误触重新开始或结算
status: In Progress
assignee:
  - '@dot'
created_date: '2026-10-23 15:55'
updated_date: '2026-10-23 15:57'
labels: []
dependencies: []
references:
  - src/lua/abyss_game_ui.lua
parent_task_id: TASK-38
priority: high
type: bug
ordinal: 50000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
菜单与结算界面的开始、提交按钮直接执行Click，退出弹窗取消后旧触摸仍可重新开局或提交结算。仅保护这些宿主动作的触摸归属，不修改结算规则、按钮外观或平台验收。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 遮挡、退出取消、模式或本局切换、缩放后旧触摸不能重新开局或提交当前结算。
- [ ] #2 外来触点和重复回放不能执行动作；新有意触摸与仅Click宿主保持可用。
- [ ] #3 增加先红后绿真实控件回归并独立复审，保留结算单次请求规则；当前头CI与平台实测分开报告。
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. 固定95ce2bd复现开始和结算控件过期触摸。2. 最小绑定触点与当前本局/模式及界面代际。3. 回归结算和退出主流程，独立评审后提交正常PR。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
固定95ce2bd候选新增20组菜单/结果控件回归：基线19失败1通过，修复20/20；全量91个Native Lua套件通过。仅复用退出控件既有指针归属机制并加入菜单/本局代际，三个旧测试的重开准备改为完整Down-Up-Click而原有卡片/药水/结束回合断言不变。多数结果状态为显式隔离夹具直接设置phase，不冒充自然游戏流程；独立评审另核查公开动作到达失败结果的实际路径。未运行本地npm全检/安装或平台验收。
<!-- SECTION:NOTES:END -->
