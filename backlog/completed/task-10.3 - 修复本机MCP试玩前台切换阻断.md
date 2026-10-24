---
id: TASK-10.3
title: 修复本机MCP试玩前台切换阻断
status: Done
assignee: []
created_date: '2026-10-22 16:19'
updated_date: '2026-10-22 16:51'
labels: []
dependencies: []
parent_task_id: TASK-10
type: bug
ordinal: 29000
---

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 复用成熟双队列焦点策略并保留失败退出，原件与可回滚补丁有据
- [x] #2 记录失败复现与修复后真实运行结果，不以mock或启动成功冒充游戏通过
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
对比现有win_input成功路径，最小修补runner焦点回退；保存原SHA和补丁，独立只读复核后实际运行一次。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
CLAIM /root feat/task-10-3-platform-focus/.worktrees/platform-focus；仅工具修补证据和该子任务。GUI独占主Agent；battle-ui由另一个/root/battle_design接手视觉对齐，本Agent不共享编辑其工作区。三次playtest均导入前因focus失败，停止相同重试。
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
本机runner双队列焦点最小修补完成，非作者复核、四类模拟与未知版本失败关闭测试通过；已保存原件/diff/前后hash。真实run7675e481通过焦点后停在文件选择框，未实机通过。只读Token证实自动化中0x2000而游戏/编辑器高0x3000，已请用户统一权限；正式存档SHA256与修改前完全相同。后续导入/游戏在TASK10继续。
<!-- SECTION:FINAL_SUMMARY:END -->
