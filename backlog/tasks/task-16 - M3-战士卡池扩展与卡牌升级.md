---
id: TASK-16
title: M3 战士卡池扩展与卡牌升级
status: To Do
assignee: []
created_date: '2026-10-22 13:48'
updated_date: '2026-10-22 21:42'
due_date: '2026-10-28'
labels: []
milestone: m-4
dependencies:
  - TASK-9
  - TASK-14
ordinal: 16000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
把卡池扩到投稿可用规模，营地升级卡牌生效。时间不足时优先保核心构筑完整。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 卡池扩展到投稿可用规模（首轮 30+，时间允许继续补到 75）
- [ ] #2 卡牌升级在营地可用且效果生效
- [ ] #3 卡牌文案与数值为自有实现，不搬运他人资产
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
### 状态
- PR37 独立候选；TASK-14 未完成，未认领、未合并。本任务状态、负责人、依赖及 AC 不变。

### 本轮卡牌
- 加固防线：当前格挡翻倍，不重复计算敏捷/脆弱。
- 集中精神：先抽牌，再禁止本回合抽牌，下回合恢复。
- 透支：支付 HP 换能量。
- 舍身进攻：支付 HP 后造成攻击伤害。
- 奋力一搏：支付 HP 换能量与抽牌，打出后消耗。
- 数值与升级沿用 data；HP 支付无视格挡与攻击修正，不触发荆棘，致死停止后续效果且无奖励。

### 验证
- 新增27组：26红、1既有保护绿 → 27绿；全191组 Lua5.4、Python12项通过。详细用例见 tests/lua/hp_loss.lua。
- 本地 JS 123/130通过，7项因缺 Fengari 失败；新候选正式 CI 待运行。
- 2459 基线 CI 39858438081 双平台成功，仅覆盖前两卡，不能代替 loseHp 验证。
- 旧 offering 未支持负例改为仍未支持的 demon_form，完整保留拒绝与能量/HP/RNG断言。

### 边界与证据
- 可用25张含3基础、22张奖励候选，未达30+；flex未接，无平台编译/导入/试玩验证。
- PR37：https://github.com/CHNISam/Slay-the-Abyss/pull/37
- 历史：8ee173c / d989 / 2459a5a；完整过程保留在 Git 历史。
- 下一步：独立复核、新提交正式 CI、TASK-14及平台验收。
<!-- SECTION:NOTES:END -->
