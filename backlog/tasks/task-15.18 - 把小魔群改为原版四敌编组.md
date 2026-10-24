---
id: TASK-15.18
title: 把小魔群改为原版四敌编组
status: In Progress
assignee:
  - '@dot'
created_date: '2026-10-24 10:29'
updated_date: '2026-10-24 10:49'
due_date: '2026-10-28'
labels:
  - required
milestone: m-4
dependencies:
  - TASK-15.17
references:
  - docs/backlog-details/TASK-15.md
  - >-
    https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/helpers/MonsterHelper.java
  - docs/reviews/TASK-15.18-gremlin-gang.md
parent_task_id: TASK-15
priority: high
type: bug
ordinal: 86000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
当前小魔群固定把五种敌人各放一只，敌人数量和组合都不符合原版。按原版带重复权重的候选池抽出四只，保留敌人本身的血量、招式与地图遭遇分布。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 每场小魔群只有四只；狂怒、潜行、迟缓各最多两只，护盾和蓄能各最多一只，抽样权重与原版一致。
- [ ] #2 四次选择按原版顺序抽取并移除候选，不额外洗牌；同样状态产生同样结果，随机状态只在开战成功后提交。
- [ ] #3 正常地图、未知房转战和直接开战都接通；失败重试不消耗随机状态或推进地图，其他遭遇行为不变。
- [ ] #4 固定来源、全部抽取分支的独立预期、真实入口与回滚回归通过评审和当前CI；完整原作随机流和实机仍单独保留。
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
复用TASK15.17的暂存开战事务，先对固定八项池的不放回四抽写独立纯选择预期和真实Run红例，再最小接线。保留原构造槽序与既有HP/AI实现，不改medium_slimes或地图分布，不擅自全局按房间重建随机流。穷举选择器与少量真实入口分层验证，避免每个纯组合都重复构造完整世界。PR174先合后才集成本片，完整原作随机流差异继续留TASK16.1。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
四敌候选池与成功后提交已实现，1680种选择分支、真实入口和失败重试已有红绿及独立回归。161份native Lua与1029项所选Node通过；正式当前提交CI待运行，不等于Fengari或实机通过。原策略seed1真实战胜四小魔后在16层正常失败，全部五局结果与随机流边界如实保留。由dot原生Agent实施和独立审查；当前PATH未找到OpenCode，未新增安装或调用用户Codex/外部模型，额度和费用节省未测。
<!-- SECTION:NOTES:END -->
