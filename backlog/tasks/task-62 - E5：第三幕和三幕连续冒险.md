---
id: TASK-62
title: 接齐第三幕敌人、事件和结局流程
status: In Progress
assignee:
  - '@Furinya'
created_date: '2026-10-24 02:02'
updated_date: '2026-10-27 04:10'
labels:
  - required
  - sts1
  - acts
  - implementation-gap
  - partially-implemented
milestone: m-4
dependencies:
  - TASK-61
references:
  - docs/backlog-details/DRAFT-6.md
  - docs/rules/CROSS_ACT.md
  - docs/BACKLOG-RECONCILE-20261026.md
  - docs/BACKLOG-AUDIT-20261026.md
  - docs/backlog-details/BACKLOG-UPDATE-20261027.md
priority: high
type: feature
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
已通过PR213合入第三幕35至51层地图、遭遇/Boss队列及51层普通结局与三钥匙门边界；第三幕没有Boss宝箱。M3剩余：真实敌人/三Boss、七普通事件与共享事件、正式Host/章节UI和四职业连续通关。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 第三幕35至51层按原版生成，三种Boss完整执行，Donu和Deca只结算一次
- [ ] #2 七普通事件及共享神龛、一次性事件按资格出现并能执行，第三幕没有Boss宝箱
- [ ] #3 第51层缺钥匙走普通结局，满足资格与三钥匙才进入终幕，四职业分别三幕正常通关并保留证据
- [x] #4 第三幕35至51层地图、来源队列及普通结局/三钥匙门边界基础已合入PR213并有对应回归。
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
2026-10-26状态整理：PR213已合入第三幕地图/队列和普通结局边界，实际怪物AI/事件体与正式Host尚未接，仍To Do。第三幕不存在Boss宝箱；按现有核心接内容再连续通关。

2026-10-26任务首页校正：直接体现已合并成果及下一步，撤销仅登记/未启动等过时开工描述。保留原有全量验收标准，不以合并代替平台验收。

2026-10-27接续状态：第三幕新增敌人/事件切片仍由PR238整合集成，远端head a4dac772为OPEN/DRAFT且CONFLICTING，未合并。同步fc51f198后Transient、Shapes、Shapes Defect、Orb Walker、Maw Growth定向通过仅为本地证据；最终整合仍有库存恢复/道具来源回归失败。先完成同一PR当前SHA验收，再补正式入口及四职业自然连续通关，不把独立切片计整幕完成。
<!-- SECTION:NOTES:END -->
