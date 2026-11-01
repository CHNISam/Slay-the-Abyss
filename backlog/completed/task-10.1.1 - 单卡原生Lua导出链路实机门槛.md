---
id: TASK-10.1.1
title: 单卡原生Lua导出链路实机门槛
status: Done
assignee:
  - '@codex'
created_date: '2026-10-22 21:45'
updated_date: '2026-10-22 21:45'
labels:
  - art
  - verified-route
dependencies: []
references:
  - docs/art/CARD_PRODUCTION.md
  - docs/art/evidence/2026-10-23.json
parent_task_id: TASK-10.1
type: spike
ordinal: 34000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
将已通过的电脑单卡路线单独记录，避免卡框制作继续等待尚未验证的肖像和场景；不将本次单卡测量外推为完整UI或目标设备容量。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 固定上游版本、JSON/Lua源、真实模板绑定与高度40兼容参数，保留原稿对照和可重复准备命令
- [x] #2 用户官方试玩截图确认标题/类型/费用/图形/说明完整显示，点击后原生文字变为点击通过
- [x] #3 记录10秒客户端dt均值33.3ms和P95 34.0ms，明确非GPU耗时、无基线/十卡/手机/主机验证；证据哈希可追溯
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
汇总v2导出与静态/VM结果、用户两张实机截图，冻结只覆盖电脑单卡的规范；其余路线与容量继续留在父Spike验收。
<!-- SECTION:PLAN:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
用户v2截图SHA03a3e362.../1fdaba4d...证实完整单卡显示与点击更新；本地导出/3项差异回归/Fengari及副本静态检查通过。客户端10秒dt均值33.3/P95 34.0ms；无基线/多卡/多设备容量结论。规范CARD_PRODUCTION.md。
<!-- SECTION:FINAL_SUMMARY:END -->
