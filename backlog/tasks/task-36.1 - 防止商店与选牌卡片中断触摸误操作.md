---
id: TASK-36.1
title: 防止商店与选牌卡片中断触摸误操作
status: In Progress
assignee:
  - '@dot'
created_date: '2026-10-23 14:26'
updated_date: '2026-10-24 02:01'
due_date: '2026-10-28'
labels: []
milestone: m-5
dependencies: []
references:
  - 'https://github.com/CHNISam/Slay-the-Abyss/pull/103'
parent_task_id: TASK-36
priority: high
type: bug
ordinal: 48000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
节点按钮已有手势归属保护，但商店和选牌卡片未接入。真实控件回调复现：按住卡片后翻页、开关牌库或重绘，再释放点击会购买当前卡片。仅补齐卡片动作归属，不改数值、分页和退出流程。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 翻页、牌库遮挡、重绘及跨局后旧卡片手势不购买或选择当前对象，金币卡组保持不变。
- [ ] #2 新的有意触摸和仅点击兼容路径保持正常，选牌与宝箱相关回调不回退。
- [ ] #3 提供真实控件先红后绿回归、独立评审和当前提交 CI；实机事件顺序未验单独保留。
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. 固定最新 develop 复现卡片触摸负例。2. 复用节点已有动作令牌保护卡片命中区域。3. 核查分页与退出并行 PR 组合，独立回归后提交 PR。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
已复现6组旧触摸错误：商店翻页、牌库开关、重绘，选牌翻页、牌库开关，以及离店后真实失败重开至下一商店。固定源7f124453负控0/6，候选6/6及全部81个Native Lua套件通过；PR114分页组合亦81通过。夹具显式以10000金币和敌人1HP隔离资金/战斗，重开另以玩家1HP加速实际失败，不宣称自然获取或玩法平衡。仅shop/picker卡片复用现有动作令牌，不改宝箱、GameUI退出、数值和分页。独立评审进行中；未执行Fengari本地全检或平台验收。

M1集成独立探针实际复现257ba09旧商店触点跨退出取消误购；复用本PR118修复组合到b76b6cc后，exit15/nodeGesture20/ownership6/独立5共46项通过，旧卡牌/遗物/选牌手势失效且新手势正常，原page保留。红绿报告.artifacts/m1-audit/exit-swipe/。保持In Progress等待当前最终head Quality，不冒充平台派发已验。
<!-- SECTION:NOTES:END -->
