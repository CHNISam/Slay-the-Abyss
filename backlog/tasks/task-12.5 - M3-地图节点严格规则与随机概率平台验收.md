---
id: TASK-12.5
title: 实测地图、价格和掉落概率是否正确
status: In Progress
assignee:
  - '@Furinya'
created_date: '2026-10-24 02:01'
updated_date: '2026-11-01 12:07'
due_date: '2026-10-28'
labels: []
milestone: m-6
dependencies:
  - TASK-12.3
  - TASK-12.4
  - TASK-13.1
references:
  - docs/backlog-details/TASK-12.5.md
  - docs/DELIVERY-CLOSEOUT.md
  - docs/M3-STATUS-20261028.md
  - docs/reviews/M3-EVENTS-OFFLINE-COMPLETION-20261031.md
  - docs/evidence/m3-completion-20261031/
parent_task_id: TASK-12
priority: medium
type: task
ordinal: 78000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
前面的规则做好后，再到游戏里核对地图、商店和奖励的实际结果。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 按原版依据检查路线、房间、敌人分布、价格范围和掉落概率；用足够多的测试确认。
- [ ] #2 在同一个版本实际交易和领奖，金币、物品和概率计数都正确；不能重复领或走非法路线。
- [x] #3 哪些通过、哪些有差异、哪些还没查清分别写明；能通关不等于这些都通过了。
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
2026-10-31 M3整批收口：以独立原版向量、黄金地图和大样本性质复验离线差异，再核同版本客户端交易领奖账本。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
负责人字段规范化：原记录 @Codex 作为历史执行者信息保留；任务负责人为 Furinya。

2026-10-28接续核对：当前主线b7dffdeb已包含PR238/250/252/259/262，第四幕及真结局接线不再待合并。M3当前32/46 Done，14项未完成。最新整合、遗留工作树与具体证据边界见docs/M3-STATUS-20261028.md；旧PR待合/冲突备注仅属历史。本次不新增自然获取、四职业四幕、平台导入或实机通过，不修改既有AC。

2026-10-31 M3最终事实核对：AC3：本轮完成/差异/未验已分列于M3-EVENTS-OFFLINE-COMPLETION；黄金12/12逐图一致，map-properties-10000.log实际10000/10000、0执行错误；价格4096 binary32差分、端点和独立金币/完整药水向量通过。结构性质不等于概率统计或原版PC认证。#1仍缺游戏内路线/敌人分布/概率实测对照；#2仍缺同一官方候选实际交易领奖、金币物品计数及非法路线证据，不以离线能通关代替。

2026-11-01阶段收尾：用户明确确认本轮已打Tag并进入master，发版阶段到此结束。已交付的M3核心实现不重做；本任务仅将剩余未验要求转由M5遗留严格验收承接，保留原状态、范围、全部AC及历史证据，不把发版确认等同逐条严格验收通过，也不重新阻塞已接受的v1.0.0。本次不打包、不追发布回执、不创建新门禁或新期限。
<!-- SECTION:NOTES:END -->
