---
id: TASK-14.1
title: 核对遗物和药水的实际效果
status: In Progress
assignee:
  - '@Codex'
created_date: '2026-10-23 01:57'
updated_date: '2026-10-24 20:35'
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

2026-10-24 用户确认原神已开并授权任意必要验收：从develop31a8f37固定源构建新副本并独立读回；确认窗口/同级权限，clientScriptLog=true导入新存档，取本轮ready/日志/截图。正常资源下验证战后发瓶、跨节点用瓶、丢弃后换瓶与资源账本；明确自动命令驱动和物理UI输入的证据边界，不外推全件实玩或M3整体通过。

2026-10-25 用户批准完整原版内容池：分别固定Ironclad A0第一幕遗物和药水完整来源/顺序/消费目录、实际可达渠道与机制依赖，再按效果钩子分组补齐。13遗物/6可获药水只是历史基线，不能通过受限桶或缺项重抽保持自报概率；跨色等合法依赖必须明确，不静默删池。目录、实现、平台与自然实玩仍分层验收。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
2026-10-24 M3当前清单复核：13遗物/7药水定义、27份固定镜像blob及限制见docs/reviews/TASK-14.1-m3-inventory-audit.md与source-identity.json。未重复改固定槽/开战顺序/已修力量上限。补原版主动丢弃：Run命令4红→4绿，三槽选择确认接通活动局顶栏，奖励/商店满槽可丢旧瓶后原槽领取/购买，保留短按用药。UI9绿含run/phase/换瓶/同ID真实补回/resize/关闭重开/终局旧确认和用药手势，旧指针问题先红后换背包身份修绿。6种自然战后瓶用原始牌组实际击败Cultist后领取、跨map相位下一战生效6绿。既有专项及JS host/layout13全过，独立子代理复审UI9+布局2通过。没有平台构建/导入/实机，Boss3件终局后无自然后续触发、Poison无战士自然入口、正版来源认证和完整队列仍保留，四项全量AC不勾。

2026-10-24 固定31a8f37新候选官方导入1845，47模块/2298控件读回一致。正常114金币商店购火瓶50→64，三槽确认丢弃不扣费，再购同ID火瓶50→14；携至第3层使用，12血赤甲虫死亡、另敌15/15、能量3/3、库存1→0，空槽重按不变。新27号日志106打印含本轮ready、药水命中12/致死、ABYSS_SETTLEMENT_DEFEAT；真实离开后落盘。首战与开局有人协助，不归因全自动输入；20点基础伤害在12血目标截断，本轮不认证精确20。满槽替换/余下瓶/全件触发和全UI门禁仍缺，AC不勾。官方图严格字段审计失败保留（布局/省略默认值），未放宽审计。证据见docs/M3-LIVE-INVENTORY-20261024.md及docs/evidence/m3-live-31a8f37/receipt.json。

2026-10-25 五瓶Swift/Weak/Fear/Ancient/LiquidBronze真实Run库存效果已实现，12组Lua/3项JS及相关门禁通过。五瓶暂acquisitionPending并列明清单排除，两个旧selector保原6瓶获取轨迹；不能把此隔离误当原版概率。完整33统一接入时必须移除此排除，不跳过unsupported。SacredBark/onUsePotion等依赖保留。见docs/reviews/TASK-14.1-potion-basic-five.md。
<!-- SECTION:NOTES:END -->
