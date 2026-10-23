---
id: TASK-13.1.2.1
title: 实现事件配对翻牌状态机候选
status: In Progress
assignee:
  - '@dot'
created_date: '2026-10-23 17:31'
updated_date: '2026-10-23 17:35'
labels: []
dependencies: []
references:
  - TASK-13.1.2
parent_task_id: TASK-13.1.2
priority: high
type: feature
ordinal: 55000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
未知事件全池缺少记忆翻牌基础能力。先实现独立配对状态机候选，输入由调用者准备的十二格牌面，不修改生产事件池、抽牌随机流、永久卡牌分配或界面。只有后续接入采样、诅咒、奖励事务和UI后才是可玩的事件。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 按固定来源行为处理十二格、五次尝试、按cardID配对；命中和未命中均消耗尝试，配对移除并只发出一次奖励结果。
- [ ] #2 拒绝非法或重复格子选择，解析期间锁定操作；公开视图与调用者输入不能篡改内部状态。
- [ ] #3 给出固定来源引用、独立回归与负控，明确未接入生产及未证明官方PC二进制或全随机流一致性。
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. 核对项目来源账本中的固定GremlinMatchGame规则。2. 测试驱动实现独立候选状态机和只读快照。3. 独立复审、负控及当前CI，通过正常PR保留候选；生产接线留父任务。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
候选仅新增独立状态机、17组回归及来源/API说明，固定来源blob f86144bdf0e00acad096e8668f17fa96d6aabac1已验证。测试先缺模块失败后17/17；10个开发负控和9个独立评审负控均被拒。独立模型对照通过，无阻塞发现。只返回一次奖励结果，不保证永久卡牌获取事务，未来适配器必须定义失败恢复；未接入生产事件池、随机流、库存或UI。待正式当前头CI，不勾生产或平台验收。
<!-- SECTION:NOTES:END -->
