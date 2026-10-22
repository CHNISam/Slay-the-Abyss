---
id: TASK-2
title: M1 复用基础场景并补齐镜头/出生/阵营配置
status: In Progress
assignee: []
created_date: '2026-10-22 13:32'
updated_date: '2026-10-22 22:24'
due_date: '2026-10-24'
labels: []
milestone: m-2
dependencies:
  - TASK-1
priority: high
ordinal: 2000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
搭建战斗场景白盒并锁定镜头与出生点，为卡牌战斗提供稳定的 3D 舞台。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 scene_build_blocks + scene_import_assets 导入成功
- [ ] #2 镜头 fixedView 锁死、出生点与复苏点已设、玩家数设为 1 到 1
- [ ] #3 阵营仅玩家与敌人敌对，己方单位不打自家物件
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. 复用1073741825与既有场景导入记录。2. 在副本补锁镜头、出生/复苏点、单人及阵营最小缺口。3. 导入副本核对实际配置，不重做场景或首发装饰。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
只读核查1073741825：22101bytes，11个默认/关卡实体，已有自定义镜头但未fixedView（yaw -180..180，pitch -89..89）；阵营1/2/3互相敌对。已有存档必须复用，不重复搭建。需查出生/复苏点和1到1玩家配置，补最小配置到副本并核验导入；不能据存在存档直接勾原AC。见docs/MILESTONES.md。

本轮实际scene_batch仅写副本，镜头yaw0/pitch55、单人1–1及仅1/3敌对已回读；原存档hash不变。复苏点仍空，出生点未证实；完整UI导出受60子控件限制失败，未导入，不勾选AC。证据docs/evidence/milestone-platform-audit.json。
<!-- SECTION:NOTES:END -->
