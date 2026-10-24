---
id: TASK-46
title: 重构已批准的M0–M6首发排期与E1–E5候选路线图
status: Done
assignee:
  - '@Codex'
created_date: '2026-10-24 01:58'
updated_date: '2026-10-24 02:22'
labels: []
dependencies: []
references:
  - 'https://github.com/CHNISam/Slay-the-Abyss/pull/151'
priority: high
type: docs
ordinal: 74000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
执行用户批准的《杀戮原塔2》管理路线图迁移；仅修改Backlog与必要文档，不包含产品实现或游戏验收。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 M0–M6日期、任务分层和E1–E5独立候选可经CLI读回，既有完成证据和进行中/Blocked状态保留。
- [x] #2 依赖无循环且基础通关不等待全量内容审计；文档包含阶段任务状态、关键路径、证据及迁移前后对照。
- [x] #3 迁移变更有可审阅PR，本地检查及当前SHA的Quality门禁结果可追溯；仅在最终SHA全部Quality作业成功后合并。
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. 从最新develop审计任务、Draft、依赖与PR并冻结迁移前快照。2. 仅经Backlog CLI迁移和拆分任务，保留Done证据与进行中状态。3. 同步Milestone Tree、范围、顺序规范和迁移对照。4. CLI读回、doctor和管理一致性检查；当前PR SHA的Quality全绿后合并并清理。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
CLI读回与doctor通过；106项迁移前既有任务状态、65份Done文件、199项已勾AC保全；另有本轮新建管理任务46。依赖无环，可选候选不阻塞主线。语法与数据校验通过。PR151首轮SHA 2a81ace已获presentation通过，check正在运行，尚不合并。

PR151首轮2a81ace的Quality40053033197两作业success：check 7m33s、presentation 8s。已同步PR150后的d0bf727并原样保留事件Done文件；地图手势任务保留In Progress且归M2。原直播编号冲突通过CLI承接至TASK48。最终记录提交仍须按其SHA重跑Quality全绿，才允许合并。
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
已交付M0–M6阶段、任务切片与依赖、E1–E5独立候选、迁移表及文档统一。CLI/doctor、Done文件与已勾AC保全、语法及数据检查通过；PR151首轮Quality40053033197双绿。游戏任务状态仅保留PR150已证实的外部Done更新，未宣称游戏验收或投稿完成；最终提交门禁与合并结果见PR151时间线。
<!-- SECTION:FINAL_SUMMARY:END -->
