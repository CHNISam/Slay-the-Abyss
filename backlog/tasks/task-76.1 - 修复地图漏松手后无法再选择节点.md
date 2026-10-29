---
id: TASK-76.1
title: 修复手机地图漏松手后无法选节点
status: To Do
assignee:
  - '@Furinya'
created_date: '2026-10-28 14:39'
updated_date: '2026-10-29 00:13'
labels: []
milestone: m-4
dependencies: []
references:
  - 'https://github.com/CHNISam/Slay-the-Abyss/pull/304'
  - docs/backlog-details/MOBILE-QA-20261028.md
parent_task_id: TASK-76
priority: medium
type: bug
ordinal: 122000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
手机实玩出现地图无法点击；离线对照复现漏释放后的锁定，尚未确认用户那次事件链。PC鼠标是否出现同问题待验证，不预设跨端。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 地图漏松手或触摸中断后可再次选择节点且不误触。
- [ ] #2 保留回归与同候选手机实测证据。
- [ ] #3 手机触屏和PC鼠标分别验证中断释放后的恢复，记录设备、候选和结果。
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
2026-10-29 完整地图安全合同承接附件§2：背景或节点丢释放后，用可证明新操作恢复，同ID复用与新ID分别验证；活跃owner不被其他控件重复Down抢占，旧Up/EndDrag/Click不误入，移动阈值和双指保护保留。恢复前楼层/路线/RNG不变，合法节点仅进入一次；同候选手机覆盖地图拖动、边缘抬指、开关卡组、取消退出，记录事件与版本。不用自动开关退出面板替代修复。
<!-- SECTION:NOTES:END -->
