---
id: TASK-62
title: 接齐第三幕敌人、事件和结局流程
status: In Progress
assignee:
  - '@Furinya'
created_date: '2026-10-24 02:02'
updated_date: '2026-10-27 15:53'
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

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
2026-10-27用户试玩期间持续离线冲刺：按固定319009d5来源独立补MindBloom和MysteriousSphere；子线程各实现事件阶段和源规则，主线程接事件战斗构造/房间奖励桥、完整事务、原生显示及机器清单。保留普通怪物/Boss队列和原预算，先单项红绿再串行共享全链回归；当前可玩测试包b12beab2保持冻结。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
2026-10-26状态整理：PR213已合入第三幕地图/队列和普通结局边界，实际怪物AI/事件体与正式Host尚未接，仍To Do。第三幕不存在Boss宝箱；按现有核心接内容再连续通关。

2026-10-26任务首页校正：直接体现已合并成果及下一步，撤销仅登记/未启动等过时开工描述。保留原有全量验收标准，不以合并代替平台验收。

2026-10-27接续状态：第三幕新增敌人/事件切片仍由PR238整合集成，远端head a4dac772为OPEN/DRAFT且CONFLICTING，未合并。同步fc51f198后Transient、Shapes、Shapes Defect、Orb Walker、Maw Growth定向通过仅为本地证据；最终整合仍有库存恢复/道具来源回归失败。先完成同一PR当前SHA验收，再补正式入口及四职业自然连续通关，不把独立切片计整幕完成。

2026-10-27优先级重排：High：第三幕敌人/事件/结局仍在PR238，当前先完成该集成再开放完整四幕验收。 解除后移出High再提升下一项；不放宽原验收。

2026-10-27 独立源码增量候选补Awakened One两阶段、Writhing Mass、Giant Head：真实0HP半死/复活与非目标选择连续性、源AI/RNG/Reactive与永久Parasite取得、Slow实际卡实例afterUse时点及Java浮点次序均有固定319009d5来源和独立审查。补通用Run.play完整事务边界，晚期奖励抛错或拒绝恢复原始对象/RNG/永久牌并可重试。五叶合并保留现有三职业内容、Ghosts和源码公告，87项Node与177组既有Lua回归通过；178模块/1050边、Luacheck89历史警告0新增、构建/数据/UI主题门禁通过。此候选未包含下一批Time Eater/Nemesis/Reptomancer/Darklings，不宣称全第三幕/全M3/自然四职业四幕或原生验收；整项AC不关闭，当前新PR完整Quality待证。

本轮Codex并行分工：MindBloom模块、MysteriousSphere模块、终幕资格审计/历史owner独立树推进；共享Run/Nodes/Act3Events/EventPool/遗物配置由主线程集成，任务库串行CLI更新。用户正在自行试玩，全部执行者禁用桌面输入。事件战斗仍是EventRoom：源金币与稀有遗物在选择时准备，通用药水和卡牌在战后按原顺序执行；不冒用Boss终局或缩池。
<!-- SECTION:NOTES:END -->
