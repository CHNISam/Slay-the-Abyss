---
id: TASK-4.16
title: 改善右上角菜单与操作说明的交互和信息层级
status: In Progress
assignee:
  - '@Furinya'
created_date: '2026-10-30 21:58'
updated_date: '2026-11-02 02:20'
labels:
  - playtest-20261030
  - p1
  - grok
milestone: m-5
dependencies: []
references:
  - docs/backlog-details/PLAYTEST-20261030.md
  - docs/backlog-details/MOBILE-QA-20261029.md
  - docs/backlog-details/TASK-4.16-map-menu-return-20261101.md
  - backlog/tasks/task-95 - 对照验证美术、交互与动效设计工具.md
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
- [x] #4 QA-R2-06本地真实Host回归：地图模式隐藏并拒绝查看同一地图；战斗或节点的只读路线预览一次返回即恢复原页面，无残留菜单，旧触点与手柄取消不穿透。
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. 基于PR432核实现有菜单退出与触控源码和回归。2. 复用inspectText为战斗及地图顶栏生命金币加入只读提示与外点关闭，保持modal及旧tap隔离。3. 定向宿主与布局验证，逐项记录已修和设备缺口后交独立复审。

2026-11-01 QA-R2-06：1. 用真实GameUI回归复现地图菜单重复入口和两层返回。2. 地图模式隐藏且拒绝查看同一地图；其他上下文的只读地图返回一次即关闭整层菜单，保留触点代际隔离与节点只读。3. 定向菜单、路线返回、奖励和手柄回归；本地证据记录到附件，手机实测AC保持未勾。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
2026-10-31：PR396@f5af0664已编码菜单外点吞输入关闭、启程前隐藏地图与三栏操作说明；含手柄回声和结算忙态保护。生命金币仅说明页有解释，未新增点击HUD提示；同候选设备未验，不勾验收。

2026-10-31按Owner最新指定，仅把结束回合说明改为“点击右下角「结束回合」”、商店说明改为“先点商品查看详情，再确认购买”；6e5c9a0f已被集成4c262462，两串已在新GIL字节读回，布局与其它文案不变。原作者18项及PC/移动Simulator证据复用，组合相关17项通过；仍待同候选官方手机验收，不勾AC。

本轮补齐地图与战斗顶栏生命金币点击提示，复用inspectText。专项两项（含手柄、旧tap、外点、只读）通过。既有菜单退出弃牌选角源码逐项证据见 docs/backlog-details/PLAYTEST-20261030-MENU-SOURCE-AUDIT.md；保留设备未验及意图历史断言失败，不勾AC。

2026-11-01 QA-R2-06：地图模式的菜单入口与命令共用准入并隐藏重复地图；预览返回走既有完整菜单关闭路径，保持exitGeneration递增。真实Host新回归覆盖地图旧room tap、战斗/节点只读及单步返回、旧menu tap、手柄Cancel；专项与相邻菜单回归已通过，详见新附件。原AC1-3和TASK-38设备验收未勾，未做官方导入或手机操作。

2026-11-02最新排期：优先M4非美术、非交互设计工程。新增操作说明信息架构与整体交互方案先取TASK-95对应实验结论；关闭菜单、误导入口、返回层级与触点穿透等已有明确缺陷及QA-R2-06回归继续，不因实验回退或延迟已批准修复。 仅对应新增正式设计切片以实验结论为前置；未来纯设计优化子任务显式依赖TASK-95并引用适用Go结论。本混合任务不新增整任务硬依赖，原状态与AC保留。
<!-- SECTION:NOTES:END -->
