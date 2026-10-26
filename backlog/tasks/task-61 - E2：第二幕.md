---
id: TASK-61
title: 接齐第二幕敌人、事件和正式游玩流程
status: In Progress
assignee:
  - '@Furinya'
created_date: '2026-10-23 01:59'
updated_date: '2026-10-26 16:11'
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
第二幕地图、队列和资源迁移基线已合入，本轮独立分支补齐5弱/8强/3精英/3Boss共19个源编组及特殊机制，40份固定源摘要和34组回归可查。仍缺事件专属敌人、13普通事件、完整Host自然流程及四职业连续/平台通关；本轮切片通过不等于第二幕整体Done。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 第二幕18至34层按原版地图、遭遇权重和全部三种Boss合法生成，接上第35层
- [ ] #2 13普通事件及神龛、一次性事件资格、内部交易和事件战斗真实执行
- [ ] #3 四职业分别正常连续通关且资源继承正确，保留同源本地、集成和平台证据
- [x] #4 第二幕18至34层地图、来源队列与跨幕资源迁移基础已合入PR213并有独立向量和事务回归。
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
2026-10-26本轮M3并行：act2独立工作树按固定来源补第二幕怪物组的A0数据/AI和正式构造分派，保留未实现内容拒绝边界，不代用第一幕怪物。Host/章节UI由父线程负责，事件和药水另树；统一集成和回归后再判各层验收。

本轮组合审查独立补齐章节非稀有奖励升级0/25/50/50%的源序、纯数据保留、UID领取及下一战；主线程接升级卡面与缺定义奖励的明确不可领取显示，身份与随机消费不重抽。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
2026-10-26状态整理：PR213已合入第二幕地图/队列/转场共享基础，但第二幕怪物AI与事件体尚未实现，正式Host未接，不能当内容齐备。仍To Do；内容实现从现有核心继续，勿重写地图。

2026-10-26任务首页校正：直接体现已合并成果及下一步，撤销仅登记/未启动等过时开工描述。保留原有全量验收标准，不以合并代替平台验收。

本轮隔离分支已增量实现第二幕全部5弱/8强/3精英所需怪物与编组，含Hex、Flight、Confusion、吸血破甲、Leader真实召唤；Champ已实现，另外两Boss和事件敌人仍缺。各切片定向红绿与固定源SHA账本见docs/rules/ACT2_ENEMIES.md，父线程正在组合验证。当前不是完整第二幕/平台验收，三项广义AC不勾。

2026-10-27组合复审：真实Leader重复Rally保留尸体后，活敌真实索引超过5导致界面不可见已复现。独立m3-summon-visibility树正在分离显示槽与actor身份，保留核心尸体、点选/拖牌/帮助/反馈及旧输入保护；缺陷修复及当前SHA完整检查完成前不提高父任务验收状态。
<!-- SECTION:NOTES:END -->
