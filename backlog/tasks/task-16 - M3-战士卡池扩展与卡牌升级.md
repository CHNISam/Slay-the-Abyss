---
id: TASK-16
title: M3 战士卡池扩展与卡牌升级
status: To Do
assignee: []
created_date: '2026-10-22 13:48'
updated_date: '2026-10-22 23:00'
due_date: '2026-10-28'
labels:
  - queued-after-M2
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
- [ ] #1 至少30张实际可构筑可执行卡牌（非仅JSON条目），基本/升级效果逐张回归且可从合法奖励/商店获得；75张仅可选
- [ ] #2 营地升级当前支持卡牌已本地回归；全部首发卡池需在平台候选验收升级后效果
- [ ] #3 卡牌文案与数值来源、表现映射完整，未实现效果不进入候选可玩池
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
2026-10-23审计：37张运行契约不等于37张可玩；PR37七张规则候选尚未合并。当前只承认初始牌组/有限奖励池及营地升级已有测试；首发至少30张实际可用仍为核心阻塞，75张扩展为可选，不阻塞M3。

- 历史快照：上段PR44审计的“PR37七张”保留为当时快照，不代表当前PR37或已合并卡池。
- 十卡候选：dot 的 PR37 head 18ecbf4e3e17c4fd8f4f01a66f6552e9be8f5719 已包含十张新增规则，规则支持30张（含3基础）、27张合法奖励候选；尚未合并、未平台验收，不等于本任务投稿可用验收完成。https://github.com/CHNISam/Slay-the-Abyss/pull/37
- 正式CI：十卡head的 Quality 39865297069 两作业成功、Fengari368组通过；此前九卡332组 Quality 39863699964成功。仅证明各自head，不代替后续整合候选重验。https://github.com/CHNISam/Slay-the-Abyss/actions/runs/39865297069
- 数值守恒：上述十卡候选的原始data树与develop77744e2完全一致，tree d23c537e07bd166be4a70076fa701aeb735d322e；未修改原始数值。
- 已知缺口：真实生成控件已复现越战越勇实际成长13/16而牌面仍为8；旧抽牌底座满手时继续抽弃，应改为停止抽牌。Owner已批准仅收尾这两项纠偏，两位独立作者正在处理，尚未交付，不能记为修复完成；不继续扩卡、不抢主冲刺。
- 顺序关口：TASK-14本地实现已Done，平台部分由M2 TASK-12.3承接；先完成M1 TASK-2/3.1/3.2/11.1/3，再完成M2平台关口，之后才轮到M3。本任务仍To Do、未正式认领、queued-after-M2，三条AC均未完成；TASK-8.3已在最新develop真实Done，不再携入旧metadata增量。

- 纠偏进展（2026-10-23）：上段“尚未交付”为当时快照。满手停止抽牌修复已由PR45合入develop1217abb22ded7b2bd8195e21f7dfdc9efa44181e，head366753的正式Quality39868328456两作业成功。https://github.com/CHNISam/Slay-the-Abyss/pull/45
- 组合候选：成长牌面现已正确显示13/16；与十卡规则及PR45底座组合后，本地系统Lua387组、Python16项通过。成长显示修复与PR37组合尚未合并，不能以先前368组CI或PR45单独CI替代新组合正式CI；平台编译、导入与实机仍未验收。只收尾既有纠偏，不继续扩卡，TASK16状态、排期及三条AC保持不变。
<!-- SECTION:NOTES:END -->
