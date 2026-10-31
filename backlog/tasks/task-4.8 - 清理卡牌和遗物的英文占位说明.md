---
id: TASK-4.8
title: 清理卡牌和遗物的英文占位说明
status: In Progress
assignee:
  - '@Furinya'
created_date: '2026-10-28 14:39'
updated_date: '2026-10-31 17:03'
labels: []
milestone: m-4
dependencies: []
references:
  - 'https://github.com/CHNISam/Slay-the-Abyss/pull/304'
  - docs/backlog-details/MOBILE-QA-20261028.md
  - docs/evidence/backlog-merge-20261029.json
  - docs/backlog-details/TRAVELER-SCOPE-20261029.md
  - docs/backlog-details/MOBILE-QA-20261029.md
  - docs/backlog-details/MOBILE-QA-20261029-SOURCES.md
  - docs/evidence/m3-visual-20261031/README.md
  - docs/evidence/m3-completion-20261031/
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
- [x] #1 比赛内容的卡牌与遗物说明使用准确中文，无英文占位。
- [ ] #2 游戏内核对并保留同候选证据。
- [x] #3 普通卡正文仅保留必要效果，打击类等身份以可发现关键词解释承接，规则标签及剑势如虹计数不变；移除常驻选敌长提示和菜单/退出弹层操作说明入口。
- [ ] #4 退出文案清晰说明本局进度无法恢复并保留取消/确认；创作者权限不是玩家等级，点赞文案不承诺未经验证的升级或存档解锁因果。
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
2026-10-31 M3整批收口：逐项核运行态中文与真实详情关键词，保留标签计数，分别记录客户端呈现及文案决定。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
2026-10-29 完整中文与规则合同承接附件§6：剑势如虹基本/升级均解释可识别的打击类标签，不能按中文名字匹配或只统计普通攻击；仅手牌/抽牌/弃牌计数，基本每张加2、升级加3、消耗堆排除。战斗、奖励、卡组、商店及遗物详情逐屏核验可达内容；翻译名称不等于TASK-14.1真实效果交付。

PR323原39dab5e9历史实施记录承接（不认证本组合，当前公开范围以docs/SCOPE.md仅岩旅行者两幕为准）：
剑势如虹基本/升级文案改准确中文，并在五种strikeTag牌的基本/升级说明标注打击类牌；178变体卡面与11项Python呈现通过（1项环境symlink跳过）。新增7遗物均有中文说明，余缺项和同候选实机仍待验。

合流双方完整metadata、AC、计划和实施notes见docs/evidence/backlog-merge-20261029.json；当前角色范围按旅行者单角两幕，雷电未来任务原81因上游重号经原生doctor改为TASK-85。所有原已勾AC不改，未验不勾。

PR327手机反馈来源增量（基于20a74da的历史观察；不认证6795160组合或新候选）：
2026-10-29录音06:21/06:48/18:12/32:49要求去冗余提示与游戏内操作说明干扰。保留真正玩法关键词与退出风险；STRIKE原版标签存在，但本轮没有对应中文语言包，不能声称原版逐字文案。创作者Lv4公告可核，当前点赞到等级公式未核，不写点赞必然解锁存档；详见SOURCES核验表。

2026-10-31 M3最终事实核对：AC1/3：标准m3-chinese-copy最终1/1及combined-acceptance.log中文项通过，遍历比赛牌/旅行者模板/遗物/状态运行说明；实际详情关键词可发现，strikeTag及剑势如虹计数不变，菜单/退出help隐藏且旧入口拒绝。chemical_x原raw名称合法变量X导致夹具误报，现精确检查Names.get玩家显示名“化学物质零号”，未放宽ASCII规则。#2同候选官方游戏内逐屏证据仍缺；#4退出不可恢复/取消确认已有，但Owner较新TASK-4.17“帮助作者提升等级”要求与旧点赞措辞需按实际平台因果单独核验，不伪勾。
<!-- SECTION:NOTES:END -->
