---
id: TASK-80
title: 按节点职责拆分原生界面
status: Done
assignee:
  - Furinya
created_date: '2026-10-28 15:26'
updated_date: '2026-10-28 15:57'
labels: []
dependencies: []
priority: medium
ordinal: 124000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
专项重构Node UI，保持最新develop的正式控件、布局、反馈及节点交易语义。技术方案与证据见docs/plans/2026-10-28-node-ui-refactor.md。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 主文件≤1000行且主构造器≤350行
- [x] #2 商店、营地、事件、宝箱、奖励及输入所有权按真实职责拆分
- [x] #3 旧新行为对照与必要交互回归通过，玩法及价格不变
- [x] #4 独立PR，不修改Combat、Run或CI
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
固定1f260a71；抽取实例上下文与职责模块；检查旧新控件和交易结果；运行回归与规模门禁；交付独立PR。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
已从1f260a71建立独立分支。职责拆分、旧高复杂度函数细分和新增两项手势回归已落地；固定Luacheck通过且无新增诊断，删除13条已消除的Node UI历史静态基线。用户明确授权仅适配静态检查器函数定位与规模门禁，未修改.github工作流。旧新快照对照及完整JS回归正在执行。实机未操作。

旧新9组快照全部一致：40组节点+22组手势，哈希与源码身份已归档docs/evidence/node-ui-refactor-20261028.json。主文件245行、构造器221行、最大提取工厂309行；300项Node UI职责复杂度测量最高15。12项布局/检查器/规模回归、静态、架构、语法、Backlog检查通过。未修改Combat/Run/CI工作流，未做官方导入或实机。完整本地npm test已中断，不记完整通过。

最终串行手势22/22通过，17670ms，保留30000ms原期限。

独立PR #310：https://github.com/CHNISam/Slay-the-Abyss/pull/310。仅交付Node UI源码、必要回归、静态门禁授权适配与文档；无Combat/Run/CI工作流改动。最终离线验收全部满足，完整Quality按PR当前SHA单独核对。
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
主文件245行、构造器221行，最大提取工厂309行；300项Node UI函数复杂度最高15。商店/营地/事件/宝箱/奖励/输入职责独立。40节点+22手势的9组旧新控件及真实状态快照逐byte一致，22项手势串行17670ms通过；12项布局/检查器/规模、静态/架构/语法/Backlog检查通过。独立PR310。官方导入、实机和完整Quality不以本地结果替代。
<!-- SECTION:FINAL_SUMMARY:END -->
