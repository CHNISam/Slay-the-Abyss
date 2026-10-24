---
id: TASK-10.5.1
title: 状态详情与敌人意图改成白话，并修复详情面板只显示一行
status: In Progress
assignee: []
created_date: '2026-10-24 04:39'
updated_date: '2026-10-24 05:14'
labels: []
dependencies: []
references:
  - 'https://github.com/CHNISam/Slay-the-Abyss/pull/159'
parent_task_id: TASK-10.5
priority: high
type: bug
ordinal: 81000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
实机截图：守卫「模式转换」详情只显示一行被截断的『进攻阶段再损失所示生命后转为防守阶段（当前』，标题/生命/状态名都不显示。原因有二：1) statusInfo 面板文本框高度（标题28/生命22/名称22/说明38）低于原生单行高度40，整行不渲染、说明只剩一行；2) 九种以外的状态直接拼 data 原文+『（当前N层）』，原文含『所示/等量/层数』等术语。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 所有状态详情都有专门白话句子并带实时数值，不出现所示/等量/层数/（当前，长度不超过两行
- [x] #2 详情面板标题、生命、状态名、说明行高均不低于原生行高，满 5 行时不超出屏幕
- [x] #3 敌人意图详情写清是谁获得什么（自身获得/使你获得/攻击 N 次每次 M 点）
- [ ] #4 原神千星奇域实机截图确认面板各行完整显示
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
本地实现：abyss_battle_ui.lua 为全部 18 种状态写白话句（模式转换=『再损失 N 点生命，就转入防守形态并获得 20 点格挡』），意图详情改为『自身获得/使你获得/攻击 2 次，每次 9 点伤害』；ui_theme statusInfo 改为宽400、各行≥40、说明56、5行；data/statuses.json 描述同步白话；压制攻势卡面改『目标的力量 -2，攻击伤害随之降低』。新增测试：card_preview 遍历全部状态查术语/数值/两行长度，ui-layout 查面板行高与总高。AC4 需实机截图，未验证。

集成 PR #159：https://github.com/CHNISam/Slay-the-Abyss/pull/159，目标 develop。fetch 后基线仍为 b3c2ecb，无需 rebase。本地 npm run check 的 JavaScript 928 通过/118 跳过，数据校验通过；acid_slime_l.lua 首次 ETIMEDOUT，使用原超时单独重跑 29 组通过，其余检查与当前 SHA CI 继续完成后合并。实机截图尚未验证；本轮未构建或导入存档，未游戏内验证。任务保持 In Progress，AC4 保持未勾选。

合并前 develop 新增 PR #157（ece758d），已 rebase 并解决冲突：保留精确伤害预览、复合意图图标、非攻击意图不显示数字、详情延迟与意图行；状态详情采用本任务白话句及 400 宽/100 行高/5 行布局。同步新基线的哨卫、黏滞和大型棘刺团文案断言。新基线完整检查与当前 SHA CI 通过后 squash 合并；实机验收仍缺。
<!-- SECTION:NOTES:END -->
