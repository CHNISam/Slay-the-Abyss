---
id: TASK-1
title: M0 开发工具链与发布入口初步定位
status: Done
assignee: []
created_date: '2026-10-22 13:32'
updated_date: '2026-10-22 22:19'
due_date: '2026-10-23'
labels: []
milestone: m-1
dependencies: []
priority: high
ordinal: 8000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
开发前置仅验工具连通、安全副本策略、已保存可识别存档及入口定位。正式表单核验见TASK-18/19、最终报名见TASK-6。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 千星沙箱可打开并新建超限模式存档，记录存档名
- [x] #2 MILIASTRA_ALLOW_LIVE_WRITE=0 生效，只写存档副本
- [x] #3 miliastra MCP 连通：get_capabilities 返回 v0.1.0，workspace 与 Python 3.12 路径正确
- [x] #4 本机存在超限模式存档且 list_maps 能列出（需人在游戏内新建并保存一次）
- [x] #5 完成实名认证并开通国服创作收益功能
- [x] #6 发布入口初步定位与操作SOP已落仓（docs/PUBLISHING.md / PR8），正式界面核验保留在TASK-18/19
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
核对既有MCP取证和人工确认，复检本机存档；将正式表单验证保留于M4。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
2026-10-22 核验：miliastra MCP 连通（v0.1.0 / genshin-ts 0.2.2，workspace=D:\\MiliastraTools\\genshin-miliastra-mcp\\workspace，Python=3.12.10，saveRoots=AppData\\LocalLow\\miHoYo\\原神\\BeyondLocal，liveWriteEnabled=false 确认只写副本）。list_maps 返回空：本机尚无任何千星奇域存档。list_editor_windows 返回空：原神/千星沙箱未运行（已拉起米哈游启动器，PID 19524）。阻塞：需人在游戏内【我的奇域→新建存档（超限模式）】并保存一次，之后复检 #1/#5；#2 赛事报名入口与收益功能需人确认。

2026-10-22 主Agent复检：Furinya已创建并保存杀戮深渊；MCP list_maps识别mapId1073741825/name杀戮深渊/21859bytes（此前87bytes空壳），窗口原神运行。get_capabilities liveWriteEnabled=false、genshin-ts0.2.2，Python3.12保持；只读验证，未写入正式或副本。#2赛事报名入口及收益开通仍未获得人工确认，保持In Progress，不解锁依赖TASK2。用户截图显示奇匠Lv1，与旧工具链Lv15记录不一致，后续实际验证文字显示。

2026-10-22 用户明确确认已完成实名认证并开通国服创作收益；原合并验收项拆分，收益部分完成，赛事报名入口未核验，任务保持 In Progress。
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
MCP连通且liveWriteEnabled=false；list_maps复检杀戮深渊1073741825/22101bytes；用户已确认收益开通。PR8发布SOP已合并。正式报名未验证，保留TASK-18/19/6。
<!-- SECTION:FINAL_SUMMARY:END -->
