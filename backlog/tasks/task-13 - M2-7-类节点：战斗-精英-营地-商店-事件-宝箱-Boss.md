---
id: TASK-13
title: M2 7 类节点：战斗/精英/营地/商店/事件/宝箱/Boss
status: In Progress
assignee:
  - '@Codex'
created_date: '2026-10-22 13:47'
updated_date: '2026-10-22 16:53'
due_date: '2026-10-26'
labels: []
milestone: m-3
dependencies:
  - TASK-12
references:
  - 'https://github.com/CHNISam/Slay-the-Abyss/pull/29'
ordinal: 13000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
七类节点各自流程：营地回血或升级卡牌，商店购买与删除卡牌，事件与宝箱产出真正生效。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 7 类节点均可进入并各有独立流程
- [x] #2 营地可回血或升级卡牌
- [x] #3 商店可购买卡牌/遗物并删除卡牌
- [x] #4 宝箱与未知事件产出真正生效
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. 在已合入地图核心上新增独立Nodes服务，事务性进入七类节点；地图UI剩余由TASK12并行实现，不将其依赖虚标完成。2. 营地回血/升级、商店买卡买遗物删牌、宝箱/事件一次性产出复用现有rules及内容字段，预检拒绝后状态不变。3. 接真实Run战斗与奖励后解锁、测试重复领取/非法跳转/金币和卡组变化；Boss仅返回节点胜利，正式结算在TASK17。4. 集成UI后再按客观证据验收，平台未验证单列。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
CLAIM 2026-10-23 /root/node_flows；feat/task-13-node-flows，.worktrees/node-flows；仅新abyss_nodes.lua与nodes.lua，主Agent集成。任务12核心已可用，UI仍在并行，尚未完成依赖的展示验收。

2026-10-23 新Nodes规则、NodeUI和统一GameUI已接线；18组规则用例与13组节点控件测试，覆盖营地实际升级/回血，商店买卡/遗物/UID删牌、递增价格、金币不足原子拒绝、宝箱/事件一次性入库存；独立只读审查无新增缺陷。整条15层低HP测试路线经实际UI处理器经过全部7类，另有原数据starter完整战斗。AC2-4按规则与实际处理器证据勾选；平台七节点入口/排版未实测，AC1未勾，仍InProgress。遗物运行效果/药水使用接TASK14，30+卡池接TASK16，正式平台结算接TASK17；本地结果页不冒充平台结算。

最终完整集成门禁npm run check退出0；统一入口5组真实处理器测试、13组节点UI、18组Nodes规则全通过。UI展示真实生成的卡牌费用/效果与升级后效果；根目录旧Backlog改动保持原状。
<!-- SECTION:NOTES:END -->
