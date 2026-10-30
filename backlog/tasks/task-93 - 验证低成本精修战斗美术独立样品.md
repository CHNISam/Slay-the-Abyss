---
id: TASK-93
title: 验证低成本精修战斗美术独立样品
status: In Progress
assignee:
  - Furinya
created_date: '2026-10-30 15:26'
updated_date: '2026-10-30 22:08'
labels: []
dependencies: []
priority: medium
ordinal: 131000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
独立快速实验，比较现有矩形重建与成熟替代路线，复用真实资源和Lua，交付可运行样品与明确的官方导入边界。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 可运行样卡与背景样品，具备选牌交互和实际截图
- [ ] #2 提供同源新旧对象数量和离线测量，官方设备未测明确标识
- [ ] #3 交付官方候选或记录真实阻碍及可复现样品
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
核对现有资源与上游能力；用已有源码制作单卡及背景切片；模拟器运行截图并修正；尝试现有候选入口，记录证据。

按用户2026-10-31授权，将首轮离线探针作为独立实验PR合入develop；保留原始质量与实机未验收标记。当前HEAD完整CI与独立复审并行，通过交付校验后精确SHA squash合并。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
首轮103控件三卡交互探针已在beyond-simulator-mcp 0.5.2运行，AI查看截图并修正颜色、层序、API参数和手机缩放；导出界面/脚本两份GIA，脚本需重挂。证据experiments/art-tech-lab/README.md、verification.json。图标替代未达到原插画质量目标；同源性能、完整战斗、独立审查与官方实机仍未完成，不勾AC、不标Done。
<!-- SECTION:NOTES:END -->
