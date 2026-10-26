---
id: TASK-63
title: 接通已合并跨幕核心的正式入口与完整结局
status: In Progress
assignee:
  - '@Furinya'
created_date: '2026-10-26 05:05'
updated_date: '2026-10-26 13:11'
labels:
  - partially-implemented
milestone: m-4
dependencies:
  - TASK-12.4
  - TASK-14
references:
  - docs/rules/CROSS_ACT.md
  - docs/evidence/m3-cross-act-20261026.json
  - docs/BACKLOG-RECONCILE-20261026.md
  - docs/BACKLOG-AUDIT-20261026.md
priority: high
type: feature
ordinal: 108000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
PR213已合并四幕楼层/地图、来源队列、换幕库存与随机流、事件池生命周期，前三项验收已完成。下一步接正式Host与章节UI，配合61/62/64补内容并验收Boss宝箱、三钥匙及普通/真结局；不重新实现已合入的核心。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 三幕随机地图与终幕固定地图使用正确楼层和独立种子，第一幕回归保持
- [x] #2 换幕保留卡牌身份和库存、执行原版治疗与随机流推进，拒绝重复及非法换幕且不改状态
- [x] #3 普通、神龛及一次性事件在章节间按原版资格重置或保留
- [ ] #4 Boss宝箱与普通结局、三钥匙门和真结局各走合法路径
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
先参数化章节地图和随机流；通过同一事务接入Nodes换幕，再补钥匙与内容清单。保持未实现章节未开放，逐项记录真实缺口。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
2026-10-26本轮离线切片已实现四幕楼层/地图、换幕库存与UID、cardRng开区间真实推进、连续monsterRng遭遇/Boss队列、事件池生命周期和结局/门边界。14连续向量/11计数向量及终幕各三槽固定队列和首幕独立向量通过；seed10首强两前重复例外已按源修复。初跑1470JS有1项环境缺pwsh；398Lua全执行后11失败文件按两个根因修复，13文件定向恢复通过；不冒充最终全量全绿。无同SHA远端CI、正式Host章节UI、完整章节内容或平台证据，保持In Progress且不勾AC。详细源码指纹与原失败/恢复见docs/evidence/m3-cross-act-20261026.json。

2026-10-26状态整理：PR213已合入develop e3a9fe2c，跨幕核心不再待推送或待合并。现有地图、队列、资源与随机流边界是本地实现；Host章节UI、后续战斗/事件、自然钥匙及平台通关仍未完成，详见CROSS_ACT和m3-campaign机器账本。

2026-10-26全面复核：已有实现及原回归支持的本地条款补勾，具体证据见BACKLOG-AUDIT。尚未通过的完整入口、组合/自然实玩或最终音画门禁保留，不重复要求开发已实现机制。
<!-- SECTION:NOTES:END -->
