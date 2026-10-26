---
id: TASK-61
title: 接入原创四角色战斗与正常流程
status: In Progress
assignee:
  - Furinya
created_date: '2026-10-26 05:23'
updated_date: '2026-10-26 05:52'
due_date: '2026-10-28'
labels: []
milestone: m-4
dependencies: []
priority: high
type: feature
ordinal: 108000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
在不改变旅行者原规则的前提下，让附件V4原创角色接入现有生产战斗和永久牌组事务。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 共享伤害状态队列、全部V4效果与边界符合冻结规则；正式选角与正常获取可达
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
先接原创身份和冻结数据适配，再接原子出牌、实际治疗、结束/开始阶段及正常获取；单写共享战斗核心，保留旅行者回归。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
核心本地切片接入原生queue、34op、角色根事件、统一实际治疗账本、生命代价预检、回合阶段及正常角色profile/奖励/商店策略。19组生产Lua定向边界通过，包括真实Guardian整根转形、Pain+付血原子拒绝、开局血瓶/新回合毒伤气氛预算、零治疗再生事件、命令幂等和只读真实管线预览。统一UI/候选构建/完整600版及跨节点回归将在继任集成树补齐，AC不提前勾选。
<!-- SECTION:NOTES:END -->
