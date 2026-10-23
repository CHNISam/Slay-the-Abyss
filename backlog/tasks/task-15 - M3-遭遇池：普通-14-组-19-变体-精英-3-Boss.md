---
id: TASK-15
title: M3 首发遭遇与敌人AI、概率和特殊机制原版对齐
status: In Progress
assignee:
  - '@Codex'
  - '@codex-enemy-parity'
created_date: '2026-10-22 13:47'
updated_date: '2026-10-23 09:28'
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

继续离线祈火徒切片：独立读取固定镜像Cultist/RitualPower及整组轮末调度。补能区分首动与0/6/9/12/15轨迹、队友时序/死亡/展示的运行时测试，再接入仪式状态和整组轮末钩子；生命48–54沿用现有项目采样，随机流一致性不宣称通过。保留睡眠AI兼容，全部来源/平台AC保留。

继续离线 Jaw Worm 切片（feat/task-15-jaw-worm-ai，ed39f46基线）：1. 固定镜像 JawWorm/Random/版本声明逐分支取证，记录非官方真实性与RNG差异。2. 先写独立边界预期：40–44 HP、首动11、Thrash7后Block5、Bellow Strength3后Block6、25/55边界及条件概率/连续限制。3. 独立Jaw决策模块接现有AI分派，历史平铺在actor；所有常数来自数据，生产随机仍明确项目LCG非原版流。4. 定向回归、schema与必要集成检查，独立提交交主线程审查；原版全池/算法/平台AC不勾。

2026-10-23 独立切片 codex-enemy-parity（feat/continue-enemy-parity，基线52f35dd）：固定社区源码核查 Gremlin Nob A0 与 AngerPower；先写真正 Combat 入口红测，再实现 HP82–86、首动 Enrage2、33边界攻击/易伤与连续限制；沿 EnemyAI 现有钩子接技能反应，验证schema与集成回归。不碰 Combat/Inventory，不开游戏或 live MCP；全池和平台AC保留。

2026-10-23 独立切片 codex-enemy-parity / feat/continue-blue-slaver，暂依赖Nob 2a86eaa：固定社区SlaverBlue源码核查A0 HP46–50、40边界选招、双动作不连三及首动随机请求；先独立Combat红测，再加Blue专属AI与hpRange，保留既有Rake7后Weak1动作值与共享状态时序；定向schema/AI/可达覆盖，不重跑全量；不碰Combat/Inventory、不启动游戏/MCP，原版RNG/平台AC保留。

2026-10-23 连续切片 codex-enemy-parity / Acid Slime S，基线ade3bb5：固定AcidSlime_S与Random源码核查A0 HP8–12、开场主roll后Boolean额外抽样、后续Tackle3/Weak1严格交替且不再roll；先独立Combat红测再专属AI接线、schema及18遭遇可达覆盖。不碰Combat/Actor/Inventory，不改共享Weak时序，不涉及分裂，所有原版RNG与平台AC保留。

2026-10-23 SpikeS切片（独立8a70065）：固定源码核对HP10–14和Tackle5、无条件主roll消费，新增rolled_attack分派；专项/schema/遭遇回归并保留反伤致死后已排队roll的共享红例，交TASK16.1修复。

2026-10-23 Fat/Sneaky抽样切片（独立283e9c3）：固定GremlinFat/GremlinThief方法核对，Fat复用rolled_attack每动Roll，Sneaky用opening_roll_attack仅开场Roll、之后SetMove；保持PR86数值与原动作回归，death/队列与领袖逃跑分别保留。
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

祈火徒生产接线离线切片：固定镜像方法体重新读取后实现48–54 HP采样、首动仪式3、随后6基础攻击及整组敌方轮末增长3力量（施加当轮跳过）。新运行时9组红→绿，真实首战UI意图/状态展示通过，补10组schema边界。完整npm run check退出0（JS268pass/14既有权限skip，Lua全套，Python15pass/1skip）；最终两个恶形schema新增10/10再通过。原反馈/药水fixture显式关闭自定义敌人AI，真实行为独立测。docs/reviews/TASK-15-cultist-runtime.md列来源与版本真实性/原版随机流限制；所有全池/平台AC保留未勾。独立复核中，未开游戏/平台编译/写存档。

本批代码已合develop fac093c（药水PR78），实际离线构建源022f22cf；git diff确认src/data/scripts与合入代码完全一致。完整check及各PR当前SHA Quality全绿，实际gil独立核实24模块源文、1220控件/六列模板/22节点启用结算图，客户端静态0error/15条已定位自定义方法warning；内存重注入与候选字节相同。候选SHA256 a6d839d45753af0e536142bba7a3cd2322155dda38a67cbcc220bce7b6c8e114，正式底图hash前后相同且liveWrite=0。证据docs/evidence/offline-candidate-022f22c.json及P0-SMOKE。未开原神、未官方导入/实机，所有剩余平台/全项AC保留原状态。

2026-10-23 Jaw Worm生产切片（feat/task-15-jaw-worm-ai，ed39f46基线）：固定ButterflyGame JawWorm/Random和开发者caseyyano公开getMove交叉，另aeubanks固定AbstractMonster核首动random(99)消费。已实现HP40–44、首动11、Thrash7后5格挡、Bellow3力量后6格挡、25/55与binary32条件概率/连续限制。13组AI独立预期先红后绿；新增13schema加既有共85JS通过；真实原生控件详情验证；18遭遇覆盖152组；最终完整Lua退出0，build/jaw-worm-lua-check.log。明确修复自定义反馈意图/一点HP导航夹具，不降低生产数据。共享16位LCG/原版独立流/种子映射仍未生产对齐，详见docs/reviews/TASK-15-jaw-worm-ai.md；未跑本片完整npm check，主线程统一组合。不开游戏/MCP/不写存档，全部全池与平台AC保留未勾。

