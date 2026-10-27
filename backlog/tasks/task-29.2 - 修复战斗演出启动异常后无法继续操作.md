---
id: TASK-29.2
title: 修复战斗演出启动异常后无法继续操作
status: Done
assignee:
  - '@dot'
created_date: '2026-10-23 11:42'
updated_date: '2026-10-27 04:15'
labels: []
milestone: m-2
dependencies: []
references:
  - docs/COMBAT_FEEDBACK.md
  - 'https://github.com/CHNISam/Slay-the-Abyss/pull/52'
  - 'https://github.com/CHNISam/Slay-the-Abyss/pull/106'
parent_task_id: TASK-29
priority: medium
type: bug
ordinal: 49000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
真实出牌已经扣能量并造成伤害后，演出初始化中的控件异常可能永久锁住输入。仅修离线故障恢复，不改战斗规则、主题或原任务平台验收。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 演出启动期间控件失败后输入恢复，已提交战斗结果不回滚或重复执行。
- [x] #2 正常演出、空队列、取消与后续新命令保持可用，完成回调不重复。
- [x] #3 新增故障回归先红后绿，经独立评审和当前提交Quality验证；实机未验明确保留。
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. 复现真实出牌后启动异常的锁死。2. 调整演出生命周期的初始化和失败清理，不改变规则事务。3. 补充正常、空队列、取消与重复完成边界测试，独立复审并走PR/CI。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
固定基线 c3c909db 复现：真实出牌结果已提交，演出首次reset控件异常后宿主输入永久锁住；空事件队列亦未完成。最小候选将busy所有权前移至begin受保护启动前，5组回归通过，基线同组2失败；根代理独立复跑通过。独立评审进一步确认reset/classify/空队列3项恢复，剩余自定义回调重入异常在基线同样存在且未证实正常宿主可达，不扩大本次修复。不改变规则/RNG、主题、TASK29/29.1负责人或平台AC。保持In Progress及AC未勾，等待最终SHA Quality。

2026-10-23独立审计固定15f62a6：恢复5项、反馈13+10+3、atomic14、battleUI47、gameUI15全过，另classify故障/cancel后batch两探针通过。回退8a5b6a5父版模块，reset/empty两项失败，恢复5/5。PR106最终head61669a2、Quality39948545690双SUCCESS，已合8a5b6a5。报告.artifacts/m1-audit/feedback/REPORT.md。真实平台恢复仍未测，父TASK29平台AC不变。
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
离线启动失败输入恢复已合并；独立红绿与正常/空队列/取消/后续命令回归通过，PR106最终SHA Quality全绿。平台验收不计入本任务完成。
<!-- SECTION:FINAL_SUMMARY:END -->
