---
id: TASK-57
title: 做好机器人完整卡池与各流派
status: In Progress
assignee:
  - Furinya
created_date: '2026-10-24 02:02'
updated_date: '2026-10-25 11:57'
labels:
  - required
  - sts1
  - builds
milestone: m-4
dependencies: []
references:
  - docs/backlog-details/DRAFT-4.md
priority: high
type: feature
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
2026-10-25用户明确要求初代四职业所有流派均须纳入必做需求，取代旧的可选候选和发布后才决定是否启动的限制。本轮仅登记需求，不启动开发，不承诺10/30前全部交付。旧附件保留为历史，冲突时以本需求为准。以初代《杀戮尖塔》PC A0固定版本为规则基线，逐项记录来源及证据等级；数值、费用、升级、概率、随机消费和结算顺序保持一致，独立实现。完整职业卡池及合法组合为必做范围，构筑示例不是裁剪白名单。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 独立职业选择、初始属性、初始牌组和遗物正确；常规池保持职业独立，合法跨色来源单列验证。
- [ ] #2 完整卡池基本版与升级版均能按原版规则获取和执行；覆盖闪电、冰霜、黑暗、等离子、集中与球位、零费、重编程及混合构筑。
- [ ] #3 每类构筑有自然奖励或商店获取、升级、真实战斗、跨节点继承及已开放章节通关的可重复记录；不能用直接塞牌替代可玩验收。
- [ ] #4 卡牌、遗物、药水和职业机制组合覆盖边界与触发顺序；目录、离线实现、平台导入和实机结果分别记录。
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
本轮用户明确授权隔离开发暂免远端认领，保持全局paused，不提交、推送或合入。先固定公开规则来源，独立实现职业基础模块及定向测试，再由主执行者复核共享Combat入口与后续接入；完整卡池、平台和实机验收保持未完成。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
2026-10-25：用户明确授权本轮隔离开发暂免远端认领；全局paused未解除。基线877c4af，未提交/推送/合入。综合可审查目录 /workspace/sts-integration，说明 docs/rules/CLASS_FOUNDATION_INTEGRATION.md；各独立树 /workspace/sts-silent、/workspace/sts-defect、/workspace/sts-watcher 保留。隔离首片：四球、有序球位、集中、同球双放、卡牌独立随机流和Combat回合钩子。23组模块测试及跨职业集成通过。Dark同步增长先于排队Lightning伤害这一反直觉顺序有固定源依据与回归。额外球能力/遗物、职业开局、自然获取和完整卡池未完成。 Sub-Agent交付已检查实际文件和运行结果；源研究与实现为免费与否未知的本平台subagent，不声称额度节省。

后续开发检查点：/workspace/sts-integration冻结版本完整npm run check exit0，JS1347项、Lua228顶层文件全执行、Python22项，Node/Python无跳过；新增14个Lua文件共198组。源/测试SHA256验证未改变，原始日志build/classes-full-check.log。三实验职业原始初始牌组通过seed42首间真实普通房间胜利并进入第二间验证重建；普通发布入口仍默认战士。已接扩展牌、战术大师/本能队列、Focus正数、姿态能力循环。完整卡池/概率/平台UI/实机仍未完成。下一阶段隔离树/workspace/sts-next继续毒流、集中生命周期和占卜，新阶段不计入本冻结检查点。未提交推送合入，全局认领仍paused，用户本轮豁免仍适用。

2026-10-25 四职业构筑与界面冻结检查点 /workspace/sts-ui，feat/experimental-class-ui，基线877c4af。完整 npm run check exit0：JS1349/no skips、Lua247顶层全部执行、Python22；73个源/测试hash复核未变。包含毒流、Focus/Bias/球位、占卜队列、战士七牌、Accuracy、Mantra、职业菜单与mandatory choices及故障回归。独立review修复SharpHide致死使用牌处置、Devotion构造计数时点；旧失败/中断日志保留。当前92/300职业牌，208缺失；完整账本docs/rules/CLASS_CARD_COVERAGE.md，集成边界docs/rules/ARCHETYPE_INTEGRATION.md。原生参数注册/平台/实机未验。后续 /workspace/sts-builds 正接腐化消耗、弃牌减费、Loop/Electro与保留成长，不计入此冻结check。保持全局paused，沿用用户本轮隔离开发豁免；未提交/推送/合入。

本轮机器人实验Profile35/75，仍缺40。utility14新牌与HeatSinks/Storm接线，defect_utility_build.lua52组通过，含FTL TOPdraw/UseCard/BOTdamage、X块清理后逐段/FNP尾、Void/Burn、真实故障原引用回滚。当前35牌池seed15/45真实奖励取得并实用Focus/Frost或Loop/Electro，各4胜最终HP47/44，严格候选/回合/RNG；第五只验重置非5胜，floor harness非地图/概率/平台。证据 /workspace/sts-triggers/docs/testing/DEFECT_NATURAL_BUILD.md。下一独立19牌未接不计支持。

2026-10-25 最新165冻结检查点 /workspace/sts-checked（feat/verified-card-triggers）完整npm run check exit0：JS1349/no skips，Lua262顶层全执行无失败，Python22；597输入SHA256复核未变，build/card-triggers-code-hashes.json/full-check.log留证。仅4旧死亡处置fixture按源修正，165源码与原sts-triggers字节相同，旧两树失败日志保持。后续/workspace/sts-flow正在接下一69张牌（warrior状态29、defect engine63、silent tactics60、watcher flow27、展示21/512变体已定向绿），未将后续树算入本完整check或所有300完成。仍未提交推送合入，平台未验。
<!-- SECTION:NOTES:END -->
