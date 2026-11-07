---
id: TASK-4.18
title: 清除新增事件玩家界面的原作专有身份外露
status: To Do
assignee:
  - Furinya
created_date: '2026-10-31 10:47'
updated_date: '2026-11-07 03:47'
labels:
  - 待验
milestone: m-8
dependencies: []
references:
  - docs/backlog-details/PLANNING-CONSOLIDATION-20261031.md
  - docs/backlog-details/STS1-DELTA-20261031.md
parent_task_id: TASK-4
priority: medium
type: bug
ordinal: 132000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
PR409已确认N-loth事件标题、开场、交易说明和结束正文有原作身份外露；复用批准的本作映射，不重开既有中文化成果，不改内部来源标识、交易和随机流。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 核对实际生产事件标题、正文、选项和奖励遗物展示，移除已确认四处原作身份外露。
- [ ] #2 复用批准世界观与名字；无批准映射时保留待评审，不自行编造。
- [ ] #3 遗物候选、移除取得顺序、重复礼物和随机流不变，专项回归与同候选设备截图分别记录。
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. 核对远端568da4e4实际事件展示与已批准世界观映射。2. 仅清理四处玩家文案身份外露，保留内部ID、交易与随机流。3. 定向回归及独立复审后提交PR；同候选设备截图单列未验。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
2026-11-01当前队列调整：在PR439已将手机可读性列入High后，优先处理用户本轮明确要求上线前紧急消除的结算错误用时（TASK-38.3）。本项由High移至Medium，保持To Do、负责人、既定首发范围及三条验收不变；没有取消原作身份清理要求或勾选完成。
2026-11-03 赛后排期：m-5 → M7 产品体验与核心特色；状态与未验 AC 保留，不设新截止日。

2026-11-03 基于远端568da4e4独立核对：四处展示及遗物中文仍有原作身份，但当前批准Lore与eventCopy没有对应映射，遵守AC2不自行命名。待Owner提供已批准称呼；调查证据见docs/backlog-details/TASK-4.18-20261103.md。

更正：此前将缺少新世界观映射判断为全部施工阻塞过强。data/relics.json已有中文称呼“恩洛斯的礼物”，先沿真实展示链路核验并统一已有中文；不编造新身份，世界观适配与设备验收另列。

2026-11-03 已沿真实生成控件复现四处英文直写，复用现有遗物中文称呼“恩洛斯”完成四处一致性修复。新控件回归先红后绿1/1、原事件专项4/4通过；仅处理中文一致性，完整Lore适配与同候选设备未验，AC均保留。详见docs/backlog-details/TASK-4.18-20261103.md，首轮完全阻塞判断已更正。

2026-11-07 看板核对（develop 2c85bc61）：实现类交付已按历史记录保留，剩余 AC 待同候选官方/设备验证；当前无在途 PR，状态由 In Progress 归 To Do（待验）。
<!-- SECTION:NOTES:END -->
