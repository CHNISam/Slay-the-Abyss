---
id: TASK-16
title: M3 战士卡池扩展与卡牌升级
status: To Do
assignee: []
created_date: '2026-10-22 13:48'
updated_date: '2026-10-22 23:42'
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

2026-10-23既有PR37组合候选：基于真实develop7fee95e（PR46导出保护、PR47生命/意图、PR48荆棘和已合并PR50格挡999上限），仅移植既有十卡与成长实例文字；不扩卡池、不改原始JSON。doubleBlock沿用Combat.block固定增量，未另写规则。修正body_slam旧荆棘绕过格挡断言和entrench无上限断言；新增基础/升级499、500、600、999边界、重复封顶后消耗再翻倍、封顶后异常原子回滚。20系统Lua套件411组及Python16通过；最新正式CI待父级推送后核对。只计本地/生成控件证据，未做官方导入或实机验收，保持To Do、queued-after-M2和现行三条AC，M1仍唯一主冲刺。
<!-- SECTION:NOTES:END -->
