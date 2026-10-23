---
id: TASK-3.2
title: M1 战斗存档副本导入验收
status: Done
assignee:
  - '@Codex'
created_date: '2026-10-22 22:20'
updated_date: '2026-10-23 16:33'
labels: []
milestone: m-2
dependencies:
  - TASK-3.1
parent_task_id: TASK-3
priority: high
ordinal: 35000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
原TASK-3导入阶段独立验收，导出成功不等于游戏接受。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 官方编辑器实际导入同一候选副本并可打开，记录分配的存档编号、截图与导入日志
- [x] #2 导入后复读战斗脚本/控件/镜头和出生配置，核对没有导入空白或错误存档
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
固定5165候选经官方UI导入为独立测试存档，记录run和截图；冻结官方存档及外部Lua后独立复读同源、UI与场景配置，正式试玩核对可打开。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
P0用户已实际导入完整v4-v6测试副本，主流程及v6正式失败结算有截图；v1/v2已复读新增存档编号与脚本/UI。当前候选SHA及证据见docs/P0-SMOKE.md，尚需对合并后的同一版本补全存档编号和配置复读记录，保持In Progress。

TASK-29/PR52候选已由用户手动导入并打开，官方新存档1073741834（abyss-feedback-ca202b8），20个Lua脚本复读内容一致（仅官方UTF-8 BOM差异）。用户确认攻击/格挡/敌方逐次行动可见；当前真实胜利奖励截图和详细边界见docs/COMBAT_FEEDBACK.md。本轮无新日志，音效未确认；不据此关闭完整导入/实战验收任务。

2026-10-23独立证据审计确认原61425e4官方存档1073741835已含32内嵌/外部Lua同源、1590控件/模板及镜头/出生配置复读，AC2可据此勾选。读回也证实该候选场景配置不合TASK2，scene-safe v2已补但尚未导入。AC1导入日志与整体继续保留。报告.artifacts/m1-audit/platform/REPORT.md。

2026-10-24新真实证据：固定源5165a78，候选hash8ff910c6772c729cf86cf26dd9d48f73c2de4ccffdf5fbc1b0029d9286f54288，官方导入测试save1073741838，run9bb0abe3-9602-418b-a729-25fc739523c2实际imported/opened-and-saved并进入完整战斗。32内嵌/32外部Lua、1695UI/模板、镜头出生复苏/单人阵营/全部图挂载独立复读一致；图身份/22节点一致，官方重序列化完整payload未认证，不扩大为语义证明。repo内docs/M1-LIVE-ACCEPTANCE.md及docs/evidence/m1-live-5165a78.json保留读回、截图、64条新日志及hash。
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
官方同候选导入切片通过：测试存档1073741838、run9bb0abe3，32内嵌/外部Lua及1695UI和场景配置复读相符；真实战斗与奖励已可打开操作。图完整往返、九状态、真实复苏与UI总门禁不随本任务关闭。
<!-- SECTION:FINAL_SUMMARY:END -->
