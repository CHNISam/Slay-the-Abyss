---
id: TASK-12.4
title: M2 原版17层地图、节点生成与遭遇分布对齐
status: In Progress
assignee:
  - '@codex-map17'
created_date: '2026-10-23 01:56'
updated_date: '2026-10-23 11:45'
due_date: '2026-10-26'
labels:
  - required
  - rule-parity
milestone: m-3
dependencies:
  - TASK-3
  - TASK-12
references:
  - data/SOURCES.md
  - data/rules.json
  - src/lua/abyss_map.lua
parent_task_id: TASK-12
priority: high
type: enhancement
ordinal: 40000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
2026-10-23用户要求：首发实际纳入的第一幕内容严格还原初代Slay the Spire PC正式版Ascension 0的数值、机制、算法、概率及结算顺序。只允许名称/背景/元素表现包装，禁止自创机制、简化AI或自行调平衡。M1唯一主冲刺，本任务排队不打断P0；10/30内部投稿准备、11/02截止不变。PR #51目前OPEN未合并，仅为待审提案，本要求直接来自用户。 当前rules.json为15层/Boss15/营地14，abyss_map.lua为三列同列链加邻列边、节点及遭遇等概率抽取；这是待核实修正差异。TASK-12已完成的本地15层证据保留，本切片独立验收新规则。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 逐项对照账本包含原版PC版本、来源URL/章节/原作观察日期、准确值/范围/算法/概率/结算顺序、当前实现位置、差异、验收输入和预期；资料不足标待核实，禁止猜测，未核实/未修复不计严格一致性通过。
- [ ] #2 核对17层统计及地图可选节点/Boss房/Boss奖励宝箱计层边界，形成15→17逐层映射；确认强制楼层、节点权重、路径/交叉/相邻限制及早期战斗/精英条件，不能仅改floors常量。
- [ ] #3 生成/导航/UI层号/快照符合核实后的完整第一幕；早晚普通池/精英池、重复限制、随机流初始化与调用顺序按原版，敌人内部AI归TASK-15。
- [ ] #4 固定种子和随机边界测试覆盖拓扑可达、强制节点、池抽取及快照；统计列样本数、原版期望和有依据阈值，不以一次出现或数量相同证明概率正确。本地独立验收，平台归TASK-12.3。
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. 复用PR59来源账本，仅落实已证实的15行地图、强制1/9/15层与早期限制；不猜原版路径或随机算法。2. 区分15生成行、Boss16、Boss宝箱17的规则字段；先修正Boss导航与层号，未实现的Boss宝箱内容明确留账。3. 先写失败测试，再更新地图签名/快照、数据门禁、UI容量与相关固定种子回归。4. 跑完整离线门禁并记录来源边界；不勾完整严格一致性或平台AC，不启动原神。

继续独立整合PR62离线证据切片到最新develop：保留当前15行/Boss16/Boss箱17地图生产代码与已有记录，复核固定Oracle和文件hash，运行最新逐边差分及10000 seed门禁；失败如实报告，问号reducer暂不生产接线。

2026-10-23 /root continued-backlog：核对固定原始方法体生成房间清单，针对随机行额外宝箱写真实Map.generate红例；仅在来源明确后移除不应在随机房间清单的treasure。保留九层固定箱与十七层Boss箱，跑边界/地图/全遭遇回归；三道拓扑、交叉边和原版RNG继续明确未对齐。

2026-10-23 @codex-map-topology，独立worktree continue-map-topology/feat/continue-map-topology，基线origin/develop6014746：先核固定MapGenerator/MapEdge/MapRoomNode与12 golden，仅修可独立证明的生产crossing。真实Map.generate交叉红例；按相邻已有边dst max/min夹限并去重，不变RNG/房型/遭遇抽样；旧两边私有断言替换成来源支持出度范围，保持无交叉/可达/导航/快照原断言。sourceSignature拒旧图。定向源/地图/UI/遭遇与0..9999结构检查、严格12golden实际差分均如实记录；不全check/MCP/游戏，7列6路径/ancestor/RNG/配额仍缺口，所有整体AC不勾。

