---
id: TASK-14.1
title: 核对遗物和药水的实际效果
status: In Progress
assignee:
  - '@Codex-m3-items'
created_date: '2026-10-23 01:57'
updated_date: '2026-10-24 10:32'
due_date: '2026-10-28'
labels:
  - required
  - rule-parity
milestone: m-4
dependencies:
  - TASK-14
references:
  - data/SOURCES.md
  - data/relics.json
  - data/potions.json
  - docs/backlog-details/TASK-14.1.md
  - docs/reviews/TASK-14.1-m3-inventory-audit.md
parent_task_id: TASK-14
priority: high
type: enhancement
ordinal: 42000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
逐件检查首发遗物和药水：数值是否正确、什么时候触发、用了以后是否真正生效。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 每件道具的效果都有原版依据，没查清的不能当成已通过。
- [ ] #2 数值、对象、持续时间、使用限制和触发顺序符合原版。
- [ ] #3 从正常背包使用和触发，检查叠加、跨房间、战斗胜利和重复使用等情况。
- [ ] #4 保存测试和实际游戏记录，明确哪些只在本地测过、哪些已在游戏里验证。
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
2026-10-24 M3复核：以当前13遗物和7药水清单重新审计来源、效果与正常获取入口；优先补真实库存入口的状态边界和奖励后使用验证。仅当固定来源及红例证明当前差异才改生产代码，不重做已合固定槽或开战顺序。更新专项账本，平台和正版PC证据继续独立保留。

原版PotionPopUp与AbstractPotion.canDiscard明确支持主动丢弃，当前缺入口。追加离线切片：先写Run.discardPotion真实槽位和无效输入原子性红例，再最小新增库存命令；UI接线由主线程随后处理。本树不碰UI。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
2026-10-24 M3当前清单复核：13遗物/7药水定义、27份固定镜像blob及限制见docs/reviews/TASK-14.1-m3-inventory-audit.md与source-identity.json。未重复改固定槽/开战顺序/已修力量上限。补原版主动丢弃：Run命令4红→4绿，三槽选择确认接通活动局顶栏，奖励/商店满槽可丢旧瓶后原槽领取/购买，保留短按用药。UI9绿含run/phase/换瓶/同ID真实补回/resize/关闭重开/终局旧确认和用药手势，旧指针问题先红后换背包身份修绿。6种自然战后瓶用原始牌组实际击败Cultist后领取、跨map相位下一战生效6绿。既有专项及JS host/layout13全过，独立子代理复审UI9+布局2通过。没有平台构建/导入/实机，Boss3件终局后无自然后续触发、Poison无战士自然入口、正版来源认证和完整队列仍保留，四项全量AC不勾。
<!-- SECTION:NOTES:END -->
