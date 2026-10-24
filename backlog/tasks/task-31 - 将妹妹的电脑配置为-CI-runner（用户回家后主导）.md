---
id: TASK-31
title: 将妹妹的电脑配置为 CI runner（用户回家后主导）
status: Done
assignee:
  - user
created_date: '2026-10-23 02:25'
updated_date: '2026-10-24 03:13'
labels:
  - user-led
  - manual-trigger
  - ci
dependencies: []
references:
  - TASK-23
priority: high
type: chore
ordinal: 37000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
希望尽快利用妹妹的电脑运行项目 CI。此任务需要用户回家后现场操作；用户会在有机会回家时主动带着 agent 完成，不设固定日期。执行约束：agent 不得自行领取、启动或推进本任务，不得自动分派给 agent；只有用户主动提出开始后才协助执行。与 TASK-23 的现有本机 runner 接入工作区分，本任务针对新增电脑。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 用户回家并主动发起后，妹妹的电脑已注册为该项目的 CI runner，且在线可用
- [x] #2 至少一次项目 CI 作业在该电脑上实际运行成功，并记录结果
- [x] #3 记录该电脑 runner 的启动、停止与维护方式
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
2026-10-24：你确认这项已经完成。
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
新增电脑的自动检查环境已配置完成，由用户确认。
<!-- SECTION:FINAL_SUMMARY:END -->
