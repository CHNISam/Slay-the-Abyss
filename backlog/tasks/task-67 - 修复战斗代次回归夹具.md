---
id: TASK-67
title: 修复战斗代次回归夹具
status: Done
assignee:
  - Furinya
created_date: '2026-10-26 07:10'
updated_date: '2026-10-27 04:23'
labels: []
dependencies: []
references:
  - 'https://github.com/CHNISam/Slay-the-Abyss/pull/219'
priority: medium
ordinal: 114000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
既有分组战斗回归遗漏运行实例新增的战斗代次字段，导致完整状态比较在通用检查中失败。修复夹具并保留完整字段核对，详见 docs/backlog-details/task-67.md。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 首次真实战斗的运行实例与战斗实例代次均明确核对为一
- [x] #2 虱子颜色及其他遭遇完整状态比较保持全部字段并通过对应回归
- [x] #3 仅更新测试夹具和复现说明，不修改生产战斗或数值
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. 保留完整状态比较并补独立的首次战斗代次预期。2. 执行颜色分支与其他遭遇两份生产回归。3. 独立复核差异并提交受控分支。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
当前基线45ba918，仅测试参考实例遗漏combatGeneration。缓存npm ci安装11包，数据重新生成成功；louse_colors第一部分52/52、第五部分53/53通过。独立进程逐字段比较louse_pair与cultist_solo仅差代次。执行者codex-v4-regression，独立session 7794f8ea-6cff-4711-af80-204c3be2f669，generation65。其他任务和隔离记录未修改。

临时副本敏感性复查：删参考代次字段恢复4个原完整比较失败；实际代次改2被固定值断言拒绝。verify:backlog通过。暂保持In Progress及有效claim，等待当前SHA CI与受控合并，不把本地回归当作实机。
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
三个已勾验收均属夹具修复：首次真实遭遇代次Run/Combat=1，reference补相同代次且保留全字段比较，删除字段及错误值敏感性已记录。生产主线louse_colors第78/79行保留断言和reference赋值；后续PR219准确HEAD完整Quality40322430626及Licenses全SUCCESS覆盖既有回归，不再以已停用claim或待合并旧备注挂进行中。非生产玩法变更，非平台验收。
<!-- SECTION:FINAL_SUMMARY:END -->
