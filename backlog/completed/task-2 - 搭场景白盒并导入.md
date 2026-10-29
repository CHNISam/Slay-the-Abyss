---
id: TASK-2
title: 确认进场、镜头和复活正常
status: Done
assignee:
  - '@Furinya'
created_date: '2026-10-22 13:32'
updated_date: '2026-10-27 15:03'
due_date: '2026-10-24'
labels: []
milestone: m-2
dependencies:
  - TASK-1
references:
  - docs/backlog-details/TASK-2.md
  - docs/evidence/task2-closeout-20261024.json
priority: medium
ordinal: 2000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
检查现在的测试场景，确保玩家能正常进场、固定视角观看战斗，并能在倒下后复活。继续使用现有场景，场景美术后面再做。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 现有测试场景已在游戏里打开，官方导入后的必要配置有读回记录。
- [x] #2 固定镜头、出生/复活点和单人1到1配置已官方读回；用户明确确认TASK-2当前最小场景可以收口。
- [x] #3 官方读回确认仅玩家与敌人互相敌对、己方物件中立；归档既有试玩截图/日志及本轮用户整体验收记录，并明确各自范围。
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. 复核1838官方导入读回及已归档同候选截图/日志。2. 如实记录用户2026-10-24对TASK-2的整体人工验收，明确未由代理重新实测1839物理复苏。3. 按用户接受的最小场景范围收口TASK-2，场景美术仍由TASK-2.1验收。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
2026-10-24用户本轮原话：“目前至少这个task two 我是认为已经可以了”。据此接受TASK-2当前最小场景并收口；AC措辞同步人工验收与官方配置读回的实际证据层级，不新增代理实测结论。1838导入读回与既有同候选PC试玩截图/本轮日志均已归档；没有把用户整体确认扩写为逐项物理复苏的操作记录，也没有拿1838材料冒充1839。详见docs/evidence/task2-closeout-20261024.json。TASK-2.1首发岩系遗迹场景、M1九状态、全平台/UI正式门禁仍独立验收。

收口独立验证：官方1838读回中的fixedView yaw0/pitch55、出生/复苏同点、1到1玩家、仅1↔3敌对及实体挂载断言通过；20份既有证据Git blob SHA256与归档manifest全部匹配。Windows检出会把部分JSON LF转换为CRLF，验证使用提交原始blob并另存工作树hash，没有改写原manifest。未运行游戏或新建试玩日志。

负责人字段规范化：原记录 @Codex 作为历史执行者信息保留；任务负责人为 Furinya。
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
按用户2026-10-24明确整体认可，收口现有最小测试场景。官方1838配置断言及20份既有截图/日志等证据Git blob哈希复核通过，证据见docs/evidence/task2-closeout-20261024.json。未将人工整体确认写成代理新做物理复苏、1839取证或全M1通过；TASK-2.1场景美术独立保留。
<!-- SECTION:FINAL_SUMMARY:END -->
