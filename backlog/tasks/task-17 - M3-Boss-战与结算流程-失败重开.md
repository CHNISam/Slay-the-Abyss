---
id: TASK-17
title: M3 Boss 战与结算流程 + 失败重开
status: In Progress
assignee:
  - '@Codex'
created_date: '2026-10-22 13:48'
updated_date: '2026-10-22 23:19'
due_date: '2026-10-28'
labels: []
milestone: m-4
dependencies:
  - TASK-16
  - TASK-15
priority: high
ordinal: 3
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
第一幕 Boss 战、通关结算界面与失败重开闭环。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Boss 有独立阶段与意图
- [ ] #2 击败 Boss 后正式结算（战绩/用时/卡组成果）
- [ ] #3 失败可重新开始，无残留状态
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
复用已实际验证的客户端第15层失败/重开闭环。恢复批准稿结果双按钮，结果阶段才允许向ABYSS_WIN/LOSE发送单次结算请求；服务器图按真实graphId设置胜败并settleStage。主Agent只写副本并区分本地测试、图编译、存档导入、官方结算实机验证。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
P0 集成审计：77744e2只有客户端首领胜利摘要与重新启程，尚无settleStage正式平台结算接线，明确为未实现；真实Boss通关与失败重开未验证。复用本任务，不新建重复任务。

当前在第五版HP/商店实机复验同时补正式结算现有缺口。代码Agent只改离线UI适配/服务器图生成器与测试；主Agent独占MCP编译/写测试副本。无正式发布。

第六版正式失败结算实机通过：用户在第1层战败（HP0/80、金币99、卡组10、遗物1），自定义失败页显示重新启程及结束并结算；点击后实际进入平台官方失败界面，显示离开/重新挑战。真实截图归档 .artifacts/p0/defeat-result-v6.png 与 official-defeat-settlement-v6.png；候选SHA256 CE9076F4295A7A9B415E9BB160E3FCFE1B552C72D71BF330F48B8ADB8FC2E752。仅失败分支通过，Boss胜利/胜利正式结算和平台重新挑战后的资源重置未验证；保持In Progress。
<!-- SECTION:NOTES:END -->
