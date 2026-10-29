---
id: TASK-29.1
title: 打磨战斗动画、打击感和死亡音效
status: In Progress
assignee:
  - '@Furinya'
created_date: '2026-10-23 03:53'
updated_date: '2026-10-29 16:51'
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
  - docs/plans/2026-10-30-battle-life.md
parent_task_id: TASK-29
priority: medium
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

2026-10-29实际接受330后的剩余修复：以actualdevelop1dc33fe7（等同330999d）新建本地线性候选，已接受的死亡演出/5+5/共享drain/11输入见证及helper完全冻结。仅补共享结算入口缺失的已提交defeat且busy保护，带回已审查14项触摸/手柄与生命周期回归。添加只绑定GameUI的一文件精确逆层，顺序guard→accepteddeath→旧层；只在现有中央入口及两个直接证明读点接线，所有原断言/种子/30秒不变。强保全和远端2bc未知输入证明以独立加法测试保留，cd104/2bc/ee39恢复引用不删。先在实际新基线重现独立RED，再本地focused/工程验证；根任务负责新head/base独立审查和既有331发布，无push/force/newPR或实机声明。

2026-10-30 用户授权自主研发并合入：先修卡牌真实去向，再补旅行者与两类怪物待机和差异技能。四个独立工作树，生产路径回归、最终完整Quality和完整GIL；平台/实体手机/听验未测继续保留。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
2026-10-24用户指出只按招式/命中分音会漏角色与怪物自身发声。本轮读仓库已有Cultist/Looter/JawWorm资料，明确原版不是全动作统一一声；补23敌人按身份固定行动音、玩家统一动作音，每intent/play一次，睡眠/眩晕/逃跑静默，命中和死亡独立。荧战斗语音在目录未确认，未冒称剑动作音为语音。生产夹具17组通过；新增主题配置覆盖门禁，重建完整音频副本及全量回归进行中。用户已要求直接采用、后续不合适再改；不等待用户试听但不伪造实机证据。

行动声音切片e974c25完整check exit0：JS1092通过/118跳过、175个Lua夹具全部通过、Python22项1跳过；精修17组。23敌人和玩家行动音覆盖门禁通过，独立完整副本读回通过，hash71e5d4f034ac1f2f5d68488be62e0591793aa55392de2087e0be8f70fea9e5ac。用户要求直接采用，不等试听。随后集成develop最新界面；TASK-4并行任务说明完整保留develop版本，音频证据集中在本任务、34和专项文档，未丢玩法/界面改动。

最终与develop ead3513集成的冻结源277c2a8已重建完整音频副本，17组行动/命中/死亡与39组房间回归通过，全部模块逐byte、BGM双true、原生图及UI读回通过；hash04c0e28c40bab1e67620566a5eb3ad4ac19f7f53206a0effe317f0d0351fe6ac。详见docs/evidence/audio-richness-integrated-20261025.json。未官方导入/听验；用户要求先采用。

2026-10-26全面复核：已有实现及原回归支持的本地条款补勾，具体证据见BACKLOG-AUDIT。尚未通过的完整入口、组合/自然实玩或最终音画门禁保留，不重复要求开发已实现机制。

负责人字段规范化：原记录 @Codex 作为历史执行者信息保留；任务负责人为 Furinya。

2026-10-29已按实际接受330的1dc33fe7重缩331：本地产物只新增共享结算入口的一行phase=defeat且busy保护及已审查14回归/强证明；已接受的演出/5+5/共享等待/11输入JSON与helper逐字不动。新一文件精确外层先还原guard，再进入冻结accepteddeath和旧PR323；只改中央及两个直接证明读点，原断言/种子/预算不改，2bc有效未知输入证明完整保留。实际1dc上独立原生两阶段先RED（提前结算各1次）再GREEN2/2；6阶段、8生命周期、原5+5、动作8/卡牌11/药水9手势全部通过（各原30秒内，包含真实重开/mini-Neow/旧指针尾断言）。56项逆层/布局/严格79543/79757/81392写入合同零skip通过；语法与完整工程门禁通过：258模块/1440边/3955测量/948职责/37旧警告零新增/4变异/原生4项。ee39/2bc/cd104恢复引用及证据保留。未推送/强推/另建或关闭PR，未导入/键鼠/实机听验，平台AC不勾；根任务继续新实际base/head独立审查、Full及既有331发布。
<!-- SECTION:NOTES:END -->
