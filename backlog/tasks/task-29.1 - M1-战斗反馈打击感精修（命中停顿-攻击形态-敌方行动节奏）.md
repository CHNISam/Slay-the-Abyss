---
id: TASK-29.1
title: M1 战斗反馈打击感精修（命中停顿/攻击形态/敌方行动节奏）
status: In Progress
assignee:
  - '@Claude'
created_date: '2026-10-23 03:53'
updated_date: '2026-10-23 03:55'
labels:
  - enhancement
dependencies: []
parent_task_id: TASK-29
priority: high
ordinal: 44000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
用户认为 PR #52 的战斗特效质量偏低。本任务只打磨 abyss_feedback 的既有表现：出牌到命中的连续性与停顿、普通/重击/群体/多段/岩元素差异、命中/格挡/受伤/状态/死亡反馈、敌方蓄势-出手-命中-结束顺序。参照初代 Slay the Spire PC 的反馈机制与节奏，保持岩元素视觉语言，独立实现；不改规则、伤害结算与随机数。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 出牌有蓄势与加速飞行，到达帧即接触帧；命中停顿使击退/闪色/数字保持峰值，重击与致命一击停顿更长
- [ ] #2 普通、重击、多段、群体、持续伤害、反伤在冲击形状、击退、抖屏和音效触发上可区分，并有自动回归
- [ ] #3 格挡获得/完全吸收/破盾、状态生效、敌人死亡各有独立反馈；同时击杀一起倒下且只播一次死亡音
- [ ] #4 敌方行动按蓄势→接触前冲与音效→回位顺序播放；非攻击意图不做攻击动作
- [ ] #5 不新增随事件分配的控件（仅 1 个固定横扫控件），输入锁、取消与故障恢复保持；npm run check 通过
- [ ] #6 实机观感与音效听感未验收时如实记录，不宣称通过
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. 在 ui_theme.json motion 增加 hitStop/hitStopHeavy/heavyHitDamage/anticipation 四个令牌
2. abyss_feedback: 依据已提交事件与卡牌定义分类命中形态（single/multi/area/dot/self）与轻重；命中停顿计入步骤时长
3. 攻击者姿态（蓄势/前冲/回位）、受击者击退/闪色/岩晶冲击、盾牌结晶/震颤/破碎、状态压印、死亡塌落，按角色每帧合成一次
4. 群体伤害逐帧涟漪+单一横扫控件，击杀延后到横扫结束并成组播放
5. 新增 tests/lua/feedback_polish.lua，保留既有回归；生成新旧轨迹对照页
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
本地实现完成：abyss_feedback 命中停顿/攻击形态分类/攻击者姿态/盾牌三态/状态压印/死亡塌落/群体涟漪与成组死亡；ui_theme motion 新增 4 令牌；ui-layout 新增 feedback/sweep。npm run check 通过（JS 260/14 跳过，Lua 全部通过含 LUA_FEEDBACK_POLISH_PASS 13，Python OK）。效果对照页由真实 Lua 轨迹生成：https://claude.ai/artifact/VGMVmHv4pRtptc7iJmZLsi 。未打开原神；实机观感、帧率、非等比 SetLocalScale 平台表现、音效听感均未验收。
<!-- SECTION:NOTES:END -->
