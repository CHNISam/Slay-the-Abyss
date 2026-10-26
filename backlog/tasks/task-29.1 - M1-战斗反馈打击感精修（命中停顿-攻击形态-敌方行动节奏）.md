---
id: TASK-29.1
title: 打磨战斗动画、打击感和死亡音效
status: In Progress
assignee:
  - '@Codex'
created_date: '2026-10-23 03:53'
updated_date: '2026-10-26 12:56'
due_date: '2026-10-28'
labels:
  - enhancement
  - awaiting-live
milestone: m-5
dependencies: []
references:
  - docs/backlog-details/TASK-29.1.md
  - docs/DELIVERY-CLOSEOUT.md
  - docs/AUDIO_RICHNESS.md
  - docs/BACKLOG-AUDIT-20261026.md
parent_task_id: TASK-29
priority: high
ordinal: 44000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
让出牌到命中更连贯，轻重攻击有区别，敌人行动顺序清楚。只打磨表现，不改战斗数值。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 出牌有蓄势和加速，命中瞬间衔接准确；重击和致命一击更有力度。
- [x] #2 普通、重击、多段、群攻、中毒和反伤有可区分的画面与声音。
- [x] #3 获得格挡、吸收攻击、破盾、状态和死亡有不同反馈；同时击杀时死亡音不重复。
- [x] #4 敌人依次蓄势、出手、命中、回位；非攻击动作不会演成攻击。
- [x] #5 表现不会越玩越卡，取消或演出故障后仍能正常操作，自动检查通过。
- [ ] #6 同一完整游戏候选已实际试玩并录制含声音录像，逐项审阅打击、格挡、状态、多段群攻、敌人行动及死亡音效，记录可接受结论或待修项；未试听不能完成。
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
2026-10-24用户纠正：角色/怪物自身的行动发声必须独立于命中和死亡；不能只按伤害轻重选音，更不能将记忆中的原版一概写成每招同声。参考现有Cultist/Looter/JawWorm代码资料，补按definitionId固定的怪物行动音、角色统一出手音；每个intent/play最多一次，睡眠/眩晕/逃跑不叫，多段不逐击重叫。保留资料来源未认证和荧语音目录未证实的限制。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
2026-10-24用户指出只按招式/命中分音会漏角色与怪物自身发声。本轮读仓库已有Cultist/Looter/JawWorm资料，明确原版不是全动作统一一声；补23敌人按身份固定行动音、玩家统一动作音，每intent/play一次，睡眠/眩晕/逃跑静默，命中和死亡独立。荧战斗语音在目录未确认，未冒称剑动作音为语音。生产夹具17组通过；新增主题配置覆盖门禁，重建完整音频副本及全量回归进行中。用户已要求直接采用、后续不合适再改；不等待用户试听但不伪造实机证据。

行动声音切片e974c25完整check exit0：JS1092通过/118跳过、175个Lua夹具全部通过、Python22项1跳过；精修17组。23敌人和玩家行动音覆盖门禁通过，独立完整副本读回通过，hash71e5d4f034ac1f2f5d68488be62e0591793aa55392de2087e0be8f70fea9e5ac。用户要求直接采用，不等试听。随后集成develop最新界面；TASK-4并行任务说明完整保留develop版本，音频证据集中在本任务、34和专项文档，未丢玩法/界面改动。

最终与develop ead3513集成的冻结源277c2a8已重建完整音频副本，17组行动/命中/死亡与39组房间回归通过，全部模块逐byte、BGM双true、原生图及UI读回通过；hash04c0e28c40bab1e67620566a5eb3ad4ac19f7f53206a0effe317f0d0351fe6ac。详见docs/evidence/audio-richness-integrated-20261025.json。未官方导入/听验；用户要求先采用。

2026-10-26全面复核：已有实现及原回归支持的本地条款补勾，具体证据见BACKLOG-AUDIT。尚未通过的完整入口、组合/自然实玩或最终音画门禁保留，不重复要求开发已实现机制。
<!-- SECTION:NOTES:END -->
