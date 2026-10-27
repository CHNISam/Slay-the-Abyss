---
id: TASK-15.13
title: 实现大型尖刺敌人的分裂流程
status: Done
assignee:
  - '@dot'
created_date: '2026-10-24 00:21'
updated_date: '2026-10-27 04:15'
labels: []
dependencies: []
references:
  - 'https://github.com/CHNISam/Slay-the-Abyss/pull/144'
parent_task_id: TASK-15
priority: medium
type: feature
ordinal: 72000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
按固定来源实现大型尖刺敌人在半血阈值切换分裂意图，行动时以剩余血量生成左右两个中型子体。保留死亡父体身份，子体不在本轮立即行动，不触发父体死亡被动或提前胜利；修复新增演员所必需的反馈身份对齐和界面交互。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 固定来源明确阈值/意图打断、行动时剩余HP、无HP重抽、子体初始化及父体roll顺序和无死亡触发规则
- [x] #2 真实Combat/Run先失败再通过，覆盖伤害来源、致死取消、状态/身份、行动快照、队友顺序、奖励一次和回滚
- [x] #3 生成控件与反馈支持分裂前后身份/目标变化，旧父体输入不得误中子体，当前5槽容量边界明确
- [x] #4 数据及受影响回归、独立评审和当前SHA CI通过；完整分流随机/其他分裂/平台及父任务边界保留
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
独立核对源身份与插入队列；建立真实负例；最小分裂构造/行动快照/反馈身份与UI接线；独立评审及正式CI后集成。
<!-- SECTION:PLAN:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
PR144 / 85be6f4 已合并，最终组合保留PR143动态数值和详情。119原生Lua文件、相关JS/Python及独立输入/身份/分裂/变异通过；原85be合后作业取消不算通过，后续1181764组合Quality40048253721双绿且分裂源码/测试未变。有限大型尖刺分裂及安全目标/反馈接入完成；完整随机流、分裂动画与平台及父任务未完成。
<!-- SECTION:FINAL_SUMMARY:END -->