本轮离线复审与合并：PR91 Jaw实际HP40–44、主/条件随机消费及历史限制接线；PR89蓄能小魔真实charge/reset第3/7/11动25攻击；PR86 Fat/Sneaky/Blue来源值与动作payload，43组真实入口和全部本机/当前CI通过。Jaw/Guardian/Cultist/Lagavulin钩子保留。相关共享Weak轮末justApplied时序、Blue原版随机选招/独立RNG仍未对齐，不能据此关闭全敌人严格一致性；尚未官方导入/实机。

2026-10-23 codex-enemy-parity / 14b2a80：固定 aeubanks/sts@319009d 源码镜像核查并独立实现 Gremlin Nob A0：HP82–86、开场Enrage2、技能效果前力量、Skull Bash6后易伤2、BullRush14、33边界与Rush禁三连。专项12组先红11后全绿，900组受控映射；10组schema及原生打包校验。完整npm run check结束：JS594项479通过115既有条件跳过0失败；全部Lua与Python16项（1权限skip）通过。证据见docs/reviews/TASK-15-gremlin-nob-ai.md。未改Combat/Inventory，无游戏/MCP/平台编译/副本导出/实机；共享LCG、PC构建真实性、全池与所有平台AC继续保留。

执行者 codex-enemy-parity 已核查 aeubanks/sts@319009d SlaverBlue.java，SHA256 A523E2AE8A5B598AD19AF3460A28F13B8BC47152501F9B4E61F46F732D869206。来源为未与正版PC构建hash认证的社区反编译镜像，非官方源码或PC实测。

2026-10-23 codex-enemy-parity / feat/continue-blue-slaver：固定SlaverBlue@319009d复核并新增A0随机首动、40边界和双动作均禁三连；历史强制分支仍消费主roll；原HP46–50与Stab12/Rake7后Weak1保留，未改Combat/Inventory/Actor。9组AI红7→全绿含900受控roll/历史、消费次数、死亡、实例和回滚；既有动作9组原样通过。相关schema与打包53项通过；18遭遇/256种子可达与129组真实Run覆盖通过；build:data、validate:data、定向JS语法与diff检查通过。未重跑本片全量check，主线程统一整合复验。证据docs/reviews/TASK-15-blue-slaver-ai.md；共享16位LCG/独立随机流、Weak共享时序及PC二进制真实性仍未验证，所有全池/平台AC保留，未游戏/MCP/编译或写入存档。

2026-10-23 codex-enemy-parity / Acid Slime S增量，基线ade3bb5：固定AcidSlime_S与Random源码核查并独立实现HP8–12、开场主roll后额外Boolean、攻击3/Weak1后续严格交替且不再AI抽样；不涉及分裂或继承中毒，不改Combat/Actor/Inventory。新增9组真实Combat/Run先5红后全绿；8项schema加现有共61项JS通过；既有Blue9/Nob12组通过；18遭遇/256种子可达、23敌人53意图124组覆盖通过；build:data/validate:data/定向JS语法/diff通过。来源hash和共享LCG/Boolean适配局限见docs/reviews/TASK-15-acid-slime-s-ai.md。未跑本片全量check，由主线程最终组合；工作树尚不含root的Weak调度整合，但本增量不碰或恢复该文件。不开游戏/MCP、不编译或写入存档，原版PC真实性与所有全池/平台AC保留。

PR100已在cf6969e双Quality成功后squash合develop14979df；下一批同步保留已合Nob/Blue与新AcidS增量，CLI记录不覆盖已完成切片。

SpikeS源8a70065：8组专项先5红后全绿，68项JS与18遭遇可达/121组覆盖通过，未全量/未平台。共享queued-roll-on-retaliation probe在solo为0/0通过、有同伴为1/0红；源码链及原始hash见TASK-15-spike-slime-s-ai.md，Blue/Nob/Jaw账本已补证据限定，不把现有死亡guard当原版消费一致。整合保留此前PR100/AcidS/CLI所有记录。

283e9c3独立交付：新8组先5红后全绿，旧Sneaky8/Fat11全保留通过，76相关JS/schema/package及18遭遇可达115组覆盖过，未全量/平台。源hash与抽样调用顺序见TASK-15-fixed-gremlin-rolls.md，旧两账本追加指向。root整合新afterAction仅rolled_attack可死后Roll，opening_roll_attack不增消费；Fat反伤死后queuedWeak另由共享规则片核实修复，不宣称完整队列/原作RNG/PC/平台一致。

第二批root集成d3e9d76：AcidS/SpikeS/Fat/Sneaky抽样策略及死后队列专项均独立复审；完整npm run check最终exit0：JS643共528pass/115既有条件skip，Lua全绿，Python16共15pass/1 Windows权限skip。首次15秒遭遇覆盖超时在相同预算隔离重跑115组过；随后发现Fat旧fixture替换intent ID与新policy冲突，仅修fixture保留身份及断言，最终全量重跑绿。未修原版生产RNG/全池/平台，所有严格AC不勾。
<!-- SECTION:NOTES:END -->
