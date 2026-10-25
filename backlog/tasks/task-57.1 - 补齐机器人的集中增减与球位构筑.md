---
id: TASK-57.1
title: 补齐机器人的集中增减与球位构筑
status: In Progress
assignee:
  - Furinya
created_date: '2026-10-25 06:11'
updated_date: '2026-10-25 08:18'
labels:
  - required
  - sts1
  - builds
milestone: m-4
dependencies: []
references:
  - >-
    https://github.com/aeubanks/sts/tree/319009d5df0a82d9fb0f23cc22322286c6a87ec0
parent_task_id: TASK-57
priority: high
type: feature
ordinal: 98000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
集中不能长期只支持碎片整理的正数增加。扩容、耗尽、重编程和偏差认知需要同一套准确的能力生命周期与人工制品处理。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 扩容与耗尽基本版和升级版正确，球位上限十；减少最后球位不唤起，零球位耗尽仍获得集中。
- [ ] #2 首次集中、叠层、负集中、零层移除各自保持固定来源语义，球与玩家能力不出现两份互相矛盾的集中。
- [ ] #3 人工制品按入站减益保护负集中和偏差；被挡后其他合法收益继续执行，多层偏差一次衰减只消耗一层人工制品。
- [ ] #4 重编程、偏差认知及球位牌形成可自然获取的构筑，覆盖暗球储伤、能力顺序和失败回滚。
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
固定源已核；集中改为单一Power状态，处理人工制品、首次/叠层/归零、Bias与球位变化；独立模块和真实卡牌定向测试先行，主线程集成Actor/回合入口，不修改正在全量验证的版本。
<!-- SECTION:PLAN:END -->
