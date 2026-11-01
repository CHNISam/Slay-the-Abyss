---
id: TASK-4.14
title: 校正顶栏卡组遗物图标计数与空间层级
status: In Progress
assignee:
  - Furinya
created_date: '2026-10-30 21:58'
updated_date: '2026-11-01 04:05'
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
type: bug
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Owner截图：卡组入口不是清楚的卡牌图标，两个类似箱子的遗物入口语义不明，顶栏右侧与计数相互挤压且残留一个「0」。同时关注不同图标表达完全不同语义的问题。圣遗物可核对原版顶栏下第二排布局，但不预设必须照某个像素实现。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 卡组、遗物及其数量一一对应，消除右侧残留「0」与任何遮挡。
- [ ] #2 图标能区分不同功能；遗物数量增多仍保持清晰，不挤压战斗核心信息。
- [ ] #3 对当前官方 UI 图标映射做必要核查，已发现的一图多义有明确判断，未证实的部分不冒充事实。
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
本轮仅修复最终gameLayout中消耗图标及计数被共享遗物入口覆盖：先跨父层几何红例，再只调整消耗组横坐标；保留胶囊/图标/数值与点击路径，实机未验不Done。

接续404楼层芯片与HP/金币配色；取消render-only滚动与跨run缓存，直接显示当前金币规则owner；真实Host验证增减/idle/重开，不改事件或玩法，不勾实机AC。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
本轮最终gameLayout跨父层红例确认：消耗图标370/计数394被共享遗物入口352覆盖。仅将消耗组移至424/448，位于遗物入口右缘388与卡组左缘472间；保留原图/数值/点击路径与胶囊造型。新增组合几何同时覆盖图标、计数、点击区对遗物盘/入口/卡组/菜单/五药水/标题无重叠。定向9项通过；仍未官方导入/设备复测，其余图标语义与药水重复不在本窄修内，AC未勾。

2026-10-31：在af178隔离树接续404@81882943；原render-only金币180时一次render显示中间值，真实Host先红确认。最小改为直接显示combat.player.gold（战斗实际值）或run.gold（非战斗），无动画cache；楼层芯片、标题拆分及HP/金币配色保留。新增增减180/7/406/0一次render准确、idle不误值、真实结束页重开不继承旧值及规则金币不变回归。主题/布局/HP/新Host共18/18通过，未改原断言/预算；原滚动提交仍保全，未实机不Done。

2026-10-31 PR收口：PR426（2da54ae1f6f970684455fab13b91d49fff30633b）提出战斗中空消耗堆也显示0，原PR明确DO NOT MERGE等待Pan。当前425有意仅在非空时显示，与弃牌堆独立；这不是已确认的玩法回归。此提案保留固定PR/提交历史并归本任务待Owner决定，不合入当前候选，不勾任何AC，也不声称手机验收通过。以后若批准恢复，须重验0/正数、非战斗隐藏、实际父层可见性与对应消耗堆点击，禁止改动弃牌堆语义。

2026-11-01 R2：抽牌弹层普通浏览移除常驻长排序说明，避免覆盖暗化手牌；保留控制器多页导航说明。现有共享顶栏消耗计数/药水/卡组/菜单碰撞回归通过，无口述猜坐标变更。
<!-- SECTION:NOTES:END -->
