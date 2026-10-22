---
id: TASK-10
title: M1 战斗界面：手牌/能量/血条/格挡/敌人意图
status: In Progress
assignee:
  - '@Codex'
created_date: '2026-10-22 13:47'
updated_date: '2026-10-22 16:55'
due_date: '2026-10-24'
labels: []
milestone: m-2
dependencies:
  - TASK-8
references:
  - 'https://github.com/CHNISam/Slay-the-Abyss/pull/29'
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
1. 接续已有原生战斗界面与旅行者显示构建，连接真实Run/Combat。2. 核验点击刷新、状态与修改后的敌人意图，补回归并接入统一构建门禁。3. 记录布局自动验证和未完成的平台多设备/存档/实机验证，不越级勾选。

4. 合入最新已批准主题与规范，统一stage等比缩放及全画布底色；主题读取与过渡布局缺口单独记录。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
2026-10-23 接续执行/root；干净集成分支feat/backlog-sprint，worktree .worktrees/runtime-integration，保留旧battle-ui工作树未提交文件；各subagent负责独立模块。

2026-10-23 本地原生控制器已集成菜单/地图/战斗/奖励；真实手牌点击、能量/血量/格挡/状态与当前修正意图刷新均通过测试。独立审查修复奖励页漏显示战后回血；隐藏面板拒绝事件。初始卡组真实战斗+15层全部7类节点低HP测试流程通过。仍非平台屏幕证据，保留全部屏幕/手机验收项未勾；按最新批准主题接线，卡面/扇形手牌/图标/动画还原有缺口。

最终本地npm run check退出0：JS/数据/主题/全部108组Lua通过；Python11项中10通过1因Windows符号链接权限skip，JS同类6项明确skip。主题生成与native*过渡布局读取、手机/电脑/主机/宽屏stage缩放、重复OnStart不累加监听器已验证；当前未原生平台导入/实机/正式结算。独立规则与组合审查通过，代码交付feat/backlog-sprint。

继续TASK14后的最终门禁更新：99JS（93通过6权限skip）、120Lua通过、Python10通过1权限skip；药水入口已与同源规则和战后奖励闭环联动。
<!-- SECTION:NOTES:END -->
