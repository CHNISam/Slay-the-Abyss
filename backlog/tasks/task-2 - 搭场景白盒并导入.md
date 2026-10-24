---
id: TASK-2
title: M1 复用基础场景并补齐镜头/出生/阵营配置
status: In Progress
assignee: []
created_date: '2026-10-22 13:32'
updated_date: '2026-10-24 02:15'
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
M1复用现有基础场景与安全副本，核验卡牌战斗所需的固定镜头、出生/复苏和阵营配置；不重搭场景或把成品美术作为基础战斗阻塞。M4首发岩系场景由TASK-2.1验收。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 复用现有基础存档生成安全候选副本，基础场景及必要配置官方导入后可读回；不要求为M1重新制作舞台或批量美术。
- [ ] #2 镜头fixedView锁定、出生点与复苏点已设并有真实复苏证据、玩家数1到1。
- [ ] #3 阵营仅玩家与敌人敌对，己方单位不打自家物件；同候选实机核对并保留SHA/hash、配置读回、截图与本轮日志。
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. 复用1073741825与既有场景导入记录。2. 在副本补锁镜头、出生/复苏点、单人及阵营最小缺口。3. 导入副本核对实际配置，不重做场景或首发装饰。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
只读核查1073741825：22101bytes，11个默认/关卡实体，已有自定义镜头但未fixedView（yaw -180..180，pitch -89..89）；阵营1/2/3互相敌对。已有存档必须复用，不重复搭建。需查出生/复苏点和1到1玩家配置，补最小配置到副本并核验导入；不能据存在存档直接勾原AC。见docs/MILESTONES.md。

本轮实际scene_batch仅写副本，镜头yaw0/pitch55、单人1–1及仅1/3敌对已回读；原存档hash不变。复苏点仍空，出生点未证实；完整UI导出受60子控件限制失败，未导入，不勾选AC。证据docs/evidence/milestone-platform-audit.json。

2026-10-23 M1统一候选第一版bbc6b09已从scene-safe v2重建，独立15项断言证明fixedView/出生复苏/1–1/阵营与11实体graph mounts保留，输入hash不变。但同源审计发现底图两份旧AI模块，首版不交付；正在修正后重建。场景正确仅副本离线层，官方导入/安全复苏与镜头实机未验，不勾AC。

2026-10-24固定5165候选官方导入save1838后独立配置复读：fixedView yaw0/pitch55、spawn与respawn均preset1073741825、单人1到1、仅1与3互敌、全部11实体图挂载与安全底图一致；见docs/evidence/m1-live-5165a78/import-readback.json。2D完整战斗实际成功不等于物理出生落地/真实复苏已验，该任务仍保留InProgress。
<!-- SECTION:NOTES:END -->
