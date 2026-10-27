---
id: TASK-63.1
title: 修复换幕药水修正和检查点章节边界
status: Done
assignee:
  - '@Furinya'
created_date: '2026-10-26 09:41'
updated_date: '2026-10-27 04:15'
labels: []
milestone: m-4
dependencies: []
parent_task_id: TASK-63
priority: medium
type: bug
ordinal: 110000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
独立复审复现换幕后真实药水掉落修正残留，以及当前边界检查点接受其他章节的合法遭遇队列。仅修复两处已实现跨幕代码的状态边界，不扩展章节内容；地图入战斗代次修复另属TASK-59.2.1，不重复计入。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 换幕重置真实药水掉落修正且失败事务不泄漏状态
- [x] #2 检查点恢复拒绝其他章节的合法队列，原边界正常恢复仍通过
- [x] #3 两项反例先红后绿，现有跨幕和检查点回归保持
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

父PR213已合入e3a9fe2，等待已解除。PR222两处补丁已与PR221合成同一主线候选；最新父基线重新实跑potion2/checkpoint3/原跨幕12通过。PR222将作为被整合草稿收口，不重复计交付；当前新SHA完整CI和合入仍待完成。
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
PR222两处补丁在父PR213合入后统一进PR221，现已合入4bbd151。真实药水owner重置2/2、异幕checkpoint拒绝与旧第一幕兼容3/3、原跨幕12组通过，均有红灯及原子失败/对象身份对照。最终准确head3a3bf6a完整Quality/Licenses成功并完成独立复审；只关闭这两处代码缺陷，未增加后续章节内容、自然通关或平台验收。证据：https://github.com/CHNISam/Slay-the-Abyss/pull/221；PR222为被吸收草稿，不重复计交付。
<!-- SECTION:FINAL_SUMMARY:END -->
