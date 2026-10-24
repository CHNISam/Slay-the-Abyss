---
id: TASK-16.1.3
title: 修复重复施放永世的磐岩时的多余反馈
status: In Progress
assignee:
  - '@dot'
created_date: '2026-10-24 11:17'
due_date: '2026-10-28'
labels:
  - required
milestone: m-4
dependencies:
  - TASK-16.1.1
references:
  - docs/backlog-details/TASK-16.1.md
  - docs/reviews/TASK-16-m3-card-audit.md
parent_task_id: TASK-16.1
priority: high
type: bug
ordinal: 87000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
已有保留格挡效果时，再施放这张能力牌会多产生一条零层状态事件，引发多余提示。让重复牌仍正常付费和离开手牌，但不再重复播放无效状态反馈；不改费用或效果数值。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 首次施放仍正常获得保留格挡效果；重复施放不再产生多余的零层状态事件。
- [ ] #2 基础和升级牌都正常扣能量、离开手牌，回合开始时的格挡保留行为不变。
- [ ] #3 其他状态的零值处理、免疫拦截和失败回滚不受影响，非法输入仍按原规则拒绝。
- [ ] #4 固定来源、真实出牌、事件与反馈回归通过独立审查和当前提交CI；不冒充已在游戏里验收。
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
先复用PR177的重复Barricade真实失败诊断，核固定ApplyPowerAction来源与当前反馈路径。仅在effect解释层收窄重复本能力的施加门槛，不全局屏蔽amount=0、不修改Actor共享状态API或卡牌费用。覆盖首次/重复基础及升级、正常付费与牌去向、格挡保留、非法数值和Artifact/Flex零值原契约。独立评审后按当前CI集成，保留Shockwave两条未修顺序差异。
<!-- SECTION:PLAN:END -->
