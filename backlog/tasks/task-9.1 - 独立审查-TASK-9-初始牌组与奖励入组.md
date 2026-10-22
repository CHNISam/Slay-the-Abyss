---
id: TASK-9.1
title: 独立审查 TASK-9 初始牌组与奖励入组
status: To Do
assignee:
  - Furinya
created_date: '2026-10-22 15:36'
labels: []
dependencies: []
parent_task_id: TASK-9
ordinal: 25000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
由未参与abyss_run实现的Agent审查出牌后奖励事务，避免重复领取、空奖励或牌组未实际更新。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 真实初始牌组完成战斗，奖励选择/跳过/错误与重放路径独立验证
- [ ] #2 核对奖励、金币、生命和随机种子事务边界，报告并复验阻断问题
<!-- AC:END -->
