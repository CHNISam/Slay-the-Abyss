---
id: TASK-25.4
title: 补齐所有场景共享卡框的原稿设计
status: In Progress
assignee:
  - Furinya
created_date: '2026-10-28 09:39'
updated_date: '2026-11-02 02:25'
labels: []
milestone: m-5
dependencies: []
references:
  - docs/design/CARD_FACE_PARITY.md
parent_task_id: TASK-25
priority: medium
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

2026-11-02 条件依赖：新增共享卡框视觉改稿条件依赖 TASK-4.22 的工具实证、独立视觉 >=9 分与用户认可；不重置已有共享实现、AC 或批准稿，不阻断现有复用/裁切/可读性缺陷修复及原生回归。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
共享原生装配与三个运行时宿主已接入；原生图片几何、材质高光、角色徽记、类型标签、费用环反馈及状态复用均有离线证据。用户本轮选择自行导入，待独立候选和用户本轮实机证据；任务保持In Progress，不宣称平台UI通过。未使用OpenCode，额度节省未知。

2026-10-28排期复核：共享卡框是前两幕M4必做品质项，补齐Medium优先级并列入M4排期；原生能力、同候选及设备实测缺口保留，状态和未勾验收不变。负责人按项目约定统一Furinya。
<!-- SECTION:NOTES:END -->
