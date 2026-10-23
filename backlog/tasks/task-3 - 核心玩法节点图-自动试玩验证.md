---
id: TASK-3
title: M1 真实平台完整战斗闭环
status: In Progress
assignee:
  - '@Codex'
created_date: '2026-10-22 13:32'
updated_date: '2026-10-23 14:14'
due_date: '2026-10-24'
labels: []
milestone: m-2
dependencies:
  - TASK-3.2
  - TASK-11.1
priority: high
ordinal: 1
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
对已完成的战斗系统做三层分离验证：编译通过、写进存档、游戏里真的能打。三件事分开报告，不得互相冒充。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 同一候选在真实游戏完成至少一场完整战斗：抽牌/出牌/能量/目标/结束回合/敌人行动/胜利奖励，日志和截图可复核
- [ ] #2 真实画面中手牌、血量/格挡/能量/敌人意图及中文可读可操作；与核心状态一致
- [ ] #3 记录候选SHA、导入存档与runId；失败和脚本错误如实列出，CI/替身控件不能代替
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
2026-10-23 M1并行收口：独立审计TASK29.2与41的已合修复、九状态及本轮真实证据；从15f62a6隔离工作树重建统一候选，复用scene-safe v2场景配置，独立读回源码/UI/结算载荷与场景；不自动开游戏，不混用历史候选验收。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
原AC1构建/写副本拆至TASK-3.1，原AC2导入拆至TASK-3.2；实战仍M1必要关口。本轮主存档无战斗脚本/UI，未运行战斗，不勾选。

P0用户优先级覆盖既定串行排期，沿用任务避免重复建项。v4完整候选实机完成菜单→地图→出牌/敌人行动→胜利奖励/跳过→回图→商店离开并推进至15层Boss失败；v5用户确认HP/MaxHP、意图与受伤更新正常。原始截图/候选SHA及故障修复在docs/P0-SMOKE.md。本轮新日志仍缺，九状态未逐项实测，AC保持未完成。

本轮固定origin/develop=15f62a61ebd1635a93a5f1cc98cbcc4e6d2602dd。四个独立代理已领取离线审计；根未提交UI/theme/测试保留。新候选在.worktrees/m1-closeout构建。

2026-10-23并行证据审计已确认新日志345打印/4胜1败及失败结算重开，不再重复列为缺新日志。15f62a6已无冲突集成退出修复为76c93d7；16项退出/宿主/审计相关JS全过。初次完整check与集成重叠，旧布局缓存造成exitPanel缺失，记录失败、不计最终证据，固定集成源须重跑。
<!-- SECTION:NOTES:END -->
