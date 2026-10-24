---
id: TASK-52
title: 让战后药水单独领取并说明来源
status: In Progress
assignee:
  - '@Codex'
created_date: '2026-10-24 12:45'
updated_date: '2026-10-24 13:24'
labels:
  - required ui rule-parity
milestone: m-4
dependencies: []
references:
  - docs/backlog-details/TASK-52.md
priority: high
type: bug
ordinal: 87000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
玩家打完整局才发现药水槽已满，选牌和跳过卡牌会在没有独立操作时收下药水。战后应看清每瓶药水的名称、效果和数量，并自行决定领取、放弃或离开。技术依据和验证记录见对应附件。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 选择或跳过卡牌不会领取或吞掉药水。
- [ ] #2 药水奖励显示名称、效果和数量，满槽时说明可丢弃旧药水再领取。
- [ ] #3 领取、放弃和离开相互独立，重复或过期输入不能消费奖励。
- [ ] #4 原版获取规则有固定来源，未认证的随机链和平台验证明确保留。
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. 固定原版来源并复现选牌自动收药。2. 先增加真实Run和生成UI的红测试。3. 取消动作串联，复用独立领取、放弃、前往地图与满槽丢弃提示。4. 跑奖励、触摸与工程回归，记录完整随机链和平台证据边界。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
本地修复选牌/跳卡自动收药；领取、放弃与前往地图独立。固定原版RewardItem/AbstractRoom/AbstractDungeon/PotionHelper已重读，完整同seed拒绝采样链和Sozu差异保留TASK-13.1。新Run3/UI2与既有药水7/UI3/失金10组通过；宿主地图JS12及safe-area布局1项通过，全Lua正在收集。免费委派因自动审批出境授权拒绝未执行，由Codex接管，未收费回退；节省额度未知。未制作或验证新平台候选，保持进行中。

旧领奖夹具迁移收尾：只在有效选牌后显式处理独立药水并离开奖励，保留原规则/数值/原子性/旧触摸断言。上一轮169文件中27个失败fixture已逐项定向修复并取得通过证据（首轮迁移26绿，另1个无失金页纯重绘手势回归已定位并修复）；相邻9个奖励归属/held/released/独立领取fixture全绿，宿主/地图/奖励布局JS13项全绿。未重启169文件全套、未放宽超时；CI与实机仍由集成线程统一验证。详情和日志哈希见TASK-52附件及结构化证据。

补充检查：validate:data与check:syntax均通过；语法检查首次在受限沙箱因Node子进程EPERM退出，以允许子进程的宿主权限运行同命令后通过。无平台导入、实机或verify:ui证据，保持In Progress，交集成线程统一验收。
<!-- SECTION:NOTES:END -->
