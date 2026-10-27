---
id: TASK-17
title: 接通Boss、Boss宝箱和胜败结算
status: Done
assignee:
  - '@Codex'
created_date: '2026-10-22 13:48'
updated_date: '2026-10-27 04:15'
due_date: '2026-10-26'
labels: []
milestone: m-3
dependencies:
  - TASK-12
  - TASK-13
  - TASK-14
  - TASK-8
references:
  - docs/backlog-details/TASK-17.md
  - docs/M2-SPRINT-20261024.md
  - docs/M2-CLOSEOUT-20261024.md
priority: medium
ordinal: 3
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
让第一幕正常收尾：击败Boss后开独立的Boss宝箱，再进入胜利结算；失败后可以重新开始。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 正常击败Boss后进入第17层独立Boss宝箱，领取正确奖励，再进入正式胜利结算。
- [x] #2 战败、击杀和特殊阶段不会重复结算；游戏内重开和重新挑战都没有上局残留。
- [x] #3 保留开发和测试结果；完整试玩与Boss原版规则分别由对应任务检查。
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
2026-10-24 M2冲刺：从3bd3afa隔离并行。Boss事务代理补齐16层Boss卡牌奖励到独立17层合法Boss遗物选择；UI代理接线及退出重开；资源代理检查合法节点和资源账本。主线程整合、固定SHA构建、独立读回，再以同候选实机验收。不降低数值，不把离线回归当实机通关。

Boss遗物暂限定为Black Blood、Slavers Collar、Sozu三件完整实现，不将受限池称为全原版池；胜利必须在第17层领取或显式跳过后才能触发。Boss16奖励后回图手动进入17，三选一交互读取主题配置。

本轮收口复用既有实机证据，纳入用户已亲测重开和重新挑战的确认，补跑当前退出、结算与资源重置回归；逐项核对后完成任务并归档M2。手机物理输入、整体UI品质和完整内容核对继续由既有后续任务承担。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
核心2a097c0/148ae99已在独立树完成并整合：第17层独立宝箱三选一/跳过、BlackBlood替换/12回血、项圈条件能量、Sozu能量/拒药、普通池排除Boss。定点宝箱8组/效果6组通过；尚无本轮官方导入或实机，不勾平台AC。

本轮原生自动流程固定源522e547、候选601f9401、官方测试存档1843：连续1至17层正常数值通关，17层真实领取Sozu后进入游戏胜利及官方胜利结算。新25号日志4032条、ready1、266动作全部成功、胜利客户端请求/服务端打印各1；独立复核资源闭合34HP/131金/17卡/3遗物。原runner未真正离开导致logFile=null；真实退出后16:29:59新gia落盘，保留原status及延迟采集证据。AC2失败/游戏内重开/官方重新挑战仍未取证；随后PR169界面组合单独本地验证，不能冒充本轮实测。

用户本轮确认已亲测重开和平台重新挑战；既有正常死亡/正式失败结算、Boss16到独立宝箱17的正式胜利证据及当前单次结算/重置回归共同补齐AC2。保留旧自动流程未覆盖重开的真实范围。详见docs/M2-CLOSEOUT-20261024.md。
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Boss16、独立宝箱17和正式胜败结算闭环完成；重开/重挑战由用户实测确认及回归支持，Boss严格规则继续由M3独立验收。
<!-- SECTION:FINAL_SUMMARY:END -->
