---
id: TASK-61
title: 接齐第二幕敌人、事件和正式游玩流程
status: In Progress
assignee:
  - '@Furinya'
created_date: '2026-10-23 01:59'
updated_date: '2026-10-26 13:11'
labels:
  - required
  - sts1
  - acts
  - implementation-gap
  - partially-implemented
milestone: m-4
dependencies:
  - TASK-63
  - TASK-59
references:
  - docs/SCOPE.md
  - docs/backlog-details/DRAFT-2.md
  - docs/rules/CROSS_ACT.md
  - docs/BACKLOG-RECONCILE-20261026.md
  - docs/BACKLOG-AUDIT-20261026.md
priority: high
type: feature
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
已通过PR213合入第二幕18至34层地图、遭遇权重/队列、Boss选择基础和换幕资源迁移，复用TASK-63，不重写地图。M3剩余：实际怪物与三Boss AI、13普通事件及共享事件交易/战斗、正式Host和章节UI，随后四职业连续通关。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 第二幕18至34层按原版地图、遭遇权重和全部三种Boss合法生成，接上第35层
- [ ] #2 13普通事件及神龛、一次性事件资格、内部交易和事件战斗真实执行
- [ ] #3 四职业分别正常连续通关且资源继承正确，保留同源本地、集成和平台证据
- [x] #4 第二幕18至34层地图、来源队列与跨幕资源迁移基础已合入PR213并有独立向量和事务回归。
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
2026-10-26状态整理：PR213已合入第二幕地图/队列/转场共享基础，但第二幕怪物AI与事件体尚未实现，正式Host未接，不能当内容齐备。仍To Do；内容实现从现有核心继续，勿重写地图。

2026-10-26任务首页校正：直接体现已合并成果及下一步，撤销仅登记/未启动等过时开工描述。保留原有全量验收标准，不以合并代替平台验收。
<!-- SECTION:NOTES:END -->
