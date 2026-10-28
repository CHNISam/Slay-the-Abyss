---
id: TASK-77
title: 让正式比赛流程在第二幕结束
status: To Do
assignee:
  - Furinya
created_date: '2026-10-28 08:20'
updated_date: '2026-10-28 08:23'
labels: []
milestone: m-4
dependencies: []
references:
  - docs/SCOPE.md
  - src/lua/abyss_ui.lua
  - src/lua/abyss_run.lua
priority: high
type: feature
ordinal: 1
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
2026-10-28用户把比赛范围改为前两幕，但e46bd5dd正式入口仍campaign=true且Run.advanceAct允许进入第三、第四幕。范围文档已变不等于运行时已收敛；此项阻塞比赛候选冻结。不删除未来章节代码，不以关闭campaign退回第一幕。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 正式比赛入口支持第一幕正常接续第二幕，并在第二幕合法完成后进入本局结果，不能进入第三幕、隐藏第四幕或真结局。
- [ ] #2 保留同一局卡组、血量、金币、遗物、药水、随机流及回滚快照，不新增退出续玩、跨局历史、解锁或存储后端。
- [ ] #3 正式入口、第二幕终点、重复和非法换幕、胜败及重开都有生产回归；同候选平台和真实试玩证据单列，未实测不勾选。
- [ ] #4 第二幕Boss后宝箱领取与跳过都合法结束于同一双幕终点；正式UI不显示后续幕、三钥匙或真结局可用提示，本局结果层数及文案与双幕一致。
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
只读审计e46bd5dd：abyss_ui.OnStart为campaign=true；Run.advanceAct允许1→2→3→4，暂无maxAct。保留campaign=true才能支持1→2，不得直接改false退回第一幕。Nodes.leaveTreasure与claimBossTreasure两条分支、Host/过期动作、结果floor分母17均须覆盖；未来四幕source/fixture保留。真实Boss历史provider未接，不得把跨局Boss解锁继续设为比赛依赖或伪造历史。
<!-- SECTION:NOTES:END -->
