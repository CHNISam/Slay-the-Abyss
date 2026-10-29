---
id: TASK-74.5
title: 拆清卡牌消耗动作并验证随机与队列不变
status: In Progress
assignee:
  - Furinya
created_date: '2026-10-29 12:33'
updated_date: '2026-10-29 12:43'
labels: []
dependencies: []
parent_task_id: TASK-74
priority: medium
ordinal: 128000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
卡牌动作入口复杂度仍高，先整理五种消耗动作，保持随机、队列和失败回滚。范围、验证证据与剩余热点见[实施附件](docs/backlog-details/TASK-74.5.md)。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 五种消耗动作旧新差分与真实变异测试通过
- [ ] #2 公开入口及辅助函数整体复杂度和依赖变化
- [ ] #3 现有工程门禁及相关回归通过且当前PR门禁全绿
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
仅在abyss_card_actions同模块提取消耗动作职责；保持RNG、队列、事件、回滚和API；审查整体指标并独立PR，暂不推送避免重复Full。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
D本地最小实现：五种消耗动作由四个同文件helper承接；入口118降至102，helpers为5/3/6/2，之和仍118，整体热点未治理完成。完整旧源固定hash的独立Fengari对照有169条入队/动作边界轨迹一致；五个真实语义变异均由行为断言杀死。固定Node24相关9个Lua入口及31项JS工具/动作回归通过，原M1-M4全部killed_by_assertion；静态37条、依赖1441和SCC76/496不变。当前按总控要求未push，远端Full与独立审查待。

完整方案、真实指标与限制已记录docs/backlog-details/TASK-74.5.md，机器证据docs/evidence/core-exhaust-20261029.json。原生UI合同首次缺独立树生成模块，补原生成步骤后4项全过；JS语法通过。当前只完成本地切片，当前PR Full与独立审查仍待。
<!-- SECTION:NOTES:END -->
