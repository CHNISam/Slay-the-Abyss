---
id: TASK-62
title: 接齐第三幕敌人、事件和结局流程
status: In Progress
assignee:
  - '@Furinya'
created_date: '2026-10-24 02:02'
updated_date: '2026-10-27 00:42'
labels:
  - required
  - sts1
  - acts
  - implementation-gap
  - partially-implemented
milestone: m-4
dependencies:
  - TASK-61
references:
  - docs/backlog-details/DRAFT-6.md
  - docs/rules/CROSS_ACT.md
  - docs/BACKLOG-RECONCILE-20261026.md
  - docs/BACKLOG-AUDIT-20261026.md
priority: high
type: feature
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
已通过PR213合入第三幕35至51层地图、遭遇/Boss队列及51层普通结局与三钥匙门边界；第三幕没有Boss宝箱。M3剩余：真实敌人/三Boss、七普通事件与共享事件、正式Host/章节UI和四职业连续通关。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 第三幕35至51层按原版生成，三种Boss完整执行，Donu和Deca只结算一次
- [ ] #2 七普通事件及共享神龛、一次性事件按资格出现并能执行，第三幕没有Boss宝箱
- [ ] #3 第51层缺钥匙走普通结局，满足资格与三钥匙才进入终幕，四职业分别三幕正常通关并保留证据
- [x] #4 第三幕35至51层地图、来源队列及普通结局/三钥匙门边界基础已合入PR213并有对应回归。
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
2026-10-27 第三批本地组合：从冻结d8f33a7c独立工作树接入已交付Transient和Sensory Stone（后者依赖钨合金棍）。逐个检查真实Diff，保留现有Orichalcum、Shapes、完整300目录与晚领奖回滚，整合后按原时限复验固定源、跨切片回归与工程门禁；不将局部结果视为整幕或平台通过。

2026-10-27 单事件Sensory Stone原计划及固定源更正一并保留：核查多组无色卡奖励的生成/稀有度/去重/顺序和持续cardRng，复用完整35普通无色与公开Nodes事务、分组选择/跳过及真实永久UID。源码已纠正早先NORMAL假设：全部奖励先生成，再HP_LOSS，走共享eventDamage和钨合金棍最终减伤；没有普通升级抽样，跳过可重开同组，Proceed回事件离开页。未接遗物明确依赖；不牵入其它事件/怪物/框架。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
2026-10-26状态整理：PR213已合入第三幕地图/队列和普通结局边界，实际怪物AI/事件体与正式Host尚未接，仍To Do。第三幕不存在Boss宝箱；按现有核心接内容再连续通关。

2026-10-26任务首页校正：直接体现已合并成果及下一步，撤销仅登记/未启动等过时开工描述。保留原有全量验收标准，不以合并代替平台验收。

2026-10-27 第二批已整合Falling/Moai/Winding三事件、Orb Walker/Shapes及球状守护者编组。父线程原时限24份组合回归全部通过，包括真实末敌自爆与Buffer/Static Discharge。Winding四个未实现遗物依赖明确拒绝并留账，Moai正常Golden Idol获取另独立补齐；Maw/Spire Growth和共享回合末优先级仍在独立工作树，暂未合入。整幕事件、剩余遭遇/Boss、自然接续和平台仍未完成。

2026-10-27 Maw/Spire Growth已在父完整300+Shapes+共享回合末实际合成树通过原18组8.639秒，来源actor/Artifact/105优先级/双死/完整回滚/Host说明均留证。保留旧Shapes自爆等原功能并独立复验，不将只读overlay当最终组合。三幕剩余事件、遭遇/Boss及自然/平台仍未完成。

2026-10-27 第三批Transient+Sensory Stone已在独立组合2349400c实际通过20份回归（含8份Sensory、原Maw/Shapes/Orb/Act2与Rod/回滚），15项JS含Transient19组通过；父线程对21/67/9 raw来源锁逐字节核对通过。当前第三批未推送合并，Guardian修复与Horde/Tomb等仍独立进行。整幕剩余敌人/Boss/事件、四职业自然通关和同候选平台均保留，具体见第三批组合记录。

2026-10-27 Transient/Horde、Sensory/Tomb与必要RedMask已进入同一PR238组合候选，原单片及组合证据见第三批记录；整幕剩余Boss/敌人/事件、四职业自然接续与平台继续未完成。本轮先集中现有交付、完成当前SHA CI再收口，不再启动新内容。
<!-- SECTION:NOTES:END -->
