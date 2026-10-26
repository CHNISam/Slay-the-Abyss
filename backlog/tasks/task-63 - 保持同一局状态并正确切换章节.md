---
id: TASK-63
title: 保持同一局状态并正确切换章节
status: In Progress
assignee:
  - '@Furinya'
created_date: '2026-10-26 05:05'
updated_date: '2026-10-26 05:57'
labels: []
milestone: m-4
dependencies:
  - TASK-12.4
  - TASK-14
references:
  - docs/rules/CROSS_ACT.md
  - docs/evidence/m3-cross-act-20261026.json
priority: high
type: feature
ordinal: 108000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
第一幕现有终点直接结算整局，事件/遗物资格也固定第一幕。为用户已纳入M3的第二至第四幕复用现有核心，建立同一局的章节、全局楼层与资源迁移。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 三幕随机地图与终幕固定地图使用正确楼层和独立种子，第一幕回归保持
- [ ] #2 换幕保留卡牌身份和库存、执行原版治疗与随机流推进，拒绝重复及非法换幕且不改状态
- [ ] #3 普通、神龛及一次性事件在章节间按原版资格重置或保留
- [ ] #4 Boss宝箱与普通结局、三钥匙门和真结局各走合法路径
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
先参数化章节地图和随机流；通过同一事务接入Nodes换幕，再补钥匙与内容清单。保持未实现章节未开放，逐项记录真实缺口。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
2026-10-26本轮离线切片已实现四幕楼层/地图、换幕库存与UID、cardRng开区间真实推进、连续monsterRng遭遇/Boss队列、事件池生命周期和结局/门边界。14连续向量/11计数向量及终幕各三槽固定队列和首幕独立向量通过；seed10首强两前重复例外已按源修复。初跑1470JS有1项环境缺pwsh；398Lua全执行后11失败文件按两个根因修复，13文件定向恢复通过；不冒充最终全量全绿。无同SHA远端CI、正式Host章节UI、完整章节内容或平台证据，保持In Progress且不勾AC。详细源码指纹与原失败/恢复见docs/evidence/m3-cross-act-20261026.json。
<!-- SECTION:NOTES:END -->
