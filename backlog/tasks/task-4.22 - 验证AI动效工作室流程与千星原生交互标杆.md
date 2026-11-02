---
id: TASK-4.22
title: 验证设计Skills与工具流程及千星原生交互标杆
status: To Do
assignee:
  - Furinya
created_date: '2026-10-31 10:47'
updated_date: '2026-11-02 02:25'
labels:
  - art
  - motion
  - technical-spike
  - design-workflow
milestone: m-5
dependencies: []
references:
  - docs/backlog-details/PLANNING-CONSOLIDATION-20261031.md
  - 'https://github.com/CHNISam/Slay-the-Abyss/pull/423'
  - docs/TOOLCHAIN.md
  - docs/design/UI_DESIGN.md
parent_task_id: TASK-4
priority: medium
type: spike
ordinal: 135000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
由 DRAFT-7 / PR423 原生晋升，承接用户本轮要求：先用成熟 Skills 与实际工具验证美术、交互和动效方法，再决定新增正式优化；不重做已交付成果，不阻塞非设计工程、缺陷修复和现有功能回归。沿用 dream-loop-evidence，按需组合成熟 Skills；同一设计问题比较真实产出，不以工具数量或口头评分替代效果。结论供 TASK-4、TASK-25.4、TASK-4.13、TASK-29.1 的新增设计切片使用。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 核实目标Agent实际加载的frontend-design、ui-animation、emil-design-eng、improve-animations、review-animations及工具，只补真实缺口。
- [ ] #2 选择一个高频战斗交互交付原生可运行A/B标杆，保留动态回放、输入与复现脚本；纯HTML不算平台成果。
- [ ] #3 至少两轮独立视觉批评与精修，评价跟手、节奏、缓动、连续性、音画及中断取消；现有输入和控件回归无倒退。
- [ ] #4 记录原生API、资源及性能边界，模拟器与官方PC/实体安卓证据分开；未实机不宣称通过。
- [ ] #5 交付前后对照、有效Skills/MCP清单和Go/No-Go，未经批准不扩大UI重构、不改玩法、默认美术开关或发布候选。
- [ ] #6 对照记录同一 brief、输入资产、实际 Skill/工具版本或渠道、截图与结论；区分已试、不采用、正在试、未试和实际阻塞，不将用户看法写成供应商能力结论。
- [ ] #7 新增设计先经独立视觉评审达到 >=9 分并获用户认可，才推进动效、Simulator 操作与录像，再交原生可导入候选及用户真机；各层证据独立，缺失层保持未验证。
- [ ] #8 优先复用官方原神/千星图标并核对平台可用性与授权，统一封面视觉；保留原版核心信息、路径决策和输入语义，不以恐怖自制图标或装饰替代可读性。
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
先固定原版核心体验、封面风格、真实数据与性能边界，以同一 brief / 输入做有限轮对照；记录实际加载的 Skill 版本、工具渠道和复现证据，不要求无关 Skill 全装。用户现状：Grok bot 实测不满意；Cursor 不考虑（非测试失败）；Google AI Studio 的“Gemini 3.8 Flash”正在试（名称按用户口述，未核实厂商规格）；Antigravity 未试且用户报告使用问题，先复现解决；OpenDesign、Figma Make 可试。候选工具不等于已接入或有效，不自动购买或占用用户 Codex。
先交独立视觉评审及静态对照；达到真实 >=9 分且用户认可后再做动效/交互、Simulator 回放，继而原生可导入候选与用户真机验收。原有至少两轮评审要求保留，预设预算；不达标则记录 No-Go/待决策，禁止无限刷分。
<!-- SECTION:PLAN:END -->
