---
id: TASK-15
title: M3 首发遭遇与敌人AI、概率和特殊机制原版对齐
status: To Do
assignee: []
created_date: '2026-10-22 13:47'
updated_date: '2026-10-23 03:26'
due_date: '2026-10-28'
labels:
  - queued-after-M2
milestone: m-4
dependencies:
  - TASK-11
  - TASK-14
  - TASK-12.3
priority: high
ordinal: 15000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
用户2026-10-23决定：首发纳入内容严格对齐初代Slay the Spire PC正式版Ascension 0数值/机制/算法/概率/结算顺序，仅名称/背景/元素表现可包装，禁止自创或凭感觉调平衡。M1唯一主冲刺，后续规则工作排队不打断P0。PR51仍OPEN，仅待审提案；用户指令为本次依据。10/30内部准备、11/02比赛截止不变。 复用已有14普通遭遇/19变体/3精英/1Boss数据，不以数量相同代表机制正确。SOURCES已知差异含固定意图循环、固定HP代替范围、遗卫无睡眠、小魔自加盾/虚弱替眩晕、软泥无分裂、窃金客无偷金逃跑及非原版五敌组合。只要求实际首发内容准确，未纳入内容不硬补；Boss内部阶段归TASK-17，地图分布归12.4。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 逐项记录原版PC版本、可复核来源URL/章节/观察日期、准确数值/算法/概率/结算顺序、现实现位置、差异与验收输入输出；不足标待核实，禁止猜测；未核实或未修正不计一致性通过。
- [ ] #2 逐个纳入敌人/精英核对HP随机范围、伤害/次数、状态值、首回合、行动权重、连续行动限制及历史状态；替换固定意图循环和固定HP近似，不以精英感觉更难为验收。
- [ ] #3 睡眠/苏醒、同伴护盾、塞眩晕、软泥分裂、偷金/逃跑与返金等纳入的特殊机制按来源实现；遭遇编组合法，未支持的效果不得以原创替代后进入池。
- [ ] #4 可控随机边界/状态轨迹覆盖每个行动分支、连招限制、死亡和特殊机制；统计样本与阈值有依据，所有纳入敌人本地可执行且有真实平台覆盖记录。
- [ ] #5 数据完成、独立原版预期自动测试、平台编译/副本导出、官方导入和千星实机分层报告，附SHA/hash/种子/日志和截图录像，不能互相替代。
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
本轮独立离线切片：1. 以可复核的初代PC A0资料确认沉眠遗卫睡眠/苏醒、生命随机范围和减益，明确社区二手资料级别。2. 实现109–111真实HP采样、起始8格挡、三次睡眠、HP损失唤醒及当次眩晕、醒后两次攻击接吸魂循环。3. 独立测试随机边界、格挡/失血、毒、固定伤害、致死、多实例、回滚和原循环兼容。4. 最新develop组合check及审查后交付；其他敌人和所有平台AC保留。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
2026-10-23审计：PR2已有14普通遭遇/19变体/3精英/1Boss数据，PR29接入节点选取；不把数据存在当作全部敌人可战。剩余需逐种真实战斗/意图验证、随机覆盖与精英难度证据，保持To Do，M1结束前不抢跑。

保留本轮离线候选记录：
2026-10-23审计：PR2已有14普通遭遇/19变体/3精英/1Boss数据，PR29接入节点选取；不把数据存在当作全部敌人可战。剩余需逐种真实战斗/意图验证、随机覆盖与精英难度证据，保持To Do，M1结束前不抢跑。

2026-10-23 离线审查（基线 origin/develop 083d780）：docs/reviews/TASK-15-encounter-audit.md 与 scripts/audit-encounter-pressure.lua 已列23敌人/55意图/18遭遇、原表SHA256、PR53已有逐意图与256种子覆盖，以及明确声明的固定循环/无睡眠/无分裂/无偷金逃跑/自盾/虚弱替代眩晕/无Boss变形缺口。无一手原作依据不猜测补规则。真实Run入口、原80HP与初始牌组不出牌不喝药诊断：普通五小魔4敌方回合致死，nob/lagavulin/sentries为11/10/5回合，提示优先做同构筑实战比较，不能把tier/HP当精英难度通过。build:data、validate:data、check:syntax、18遭遇诊断退出0。仅增审查与工具，不改敌人/数值/卡牌；本轮未启动原神、MCP或写存档，未改状态/AC，平台抽样、原版逐敌核验与真实难度均保留。

已同步2eaf30f新的原版一致性验收范围和依赖；本轮离线实现/诊断不替代原版来源核实、平台或完整通关验收。所有新AC保留未勾。

2026-10-23 /root/enemy_ai / feat/task-15-lagavulin：睡眠机制、受击/毒/固定伤害唤醒、18伤害两次接敏捷/力量各-1循环已实现。新增9组独立AI测试、13组schema检查、真实控件UI三态通过；20cb936基线完整npm run check通过，已有Windows符号链接权限测试按原规则跳过。接入a6be1b6新基线时保留新的卡牌playedCard参数和全部拖牌用例；新TASK15验收明确真实HP随机范围，因此补109–111采样后再全套复验。来源及证据等级见docs/reviews/TASK-15-lagavulin-ai.md；所有AC保持未勾，暂不开游戏/MCP/不编译或写存档。

最终a6be1b6组合复验：支持hpRange闭区间109–111真实战斗种子采样，seed3/0/5分别得到109/110/111且重复战斗和洗牌一致，maxHp取实际采样值。实际双Strike和Run.usePotion火瓶入口均验证立即唤醒与当次眩晕。新增AI规则12组、schema18组；完整npm run check退出0，Python16组1个既有权限skip；日志build/enemy-ai-check.log。已兼容PR37的严格非空Effects.supported，只有sleep/stunned意图在Combat.new中专门允许空effects，不放宽卡牌验证。原版随机算法/种子映射和原版二进制版本仍未核实；社区二手资料级别明确，五个AC全部未勾。

2026-10-23 /root/advance_enemy_rule_slice：独立离线祈火徒接线，基线7d809f3。计划先红灯验证首动仪式3、首轮跳过、后续基础攻击6与整组轮末力量增长，再仅改Cultist数据/AI、Combat轮末调用、状态定义/图标及严格schema；复用现有48–54 HP采样入口，不声称原版RNG。覆盖死亡/毒/反伤、多敌顺序、Lagavulin、UI与卡牌回滚。原计划/状态/AC保持，未启游戏/MCP；完成证据另追加。

2026-10-23 祈火徒离线接线完成候选（7d809f3基线）：首动自身仪式3，之后基础攻击6；首轮跳过，整组敌方行动/既有回合结束后才增长力量。HP48–54通过已有项目RNG实际采样，名义hp50不作实战值，不声称原版RNG。新增14组Combat/31组schema通过，Lua5.4全31文件通过（UI38、Lagavulin12、遭遇174），5种生产错误变体被检出，Python16通过。npm run check exit1：Node280通过/7因缺Fengari失败，未安装依赖；完整正式聚合需CI。docs/reviews/TASK-15-cultist-ai-candidate.md记录来源、时序及限制。未改原计划/状态/assignee/AC，未启游戏或写平台存档；待独立复审。
<!-- SECTION:NOTES:END -->
