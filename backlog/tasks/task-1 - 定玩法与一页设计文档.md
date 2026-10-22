---
id: TASK-1
title: M0 工具链与参赛通道核验
status: In Progress
assignee: []
created_date: '2026-10-22 13:32'
updated_date: '2026-10-22 14:38'
due_date: '2026-10-23'
labels: []
milestone: m-1
dependencies: []
priority: high
ordinal: 1000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
确认开发工具链与参赛通道可用：MCP 连通、千星沙箱能建存档、赛事报名入口与收益功能状态。这是所有开发的前置。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 千星沙箱可打开并新建超限模式存档，记录存档名
- [ ] #2 确认赛事报名入口（上传界面-赛事报名）与创作者中心收益功能已开通
- [x] #3 MILIASTRA_ALLOW_LIVE_WRITE=0 生效，只写存档副本
- [x] #4 miliastra MCP 连通：get_capabilities 返回 v0.1.0，workspace 与 Python 3.12 路径正确
- [x] #5 本机存在超限模式存档且 list_maps 能列出（需人在游戏内新建并保存一次）
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
2026-10-22 核验：miliastra MCP 连通（v0.1.0 / genshin-ts 0.2.2，workspace=D:\\MiliastraTools\\genshin-miliastra-mcp\\workspace，Python=3.12.10，saveRoots=AppData\\LocalLow\\miHoYo\\原神\\BeyondLocal，liveWriteEnabled=false 确认只写副本）。list_maps 返回空：本机尚无任何千星奇域存档。list_editor_windows 返回空：原神/千星沙箱未运行（已拉起米哈游启动器，PID 19524）。阻塞：需人在游戏内【我的奇域→新建存档（超限模式）】并保存一次，之后复检 #1/#5；#2 赛事报名入口与收益功能需人确认。

2026-10-22 主Agent复检：Furinya已创建并保存杀戮深渊；MCP list_maps识别mapId1073741825/name杀戮深渊/21859bytes（此前87bytes空壳），窗口原神运行。get_capabilities liveWriteEnabled=false、genshin-ts0.2.2，Python3.12保持；只读验证，未写入正式或副本。#2赛事报名入口及收益开通仍未获得人工确认，保持In Progress，不解锁依赖TASK2。用户截图显示奇匠Lv1，与旧工具链Lv15记录不一致，后续实际验证文字显示。
<!-- SECTION:NOTES:END -->
