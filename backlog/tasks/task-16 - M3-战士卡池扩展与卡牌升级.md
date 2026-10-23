---
id: TASK-16
title: M3 战士卡池扩展与卡牌升级
status: To Do
assignee: []
created_date: '2026-10-22 13:48'
updated_date: '2026-10-23 01:07'
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

2026-10-23 PR37兼容候选续整合：基于真实develop fb83e626（PR53遭遇回归、PR52战斗演出），保留原有十卡/成长文字与所有主线事件队列。自扣血新增独立hp_loss帧，临时力量增益/清零后移除帧完整，body_slam飞牌识别实际敌方目标；原数值/费用/格挡/荆棘/原子回滚不变。生成控件实跑成长与复制、逐帧HP支付/攻击、输入锁及释放、异常不泄漏帧。完整系统Lua23套件623组及Python16通过，正式CI仍须发布后核对。仅本地候选整合，未做官方导入/平台试玩，不扩卡池；保持To Do、queued-after-M2和原三条AC，M1仍唯一主冲刺。
<!-- SECTION:NOTES:END -->
