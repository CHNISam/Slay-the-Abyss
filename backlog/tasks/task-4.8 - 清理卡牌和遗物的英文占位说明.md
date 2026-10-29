---
id: TASK-4.8
title: 清理卡牌和遗物的英文占位说明
status: To Do
assignee:
  - '@Furinya'
created_date: '2026-10-28 14:39'
updated_date: '2026-10-29 04:17'
labels: []
milestone: m-4
dependencies: []
references:
  - 'https://github.com/CHNISam/Slay-the-Abyss/pull/304'
  - docs/backlog-details/MOBILE-QA-20261028.md
  - docs/evidence/backlog-merge-20261029.json
  - docs/backlog-details/TRAVELER-SCOPE-20261029.md
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

PR323原39dab5e9历史实施记录承接（不认证本组合，当前公开范围以docs/SCOPE.md仅岩旅行者两幕为准）：
剑势如虹基本/升级文案改准确中文，并在五种strikeTag牌的基本/升级说明标注打击类牌；178变体卡面与11项Python呈现通过（1项环境symlink跳过）。新增7遗物均有中文说明，余缺项和同候选实机仍待验。

合流双方完整metadata、AC、计划和实施notes见docs/evidence/backlog-merge-20261029.json；当前角色范围按旅行者单角两幕，雷电未来任务原81因上游重号经原生doctor改为TASK-85。所有原已勾AC不改，未验不勾。
<!-- SECTION:NOTES:END -->
