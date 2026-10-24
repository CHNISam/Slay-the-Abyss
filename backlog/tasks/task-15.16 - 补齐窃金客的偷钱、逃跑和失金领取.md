---
id: TASK-15.16
title: 补齐窃金客的偷钱、逃跑和失金领取
status: In Progress
assignee:
  - '@dot'
created_date: '2026-10-24 07:57'
due_date: '2026-10-28'
labels:
  - required
milestone: m-4
dependencies:
  - TASK-14
references:
  - docs/backlog-details/TASK-15.md
  - >-
    https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/monsters/exordium/Looter.java
parent_task_id: TASK-15
priority: high
type: bug
ordinal: 84000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
现有窃金客只会攻击和格挡，不会真正偷钱或逃跑。补齐这个首发敌人的完整有限战斗链，玩家击败它后可以在战后单独取回失金，不启用只偷钱却无法领取返还的半成品。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 按固定原版来源实现44–48生命、两次偷钱攻击、后续分支及逃跑；每次最多偷15金币，格挡不免偷。
- [ ] #2 每只敌人独立记账，逃跑不返还，死亡只登记待领奖励；伤害、死亡、随机消耗和失败回滚顺序有真实用例。
- [ ] #3 战后取回失金与选牌分别操作，重复领取和旧操作无效；离开可以放弃未领取项目，无失金的旧奖励流程不变。
- [ ] #4 实际战斗、领取、逃跑、重开与多敌边界通过独立审查及当前提交CI；完整奖励算法和实机未验证部分如实保留。
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
一个PR内先完成独立失金领取与既有控件接线，再一次接通窃金客血量、AI、扣金、逃跑和死亡登记；整条链验证前不启用生产偷金。不更改商店、完整奖励池或原作随机分流。保留现有胜利场次统计语义，不拿原作击杀统计擅自替换。先红后绿、独立审查和精确CI后集成。
<!-- SECTION:PLAN:END -->
