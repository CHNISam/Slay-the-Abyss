---
id: TASK-3.2
title: M1 战斗存档副本导入验收
status: In Progress
assignee:
  - '@Codex'
created_date: '2026-10-22 22:20'
updated_date: '2026-10-23 01:36'
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
- [ ] #1 官方编辑器实际导入同一候选副本并可打开，记录分配的存档编号、截图与导入日志
- [ ] #2 导入后复读战斗脚本/控件/镜头和出生配置，核对没有导入空白或错误存档
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
P0用户已实际导入完整v4-v6测试副本，主流程及v6正式失败结算有截图；v1/v2已复读新增存档编号与脚本/UI。当前候选SHA及证据见docs/P0-SMOKE.md，尚需对合并后的同一版本补全存档编号和配置复读记录，保持In Progress。

TASK-29/PR52候选已由用户手动导入并打开，官方新存档1073741834（abyss-feedback-ca202b8），20个Lua脚本复读内容一致（仅官方UTF-8 BOM差异）。用户确认攻击/格挡/敌方逐次行动可见；当前真实胜利奖励截图和详细边界见docs/COMBAT_FEEDBACK.md。本轮无新日志，音效未确认；不据此关闭完整导入/实战验收任务。
<!-- SECTION:NOTES:END -->
