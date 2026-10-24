---
id: TASK-10.7
title: 卡牌显示准确伤害，不再把不同目标合成范围
status: Done
assignee:
  - '@Codex'
created_date: '2026-10-24 04:23'
updated_date: '2026-10-24 06:39'
labels: []
milestone: m-2
dependencies: []
documentation:
  - docs/backlog-details/TASK-10.7.md
parent_task_id: TASK-10
priority: high
type: bug
ordinal: 81000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
用户实机发现普通攻击显示4～6点伤害。按原版区分未选目标与瞄准目标的确定数值，并检查整数资源。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 未指定目标和瞄准目标均显示原版对应的确定值，不合并成范围。
- [x] #2 单体、多段、群攻、格挡、费用和意图核对通过；不改变结算和随机状态。
- [x] #3 原问题先复现再通过，包含本轮实机复验和可核验的测试副本。
- [x] #4 整数资源按整数显示，拒绝隐藏实际小数错误。
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
先固定原版来源和复现，再修数值及同类显示，完整检查后合并；实机证据单独保留。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
本地修复与回归已实施，完整检查进行中；新副本实机复验尚未完成，详见技术附件。

2026-10-24预览专项夹具14阶段离线通过：未瞄准4/易伤目标6、双击5×2、群攻基础6及实际6/9、格挡/费用/整数资源和拒绝非法小数；核心副本结算oracle及唯一一次正常Strike一致。统一诊断副本hash01dd3927…已编译写副本，尚未官方导入/实机复验，保留AC。

2026-10-24官方1841/01dd副本run ced168e4完成14阶段原生画面和837条新日志独立复核：未瞄准4、瞄准易伤6、取消4、双击5x2、群攻显示6且逐目标6/9、格挡5、费用1/1/1/1/2、资源整数可读。核心状态/RNG只读断言通过；预览段只有t647一次正常Strike，t648伤害6，能量3到2/手牌5到4/敌HP44到38。非法小数拒绝与原版失败证据保留于证据包regressions，不伪称本轮运行旧客户端。逐图hash及唯一出牌审计见docs/evidence/m1-live-20261024/reviews/preview-live-review.json。
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
原问题已先红后绿；01dd官方测试副本14阶段实机复验确定数值、整数资源、真实结算和预览只读通过。原始新gia及精选图可核验；不代替全UI门禁。
<!-- SECTION:FINAL_SUMMARY:END -->
