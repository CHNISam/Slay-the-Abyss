---
id: TASK-4.6
title: 让战斗卡牌数字显示增减颜色和文字提示
status: In Progress
assignee:
  - '@Codex'
created_date: '2026-10-24 17:08'
labels: []
milestone: m-5
dependencies: []
parent_task_id: TASK-4
priority: high
type: enhancement
ordinal: 92000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
按用户提供的动态数值反馈实施包，复用现有战斗预览，补数字颜色与不依赖颜色的方向提示。技术约束、矩阵和分层验证见 docs/backlog-details/card-value-feedback.md。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 逐效果使用本卡当前定义和预览比较，支持增强、削弱、中性及瞄准取消，战斗规则不变。
- [ ] #2 数字采用主题增减色并有文字方向，保留费用、完整描述和输入隔离；本地自动回归通过。
- [ ] #3 同源候选完成构建回读，真实记录原生电脑与手机验证和严格UI门禁，未测项明确保留。
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. 冻结基线与矩阵；2. 先红后绿实现只读逐效果展示；3. 原生能力核查与最小布局；4. 自动回归、候选与分层证据；5. 当前SHA CI通过后PR合并develop。
<!-- SECTION:PLAN:END -->
