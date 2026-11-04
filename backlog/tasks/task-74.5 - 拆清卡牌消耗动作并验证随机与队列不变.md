---
id: TASK-74.5
title: 拆清卡牌消耗动作并验证随机与队列不变
status: Done
assignee:
  - Furinya
created_date: '2026-10-29 12:33'
updated_date: '2026-11-04 20:29'
labels: []
milestone: m-7
dependencies: []
references:
  - docs/plans/2026-11-03-m9-engineering-foundation.md
documentation:
  - docs/backlog-details/TASK-74.5.md
  - docs/evidence/m7-task745-current-audit-20261105.json
parent_task_id: TASK-74
priority: medium
ordinal: 128000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
卡牌动作曾混合消耗、选择校验与提交；第一次消耗切片后仍有四个选择热点。两片已合入，但原任务和附件未同步收口，本轮按当前a308的独立差分、真实变异与严格交付重新验收。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 五种消耗动作旧新差分与真实变异测试通过
- [x] #2 公开入口及辅助函数整体复杂度和依赖变化
- [x] #3 现有工程门禁及相关回归通过且当前PR门禁全绿
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. 保留第一次五消耗118→102历史，补齐已合入的20项选择职责及整体指标。2. 以当前a308完整模块重做三套边界差分、真实变异和独立审查，明确旧490基线与实际合并父不同。3. 关联当前严格源码、原生组合及合后验收后收口，不扩大为父74、M7性能或设备完成。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
D本地最小实现：五种消耗动作由四个同文件helper承接；入口118降至102，helpers为5/3/6/2，之和仍118，整体热点未治理完成。完整旧源固定hash的独立Fengari对照有169条入队/动作边界轨迹一致；五个真实语义变异均由行为断言杀死。固定Node24相关9个Lua入口及31项JS工具/动作回归通过，原M1-M4全部killed_by_assertion；静态37条、依赖1441和SCC76/496不变。当前按总控要求未push，远端Full与独立审查待。

完整方案、真实指标与限制已记录docs/backlog-details/TASK-74.5.md，机器证据docs/evidence/core-exhaust-20261029.json。原生UI合同首次缺独立树生成模块，补原生成步骤后4项全过；JS语法通过。当前只完成本地切片，当前PR Full与独立审查仍待。

新鲜独立审计确认当前apply5、选择6/12/2/10，除drain25外其他函数最高13；六VM的76/39/169边界与冻结hash相同，现有8变异及新增token错误均拒绝。原490审查969a与实际父5129不同，已显式记录，由本轮a308新审承接；AC3仍等当前整合最终收口。

当前a308新鲜独立深审、六VM差分/新增token真实负控与PR513严格完整交付已终验；合后41900003124及原验证器merged_passed在共同交付附件。旧490基线差异明确保留，不伪造旧严格收据。
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
已合五消耗与选择职责在当前a308重新独审，76/39/169边界逐字同源，九个真实语义变异及完整交付通过；drain25和父74残余明确保留。
<!-- SECTION:FINAL_SUMMARY:END -->
