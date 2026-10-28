---
id: TASK-79
title: 修复紧急合并后的真实检查失败
status: In Progress
assignee:
  - '@Furinya'
created_date: '2026-10-28 11:33'
updated_date: '2026-10-28 12:25'
labels: []
dependencies: []
references:
  - docs/backlog-details/TASK-79.md
priority: high
type: bug
ordinal: 122000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
紧急合并后的develop完整检查出现跨平台UI集成失败；逐项核对真实日志，修正功能回归和合法设计变动后的测试合同，保留原预算及历史证据。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 当前develop相关失败逐项记录根因和修复映射
- [ ] #2 完整Windows与Linux检查保持全部有效测试和原超时并通过
- [ ] #3 修复精确PR头完整检查通过并由S0审查；合入后最终复验由S0负责
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
先读全部失败日志并复现；分别修共享mock、合法UI合同与历史逆投影；验证定向负例和工程门禁；提交独立PR、等待完整CI并交S0验收。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
已固定最新7a87de3a完整失败日志并分类：真实Boss/五敌意图遮挡和Quick浅克隆base缺失已最小修复；模拟Color与合法视觉合同更新保留全部场景/原时限/精确逆转原hash。25项历史/空间/原生契约、原七片53场景/六种子及通用runner18项通过。完整PR头CI与S0审查未完成，保持In Progress；详见附件。

PR302首头036ce0de真实CI仍失败：Quick昏眩主图标预期错误；历史逆层抢占旧层中间witness；Sapphire补参未逆转；selector把条件历史分发传播给无关wrapper。本轮逐项修复，旧黄金/时限保持；另主动扫描补齐三个NodeUI平台Color模拟。Node24当前16项来源/原体/正式入口、四raw批次全部status0、selector/Quick100项全过；首轮失败与取消均交S0审计，未宣称036通过。
<!-- SECTION:NOTES:END -->
