---
id: TASK-4.8
title: 清理卡牌和遗物的英文占位说明
status: To Do
assignee:
  - '@Furinya'
created_date: '2026-10-28 14:39'
updated_date: '2026-10-29 00:13'
labels: []
milestone: m-4
dependencies: []
references:
  - 'https://github.com/CHNISam/Slay-the-Abyss/pull/304'
  - docs/backlog-details/MOBILE-QA-20261028.md
parent_task_id: TASK-4
priority: medium
ordinal: 124000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
手机试玩发现卡牌与遗物英文占位；源码确认部分文本及回退。PC具体展示待验，规则与本地化问题分开记录。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 比赛内容的卡牌与遗物说明使用准确中文，无英文占位。
- [ ] #2 游戏内核对并保留同候选证据。
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
2026-10-29 完整中文与规则合同承接附件§6：剑势如虹基本/升级均解释可识别的打击类标签，不能按中文名字匹配或只统计普通攻击；仅手牌/抽牌/弃牌计数，基本每张加2、升级加3、消耗堆排除。战斗、奖励、卡组、商店及遗物详情逐屏核验可达内容；翻译名称不等于TASK-14.1真实效果交付。
<!-- SECTION:NOTES:END -->
