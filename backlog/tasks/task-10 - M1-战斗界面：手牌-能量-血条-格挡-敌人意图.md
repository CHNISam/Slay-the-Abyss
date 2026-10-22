---
id: TASK-10
title: M1 战斗界面：手牌/能量/血条/格挡/敌人意图
status: In Progress
assignee: []
created_date: '2026-10-22 13:47'
updated_date: '2026-10-22 16:05'
due_date: '2026-10-24'
labels: []
milestone: m-2
dependencies:
  - TASK-8
ordinal: 10000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
用客户端 Lua 或节点图实现战斗界面，保证信息可读。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 手牌可见可选，出牌后即时刷新
- [ ] #2 能量、血量、格挡、敌人意图显示正确
- [ ] #3 手机画布下 UI 不出屏
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. 复用已审查Combat/Run，以事件驱动Lua界面显示手牌、能量、血量、格挡、状态和真实意图。2. 用旅行者中文表现资源生成Lua显示表，布局限制在手机画布内；点击目标/卡牌/结束回合后即时刷新。3. 自动化检验布局与实际规则适配，独立审查；MCP保持live0向存档副本导入，预览手机/主机并在游戏中操作取证。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
CLAIM /root，feat/task-10-battle-ui/.worktrees/battle-ui；边界新UI脚本、布局、UI构建工具及对应测试。独占MCP/GUI主Agent持有。正式存档杀戮深渊已只读确认22101字节；Lv2用户确认，文字显示待实测。

实现真实Run/Combat驱动点击界面，56JS+52Lua（3UI+15core+8run+26status）及Python10pass1envskip通过，所有控件在1280x720内。八模块已写入工作区副本，scene_check_client errors0/warnings0。首轮真机在导入前前台切换失败，无截图日志；不计实机通过。独立审查与多设备预览进行中。
<!-- SECTION:NOTES:END -->
