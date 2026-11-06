---
id: TASK-74.19
title: 收敛核心依赖环与领域状态所有权
status: In Progress
assignee:
  - Furinya
created_date: '2026-11-06 01:46'
updated_date: '2026-11-06 01:51'
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
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
本轮新鲜AST：328模块1902引用位置1535唯一对；即时图无SCC，含延迟图104成员804内部位置538唯一对。已逐类核对RelicHooks和Session/Combat提交owner，见M7-DEPENDENCY-AUDIT-20261106。六处入队解耦只减少职责反向边，不使大环缩小；优先审清生命周期切片及历史来源适配成本，不以数字下降收口。
<!-- SECTION:NOTES:END -->