2026-10-23 @codex-map-rng，独立树continue-map-rng/feat/continue-map-rng @1cfaba2：root批准先做tools/candidates隔离7列15行6路径拓扑。固定源证明raw十进制signed64局seed+1（Java long回绕）；复用已有正确拒绝采样原语/闭区间wrapper，不接生产。先保持12原golden hash不变写坐标+边topology-only红例，再独立实现起点重抽/祖先（保留来源x<y分支及深度边界）/夹限/dst去重/父列表/首行冗余边过滤。完整64位输入含2780…，手写边界向量与真实12golden独立核对，不用同实现自重放替代。full房型golden另保留失败；完成后给Map/restore/7列UI容量/同raw房型shuffle生产迁移具体方案，不把候选当长期终点。不开游戏/full/Miliastra。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
2026-10-23 用户最新授权多个独立任务并行自主推进且暂不开原神，覆盖历史唯一主冲刺排队纪律。执行worktree .worktrees/task12-map17；本切片保留已核对范围与未知项，完整17层Boss宝箱内容/原版随机流仍单独列缺口。

2026-10-23 离线切片已基于合并PR37/57/60后的develop：Map v2区分15生成行、Boss16、独立Boss宝箱17入口（roomKind=boss_treasure）；UI不将17画成普通可选地图行，源报告与数据说明同步。固定128种子强制1/9/15、前5禁精英/营地、14禁营地及17步快照通过；聚焦map/data/UI 77/77通过。完整check发现旧LCG连续取模关联导致移除伪强制节点后blue_slaver_solo等偶数池候选不可达，正在修复验证，不计全门禁通过。Boss17奖励由主线程保护，现宿主仍Boss16结果；本任务全部完整一致性AC保持未勾。

旧LCG回归红绿证据：首次完整check在encounter_coverage.lua:153失败，blue_slaver_solo在256种子缺失；保留同一断言，以相同seed独立创建地图房间/拓扑流及遭遇流后，18遭遇全部出现、188组遭遇回归通过。分流依据Forgotten Arbiter 2020-07-24原始分析（源链接及边界见地图报告），未改变数值/权重，未添加任意偏移/补抽；仍保留16位LCG与uniform候选，故不宣称原版64位RNG/加权列表/重复限制一致。完整check正在重跑。

2026-10-23 最终离线复验：npm run check exit0；JS188项（174通过，14项符号链接能力跳过），Lua735组通过，Python16项（15通过，1符号链接权限跳过）；另聚焦map/data/UI77项通过。未修改全遭遇覆盖断言。快照验证也覆盖独立遭遇流末态被篡改时拒绝。当前分支不宣称原版算法/概率/17层奖励事务或平台验收，所有AC保持未勾。

PR62旧基线合并冲突采用最新develop的任务元数据，保留既有地图修复、候选构建与未完成AC；PR62新增黄金Seed、严格比较工具及独立问号reducer为证据切片，待当前代码复跑和独立复审，不据此宣布原版地图一致。

PR62与develop ed39f46离线整合完成：修复Golden仅比较生成15行且独立校验Boss16/箱17、完整图先验防隐藏坏边，CAPTURED非零退出/捕获错误拒绝。定向10/10，全check exit0(JS315pass14skip/Lua全套/Python15pass1skip)。最新严格Golden仍FAIL0/12(11差异1完整64位seed不支持)，结构10000实际执行0通过0执行错误，剩余原因含随机宝箱和交叉边；docs/rules/evidence/w1-latest-integration.json记录hash/反例。纯问号reducer未接生产，原版RNG/全地图/实机AC均不勾。待固定head独立复审和当前CI。

本轮执行身份/root，独立worktree .worktrees/continued-backlog，基线52f35dd；与四条subagent任务并行，不开原神、不将离线修复作为完整地图一致性验收。

