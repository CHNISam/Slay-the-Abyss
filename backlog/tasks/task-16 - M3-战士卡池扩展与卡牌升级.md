---
id: TASK-16
title: M3 战士卡池扩展与卡牌升级
status: To Do
assignee: []
created_date: '2026-10-22 13:48'
updated_date: '2026-10-22 22:28'
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
- PR37 独立候选；TASK-14 未完成，不认领、不关闭 TASK-16，状态、负责人、依赖及 AC 不变。

### 已接入的规则
- 加固防线：当前格挡翻倍，不重复计算敏捷或脆弱。
- 集中精神：先抽牌，本回合禁止继续抽牌，下回合恢复。
- 透支、舍身进攻、奋力一搏：支付 HP 换能量、攻击或抽牌；致死停止后续效果，沿用既有消耗规则。
- 蓄力：本回合获得临时力量，按既有回合时序回收。
- 格挡反击：当前格挡作为攻击基础，沿用攻击修正，不主动消耗格挡。
- 乘隙追击：攻击易伤目标后回能、抽牌；仅启用已有条件契约，错误或不支持的分支在出牌前拒绝。
- 连续出剑：攻击后生成本牌副本进入本场弃牌堆，保留升级、分配新UID，不写入永久牌组。
- 越战越勇：仅此实例本场伤害增长，下一战清零；失败连成长字段一起原地回滚。
- 名称、数值和升级沿用现有 data 与表现层，不新增 UI 方向。

### 验证
- 新增 entrench 10、draw_lock 15、hp_loss 27、flex 16、block_damage 25、vulnerable_combo 52、copied_attack 34、growing_attack 36 组回归；各能力先红后绿。
- 当前组合全368组系统 Lua5.4、Python13通过；本地 JS123/130，7项缺 Fengari 失败，新组合正式 CI 待跑。
- 九卡基线62341c0已通过正式CI39863699964（Fengari332、JS124通过/0失败/6跳过）；它不替代新增成长验证。
- 出牌异常回滚已由PR41合入develop77744e2，正式CI39860609778通过。flex换回旧核心有5组真实失败，现组合已修复。
- 旧offering拒绝用例改用仍未支持的demon_form，原状态不变断言完整保留。

### 证据与边界
- PR37：https://github.com/CHNISam/Slay-the-Abyss/pull/37
- 旧过程保留在提交历史，详细用例见tests/lua；不把系统Lua补证当平台验收。
- 规则支持30张含3基础、27张奖励候选；尚未满足整项投稿可用验收，无平台编译、存档导入或试玩通过声明。
- 已复现UI缺口：越战越勇成长到13/16时牌面仍写静态8，不能宣称完整显示体验；文案衔接单独复核。
- 下一步：新组合独立复核与正式CI，等待TASK-14依赖完成后再整合交付。
<!-- SECTION:NOTES:END -->
