---
id: TASK-52.1
title: 修复旧路线诊断的领奖与节点推进
status: Done
assignee:
  - '@dot'
created_date: '2026-10-24 14:44'
updated_date: '2026-10-24 15:45'
due_date: '2026-10-28'
labels:
  - required
milestone: m-4
dependencies: []
references:
  - >-
    https://github.com/CHNISam/Slay-the-Abyss/pull/182#pullrequestreview-5638511037
  - docs/reviews/TASK-52.1-diagnostic-reward-protocol.md
parent_task_id: TASK-52
priority: medium
type: bug
ordinal: 91000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
药水独立领取已合入后，旧路线诊断仍在选牌后直接回图，首战会报reward_pending。让诊断按当前真实领奖协议继续，不把过时脚本错误当成游戏回归。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 旧seed42路线通过真实首战领奖并继续；正式胜败仍按真实结果报告，不强制通关。
- [x] #2 明确处理药水领取或放弃，失金与离开奖励分别处理；满槽和无药水情况不死循环。
- [x] #3 保留原战斗、选牌、地图及数值策略，不修改生产Run/Nodes或放宽错误检查。
- [x] #4 原失败先红后绿，回归覆盖完整领奖组合，经独立审查和当前CI；不冒充平台试玩。
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
复用PR182已迁移m2-resource-audit的公开领奖接口顺序，只修tools/diagnostics/core_route_seed42.lua旧调用处并补独立fixture。已有单独76bbefa真实首战reward_pending负例，先在最新b91再次核对，再按明确领/弃药、独立失金、leave、complete顺序迁移，防满槽/重复/无待领项死循环；保留真实死亡路径，不改生产或测试预算。

为直接测试诊断实际使用的逻辑，增加仅供诊断的tools/diagnostics/finish_combat_rewards.lua最小helper，由旧脚本与真实Run/Nodes fixture共同调用；不导入生产、不改原选卡策略，不扩成通用框架。

修好领奖后自然seed42到f14_l3又复现旧event分派访问nil。只在成功enter后按真实已解析节点类型分派到原处理分支，保留路径排序/ID/事件策略；补问号→战斗/商店/宝箱/事件回归，不静默跳过未知类型，不改生产。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
已实证原首战reward_pending；最小领奖修复后推进13层7胜、71HP/234金币/3瓶，但f14_l3旧脚本按原event类型访问nil事件。获准补同文件必要的已解析类型分派，不把此中途停止记为自然胜败或通关。

最终四文件候选只改诊断脚本、诊断专用helper、fixture与报告。两个真实红例（首战reward_pending和f14问号解析商店访问nil）均修复，47专项、原6份54回归、13负变异与独立4边界通过。自然seed42完成诊断到第16层Guardian合法败亡，7胜/188金币/3瓶，LOSS_GATE/FRESH_RUN原断言通过；不是17层通关，不改生产或强制胜利。root亦独立复跑47及完整自然脚本成功。当前SHA CI与合并仍待，不声明Fengari或平台通过。

诊断代码头7510fdfc的Quality40107601669两个作业均成功，47专项/原回归/独立审查和真实seed42终态均已核。本次在原PR186内仅收口任务与里程碑记录，不改变代码；最终元数据提交仍须自己的当前SHA CI成功后才合并，未合候选不算已交付。
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
旧路线诊断已适配独立药水/失金/离开奖励和问号解析类型，生产规则与选择策略未改。47专项、13负变异、独立边界及代码头CI通过；seed42真实第16层败亡并通过LOSS_GATE/FRESH_RUN，不是通关。PR186：https://github.com/CHNISam/Slay-the-Abyss/pull/186；代码CI：https://github.com/CHNISam/Slay-the-Abyss/actions/runs/40107601669。无平台实测声明。
<!-- SECTION:FINAL_SUMMARY:END -->
