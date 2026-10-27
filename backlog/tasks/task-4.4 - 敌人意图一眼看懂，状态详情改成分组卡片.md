---
id: TASK-4.4
title: 敌人意图一眼看懂，状态详情改成分组卡片
status: In Progress
assignee:
  - '@Furinya'
created_date: '2026-10-24 10:34'
updated_date: '2026-10-27 15:03'
due_date: '2026-10-26'
labels:
  - awaiting-live
milestone: m-5
dependencies: []
references:
  - docs/BACKLOG-AUDIT-20261026.md
parent_task_id: TASK-4
priority: medium
type: feature
ordinal: 85000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
敌人头顶意图除攻击数字外不写字，非攻击意图只靠图标；点开角色或状态后的详情面板是居中堆叠的一坨文字，超过 5 项状态时其余看不到。只改表现与交互，不改战斗规则、数值和敌人行动逻辑。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 敌人头顶：攻击显示含修正的伤害（多段写 9×2），其余意图在图标旁写两字类型名并用意图颜色，复合意图保留角标
- [x] #2 意图详情按动作逐行列出名称、关键数值、效果与持续，并标明尚未执行
- [x] #3 状态详情按 单位 → 生命/格挡 → 增益/减益分组 → 名称层数与持续 → 效果 → 条件 排列
- [x] #4 状态多于一页时点按面板翻页，所有状态都能看到；点空白处关闭且不会误出牌
- [ ] #5 原神千星奇域实机截图确认意图与详情面板显示完整、布局正确
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
修正用户截图指出的虚弱上箭头语义：虚弱/缠绕改用主题既有削弱图标，排查其他状态映射并运行主题/布局与战斗UI回归。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
改动（只动表现与交互，不改规则/数值/AI）：
- 头顶意图（src/lua/abyss_battle_ui.lua intentView、scripts/ui-layout.mjs unit()）：图标右侧左对齐；攻击写含修正伤害（9×2），非攻击新增 intentLabel 写两字类型名（防御/强化/削弱/蓄能/沉睡/苏醒/分裂/逃跑），颜色同图标；复合角标保留；仍不写层数。
- 详情卡（renderInfo/describeInfo/paginate；ui_theme statusInfo 新 token）：宽400左对齐，顶部色条（状态金/意图按类型色），标题+右侧标签（当前状态/下一步行动/关键词），生命/格挡带图标，增益→减益分组，每项 名称层数+右侧持续 / 效果 / 条件；意图卡逐动作列出数值、总伤、基础值与将施加状态的效果并标「尚未执行」；超过一页点按卡片翻页（续页标「（续）」），点空白关闭；悬停为透传临时提示不挡出牌。
- statusDetail 拆成 效果/持续/条件 三段，文案沿用既有白话并按 data/statuses.json 补条件。
对照：docs/design/UI_DESIGN.md 意图与提示框、prototype 配色；偏离（宽240→400、左对齐分组）已记入 docs/design/PLATFORM_PARITY.md。
验证层级：AC1–4 为本地实现+离线预览通过——Lua/JS 测试已更新（分页覆盖全部状态、标签、意图行、行高、对齐）；离线预览 scripts/battle-ui-preview.mjs，截图 docs/evidence/battle-intent-status-ui/（字形代替图库图、系统字体）。未构建候选 .gil、未导入、未实机、未跑 verify:ui，AC5 未勾选。
待接手：1) 构建候选并实机截图核对：叠放的 40 高文本框（行距 20–24）显示、left/right 对齐、翻页 cursorArea 只吃面板内点按；2) 手机长按后转常驻、点卡片翻页手感；3) 意图/状态图库图标仍标 verify。

2026-10-24：虚弱/缠绕103053改为102045；其余共用图形及新实机核对边界见docs/design/BATTLE_IMPLEMENTATION.md。根工作树验证13项主题/布局与53项战斗UI通过；未构建gil/导入/实机，AC5保持待验。

2026-10-24 用户截图反馈修正：虚弱/缠绕由含上箭头剑的103053改为主题既有削弱102045，血条与详情共享映射；其他共用图标和待实机核对限制记入docs/design/BATTLE_IMPLEMENTATION.md。build:theme及13项主题/布局测试通过；未构建gil、未导入或实机，不勾选AC5。

负责人字段规范化：原记录 @Claude 作为历史执行者信息保留；任务负责人为 Furinya。
<!-- SECTION:NOTES:END -->
