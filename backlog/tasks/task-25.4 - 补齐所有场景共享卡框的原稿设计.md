---
id: TASK-25.4
title: 补齐所有场景共享卡框的原稿设计
status: In Progress
assignee:
  - '@codex'
created_date: '2026-10-28 09:39'
updated_date: '2026-10-28 10:12'
labels: []
milestone: m-5
dependencies: []
references:
  - docs/design/CARD_FACE_PARITY.md
parent_task_id: TASK-25
ordinal: 121000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
按Card与CardText批准稿还原共享卡面，覆盖手牌、牌库、奖励、商店与锻造；不制作插画、不改规则。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 五类场景使用完整共享卡框与动态费用反馈
- [ ] #2 原生方案有能力证据和1倍对照预览
- [ ] #3 布局运行时回归通过，平台未验证范围明确记录
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
核对原稿与原生图库；共享装配与皮肤绑定；各场景复用；生成预览并运行回归；提交PR。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
共享原生装配与三个运行时宿主已接入；原生图片几何、材质高光、角色徽记、类型标签、费用环反馈及状态复用均有离线证据。用户本轮选择自行导入，待独立候选和用户本轮实机证据；任务保持In Progress，不宣称平台UI通过。未使用OpenCode，额度节省未知。
<!-- SECTION:NOTES:END -->
