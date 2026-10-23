---
id: TASK-24
title: 当前版本产品原型、前端实现与美术打磨（Opus）
status: To Do
assignee:
  - '@opus'
created_date: '2026-10-22 15:33'
updated_date: '2026-10-22 22:46'
labels:
  - ui
  - art
  - polish
dependencies: []
references:
  - docs/SCOPE.md
  - docs/TOOLCHAIN.md
  - 'https://github.com/CHNISam/Slay-the-Abyss/pull/19'
priority: low
type: enhancement
ordinal: 25000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
纳入当前正在开发的版本，由 Opus 负责产品原型设计、前端实现与UI/美术打磨。目标是让产品流程、界面交互和视觉呈现一起达到工业级成品质感。作为贯穿当前版本开发的工作，可随功能进展进行轻量优化，也可对成熟界面深入精修，不等待后期里程碑或基础战斗反馈任务全部结束。覆盖战斗、卡牌、地图及节点、结算等当前版本界面；按实际功能成熟度逐步落实，遵守首发范围和千星平台能力边界。工具/模型名称确认为 Opus，替代此前误记的 opens。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 由 Opus 产出与当前版本范围一致的产品原型，关键流程、界面布局、交互状态和信息层级明确，并随功能进展更新。
- [ ] #2 由 Opus 将当前版本已具备的流程落实为可交互的前端界面，覆盖相应正常、不可用及结果反馈状态；原型与已实现功能的差异明确记录。
- [ ] #3 由 Opus 持续统一字体、配色、间距、卡牌、面板、图标及反馈表现；每轮按功能成熟度选择轻量优化或深入精修，保留关键设计与界面截图。
- [ ] #4 已交付界面在手机与主机画布中无出屏、重叠或关键文字不可读，核心信息及主要操作清晰；分别报告原型、前端实现、平台预览、存档导入和实机验证状态，未验证项如实列明。
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. 读平台客户端控件能力(图片库/文本/填充/补间/模板/分设备画布)，只用已上机验证的控件做设计，避免做出实现不了的东西。
2. 设计规范 docs/design/UI_DESIGN.md：视觉方向、1280x720 手机安全区优先的布局网格、色板/字号/间距 token、组件规格(卡牌/意图/血条/按钮四态)、各界面布局与状态矩阵、动效、平台控件映射、原型与实现差异表。
3. 数据驱动主题 data/presentation/ui_theme.json + 生成 Lua 模块与测试，供 TASK-10 UI 控制器 require，不改其文件。
4. 可交互 HTML 原型（战斗/地图/奖励/营地/商店/事件/宝箱/结算），1280x720 逻辑画布，仅用平台可实现的形状；截图存档。
5. 平台预览/存档导入/实机验证另行如实报告，不冒充。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
CLAIM 2026-10-22 Opus；分支 feat/task-24-ui-design；worktree .worktrees/ui-design。边界：docs/design/UI_DESIGN.md、docs/design/prototype/、data/presentation/ui_theme.json、scripts/build-ui-theme.mjs 及其测试；不改 combat/map/UI 控制器，不操作 MCP/游戏 GUI（由 /root 独占）。

2026-10-23 Opus 第一轮交付（commit 32c79a3，分支 feat/task-24-ui-design）：设计规范 docs/design/UI_DESIGN.md；主题 data/presentation/ui_theme.json 与 build:theme 生成的 abyss_theme.lua（4 项测试通过，check:rules 全绿）；可交互原型 docs/design/prototype/index.html，覆盖 12 个界面，截图在 docs/design/screens。方向：旅行者·岩，主色琥珀金，稀有度沿用原神星级配色。AC1 原型已完成。AC2/AC3 只完成了原型和 token，平台控件实现属于 TASK-10 等界面任务。AC4 只在原型层检查过安全区；编辑器多设备预览、存档导入、真机都未做，手机平台按键区是否与结束回合按钮冲突待用 editor_preview_interface 确认。图库 verify 组需人工核对。

2026-10-23 追加 1e51b5c：按用户要求在原型中加入拖牌和甩牌，自动化拖动测试中三种情况都通过；平台实现按 A 跟手 / B 假拖动 / C 点选三档降级，A、B 未验证。交接：PR #19（feat/task-24-ui-design → develop），等待审查合并；平台实现由 TASK-10 等界面任务按 docs/design/UI_DESIGN.md 落地。

2026-10-23 用户明确批准PR #19作为整个游戏美术与界面设计依据，已squash合入develop（91ae349）。PR头提交本地npm run check通过：58 JS、15 Lua、11 Python（1 skip）；GitHub Quality成功。AGENTS/SCOPE/HANDOFF将持久化准则。战斗界面由/root/battle_design在battle-ui树独立推进TASK-10；地图界面由/root/map_design在map-ui树推进TASK-12，均先对齐共享theme并记录平台差异，不操作MCP/存档或虚报实机。TASK-24仍为In Progress，平台实现AC未验收。源表保护任务重号已用backlog doctor修复为TASK-27，现有美术引用保留。

2026-10-23 用户P0指令：暂停非必要美术扩量、技术研究；资源转TASK-3完整游戏集成冒烟与TASK-5真实15层回归，冒烟通过后才恢复。
<!-- SECTION:NOTES:END -->
