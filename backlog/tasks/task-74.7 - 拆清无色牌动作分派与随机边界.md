---
id: TASK-74.7
title: 拆清无色牌动作分派与随机边界
status: In Progress
assignee:
  - Furinya
created_date: '2026-11-04 15:42'
updated_date: '2026-11-04 15:43'
labels: []
milestone: m-7
dependencies: []
parent_task_id: TASK-74
priority: medium
type: task
ordinal: 143000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
现有Colorless.apply集中全部动作分派，CC82；此独立模块未被开回合切片覆盖。只治理动作职责，不调整卡牌规则。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Madness、Deep Breath、Violence、Greed和Ritual等动作旧新差分及错误变异保持RNG、顺序和永久成长语义
- [ ] #2 入口和全部helper接入CC15门禁并记录全库与依赖指标
- [ ] #3 相关回归、独立复审、精确HEAD Full及合后验证分别通过
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. 固定b4ac6314全源，按动作职责提取同模块分派并保留原RNG/队列/击杀判断。2. 新helper全纳入CC15，旧新独立VM及真实变异证明随机、金币与成长一致。3. 本地与独立复审通过后提交独立PR，Full及合后验证分别取证。
<!-- SECTION:PLAN:END -->
