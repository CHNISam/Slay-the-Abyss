---
id: TASK-69
title: 交付原创四角色并合入远端
status: In Progress
assignee:
  - Furinya
created_date: '2026-10-26 09:42'
updated_date: '2026-10-26 09:47'
due_date: '2026-10-28'
labels: []
milestone: m-4
dependencies: []
ordinal: 116000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
交付附件V4的四位原创角色，每人完整75张牌，接入既有正常游戏流程并合入远端develop。技术与证据见 docs/backlog-details/task-69.md。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 四位角色完整卡池、正常获取升级商店、战斗跨节点与结算接入生产
- [ ] #2 当前候选完整Quality成功且合入远端develop
- [x] #3 同候选实机缺失及受影响范围如实记录，不冒充游戏验收
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
以最新develop合成完整实现，保留官方Quality；核对冻结数值、生产回归和候选身份，按当前SHA全绿合并。实机缺失单独保留。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
PR219基于最新develop4c75a31。独立复算212生产输入、119模块和2UI摘要一致；四角真实UI出牌4/4、显示16组640牌面、观者28组通过。新增选角后旧平台启动回归补选旅行者，保留剧情地图及监听器断言。完整Quality和合并仍待当前head，PC/手机/GIL及12流派实机not_run。按远端PR216最新AGENTS停用额外claim要求，旧认领已释放；不放宽Quality。
<!-- SECTION:NOTES:END -->
