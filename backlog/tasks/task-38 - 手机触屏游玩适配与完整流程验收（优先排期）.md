---
id: TASK-38
title: 在手机上完整玩一遍
status: In Progress
assignee:
  - '@Codex'
created_date: '2026-10-23 12:23'
updated_date: '2026-10-25 08:05'
due_date: '2026-10-28'
labels: []
milestone: m-5
dependencies: []
references:
  - TASK-4
  - TASK-10
  - docs/design/UI_DESIGN.md
  - docs/backlog-details/TASK-38.md
  - docs/DELIVERY-CLOSEOUT.md
priority: high
type: feature
ordinal: 39000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
确认手机只靠触屏就能完成游戏，文字看得清、按钮点得到，不需要鼠标或键盘。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 能触屏选牌、看详情、选敌人、出牌、取消和结束回合。
- [ ] #2 能完成选路、领奖、商店、营地、事件、胜败结算和重开。
- [ ] #3 常用手机屏幕下界面不出屏；拖牌受限时仍能用点选出牌。
- [ ] #4 记录实测手机和操作结果，没通过的写清楚；预览不能代替手机实测。
- [ ] #5 同一候选实测跨战斗首次点牌、旧触点、药水、奖励、弹窗和取消退出的真实事件派发；已完成本地手势切片不能代替手机验收。
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
P1手机横屏露底修复：基于最新develop，把共享canvasBackdrop改为全范围拉伸锚点和零尺寸增量，移除运行时用逻辑画布宽高覆盖背景尺寸；内容仍按1280×720等比缩放。先以几何回归复现并保护不同宿主/画布尺寸，再完整check、候选存档独立读回；官方预览和试玩必须先与用户约定鼠标键盘时间窗口，手机实测缺口保留，不勾整体验收。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
2026-10-25用户指定P1高优先级、非阻塞但正式发布前必修；复用TASK-4/38。本轮新claim被Migration paused拒绝，用户在说明最小范围例外后要求continue；不改执行权配置、不冒用其他session。后续用户强调任何抢占输入测试必须提前协调并等待本轮明确时间窗口，已写入AGENTS和官方客户端指引。本轮尚未进行任何鼠标键盘或置前操作。

2026-10-25用户明确选择本轮先只做离线验证，之后另约输入设备时间；因此本轮不做官方导入、设备预览、原生试玩、手机或性能实测。源码79244ee已推Draft PR207；2项背景几何回归（旧版真实失败）、9组尺寸与重复缩放、15项游戏宿主回归通过，完整check和存档副本仍在执行。

候选79244ee已独立审计通过：65/65模块、2824控件/max60、静态0错35警告、四设备宿主/根/背景拉伸零增量。候选与报告见docs/evidence/mobile-fullbleed-20261025.json。完整npm check的JS1366项中1247通过/119环境跳过/0失败；Lua阶段发现同机M3 CI40174178038已在本地任务启动后开始，已停止自己的全量进程保留日志以恢复串行，不报本地完整通过。最终SHA完整CI仍必须完成；verify:ui实为6屏partial/5屏pending。
<!-- SECTION:NOTES:END -->
