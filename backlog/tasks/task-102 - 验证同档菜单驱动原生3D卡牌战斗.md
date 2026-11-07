---
id: TASK-102
title: 验证同档菜单驱动原生3D卡牌战斗
status: In Progress
assignee:
  - Furinya
created_date: '2026-11-07 10:29'
updated_date: '2026-11-07 11:03'
labels: []
dependencies: []
priority: medium
type: spike
ordinal: 165000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
用户于2026-11-07明确授权独立3D技术实验，正式游戏暂不迁移且不占M7任务；要求一次导入完成菜单内对比。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 同一GIL包含六类实验菜单及自动连续和手动测试，不能实现的功能展示原因
- [ ] #2 现有Lua规则驱动原生表现，数值规则不改且验证AI和伤害隔离
- [ ] #3 画面展示关键日志错误性能及证据边界，手机和官方未验证项不冒充通过
- [ ] #4 构建读回检查、独立复审及实验代码结果PR齐全，给出迁移建议
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
先复用工具核实官方能力，再实现隔离菜单和表现适配，构建一份完整GIL并静态读回、测试与复审；官方及手机结果分别标注。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
用户追加：同一实验内对照官方Tween/TweenSequence与真实手牌归位，不另建任务；比较Lua调用、复杂度及中断拖拽命中销毁。用户同时要求精简TASK-51委派历史，已仅保留当前有效约定。原生3D桥继续现有实现，离线通过不计实机验证。

完整内部GIL348模块与UI读回通过，0错误357条跨模块UNKNOWN_METHOD告警保留。独立评审已关闭性能超时误报和UI读回问题，并补修Tween旧完成回调的8类状态变更负对照；将重构建最终候选。官方导入、新ready、真实Lua↔节点通信与设备证据尚未执行，任务保持In Progress，AC不提前勾选。
<!-- SECTION:NOTES:END -->
