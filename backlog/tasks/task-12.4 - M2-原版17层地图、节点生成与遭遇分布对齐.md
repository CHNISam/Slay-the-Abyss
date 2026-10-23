---
id: TASK-12.4
title: M2 原版17层地图、节点生成与遭遇分布对齐
status: In Progress
assignee:
  - '@Codex'
created_date: '2026-10-23 01:56'
updated_date: '2026-10-23 02:39'
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
documentation:
  - docs/rules/W1.md
  - docs/rules/sts1-rule-matrix.csv
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
1. 渐进读取W1规则及验收，刷新develop 2eaf30f差异并登记来源。2. 先建立可运行Oracle --a0黄金种子和地图/问号失败回归；无证据项显式待核实。3. 逐切片实现地图生成、15行/16Boss/17箱边界、问号状态机及导航/UI/恢复契约。4. 当前SHA完整门禁、10黄金种子与10000性质种子，更新Rule Matrix；独立PR审查和Quality成功后集成。平台编译/副本/实机分别报告。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
用户2026-10-23直接授权按规则包W1→W4推进，覆盖旧M1排队顺序；只在feat/sts1-w1独立工作树实施，保留所有既有任务历史和主工作区修改。W1未验收不得开启W2。

W1首切片：实际执行固定Oracle v1.1.0（自报1.0.0、sha ea5200f、exe SHA256 add3b40d…），12个指定Seed显式--a0，已记录独立节点/边JSON及hash。当前真实Lua黄金差分0/12通过（11不一致、1完整64位种子接口不支持）；实际Lua Seed0-9999结构检查0/10000通过，10000执行/0进程错误。新增纯问号基础概率reducer：9/9资料包向量、边界/超1不归一化/恢复/失败原子性及10000次重放通过；未接Nodes/原版eventRng，特例仍待核实。npm run check exit0，JS202=188pass14symlink权限skip，Lua现有套件通过且新增6组，Python13=12pass1skip。普通门禁不等于地图Parity。矩阵和完整失败证据在docs/rules/，宽验收项不勾选，任务继续In Progress，不开启W2。
<!-- SECTION:NOTES:END -->
