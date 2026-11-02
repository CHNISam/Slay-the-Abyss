---
id: TASK-4.21
title: 定位玩家反馈的手机卡顿与加载慢
status: In Progress
assignee:
  - Furinya
created_date: '2026-10-31 23:38'
updated_date: '2026-11-02 02:25'
labels: []
milestone: m-5
dependencies: []
references:
  - docs/backlog-details/TASK-4.21.md
  - docs/evidence/mobile-readability-20261101/
parent_task_id: TASK-4
priority: medium
type: bug
ordinal: 136000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
同一批玩家反馈还包含很卡，具体阶段未知；加载慢和低配置均为待验证猜测。独立排查逐帧重复写入、切页重建与加载路径，优先保留可重复证据，不更换已延期优化的背景。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 分别记录启动加载、静止帧、战斗与切页路径的已证实事实和未知项，不将mock耗时或配置猜测当真机根因。
- [x] #2 对已证实的冗余原生写入作最小修复，保持滚动、状态更新、生命周期与失败恢复正确，并有前后调用计数回归。
- [ ] #3 同候选手机记录设备、启动和交互耗时，区分冷载、持续卡顿及累积实例；未实测不宣称手机性能已修好。
- [x] #4 同战斗覆盖页暂停不重复创建销毁怪物容器，默认卸载、战斗更换和失败清理保持正确，离线计数和状态回归可重放。
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. 独立计数地图和战斗静止帧及覆盖页切换。2. 有证据后只消除同值重复原生写入，不动背景算法或提高门槛。3. 验证状态变化、回页和新对象仍更新，独立审查并与字体修复一起交付。4. 实机性能结论保持待验。

2026-11-01 M4独立切片：基于4f42212重新计数覆盖页往返。显式区分同战斗覆盖暂停与默认卸载，仅保留暂停actor容器，隐藏并停止输入/动画；粒子输出仍释放。换战斗、死亡、结算、禁用及失败恢复保持原清理合同。新增真实Host负控、10轮创建销毁计数、run/RNG/旧输入与重复恢复回归；设备性能不作结论。

2026-11-02 非视觉性能小切片：先在真实Host和奖励布局模块计数复现隐藏/稳定奖励区重复尺寸提交；仅为六处SetSizeDelta添加成功写入缓存，按原生对象和控制器所有权隔离，写前撤销旧值，false/throw后重试，失效对象仍走原生检查。覆盖普通与expanded切换、换对象与换owner，保持位置、可见性、布局、动效、按钮和run/RNG不变；保留负控及计数，独立复审后交付，实体手机性能AC仍未验。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
2026-11-01 已证实并修复地图重复尺寸与意图图文写入；db4014c5独审PASS并整合04e3a75e。300次离线更新地图15000→1200次尺寸提交，意图文字/图片300→0次重复提交；呼吸/滚动/粒子保持原路径。跨地图与控制器共享native控件、部分成功后返回false/throw均有RED→GREEN；两次Important拒绝及修正证据保留。Root实际两raw场景共13项与独审通过；没有手机FPS/P95/冷载结论，actor覆盖页重建仅调查、本批未动，实际卡顿原因与AC3保持未验。

2026-11-01 M4覆盖暂停切片：4f42212同battle菜单/地图10轮actor创建/销毁10/10→0/0，模板mock控件350→0。显式临时暂停保留容器，默认false仍卸载；新Host回归验证完整run/RNG/事件不变、旧输入、暂停、换battle、死亡/终态、settle、失败清理及恢复，既有粒子/死亡/菜单/原生生命周期和工程门禁通过。证据docs/evidence/m4-overlay-suspend-20261101/；完整精确SHA CI与独审另验，原生美术关闭计数不能外推其成本，实体手机AC3仍未验。

2026-11-02 非视觉尺寸提交切片：真实Host复现隐藏奖励区3次render尺寸18→0、真实奖励按钮打开picker后入场1次update尺寸6→0；模块首帧后300次重复尺寸1800→0。仅六目标SetSizeDelta成功写缓存与无回指controller token接线，位置/可见性/行序/动效/业务不改。十组边界、三负控、真实Host完整run/RNG及九按钮字段不变、五项相邻Lua通过；固定hash Luacheck恢复后quality/architecture/static、四关键变异、四原生合同及syntax/backlog/diff通过。证据docs/evidence/m4-reward-size-cache-20261102/。独立复审通过，待最终提交绑定与托管完整CI；未push/合并，无实机性能结论，AC3及任务状态保持。
<!-- SECTION:NOTES:END -->
