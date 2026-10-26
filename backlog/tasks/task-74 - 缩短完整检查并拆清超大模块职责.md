---
id: TASK-74
title: 缩短完整检查并拆清超大模块职责
status: In Progress
assignee:
  - '@codex'
created_date: '2026-10-26 14:33'
updated_date: '2026-10-26 14:44'
labels: []
dependencies: []
references:
  - docs/backlog-details/TASK-74.md
ordinal: 118000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
完整CI反复耗时近一小时，测试存在重复执行，界面与战斗大文件也提高了修改成本。本轮按已知热点交付可独立验证的减负切片，保持游戏行为和检查覆盖。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 完整检查保留原有断言和失败传播，并有同环境耗时对照
- [ ] #2 超大模块按明确职责拆分，公开接口及构建模块完整
- [ ] #3 相关回归和工程门禁通过，记录剩余热点与未执行的平台验证
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1.按成功CI分阶段记录耗时和重复执行。2.在隔离切片中将Lua用例有界并发执行，保持每进程隔离、完整发现和失败传播。3.并行拆分战斗手牌子视图与商店渲染职责，保留布局和规则来源。4.综合测量后选用最小CI分片方案，核对静态基线只因移动代码产生的变化。5.运行相关、完整回归及当前SHA官方CI，按证据提交PR和收口。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
已集成两个UI职责切片和最小Lua分片CLI；固定Node24通过19项原runner/数据/分片回归，候选子模块部署闭环及四项语义变异门禁通过。静态113条无新增，42条仅行号移动。并发试验因重例预算风险撤回，CI采用四个隔离Windows VM、片内保持同步串行；现等待当前SHA官方完整CI，未计为最终通过。
<!-- SECTION:NOTES:END -->
