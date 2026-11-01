---
id: TASK-30.1
title: 拒绝出牌确认时的无效坐标
status: Done
assignee:
  - '@Furinya'
created_date: '2026-10-24 14:10'
updated_date: '2026-10-27 15:04'
due_date: '2026-10-28'
labels:
  - required
milestone: m-5
dependencies: []
references:
  - >-
    https://github.com/CHNISam/Slay-the-Abyss/pull/183#pullrequestreview-5638534554
  - docs/reviews/TASK-30.1-play-area-coordinates.md
parent_task_id: TASK-30
priority: medium
type: bug
ordinal: 90000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
选牌后在战场确认区按下，释放事件若明确返回非有限坐标，仍会被当成无坐标兼容模式而出牌。区分缺少坐标能力与坏坐标，避免异常输入消耗牌和费用。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 释放事件明确返回NaN或无穷坐标时取消本次确认，随后Click不出牌、不扣费、不丢牌。
- [x] #2 正常有限坐标确认与完整无坐标宿主的点选兼容方式继续可用，原拖牌和同牌取消规则不变。
- [x] #3 取消后新手势可正常使用，不受迟到事件、另一触点或手牌槽变化影响。
- [x] #4 真实生产界面逻辑的先红后绿与独立评审通过，当前提交CI通过；不把离线用例当成手机或原神实测。
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
复用PR183评审四例和最新3c3b660主线。仅在坐标解析与playArea确认门槛区分明确坏坐标和未提供API，保持原C档与其他调用契约；不修改战斗数值/卡牌规则/布局。补有限/无API/NaN/正负Infinity及取消重试，覆盖迟到事件和已有手势回归，当前CI后集成。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
最小修复仅给明确NaN/正负无穷坐标增加局部拒绝标记，保留缺API与原未知坐标C档。真实31专项先13过18败后全过，9负变异被捕获；独立96矩阵、173原生Lua、1090纯Node、22Python通过。首次15模块寻址环境失败保留，补正确LUA_PATH后全量重跑；无安装或预算变化。尚待本PR当前SHA CI与合并，未改父任务平台AC，未认证PR182组合或实机。

原头097c622的Quality40102429513双成功后，主线新合PR182到b91a461，故重新接合而未直接沿用旧头认证。以3c3为共同祖先自然合并UI/MILESTONES，保留182其余424份代码/数据/测试；最新并集31专项、BattleUI53、176原生Lua、1091纯Node、22Python及独立96+7通过。新并集仍须自身SHA CI，不认证平台或旧候选实机。

PR184最终f6d0446在Quality40104681083 attempt2两个job成功后，已squash合入1511f0a。attempt1是测试前Git fetch curl56/earlyEOF失败，仅重试失败作业一次，未改代码/超时/预算。本地新主线并集和独立评审结果见报告；父任务30平台验收不变。

负责人字段规范化：原记录 @dot 作为历史执行者信息保留；任务负责人为 Furinya。
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
明确NaN/正负无穷Down/Up不再获得场上出牌许可，迟到Click不能误扣费，正常与无坐标兼容不变。已合https://github.com/CHNISam/Slay-the-Abyss/pull/184；当前头CI https://github.com/CHNISam/Slay-the-Abyss/actions/runs/40104681083。仅关闭离线切片，无平台实测声明。
<!-- SECTION:FINAL_SUMMARY:END -->
