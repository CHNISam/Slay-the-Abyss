---
id: TASK-2.1
title: 首发岩系遗迹场景制作（原生资产小样通过后）
status: To Do
assignee:
  - '@art-scene'
created_date: '2026-10-22 16:37'
updated_date: '2026-10-22 16:42'
labels:
  - art
  - launch
dependencies:
  - TASK-10.1
references:
  - docs/art/scene-spike/README.md
parent_task_id: TASK-2
type: task
ordinal: 32000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
复用PR25现成官方原生模型方案；当前仅完成7/1件GIA离线构建与读回。无额外框架；发布由人完成。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 原生单建筑和7件景片先完成官方副本导入、GUID读回、固定镜头真机显示和性能检查
- [ ] #2 首发场景按验证过的官方模型与预算制作，角色轮廓/出生/脚高/碰撞/安全区合格，不将二维GIA当3D建筑
- [ ] #3 独立feat分支与PR，逐包导入去重并留截图；主Agent集成质量检查且不覆盖原始存档
<!-- AC:END -->
