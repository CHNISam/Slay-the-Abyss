---
id: TASK-16.1
title: 把伤害、抽牌和结算顺序算对
status: In Progress
assignee:
  - '@Codex'
created_date: '2026-10-23 01:57'
updated_date: '2026-10-24 21:52'
due_date: '2026-10-28'
labels:
  - required
  - rule-parity
milestone: m-4
dependencies:
  - TASK-8
  - TASK-11
references:
  - src/lua/abyss_combat.lua
  - data/SOURCES.md
  - docs/backlog-details/TASK-16.1.md
parent_task_id: TASK-16
priority: high
type: enhancement
ordinal: 43000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
核对所有卡牌和敌人共用的基础规则，避免同一种效果在不同地方算出不同结果。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 每条计算规则有原版依据，未知和差异明确记录。
- [ ] #2 伤害、格挡、状态加减、多段、反伤、中毒和死亡处理的数值与先后顺序正确。
- [ ] #3 抽牌、洗牌、弃牌、消耗、满手、费用支付和随机选择符合原版。
- [ ] #4 用原版预期结果检查特殊情况；卡牌、敌人和道具用同一套正确规则。
- [ ] #5 保存测试与实际游戏记录，明确各部分验证到了哪一步。
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
2026-10-25 正式洗牌独立片：先固定CardGroup与DrawCardAction来源，验证masterDeck初始顺序、尾端抽牌、每次含空/单牌shuffle消费一次randomLong并播种Java48/Collections。正式state.shuffleRng按层独立，初始/弃牌重洗及过量请求空堆均按源顺序；先独立向量和真实红例，再接线并覆盖出牌失败回滚/恢复，legacy显式入口保留但不作原版认证。只改Combat与局部fixture，不扩奖励/其它流，整体AC不勾。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
2026-10-25 PR193已合入9ae1aec，check/presentation完整通过。新卡牌状态切片建立唯一run.cardRng+offset owner，Shop准备与购买成功后才提交，不再持久shopRng.card；8组状态/入口、商店15组、致死药水4组及独立oracle 228原语/148稀有度偏移全部通过。完整卡牌身份/奖励概率尚未接，不能计整池或平台AC；见docs/reviews/TASK-16.1-card-random-owner.md。

2026-10-25 合并门禁补查：6457b61 的 Quality 40134143690 为 JS1209通过/1超时/119跳过，完整Lua未执行。原生子代理将意图预览原12组逐字拆为4/3/5，原生成UI入口及另外3份夹具共6文件通过，各5783/14048/8177/12415/8684/1922ms，全部保留30秒。Codex将原问号房220种子矩阵分为1–110、111–220，两半均保留所有逐种子断言并各自验证4路由/7事件，18170/16867ms通过；其余13组原文不变，3741ms通过。断言保留证明、实际红绿和只读复审已归档；docs/CI.md补充重复准备成本、可变状态隔离/别名及完整种子拆分要求。卡牌夹具缓存曾因RNG别名复审返工，最终93组20931ms通过；中间超时未改写为通过。子代理总墙钟耗时和实际费用未单独取得，Codex额度节省未知；未使用收费模型回退。本批仍须新当前SHA完整CI成功，父任务/平台验收不关闭。
<!-- SECTION:NOTES:END -->
