---
id: TASK-4.7
title: 显示已获得遗物和卡牌升级来源
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
ordinal: 123000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
手机试玩发现看不到完整持有遗物，升级来源不清；源码显示顶栏仅数量，用户该局升级来源未确认。PC实际展示和交互待核实。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 可查看完整持有遗物及其说明，卡牌升级来源可追溯。
- [ ] #2 同候选电脑和手机实测并留证。
- [ ] #3 战斗、地图、营地与宝箱均可用触屏查看本局全部已持有遗物的中文名、效果及适用的次数/已耗尽状态。
- [ ] #4 取得遗物或事件导致永久升级时，显示真实来源与被升级的具体牌；临时战斗升级、永久升级和获得已升级牌能分辨。
- [ ] #5 记录取得遗物与休息前后的卡牌UID及升级状态；无相关效果的休息不升级已有牌，战纹和磨刀石只在真实取得时按各自类型升级一次。
- [ ] #6 查看、分页、关闭只读详情不触发领取、升级、出牌或选路；关闭后立即恢复底层交互，同候选手机实测通过。
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
2026-10-29 完整验收承接PR304原四项及附件§5–6；用户该局升级来源仍未知，不能猜测已拿战纹或将受控休息阴性对照当作用户异常已关闭。保留既有电脑和手机同候选验收，新增明确的身份、来源和只读安全要求均未勾，不表示已实现。

PR323原39dab5e9历史实施记录承接（不认证本组合，当前公开范围以docs/SCOPE.md仅岩旅行者两幕为准）：
完整持有列表入口已实现，42件含重复分页/正文/关闭/重开/旧endTurn跨弹窗拒绝两场景通过；父线程独立复验通过并经只读审查。升级来源追踪、缺定义文案和实体PC/手机仍未验，原AC不勾。

合流双方完整metadata、AC、计划和实施notes见docs/evidence/backlog-merge-20261029.json；当前角色范围按旅行者单角两幕，雷电未来任务原81因上游重号经原生doctor改为TASK-85。所有原已勾AC不改，未验不勾。
<!-- SECTION:NOTES:END -->
