---
id: TASK-74.7
title: 拆清无色牌动作分派与随机边界
status: In Progress
assignee:
  - Furinya
created_date: '2026-11-04 15:42'
updated_date: '2026-11-04 15:59'
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

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
本轮同模块动作分派已实现：apply CC82降至2，21新helper最高9，入口及helper总CC仍82；全库CC>15为282→281、CC>30为78→77，依赖/SCC/15历史告警不变。三组独立VM23场景46边界逐字一致，7真实变异由行为断言拒绝；52项定向JS与原9份Lua通过。新增raw默认低输出合同另验。源码与限制详见docs/backlog-details/TASK-74.7.md及docs/evidence/colorless-actions-20261104.json。独立复审、精确HEAD Full和合后push尚待，AC不提前勾选。
<!-- SECTION:NOTES:END -->
