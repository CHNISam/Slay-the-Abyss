---
id: TASK-96
title: 建立首局可感知的独立职业身份
status: In Progress
assignee:
  - Furinya
created_date: '2026-11-03 02:45'
updated_date: '2026-11-03 15:29'
labels:
  - design
milestone: m-8
dependencies: []
references:
  - docs/SCOPE.md
  - docs/ORIGINAL_V4.md
  - 'https://github.com/CHNISam/Slay-the-Abyss/pull/479'
  - docs/backlog-details/TASK-96-CHARACTER-IDENTITY-20261103.md
priority: medium
ordinal: 138000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
当前编号映射（2026-11-03）：本任务属于 M8/m-8 产品体验与核心特色；下文保留的旧称“M7 核心产品体验门槛”按当前 M8 理解，验收实质、负责人及既有 AC 不变。

解决当前岩系旅行者仅将《杀戮尖塔》铁甲战士机制换名包装、难以形成《杀戮原塔2》自身玩法身份的问题。优先评估让已实现的 V4 自研职业（TASK-85 雷电将军）作为正式差异化入口；也可经 Owner 批准采用其他不重做冻结代码的方案。此项是 M7 核心产品体验门槛，不等于要求原创 IP 人物或重写整个卡池。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 以当前生产牌组/机制核对岩旅与 Ironclad 的共性与差异，说明哪些仅是表现换名，不冒称自研机制。
- [ ] #2 提出最小可行的角色差异化方案及首次十分钟可感知的特征，经 Owner 确认后实施；不擅改已冻结平衡数据、不删除历史旅行者版。
- [ ] #3 复用 TASK-85 或获批的等价角色任务完成实际正式入口、玩法与必要美术/信息呈现；代码、候选与官方 PC/安卓实测分层留证，不重复开发现有 V4 卡牌。
- [ ] #4 同候选试玩可明确辨认本作的职业机制和角色表现；未完成验收前不得宣称原创职业体验已交付。
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. 定向核对当前生产入口、岩旅牌组/遗物/资源/生成数据与 Ironclad 来源，形成可重算事实审计。
2. 基于现有冻结 V4 提供 2–3 个最小方向、首十分钟特征、UI/资产/入口依赖与分层验证出口，等待 Owner 决定。
3. 仅写 TASK-96 专属附件及必要事实 JSON，轻量 guidance/backlog/diff 校验后交主控独审；AC1 不自行勾选，AC2–4 保持未完成。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
执行者：TASK-96 事实审计；工作树 F:\New folder\.worktrees\character-identity-audit-20261103；分支 feat/character-identity-audit-20261103；基线 013535ae48198bd72616224a4729f90bb187ecd9。公开认领：PR479 评论6597919043。仅研究与提案，不参与 TASK-85 执行验证；新行为与视觉待 Owner 确认。

事实审计/提案切片已交付，待主控独审：docs/backlog-details/TASK-96-CHARACTER-IDENTITY-20261103.md；事实快照 docs/evidence/character-identity-20261103/facts.json。核实生产仅ironclad；75红牌保留原作身份、72非基础池成员一致、余烬之心映射Burning Blood胜利回血6。提供A雷电主推荐+岩旅可选（推荐）、B雷电单入口保留历史岩旅、C既有胡桃V4三个下一版本待批准方向。首十分钟拔刀不保证：初始只有两张军令，爆发需愿力3。7项输入hash/75映射/3个内存生成模块、数据交叉核对、Geo开局目录盘点及guidance/backlog/附件diff轻量检查通过；无候选/官方导入/新ready/PC或安卓证据，未运行TASK-85测试。Owner待决定是否批准A及其验收后开放边界。AC1待主控独审，AC2–4未批准/未实施/未验收，全部保持未勾，状态保持In Progress；本轮不提交、不推送、不建PR、不合并。

本批集成复核：独立审查OpenCode-gpt-6.1-sol-9450b8af-50d5-4a27-ae2a-07570e988d00实际重算75映射、初始资源、来源与3模块，主控据此接受AC1；AC2–4继续待Owner方向确认、实施及设备验收。按用户最新要求，本批先复审/CI/集成再领下一批，任务保持In Progress。

当前编号映射（2026-11-03）：本任务属于 M8/m-8 产品体验与核心特色；下文保留的旧称“M7 核心产品体验门槛”按当前 M8 理解，验收实质、负责人及既有 AC 不变。
<!-- SECTION:NOTES:END -->
