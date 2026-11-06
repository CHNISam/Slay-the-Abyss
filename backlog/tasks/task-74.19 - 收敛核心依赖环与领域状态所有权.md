---
id: TASK-74.19
title: 收敛核心依赖环与领域状态所有权
status: In Progress
assignee:
  - Furinya
created_date: '2026-11-06 01:46'
updated_date: '2026-11-06 04:48'
labels: []
milestone: m-7
dependencies: []
documentation:
  - docs/backlog-details/M7-DEPENDENCY-AUDIT-20261106.md
parent_task_id: TASK-74
priority: medium
type: task
ordinal: 161000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
当前大SCC仍有104个模块，既有职责切片未覆盖全部跨领域反向边；先确认影响后续角色内容开发的真实高风险耦合，避免仅靠拆文件宣称架构完成。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 以当前同一源码身份输出即时及延迟完整依赖图、SCC成员和内部边位置，逐类说明状态提交owner与风险依据
- [ ] #2 消除已确证P0/P1反向依赖并以旧新状态、随机、事件、队列、别名及失败回滚对照验证；保留边有生命周期依据且新增边受可执行防回退门禁
- [ ] #3 公布同算法最终SCC绝对值、残余风险与责任；独立深审及实际合后Full通过，未确认残余不冒充低风险
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1.在dedb9ed5完整源码上复用AST依赖采集，核对即时及延迟SCC、真实反向调用与状态owner。2.独立审查优先核心调用链，形成逐边风险与可证实解环路径。3.按真实P0/P1选择最小职责切片，固定旧新行为并加门禁后独立深审及完整交付。

4.依据391306af只读审计与现有CardActions规范，准备单一无出边遗物只读查询模块：移动原五套有序alias及窄奖励计数，保留普通动态字段读写、Shop.aliases枚举/替换、Rare私有owns与公开替换隔离、Run调用时函数快照。先冻结完整旧源和行为/加载边界基线；当前PR521由原生队列完成，后续提交不另建待合PR或改入队HEAD，待基线落地后再集成。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
本轮新鲜AST：328模块1902引用位置1535唯一对；即时图无SCC，含延迟图104成员804内部位置538唯一对。已逐类核对RelicHooks和Session/Combat提交owner，见M7-DEPENDENCY-AUDIT-20261106。六处入队解耦只减少职责反向边，不使大环缩小；优先审清生命周期切片及历史来源适配成本，不以数字下降收口。

只读反事实提示CardPool三查询接真正叶可使104→103；更大族Session与purge路径104→88仅删边实验，不是实测改善或P2接受。补查现有规范不承诺raw反射形状，真实Shop.aliases与Rare.owns动态消费必须保留；原先要求纯反射另审批的推断已撤回。证据在主控521工作树build/g1-next-boundary及根.artifacts。所有AC仍未勾。

遗物只读查询切片已在隔离树完成本地实现：单一零依赖叶保留五别名域和动态API；139别名、48奖励场景/344随机数边界双独立VM一致，专项6/6绿。CardPool实际退出核心SCC，104→103成员、内部位置804→791，未宣称整个环完成。独立生产初审无缺陷；来源适配、最终提交与托管验证继续，AC保持未勾。技术证据见docs/backlog-details/M7-RELIC-QUERIES-20261106.md。

只读能力批次新增永久牌候选owner：仅依赖Copy，Boss不再回导LivingWall事件；原动态purgeCards、逐卡Copy图、错误和事务/RNG保持。新增6项先红后绿，原LivingWall72变换槽及Boss/Astrolabe等9项绿；同epoch十源34项绿。完整图实测331模块，大环102成员/787内部位置/527对，CardPool与LivingWall退出；14旧告警，无新增豁免。源码和来源已稳定，最终独审/提交/托管继续，AC未勾。
<!-- SECTION:NOTES:END -->
