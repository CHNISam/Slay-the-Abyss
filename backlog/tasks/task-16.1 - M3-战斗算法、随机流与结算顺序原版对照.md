---
id: TASK-16.1
title: 把伤害、抽牌和结算顺序算对
status: In Progress
assignee:
  - '@Codex'
created_date: '2026-10-23 01:57'
updated_date: '2026-10-24 21:13'
due_date: '2026-10-28'
labels:
  - required
  - rule-parity
milestone: m-4
dependencies:
  - TASK-8
  - TASK-11
references:
  - src/lua/abyss_combat.lua
  - data/SOURCES.md
  - docs/backlog-details/TASK-16.1.md
parent_task_id: TASK-16
priority: high
type: enhancement
ordinal: 43000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
核对所有卡牌和敌人共用的基础规则，避免同一种效果在不同地方算出不同结果。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 每条计算规则有原版依据，未知和差异明确记录。
- [ ] #2 伤害、格挡、状态加减、多段、反伤、中毒和死亡处理的数值与先后顺序正确。
- [ ] #3 抽牌、洗牌、弃牌、消耗、满手、费用支付和随机选择符合原版。
- [ ] #4 用原版预期结果检查特殊情况；卡牌、敌人和道具用同一套正确规则。
- [ ] #5 保存测试与实际游戏记录，明确各部分验证到了哪一步。
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
2026-10-25承接完整75卡：共用动作队列支持真实选牌暂停/恢复、消耗钩子TOP/BOTTOM顺序、费用与抽牌触发；优先验证Burning Pact/Fiend Fire/Corruption/Dark Embrace/FNP/True Grit/Second Wind/Exhume联动和死亡中断，再补X费用、复制、持续能力及既有30卡回归。

承接develop9ae1aec的正式房间洗牌片：CardGroup/DrawCardAction尾端抽牌与空/单牌shuffle消费randomLong后播种Java48/Collections，按层独立；保留原独立向量与失败回滚，和75卡动作/触发系统共同回归。来源与legacy入口边界见docs/reviews/TASK-16.1-room-shuffle.md，整体AC不勾。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
2026-10-25随TASK-16完整75张候选推进：共享牌动作队列与独立牌队列、UID选牌、完整消耗/抽牌触发、房间shuffleRng和cardRandomRng、run.cardRng+稀有度偏移已接入并有专项回归。补正同优先级能力按施加顺序触发、Double Tap/Rampage共享身份成长、暂停事务克隆引用，以及Burn/Regret回合末顺序。原始75卡名保留，旧附件允许自定义名称仅为历史口径。仍缺Courier补货MathUtils身份熵接线、正版PC构建身份认证、完整同源回归和逐卡平台联动证据，不将可复现当原版一致性通过。源a891451整合develop7f11cc2，150普通/升级与75获取升级下一战事务通过；平台新组合正在重建，历史启动/普通实战不移算到新组合。

2026-10-25：Courier职业补货身份改走独立MathUtils语义的会话熵，稀有度仍共用cardRng；6组外部熵/失败原子性、15组重复卡槽、既有商店专项通过。依据与精确边界见docs/reviews/TASK-16-warrior75-courier.md。原作全局外部随机历史、PC二进制认证和平台商店实玩仍未验；不勾选严格验收。7854a5e修复完整牌名/效果裁切、重复Searing Blow升级预览，900条菌兽与每色800条虱虫决策断言均保留，构造优化后分别约2.5/3.4秒；完整CI待新SHA。

整合develop9ae1aec时复核AbstractRoom.endTurn发现临时费用边界：原版在回合末只重置手/抽/弃牌堆，排除消耗堆。先新增跨回合零费Bludgeon→Exhume取回红例（错误3费），再把重置移到回合末且排除消耗堆，40组边界通过。正规房间HP/AI/misc/洗牌流、手动金币奖励与完整75卡奖励cardRng已共同接线；combat_gold13、reward_flow10、Boss奖励事务及药水失败原子性专项通过。历史529原生150基础升级/六专项通过但选牌脚本错误、卡名第二行和选择费用未通过；cursorArea及新标题布局需新同源官方Lua门禁后实测。
<!-- SECTION:NOTES:END -->
