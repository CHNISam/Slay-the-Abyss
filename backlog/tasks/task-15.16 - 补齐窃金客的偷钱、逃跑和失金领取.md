---
id: TASK-15.16
title: 补齐窃金客的偷钱、逃跑和失金领取
status: Done
assignee:
  - '@dot'
created_date: '2026-10-24 07:57'
updated_date: '2026-10-24 09:32'
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
  - docs/reviews/TASK-15.16-looter-steal-escape-reward.md
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
- [x] #1 按固定原版来源实现44–48生命、两次偷钱攻击、后续分支及逃跑；每次最多偷15金币，格挡不免偷。
- [x] #2 每只敌人独立记账，逃跑不返还，死亡只登记待领奖励；伤害、死亡、随机消耗和失败回滚顺序有真实用例。
- [x] #3 战后取回失金与选牌分别操作，重复领取和旧操作无效；离开可以放弃未领取项目，无失金的旧奖励流程不变。
- [x] #4 实际战斗、领取、逃跑、重开与多敌边界通过独立审查及当前提交CI；完整奖励算法和实机未验证部分如实保留。
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
一个PR内先完成独立失金领取与既有控件接线，再一次接通窃金客血量、AI、扣金、逃跑和死亡登记；整条链验证前不启用生产偷金。不更改商店、完整奖励池或原作随机分流。保留现有胜利场次统计语义，不拿原作击杀统计擅自替换。先红后绿、独立审查和精确CI后集成。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
完整窃金客战斗与独立失金领取已接入当前药水奖励、Boss宝箱、居中选牌及开场对话；保留无失金原有操作。已通过离线独立规则、事务和输入回归；补齐药水击杀失败时的随机流回滚。正式当前提交CI待验证，不算已合并或实机通过。来源、原有异常边界和剩余缺口见专项报告。
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
完整有限切片已完成源码与独立验收：窃金客A0偷钱/逃跑/死亡登记及独立失金领取，兼容居中选牌、正常药水、Boss宝箱与开场商人。157份native Lua通过；独立规则/奖励/输入与最终组合核验通过。代码提交b3b967ea86bd5f084989e669d81edf311a6eee75的Quality两作业成功：https://github.com/CHNISam/Slay-the-Abyss/actions/runs/40081525906 。本次状态收口后仍以最终提交CI及PR168合并作为远端交付证据。完整随机流/奖励池、任意endTurn异常原子性、官方导入及此组合PC/手机实机不在本有限切片完成声明内，详见专项报告。
<!-- SECTION:FINAL_SUMMARY:END -->
