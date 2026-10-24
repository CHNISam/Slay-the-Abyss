---
id: TASK-15.5
title: 修正护盾敌人的援护目标与出招
status: Done
assignee:
  - '@dot'
created_date: '2026-10-23 21:11'
updated_date: '2026-10-23 21:45'
labels: []
dependencies: []
references:
  - 'https://github.com/CHNISam/Slay-the-Abyss/pull/135'
parent_task_id: TASK-15
priority: high
type: bug
ordinal: 64000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
按固定来源修复shield_gremlin的12–15血量、援护7目标选择和孤立后永久攻击6；并修正敌群回合开始格挡重置/毒结算先于行动的必要时序，避免援护给后行动同伴的格挡立即消失。只改已支持行为，不引入新平衡。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 固定来源明确援护目标过滤、单目标/空目标随机消费和孤立转攻击规则
- [x] #2 真实Combat/Run先失败再通过，覆盖敌群格挡先重置、毒先结算、目标死亡及持久援护结果
- [x] #3 界面意图准确说明援护对象，数据/既有回归及独立评审、当前SHA CI通过；平台与全随机流边界保留
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
核对源动作队列和所有权；建立真实负例；最小敌人行为及必要敌群前置时序修复；独立审查与正式CI后集成。
<!-- SECTION:PLAN:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
PR135 / 7b09fdb 已合并。22专项、103原生Lua文件、164相关JS与独立20对抗/8负控通过；合后Quality40026878761成功。有限Shield援护/必要敌群前置时序修复完成，固定格挡意图已验证。完整随机流、平台及父任务未完成。
<!-- SECTION:FINAL_SUMMARY:END -->
