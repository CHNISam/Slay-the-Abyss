---
id: TASK-4.21
title: 定位玩家反馈的手机卡顿与加载慢
status: In Progress
assignee:
  - Furinya
created_date: '2026-10-31 23:38'
updated_date: '2026-11-03 02:45'
labels: []
milestone: m-7
dependencies: []
references:
  - docs/backlog-details/TASK-4.21.md
  - docs/evidence/mobile-readability-20261101/
  - docs/evidence/m4-deck-controller-lifecycle-20261102/
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

2026-11-02 fresh单槽药水查询：拒绝跨hover和跨native渲染间隔复用frame缓存，不引全模型revision改造；将原药水row构造抽为共用helper，完整potionView保持原槽序与候选规则，仅popup每次open/render/act改为fresh单槽查询，实际使用前完整重验不变。覆盖全药水parity、非法/空/第五槽、后续合法目标、busy、原地状态改变、真实Host重入与使用；按465合入后的最新develop组合TASK81输入路径切片，保留全部历史证据和未验实机AC。

2026-11-02 牌库注册生命周期小切片：先用真实 DeckUI/Controller 与原生 Grid 销毁语义复现记录累积；只对确认销毁的牌面保存 hit 并调用现有 Controller.unbind，覆盖关闭后的及时释放及存活复用。新增重复开关、翻页/过滤/排序、刷新销毁/回收、原生失效、键鼠/手柄和旧回调回归；先红后绿、定向检查及独审，不改设计/Controller 架构，不推断手机性能，AC3 保持未验。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
2026-11-01 已证实并修复地图重复尺寸与意图图文写入；db4014c5独审PASS并整合04e3a75e。300次离线更新地图15000→1200次尺寸提交，意图文字/图片300→0次重复提交；呼吸/滚动/粒子保持原路径。跨地图与控制器共享native控件、部分成功后返回false/throw均有RED→GREEN；两次Important拒绝及修正证据保留。Root实际两raw场景共13项与独审通过；没有手机FPS/P95/冷载结论，actor覆盖页重建仅调查、本批未动，实际卡顿原因与AC3保持未验。

2026-11-01 M4覆盖暂停切片：4f42212同battle菜单/地图10轮actor创建/销毁10/10→0/0，模板mock控件350→0。显式临时暂停保留容器，默认false仍卸载；新Host回归验证完整run/RNG/事件不变、旧输入、暂停、换battle、死亡/终态、settle、失败清理及恢复，既有粒子/死亡/菜单/原生生命周期和工程门禁通过。证据docs/evidence/m4-overlay-suspend-20261101/；完整精确SHA CI与独审另验，原生美术关闭计数不能外推其成本，实体手机AC3仍未验。

2026-11-02 非视觉尺寸提交切片：真实Host复现隐藏奖励区3次render尺寸18→0、真实奖励按钮打开picker后入场1次update尺寸6→0；模块首帧后300次重复尺寸1800→0。仅六目标SetSizeDelta成功写缓存与无回指controller token接线，位置/可见性/行序/动效/业务不改。十组边界、三负控、真实Host完整run/RNG及九按钮字段不变、五项相邻Lua通过；固定hash Luacheck恢复后quality/architecture/static、四关键变异、四原生合同及syntax/backlog/diff通过。证据docs/evidence/m4-reward-size-cache-20261102/。独立复审通过，待最终提交绑定与托管完整CI；未push/合并，无实机性能结论，AC3及任务状态保持。

2026-11-02 PR465已合develop de5607ba8edc0701c2545a587c85aefd499281b4，原尺寸切片记录保留。本次fresh单槽查询不使用缓存、不简化任何药水候选规则：三药水真实Host单render候选模拟6→4，完整run/RNG不变；34定义parity、槽位/目标/状态边界、无refresh旧Use拒绝及恢复真实Use通过。原生setter中注入公开Run.play的合成重入证明旧frame缓存不安全；组合465后注入改同节点SetAnchoredPosition并显式断言执行，旧frame-cache负控仍被原fresh断言杀死。独立切片及组合定向验证、负控、工程门禁证据见docs/evidence/m4-potion-slot-view-20261102/；现线性集成base为de5607，集成内容提交ad7820030efc78ae2ae5c64e3d2b087a3466621c与历史827ca09源码/测试逐字一致。新PR精确SHA完整CI仍待验；未做手机或官方客户端测试，不把离线计数当手机性能结论，AC3未勾、任务状态不变。

2026-11-02 牌库注册生命周期：真实 DeckUI/Controller 与共享原生 Grid 销毁夹具复现关闭一次 records 27（基线14）而回归先红；仅保存原 hit，确认 item 死亡后复用 unbind，刷新后及隐藏/详情 update 回收，不解绑存活复用对象。修后12牌重复1/10/20次关闭均14条、零死亡注册，300次非手柄 sync 扫描82200→4200；7组生命周期/旧输入/选牌/真实Host完整run与RNG、原生合同6项含两负控、相邻7 Lua入口、布局6项、工程/架构/静态/语法及4关键变异通过。证据 docs/evidence/m4-deck-controller-lifecycle-20261102/；独审与精确SHA完整CI另验。无手机FPS/加载结论、无官方导入/实机，AC3及任务状态不变；本轮只本地交付，未推送/开PR/合并。

2026-11-02 PR471完整CI在Windows9/POSIX6实际失败：pr323-deck-lifecycle第二负控仍匹配旧单行清理，唯一锚断言1≠2；不是基础设施豁免。仅适配该入口两行锚点/变异字符串，保留单锚、非零及GetChild invalid-object断言；生产、Lua回归和冻结历史fixture未改。作者原失败复现及ui-mock5项通过，独审pr323两项通过；全树搜索无其他可执行旧锚，原始失败和回归记录见同证据目录ci-anchor-repair。修复后精确SHA完整CI仍须重新验证，AC3与任务状态不变。

2026-11-02 意图几何窄切片计划：已从最新 develop fafcc29 的真实 renderEnemyIntent 重新复现，300帧单敌图标/数值/点击区 size与position各900次，其中各897同值；四敌各3600/3588。仅为六处原生几何写入复用成功缓存模式，按弱native键与无回指binding token隔离，false/throw和重入失效，新对象/重绑/尺寸位数变化继续更新；先红后绿与有序写入/隐藏返回/生命周期定向回归，不改视觉、粒子、动画、输入和玩法。PR473评论6591476184已认领；只本地实现待独审，不代表手机FPS或加载改善，AC3未验且状态保持。

2026-11-02 意图几何切片本地验证：仅renderEnemyIntent图标/数值/点击区六处尺寸位置成功写缓存，弱native键与无回指binding token隔离；重叠setter及其false/throw均不保留不确定承诺。300帧1–5敌size/position各900n→3n（首帧后零同值），真实Host挂载BattleUI300次update各900→0；完整run/RNG、几何/可见/点击字段、idle动画与覆盖返回保持。21组边界、7项JS入口含5精确负控、8份相邻Lua及6原生合同通过，工程测量/架构/静态与syntax/backlog/diff通过。证据docs/evidence/m4-intent-geometry-cache-20261102/，构造失败与最终基线RED均保留；仅本地提交待独审，未推送/PR/合并，完整精确SHA托管CI待验。无官方/手机/FPS/加载结论，AC3及任务状态保持。
2026-11-03 赛后排期：m-5 → M7 产品体验；任务状态与未验 AC 保留。未定新截止日。
<!-- SECTION:NOTES:END -->
