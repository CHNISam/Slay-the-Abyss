---
id: TASK-53
title: 确认断网后能否继续本局，有能力时补上恢复
status: To Do
assignee:
  - '@Furinya'
created_date: '2026-10-24 15:48'
updated_date: '2026-10-27 04:24'
labels:
  - post-release
  - platform-capability
dependencies: []
references:
  - docs/TOOLCHAIN.md
  - src/lua/abyss_ui.lua
  - src/lua/abyss_game_ui.lua
  - 'https://act.mihoyo.com/ys/ugc/tutorial/detail/mhzcw29qjjma'
priority: low
type: feature
ordinal: 91000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
2026年10月24日，用户报告网络中断恢复后，本局进度全部丢失。当前源码审阅显示局状态保存在客户端Lua内存中，尚未接保存和读取；这与丢失现象相符，但没有本轮断网复现日志，不能认定平台具体重连行为。用户要求先确认平台和账号有没有能力，支持时再做；不支持就记录限制，不强行实现、不为此升级账号，不阻塞首发。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 核对并记录官方断线重连、局内存档能力及账号实际权限，区分短暂重连和离开后重进；现有资料所述Lv.4仍需官方复核。
- [ ] #2 能力可用时补齐恢复，并以同一候选实测断网后关键进度一致；不可用时记录限制和依据，不能把完成记录当作恢复功能通过。
- [ ] #3 不为本项升级账号，不阻塞10月30日首投，不改现有必过里程碑。
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
2026-10-27队列复核：补齐有效负责人Furinya；Low候选仍不占当前冲刺，不因指定负责人自动启动新功能。
<!-- SECTION:NOTES:END -->
