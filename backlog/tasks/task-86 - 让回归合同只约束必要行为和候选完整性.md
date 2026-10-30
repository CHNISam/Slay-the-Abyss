---
id: TASK-86
title: 让回归合同只约束必要行为和候选完整性
status: In Progress
assignee:
  - Furinya
created_date: '2026-10-29 12:26'
updated_date: '2026-10-30 17:06'
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

2026-10-30按真实372秒/77秒历史逆变换成本重审验收边界，保留来源/oracle/语义/负例，去除重复重建成本；本轮最终CI另验。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
固定PR336首失败头4da5c49/run40863783913，区分历史identity、根树合同与无效负例；当前df163运行不冒充失败。实施仅architecture JSON排版空白等价适配，全部旧原文/hash保留；5项定向及9文件30项集成通过，单行磁盘实验与精确PR CI待。证据docs/backlog-details/TASK-86.md。

实际将独立工作树architecture配置压成单行，相同九文件30/30通过(15477.3ms)，finally已恢复原始字节。未修改任何产品Lua/候选审计；精确PR CI未通过前保留AC3未勾。

2026-10-31本轮治理：历史矩阵改在完整原始输入隔离树执行，现行动态Host另验；保留全部原source/oracle及变异负例。Nodes纯历史5/5为47.524s，PR323纯历史5/5为29.603s；原CI372.02/76.82s环境不同，不作严格倍数。原预算runtime代表4入口约5–15s通过；不再每次重复26个UI来源的重复逆变换。实际读源探针证明无关输入1次读，等价输入仍152次完整读且改脏关联owner严格拒绝；最终完整CI仍待。
<!-- SECTION:NOTES:END -->
