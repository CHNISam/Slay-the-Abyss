---
id: TASK-15.19
title: 让双甲虫与三甲虫遭遇按原版随机配色
status: Done
assignee:
  - '@Furinya'
created_date: '2026-10-25 12:29'
updated_date: '2026-10-27 04:15'
due_date: '2026-10-28'
labels: []
milestone: m-4
dependencies: []
references:
  - docs/backlog-details/TASK-15.md
  - docs/reviews/TASK-15.19-louse-color-sampling.md
  - docs/BACKLOG-AUDIT-20261026.md
parent_task_id: TASK-15
priority: medium
type: bug
ordinal: 95000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
旧分支的双甲虫固定赤青、三甲虫固定赤青赤，显式遭遇应与正式编组一样逐只抽取红绿颜色；保留甲虫数值与招式。统一集成保留当前正式formation与随机流，只补显式兼容入口。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 每槽独立选择赤或青，双甲虫覆盖四种、三甲虫覆盖八种有序组合。
- [x] #2 正式地图与未知房保留现有formation规则，显式开战采用同样颜色选择，不重复消费随机流。
- [x] #3 开战失败保留原地图、随机状态和引用；重试稳定，其他遭遇与抽牌流程不变。
- [x] #4 独立来源、入口、清单与失败回滚通过组合检查；当前CI与平台实测证据分别记录。
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
复核已有正式编组与旧候选差异；显式入口补逐槽Boolean，保留原生产formation。对接旧独立回归，验证全部12颜色分支、失败回滚和其他遭遇；最终统一CI验组合，平台证据保留缺口。

2026-10-26收口：核对最新合入、既有交付和平台矩阵，复跑相关原回归；开发与整体验收责任明确分层，原失败记录保留。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
原候选862b0a6来自既有在途分支，本轮以CLI迁回本地任务库并保留原编号，未覆盖旧source或实机状态。当前正式编组已有逐槽颜色，禁止再次取随机数。

组合已通过273项：12种有序颜色、24组失败/重试、其他16遭遇全状态；当前七列地图/source队列使用显式检查点，保留正式formation不重复抽色。数据/清单及相邻遭遇、正式编组回归通过。第四项仍等待最终CI与平台边界记录，未把离线当自然实机。

2026-10-26全面复核：PR206已整合，本轮louse_colors52项及126构造向量通过，来源/事务/最终PR213全绿和平台未验边界已分别记录。
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
PR206已整合，本轮louse_colors52项及126构造向量通过，来源/事务/最终PR213全绿和平台未验边界已分别记录。 完整责任与证据见docs/BACKLOG-AUDIT-20261026.md
<!-- SECTION:FINAL_SUMMARY:END -->
