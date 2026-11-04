---
id: TASK-74.10
title: 拆清实验回合结束与敌人阶段职责
status: In Progress
assignee:
  - Furinya
created_date: '2026-11-04 16:17'
updated_date: '2026-11-04 16:31'
labels: []
milestone: m-7
dependencies: []
documentation:
  - docs/backlog-details/TASK-74.10.md
parent_task_id: TASK-74
priority: medium
type: task
ordinal: 147000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
实验结束回合入口CC55，包含费用恢复、自动结束牌、保留暂停、全敌开始和轮末编排。只整理现有协议，保持其与native不同的drain和清理行为。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 费用与exhaust边界、NoDraw/Regret、保留恢复、跳怪物回合与敌人快照旧新完整状态差分及真实变异通过
- [ ] #2 入口和全部提取职责接入CC15，保留全库与依赖真实指标
- [ ] #3 原回归、独立复审、精确HEAD Full及合后验证分别通过
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. 固定9a2d88dc源码与已验证native切片，明确实验协议的两处保留恢复guard及费用/NoDraw顺序。2. 同模块拆费用、自动结束牌、玩家结束准备、敌人组及轮末，保留原拒绝顺序和终局/暂停返回；不触碰native/startTurn/M.new。3. 完整旧新差分、真实变异、原回归和CC15后独立复审；Full与合后验收不提前完成。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
实验入口CC55→15，六helper最高9；新5类边界与原6类完整图差分、6真实变异、native16合同与原10入口通过。保留成本exhaust排除、两处独立resume guard、NoDraw/致死Regret/skip与敌人快照。Ctor新引入无关prefix冻结将由最终集成修正，完整行为差分和语义断言保留。独立最终组合、Full及合后未完成。
<!-- SECTION:NOTES:END -->