2026-10-23 /root fixed treasure切片：固定AbstractDungeon方法体和既有第三方golden确认随机地图房清单不含treasure。真实Map.generate seed0/f2_l3修前红；移除随机treasure后128输入固定宝箱/17步/恢复通过，地图10组、层边界128种子、遭遇143组（18遭遇全出现）通过。sourceSignature明确拒绝旧分布快照。来源与限制见docs/reviews/TASK-12.4-fixed-treasure.md；三道拓扑/交叉边/RNG/配额/Boss宝箱事务仍未对齐，全部AC不勾。

本轮golden实际复跑仍FAIL 0/12（11差异/1完整seed不支持），11个成功导出样本的random treasure错误为0。完整check首次发现旧inventory夹具依赖第9层前随机箱；迁移至固定seed36路线并限制仅买一次，保留11/12张卡组、金币、UID、两战与Anchor等全部断言，inventory11组通过。完整组合门禁待最终整合。

2026-10-23 @codex-map-topology 离线领取工具/来源层核对完成：固定319009d5df0a82d9fb0f23cc22322286c6a87ec0三份Map原文实际读取，response保留根.artifacts/map-topology-source-6014746。此为未经正版PC二进制认证的第三方CFR镜像，不复制实现或运行镜像。最小可验证方案已报root。

2026-10-23 @codex-map-topology：最小生产crossing修复完成，真实seed0反向对角先红后绿；相邻边目标max/min夹限后按dst去重，sourceSignature增adjacentEdgeClamp。旧源码128输入逐次12081个RNG调用before/bound/after/value完全相同，6016房间/遭遇记录+生成后双随机seed相同，128真实旧图snapshot以configuration_mismatch拒绝。40个地图/evidence/contract/UI专项，map10组、floor128、treasure128、encounter115组（原18遭遇全到达）均通过。既有50seed分批/15s预算未改，性质0..9999实际10000请求/执行/通过，0失败0执行错误；严格golden仍FAIL0/12（11diff/1完整64位seed不支持），11导出图结构错误0。来源hash/边界见docs/reviews/TASK-12.4-map-crossings.md与docs/rules/evidence/w1-map-crossings.json；raw source/旧源/逐调用脚本/完整差分见根.artifacts/map-topology-source-6014746。不改RNG生产接线/房型/遭遇权重，不以性质绿代替7列6路径/祖先/配额/原版RNG/全拓扑一致；无full/MCP/游戏，全项AC不勾。

RNG只读调查原文/13份response及source blob/content hash、12golden seed口径与fixture hash、稀有拒绝采样oracle公式差异已保留根.artifacts/map-rng-source-1cfaba2/investigation.json。原作PC二进制/实际libGDX依赖版本仍未认证；不迁就oracle unsigned拒绝条件、不修改golden。此片不改production RNG及任务广义AC。

2026-10-23 @codex-map-rng 收敛交接：隔离tools/candidates/sts1_map_topology.lua完成，未接生产。新增15专项先0/15（缺候选）后15/15；12未改捕获golden的连接坐标/每条边全部匹配，含完整2780424839485660359输入，无tonumber/16位截断；seed+1回绕及起点/祖先/夹限/父引用/首行过滤独立边界通过。原语/包装器、src/golden/data/CI未改；生产全图另实际FAIL0/12（11diff/1unsafe64）。结构化证据docs/rules/evidence/w1-map-topology-candidate.json，原始13source与各seed实际图/state/runner响应在根.artifacts/map-rng-source-1cfaba2；稀有oracle拒绝采样差异未迁就。生产房型/同raw洗牌、Map v3 stringseed/restore、7列UI92节点容量等具体gate写docs/reviews/TASK-12.4-map-rng-topology-candidate.md，均未实施。用户现可登录原神且要求收敛，停止新范围，仅文档/独立commit/交接；无full/Miliastra/游戏，广义一致性/平台AC不勾。
<!-- SECTION:NOTES:END -->
