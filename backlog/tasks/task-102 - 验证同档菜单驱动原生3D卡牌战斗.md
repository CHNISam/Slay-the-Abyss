---
id: TASK-102
title: 验证同档菜单驱动原生3D卡牌战斗
status: In Progress
assignee:
  - Furinya
created_date: '2026-11-07 10:29'
updated_date: '2026-11-07 11:39'
labels: []
dependencies: []
references:
  - 'https://github.com/FurinyaWorks/Slay-the-Abyss/pull/553'
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

最终候选3f61866d已从干净源89cc82d9构建：GIL SHA256 1d5f170724b50c63bd3bb0aa75725371fee6050286d4b9da57cda0708f4c61f5，15867034字节；348模块和完整UI读回通过、0error357warning保留。独立复审无未解P1/P2，Draft PR #553。报告和摘要在experiments/native-3d-lab/RESULTS.md及evidence-summary.json。等待本轮明确输入窗口再做官方导入/真实双向回执/Tween视觉，不让用户提前导入，AC保持未勾选。

用户官方截图证实3f61866d试玩校验失败：出生点{0,2000.4,0}越界。根因是误用默认模板停放高度。bb331ebc统一改为[0,.4,0]并同步怪物/地板、增加坐标守卫与独立出生点读回；7项原生场景测试通过，正在重建。旧包不再交付，实机ready仍未验证。截图保存在.artifacts/native-3d-launch-failure.png。

坐标修复完整候选85472c95构建/348模块/UI与出生点独立读回通过，hash758437bcb617e4e28572db6fa3fdf2113ec48cdf245b1489a3788e717928292e。简短路径 F:/New folder/.artifacts/原生3D实验-坐标修复-85472c95.gil 哈希一致。新增7项测试及小修独立复审通过，官方启动仍未验收。

用户手动实测日志109已只读核查，当前85472c95 marker+ready匹配，官方1918外部Lua348/348一致。真实双向通信37请求53回执通过；TweenB完成，首次局部调用A84/B20。攻击/受击共8次animation_timeout且0completed，3D性能组正确作废，不能判整体通过。详情experiments/native-3d-lab/REAL-CLIENT-RESULTS.md，任务保持In Progress。
<!-- SECTION:NOTES:END -->
