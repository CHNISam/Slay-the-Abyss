---
id: TASK-59.3.1
title: 修复比赛选角页主视觉小头像和牌组信息呈现
status: In Progress
assignee:
  - Furinya
created_date: '2026-10-30 21:58'
updated_date: '2026-10-30 22:19'
labels:
  - playtest-20261030
  - p1
  - grok
milestone: m-4
dependencies: []
references:
  - docs/backlog-details/PLAYTEST-20261030.md
  - docs/backlog-details/MOBILE-QA-20261029.md
parent_task_id: TASK-59.3
priority: medium
type: enhancement
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Owner截图：选角页圆形大底叠黑色矩形包裹立绘，底部小头像被截半、缩在大框中且浮在中间，左侧全部/攻击/技能/能力/状态/诅咒筛选按钮堆积。根因涉及素材尺寸/裁剪/布局多方面。无法低成本用原版高清巨幅背景图，允许在性能边界内自主设计；最大程度复用原作成熟的选角信息架构。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 岩系旅行者主视觉、头部小头像与容器关系自然，头像不会悬空或不当裁切。
- [ ] #2 首发角色初始生命、金币、遗物、牌组信息一眼可读，主次符合选角任务；保留 Production 仅旅行者入口。
- [ ] #3 交付可与批准设计/原版交互对照的界面证据，平台约束和自设计取舍如实注明。
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. 以最新develop隔离接续PR389选角成果。2. 用完整身份绑定外层inverse恢复旧源码，保持历史门禁。3. 定向验证并交独立复审，实机保持未验。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
接续PR389原选角改动，补充完整身份外层inverse，旧历史fixture与hash不变；完整文件/漂移负例通过，选角/头像/比赛入口组合定向验证进行中。尚无官方导入或实机验收。
<!-- SECTION:NOTES:END -->
