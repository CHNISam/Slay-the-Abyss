---
id: TASK-4.16
title: 改善右上角菜单与操作说明的交互和信息层级
status: In Progress
assignee:
  - '@Furinya'
created_date: '2026-10-30 21:58'
updated_date: '2026-10-31 15:40'
labels:
  - playtest-20261030
  - p1
  - grok
milestone: m-5
dependencies: []
references:
  - docs/backlog-details/PLAYTEST-20261030.md
  - docs/backlog-details/MOBILE-QA-20261029.md
parent_task_id: TASK-4
priority: medium
type: enhancement
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Owner反馈：菜单只能点「继续游戏」关闭；未启程时仍显示不可进入的「查看地图（启程后可用）」；操作说明六宫格信息堆砌，新手看不懂；血量、金币等资源标识缺少快速解释。应整体梳理信息架构和触屏交互，不强行指定控件结构。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 菜单可通过非破坏性的直观操作关闭，不误触后台游戏/放弃本局。
- [ ] #2 未启程地图入口不误导玩家；已可用时正常进入。
- [ ] #3 操作说明层次清楚、能快速找到出牌/取消/详情/药水/地图等信息；基础资源含义易获知。
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. 基于PR432核实现有菜单退出与触控源码和回归。2. 复用inspectText为战斗及地图顶栏生命金币加入只读提示与外点关闭，保持modal及旧tap隔离。3. 定向宿主与布局验证，逐项记录已修和设备缺口后交独立复审。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
2026-10-31：PR396@f5af0664已编码菜单外点吞输入关闭、启程前隐藏地图与三栏操作说明；含手柄回声和结算忙态保护。生命金币仅说明页有解释，未新增点击HUD提示；同候选设备未验，不勾验收。

2026-10-31按Owner最新指定，仅把结束回合说明改为“点击右下角「结束回合」”、商店说明改为“先点商品查看详情，再确认购买”；6e5c9a0f已被集成4c262462，两串已在新GIL字节读回，布局与其它文案不变。原作者18项及PC/移动Simulator证据复用，组合相关17项通过；仍待同候选官方手机验收，不勾AC。

本轮补齐地图与战斗顶栏生命金币点击提示，复用inspectText。专项两项（含手柄、旧tap、外点、只读）通过。既有菜单退出弃牌选角源码逐项证据见 docs/backlog-details/PLAYTEST-20261030-MENU-SOURCE-AUDIT.md；保留设备未验及意图历史断言失败，不勾AC。
<!-- SECTION:NOTES:END -->
