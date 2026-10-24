---
id: TASK-16
title: 完整实现初代战士75张卡牌
status: In Progress
assignee:
  - '@Codex'
created_date: '2026-10-22 13:48'
updated_date: '2026-10-24 18:45'
due_date: '2026-10-28'
labels: []
milestone: m-4
dependencies:
  - TASK-9
  - TASK-14
references:
  - docs/backlog-details/TASK-16.md
  - docs/reviews/TASK-16-m3-card-audit.md
  - docs/reviews/TASK-16-warrior75-matrix.md
priority: high
ordinal: 16000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
正式交付完整75张初代《杀戮尖塔》PC正式版Ascension 0铁甲战士卡牌。逐张复刻基本版、升级版、获取规则与全部交互，不允许缩减为30张、占位效果或近似规则。来源核验、自动回归、平台与自然实玩证据分别保存，缺口如实报告并继续推进。详见 docs/backlog-details/TASK-16.md。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 75张逐张保存可靠原版依据，费用、数值、类型、稀有度、目标、条件、关键词及执行顺序均核验，未知项不能计通过。
- [ ] #2 完整75张基本版和升级版可正确执行，初始牌组、X费用、无限升级与特殊获取规则正确，不含占位或近似效果。
- [ ] #3 奖励、商店、生成、复制、消耗回收及营地升级遵守原版规则，原版名称与效果对应，未实现项明确阻塞最终验收。
- [ ] #4 逐牌及升级独立预期回归通过，完整消耗组合、抽弃牌、持续能力和特殊交互经真实入口验证。
- [ ] #5 同一候选保存平台导入与自然获取使用记录，75张最终验收齐全；代码、本地测试、导出、导入、实机分层报告。
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. 从最新origin/develop隔离工作树，纠正范围、首发清单和排期，复用TASK-16/16.1/47不重复建任务。2. 以参考75卡盘点并逐张复核固定原版方法链，记录未核实项。3. 先实现消耗/选择/触发公共机制，再逐卡补基本升级、费用、生成与获取。4. 用独立预期验证逐卡及组合，完整本地门禁通过后统一构建和实机验收。10/25-27实现与核对，10/28平台及自然构筑，10/29同RC回归；未完成即报告10/30风险，绝不缩池或虚报。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
2026-10-24逐卡审计：30张constructor/use/upgrade重新下载并逐件验证Git blob，另核AbstractCard、Ironclad、EntanglePower和版本字段4件；来源身份及逐卡费用、基本升级效果、目标、条件、测试映射见docs/reviews/TASK-16-m3-card-audit.md及docs/evidence/card-audit-m3。没有找到需要改费用/数值的差异。确认两项严格差异：Shockwave双敌Weak/Vulnerable由逐敌变成逐状态；重复Barricade多发amount0状态帧，三条基本/升级诊断strictExpectedMatch=false，按协调留TASK16/16.1待修，未动Combat/Effects。已有card_pool 93/93、新card_use_requirements 60/60通过；原作构建真实性、共享完整队列/钩子、自然构筑和平台/实机仍未验，AC全未勾，保持In Progress。

2026-10-25用户否决首轮30张缩减，完整75张为正式交付和最终验收目标，覆盖旧30张口径。隔离基线origin/develop 695d94d；不复用旧30卡实机证据冒充75卡。

2026-10-25隔离候选：75张基本/升级150组真实Combat基础执行、6组消耗联动、28组边界、7组原版奖励/商店随机契约、75条公共获取/营地/下一战事务及1项真实控件树选牌通过；均非平台/自然实玩。复用051f9a1原版池目录，接72非基础奖励/typed商店原序、共享cardRng和独立cardRandomRng。正在修复完整旧回归及统一候选，AC仍全部未勾。免费委派未调用：既往限额窗口未知，本机CLI日志路径当前不可写；Codex接管，费用节省未知。

2026-10-25完整75卡执行进展：已提交共享动作/选牌/消耗体系和全部75张候选，150个基础/升级独立执行、75个实际商店/初始获取→营地升级→下一战事务，以及消耗/复制/死亡/洗牌专项通过。补正既有30张与旧30卡池测试假设；Node全量1104通过118既有环境跳过，呈现21通过1跳过。已发现并修复Havoc/DoubleTap等待动作尾部、同优先级能力施加顺序和Rampage同身份成长。全量Lua仍在复验，不能算整体通过。50模块候选构建0静态错误34警告；首个复用音频基底候选审计有空BGM图多余，已重建干净基底，待读回审计。首次官方试玩请求因另一工作区占用窗口被工具拒绝，未启动导入，逐卡平台仍未验。完整75张与10/28验收目标保持，不削减、不勾AC。
<!-- SECTION:NOTES:END -->
