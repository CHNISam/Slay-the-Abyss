---
id: TASK-12.4
title: M2 原版17层地图、节点生成与遭遇分布对齐
status: In Progress
assignee:
  - '@codex-map17'
created_date: '2026-10-23 01:56'
updated_date: '2026-10-23 02:46'
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
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
2026-10-23 用户最新授权多个独立任务并行自主推进且暂不开原神，覆盖历史唯一主冲刺排队纪律。执行worktree .worktrees/task12-map17；本切片保留已核对范围与未知项，完整17层Boss宝箱内容/原版随机流仍单独列缺口。

2026-10-23 离线切片已基于合并PR37/57/60后的develop：Map v2区分15生成行、Boss16、独立Boss宝箱17入口（roomKind=boss_treasure）；UI不将17画成普通可选地图行，源报告与数据说明同步。固定128种子强制1/9/15、前5禁精英/营地、14禁营地及17步快照通过；聚焦map/data/UI 77/77通过。完整check发现旧LCG连续取模关联导致移除伪强制节点后blue_slaver_solo等偶数池候选不可达，正在修复验证，不计全门禁通过。Boss17奖励由主线程保护，现宿主仍Boss16结果；本任务全部完整一致性AC保持未勾。

旧LCG回归红绿证据：首次完整check在encounter_coverage.lua:153失败，blue_slaver_solo在256种子缺失；保留同一断言，以相同seed独立创建地图房间/拓扑流及遭遇流后，18遭遇全部出现、188组遭遇回归通过。分流依据Forgotten Arbiter 2020-07-24原始分析（源链接及边界见地图报告），未改变数值/权重，未添加任意偏移/补抽；仍保留16位LCG与uniform候选，故不宣称原版64位RNG/加权列表/重复限制一致。完整check正在重跑。

2026-10-23 最终离线复验：npm run check exit0；JS188项（174通过，14项符号链接能力跳过），Lua735组通过，Python16项（15通过，1符号链接权限跳过）；另聚焦map/data/UI77项通过。未修改全遭遇覆盖断言。快照验证也覆盖独立遭遇流末态被篡改时拒绝。当前分支不宣称原版算法/概率/17层奖励事务或平台验收，所有AC保持未勾。
<!-- SECTION:NOTES:END -->
