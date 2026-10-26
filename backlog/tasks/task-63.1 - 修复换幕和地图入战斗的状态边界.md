---
id: TASK-63.1
title: 修复换幕药水修正和检查点章节边界
status: In Progress
assignee:
  - '@Furinya'
created_date: '2026-10-26 09:41'
updated_date: '2026-10-26 10:15'
labels: []
milestone: m-4
dependencies: []
parent_task_id: TASK-63
priority: high
type: bug
ordinal: 110000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
独立复审复现换幕后真实药水掉落修正残留，以及当前边界检查点接受其他章节的合法遭遇队列。仅修复两处已实现跨幕代码的状态边界，不扩展章节内容。主线地图入战斗代次修复独立交付，避免等待未合入的章节功能。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 换幕重置真实药水掉落修正且失败事务不泄漏状态
- [ ] #2 检查点恢复拒绝其他章节的合法队列，原边界正常恢复仍通过
- [ ] #3 两项反例先红后绿，现有跨幕和检查点回归保持
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. 两项独立反例先红，覆盖真实药水owner与公开换幕边界。2. 最小修复potionChanceModifier重置和queue章节一致性。3. 验证原子失败/旧第一幕合同与既有跨幕回归，待PR213协调接入后复核准确SHA。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Executor: dot。仅在自有云独立工作树 feat/dot-run-boundary-fixes 基于 PR213 head204314b 准备补丁；不直接修改 PR213 分支或其他执行者工作区。Owner 09:35 UTC 授权已确认问题修复、测试、PR及合并；已在PR213评论6412861187公开具体反例与独立边界，接入前重新核对作者更新，禁止重复覆盖。父任务内容和认领不变。

交付边界调整：Nodes入战斗代次缺陷在develop已存在，拆出独立主线修复，不将PR213整套功能或license夹带进小修复；本任务只保留跨幕两项。已完成的节点反例/补丁复用，不重复开发。

两项修复分别红灯后，potion2/2和checkpoint3/3通过，原跨幕12与checkpoint4通过；独立复审未发现阻断问题。Nodes修复与3组回归移入TASK-59.2.1作为独立主线交付，不在本任务重复领取；跨幕部分不夹带未合并PR213的完整功能或license。

已核对PR213更新为c2fef7b，Run/Nodes/原cross_act源码与旧204314b逐文件无差异；独立工作树已快进到最新候选。节点单行修复和回归已从此候选移出，改由主线PR221交付；本候选只含两处跨幕修复，接入前仍核对PR213/主线状态。
<!-- SECTION:NOTES:END -->
