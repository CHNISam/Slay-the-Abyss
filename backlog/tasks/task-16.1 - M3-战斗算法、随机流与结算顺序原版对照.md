---
id: TASK-16.1
title: M3 战斗算法、随机流与结算顺序原版对照
status: In Progress
assignee:
  - '@Codex'
created_date: '2026-10-23 01:57'
updated_date: '2026-10-23 08:54'
due_date: '2026-10-28'
labels:
  - required
  - rule-parity
milestone: m-4
dependencies:
  - TASK-8
  - TASK-11
  - TASK-12.3
references:
  - src/lua/abyss_combat.lua
  - data/SOURCES.md
parent_task_id: TASK-16
priority: high
type: enhancement
ordinal: 43000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
2026-10-23用户要求：首发实际纳入的第一幕内容严格还原初代Slay the Spire PC正式版Ascension 0的数值、机制、算法、概率及结算顺序。只允许名称/背景/元素表现包装，禁止自创机制、简化AI或自行调平衡。M1唯一主冲刺，本任务排队不打断P0；10/30内部投稿准备、11/02截止不变。PR #51目前OPEN未合并，仅为待审提案，本要求直接来自用户。 保留核心/九状态/满手/荆棘/格挡封顶有效修复，先查已合并PR，不重复M1缺陷。此切片核对共享算法；卡牌清单归TASK-16，AI归15，Boss阶段归17，库存效果归14.1。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 逐项对照账本包含原版PC版本、来源URL/章节/原作观察日期、准确值/范围/算法/概率/结算顺序、当前实现位置、差异、验收输入和预期；资料不足标待核实，禁止猜测，未核实/未修复不计严格一致性通过。
- [ ] #2 明确伤害/格挡修正及每步取整/上限，力量/虚弱/易伤/脆弱、多段/反伤/自损/中毒、状态叠加衰减、回合开始结束与死亡/胜利队列顺序，给出精确算法和边界输入输出。
- [ ] #3 核对抽牌/洗牌/弃牌/消耗/生成、满手、X费用/能量支付、随机目标及随机流初始化与调用顺序，不以可复现代替原版RNG算法一致。
- [ ] #4 独立原版预期验证顺序轨迹与边界并保留现有回归；跨卡牌/敌人/库存共享结果一致。未知算法待核实，不得勾相关严格验收。
- [ ] #5 数据完成、独立原版预期的自动测试、平台编译/副本导出、官方导入、千星实机分层报告，附SHA、候选hash、种子/输入、日志与截图或录像，不互相替代。
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
共享力量/敏捷边界切片：独立复审PR82的固定方法体、临时力量完整归还和int32原子保护，真实入口与当前CI验证；单项cap不等于全部算法或RNG一致。

combat_order 离线切片（基线52f35dd）：固定Weak/Vulnerable/Frail方法体、ApplyPower堆叠和MonsterGroup调度来源；先用真实Combat入口证红轮末衰减/首次施加/既有叠加，再最小调整共享轮末与扁平justApplied标记，保留异常回滚。仅核对此切片，不勾全项AC，不声明官方PC认证或实机。

random_float候选切片（基线94c1045）：核实固定STS Random与官方libGDX nextFloat；新增显式float range/between包装及每步binary32舍入，限制精确finite binary32与有限span，非法请求抽样前拒绝。独立手写Java float表达式固定向量先红绿，验证24位端点、计数/回绕/状态、下溢及nearest-even；不接生产、不推测种子/流初始化，不跑全量。

2026-10-23 死后已排队Roll片：固定RollMoveAction/Thorns/DamageAction/clearPostCombatActions/MonsterGroup链，区分同伴存活和末敌；真实Combat受控RNG红例后新增EnemyAI.afterAction，仅已核实Roll策略在行动后反伤致死且战斗未完时消费，毒死/末敌不消费。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
PR82固定0efbb7独立源码及116组Fengari复核无阻断，远端Quality双项SUCCESS后已合develop01817ab。Strength/Dex限制[-999,999]，Flex完整量归还；原int32/原子oracle保留。完整check通过，Java极端wrap与安全拒绝差异见SIGNED_STATUS_CAPS.md。未原神/官方导入/实机，整项AC保持未勾。

2026-10-23 @Codex/combat_order 独立worktree feat/continue-combat-order领取；TASK12.3平台依赖保留，按用户授权推进可离线规则切片，暂不开原神。

combat_order切片：Weak/Frail/Vulnerable改为整组敌人行动后、玩家再存活敌人的round_end衰减；首次怪物来源按三方法体justApplied跳过，已有叠加不重置，死亡提前终止不制造tick。固定fc379c8源码blob、边界输入预期及证据等级见docs/rules/ROUND_DEBUFF_DURATION.md。旧实现15专项5过10败；修复后17专项、35状态、11Fat、9Blue、24Guardian、9Cultist、6Boundary、23Combat、93CardPool、10Feedback、27HP-loss、11Inventory、12Caps及54schema通过，JS syntax和diff检查通过。整合全量check由主代理执行；power priority全交错/原版RNG/平台全部AC仍未完成，状态保持In Progress。

2026-10-23 @Codex/combat_order 在feat/continue-random-float独立推进scaled-float候选；沿用systematic-debugging/TDD/verification-before-completion工作流，固定来源已只读核实。

random_float候选切片：显式randomFloatRange/Between新增逐步binary32 nearest-even、正负零及2^-149次正规；仅收窄finite exact binary32/finite span ABI，非法请求抽样前拒绝，不接生产或猜流初始化。固定STS c4b71d与官方libGDX a6a0b3来源；独立Java17表达式132行fixture复现逐字段一致（非官方RNG/游戏Oracle）。新增7专项先1过6败，修复后连wrapper10/primitive8共25过；十个隔离负变异检出（漏span guard为超时，其余断言）；Node语法/diff检查通过。详见docs/reviews/TASK-16.1-scaled-float-candidate.md。全量待主代理统一，无平台编译/导出/导入/原神实机，全部严格AC保留。

PR100轮末状态片已squash合develop14979df；下一批同步保留该修复及新scaled-float隔离候选，不将候选当生产RNG或平台通过。

独立26ff410死后选招：15专项（初13例8过5败）及相关149组定向绿；支持Jaw/Blue/Nob/rolled_attack，排除AcidS与仅开场抽样策略，死者不执行Actor.endTurn。源链/blob和输入/剩余差异见docs/rules/QUEUED_ENEMY_ROLL_AFTER_DEATH.md。末敌清queue、同伴存活先消耗再队友、额外条件draw、后续不重复与回滚均覆盖。Blue/Nob死后已排队debuff仍单独未对齐，不改变LCG，不宣称完整动作队列/平台通过；整合后全量待跑。
<!-- SECTION:NOTES:END -->
