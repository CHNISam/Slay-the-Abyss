---
id: TASK-59.2
title: 从菜单选择四职业并完成战斗中的选牌
status: Done
assignee:
  - Furinya
created_date: '2026-10-25 08:14'
updated_date: '2026-10-26 12:56'
labels:
  - required
  - sts1
  - builds
milestone: m-4
dependencies: []
references:
  - docs/BACKLOG-AUDIT-20261026.md
  - docs/testing/CLASS_CHOICES.md
documentation:
  - docs/testing/CLASS_CHOICES.md
parent_task_id: TASK-59
priority: high
type: feature
ordinal: 101000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
让四职业可以通过界面开始新局，卡牌显示准确；弃牌、占卜、消耗和置顶选择能够确认并继续结算。实验版本与默认发布版本分别验证。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 四职业选择使用各自真实初始牌组、生命与遗物，取消选择不创建新局。
- [x] #2 新牌基础和升级文案、费用与实时伤害完整，首次战斗和卡组页正常显示。
- [x] #3 弃牌、占卜、消耗和置顶选择正确提交，旧触摸与重复确认不会操作新牌或新战斗。
- [x] #4 离线控制器与布局证据和平台实机证据分开记录，保留实际未通过项目。
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
独立子执行者核对固定来源并实现模块，主执行者负责共享核心与界面集成；定向验证后串行完整回归。用户已授权本轮隔离开发暂免认领，保持全局暂停，不提交推送合入。

按实际职业菜单、真实控件选择及全Profile文案回归逐项收口；原生正式入口/平台验收继续留59与47。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
2026-10-25 四职业构筑与界面冻结检查点 /workspace/sts-ui，feat/experimental-class-ui，基线877c4af。完整 npm run check exit0：JS1349/no skips、Lua247顶层全部执行、Python22；73个源/测试hash复核未变。包含毒流、Focus/Bias/球位、占卜队列、战士七牌、Accuracy、Mantra、职业菜单与mandatory choices及故障回归。独立review修复SharpHide致死使用牌处置、Devotion构造计数时点；旧失败/中断日志保留。当前92/300职业牌，208缺失；完整账本docs/rules/CLASS_CARD_COVERAGE.md，集成边界docs/rules/ARCHETYPE_INTEGRATION.md。原生参数注册/平台/实机未验。后续 /workspace/sts-builds 正接腐化消耗、弃牌减费、Loop/Electro与保留成长，不计入此冻结check。保持全局paused，沿用用户本轮隔离开发豁免；未提交/推送/合入。

2026-10-26本轮game_ui_classes、game_ui_classes_failure、game_ui_class_choices10组、choice_ui19组及character_presentation16组/640变体通过。文案首次30秒超时原样保留，原预算复跑22.031秒通过。显式实验菜单与普通native入口有区别，未认证后者或实机；父任务59/47承接正式范围与自然通关。
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
四职业实验菜单与战斗选牌的本地控制器/呈现切片完成，真实菜单、10+19选择用例及16组/640变体复验通过；正式平台与完整300牌仍由59/47验收。
<!-- SECTION:FINAL_SUMMARY:END -->
