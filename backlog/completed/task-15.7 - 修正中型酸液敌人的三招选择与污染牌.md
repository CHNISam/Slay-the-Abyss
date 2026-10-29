---
id: TASK-15.7
title: 修正中型酸液敌人的三招选择与污染牌
status: Done
assignee:
  - '@Furinya'
created_date: '2026-10-23 22:10'
updated_date: '2026-10-27 15:04'
labels: []
dependencies: []
references:
  - 'https://github.com/CHNISam/Slay-the-Abyss/pull/137'
parent_task_id: TASK-15
priority: medium
type: bug
ordinal: 66000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
按固定来源修复Acid Slime M的28–32血量、7伤害加污染牌、10伤害、虚弱1三种招式及30/40/30选择/历史限制。复用已接入污染牌，不改卡池；明确保留项目LCG与原版随机底层差异。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 固定来源明确三招数据、主roll区间和Boolean/0.4f历史回退规则，记录源身份与随机适配限制
- [x] #2 真实Combat/Run负例先失败再通过，验证边界输入、历史限制、攻击污染顺序与死亡队列
- [x] #3 受影响全仓测试已盘点，数据/相关回归及独立评审、当前SHA CI通过；完整随机流/平台与父任务边界保留
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
核对源码与完整测试清单；建立真实负例；最小AI/data/schema修复；独立评审及当前SHA CI后集成。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
负责人字段规范化：原记录 @dot 作为历史执行者信息保留；任务负责人为 Furinya。
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
PR137 / 28c2aaf 已合并。21专项含2600决策输入、106原生Lua文件、343相关JS、17Python及独立策略/适配值/负控通过；合后Quality40033159636成功。有限AcidM三招选择切片完成，完整分流随机、分裂与平台及父任务未完成。
<!-- SECTION:FINAL_SUMMARY:END -->
