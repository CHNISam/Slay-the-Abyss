---
id: TASK-15.10
title: 修正红绿虫的血量咬击与招式选择
status: Done
assignee:
  - '@Furinya'
created_date: '2026-10-23 23:13'
updated_date: '2026-10-27 15:04'
labels: []
dependencies: []
references:
  - 'https://github.com/CHNISam/Slay-the-Abyss/pull/140'
parent_task_id: TASK-15
priority: medium
type: bug
ordinal: 69000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
仅修复现有红绿虫的独立血量区间、每只创建时抽取一次5–7咬击、25/75辅助/攻击选择与两种招式禁止三连。按源码保持每只HP后抽咬击的顺序，不改共享牌表；Curl Up与其额外随机阶段明确留后续，不声称完整敌人一致。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 固定来源明确两变体HP、咬击一次抽样、构造顺序及25/75历史限制与RollMove规则
- [x] #2 真实Combat/Run先失败再通过，覆盖多敌人构造、独立咬击、力量虚弱、历史边界及反伤死亡队列
- [x] #3 数据/受影响回归、独立评审及当前SHA CI通过，Curl Up、完整随机流/平台及父任务边界保留
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
源身份及构造顺序核对；真实负例；最小共享策略和逐演员prepare接线；独立评审及正式CI后集成。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
负责人字段规范化：原记录 @dot 作为历史执行者信息保留；任务负责人为 Furinya。
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
PR140 / bf0602b 已合并。26专项、111原生Lua文件、相关JS/Python及独立15边界/10负控/336非Louse轨迹一致性通过；合后Quality40039720321成功。有限红绿虫HP/Bite/AI切片完成，蜷缩由独立TASK-15.11承接，完整随机流/平台及父任务未完成。
<!-- SECTION:FINAL_SUMMARY:END -->
