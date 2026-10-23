---
id: TASK-3.1
title: M1 战斗候选平台构建与副本导出
status: Done
assignee:
  - '@Codex'
created_date: '2026-10-22 22:20'
updated_date: '2026-10-23 03:16'
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
- [x] #1 当前提交的真实战斗入口及全部模块通过平台检查/编译，并生成存档副本；记录SHA、工具输出和副本hash
- [x] #2 liveWrite保持0，原存档hash前后相同；检查非空战斗模块与挂载，不能用空checked通过
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
从已合develop be5093f建立同版本候选；只读正式底图1073741825并复制到仓库artifacts，记录正式文件hash前后。先读workflow/platform-rules/client-lua；使用现有build-native-candidate（不传playtest）写完整Lua/UI/结算图到副本，检查非空模块和挂载并记录工具输出/hash。游戏导入/试玩不执行。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
2026-10-23真实平台尝试：20步完成（最小配置及Lua模块写副本），第21步scene_add_client_ui INVALID_ARGUMENT：controls[1].children[1].children超过60个直接子控件。副本静态检查0errors/10warnings，缺完整UI，不能判为构建成功。下一动作：对超限容器分组并适配路径→真实控件回归→重试导出；不要重复空跑试玩。原存档hash未改，证据docs/evidence/milestone-platform-audit.json。

P0后续已越过旧阻塞：完整UI容器分组、Color和SetImage修复后，完整游戏v4-v6已生成并由用户导入独立测试存档试玩；build-native-candidate脚本固化构建。版本证据见docs/P0-SMOKE.md，尚未对合并后的最新提交重建同一候选并补齐全部AC证据，保持In Progress。

已从已合代码be5093f构建完整副本，未传playtest且liveWrite=0：21个Lua模块静态检查0errors/12warnings，1178控件、最大50直接子、四主面板/abyss_ui主脚本读回存在；结算服务端图22节点/编辑计数72编译写入并启用挂stage。副本SHA256 3e450284ff5b8096ea5836a1e12639ff702775e301788cf6e40b39e57e1ecb6a；正式底图6e82decfb9b113310ba97c0cad5cf541288c0cada5cb52644a0dd8785004a432前后相同。结构化证据docs/evidence/offline-candidate-be5093f.json，原始工具输出.artifacts/m1-offline-be5093f。21模块非空检查；官方导入/实机NOT_TESTED。等待独立复核12条跨模块方法warning及任务范围后仅收构建切片。

独立复核通过：实际gil中21份Lua源文逐份等于be5093f；重跑checkClientScripts仍0errors/12个已定位跨模块方法warning；UI与图挂载非空。另以原底图和编译main.gia内存重注入，输出字节与候选完全一致。原文件hash与source-base及前后记录一致。关闭的仅为构建副本切片，TASK2/3.2/3继续未完成。
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
从be5093f生成真实完整平台副本，21模块检查0错误，1178控件及22节点结算图已写入挂载；候选SHA256 3e450284ff5b8096ea5836a1e12639ff702775e301788cf6e40b39e57e1ecb6a，正式底图前后hash相同。独立解析、源文比对和内存重注入验证通过；官方导入/实机未执行。证据docs/evidence/offline-candidate-be5093f.json。
<!-- SECTION:FINAL_SUMMARY:END -->
