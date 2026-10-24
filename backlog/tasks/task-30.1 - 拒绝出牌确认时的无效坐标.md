---
id: TASK-30.1
title: 拒绝出牌确认时的无效坐标
status: In Progress
assignee:
  - '@dot'
created_date: '2026-10-24 14:10'
due_date: '2026-10-28'
labels:
  - required
milestone: m-5
dependencies: []
references:
  - >-
    https://github.com/CHNISam/Slay-the-Abyss/pull/183#pullrequestreview-5638534554
parent_task_id: TASK-30
priority: high
type: bug
ordinal: 90000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
选牌后在战场确认区按下，释放事件若明确返回非有限坐标，仍会被当成无坐标兼容模式而出牌。区分缺少坐标能力与坏坐标，避免异常输入消耗牌和费用。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 释放事件明确返回NaN或无穷坐标时取消本次确认，随后Click不出牌、不扣费、不丢牌。
- [ ] #2 正常有限坐标确认与完整无坐标宿主的点选兼容方式继续可用，原拖牌和同牌取消规则不变。
- [ ] #3 取消后新手势可正常使用，不受迟到事件、另一触点或手牌槽变化影响。
- [ ] #4 真实生产界面逻辑的先红后绿与独立评审通过，当前提交CI通过；不把离线用例当成手机或原神实测。
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
复用PR183评审四例和最新3c3b660主线。仅在坐标解析与playArea确认门槛区分明确坏坐标和未提供API，保持原C档与其他调用契约；不修改战斗数值/卡牌规则/布局。补有限/无API/NaN/正负Infinity及取消重试，覆盖迟到事件和已有手势回归，当前CI后集成。
<!-- SECTION:PLAN:END -->
