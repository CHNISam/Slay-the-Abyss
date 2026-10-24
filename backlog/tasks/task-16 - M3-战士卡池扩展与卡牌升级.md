---
id: TASK-16
title: 做好首发卡牌、费用和升级效果
status: In Progress
assignee:
  - '@Codex'
created_date: '2026-10-22 13:48'
updated_date: '2026-10-24 10:35'
due_date: '2026-10-28'
labels:
  - queued-after-M2
milestone: m-4
dependencies:
  - TASK-9
  - TASK-14
references:
  - docs/backlog-details/TASK-16.md
  - docs/reviews/TASK-16-m3-card-audit.md
priority: high
ordinal: 16000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
首发岩元素荧使用原版战士的卡牌体系。至少30张牌要能正常获得、使用和升级，支持多种合法构筑。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 逐张核对原版依据，差异和未确认的效果列清楚。
- [ ] #2 至少30张可用牌的普通和升级效果、费用、目标和使用条件正确，初始牌组和遗物也正确。
- [ ] #3 能通过奖励、商店和营地正常获得或升级；说明与效果一致，未做完的牌不出现。
- [ ] #4 测过每张牌和升级效果，能自然组成力量、格挡、自损、消耗等合法构筑。
- [ ] #5 保存对应版本的测试和实玩记录；牌表里有名字不代表已经可玩。
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
2026-10-24 M3逐卡核对：在ecade28清单依赖上隔离分支，复用现有30卡及Iron Wave/Twin Strike/能力生命周期账本，读取同一固定镜像逐卡构造、use、upgrade，记录ID/费用/目标/条件/动作顺序与本地覆盖的对应关系；保存来源身份与认证不足，若未发现真实差异不改数值/Combat。定向验证并交增量提交，平台及自然构筑AC保持未勾。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
2026-10-24逐卡审计：30张constructor/use/upgrade重新下载并逐件验证Git blob，另核AbstractCard、Ironclad、EntanglePower和版本字段4件；来源身份及逐卡费用、基本升级效果、目标、条件、测试映射见docs/reviews/TASK-16-m3-card-audit.md及docs/evidence/card-audit-m3。没有找到需要改费用/数值的差异。确认两项严格差异：Shockwave双敌Weak/Vulnerable由逐敌变成逐状态；重复Barricade多发amount0状态帧，三条基本/升级诊断strictExpectedMatch=false，按协调留TASK16/16.1待修，未动Combat/Effects。已有card_pool 93/93、新card_use_requirements 60/60通过；原作构建真实性、共享完整队列/钩子、自然构筑和平台/实机仍未验，AC全未勾，保持In Progress。
<!-- SECTION:NOTES:END -->
