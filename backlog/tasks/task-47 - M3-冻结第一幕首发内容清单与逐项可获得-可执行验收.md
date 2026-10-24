---
id: TASK-47
title: 确定首发内容，并逐项确认真的能玩
status: In Progress
assignee:
  - '@Codex'
created_date: '2026-10-24 02:01'
updated_date: '2026-10-24 10:18'
due_date: '2026-10-28'
labels: []
milestone: m-4
dependencies:
  - TASK-7
references:
  - docs/backlog-details/TASK-47.md
  - docs/DELIVERY-CLOSEOUT.md
  - docs/LAUNCH_CONTENT.md
  - data/release/launch-content.json
priority: high
type: task
ordinal: 75000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
列清楚首发有哪些卡牌、敌人、遭遇、事件、遗物、药水和Boss。每项都要能正常遇到、拿到或使用。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 列出首发具体清单和获取方式；至少30张可用牌、1个Boss，没做完或未验证的内容不随机出现。
- [ ] #2 清单上的每项都通过正常玩法获得并使用过，有测试和实玩记录，不靠调试塞进背包。
- [ ] #3 能自然组成不同合法卡组并重复游玩；未完成项逐项列出。
- [ ] #4 首发清单同时注明每项代码或素材实际接入入口、对应平台及实机验收任务和当前占位；独立候选与离线文件不能登记为玩家可用。
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. 从生产代码枚举各类首发内容及合法入口，明确候选排除。 2. 建立逐项机器清单和中文说明，列明验收任务、本地、平台和实机边界。 3. 定向核对清单与生产池，保留自然获取和实机缺口，不因建表转Done。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
已按6e8714f建立生产首发范围清单：30张基本/升级职业牌，另列3种状态/诅咒；19普通敌人、3精英、1Boss及18遭遇；当前已接7事件；13遗物及6种战士可获药水。配对/转化、未实现7牌和Silent专属毒药水明确排除。每项经profile关联代码入口、已有本地测试、平台/自然实机待验状态和负责任务。机器校验与4项定向回归通过，默认Node测试会发现新门禁；未运行游戏/MCP或制作候选。三件Boss遗物第17层才获，本幕无后续战斗自然触发，保留此执行边界。所有AC仍未勾，TASK-47保持In Progress。详见docs/LAUNCH_CONTENT.md。
<!-- SECTION:NOTES:END -->
