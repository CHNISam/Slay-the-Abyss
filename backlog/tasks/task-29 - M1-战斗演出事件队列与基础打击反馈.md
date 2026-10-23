---
id: TASK-29
title: M1 战斗演出事件队列与基础打击反馈
status: In Progress
assignee:
  - '@Codex'
created_date: '2026-10-22 23:29'
updated_date: '2026-10-23 00:46'
labels:
  - P1
  - battle-feedback
milestone: m-2
dependencies:
  - TASK-10
  - TASK-11
references:
  - docs/COMBAT_FEEDBACK.md
priority: high
type: enhancement
ordinal: 38000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
复用批准稿主题参数与同步核心，增加只读表现队列及原生UI基础反馈。M1立即实现本地闭环；平台验收衔接TASK-3.2导入与TASK-3实战。M4精修继续由TASK-4承接。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 真实出牌命令驱动攻击飞牌、命中/飘字/血条，格挡获取与吸收、状态、死亡和胜负过渡；本地控件集成可复核
- [x] #2 敌方回合按行动者和意图顺序展示，多段/多敌/群体/持续伤害/反伤不跳过
- [ ] #3 自动回归验证规则结果与RNG不变、事件仅消费一次、输入恢复及表现故障恢复；控件复用有界；npm run check和CI通过
- [ ] #4 同一候选经TASK-3.2导入后完成TASK-3基础反馈实机截图/日志或录像；音效编号及听感以平台验证为准，未验证明确记录
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. 保留核心同步事务，补齐有序只读表现事件与轻量状态快照，复用已有主题时序。2. 原生UI增加复用的飞牌/命中/盾牌/飘字/血条残影/震动/死亡和回合横幅，host等队列结束才切结果。3. 真实Run命令集成测试覆盖三主场景及多段、多敌、群体、状态、反伤、胜负、故障和重入；比较完整规则状态和RNG。4. npm run check、独立代码自审和CI后提交PR，符合门禁集成develop；构建同SHA存档副本，衔接TASK-3.2/TASK-3实机，未验证分层记录。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
真实Run命令的攻击/格挡/敌回合、群体、多段多敌、中毒/荆棘、死亡及宿主过渡回归通过；6种子序列比较运行状态与RNG。准备/控件/音效故障、重入、切局与消费帧释放均有回归。保持In Progress：同候选平台实机与音效听感未验。整体变更复核已按large-change-review完成，发现并修复药水槽被快照重建、准备失败后重绘与切局残留等边界。
<!-- SECTION:NOTES:END -->
