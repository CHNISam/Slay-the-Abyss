---
id: TASK-79
title: 恢复仓库健康并防止分支和验证积压
status: In Progress
assignee:
  - Furinya
created_date: '2026-10-28 11:30'
updated_date: '2026-10-28 12:10'
labels: []
dependencies: []
references:
  - docs/backlog-details/ENGINEERING-HEALTH-20261028.md
priority: medium
type: chore
ordinal: 122000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
多轮并行开发留下分支、工作树和过时验证，集成变更反复吸收且主线出现红灯；本轮按最新主线核实成果后安全清理，并复用现有机制防止重演。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 每个残留分支和工作树都有成果去向，已吸收且干净的无用项完成清理，未合并和未提交内容保留
- [ ] #2 当前验证队列无遗忘的过时任务，素材来源记录真实可核验，最新主线必要检查全部成功
- [ ] #3 既有规则和快速检查拒绝异常合并方式及跨功能合并，不新增锁或重复完整验证
- [ ] #4 治理通过PR正常合入，实际主线验证与耗时有证据，剩余保留项说明原因
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. 从最新develop隔离并盘点PR、分支、worktree与Actions。2. 核实素材记录和真实失败并修复，保留原断言与预算。3. 最小加强已有Ruleset和快速检查，记录吸收及清理证据。4. 当前HEAD完整CI成功后squash合入，清理并核验最新develop的必要检查。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
已从7a87de3a隔离，40个已吸收干净树及49条本地分支完成安全清理；84MiB历史bundle验证后移除引用，独有build/截图/日志完整搬存。远端从6条收为develop/master/未完成dedup草稿3条，无开放PR。pr260商店只读说明与6组回归为未吸收成果，保持原树；所有脏树保留。#292特有13文件当前blob一致，精确59960a17的3份bundle验证通过。已收紧现有develop Ruleset为squash+linear+inventory，未改master或防强推规则；新门禁16项及worker原8项通过，许可门禁真实字节通过，当前完整CI仍待新HEAD。

中途发现另一会话PR300重复；用户明确确认会话结束交本轮统一收口。已保存verify精确d3 bundle、关闭PR和取消其过时验证、删除源引用。择取长提示条143字符和精确图元/导航/语义断言，不引入另一套历史closure；7/194/143与浮字诊断通过，未新增日常测试入口。最终提示条520x80(-330,206)，敌人恢复原站位。主原始Lua旧81392断言缺口已重现并修为与JS同一当前73316轨迹，旧完整fixture与golden继续严格回放。新HEAD完整CI及实际合后develop仍待，未作最终通过声明。
<!-- SECTION:NOTES:END -->
