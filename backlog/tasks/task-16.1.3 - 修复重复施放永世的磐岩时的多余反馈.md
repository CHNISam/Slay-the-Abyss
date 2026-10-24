---
id: TASK-16.1.3
title: 修复重复施放永世的磐岩时的多余反馈
status: Done
assignee:
  - '@dot'
created_date: '2026-10-24 11:17'
updated_date: '2026-10-24 13:04'
due_date: '2026-10-28'
labels:
  - required
milestone: m-4
dependencies:
  - TASK-16.1.1
references:
  - docs/backlog-details/TASK-16.1.md
  - docs/reviews/TASK-16-m3-card-audit.md
  - docs/reviews/TASK-16.1.3-barricade-repeat.md
parent_task_id: TASK-16.1
priority: high
type: bug
ordinal: 87000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
已有保留格挡效果时，再施放这张能力牌会多产生一条零层状态事件，引发多余提示。让重复牌仍正常付费和离开手牌，但不再重复播放无效状态反馈；不改费用或效果数值。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 首次施放仍正常获得保留格挡效果；重复施放不再产生多余的零层状态事件。
- [x] #2 基础和升级牌都正常扣能量、离开手牌，回合开始时的格挡保留行为不变。
- [x] #3 其他状态的零值处理、免疫拦截和失败回滚不受影响，非法输入仍按原规则拒绝。
- [x] #4 固定来源、真实出牌、事件与反馈回归通过独立审查和当前提交CI；不冒充已在游戏里验收。
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
先复用PR177的重复Barricade真实失败诊断，核固定ApplyPowerAction来源与当前反馈路径。仅在effect解释层收窄重复本能力的施加门槛，不全局屏蔽amount=0、不修改Actor共享状态API或卡牌费用。覆盖首次/重复基础及升级、正常付费与牌去向、格挡保留、非法数值和Artifact/Flex零值原契约。独立评审后按当前CI集成，保留Shockwave两条未修顺序差异。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
候选1158已纠正旧1130对异常定义类型和stack的过度跳过，仅正常已生效本能力不再发零事件；非法值/定义保留原Actor行为。20专项、167原生Lua文件、1008纯Node、17Python通过；独立4802差分、新主线179 UI下4真实重复牌/4晚失败回滚通过。尚待本PR当前SHA CI和合并；Shockwave两条顺序差异仍保留。未新增安装或调用用户Codex，费用/额度节省未知。

PR180已合入ed1505bf。当前94fd0218的Quality40093863686 attempt2双成功；attempt1在game_ui阶段Node Zone OOM，保留失败日志。核同轮前段同UI15组已过、每fixture独立进程后仅重试失败job一次，未修改预算/代码/测试；OOM根因缺宿主内存证据仍未知。
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
仅正常已生效能力的重复施放不再发零层状态事件，费用/去向/格挡不变；非法值/异常定义/其他状态保持原行为。独立差分、真实UI及回滚回归通过，已合PR180：https://github.com/CHNISam/Slay-the-Abyss/pull/180；当前头CI：https://github.com/CHNISam/Slay-the-Abyss/actions/runs/40093863686。无官方导入或实机验收声明。
<!-- SECTION:FINAL_SUMMARY:END -->
