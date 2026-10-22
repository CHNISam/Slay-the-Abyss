---
id: TASK-3.1
title: M1 战斗候选平台构建与副本导出
status: In Progress
assignee:
  - '@Codex'
created_date: '2026-10-22 22:20'
updated_date: '2026-10-22 23:24'
labels: []
milestone: m-2
dependencies:
  - TASK-2
  - TASK-8
  - TASK-9
  - TASK-10
  - TASK-11
parent_task_id: TASK-3
priority: high
ordinal: 34000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
分离原TASK-3编译与写副本阶段。当前主存档无graphs/UI，scene_check_client checked为空，零错误不是战斗构建成功。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 当前提交的真实战斗入口及全部模块通过平台检查/编译，并生成存档副本；记录SHA、工具输出和副本hash
- [ ] #2 liveWrite保持0，原存档hash前后相同；检查非空战斗模块与挂载，不能用空checked通过
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
2026-10-23真实平台尝试：20步完成（最小配置及Lua模块写副本），第21步scene_add_client_ui INVALID_ARGUMENT：controls[1].children[1].children超过60个直接子控件。副本静态检查0errors/10warnings，缺完整UI，不能判为构建成功。下一动作：对超限容器分组并适配路径→真实控件回归→重试导出；不要重复空跑试玩。原存档hash未改，证据docs/evidence/milestone-platform-audit.json。

P0后续已越过旧阻塞：完整UI容器分组、Color和SetImage修复后，完整游戏v4-v6已生成并由用户导入独立测试存档试玩；build-native-candidate脚本固化构建。版本证据见docs/P0-SMOKE.md，尚未对合并后的最新提交重建同一候选并补齐全部AC证据，保持In Progress。
<!-- SECTION:NOTES:END -->
