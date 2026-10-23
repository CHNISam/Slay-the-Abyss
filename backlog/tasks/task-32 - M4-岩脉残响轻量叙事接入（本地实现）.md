---
id: TASK-32
title: M4 岩脉残响轻量叙事接入（本地实现）
status: Done
assignee:
  - '@codex'
created_date: '2026-10-23 03:27'
updated_date: '2026-10-23 03:35'
labels:
  - narrative
  - presentation
milestone: m-5
dependencies: []
priority: low
ordinal: 38000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
用户批准素材包的低成本接入：补足荧进入遗迹、守卫身份及胜败句号。独立本地切片，不改规则、数值、地图和事件动作，不阻塞M1；平台和实机沿用既有P0/UI任务追踪。已查世界观、剧情、叙事及TASK-4/18/24，无同范围任务。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 开场、Boss和胜败显示素材包短文案，完整保留批准长版，叙事不写死层数
- [x] #2 节点文案匹配实际事件，保留操作说明、统计、重开和正式结算行为
- [x] #3 本地构建和主流程回归通过，记录文本容量证据及平台导入和实机缺口
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1.沿用presentation构建链及summary/notice。2.接入短版开场Boss胜败及匹配节点文案。3.回归交互结算并验证布局容量，记录分层证据。4.独立PR通过当前SHA CI与审查后集成。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
2026-10-23 codex：在独立worktree rock-vein-lore，从最新8cedaaf基线接入。菜单/guardian入场/胜败和营地商店宝箱、cleric/purifier风味复用summary/notice；未改控件、主题及任何核心规则。游戏文案JSON原样保留，9份源文件SHA256与包MANIFEST一致。初次新增开场断言在实现前失败，接入后game UI 10项及node UI 17项通过；完整npm run check复验退出0。JS260通过/14符号链接权限跳过；Python15通过/1权限跳过；Lua全部通过。保守容量菜单4行160/280，结果含错误6行240/280，Boss及节点各40高，不缩字号。代码简化与规则隔离自审无待修问题。详见docs/lore/README.md，实际本地输出可由tests/game-ui.test.mjs生成build/lore-preview.json。平台构建/导入/实机及候选专属verify:ui均未执行，沿用现有P0/UI任务，不标为平台通过。
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
本地叙事实现与验收完成：素材原样保留，开场/Boss/胜败及四类非战斗节点复用现有文本位，规则和控件不变。8cedaaf基线npm run check退出0：JS260通过14权限跳过，Lua23组通过，Python15通过1权限跳过；实际控制器输出及保守容量回归通过。集成走本轮独立PR，当前SHA CI继续核对。仅本地切片Done，平台构建/导入、原生字体裁切、真实试玩和verify:ui未执行，详见docs/lore/README.md，沿用现有P0/UI关口。
<!-- SECTION:FINAL_SUMMARY:END -->
