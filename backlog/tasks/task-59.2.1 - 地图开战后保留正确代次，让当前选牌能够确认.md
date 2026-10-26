---
id: TASK-59.2.1
title: 地图开战后保留正确代次，让当前选牌能够确认
status: Done
assignee:
  - '@Furinya'
created_date: '2026-10-26 09:53'
updated_date: '2026-10-26 13:08'
labels: []
milestone: m-4
dependencies: []
parent_task_id: TASK-59.2
priority: high
type: bug
ordinal: 116000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
地图通过暂存Run建立战斗后没有提交combatGeneration。实验Defect自然抽到Seek时，真实当前选择被误判过期。该问题在develop已存在，独立于未合并章节功能，也不同于TASK-67的参考夹具元数据修正。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 从真实地图入战斗后当前Seek选择成功，Run与Combat代次一致
- [x] #2 新战斗代次递增，旧代次、坏token/UID及重复确认继续拒绝
- [x] #3 入战斗异常后状态和原有对象引用回滚，重试成功
- [x] #4 针对性反例先红后绿，准确提交通过完整Quality后合入
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. 复用独立复审的公共入口回归，验证develop基线红灯。2. 在已有Nodes事务提交中只补combatGeneration字段。3. 跑当前/旧代次、失败回滚、选择/节点回归；独立复审与精确SHA完整CI后合并。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Executor: dot，自有云独立工作树feat/dot-node-combat-generation，基线4c75a31。该单行修复和测试来自已完成TASK63.1独立实现，现从跨幕范围拆出，避免等待PR213；TASK63.1已经原生CLI移除此范围，不重复开发。独立复审已在准确develop基线验证先红后绿。Owner09:35授权这轮修复、测试、PR与合并，不改其他执行者工作区或认领。

独立复审在准确develop4c75a31完整生产源码副本中，仅拷贝新测试先复现stale_combat_generation红灯；只加入Nodes提交代次这一行后3组通过，测试与本分支逐字一致，无跨幕模块依赖。保留旧代次、token/UID、重复确认拒绝及第二次开战异常回滚/重试断言。未减少或放宽守卫；远端完整CI仍待执行。

与TASK-68.1组成同一主线小修复候选feat/dot-regression-boundary-fixes，保留独立回归及审查证据，一次准确SHA完整Quality；不等待或夹带跨幕功能。

最终组合候选实跑：node-generation3/3、selector35/35与JS语法通过；Backlog校验首次提示缺里程碑，已沿用父任务m-4补齐后重验。

首轮PR221准确head的官方Linux完整npm1502/1502通过，架构109/497通过；Luacheck因新增一行移动了三处既存unused position的基线行号而失败。已实际移除这三处未使用第二局部绑定，不改find调用/首返回值，不修改基线或阈值；8份shop/purge/节点相关回归通过，等待新head完整CI。

已接入e3a9fe2主线；其本身已清理三处unused绑定，因此对新主线净生产差异只有一行代次提交。新组合3组地图/选择/回滚回归再次通过，当前准确新head完整CI待验证。
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
已由PR221合入4bbd151。精确旧主线公共地图入口反例先红，仅补Nodes代次提交后3组通过：当前Seek成功、旧代次/token/UID/重复确认拒绝、第二场代次递增及异常回滚/重试。独立复审与准确head3a3bf6a完整Quality/Licenses通过；普通expected-head squash后树与预期一致。仅关闭代码回归修复，不将父任务UI或原神/手机实机验收提升为通过。证据：https://github.com/CHNISam/Slay-the-Abyss/pull/221
<!-- SECTION:FINAL_SUMMARY:END -->
