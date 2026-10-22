---
id: TASK-5
title: M4 平衡打磨与完整通关试玩
status: In Progress
assignee:
  - '@Codex'
created_date: '2026-10-22 13:32'
updated_date: '2026-10-22 23:24'
due_date: '2026-10-29'
labels: []
milestone: m-5
dependencies:
  - TASK-17
  - TASK-4
priority: high
ordinal: 2
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
按基准数值表核对平衡，并真机从第 1 层打到 Boss 完成一次完整通关。缺口如实记录。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 从第 1 层到 Boss 完整通关一遍，日志无异常、无卡死
- [ ] #2 失败可重新开始，跨层状态（血量/金币/卡组/遗物/药水）正确
- [ ] #3 数值对照基准表核对，记录偏差与未完成项
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
P0真实回归：用户使用v4原数值跑至第15层Boss后战败；摘要15/15、HP0/80、金币4、卡组14、遗物4，重新启程返回新局正常。尚非胜利通关，未提供完整逐层资源账本或本轮新日志，AC不勾选。暂停非必要美术扩量和研究，继续补Boss胜利及资源逐项回归。
<!-- SECTION:NOTES:END -->
