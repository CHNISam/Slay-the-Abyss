---
id: TASK-76.1
title: 修复手机地图漏松手后无法选节点
status: To Do
assignee:
  - '@Furinya'
created_date: '2026-10-28 14:39'
updated_date: '2026-10-29 04:17'
labels: []
milestone: m-4
dependencies: []
references:
  - 'https://github.com/CHNISam/Slay-the-Abyss/pull/304'
  - docs/backlog-details/MOBILE-QA-20261028.md
  - docs/evidence/backlog-merge-20261029.json
  - docs/backlog-details/TRAVELER-SCOPE-20261029.md
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

PR323原39dab5e9历史实施记录承接（不认证本组合，当前公开范围以docs/SCOPE.md仅岩旅行者两幕为准）：
同一非nil touchId的背景地图漏Up→新节点完整tap恢复已实现；延迟背景Up不能提交。原地图35组及新增回归通过。node自身漏Up/异touch恢复未证，实体手机仍待验，不关闭整项。

合流双方完整metadata、AC、计划和实施notes见docs/evidence/backlog-merge-20261029.json；当前角色范围按旅行者单角两幕，雷电未来任务原81因上游重号经原生doctor改为TASK-85。所有原已勾AC不改，未验不勾。
<!-- SECTION:NOTES:END -->
