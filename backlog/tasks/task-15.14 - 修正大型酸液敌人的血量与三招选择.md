---
id: TASK-15.14
title: 修正大型酸液敌人的血量与三招选择
status: In Progress
assignee:
  - '@dot'
created_date: '2026-10-24 02:52'
labels: []
milestone: m-4
dependencies: []
parent_task_id: TASK-15
priority: high
type: bug
ordinal: 80000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
大型酸液敌人当前固定68血且固定循环，缺少原版16伤普通攻击与吐液加入两张污染牌。本切片复用已验证中型酸液策略，先补有限非分裂行为；半血分裂、完整敌人和平台验收仍留父任务，不改父任务认领。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 固定社区源码及hash核对A0血量65–69、吐液11加Slimed2、攻击16、虚弱2与历史随机调用顺序
- [ ] #2 真实Combat/Run负例转绿，覆盖边界历史、排队死亡、多实例、回滚与中型酸液回归
- [ ] #3 严格schema及受影响测试、独立审查、当前SHA正式CI通过，复用既有策略而不复制算法
- [ ] #4 不改玩家命名和数值规则，不碰UI/Actor/Combat；分裂、完整随机流、PC版本认证及平台缺口明确保留
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
保留23组基线负例；复用AcidM策略并仅接大型派发、正确数据与schema；增加历史/随机顺序及严格负对照；独立审查后当前headCI并集成。
<!-- SECTION:PLAN:END -->
