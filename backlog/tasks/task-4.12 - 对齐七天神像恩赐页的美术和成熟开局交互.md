---
id: TASK-4.12
title: 对齐七天神像恩赐页的美术和成熟开局交互
status: In Progress
assignee:
  - Furinya
created_date: '2026-10-30 21:58'
updated_date: '2026-11-02 02:20'
labels:
  - playtest-20261030
  - p1
  - grok
milestone: m-5
dependencies: []
references:
  - docs/backlog-details/PLAYTEST-20261030.md
  - docs/backlog-details/MOBILE-QA-20261029.md
  - backlog/tasks/task-95 - 对照验证美术、交互与动效设计工具.md
parent_task_id: TASK-4
priority: medium
type: enhancement
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Owner截图：七天神像由矩形圆片拼成，左右空旷、恩赐选项简单罗列，缺少与人物交谈及开局氛围。目标是尽可能移植原版涅奥交互的体验与信息层次，以原神/提瓦特获许可内容适配；不能直接搬运受版权保护实现。GPT负责任务13.1.3中的事件内容逻辑。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 七天神像的场景主体是正式可接受的美术表现，不再以简单几何占位拼装充当成品。
- [ ] #2 恩赐交互与角色对话在视觉和操作上连贯，能接入已批准的实际内容及分支，正常进入后续冒险。
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. 接续403原两提交，仅修恩赐完整说明可读、原生RGB与历史截图来源。2. 用真实Host首次mini及合法full历史入口核对说明和代价，验证普通事件布局恢复，不改随机和池。3. 定向检查交独立评审；原图仅静态布局，官方/设备与神像正式美术未验。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
403必要修复切片：真实Host首次mini2及两幕受控结算后session-completed-run合法full4，完整奖励/代价严格对应Neow.options且说明可见；普通事件复用恢复尺寸。原生RGBA编码与布局几何回归通过；原4PNG已看图核hash登记为强制历史/无脚本静态布局，未当作本轮玩法证据。官方导入、手机与正式神像美术仍未验，AC不勾。

本轮定向16项、真实Host formal4组及Neow UI8组、native契约4项通过；license inventory通过；工程quality/architecture/Luacheck无新诊断，复杂度上限不变，4个既有mutation全部被有效断言杀死。仅提取原底部notice选择满足复杂度，未改随机/池/奖励/商店规则。无全量CI、无官方/设备验收，待主集成独审。

UI合流补充：开局顶栏按既有roomKind=neow显示七天神像，普通事件仍保原标识；真实mini/full及普通事件复用回归已通过。组合发现新官方背景/晕影/气泡未进旧精确图ID白名单，新增命名token逐一变异传播断言与精确白名单，未放宽RGBA或任意图ID许可。仍无官方/手机验收，不勾AC。

2026-11-02最新排期：优先M4非美术、非交互设计工程。神像成品美术与角色对话整体新方案先取TASK-95对应实验结论；已明确的恩赐说明可读性、颜色与入口/分支缺陷可继续修复，既有批准内容与已交付实现不重做。 仅对应新增正式设计切片以实验结论为前置；未来纯设计优化子任务显式依赖TASK-95并引用适用Go结论。本混合任务不新增整任务硬依赖，原状态与AC保留。
<!-- SECTION:NOTES:END -->
