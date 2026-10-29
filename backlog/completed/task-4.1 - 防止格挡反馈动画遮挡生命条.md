---
id: TASK-4.1
title: 格挡动画不能挡住血条
status: Done
assignee:
  - '@Furinya'
created_date: '2026-10-23 14:56'
updated_date: '2026-10-27 15:03'
due_date: '2026-10-24'
labels: []
milestone: m-2
dependencies: []
references:
  - 'https://github.com/CHNISam/Slay-the-Abyss/pull/117#issuecomment-6367383439'
  - docs/backlog-details/TASK-4.1.md
parent_task_id: TASK-4
priority: medium
type: bug
ordinal: 49000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
获得格挡时的动画会变大，修好它压住血条的问题，让玩家始终看得清血量。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 玩家、普通敌人和Boss的格挡动画全过程都不挡血条，格挡数值正确。
- [x] #2 其他动画保持正常，取消或播放结束后界面恢复正常。
- [x] #3 先复现再确认修好，自动检查通过；游戏里看过才算实际视觉通过。
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
固定ce2e417，复核01dd同候选真实384.01飞牌遮挡并保存相邻帧。先用真实控件树/Defend飞行驱动建立层级+几何交叉失败回归；将飞牌单独置于角色信息之后绘制，保留时间、轨迹、尺寸和前景横幅/模态；专项先红后绿及现有反馈/宿主回归后提交。不宣称新候选实机通过，原run继续核其他项。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
2026-10-24最新7e1123b独立复核：横向scale=1修正已由PR109合入95ce2bd，现有真实Defend/1至5敌人/Boss/取消回归全部保留。本轮Fengari battle_ui 52/52通过（19.021秒），布局主题12项通过；实际查看5165候选defend-two截图，玩家格挡5与74/80清晰，不能外推敌人/Boss全过程。未新增游戏操作，尚需同候选连续帧/录像确认玩家、普通敌人各列宽及Boss格挡动画，故AC1/3与整体继续保留。

2026-10-24准备同源统一诊断副本：1–5普通敌人及Guardian六种布局，108个格挡时间线样本、6次播放中取消，旧横向缩放负控失败且修复版离线通过。此为显式夹具/暂停时间线，不认证正常AI、节奏或通关。原生视觉仍缺；自动试玩前台切换失败，未勾AC。

2026-10-24同候选01dd/官方1841/runced168e4新日志837打印，block六布局108样本/6取消已运行；真实63-b384.jpg及相邻帧证明飞牌层在途遮英雄60/80右半，原徽标横向放大缺陷未复现，整体视觉仍FAIL。按该任务继续最小修复：保留playedCard原路径和全部轨迹/时序/字号，将其feedback容器置于角色信息后方；独立feedbackForeground保留横幅/横扫前景。真实生成树加原生SetAsLastSibling顺序模型先红（flying Defend hides hero/hpBorder）后绿，6布局回归过；Node9项、battle_ui52、feedback_polish13、game_ui15、game_ui_exit15全过。新版本未重建/实机，AC保持未勾。

2026-10-24用户最新明确正常飞牌的短暂遮盖不视作bug，要求按优先级完成M1，不让小优化阻塞。原问题是格挡徽标放大压住血条，不能扩大为飞牌的绝对无遮挡标准。01dd/官方1841真实run ced168已完成玩家、1至5普通敌人、Guardian六布局，108格挡时间线样本、6播放中取消；徽标和HP始终分离、格挡数值/恢复正确。真实截图和837条新日志见docs/evidence/m1-live-20261024，block-live-review.json保留当时因飞牌判FAIL的历史，最终用户裁决另记。新飞牌层级尝试为可选优化，已从M1最终生产改动撤出，保留可恢复Git历史，不拿未实测1842冒充通过。

负责人字段规范化：原记录 @dot 作为历史执行者信息保留；任务负责人为 Furinya。
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
原格挡徽标遮血条问题已由01dd实机六布局/108样本/6取消及既有先红后绿回归证明修好。正常飞牌短暂遮盖经用户明确接受，不扩为M1阻塞；额外绘制层试验不交付。旧截图不认证随后develop独立规则更改。
<!-- SECTION:FINAL_SUMMARY:END -->
