---
id: TASK-14
title: M2 同局跨节点库存与遗物药水本地实现
status: Done
assignee:
  - '@Codex'
created_date: '2026-10-22 13:47'
updated_date: '2026-10-22 22:21'
due_date: '2026-10-26'
labels: []
milestone: m-3
dependencies:
  - TASK-12
  - TASK-13
references:
  - 'https://github.com/CHNISam/Slay-the-Abyss/pull/29'
ordinal: 14000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
跨节点存档状态：血量、金币、卡组、遗物、药水，以及死亡重开重置。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 遗物效果在后续战斗真正生效
- [x] #2 死亡后重开，状态正确重置
- [x] #3 本地真实Map/Nodes跨节点保留生命、金币、卡组UID、遗物和药水；失败/重复输入保持事务
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. 在已本地验证的七节点接口上推进同局库存功能；上游平台验收保持未完成，不以Lv4退出续局阻塞。2. 接六个combat_start遗物和已有combat_end回血，复用数据字段，跨战斗重置暂态。3. 接七药水实际消耗与效果，预检目标/槽位/阶段及失败原子性，固定药水数值不吃卡牌力量或敏捷。4. 测试跨节点血量/金币/UID卡组/遗物/药水保持及死亡新局重置；界面接按钮并独立复核。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
CLAIM 2026-10-23 /root/inventory_effects；feat/task-14-inventory/.worktrees/inventory-effects；独立修改Run库存与测试。TASK12/13代码已有且本地接线验证，但平台AC仍待实测。

已接六件开战遗物与原有胜利回血、七药水真实消耗/效果，Run.usePotion候选事务保留combat根引用，非法槽/目标/未知status/溢出全部拒绝且原子。三个固定场内按钮按真实数据展示效果，喝掉后留空位防重复点击误耗下一瓶；末敌药水击杀触发正常奖励/回血一次。10组inventory用例含真实Map/Nodes两场原数值战斗（仅初始金币测试夹具提高到1000以覆盖购卡），验证资源/永久UID保持、新遗物下战生效、临时状态清除和死亡Run.new重置；UI新增2组药水点击回归。完整npm run check退出0：99JS中93通过6权限skip、120Lua通过、Python10通过1权限skip。AC2/3按本地规则与重开证据勾；平台跨节点实际验证未做，AC1未勾，仍InProgress，未声明退出续局。独立审查进行中。

独立只读审查/root/inventory_review通过：既有inventory10与UI8，加12组药水消耗顺序/重复/换战换局/隐藏保护探针全部通过；未知status、状态溢出、异常奖励事务、非有限目标及开战遗物失败均保持完整原状态。未发现可复现缺陷；本地验证不代表平台通过。

原平台跨节点验收拆至TASK-12.3 M2；本轮inventory10组通过。Lv4退出续玩不在首发依赖中。
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
同局库存、遗物真实效果、七药水与新局重置已合入PR29，本地inventory10组通过；平台保持待验收。
<!-- SECTION:FINAL_SUMMARY:END -->
