---
id: TASK-86
title: 让回归合同只约束必要行为和候选完整性
status: In Progress
assignee:
  - Furinya
created_date: '2026-10-29 12:26'
updated_date: '2026-10-29 12:32'
labels: []
dependencies: []
priority: medium
ordinal: 128000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
PR集成中的历史实现快照可能阻止行为等价改动，需以真实失败区分回归与过度耦合。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 真实失败有源码与日志归因
- [x] #2 最小合同调整保留完整性并通过正反例
- [ ] #3 当前PR全部必要门禁通过
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
Agent C读取PR336真实失败，区分历史快照与行为回归；仅对证明等价的检查最小调整，保留重要字节完整性与负例；独立PR验收。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
固定PR336首失败头4da5c49/run40863783913，区分历史identity、根树合同与无效负例；当前df163运行不冒充失败。实施仅architecture JSON排版空白等价适配，全部旧原文/hash保留；5项定向及9文件30项集成通过，单行磁盘实验与精确PR CI待。证据docs/backlog-details/TASK-86.md。

实际将独立工作树architecture配置压成单行，相同九文件30/30通过(15477.3ms)，finally已恢复原始字节。未修改任何产品Lua/候选审计；精确PR CI未通过前保留AC3未勾。
<!-- SECTION:NOTES:END -->
