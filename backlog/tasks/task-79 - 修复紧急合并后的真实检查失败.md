---
id: TASK-79
title: 修复紧急合并后的真实检查失败
status: In Progress
assignee:
  - '@Furinya'
created_date: '2026-10-28 11:33'
labels: []
dependencies: []
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
