---
id: TASK-62
title: 接齐第三幕敌人、事件和结局流程
status: In Progress
assignee:
  - '@Furinya'
created_date: '2026-10-24 02:02'
updated_date: '2026-10-27 15:07'
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
第三幕地图、来源队列和结局边界已合入；已合内容与待合PR252组合后，全部弱敌、强敌、精英和三Boss均有生产路由。仍缺心灵绽放、神秘球体及共享事件完整执行、自然章节流程和四职业同候选平台通关；第三幕没有Boss宝箱。
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

2026-10-27优先级重排：High：第三幕敌人/事件/结局仍在PR238，当前先完成该集成再开放完整四幕验收。 解除后移出High再提升下一项；不放宽原验收。

2026-10-27 独立源码增量候选补Awakened One两阶段、Writhing Mass、Giant Head：真实0HP半死/复活与非目标选择连续性、源AI/RNG/Reactive与永久Parasite取得、Slow实际卡实例afterUse时点及Java浮点次序均有固定319009d5来源和独立审查。补通用Run.play完整事务边界，晚期奖励抛错或拒绝恢复原始对象/RNG/永久牌并可重试。五叶合并保留现有三职业内容、Ghosts和源码公告，87项Node与177组既有Lua回归通过；178模块/1050边、Luacheck89历史警告0新增、构建/数据/UI主题门禁通过。此候选未包含下一批Time Eater/Nemesis/Reptomancer/Darklings，不宣称全第三幕/全M3/自然四职业四幕或原生验收；整项AC不关闭，当前新PR完整Quality待证。

2026-10-27运行时重算：以81f3ffd2的实际Run.new入口加载当前JSON与Lua，四职业各75张共300张的基本/升级Capability均通过；战士reward/src/shop各72个唯一ID，其他职业各71个，逐ID双版本无缺定义；四职业各33瓶药水均通过生产available定义检查。第三幕3弱/8强/3精英与三Boss均有生产路由，七普通事件仍缺MindBloom和Mysterious Sphere映射。PR252本次记待合，最终合并由主线程另行核对。证据：docs/evidence/m3-runtime-audit-20261027.json及docs/backlog-details/BACKLOG-UPDATE-20261027.md本轮节。Capability不代表逐牌实际执行或原版完整一致；定义注册和路由不代表自然获取、概率全链或平台通关。本次只更正首页与追加事实，状态、负责人、优先级、依赖和全部验收项保持，不新增勾选；历史数量和旧备注保留原样。
<!-- SECTION:NOTES:END -->
