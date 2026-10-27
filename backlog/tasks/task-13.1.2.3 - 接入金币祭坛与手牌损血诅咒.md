---
id: TASK-13.1.2.3
title: 接入金币祭坛与手牌损血诅咒
status: Done
assignee:
  - '@dot'
created_date: '2026-10-24 01:16'
updated_date: '2026-10-27 04:15'
labels: []
dependencies: []
references:
  - 'https://github.com/CHNISam/Slay-the-Abyss/pull/149'
parent_task_id: TASK-13.1.2
priority: medium
type: feature
ordinal: 73000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
按固定来源完整接入Golden Shrine三选项：100金币、275金币并获得Regret、离开。补齐仅这一张诅咒的不可打出/不可升级与回合末按初始手牌数失去生命行为；永久获取、事件池消费、节点界面和状态展示一起验证，不把其余事件池算完成。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 固定来源明确三选项收益、正常祭坛池资格/消费与零额外选项随机调用，并保留原版版本/完整随机限制
- [x] #2 真实Run/Combat先失败再通过，覆盖诅咒入组/抽到/多张快照/损血顺序与死亡、奖励商店升级排除及原子失败
- [x] #3 实际生成控件展示选项收益代价，完成事件后状态正确，相关牌表/Python/原型一致且不覆盖Lore/品牌改动
- [x] #4 独立评审与当前SHA正式CI通过；只交付第七个完整事件及该诅咒，完整池/平台与父任务边界保留
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
核对源动作及池规则；真实负例；最小诅咒与事件/界面接线；品牌原型一行数据增量独立合成；完整相关回归及独立审查后正式CI集成。
<!-- SECTION:PLAN:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
PR149 已合入 b92bce64，实际组合树70caa664与独立评审完全一致，地图PR148与品牌均保留。122项native Lua与相关JS/17Python、真实生成节点及自然地图→祭坛→诅咒战斗流程通过。head074a1836 Quality40050743021双绿，合后b92bce64 Quality40051640565双绿；证据见PR149评论6378501998。仅第七个完整事件与单张诅咒代码完成，父任务、完整事件池/随机流及平台实测不扩写。
<!-- SECTION:FINAL_SUMMARY:END -->
