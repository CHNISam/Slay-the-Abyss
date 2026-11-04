---
id: TASK-74.17
title: 拆清GameUI构造生命周期并约束完整函数跨度
status: In Progress
assignee:
  - Furinya
created_date: '2026-11-04 22:58'
updated_date: '2026-11-04 22:59'
labels: []
milestone: m-7
dependencies: []
references:
  - docs/SPRINT_EXECUTION.md
documentation:
  - docs/backlog-details/M7-HOST-BATCH-20261105.md
parent_task_id: TASK-74
priority: medium
type: task
ordinal: 155000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
GameUI完整构造器跨度1004行，11处私有UI职责复杂度超过15；构造、输入和生命周期相互捕获，后续维护风险高。仅治理既有行为，保留批准UI及M8设备验收。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 入口文件不超过250行、M.new完整跨度不超过200行，其余函数含嵌套不超过150行；职责模块不超过1000行且全部函数与初始化块复杂度不超过15，当前采集可执行门禁拒绝缺测和超限
- [ ] #2 完整旧新Host独立VM差分覆盖状态别名、随机、返回与异常、原生写入顺序、同步重入、双Host和陈旧输入；真实关键语义变异被拒绝，原历史来源验证每次新鲜且不放宽旧合同
- [ ] #3 独立深审、精确HEAD与实际合入提交完整CI和原交付验证器通过，未实测设备边界保持未完成
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1.认证78e4完整旧Host与历史来源并冻结独立oracle。2.按overlays/view/run/lifecycle/input五个静态职责模块拆分，在原位置安装方法，显式私有owner保持引用及动态查询。3.共享当前AST测量执行入口250/M.new200/其他150/模块1000及全域CC15门禁。4.真实旧新Host完整图/顺序/重入/双Host差分、原历史证明每调用新鲜验证及变异。5.独立深审、精确候选/原生队列/实际推送Full及原合后验收。
<!-- SECTION:PLAN:END -->
